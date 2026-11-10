import SwiftUI
import UIKit
import FirebaseMessaging

/// Συντομεύσεις εικονιδίου (παρατεταμένο πάτημα) + έναρξη ειδοποιήσεων/παρασκηνίου
@MainActor
final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        Notifier.shared.setup()
        Push.shared.setup()
        LiveActivities.shared.observe() // tokens των Live Activities (και όσων άνοιξαν με push) → server
        return true
    }
    /// Push: το token της Apple → Firebase (ρητά, εκτός από το swizzling του Firebase)
    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        Messaging.messaging().apnsToken = deviceToken
    }
    func application(_ application: UIApplication, configurationForConnecting s: UISceneSession, options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        if let item = options.shortcutItem { AppState.shared.shortcut(item.type) }
        let c = UISceneConfiguration(name: nil, sessionRole: s.role)
        c.delegateClass = SceneDelegate.self
        return c
    }
}

@MainActor
final class SceneDelegate: NSObject, UIWindowSceneDelegate {
    func windowScene(_ windowScene: UIWindowScene, performActionFor shortcutItem: UIApplicationShortcutItem, completionHandler: @escaping (Bool) -> Void) {
        AppState.shared.shortcut(shortcutItem.type)
        completionHandler(true)
    }
}

@main
struct AEKHubApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
    @StateObject private var app = AppState.shared
    @StateObject private var prefs = Prefs.shared
    init() { SplashPreload.start() } // το βίντεο ανοίγματος φορτώνει ήδη από τώρα
    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(app)
                .environmentObject(prefs)
                .preferredColorScheme(.dark)
                .tint(C.gold)
        }
    }
}

/// Ρυθμίσεις από το wp-admin (κατηγορίες, αθλήματα, social) + άνοιγμα οθονών από widgets/ειδοποιήσεις.
@MainActor
final class AppState: ObservableObject {
    static let shared = AppState()
    @Published var config: AppConfig?
    @Published var tab: Tab = .home
    /// Οθόνη που πρέπει να ανοίξει (από widget, ειδοποίηση, συντόμευση)
    @Published var deepLink: Route?
    /// Ξανά πάτημα στην καρτέλα που είσαι ήδη (στην αρχή της): Ειδήσεις → πάνω + ανανέωση, οι άλλες → πάνω
    var reselectTab: Tab = .home
    @Published var reselectN = 0
    /// Κάθε φορά που η εφαρμογή ξαναβγαίνει μπροστά → οι οθόνες φέρνουν φρέσκα δεδομένα
    @Published var activeN = 0

    init() {
        if let j = Api.shared.peek(Api.pConfig) { config = AppConfig(j) }
        Task { await load() }
    }
    func load() async {
        if let c = try? await Api.shared.config() { config = c; Push.shared.sync() } // κατηγορίες → topics ειδήσεων
    }

    /// aekhub://match/123 · aekhub://post/123 · aekhub://event/123 · aekhub://matches · aekhub://standings
    func open(_ url: URL) {
        guard url.scheme == "aekhub" else { return }
        let id = Int(url.lastPathComponent) ?? 0
        switch url.host ?? "" {
        case "match" where id > 0: tab = .matches; deepLink = .match(id)
        case "post" where id > 0: tab = .home; deepLink = .post(id, nil)
        case "event" where id > 0: tab = .home; deepLink = .event(id)
        case "matches": tab = .matches
        case "standings": tab = .standings
        case "news": tab = .home
        case "feed": tab = .home; deepLink = .feed
        case "category": tab = .home; deepLink = .category(url.lastPathComponent, config?.categories.first { $0.slug == url.lastPathComponent }?.name ?? "")
        case "me": tab = .me
        case "notifs": tab = .me; deepLink = .notifs
        case "back": deepLink = nil
        default: break
        }
    }
    func shortcut(_ type: String) {
        switch type {
        case "matches": tab = .matches
        case "standings": tab = .standings
        case "search": tab = .home; deepLink = .search
        default: break
        }
    }
}

/// Οι οθόνες που ανοίγουν πάνω από τις καρτέλες
enum Route: Hashable {
    case post(Int, PostCard?)
    case match(Int)
    case event(Int)
    case category(String, String)
    case feed
    case search
    case saved
    case history
    case notifs
}

