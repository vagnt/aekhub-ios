import SwiftUI

/// AEK Hub για Apple Watch (σχέδιο watchOS 26): live/επόμενος, αγώνες, βαθμολογία, νέα.
@main
struct AEKHubWatchApp: App {
    var body: some Scene {
        WindowGroup { WatchRoot().tint(C.gold) }
    }
}

enum WRoute: Hashable { case match(Int), post(PostCard), postId(Int), standings, feed(String, String), categories }

struct WatchRoot: View {
    @State private var path = NavigationPath()
    var body: some View {
        NavigationStack(path: $path) { WatchHome() }
            .onAppear {
                // για τα screenshots του CI: -open match/123 · standings
                guard let o = UserDefaults.standard.string(forKey: "open") else { return }
                if o == "standings" { path.append(WRoute.standings) }
                else if o.hasPrefix("match/"), let id = Int(o.dropFirst(6)) { path.append(WRoute.match(id)) }
                else if o == "feed" { path.append(WRoute.feed("", "Ροή ειδήσεων")) }
                else if o == "categories" { path.append(WRoute.categories) }
                else if o.hasPrefix("category/") { path.append(WRoute.feed(String(o.dropFirst(9)), "Κατηγορία")) }
                else if o.hasPrefix("post/"), let id = Int(o.dropFirst(5)) { path.append(WRoute.postId(id)) }
            }
            // complication «Τελευταίο νέο» → άνοιγμα του άρθρου
            .onOpenURL { u in
                guard u.scheme == "aekhub" else { return }
                if u.host == "post", let id = Int(u.lastPathComponent) { path = NavigationPath(); path.append(WRoute.postId(id)) }
                else if u.host == "match", let id = Int(u.lastPathComponent) { path = NavigationPath(); path.append(WRoute.match(id)) }
            }
    }
}

struct WatchHome: View {
    @State private var home: HomeData? = Api.shared.peek(Api.pHome).map(HomeData.init)
    @State private var list: MatchList? = Api.shared.peek(Api.pMatches()).map(MatchList.init)
    @State private var error = false

    var body: some View {
        List {
            if let m = home?.liveHero?.match ?? list?.items.first(where: { $0.live }) ?? home?.next {
                NavigationLink(value: WRoute.match(m.id)) { WatchHero(m: m) }
                    .listRowBackground(RoundedRectangle(cornerRadius: 22, style: .continuous).fill(m.live ? C.live.opacity(0.18) : C.panel))
            }

            let today = Fmt.ymdString(Date())
            let all = list?.items ?? []
            let next = all.filter { ($0.upcoming && $0.date >= today) || $0.live }.sorted { ($0.date, $0.time) < ($1.date, $1.time) }.prefix(6)
            let recent = all.filter { $0.finished && $0.date <= today }.sorted { ($0.date, $0.time) > ($1.date, $1.time) }.prefix(4)

            if !next.isEmpty {
                Section { ForEach(Array(next)) { m in NavigationLink(value: WRoute.match(m.id)) { WatchMatchRow(m: m) }.listRowBackground(rowBG) } }
                header: { head("Αγώνες", Fmt.shortDay(today)) }
            }
            if !recent.isEmpty {
                Section { ForEach(Array(recent)) { m in NavigationLink(value: WRoute.match(m.id)) { WatchMatchRow(m: m) }.listRowBackground(rowBG) } }
                header: { head("Αποτελέσματα", "") }
            }
            NavigationLink(value: WRoute.standings) {
                Label("Βαθμολογία", systemImage: "list.number").font(.system(size: 15, weight: .semibold))
            }.listRowBackground(rowBG)
            if let h = home {
                let posts = ([h.featured].compactMap { $0 } + h.top).prefix(8)
                Section {
                    ForEach(Array(posts)) { p in
                        NavigationLink(value: WRoute.post(p)) {
                            VStack(alignment: .leading, spacing: 3) {
                                if !p.category.isEmpty { Text(p.category.upperGr).font(.system(size: 10, weight: .bold)).foregroundStyle(C.gold) }
                                Text(p.title).font(.system(size: 14, weight: .semibold)).lineLimit(4)
                            }.padding(.vertical, 2)
                        }.listRowBackground(rowBG)
                    }
                    NavigationLink(value: WRoute.feed("", "Ροή ειδήσεων")) {
                        Label("Ροή ειδήσεων", systemImage: "newspaper").font(.system(size: 15, weight: .semibold)).foregroundStyle(C.gold)
                    }.listRowBackground(rowBG)
                    NavigationLink(value: WRoute.categories) {
                        Label("Κατηγορίες", systemImage: "square.grid.2x2").font(.system(size: 15, weight: .semibold)).foregroundStyle(C.gold)
                    }.listRowBackground(rowBG)
                } header: { head("Νέα", "") }
            }
            if home == nil && list == nil {
                if error { VStack(spacing: 6) { Text("Χωρίς σύνδεση").font(.headline); Button("Ξανά") { Task { await load() } } } }
                else { ProgressView() }
            }
        }
        .navigationTitle("AEK Hub")
        .navigationDestination(for: WRoute.self) { r in
            switch r {
            case .match(let id): WatchMatchView(id: id)
            case .post(let p): WatchPostView(id: p.id, card: p)
            case .postId(let id): WatchPostView(id: id, card: nil)
            case .standings: WatchStandingsView()
            case .feed(let cat, let title): WatchFeedView(cat: cat, title: title)
            case .categories: WatchCategoriesView()
            }
        }
        .task {
            await load()
            while !Task.isCancelled {
                let live = list?.items.contains { $0.live } == true
                try? await Task.sleep(nanoseconds: (live ? 15 : 120) * 1_000_000_000)
                await load()
            }
        }
    }

