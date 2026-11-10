import SwiftUI
import AVFoundation

/// Αποθηκευμένα άρθρα ή ιστορικό ανάγνωσης
struct SavedView: View {
    var history = false
    @ObservedObject var p = Prefs.shared
    @Environment(\.dismiss) var dismiss
    var list: [PostCard] { history ? p.history : p.saved }
    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                Button { dismiss() } label: { Image(systemName: "chevron.left").font(.system(size: 19, weight: .semibold)).foregroundStyle(C.text).frame(width: 44, height: 44) }
                ScreenTitle(text: history ? "Διάβασες πρόσφατα" : "Αποθηκευμένα")
                Spacer()
                if history && !p.history.isEmpty {
                    Button { p.history = [] } label: { Text("Καθάρισμα").font(F.body(14, .heavy)).foregroundStyle(C.gold) }.buttonStyle(.plain)
                }
            }
            .padding(.leading, 4).padding(.trailing, 16).padding(.vertical, 6)
            ScrollView {
                if list.isEmpty {
                    EmptyState(icon: history ? "clock" : "bookmark", text: history ? "Τα άρθρα που διαβάζεις θα εμφανίζονται εδώ." : "Δεν έχεις αποθηκεύσει άρθρα.\nΠάτα 🔖 πάνω σε ένα άρθρο για να το κρατήσεις εδώ.")
                }
                LazyVGrid(columns: adaptiveCols, spacing: 0) {
                    ForEach(list) { a in
                        PostRow(p: a).contextMenu {
                            if !history { Button(role: .destructive) { p.toggleSaved(a) } label: { Label("Αφαίρεση", systemImage: "trash") } }
                        }
                    }
                }
                .padding(.horizontal, 16)
            }
        }
        .background(C.ink)
        .toolbar(.hidden, for: .navigationBar)
    }
}

/// Άνοιγμα της εφαρμογής (10/11/2026, ζήτησε ο χρήστης): το βίντεο του AEK Hub σε όλη την οθόνη
/// (κινητό · iPad κάθετο · iPad οριζόντιο) με δονήσεις ΣΥΓΧΡΟΝΙΣΜΕΝΕΣ με το βίντεο:
/// «σκάει» ο κύκλος hub → γίνεται κουτί → πέφτουν a, e → το K (δυνατό) → το σύνθημα. Πάτημα = προσπέραση.
struct IntroSplash: View {
    var done: () -> Void
    @State private var out = 0.0
    @State private var ended = false

    var body: some View {
        GeometryReader { g in
            ZStack {
                Color.black.ignoresSafeArea()
                if let url = Self.video(g.size) {
                    SplashPlayer(player: SplashPreload.take(url), beats: Self.beats) { finish() }.ignoresSafeArea()
                }
            }
            .opacity(1 - out)
            .contentShape(Rectangle())
            .onTapGesture { finish() }
            .onAppear { if Self.video(g.size) == nil { finish() } }
        }
        .ignoresSafeArea()
    }

    /// 5″ (ολόκληρο) στο πρώτο άνοιγμα της μέρας και μετά από εγκατάσταση/ενημέρωση· 3″ σε όλα τα άλλα.
    /// Υπολογίζεται μία φορά ανά εκκίνηση (η επιστροφή από το παρασκήνιο δεν ξαναπαίζει βίντεο).
    static let long: Bool = {
        let d = UserDefaults.standard
        let day = { let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"; return f.string(from: Date()) }()
        let ver = (Bundle.main.infoDictionary?["CFBundleVersion"] as? String) ?? ""
        let l = d.string(forKey: "splash_day") != day || d.string(forKey: "splash_ver") != ver
        d.set(day, forKey: "splash_day"); d.set(ver, forKey: "splash_ver")
        return l
    }()

    typealias Beat = (Double, UIImpactFeedbackGenerator.FeedbackStyle, CGFloat)
    static var beats: [Beat] { long ? beats5 : beats3 }

    /// Στιγμές (δευτερόλεπτα του βίντεο) και ένταση της δόνησης — 5″
    static let beats5: [Beat] = [
        (0.65, .light, 0.6),   // εμφανίζεται ο κύκλος hub
        (1.10, .medium, 1.0),  // ο κύκλος «σκάει» (κύμα)
        (1.50, .light, 0.8),   // γίνεται το κουτί
        (2.30, .rigid, 0.9),   // πέφτει το a
        (2.60, .rigid, 0.9),   // το e
        (2.90, .heavy, 1.0),   // το K
        (3.30, .soft, 0.6),    // «Όλη η ΑΕΚ, σε ένα σημείο!»
    ]
    /// — 3″ (ίδια σειρά, πιο γρήγορα)
    static let beats3: [Beat] = [
        (0.30, .light, 0.6),
        (0.67, .medium, 1.0),
        (0.90, .light, 0.8),
        (1.40, .rigid, 0.9),
        (1.60, .rigid, 0.9),
        (1.80, .heavy, 1.0),
        (2.10, .soft, 0.6),
    ]

    /// Από πού ξεκινά το βίντεο: τα πρώτα κλάσματα είναι σχεδόν μαύρα (ο δικέφαλος «ανάβει») και μαζί
    /// με την οθόνη εκκίνησης φαίνονταν σαν μαύρο κενό (ο χρήστης, 10/11) → ξεκινάμε μόλις φαίνεται κάτι.
    static var startAt: Double { long ? 0.25 : 0.15 }

    static func video(_ size: CGSize) -> URL? {
        let pad = UIDevice.current.userInterfaceIdiom == .pad
        let name = (!pad ? "splash_phone" : (size.width > size.height ? "splash_tab_l" : "splash_tab_p")) + (long ? "" : "_s")
        return Bundle.main.url(forResource: name, withExtension: "mp4")
    }

    func finish() {
        guard !ended else { return }
        ended = true
        withAnimation(.easeInOut(duration: 0.35)) { out = 1 }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.36) { done() }
    }
}

