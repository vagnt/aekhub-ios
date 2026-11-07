import SwiftUI
import UIKit
import GoogleMobileAds
import UserMessagingPlatform
import AppTrackingTransparency

/// Διαφημίσεις του app (ίδιες θέσεις και κανόνες με το Android): AdMob (banner, fullscreen, native, rewarded)
/// + δικοί σου χορηγοί (splash, fullscreen, κάρτα στη ροή, banner, «Παρουσιάζεται από»).
/// Όλα από το wp-admin (📱 AEK Hub App → 📢 Διαφημίσεις). Πρώτα συγκατάθεση (GDPR, Google UMP), μετά φόρτωση.
@MainActor
final class Ads: NSObject, ObservableObject {
    static let shared = Ads()

    // Δοκιμαστικά IDs της Google για iOS: όσο το πεδίο «iOS» στο wp-admin είναι κενό
    static let testBanner = "ca-app-pub-3940256099942544/2435281174"
    static let testInter = "ca-app-pub-3940256099942544/4411468910"
    static let testNative = "ca-app-pub-3940256099942544/3986624511"
    static let testReward = "ca-app-pub-3940256099942544/1712485313"

    @Published var ready = false
    /// 🩺 Τι απάντησε η Google την τελευταία φορά (φαίνεται στο «Εγώ»)
    @Published var diag = "Δεν ξεκίνησαν ακόμα"
    func note(_ unit: String, _ e: Error?) {
        let kind = unit.contains("3940256099942544") ? "δοκιμαστική" : "πραγματική"
        if let e { diag = "✗ \(kind): \((e as NSError).code) · \(e.localizedDescription)" } else { diag = "✓ Ήρθε διαφήμιση (\(kind))" }
    }
    @Published var privacyButton = false
    @Published var adFreeUntil: Double = UserDefaults.standard.double(forKey: "ads_free_until")
    /// Χορηγός σε πλήρη οθόνη: (καμπάνια, είναι splash)
    @Published var overlay: SponsorShow?
    @Published var rewardReady = false
    /// Παίζει τώρα η ΑΕΚ; (καμία fullscreen διαφήμιση στη διάρκεια)
    var aekLive = false

    private var started = false
    private var inter: GADInterstitialAd?
    private var interLoading = false
    private var reward: GADRewardedAd?
    private var rewardLoading = false
    private var articles = 0
    private var lastFull = Date.distantPast
    private var rewardDone: ((Bool) -> Void)?
    private var earned = false

    struct SponsorShow: Identifiable, Equatable { let c: Campaign; let splash: Bool; var id: String { c.id + (splash ? "s" : "f") } }

    var cfg: AdsConfig? { AppState.shared.config?.ads }
    var adFree: Bool { Date().timeIntervalSince1970 < adFreeUntil }
    static var shots: Bool { UserDefaults.standard.bool(forKey: "shots") }

    // MARK: Έναρξη: συγκατάθεση → (ATT) → AdMob

