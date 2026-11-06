import SwiftUI

@main
struct AEKHubApp: App {
    @StateObject private var app = AppState()
    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(app)
                .preferredColorScheme(.dark)
                .tint(C.gold)
        }
    }
}

/// Ρυθμίσεις από το wp-admin (κατηγορίες, αθλήματα, social) — μία φορά ανά άνοιγμα.
@MainActor
final class AppState: ObservableObject {
    @Published var config: AppConfig?
    init() {
        if let j = Api.shared.peek(Api.pConfig) { config = AppConfig(j) }
        Task { await load() }
    }
    func load() async {
        if let c = try? await Api.shared.config() { config = c }
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
            }
        }
    }
}

enum Tab: Hashable { case home, matches, standings, me }

struct RootView: View {
    @State private var tab: Tab = .home
    @State private var homePath = NavigationPath()
    @State private var matchesPath = NavigationPath()
    @State private var standingsPath = NavigationPath()
    @State private var mePath = NavigationPath()

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
    }

    /// Ξανά πάτημα στην ίδια καρτέλα → επιστροφή στην αρχή της (όπως σε κάθε app iPhone)
    private var tabBinding: Binding<Tab> {
        Binding(get: { tab }, set: { t in
            if t == tab {
                switch t {
                case .home: homePath = NavigationPath()
                case .matches: matchesPath = NavigationPath()
                case .standings: standingsPath = NavigationPath()
                case .me: mePath = NavigationPath()
                }
            }
            tab = t
        })
    }
}
