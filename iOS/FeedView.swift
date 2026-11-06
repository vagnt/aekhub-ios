import SwiftUI

/// Ροή ειδήσεων / Κατηγορία (Android FeedScreen / CategoryScreen): κεφαλίδα με εικονίδιο, πρώτο άρθρο σε μεγάλη κάρτα
/// (κατηγορία), μετά γραμμές· «ΠΕΡΙΣΣΟΤΕΡΑ ΑΡΘΡΑ» αντί για ατελείωτο scroll. iPad: 2–3 στήλες.
struct FeedView: View {
    let cat: String?
    let title: String
    var icon: String = "eagle"
    @Environment(\.dismiss) var dismiss
    @Environment(\.horizontalSizeClass) var hsc
    @State private var items: [PostCard] = []
    @State private var page = 0
    @State private var pages = 1
    @State private var loading = false
    @State private var error = false

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                Button { dismiss() } label: { Image(systemName: "chevron.left").font(.system(size: 19, weight: .semibold)).foregroundStyle(C.text).frame(width: 44, height: 44) }
                if cat != nil {
                    Image(catIcon(icon)).resizable().scaledToFit().frame(width: 34, height: 34)
                    VStack(alignment: .leading, spacing: 0) {
                        Text("ΚΑΤΗΓΟΡΙΑ").font(F.body(10, .heavy)).foregroundStyle(C.gold)
                        ScreenTitle(text: title)
                    }
                } else {
                    ScreenTitle(text: title)
                }
                Spacer()
            }
            .padding(.trailing, 16).padding(.leading, 4).padding(.vertical, 6)

            ScrollView {
                if items.isEmpty && error { EmptyState(icon: "wifi.exclamationmark", text: "Δεν φόρτωσε. Έλεγξε τη σύνδεση.") { Task { await load(reset: true) } } }
                else if items.isEmpty { SkeletonList() }
                else {
                    // Διαφήμιση στη ροή κάθε Ν άρθρα (Ν από το wp-admin, όπως Android)
                    let every = AppState.shared.config?.ads.everyN ?? 5
                    let chunks = stride(from: 0, to: items.count, by: every).map { Array(items[$0..<min($0 + every, items.count)]) }
                    LazyVStack(spacing: 8) {
                        ForEach(Array(chunks.enumerated()), id: \.offset) { ci, chunk in
                            if hsc == .regular {
                                LazyVGrid(columns: [GridItem(.adaptive(minimum: 260), spacing: 20, alignment: .top)], spacing: 22) {
                                    ForEach(chunk) { PostTile(p: $0) }
                                }
                            } else {
                                ForEach(chunk) { p in
                                    if p.id == items.first?.id && cat != nil { PostCardMedium(p: p).padding(.bottom, 6) } else { PostRow(p: p) }
                                }
                            }
                            if chunk.count == every { FeedAd().frame(maxWidth: 620) }
                        }
                    }
                    .padding(.horizontal, hsc == .regular ? 28 : 16)
                    if page < pages {
                        Button { Task { await load(reset: false) } } label: {
                            Group {
                                if loading { ProgressView().tint(C.ink) } else { Text("ΠΕΡΙΣΣΟΤΕΡΑ ΑΡΘΡΑ").font(F.body(14, .heavy)) }
                            }
                            .foregroundStyle(C.ink).padding(.horizontal, 22).padding(.vertical, 12)
                            .background(RoundedRectangle(cornerRadius: 12).fill(C.gold))
                        }.buttonStyle(.plain).padding(.top, 8).padding(.bottom, 24)
                    }
                }
            }
            .refreshable { haptic(); await load(reset: true) }
        }
        .background(C.ink)
        .toolbar(.hidden, for: .navigationBar)
        .task {
            Analytics.screen(cat == nil ? 6 : 3, name: cat ?? "feed")
            if items.isEmpty {
                if let j = Api.shared.peek(Api.pFeed(cat)) { let f = Feed(j); items = merge([], ([f.featured].compactMap { $0 }) + f.items) }
                await load(reset: true)
            }
        }
    }

    func merge(_ old: [PostCard], _ new: [PostCard]) -> [PostCard] {
        var out = old
        for n in new.sorted(by: { $0.date > $1.date }) where !out.contains(where: { $0.id == n.id }) { out.append(n) }
        return out
    }

    func load(reset: Bool) async {
        guard !loading else { return }
        loading = true; defer { loading = false }
        do {
            let f = try await Api.shared.feed(cat, page: reset ? 1 : page + 1)
            let all = (reset ? [f.featured].compactMap { $0 } : []) + f.items
            items = merge(reset ? [] : items, all)
            page = f.page; pages = f.pages; error = false
        } catch { if reset && items.isEmpty { self.error = true } }
    }
}

struct SearchView: View {
    @State private var q = ""
    @State private var items: [PostCard] = []
    @State private var searching = false
    @State private var done = false

    var body: some View {
        ScrollView {
            LazyVGrid(columns: adaptiveCols, spacing: 0) { ForEach(items) { PostRow(p: $0) } }.padding(.horizontal, 16)
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