/// Το βίντεο φορτώνεται μόλις ξεκινήσει η εφαρμογή (πριν σχεδιαστεί η οθόνη), ώστε να είναι έτοιμο
/// τη στιγμή που φεύγει η οθόνη εκκίνησης — χωρίς μαύρο κενό.
enum SplashPreload {
    private static var url: URL?
    private static var player: AVPlayer?

    static func start() {
        guard !UserDefaults.standard.bool(forKey: "shots"), player == nil,
              let u = IntroSplash.video(UIScreen.main.bounds.size) else { return }
        url = u; player = make(u)
    }

    /// Ο έτοιμος player αν ταιριάζει (π.χ. το iPad δεν γύρισε στο μεταξύ), αλλιώς καινούργιος
    static func take(_ u: URL) -> AVPlayer {
        defer { player = nil; url = nil }
        if let p = player, url == u { return p }
        return make(u)
    }

    private static func make(_ u: URL) -> AVPlayer {
        // να μη σταματά η μουσική/το podcast του χρήστη στο άνοιγμα
        try? AVAudioSession.sharedInstance().setCategory(.ambient, options: [.mixWithOthers])
        let p = AVPlayer(playerItem: AVPlayerItem(url: u))
        p.isMuted = true
        p.automaticallyWaitsToMinimizeStalling = false
        p.preventsDisplaySleepDuringVideoPlayback = false
        p.seek(to: CMTime(seconds: IntroSplash.startAt, preferredTimescale: 600), toleranceBefore: .zero, toleranceAfter: .zero)
        return p
    }
}

/// AVPlayer χωρίς ήχο (δεν σταματά τη μουσική του χρήστη), γεμίζει την οθόνη, δονήσεις στις ακριβείς στιγμές του βίντεο
struct SplashPlayer: UIViewRepresentable {
    let player: AVPlayer
    let beats: [IntroSplash.Beat]
    var end: () -> Void

    final class PView: UIView {
        override class var layerClass: AnyClass { AVPlayerLayer.self }
        var pl: AVPlayerLayer { layer as! AVPlayerLayer }
        var obs: [Any] = []
        var timeObs: [Any] = []
        var ready: NSKeyValueObservation?
        var started = false
        func go() { guard !started else { return }; started = true; pl.player?.play() }
        deinit {
            ready?.invalidate()
            for o in obs { NotificationCenter.default.removeObserver(o) }
            for o in timeObs { pl.player?.removeTimeObserver(o) }
        }
    }

    func makeUIView(context: Context) -> PView {
        let v = PView()
        v.backgroundColor = .black
        let p = player
        v.pl.player = p
        v.pl.videoGravity = .resizeAspectFill
        // δονήσεις συγχρονισμένες με το βίντεο (όχι με χρονόμετρο: αν αργήσει το βίντεο, αργούν κι αυτές)
        for b in beats where b.0 > IntroSplash.startAt {
            let gen = UIImpactFeedbackGenerator(style: b.1); gen.prepare()
            let t = NSValue(time: CMTime(seconds: b.0, preferredTimescale: 600))
            v.timeObs.append(p.addBoundaryTimeObserver(forTimes: [t], queue: .main) { gen.impactOccurred(intensity: b.2) })
        }
        if let item = p.currentItem {
            v.obs.append(NotificationCenter.default.addObserver(forName: .AVPlayerItemDidPlayToEndTime, object: item, queue: .main) { _ in end() })
            v.obs.append(NotificationCenter.default.addObserver(forName: .AVPlayerItemFailedToPlayToEndTime, object: item, queue: .main) { _ in end() })
        }
        // παίζει ΜΟΛΙΣ το πρώτο καρέ είναι στην οθόνη (αλλιώς «έτρεχε» κρυφά πίσω από μαύρο και χανόταν η αρχή)
        v.ready = v.pl.observe(\.isReadyForDisplay, options: [.initial, .new]) { [weak v] l, _ in
            if l.isReadyForDisplay { DispatchQueue.main.async { v?.go() } }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak v] in v?.go() } // ασφάλεια
        return v
    }

    func updateUIView(_ v: PView, context: Context) {}
    static func dismantleUIView(_ v: PView, coordinator: ()) {
        v.pl.player?.pause()
        try? AVAudioSession.sharedInstance().setCategory(.soloAmbient) // η προεπιλογή του iOS (για τα βίντεο της εφαρμογής)
    }
}