    var rowBG: some View { RoundedRectangle(cornerRadius: 18, style: .continuous).fill(C.panel2) }
    func head(_ t: String, _ r: String) -> some View {
        HStack { Text(t.upperGr).font(.system(size: 17, weight: .heavy).width(.condensed)).foregroundStyle(C.gold); Spacer(); Text(r).font(.system(size: 12, weight: .semibold)).foregroundStyle(C.text2) }
    }

    func load() async {
        async let h = try? Api.shared.home()
        async let l = try? Api.shared.matches()
        let (hh, ll) = await (h, l)
        if let hh { home = hh }
        if let ll { list = ll }
        error = hh == nil && ll == nil
    }
}

/// Live σκορ ή αντίστροφη μέτρηση (σχέδιο «Live · Smart Stack»)
struct WatchHero: View {
    let m: MatchCard
    var body: some View {
        VStack(spacing: 5) {
            if m.live {
                TimelineView(.periodic(from: .now, by: 15)) { ctx in
                    HStack(spacing: 4) {
                        Circle().fill(C.live).frame(width: 7, height: 7)
                        Text("LIVE · " + liveMinute(m.clock, fallback: m.minute.isEmpty ? m.statusLabel : m.minute, now: ctx.date)).font(.system(size: 13, weight: .heavy)).foregroundStyle(C.live)
                    }
                }
            } else {
                Text(m.finished ? "ΤΕΛΙΚΟ" : "ΕΠΟΜΕΝΟΣ").font(.system(size: 11, weight: .heavy)).foregroundStyle(C.gold)
            }
            HStack(spacing: 6) {
                TeamLogo(url: m.homeLogo, size: 30, name: m.home)
                if m.live || m.hasScore {
                    HStack(spacing: 3) {
                        Text(m.scoreHome).foregroundStyle(m.aek == "home" ? C.gold : C.text)
                        Text("–").foregroundStyle(C.muted).font(.system(size: 20))
                        Text(m.scoreAway).foregroundStyle(m.aek == "away" ? C.gold : C.text)
                    }.font(.system(size: 36, weight: .heavy).width(.condensed)).monospacedDigit()
                } else {
                    Text(m.time).font(.system(size: 30, weight: .heavy).width(.condensed)).foregroundStyle(C.gold)
                }
                TeamLogo(url: m.awayLogo, size: 30, name: m.away)
            }
            Text(m.competition).font(.system(size: 11)).foregroundStyle(C.text2).lineLimit(1)
            if m.live {
                GeometryReader { g in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color.white.opacity(0.15))
                        Capsule().fill(C.gold).frame(width: g.size.width * progress)
                    }
                }.frame(height: 4).padding(.horizontal, 12)
            } else if let ko = m.kickoffDate, ko > Date() {
                Text(ko, style: .relative).font(.system(size: 12, weight: .bold)).foregroundStyle(C.gold).multilineTextAlignment(.center)
            }
        }
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity)
    }
    var progress: CGFloat {
        let mn = Double(liveMinute(m.clock, fallback: m.minute).filter(\.isNumber).prefix(3)) ?? 0
        return CGFloat(min(1, mn / (m.sport.contains("football") ? 90 : 40)))
    }
}