extension View {
    func withRoutes() -> some View {
        navigationDestination(for: Route.self) { r in
            switch r {
            case .post(let id, let card): ArticleView(id: id, card: card)
            case .match(let id): MatchView(id: id)
            case .event(let id): EventView(id: id)
            case .category(let slug, let name): FeedView(cat: slug, title: name, icon: AppState.shared.config?.categories.first { $0.slug == slug }?.icon ?? "eagle")
            case .feed: FeedView(cat: nil, title: "Ροή ειδήσεων")
            case .search: SearchView()
            case .saved: SavedView()
            case .history: SavedView(history: true)
            case .notifs: NotifSettingsView()
            }
        }
    }
}

enum Tab: Hashable, CaseIterable {
    case home, matches, standings, me
    var label: String { switch self { case .home: return "Ειδήσεις"; case .matches: return "Αγώνες"; case .standings: return "Βαθμ."; case .me: return "Εγώ" } }
    var long: String { switch self { case .home: return "Ειδήσεις"; case .matches: return "Αγώνες"; case .standings: return "Βαθμολογίες"; case .me: return "Εγώ" } }
    var icon: String { switch self { case .home: return "doc.text"; case .matches: return "soccerball"; case .standings: return "chart.bar"; case .me: return "person" } }
    var iconOn: String { switch self { case .home: return "doc.text.fill"; case .matches: return "soccerball.inverse"; case .standings: return "chart.bar.fill"; case .me: return "person.fill" } }
}

/// Το swipe «πίσω» να δουλεύει και στις οθόνες χωρίς μπάρα πλοήγησης (αγώνας, άρθρο)
extension UINavigationController: UIGestureRecognizerDelegate {
    override open func viewDidLoad() {
        super.viewDidLoad()
        interactivePopGestureRecognizer?.delegate = self
    }
    public func gestureRecognizerShouldBegin(_ g: UIGestureRecognizer) -> Bool { viewControllers.count > 1 }
}

struct RootView: View {
    @ObservedObject var app = AppState.shared
    @ObservedObject var prefs = Prefs.shared
    @Environment(\.scenePhase) var phase
    @Environment(\.horizontalSizeClass) var hsc
    @State private var paths: [Tab: NavigationPath] = [.home: NavigationPath(), .matches: NavigationPath(), .standings: NavigationPath(), .me: NavigationPath()]
    @State private var pinger: Task<Void, Never>?
    @State private var liveNow: MatchCard?
    /// iPad: πλαϊνή στήλη μαζεμένη/ανοιχτή με κουμπί (ζήτησε ο χρήστης) — χωριστά για στενή (κάθετο) και φαρδιά οθόνη
    @AppStorage("side_min") private var sideMin = false
    @AppStorage("side_wide_narrow") private var sideWideNarrow = false
    @State private var splash = !UserDefaults.standard.bool(forKey: "shots")
    @State private var onboard = false
    @ObservedObject private var ads = Ads.shared

    init() {
        let nb = UINavigationBarAppearance()
        nb.configureWithTransparentBackground()
        nb.backgroundColor = UIColor(C.ink).withAlphaComponent(0.92)
        nb.titleTextAttributes = [.foregroundColor: UIColor(C.text), .font: UIFont.systemFont(ofSize: 17, weight: .semibold)]
        nb.largeTitleTextAttributes = [.foregroundColor: UIColor(C.text), .font: UIFont(name: "SofiaSansExtraCondensed-Black", size: 40) ?? .boldSystemFont(ofSize: 34)]
        UINavigationBar.appearance().standardAppearance = nb
        UINavigationBar.appearance().scrollEdgeAppearance = nb
        UINavigationBar.appearance().compactAppearance = nb
        UINavigationBar.appearance().tintColor = UIColor(C.gold)
    }

    func binding(_ t: Tab) -> Binding<NavigationPath> {
        Binding(get: { paths[t] ?? NavigationPath() }, set: { paths[t] = $0 })
    }

    @ViewBuilder func root(_ t: Tab) -> some View {
        switch t {
        case .home: HomeView()
        case .matches: MatchesView()
        case .standings: StandingsView()
        case .me: MeView()
        }
    }

    func stack(_ t: Tab, bar: Bool) -> some View {
        NavigationStack(path: binding(t)) {
            root(t)
                .toolbar(.hidden, for: .navigationBar)
                .safeAreaInset(edge: .bottom) { if bar { Color.clear.frame(height: 80) } }
                .withRoutes()
        }
    }

    var isPad: Bool { hsc == .regular }