    func start() {
        if UserDefaults.standard.bool(forKey: "noads") { return } // screenshots για το App Store
        if Ads.shots { initAds(); return } // screenshots του CI: χωρίς παράθυρα
        let ci = UMPConsentInformation.sharedInstance
        let params = UMPRequestParameters()
        params.tagForUnderAgeOfConsent = false
        ci.requestConsentInfoUpdate(with: params) { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }
                if let vc = Ads.top() {
                    UMPConsentForm.loadAndPresentIfRequired(from: vc) { _ in
                        Task { @MainActor in
                            self.privacyButton = ci.privacyOptionsRequirementStatus == .required
                            self.askTracking { if ci.canRequestAds { self.initAds() } }
                        }
                    }
                } else if ci.canRequestAds { self.initAds() }
            }
        }
        if ci.canRequestAds { initAds() } else { diag = "Περιμένει συγκατάθεση (GDPR)" }
    }

    /// Άδεια παρακολούθησης της Apple (μετά τη συγκατάθεση GDPR, μία φορά)
    private func askTracking(_ done: @escaping () -> Void) {
        guard ATTrackingManager.trackingAuthorizationStatus == .notDetermined else { done(); return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            ATTrackingManager.requestTrackingAuthorization { _ in DispatchQueue.main.async { done() } }
        }
    }

    private func initAds() {
        guard !started else { return }
        started = true
        GADMobileAds.sharedInstance().start { [weak self] _ in
            Task { @MainActor in self?.ready = true; self?.diag = "Έτοιμες, φορτώνουν…"; self?.preload() }
        }
    }

    func showPrivacy() {
        guard let vc = Ads.top() else { return }
        UMPConsentForm.presentPrivacyOptionsForm(from: vc) { _ in }
    }

    static func top() -> UIViewController? {
        let scene = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first { $0.activationState == .foregroundActive }
            ?? UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first
        var vc = scene?.windows.first { $0.isKeyWindow }?.rootViewController ?? scene?.windows.first?.rootViewController
        while let p = vc?.presentedViewController { vc = p }
        return vc
    }

    func unit(_ v: String, _ test: String) -> String { v.isEmpty ? test : v }

    private func preload() {
        guard let cfg, cfg.enabled, ready else { return }
        if cfg.interOn, inter == nil, !interLoading {
            interLoading = true
            let u = unit(cfg.inter, Ads.testInter)
            GADInterstitialAd.load(withAdUnitID: u, request: GADRequest()) { [weak self] ad, err in
                Task { @MainActor in self?.note(u, err); self?.inter = ad; self?.interLoading = false; ad?.fullScreenContentDelegate = self }
            }
        }
        if cfg.rewardOn, reward == nil, !rewardLoading {
            rewardLoading = true
            GADRewardedAd.load(withAdUnitID: unit(cfg.reward, Ads.testReward), request: GADRequest()) { [weak self] ad, _ in
                Task { @MainActor in self?.reward = ad; self?.rewardLoading = false; self?.rewardReady = ad != nil; ad?.fullScreenContentDelegate = self }
            }
        }
    }

    // MARK: Fullscreen όταν κλείνει άρθρο (κάθε Ν άρθρα, με κενό λεπτών, ποτέ όσο παίζει η ΑΕΚ)

    func onArticleClosed() {
        guard let cfg else { return }
        articles += 1
        let sponsor = cfg.pick("interstitial")
        if adFree || (!cfg.interOn && sponsor == nil) { return }
        if articles % cfg.interEvery != 0 { return }
        if Date().timeIntervalSince(lastFull) < Double(cfg.interGap) * 60 { return }
        if cfg.interLiveOff && aekLive { return }
        if let sponsor { lastFull = Date(); overlay = SponsorShow(c: sponsor, splash: false); return }
        guard cfg.enabled else { return }
        guard let ad = inter, let vc = Ads.top() else { preload(); return }
        lastFull = Date()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) { ad.present(fromRootViewController: vc) } // μετά το κλείσιμο του άρθρου
    }

    /// Splash χορηγού μετά το logo (το πολύ μία φορά ανά 4 ώρες)
    func maybeSplash() {
        guard !Ads.shots, let cfg, cfg.splash, let c = cfg.pick("splash") else { return }
        let d = UserDefaults.standard
        if Date().timeIntervalSince1970 - d.double(forKey: "ads_splash_at") < 4 * 3600 { return }
        d.set(Date().timeIntervalSince1970, forKey: "ads_splash_at")
        overlay = SponsorShow(c: c, splash: true)
    }

    // MARK: Rewarded: «χωρίς διαφημίσεις για Χ ώρες»

    func showReward(hours: Int, done: @escaping (Bool) -> Void) {
        guard let ad = reward, let vc = Ads.top() else { preload(); done(false); return }
        earned = false; rewardDone = done
        ad.present(fromRootViewController: vc) { [weak self] in
            Task { @MainActor in
                guard let self else { return }
                self.earned = true
                self.adFreeUntil = Date().timeIntervalSince1970 + Double(max(1, hours)) * 3600
                UserDefaults.standard.set(self.adFreeUntil, forKey: "ads_free_until")
            }
        }
    }

    // MARK: Χορηγοί: μετρητής εμφανίσεων/κλικ (ίδιο με το Android)

    func track(_ c: Campaign, _ ev: String) {
        guard let u = URL(string: Api.base + "/adtrack?c=" + Api.q(c.id) + "&e=" + ev) else { return }
        var r = URLRequest(url: u); r.httpMethod = "POST"
        URLSession.shared.dataTask(with: r).resume()
    }
    func click(_ c: Campaign) {
        track(c, "c")
        if let u = URL(string: c.link), !c.link.isEmpty { UIApplication.shared.open(u) }
    }
}

extension Ads: GADFullScreenContentDelegate {
    nonisolated func adDidDismissFullScreenContent(_ ad: GADFullScreenPresentingAd) {
        Task { @MainActor in
            if ad is GADRewardedAd { self.reward = nil; self.rewardReady = false; self.rewardDone?(self.earned); self.rewardDone = nil }
            else { self.inter = nil }
            self.preload()
        }
    }
    nonisolated func ad(_ ad: GADFullScreenPresentingAd, didFailToPresentFullScreenContentWithError error: Error) {
        Task { @MainActor in
            if ad is GADRewardedAd { self.reward = nil; self.rewardReady = false; self.rewardDone?(false); self.rewardDone = nil }
            else { self.inter = nil }
            self.preload()
        }
    }
}