/// «ΑΕΚ – ΡΕΑΛ 19:45» (σχέδιο «Αγώνες»)
struct WatchMatchRow: View {
    let m: MatchCard
    var body: some View {
        HStack(spacing: 8) {
            TeamLogo(url: m.aek == "away" ? m.awayLogo : m.homeLogo, size: 22, name: "ΑΕΚ")
            VStack(alignment: .leading, spacing: 1) {
                Text("\(short(m.home)) – \(short(m.away))").font(.system(size: 14, weight: .heavy).width(.condensed)).lineLimit(1)
                Text(Sports.label(m.sport)).font(.system(size: 10)).foregroundStyle(C.muted).lineLimit(1)
            }
            Spacer(minLength: 2)
            VStack(alignment: .trailing, spacing: 1) {
                if m.upcoming && !m.hasScore {
                    Text(m.time).font(.system(size: 15, weight: .heavy).width(.condensed)).foregroundStyle(C.gold)
                    Text(Fmt.shortDay(m.date)).font(.system(size: 10)).foregroundStyle(C.muted)
                } else {
                    Text("\(m.scoreHome)–\(m.scoreAway)").font(.system(size: 16, weight: .heavy).width(.condensed)).monospacedDigit().foregroundStyle(m.live ? C.gold : C.text)
                    if m.live { Text("LIVE").font(.system(size: 9, weight: .heavy)).foregroundStyle(C.live) }
                }
            }
        }
    }
    func short(_ n: String) -> String { n.upperGr.split(separator: " ").first.map(String.init) ?? n.upperGr }
}

struct WatchMatchView: View {
    let id: Int
    @State private var d: MatchDetail?

    init(id: Int) { self.id = id; _d = State(initialValue: Api.shared.peek(Api.pMatch(id)).map(MatchDetail.init)) }

    var body: some View {
        ScrollView {
            if let d {
                let c = d.card
                VStack(spacing: 8) {
                    WatchHero(m: c)
                    if !d.scorersHome.isEmpty || !d.scorersAway.isEmpty {
                        HStack(alignment: .top) {
                            VStack(alignment: .leading) { ForEach(d.scorersHome, id: \.self) { Text($0) } }
                            Spacer()
                            VStack(alignment: .trailing) { ForEach(d.scorersAway, id: \.self) { Text($0) } }
                        }.font(.system(size: 11)).foregroundStyle(C.text2)
                    }
                    let evs = (d.groups.isEmpty ? d.events : d.groups.flatMap(\.events)).filter { $0.type != "point" }
                    ForEach(Array(evs.prefix(25).enumerated()), id: \.offset) { _, e in
                        HStack(alignment: .top, spacing: 6) {
                            Text(e.minute).font(.system(size: 13, weight: .heavy).width(.condensed)).foregroundStyle(C.gold).frame(width: 30, alignment: .leading)
                            Text(eventIconW(e.type)).font(.system(size: 11))
                            VStack(alignment: .leading, spacing: 1) {
                                Text(e.label).font(.system(size: 12, weight: .semibold))
                                if !e.text.isEmpty { Text(e.text).font(.system(size: 11)).foregroundStyle(C.text2) }
                            }
                            Spacer(minLength: 0)
                            if !e.score.isEmpty { Text(e.score).font(.system(size: 11)).foregroundStyle(C.muted) }
                        }
                        .padding(8).background(RoundedRectangle(cornerRadius: 12).fill(C.panel2))
                    }
                    if !c.venue.isEmpty { Text(c.venue).font(.system(size: 10)).foregroundStyle(C.muted).multilineTextAlignment(.center) }
                }
            } else { ProgressView() }
        }
        .navigationTitle(d.map { $0.card.live ? "LIVE" : $0.card.sportLabel } ?? "")
        .task {
            await load()
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: (d?.card.live == true ? 15 : 120) * 1_000_000_000)
                await load()
            }
        }
    }
    func load() async { if let x = try? await Api.shared.match(id) { d = x } }
}