    var body: some View {
        Group {
            if isPad {
                GeometryReader { g in
                    HStack(spacing: 0) {
                        let narrow = g.size.width < 1000
                        Sidebar(tab: tabBinding, live: liveNow, compact: narrow ? !sideWideNarrow : sideMin) {
                            withAnimation(.easeOut(duration: 0.22)) { if narrow { sideWideNarrow.toggle() } else { sideMin.toggle() } }
                        }
                        ZStack { ForEach(Tab.allCases, id: \.self) { t in stack(t, bar: false).opacity(app.tab == t ? 1 : 0).allowsHitTesting(app.tab == t) } }
                    }
                }
            } else {
                ZStack(alignment: .bottom) {
                    ForEach(Tab.allCases, id: \.self) { t in stack(t, bar: true).opacity(app.tab == t ? 1 : 0).allowsHitTesting(app.tab == t) }
                    if (paths[app.tab]?.count ?? 0) == 0 {
                        FloatingTabBar(tab: tabBinding)
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                }
                .animation(.easeOut(duration: 0.2), value: paths[app.tab]?.count ?? 0)
            }
        }
        .background(C.ink.ignoresSafeArea())
        .onOpenURL { app.open($0) }
        .onAppear {
            // για τα screenshots του CI: -open matches / match/123
            if let o = UserDefaults.standard.string(forKey: "open"), let u = URL(string: "aekhub://" + o) {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { app.open(u) }
            }
        }
        .onChange(of: app.deepLink) { r in
            guard let r else { return }
            go(r)
            app.deepLink = nil
        }
        .onChange(of: phase) { p in
            if p == .active {
                app.activeN += 1
                Analytics.ping()
                pinger?.cancel()
                pinger = Task { while !Task.isCancelled { try? await Task.sleep(nanoseconds: 60_000_000_000); Analytics.ping() } }
                Task { await Notifier.shared.refresh(force: true) }
            } else if p == .background {
                pinger?.cancel(); pinger = nil
                Analytics.ping(leave: true)
                Notifier.shared.scheduleBG()
            }
        }
        .task {
            // «LIVE ΤΩΡΑ» στην πλαϊνή στήλη του iPad
            while !Task.isCancelled {
                if let l = try? await Api.shared.matches() {
                    liveNow = l.items.first { $0.live && !$0.aek.isEmpty } ?? l.items.first { $0.live }
                    Ads.shared.aekLive = l.items.contains { $0.live && !$0.aek.isEmpty }
                }
                try? await Task.sleep(nanoseconds: 30_000_000_000)
            }
        }
        .overlay {
            if let o = ads.overlay { SponsorOverlay(s: o).id(o.id).transition(.opacity).zIndex(2) }
        }
        .overlay {
            if splash {
                IntroSplash {
                    splash = false
                    if !prefs.introDone {
                        prefs.introDone = true
                        // νέος χρήστης: άδεια ειδοποιήσεων → αν τη δώσει, «Τι θέλεις να μαθαίνεις;» → μετά διαφημίσεις/συγκατάθεση
                        Task {
                            if await Notifier.shared.requestPermission() { onboard = true } else { ads.start() }
                        }
                    } else {
                        ads.start()
                        ads.maybeSplash()
                    }
                }
                .transition(.opacity)
            }
        }
        .fullScreenCover(isPresented: $onboard) {
            OnboardView { onboard = false; Push.shared.sync(); LiveActivities.shared.syncStart(); DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { ads.start() } }
        }
        .animation(.easeOut(duration: 0.25), value: ads.overlay)
        .onAppear { if !splash { ads.start() } }
    }

    func go(_ r: Route) {
        var p = paths[app.tab] ?? NavigationPath()
        p.append(r)
        paths[app.tab] = p
    }

    /// Ξανά πάτημα στην ίδια καρτέλα → επιστροφή στην αρχή της
    private var tabBinding: Binding<Tab> {
        Binding(get: { app.tab }, set: { t in
            if t == app.tab {
                if (paths[t]?.count ?? 0) == 0 { app.reselectTab = t; app.reselectN += 1 }
                paths[t] = NavigationPath()
            }
            app.tab = t
        })
    }
}

/// Κάψουλα καρτελών που «αιωρείται», στο κέντρο (μόνο οι 4 καρτέλες).
/// 💧 Υγρό γυαλί (ζήτησε ο χρήστης, όπως το iOS 26): κρατάς το δάχτυλο και σέρνεις → η γυάλινη «φούσκα» μεγαλώνει,
/// ακολουθεί το δάχτυλο και ανάβει η καρτέλα από κάτω· αφήνεις → αλλάζει καρτέλα. Απλό πάτημα δουλεύει όπως πριν.
struct FloatingTabBar: View {
    @Binding var tab: Tab
    @State private var dragX: CGFloat?
    @State private var hover: Int?
    private let tabs = Tab.allCases
    private let pad: CGFloat = 6, h: CGFloat = 62

