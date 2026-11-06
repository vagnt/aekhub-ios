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
    case notifs
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
            case .notifs: NotifSettingsView()
            case .saved: SavedView()
            }
        }
    }
}

enum Tab: Hashable { case home, matches, standings, me }

struct RootView: View {
    @EnvironmentObject var app: AppState
    @EnvironmentObject var prefs: Prefs
    @Environment(\.scenePhase) var phase
    @State private var homePath = NavigationPath()
    @State private var matchesPath = NavigationPath()
    @State private var standingsPath = NavigationPath()
    @State private var mePath = NavigationPath()
    @State private var pinger: Task<Void, Never>?

    init() {
        // Σκούρες μπάρες (καρτέλες & πλοήγηση), όπως στο Android
        let tb = UITabBarAppearance()
        tb.configureWithOpaqueBackground()
        tb.backgroundColor = UIColor(C.ink2)
        UITabBar.appearance().standardAppearance = tb
        UITabBar.appearance().scrollEdgeAppearance = tb
        let nb = UINavigationBarAppearance()
        nb.configureWithOpaqueBackground()
        nb.backgroundColor = UIColor(C.ink)
        nb.shadowColor = .clear
        nb.titleTextAttributes = [.foregroundColor: UIColor(C.text), .font: UIFont(name: "ManropeExtraLight-ExtraBold", size: 16) ?? .boldSystemFont(ofSize: 16)]
        nb.largeTitleTextAttributes = [.foregroundColor: UIColor(C.text), .font: UIFont(name: "SofiaSansExtraCondensed-Black", size: 34) ?? .boldSystemFont(ofSize: 34)]
        UINavigationBar.appearance().standardAppearance = nb
        UINavigationBar.appearance().scrollEdgeAppearance = nb
        UINavigationBar.appearance().compactAppearance = nb
    }

    var body: some View {
        TabView(selection: tabBinding) {
            NavigationStack(path: $homePath) { HomeView().withRoutes() }
                .tabItem { Label("Ειδήσεις", systemImage: "newspaper") }.tag(Tab.home)
            NavigationStack(path: $matchesPath) { MatchesView().withRoutes() }
                .tabItem { Label("Αγώνες", systemImage: "soccerball") }.tag(Tab.matches)
            NavigationStack(path: $standingsPath) { StandingsView().withRoutes() }
                .tabItem { Label("Βαθμολογίες", systemImage: "list.number") }.tag(Tab.standings)
            NavigationStack(path: $mePath) { MeView().withRoutes() }
                .tabItem { Label("Εγώ", systemImage: "person") }.tag(Tab.me)
        }
        .onOpenURL { app.open($0) }
        .onChange(of: app.deepLink) { r in
            guard let r else { return }
            switch app.tab {
            case .home: homePath.append(r)
            case .matches: matchesPath.append(r)
            case .standings: standingsPath.append(r)
            case .me: mePath.append(r)
            }
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
        .fullScreenCover(isPresented: Binding(get: { !prefs.introDone }, set: { _ in })) {
            IntroView { prefs.introDone = true }
        }
    }

    /// Ξανά πάτημα στην ίδια καρτέλα → επιστροφή στην αρχή της (όπως σε κάθε app iPhone)
    private var tabBinding: Binding<Tab> {
        Binding(get: { app.tab }, set: { t in
            if t == app.tab {
                switch t {
                case .home: homePath = NavigationPath()
                case .matches: matchesPath = NavigationPath()
                case .standings: standingsPath = NavigationPath()
                case .me: mePath = NavigationPath()
                }
            }
            app.tab = t
        })
    }
}