// MARK: - Θέσεις

struct AdLabel: View {
    var text = "ΔΙΑΦΗΜΙΣΗ"
    var body: some View { Text(text).font(F.body(9, .heavy)).tracking(1).foregroundStyle(C.muted) }
}

/// Banner: πρώτα καμπάνια χορηγού για τη θέση, αλλιώς AdMob. Αν δεν φορτώσει τίποτα, δεν πιάνει χώρο.
struct BannerAd: View {
    var place = "home"
    var medium = false
    @ObservedObject private var ads = Ads.shared
    @EnvironmentObject var app: AppState
    @State private var picked = false
    @State private var sponsor: Campaign?
    var body: some View {
        VStack(spacing: 0) {
            Color.clear.frame(height: 0)
            if picked, let cfg = app.config?.ads, !ads.adFree {
                if let c = sponsor { SponsorBanner(c: c) }
                else if cfg.enabled && ads.ready { AdmobBanner(unit: ads.unit(cfg.banner, Ads.testBanner), medium: medium) }
            }
        }
        .onAppear { if !picked { sponsor = app.config?.ads.pick("banner", place: place); picked = true } }
    }
}

/// Διαφήμιση μέσα στη ροή ειδήσεων: κάρτα χορηγού → native AdMob → banner
struct FeedAd: View {
    @ObservedObject private var ads = Ads.shared
    @EnvironmentObject var app: AppState
    @State private var picked = false
    @State private var sponsor: Campaign?
    var body: some View {
        VStack(spacing: 0) {
            Color.clear.frame(height: 0)
            if picked, let cfg = app.config?.ads, !ads.adFree {
                if let c = sponsor { SponsorNative(c: c) }
                else if cfg.enabled && ads.ready && cfg.nativeOn { AdmobNative(unit: ads.unit(cfg.native, Ads.testNative)) }
                else if cfg.enabled && ads.ready { AdmobBanner(unit: ads.unit(cfg.banner, Ads.testBanner), medium: false) }
            }
        }
        .onAppear { if !picked { sponsor = app.config?.ads.pick("native"); picked = true } }
    }
}

struct SponsorBanner: View {
    let c: Campaign
    var body: some View {
        VStack(spacing: 4) {
            AdLabel(text: "ΧΟΡΗΓΟΥΜΕΝΟ")
            Button { Ads.shared.click(c) } label: {
                NaturalImage(url: c.image, w: 1200, maxH: 400)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }.buttonStyle(.plain)
        }
        .padding(.vertical, 6)
        .onAppear { Ads.shared.track(c, "i") }
    }
}

/// Κάρτα χορηγού που μοιάζει με άρθρο
struct SponsorNative: View {
    let c: Campaign
    var body: some View {
        Button { Ads.shared.click(c) } label: {
            VStack(alignment: .leading, spacing: 0) {
                FillImage(url: c.image, w: 1200).aspectRatio(16 / 9, contentMode: .fit)
                VStack(alignment: .leading, spacing: 8) {
                    Text("ΧΟΡΗΓΟΥΜΕΝΟ · " + c.name.upperGr).font(F.body(10, .heavy)).tracking(0.8).foregroundStyle(C.gold).lineLimit(1)
                    if !c.title.isEmpty { Text(c.title).font(F.body(17, .heavy)).foregroundStyle(C.text).multilineTextAlignment(.leading) }
                    if !c.link.isEmpty {
                        Text(c.cta.isEmpty ? "Δες περισσότερα" : c.cta).font(F.body(13, .heavy)).foregroundStyle(C.ink)
                            .padding(.horizontal, 14).padding(.vertical, 9).background(RoundedRectangle(cornerRadius: 10).fill(C.gold))
                    }
                }.padding(14)
            }
            .card(16)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(.plain)
        .padding(.vertical, 4)
        .onAppear { Ads.shared.track(c, "i") }
    }
}

/// «Παρουσιάζεται από»: λογότυπο χορηγού (Match Center / βαθμολογίες / live). Δεν το κλείνει το rewarded.
struct PresentedBy: View {
    let place: String
    @EnvironmentObject var app: AppState
    @State private var c: Campaign?
    @State private var picked = false
    var body: some View {
        VStack(spacing: 0) {
            Color.clear.frame(height: 0)
            if let c {
                Button { Ads.shared.click(c) } label: {
                    HStack(spacing: 12) {
                        Text("ΠΑΡΟΥΣΙΑΖΕΤΑΙ ΑΠΟ").font(F.body(10, .heavy)).tracking(1).foregroundStyle(C.muted)
                        NetImage(url: c.image, w: 400, mode: .fit).frame(width: 110, height: 28)
                    }
                    .frame(maxWidth: .infinity).padding(.horizontal, 14).padding(.vertical, 8)
                    .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(C.panel))
                }
                .buttonStyle(.plain).disabled(c.link.isEmpty)
                .onAppear { Ads.shared.track(c, "i") }
            }
        }
        .onAppear { if !picked { picked = true; c = app.config?.ads.pick("presented", place: place) } }
    }
}