/// Βαθμολογία (το πρωτάθλημα με την ΑΕΚ)
struct WatchStandingsView: View {
    @State private var items: [Standing] = Api.shared.peek(Api.pStandings)?["items"].list(Standing.init) ?? []
    @State private var sel = 0
    var body: some View {
        let s = items.first { $0.id == sel } ?? items.first { $0.rows.contains { $0.aek } } ?? items.first
        ScrollView {
            if let s {
                VStack(alignment: .leading, spacing: 4) {
                    HStack { Text(s.title.upperGr).font(.system(size: 15, weight: .heavy).width(.condensed)).foregroundStyle(C.gold).lineLimit(1); Spacer(); Text("Β").font(.system(size: 11, weight: .bold)).foregroundStyle(C.muted) }
                    ForEach(s.rows, id: \.self) { r in
                        HStack(spacing: 6) {
                            Text("\(r.pos)").font(.system(size: 13)).foregroundStyle(C.text2).frame(width: 18, alignment: .trailing)
                            Text(r.name.upperGr).font(.system(size: 14, weight: .heavy).width(.condensed)).foregroundStyle(r.aek ? C.gold : C.text).lineLimit(1)
                            Spacer()
                            Text(r.points).font(.system(size: 14, weight: .bold)).monospacedDigit()
                        }
                        .padding(.vertical, 4).padding(.horizontal, 6)
                        .background(RoundedRectangle(cornerRadius: 8).fill(r.aek ? C.gold.opacity(0.18) : .clear))
                    }
                    if items.count > 1 {
                        Picker("Διοργάνωση", selection: $sel) { ForEach(items) { Text($0.title).tag($0.id) } }.padding(.top, 8)
                    }
                }
            } else { ProgressView() }
        }
        .navigationTitle("Βαθμολογία")
        .task { if let l = try? await Api.shared.standings() { items = l } }
    }
}

func eventIconW(_ t: String) -> String {
    if t.contains("goal") { return t.contains("miss") ? "❌" : "⚽" }
    switch t {
    case "yellow": return "🟨"
    case "red", "second_yellow": return "🟥"
    case "sub": return "🔄"
    case "ft": return "🏁"
    case "ht": return "⏸"
    default: return "•"
    }
}

/// Ροή ειδήσεων (όλες ή μίας κατηγορίας) — με «Περισσότερα» στο τέλος
struct WatchFeedView: View {
    let cat: String
    let title: String
    @State private var items: [PostCard] = []
    @State private var page = 0
    @State private var pages = 1
    @State private var loading = false
    @State private var error = false
    @State private var name = ""

    var body: some View {
        List {
            ForEach(items) { p in
                NavigationLink(value: WRoute.post(p)) { WatchPostRow(p: p) }
                    .listRowBackground(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(C.panel2))
            }
            if loading { ProgressView().frame(maxWidth: .infinity) }
            else if error && items.isEmpty {
                VStack(spacing: 6) { Text("Χωρίς σύνδεση").font(.headline); Button("Ξανά") { Task { await load(reset: true) } } }
            } else if page < pages {
                Button { Task { await load(reset: false) } } label: {
                    Text("Περισσότερα").font(.system(size: 15, weight: .heavy)).foregroundStyle(C.ink).frame(maxWidth: .infinity)
                }
                .listRowBackground(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(C.gold))
            }
        }
        .navigationTitle(name.isEmpty ? title : name)
        .task {
            if items.isEmpty {
                if let j = Api.shared.peek(Api.pFeed(cat.isEmpty ? nil : cat)) { let f = Feed(j); items = ([f.featured].compactMap { $0 } + f.items) }
                if !cat.isEmpty, name.isEmpty, let c = try? await Api.shared.config() { name = c.categories.first { $0.slug == cat }?.name ?? "" }
                await load(reset: true)
            }
        }
    }