    var body: some View {
        GeometryReader { g in
            let w = (g.size.width - pad * 2) / CGFloat(tabs.count)
            let sel = CGFloat(tabs.firstIndex(of: tab) ?? 0)
            let active = hover ?? Int(sel)
            let pressed = dragX != nil
            let x = dragX.map { min(max($0 - w / 2, pad), g.size.width - pad - w) } ?? (pad + sel * w)
            ZStack(alignment: .leading) {
                // η «φούσκα»: γυαλί που μεγαλώνει όσο κρατάς το δάχτυλο
                Capsule()
                    .fill(Color.white.opacity(pressed ? 0.16 : 0.12))
                    .overlay(Capsule().strokeBorder(LinearGradient(colors: [.white.opacity(pressed ? 0.55 : 0.18), .white.opacity(0.04)], startPoint: .top, endPoint: .bottom), lineWidth: 1))
                    .frame(width: w, height: h)
                    .scaleEffect(pressed ? 1.14 : 1)
                    .shadow(color: .black.opacity(pressed ? 0.35 : 0), radius: 10, y: 4)
                    .offset(x: x)
                HStack(spacing: 0) {
                    ForEach(Array(tabs.enumerated()), id: \.offset) { i, t in
                        let on = i == active
                        VStack(spacing: 4) {
                            Image(systemName: on ? t.iconOn : t.icon).font(.system(size: 22, weight: .medium))
                                .symbolRenderingMode(.monochrome)
                            Text(t.label).font(.system(size: 11.5, weight: on ? .bold : .medium))
                        }
                        .foregroundStyle(on ? C.gold : C.text)
                        .scaleEffect(on && pressed ? 1.08 : 1)
                        .frame(width: w, height: h)
                    }
                }
                .padding(.horizontal, pad)
            }
            .frame(height: h + pad * 2)
            .contentShape(Capsule())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { v in
                        let i = min(tabs.count - 1, max(0, Int((v.location.x - pad) / w)))
                        if dragX == nil { haptic(.soft) } else if i != hover { UISelectionFeedbackGenerator().selectionChanged() }
                        withAnimation(.interactiveSpring(response: 0.28, dampingFraction: 0.72)) { dragX = v.location.x; hover = i }
                    }
                    .onEnded { _ in
                        let t = tabs[hover ?? Int(sel)]
                        withAnimation(.spring(response: 0.38, dampingFraction: 0.74)) { dragX = nil; hover = nil; tab = t }
                    }
            )
        }
        .frame(height: h + pad * 2)
        .frame(maxWidth: 380)
        .glass(Capsule())
        .shadow(color: .black.opacity(0.35), radius: 18, y: 6)
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 22).padding(.bottom, 2)
    }
}

