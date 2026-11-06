import SwiftUI

/// Ροή ειδήσεων (όλες ή μίας κατηγορίας), με σελίδες που φορτώνουν καθώς κατεβαίνεις.
struct FeedView: View {
    let cat: String?
    let title: String
    @EnvironmentObject var app: AppState
    @State private var selected: String = ""
    @State private var items: [PostCard] = []
    @State private var page = 0
    @State private var pages = 1
    @State private var loading = false
    @State private var error: String?

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                if cat == nil, let cats = app.config?.categories, !cats.isEmpty {
                    ChipRow(items: [("", "Όλα")] + cats.map { ($0.slug, $0.name) }, selected: selected) { k in
                        selected = k; Task { await reload() }
                    }.padding(.vertical, 10)
                }
                LazyVGrid(columns: adaptiveCols, spacing: 0) {
                    ForEach(items) { p in
                        PostRow(p: p).onAppear { if p.id == items.last?.id { Task { await more() } } }
                    }
                }
                if loading { ProgressView().tint(C.gold).frame(maxWidth: .infinity).padding(24) }
                else if let error, items.isEmpty { EmptyState(icon: "wifi.exclamationmark", text: error) { Task { await reload() } } }
            }.padding(.bottom, 20)
        }
        .background(C.ink)
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .refreshable { await reload() }
        .task {
            Analytics.screen(cat == nil ? 6 : 3, name: cat ?? "feed")
            if items.isEmpty { selected = cat ?? ""; await reload() }
        }
    }

    var key: String? { selected.isEmpty ? nil : selected }

    func reload() async {
        page = 0; pages = 1
        if let j = Api.shared.peek(Api.pFeed(key)) { items = Feed(j).items } else { items = [] }
        await more(reset: true)
    }

    func more(reset: Bool = false) async {
        guard !loading, page < pages else { return }
        loading = true; defer { loading = false }
        do {
            let f = try await Api.shared.feed(key, page: page + 1)
            var list = f.items
            if page == 0, let feat = f.featured, !list.contains(where: { $0.id == feat.id }) { list.insert(feat, at: 0) }
            if reset || page == 0 { items = list } else { items += list.filter { n in !items.contains { $0.id == n.id } } }
            page = f.page; pages = f.pages; error = nil
        } catch { self.error = "Δεν φόρτωσαν τα άρθρα.\n" + error.localizedDescription }
    }
}

struct SearchView: View {
    @State private var q = ""
    @State private var items: [PostCard] = []
    @State private var searching = false
    @State private var done = false

    var body: some View {
        ScrollView {
            LazyVGrid(columns: adaptiveCols, spacing: 0) { ForEach(items) { PostRow(p: $0) } }
            if searching { ProgressView().tint(C.gold).padding(30) }
            else if done && items.isEmpty { EmptyState(icon: "magnifyingglass", text: "Δεν βρέθηκαν άρθρα για «\(q)».") }
        }
        .background(C.ink)
        .navigationTitle("Αναζήτηση")
        .navigationBarTitleDisplayMode(.inline)
        .searchable(text: $q, placement: .navigationBarDrawer(displayMode: .always), prompt: "Ψάξε άρθρα…")
        .onSubmit(of: .search) { Task { await run() } }
    }

    func run() async {
        let s = q.trimmingCharacters(in: .whitespaces)
        guard s.count >= 2 else { return }
        searching = true; defer { searching = false; done = true }
        items = (try? await Api.shared.search(s).items) ?? []
    }
}