    func load(reset: Bool) async {
        guard !loading else { return }
        loading = true; defer { loading = false }
        do {
            let f = try await Api.shared.feed(cat.isEmpty ? nil : cat, page: reset ? 1 : page + 1)
            let all = (reset ? [f.featured].compactMap { $0 } : []) + f.items
            var out = reset ? [] : items
            for n in all where !out.contains(where: { $0.id == n.id }) { out.append(n) }
            items = out; page = f.page; pages = f.pages; error = false
        } catch { self.error = true }
    }
}

/// Γραμμή άρθρου στο ρολόι: μικρή φωτογραφία, κατηγορία, τίτλος, ημερομηνία
struct WatchPostRow: View {
    let p: PostCard
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            if !p.image.isEmpty {
                Color.clear.frame(height: 70).overlay(NetImage(url: p.image, w: 400)).clipShape(RoundedRectangle(cornerRadius: 10))
            }
            if !p.category.isEmpty { Text(p.category.upperGr).font(.system(size: 10, weight: .bold)).foregroundStyle(C.gold) }
            Text(p.title).font(.system(size: 14, weight: .semibold)).lineLimit(4)
            Text(Fmt.postDate(p.date, withYear: false)).font(.system(size: 10)).foregroundStyle(C.muted)
        }
        .padding(.vertical, 4)
    }
}

/// Κατηγορίες (ίδιες με το site/app)
struct WatchCategoriesView: View {
    @State private var cats: [Category] = Api.shared.peek(Api.pConfig).map { AppConfig($0).categories } ?? []
    var body: some View {
        List {
            ForEach(cats) { c in
                NavigationLink(value: WRoute.feed(c.slug, c.name)) {
                    HStack(spacing: 10) {
                        Image(systemName: icon(c.icon)).font(.system(size: 16, weight: .semibold)).foregroundStyle(C.gold).frame(width: 24)
                        Text(c.name).font(.system(size: 16, weight: .semibold))
                    }.padding(.vertical, 4)
                }
                .listRowBackground(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(C.panel2))
            }
            if cats.isEmpty { ProgressView() }
        }
        .navigationTitle("Κατηγορίες")
        .task { if let c = try? await Api.shared.config() { cats = c.categories } }
    }
    func icon(_ k: String) -> String {
        switch k {
        case "football": return "soccerball"
        case "basketball": return "basketball.fill"
        case "erasitechniki": return "trophy.fill"
        case "hubplus": return "plus.circle.fill"
        default: return "newspaper.fill"
        }
    }
}

struct WatchPostView: View {
    let id: Int
    let card: PostCard?
    @State private var post: Post?
    init(id: Int, card: PostCard?) {
        self.id = id; self.card = card
        _post = State(initialValue: Api.shared.peek(Api.pPost(id)).map(Post.init))
    }
    var body: some View {
        let image = post?.image ?? card?.image ?? ""
        let cat = post?.category ?? card?.category ?? ""
        let title = post?.title ?? card?.title ?? ""
        let date = post?.date ?? card?.date ?? ""
        ScrollView {
            VStack(alignment: .leading, spacing: 8) {
                if !image.isEmpty { Color.clear.frame(height: 95).overlay(NetImage(url: image, w: 400)).clipShape(RoundedRectangle(cornerRadius: 12)) }
                if !cat.isEmpty { Text(cat.upperGr).font(.system(size: 10, weight: .bold)).foregroundStyle(C.gold) }
                Text(title).font(.system(size: 16, weight: .bold))
                if !date.isEmpty { Text(Fmt.postDate(date, withYear: false)).font(.system(size: 11)).foregroundStyle(C.muted) }
                if let p = post {
                    if !p.excerpt.isEmpty { Text(p.excerpt).font(.system(size: 13, weight: .semibold)).foregroundStyle(C.text2).padding(.leading, 8).overlay(alignment: .leading) { Rectangle().fill(C.gold).frame(width: 2) } }
                    Text(p.html.plainText).font(.system(size: 14))
                } else {
                    if let e = card?.excerpt, !e.isEmpty { Text(e).font(.system(size: 13)).foregroundStyle(C.text2) }
                    ProgressView()
                }
            }
        }
        .task { if let p = try? await Api.shared.post(id) { post = p } }
    }
}