/// iPad: πλαϊνή στήλη τύπου Apple News — καρτέλες, κατηγορίες, αποθηκευμένα, αναζήτηση, «LIVE ΤΩΡΑ».
/// Σε κάθετο iPad γίνεται στενή στήλη με εικονίδια.
struct Sidebar: View {
    @Binding var tab: Tab
    let live: MatchCard?
    var compact = false
    var toggle: (() -> Void)? = nil
    @ObservedObject var app = AppState.shared
    var body: some View {
        VStack(alignment: compact ? .center : .leading, spacing: 4) {
            Group {
                if compact {
                    VStack(spacing: 10) {
                        Image("Eagle").resizable().scaledToFit().frame(width: 34, height: 34)
                        collapseButton
                    }.padding(.top, 22).padding(.bottom, 14)
                } else {
                    HStack(spacing: 8) {
                        LogoTitle(h: 36)
                        Spacer(minLength: 0)
                        collapseButton
                    }.padding(.horizontal, 14).padding(.top, 26).padding(.bottom, 18)
                }
            }
            ForEach(Tab.allCases, id: \.self) { t in
                item(t.long, t == tab ? t.iconOn : t.icon, on: t == tab) { tab = t }
            }
            item("Αναζήτηση", "magnifyingglass", on: false) { app.tab = .home; app.deepLink = .search }
            item("Αποθηκευμένα", "bookmark", on: false) { app.tab = .home; app.deepLink = .saved }
            if !compact, let cats = app.config?.categories, !cats.isEmpty {
                Text("ΚΑΤΗΓΟΡΙΕΣ").font(F.body(11, .heavy)).tracking(1).foregroundStyle(C.muted).padding(.horizontal, 16).padding(.top, 18).padding(.bottom, 4)
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 2) {
                        ForEach(cats, id: \.slug) { c in
                            Button { app.tab = .home; app.deepLink = .category(c.slug, c.name) } label: {
                                HStack(spacing: 12) {
                                    Image(catIcon(c.icon)).resizable().scaledToFit().frame(width: 24, height: 24)
                                    Text(c.name).font(F.body(15, .medium)).foregroundStyle(C.text2).lineLimit(1)
                                    Spacer()
                                }
                                .padding(.horizontal, 16).frame(height: 40).contentShape(Rectangle())
                            }.buttonStyle(.plain)
                        }
                    }
                }
            }
            Spacer(minLength: 8)
            if let m = live {
                Button { app.tab = .matches; app.deepLink = .match(m.id) } label: {
                    if compact {
                        VStack(spacing: 4) {
                            LiveDot(size: 8)
                            Text("\(m.scoreHome)–\(m.scoreAway)").font(F.disp(18)).foregroundStyle(C.text)
                        }.padding(.vertical, 10).frame(maxWidth: .infinity).card(16, fill: C.ink)
                    } else {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack(spacing: 6) { LiveDot(size: 7); Text("LIVE ΤΩΡΑ · " + liveText(m)).font(F.tag(11)).tracking(0.6).foregroundStyle(C.live) }
                            HStack(spacing: 8) {
                                TeamLogo(url: m.homeLogo, size: 26, name: m.home)
                                Text("\(m.scoreHome) – \(m.scoreAway)").font(F.disp(26)).foregroundStyle(C.text).frame(maxWidth: .infinity)
                                TeamLogo(url: m.awayLogo, size: 26, name: m.away)
                            }
                            Text("\(m.home) – \(m.away)").font(F.body(12, .bold)).foregroundStyle(C.text2).lineLimit(1)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading).padding(14).card(18, fill: C.ink)
                    }
                }.buttonStyle(.plain)
            }
        }
        .padding(compact ? 8 : 12)
        .frame(width: compact ? 84 : 270)
        .frame(maxHeight: .infinity)
        .glass(RoundedRectangle(cornerRadius: 30, style: .continuous))
        .padding(12)
    }

    /// Σύμπτυξη / άνοιγμα της στήλης (μεγαλώνει ό,τι είναι δεξιά)
    @ViewBuilder var collapseButton: some View {
        if let toggle {
            Button { haptic(.soft); toggle() } label: {
                Image(systemName: compact ? "sidebar.left" : "chevron.left.2").font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(C.text2).frame(width: 34, height: 34)
                    .background(Circle().fill(Color.white.opacity(0.08)))
            }
            .buttonStyle(.plain)
            .accessibilityLabel(compact ? "Άνοιγμα μενού" : "Σύμπτυξη μενού")
        }
    }

    func item(_ title: String, _ icon: String, on: Bool, _ action: @escaping () -> Void) -> some View {
        Button { haptic(.soft); action() } label: {
            Group {
                if compact {
                    VStack(spacing: 3) {
                        Image(systemName: icon).font(.system(size: 20))
                        Text(title).font(.system(size: 9.5, weight: on ? .bold : .medium)).lineLimit(1).minimumScaleFactor(0.7)
                    }
                    .frame(width: 66, height: 56)
                } else {
                    HStack(spacing: 14) {
                        Image(systemName: icon).font(.system(size: 18)).frame(width: 26)
                        Text(title).font(F.body(16, on ? .bold : .medium))
                        Spacer()
                    }
                    .padding(.horizontal, 16).frame(height: 46)
                }
            }
            .foregroundStyle(on ? C.gold : C.text)
            .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(on ? Color.white.opacity(0.1) : .clear))
            .contentShape(Rectangle())
        }.buttonStyle(.plain)
    }
}
