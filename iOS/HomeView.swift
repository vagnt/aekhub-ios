import SwiftUI

/// Αρχική (καρτέλα «Ειδήσεις»): λογότυπο + γυάλινα κουμπιά, κατηγορίες, κύριο θέμα, τελευταία νέα, αγώνες, ενότητες.
struct HomeView: View {
    @EnvironmentObject var app: AppState
    @State private var data: HomeData? = Api.shared.peek(Api.pHome).map(HomeData.init)
    @State private var error: String?
    @State private var cat = ""
    @State private var catItems: [PostCard] = []
    @State private var catPage = 0
    @State private var catPages = 1
    @State private var catLoading = false

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                header
                ChipRow(items: [("", "Όλα")] + (app.config?.categories ?? []).map { ($0.slug, $0.name) }, selected: cat) { k in
                    cat = k
                    if !k.isEmpty { Task { await loadCat(reset: true) } }
                }
                .padding(.bottom, 16)

                if cat.isEmpty {
                    if let d = data { content(d) }
                    else if let error { EmptyState(icon: "wifi.exclamationmark", text: error) { Task { await load() } } }
                    else { ProgressView().tint(C.gold).frame(maxWidth: .infinity).padding(60) }
                } else {
                    category
                }
            }
            .padding(.bottom, 24)
        }
        .background(C.ink)
        .refreshable { if cat.isEmpty { await load() } else { await loadCat(reset: true) } }
        .task {
            Analytics.screen(2)
            await load()
            while !Task.isCancelled {
                let live = data?.matches.contains { $0.live } == true || data?.next?.live == true
                try? await Task.sleep(nanoseconds: (live ? 15 : 60) * 1_000_000_000)
                await load()
            }
        }
    }

    var header: some View {
        HStack {
            LogoTitle(h: 34)
            Spacer()
            HStack(spacing: 4) {
                NavigationLink(value: Route.feed) { icon("clock.arrow.circlepath") }
                NavigationLink(value: Route.search) { icon("magnifyingglass") }
                Button { app.tab = .me } label: {
                    icon("bell").overlay(alignment: .topTrailing) { Circle().fill(C.gold).frame(width: 7, height: 7).offset(x: -10, y: 10) }
                }
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 6)
            .glass(Capsule())
        }
        .padding(.horizontal, screenPad).padding(.top, 8).padding(.bottom, 16)
    }
    func icon(_ n: String) -> some View {
        Image(systemName: n).font(.system(size: 18, weight: .semibold)).foregroundStyle(C.text).frame(width: 40, height: 44)
    }

    func load() async {
        do { data = try await Api.shared.home(); error = nil }
        catch { if data == nil { self.error = "Δεν ήταν δυνατή η σύνδεση με το aekhub.gr.\n" + error.localizedDescription } }
    }

    // MARK: Όλα

    @ViewBuilder func content(_ d: HomeData) -> some View {
        // 🔴 Live Hero (αγώνας ή γεγονός) → αλλιώς ο επόμενος αγώνας
        if let h = d.liveHero, let m = h.match {
            CountdownCard(m: m).padding(.bottom, 16)
        } else if let h = d.liveHero, h.type == "event" {
            NavigationLink(value: Route.event(h.id)) {
                ZStack(alignment: .bottomLeading) {
                    NetImage(url: h.image, w: 1200).frame(height: 230).frame(maxWidth: .infinity).clipped()
                    LinearGradient(colors: [.clear, .black.opacity(0.92)], startPoint: .center, endPoint: .bottom)
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 6) { LiveDot(); Text("LIVE").font(.system(size: 12, weight: .heavy)).foregroundStyle(C.live) }
                        Text(h.title.upperGr).font(F.disp(28)).foregroundStyle(.white).lineLimit(3)
                    }.padding(20)
                }
                .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
                .padding(.horizontal, screenPad).padding(.bottom, 16)
            }.buttonStyle(.plain)
        }

        if let f = d.featured { PostHero(p: f) }

        if d.liveHero?.match == nil, let n = d.next {
            CountdownCard(m: n).padding(.top, 16)
        }

        if !d.top.isEmpty {
            GoldHeader(title: "Τελευταία νέα", action: "Ροή ειδήσεων", route: .feed)
            LazyVGrid(columns: adaptiveCols, spacing: 0) { ForEach(d.top) { PostRow(p: $0) } }
        }

        if !d.matches.isEmpty {
            HStack { GoldHeader(title: "Αγώνες") }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) { ForEach(d.matches) { MatchMini(m: $0) } }.padding(.horizontal, screenPad)
            }
        }

        ForEach(d.sections) { s in
            if !s.items.isEmpty {
                GoldHeader(title: s.name, action: "Όλα", route: .category(s.slug, s.name))
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(alignment: .top, spacing: 14) { ForEach(s.items) { PostTile(p: $0) } }.padding(.horizontal, screenPad)
                }
            }
        }
    }

    // MARK: Κατηγορία (στο ίδιο σημείο, όπως στο Android)

    @ViewBuilder var category: some View {
        if let first = catItems.first {
            PostHero(p: first)
            GoldHeader(title: (app.config?.categories.first { $0.slug == cat }?.name ?? "Άρθρα"))
            LazyVGrid(columns: adaptiveCols, spacing: 0) {
                ForEach(catItems.dropFirst()) { p in
                    PostRow(p: p).onAppear { if p.id == catItems.last?.id { Task { await loadCat(reset: false) } } }
                }
            }
        }
        if catLoading { ProgressView().tint(C.gold).frame(maxWidth: .infinity).padding(30) }
    }

    func loadCat(reset: Bool) async {
        if reset {
            catPage = 0; catPages = 1
            catItems = Api.shared.peek(Api.pFeed(cat)).map { Feed($0).items } ?? []
        }
        guard !catLoading, catPage < catPages else { return }
        catLoading = true; defer { catLoading = false }
        let want = cat
        guard let f = try? await Api.shared.feed(want, page: catPage + 1), want == cat else { return }
        var list = f.items
        if catPage == 0, let feat = f.featured, !list.contains(where: { $0.id == feat.id }) { list.insert(feat, at: 0) }
        catItems = catPage == 0 ? list : catItems + list.filter { n in !catItems.contains { $0.id == n.id } }
        catPage = f.page; catPages = f.pages
    }
}
