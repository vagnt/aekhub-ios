import SwiftUI
import UIKit

/// Συντομεύσεις εικονιδίου (παρατεταμένο πάτημα) + έναρξη ειδοποιήσεων/παρασκηνίου
@MainActor
final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        Notifier.shared.setup()
        return true
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

    init() {
        if let j = Api.shared.peek(Api.pConfig) { config = AppConfig(j) }
        Task { await load() }
    }
    func load() async {
        if let c = try? await Api.shared.config() { config = c }
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
}

extension View {
    func withRoutes() -> some View {
        navigationDestination(for: Route.self) { r in
            switch r {
            case .post(let id, let card): ArticleView(id: id, card: card)
            case .match(let id): MatchView(id: id)
            case .event(let id): EventView(id: id)
            case .category(let slug, let name): FeedView(cat: slug, title: name)
            case .feed: FeedView(cat: nil, title: "Ροή ειδήσεων")
            case .search: SearchView()
            case .saved: SavedView()
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
    @EnvironmentObject var app: AppState
    @EnvironmentObject var prefs: Prefs
    @Environment(\.scenePhase) var phase
    @Environment(\.horizontalSizeClass) var hsc
    @State private var paths: [Tab: NavigationPath] = [.home: NavigationPath(), .matches: NavigationPath(), .standings: NavigationPath(), .me: NavigationPath()]
    @State private var pinger: Task<Void, Never>?
    @State private var liveNow: MatchCard?

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
                .safeAreaInset(edge: .bottom) { if bar { Color.clear.frame(height: 78) } }
                .withRoutes()
        }
    }

    var isPad: Bool { hsc == .regular }

    var body: some View {
        Group {
            if isPad {
                HStack(spacing: 0) {
                    Sidebar(tab: tabBinding, live: liveNow)
                    ZStack { ForEach(Tab.allCases, id: \.self) { t in stack(t, bar: false).opacity(app.tab == t ? 1 : 0).allowsHitTesting(app.tab == t) } }
                }
            } else {
                ZStack(alignment: .bottom) {
                    ForEach(Tab.allCases, id: \.self) { t in stack(t, bar: true).opacity(app.tab == t ? 1 : 0).allowsHitTesting(app.tab == t) }
                    if (paths[app.tab]?.count ?? 0) == 0 {
                        FloatingTabBar(tab: tabBinding) { go(.search) }
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                }
                .animation(.easeOut(duration: 0.2), value: paths[app.tab]?.count ?? 0)
            }
        }
        .background(C.ink.ignoresSafeArea())
        .onOpenURL { app.open($0) }
        .onChange(of: app.deepLink) { r in
            guard let r else { return }
            go(r)
            app.deepLink = nil
        }
        .onChange(of: phase) { p in
            if p == .active {
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
                if let l = try? await Api.shared.matches() { liveNow = l.items.first { $0.live } }
                try? await Task.sleep(nanoseconds: 30_000_000_000)
            }
        }
        .fullScreenCover(isPresented: Binding(get: { !prefs.introDone }, set: { _ in })) {
            IntroView { prefs.introDone = true }
        }
    }

    func go(_ r: Route) {
        var p = paths[app.tab] ?? NavigationPath()
        p.append(r)
        paths[app.tab] = p
    }

    /// Ξανά πάτημα στην ίδια καρτέλα → επιστροφή στην αρχή της
    private var tabBinding: Binding<Tab> {
        Binding(get: { app.tab }, set: { t in
            if t == app.tab { paths[t] = NavigationPath() }
            app.tab = t
        })
    }
}

/// Κάψουλα καρτελών που «αιωρείται» (ύψος 66) + ξεχωριστό γυάλινο κουμπί αναζήτησης
struct FloatingTabBar: View {
    @Binding var tab: Tab
    var search: () -> Void
    var body: some View {
        HStack(spacing: 10) {
            HStack(spacing: 2) {
                ForEach(Tab.allCases, id: \.self) { t in
                    let on = t == tab
                    Button { tab = t } label: {
                        VStack(spacing: 3) {
                            Image(systemName: on ? t.iconOn : t.icon).font(.system(size: 19, weight: .medium))
                                .symbolRenderingMode(.monochrome)
                            Text(t.label).font(.system(size: 11, weight: on ? .bold : .medium))
                        }
                        .foregroundStyle(on ? C.gold : C.text)
                        .frame(maxWidth: .infinity).frame(height: 56)
                        .background(Capsule().fill(on ? Color.white.opacity(0.12) : .clear))
                        .contentShape(Capsule())
                    }.buttonStyle(.plain)
                }
            }
            .padding(5)
            .glass(Capsule())
            GlassCircle(icon: "magnifyingglass", size: 66, action: search)
        }
        .padding(.horizontal, 16).padding(.bottom, 4)
    }
}

/// iPad: πλαϊνή στήλη (λογότυπο, καρτέλες, «LIVE ΤΩΡΑ»)
struct Sidebar: View {
    @Binding var tab: Tab
    let live: MatchCard?
    @EnvironmentObject var app: AppState
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            LogoTitle(h: 38).padding(.horizontal, 14).padding(.top, 30).padding(.bottom, 26)
            ForEach(Tab.allCases, id: \.self) { t in
                let on = t == tab
                Button { tab = t } label: {
                    HStack(spacing: 14) {
                        Image(systemName: on ? t.iconOn : t.icon).font(.system(size: 19)).frame(width: 26)
                        Text(t.long).font(F.body(17, on ? .semibold : .regular))
                        Spacer()
                    }
                    .foregroundStyle(on ? C.gold : C.text)
                    .padding(.horizontal, 16).frame(height: 50)
                    .background(Capsule().fill(on ? Color.white.opacity(0.1) : .clear))
                    .contentShape(Capsule())
                }.buttonStyle(.plain)
            }
            Spacer()
            if let m = live {
                Button { app.tab = .matches; app.deepLink = .match(m.id) } label: {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("LIVE ΤΩΡΑ").font(F.tag(11)).tracking(1).foregroundStyle(C.gold)
                        Text("\(m.home) \(m.scoreHome)–\(m.scoreAway) \(m.away) · \(liveText(m))").font(F.body(14, .semibold)).foregroundStyle(C.text).lineLimit(2)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading).padding(14).card(18, fill: C.ink)
                }.buttonStyle(.plain)
            }
        }
        .padding(12)
        .frame(width: 260)
        .glass(RoundedRectangle(cornerRadius: 30, style: .continuous))
        .padding(12)
    }
}