/// AdMob banner (adaptive ή 300×250)
struct AdmobBanner: View {
    let unit: String
    var medium = false
    @State private var loaded = false
    @State private var failed = false
    @State private var width: CGFloat = 0
    var body: some View {
        if !failed {
            VStack(spacing: 4) {
                if loaded { AdLabel() }
                if width > 0 {
                    let size = medium ? GADAdSizeMediumRectangle : GADCurrentOrientationAnchoredAdaptiveBannerAdSizeWithWidth(min(width, 728))
                    BannerRep(unit: unit, size: size, loaded: $loaded, failed: $failed)
                        .frame(width: size.size.width, height: size.size.height)
                }
            }
            .frame(maxWidth: .infinity)
            .background(GeometryReader { g in Color.clear.onAppear { width = g.size.width } })
            .frame(height: loaded ? nil : 1).opacity(loaded ? 1 : 0)
            .padding(.vertical, loaded ? 6 : 0)
        }
    }
}

struct BannerRep: UIViewRepresentable {
    let unit: String
    let size: GADAdSize
    @Binding var loaded: Bool
    @Binding var failed: Bool
    func makeCoordinator() -> Coord { Coord(self) }
    func makeUIView(context: Context) -> GADBannerView {
        let v = GADBannerView(adSize: size)
        v.adUnitID = unit
        v.rootViewController = Ads.top()
        v.delegate = context.coordinator
        v.load(GADRequest())
        return v
    }
    func updateUIView(_ v: GADBannerView, context: Context) { context.coordinator.p = self }
    final class Coord: NSObject, GADBannerViewDelegate {
        var p: BannerRep
        init(_ p: BannerRep) { self.p = p }
        func bannerViewDidReceiveAd(_ bannerView: GADBannerView) { p.loaded = true; let u = p.unit; Task { @MainActor in Ads.shared.note(u, nil) } }
        func bannerView(_ bannerView: GADBannerView, didFailToReceiveAdWithError error: Error) { p.failed = true; let u = p.unit; Task { @MainActor in Ads.shared.note(u, error) } }
    }
}

/// Native AdMob με τα χρώματα του app (εικόνα/βίντεο, τίτλος, κείμενο, κουμπί)
struct AdmobNative: View {
    let unit: String
    @StateObject private var l = NativeLoader()
    @State private var width: CGFloat = 0
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            if let ad = l.ad {
                AdLabel()
                NativeRep(ad: ad).frame(height: max(width, 1) * 9 / 16 + 128)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
        }
        .frame(maxWidth: .infinity)
        .background(GeometryReader { g in Color.clear.onAppear { width = g.size.width } })
        .padding(.vertical, l.ad == nil ? 0 : 4)
        .onAppear { l.load(unit) }
    }
}

@MainActor
final class NativeLoader: NSObject, ObservableObject, GADNativeAdLoaderDelegate {
    @Published var ad: GADNativeAd?
    private var loader: GADAdLoader?
    private var unit = ""
    func load(_ unit: String) {
        self.unit = unit
        guard loader == nil else { return }
        let l = GADAdLoader(adUnitID: unit, rootViewController: Ads.top(), adTypes: [.native], options: nil)
        l.delegate = self; loader = l
        l.load(GADRequest())
    }
    nonisolated func adLoader(_ adLoader: GADAdLoader, didReceive nativeAd: GADNativeAd) { Task { @MainActor in self.ad = nativeAd; Ads.shared.note(self.unit, nil) } }
    nonisolated func adLoader(_ adLoader: GADAdLoader, didFailToReceiveAdWithError error: Error) { Task { @MainActor in Ads.shared.note(self.unit, error) } }
}

struct NativeRep: UIViewRepresentable {
    let ad: GADNativeAd
    func makeUIView(context: Context) -> GADNativeAdView {
        let v = GADNativeAdView()
        v.backgroundColor = UIColor(C.panel)
        let media = GADMediaView(); media.translatesAutoresizingMaskIntoConstraints = false
        let head = UILabel(); head.textColor = UIColor(C.text); head.font = .systemFont(ofSize: 17, weight: .heavy); head.numberOfLines = 2
        let body = UILabel(); body.textColor = UIColor(C.text2); body.font = .systemFont(ofSize: 13); body.numberOfLines = 2
        let cta = UIButton(type: .custom); cta.backgroundColor = UIColor(C.gold); cta.setTitleColor(UIColor(C.ink), for: .normal)
        cta.titleLabel?.font = .systemFont(ofSize: 13, weight: .heavy); cta.layer.cornerRadius = 10
        cta.contentEdgeInsets = UIEdgeInsets(top: 8, left: 14, bottom: 8, right: 14); cta.isUserInteractionEnabled = false
        let stack = UIStackView(arrangedSubviews: [head, body, cta]); stack.axis = .vertical; stack.spacing = 6; stack.alignment = .leading
        stack.translatesAutoresizingMaskIntoConstraints = false
        v.addSubview(media); v.addSubview(stack)
        NSLayoutConstraint.activate([
            media.topAnchor.constraint(equalTo: v.topAnchor), media.leadingAnchor.constraint(equalTo: v.leadingAnchor),
            media.trailingAnchor.constraint(equalTo: v.trailingAnchor), media.heightAnchor.constraint(equalTo: media.widthAnchor, multiplier: 9.0 / 16.0),
            stack.topAnchor.constraint(equalTo: media.bottomAnchor, constant: 12), stack.leadingAnchor.constraint(equalTo: v.leadingAnchor, constant: 14),
            stack.trailingAnchor.constraint(lessThanOrEqualTo: v.trailingAnchor, constant: -14),
        ])
        v.mediaView = media; v.headlineView = head; v.bodyView = body; v.callToActionView = cta
        return v
    }
    func updateUIView(_ v: GADNativeAdView, context: Context) {
        (v.headlineView as? UILabel)?.text = ad.headline
        (v.bodyView as? UILabel)?.text = ad.body
        (v.callToActionView as? UIButton)?.setTitle(ad.callToAction ?? "Περισσότερα", for: .normal)
        v.mediaView?.mediaContent = ad.mediaContent
        v.nativeAd = ad
    }
}

/// Χορηγός σε πλήρη οθόνη: splash (3″, «Παράλειψη») ή fullscreen ανάμεσα σε άρθρα (Χ μετά από 3″)
struct SponsorOverlay: View {
    let s: Ads.SponsorShow
    @State private var left = 3
    var body: some View {
        ZStack(alignment: .topTrailing) {
            Color.black.ignoresSafeArea()
            Button { Ads.shared.click(s.c) } label: {
                Color.clear.overlay(NetImage(url: s.c.image, w: 1400, mode: s.splash ? .fill : .fit)).clipped().ignoresSafeArea()
            }.buttonStyle(.plain)
            HStack(spacing: 8) {
                Text(s.splash ? "ΧΟΡΗΓΟΣ" : "ΧΟΡΗΓΟΥΜΕΝΟ").font(F.body(10, .heavy)).tracking(1).foregroundStyle(.white)
                    .padding(.horizontal, 8).padding(.vertical, 4).background(RoundedRectangle(cornerRadius: 6).fill(.black.opacity(0.55)))
                if s.splash || left == 0 {
                    Button { Ads.shared.overlay = nil } label: {
                        Group {
                            if s.splash { Text("Παράλειψη" + (left > 0 ? " · \(left)" : "")).font(F.body(13, .heavy)) }
                            else { Image(systemName: "xmark").font(.system(size: 16, weight: .bold)) }
                        }
                        .foregroundStyle(.white).padding(.horizontal, 14).padding(.vertical, 9)
                        .background(Capsule().fill(.black.opacity(0.6)))
                    }.buttonStyle(.plain)
                } else {
                    Text("\(left)").font(F.disp(16)).foregroundStyle(.white).frame(width: 36, height: 36).background(Circle().fill(.black.opacity(0.6)))
                }
            }
            .padding(14)
        }
        .task {
            Ads.shared.track(s.c, "i")
            while left > 0 { try? await Task.sleep(nanoseconds: 1_000_000_000); left -= 1 }
            if s.splash { Ads.shared.overlay = nil }
        }
    }
}
