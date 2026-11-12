import SwiftUI
import WatchKit

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

// MARK: - Αρχική: σελίδες με το Digital Crown (watchOS 10+ κάθετα, παλιότερα οριζόντια)
// 1 Αγώνας (live/επόμενος σε όλη την οθόνη) · 2 Νέα (κάρτες με φωτογραφία) · 3 Πρόγραμμα · 4 Βαθμολογία · 5 Περισσότερα

struct WatchHome: View {
    @State private var home: HomeData? = Api.shared.peek(Api.pHome).map(HomeData.init)
    @State private var list: MatchList? = Api.shared.peek(Api.pMatches()).map(MatchList.init)
    @State private var table: [Standing] = Api.shared.peek(Api.pStandings)?["items"].list(Standing.init) ?? []
    @State private var error = false
    @State private var page = 0

    var main: MatchCard? { home?.liveHero?.match ?? list?.items.first(where: { $0.live }) ?? home?.next }

    var body: some View {
        Group {
            if #available(watchOS 10, *) {
                TabView(selection: $page) { pages }.tabViewStyle(.verticalPage)
            } else {
                TabView(selection: $page) { pages }.tabViewStyle(.page)
            }
        }
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

    @ViewBuilder var pages: some View {
        matchPage.tag(0)
        newsPage.tag(1)
        schedulePage.tag(2)
        tablePage.tag(3)
        morePage.tag(4)
    }

    // 1 · Ο αγώνας
    var matchPage: some View {
        Group {
            if let m = main {
                NavigationLink(value: WRoute.match(m.id)) { WatchHero(m: m, big: true) }.buttonStyle(.plain)
            } else if error {
                VStack(spacing: 8) {
                    Image(systemName: "wifi.slash").font(.title3).foregroundStyle(C.muted)
                    Text("Χωρίς σύνδεση").font(.headline)
                    Button("Ξανά") { Task { await load() } }.tint(C.gold)
                }
            } else { ProgressView() }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .wBackground(main?.live == true ? C.live : C.gold)
        .navigationTitle { WatchBrand() }
    }

    // 2 · Νέα — μεγάλες κάρτες με φωτογραφία (το Crown περνά από τη μία στην άλλη)
    var newsPage: some View {
        let posts = home.map { Array(([$0.featured].compactMap { $0 } + $0.top).prefix(8)) } ?? []
        return ScrollView {
            VStack(spacing: 10) {
                ForEach(posts) { p in NavigationLink(value: WRoute.post(p)) { WatchNewsCard(p: p) }.buttonStyle(.plain) }
                NavigationLink(value: WRoute.feed("", "Ροή ειδήσεων")) { pill("Όλα τα νέα", "newspaper.fill") }.buttonStyle(.plain)
                if posts.isEmpty { ProgressView() }
            }
        }
        .wBackground(C.gold)
        .navigationTitle("Νέα")
    }

    // 3 · Πρόγραμμα & αποτελέσματα
    var schedulePage: some View {
        let today = Fmt.ymdString(Date())
        let all = list?.items ?? []
        let next = Array(all.filter { ($0.upcoming && $0.date >= today) || $0.live }.sorted { ($0.date, $0.time) < ($1.date, $1.time) }.prefix(6))
        let recent = Array(all.filter { $0.finished && $0.date <= today }.sorted { ($0.date, $0.time) > ($1.date, $1.time) }.prefix(5))
        return ScrollView {
            VStack(alignment: .leading, spacing: 6) {
                if !next.isEmpty { label("Επόμενοι") }
                ForEach(next) { m in NavigationLink(value: WRoute.match(m.id)) { WatchMatchRow(m: m) }.buttonStyle(.plain) }
                if !recent.isEmpty { label("Αποτελέσματα").padding(.top, 6) }
                ForEach(recent) { m in NavigationLink(value: WRoute.match(m.id)) { WatchMatchRow(m: m) }.buttonStyle(.plain) }
                if next.isEmpty && recent.isEmpty { ProgressView().frame(maxWidth: .infinity) }
            }
        }
        .wBackground(C.gold)
        .navigationTitle("Πρόγραμμα")
    }

    // 4 · Βαθμολογία: η ΑΕΚ στη μέση (2 πάνω, 2 κάτω)
    var tablePage: some View {
        let s = table.first { $0.rows.contains { $0.aek } && ($0.sport.contains("ποδ") || $0.sport.lowercased().contains("foot")) } ?? table.first { $0.rows.contains { $0.aek } }
        return ScrollView {
            if let s {
                let i = s.rows.firstIndex { $0.aek } ?? 0
                let lo = max(0, min(i - 2, s.rows.count - 5)), hi = min(s.rows.count, lo + 5)
                VStack(alignment: .leading, spacing: 4) {
                    Text(s.title.upperGr).font(.system(size: 13, weight: .heavy).width(.condensed)).foregroundStyle(C.gold).lineLimit(1)
                    ForEach(s.rows[lo..<hi], id: \.self) { r in WatchTableRow(r: r) }
                    NavigationLink(value: WRoute.standings) { pill("Όλη η βαθμολογία", "list.number") }.buttonStyle(.plain).padding(.top, 4)
                }
            } else { ProgressView() }
        }
        .wBackground(C.gold)
        .navigationTitle("Βαθμολογία")
    }

    // 5 · Περισσότερα
    var morePage: some View {
        ScrollView {
            VStack(spacing: 8) {
                NavigationLink(value: WRoute.feed("", "Ροή ειδήσεων")) { pill("Ροή ειδήσεων", "newspaper.fill") }.buttonStyle(.plain)
                NavigationLink(value: WRoute.categories) { pill("Κατηγορίες", "square.grid.2x2.fill") }.buttonStyle(.plain)
                NavigationLink(value: WRoute.standings) { pill("Βαθμολογίες", "list.number") }.buttonStyle(.plain)
                Text("aekhub.gr").font(.system(size: 11, weight: .semibold)).foregroundStyle(C.muted).padding(.top, 6)
            }
        }
        .wBackground(C.gold)
        .navigationTitle("Περισσότερα")
    }

    func label(_ t: String) -> some View {
        Text(t.upperGr).font(.system(size: 12, weight: .heavy)).tracking(0.6).foregroundStyle(C.gold)
    }
    func pill(_ t: String, _ icon: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon).font(.system(size: 14, weight: .bold)).foregroundStyle(C.gold)
            Text(t).font(.system(size: 15, weight: .semibold)).foregroundStyle(C.text)
            Spacer(minLength: 0)
            Image(systemName: "chevron.right").font(.system(size: 11, weight: .bold)).foregroundStyle(C.muted)
        }
        .padding(.horizontal, 12).padding(.vertical, 11)
        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Color.white.opacity(0.09)))
    }

    func load() async {
        let th = Task { try? await Api.shared.home() }
        let tl = Task { try? await Api.shared.matches() }
        let ts = Task { try? await Api.shared.standings() }
        let hh = await th.value, ll = await tl.value, ss = await ts.value
        if let hh { home = hh }
        if let ll { list = ll }
        if let ss { table = ss }
        error = hh == nil && ll == nil
    }
}

/// Λογότυπο «aek hub» στη θέση του τίτλου
struct WatchBrand: View {
    var body: some View {
        HStack(spacing: 2) {
            Text("AEK").font(.system(size: 15, weight: .black).width(.condensed)).foregroundStyle(C.gold)
            Text("HUB").font(.system(size: 15, weight: .black).width(.condensed)).foregroundStyle(C.text)
        }
    }
}

extension View {
    /// Σκούρο φόντο με απαλή λάμψη στο πάνω μέρος (κίτρινη ΑΕΚ ή κόκκινη όταν είναι live)
    @ViewBuilder func wBackground(_ glow: Color) -> some View {
        let bg = ZStack {
            Color.black
            RadialGradient(colors: [glow.opacity(0.35), .clear], center: .top, startRadius: 0, endRadius: 170)
        }
        if #available(watchOS 10, *) { self.containerBackground(for: .tabView) { bg }.containerBackground(for: .navigation) { bg } }
        else { self.background(bg.ignoresSafeArea()) }
    }
}

/// Κάρτα είδησης: φωτογραφία σε όλο το πλάτος, ο τίτλος πάνω της με σκίαση
struct WatchNewsCard: View {
    let p: PostCard
    var body: some View {
        ZStack(alignment: .bottomLeading) {
            Color.clear.frame(height: 118)
                .overlay(Group { if p.image.isEmpty { C.panel2 } else { NetImage(url: p.image, w: 420) } })
            LinearGradient(colors: [.clear, .black.opacity(0.92)], startPoint: .center, endPoint: .bottom)
            VStack(alignment: .leading, spacing: 2) {
                if !p.category.isEmpty {
                    Text(p.category.upperGr).font(.system(size: 9, weight: .heavy)).foregroundStyle(C.ink)
                        .padding(.horizontal, 5).padding(.vertical, 2).background(Capsule().fill(C.gold))
                }
                Text(p.title).font(.system(size: 14, weight: .bold)).foregroundStyle(.white).lineLimit(3)
                    .shadow(color: .black.opacity(0.6), radius: 3)
            }
            .padding(8)
        }
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

/// Γραμμή βαθμολογίας (η ΑΕΚ φωτισμένη)
struct WatchTableRow: View {
    let r: StandingRow
    var body: some View {
        HStack(spacing: 6) {
            Text("\(r.pos)").font(.system(size: 13, weight: .bold)).foregroundStyle(r.aek ? C.ink : C.text2).frame(width: 18, alignment: .trailing)
            if !r.logo.isEmpty { TeamLogo(url: r.logo, size: 16, name: r.name) }
            Text(r.name.upperGr).font(.system(size: 14, weight: .heavy).width(.condensed)).foregroundStyle(r.aek ? C.ink : C.text).lineLimit(1)
            Spacer(minLength: 2)
            Text(r.points).font(.system(size: 15, weight: .heavy).width(.condensed)).monospacedDigit().foregroundStyle(r.aek ? C.ink : C.text)
        }
        .padding(.vertical, 5).padding(.horizontal, 7)
        .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(r.aek ? C.gold : Color.white.opacity(0.06)))
    }
}

/// Live σκορ ή αντίστροφη μέτρηση. `big` = σελίδα «Αγώνας» σε όλη την οθόνη.
struct WatchHero: View {
    let m: MatchCard
    var big = false
    var body: some View {
        VStack(spacing: big ? 7 : 5) {
            // πάνω: φάση
            if m.live {
                TimelineView(.periodic(from: .now, by: 15)) { ctx in
                    HStack(spacing: 4) {
                        Circle().fill(C.live).frame(width: 7, height: 7)
                        Text("LIVE · " + liveMinute(m.clock, fallback: m.minute.isEmpty ? m.statusLabel : m.minute, now: ctx.date))
                            .font(.system(size: 13, weight: .heavy)).foregroundStyle(C.live)
                    }
                }
            } else {
                Text(m.finished ? "ΤΕΛΙΚΟ" : "ΕΠΟΜΕΝΟΣ ΑΓΩΝΑΣ").font(.system(size: 11, weight: .heavy)).tracking(0.8).foregroundStyle(C.gold)
            }
            // σήματα + σκορ/ώρα
            HStack(spacing: 4) {
                team(m.homeLogo, m.home, m.aek == "home")
                Spacer(minLength: 0)
                if m.live || m.hasScore {
                    HStack(spacing: 3) {
                        Text(m.scoreHome).foregroundStyle(m.aek == "home" ? C.gold : C.text)
                        Text("–").foregroundStyle(C.muted).font(.system(size: 22))
                        Text(m.scoreAway).foregroundStyle(m.aek == "away" ? C.gold : C.text)
                    }
                    .font(.system(size: big ? 44 : 36, weight: .heavy).width(.condensed)).monospacedDigit()
                    .minimumScaleFactor(0.6).lineLimit(1)
                } else {
                    Text(m.time).font(.system(size: big ? 34 : 28, weight: .heavy).width(.condensed)).foregroundStyle(C.gold)
                }
                Spacer(minLength: 0)
                team(m.awayLogo, m.away, m.aek == "away")
            }
            // κάτω: διοργάνωση + πρόοδος/αντίστροφη μέτρηση
            Text(m.competition.isEmpty ? m.sportLabel : m.competition).font(.system(size: 11, weight: .medium)).foregroundStyle(C.text2).lineLimit(1)
            if m.live {
                GeometryReader { g in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color.white.opacity(0.15))
                        Capsule().fill(LinearGradient(colors: [C.gold.opacity(0.7), C.gold], startPoint: .leading, endPoint: .trailing))
                            .frame(width: max(6, g.size.width * progress))
                    }
                }.frame(height: 5).padding(.horizontal, 10)
            } else if let ko = m.kickoffDate, ko > Date() {
                if big { WatchCountdown(to: ko) }
                else { Text(ko, style: .relative).font(.system(size: 12, weight: .bold)).foregroundStyle(C.gold).multilineTextAlignment(.center) }
                Text(Fmt.shortDay(m.date)).font(.system(size: 11, weight: .semibold)).foregroundStyle(C.muted)
            }
        }
        .padding(.vertical, 6).padding(.horizontal, 2)
        .frame(maxWidth: .infinity)
    }

    func team(_ logo: String, _ name: String, _ aek: Bool) -> some View {
        VStack(spacing: 3) {
            TeamLogo(url: logo, size: big ? 38 : 30, name: name)
            if big {
                Text(name.upperGr).font(.system(size: 10, weight: .heavy).width(.condensed))
                    .foregroundStyle(aek ? C.gold : C.text2).lineLimit(1).minimumScaleFactor(0.7)
            }
        }.frame(width: big ? 50 : 34)
    }

    var progress: CGFloat {
        let mn = Double(liveMinute(m.clock, fallback: m.minute).filter(\.isNumber).prefix(3)) ?? 0
        let full: Double = m.sport.contains("football") ? 90 : m.sport.contains("basket") ? 40 : m.sport.contains("handball") ? 60 : 40
        return CGFloat(min(1, mn / full))
    }
}

/// Αντίστροφη μέτρηση σε κουτάκια (μέρες · ώρες · λεπτά), όπως στο κινητό
struct WatchCountdown: View {
    let to: Date
    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { ctx in
            let s = max(0, Int(to.timeIntervalSince(ctx.date)))
            let d = s / 86400, h = (s % 86400) / 3600, mi = (s % 3600) / 60, se = s % 60
            HStack(spacing: 4) {
                if d > 0 { box(d, "Μ"); box(h, "Ω"); box(mi, "Λ") } else { box(h, "Ω"); box(mi, "Λ"); box(se, "Δ") }
            }
        }
    }
    func box(_ v: Int, _ l: String) -> some View {
        VStack(spacing: 0) {
            Text(String(format: "%02d", v)).font(.system(size: 18, weight: .heavy).width(.condensed)).monospacedDigit().foregroundStyle(C.gold)
            Text(l).font(.system(size: 8, weight: .bold)).foregroundStyle(C.muted)
        }
        .frame(width: 36, height: 34)
        .background(RoundedRectangle(cornerRadius: 9, style: .continuous).fill(Color.white.opacity(0.08)))
    }
}

/// Γραμμή αγώνα: ΑΕΚ – ΧΧΧ με σήμα αντιπάλου, ώρα ή σκορ
struct WatchMatchRow: View {
    let m: MatchCard
    var body: some View {
        let oppAway = m.aek != "away"
        HStack(spacing: 8) {
            TeamLogo(url: oppAway ? m.awayLogo : m.homeLogo, size: 24, name: oppAway ? m.away : m.home)
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
                    Text("\(m.scoreHome)–\(m.scoreAway)").font(.system(size: 17, weight: .heavy).width(.condensed)).monospacedDigit().foregroundStyle(m.live ? C.gold : C.text)
                    if m.live { Text("LIVE").font(.system(size: 9, weight: .heavy)).foregroundStyle(C.live) }
                    else if let r = result { Text(r.0).font(.system(size: 9, weight: .heavy)).foregroundStyle(C.ink).padding(.horizontal, 4).background(Capsule().fill(r.1)) }
                }
            }
        }
        .padding(.horizontal, 10).padding(.vertical, 8)
        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(m.live ? C.live.opacity(0.22) : Color.white.opacity(0.08)))
    }
    /// Ν / Ι / Η για την ΑΕΚ
    var result: (String, Color)? {
        guard m.finished, let h = Int(m.scoreHome), let a = Int(m.scoreAway), !m.aek.isEmpty else { return nil }
        let mine = m.aek == "home" ? h : a, other = m.aek == "home" ? a : h
        return mine > other ? ("Ν", C.win) : mine == other ? ("Ι", C.muted) : ("Η", C.live)
    }
    func short(_ n: String) -> String { n.upperGr.split(separator: " ").first.map(String.init) ?? n.upperGr }
}

/// Σελίδα αγώνα: μεγάλος πίνακας σκορ, σκόρερ και πορεία χωρισμένη αριστερά/δεξιά (γηπεδούχος/φιλοξενούμενος)
struct WatchMatchView: View {
    let id: Int
    @State private var d: MatchDetail?
    @State private var lastAek: Int?

    init(id: Int) { self.id = id; _d = State(initialValue: Api.shared.peek(Api.pMatch(id)).map(MatchDetail.init)) }

    var body: some View {
        ScrollView {
            if let d {
                let c = d.card
                VStack(spacing: 8) {
                    WatchHero(m: c, big: true)
                    if !d.scorersHome.isEmpty || !d.scorersAway.isEmpty {
                        HStack(alignment: .top) {
                            VStack(alignment: .leading, spacing: 1) { ForEach(d.scorersHome, id: \.self) { Text($0) } }
                            Spacer()
                            VStack(alignment: .trailing, spacing: 1) { ForEach(d.scorersAway, id: \.self) { Text($0) } }
                        }.font(.system(size: 11)).foregroundStyle(C.text2)
                    }
                    let evs = (d.groups.isEmpty ? d.events : d.groups.flatMap(\.events)).filter { $0.type != "point" }
                    if !evs.isEmpty {
                        Text("ΠΟΡΕΙΑ").font(.system(size: 12, weight: .heavy)).tracking(0.6).foregroundStyle(C.gold).frame(maxWidth: .infinity, alignment: .leading).padding(.top, 4)
                    }
                    ForEach(Array(evs.prefix(30).enumerated()), id: \.offset) { _, e in WatchEventRow(e: e) }
                    if !c.venue.isEmpty { Label(c.venue, systemImage: "mappin.and.ellipse").font(.system(size: 10)).foregroundStyle(C.muted).multilineTextAlignment(.center).padding(.top, 4) }
                }
            } else { ProgressView() }
        }
        .wBackground(d?.card.live == true ? C.live : C.gold)
        .navigationTitle(d.map { $0.card.live ? "LIVE" : $0.card.sportLabel } ?? "")
        .task {
            await load()
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: (d?.card.live == true ? 15 : 120) * 1_000_000_000)
                await load()
            }
        }
    }

    func load() async {
        guard let x = try? await Api.shared.match(id) else { return }
        // δόνηση στο γκολ της ΑΕΚ — μόνο ποδόσφαιρο ανδρών (κανόνας του χρήστη)
        let c = x.card
        let aek = Int(c.aek == "away" ? c.scoreAway : c.scoreHome) ?? 0
        if c.live, c.sport == "football", let prev = lastAek, aek > prev { WKInterfaceDevice.current().play(.success) }
        lastAek = c.aek.isEmpty ? nil : aek
        d = x
    }
}

/// Γεγονός: γηπεδούχος αριστερά, φιλοξενούμενος δεξιά, λεπτό στη μέση της γραμμής
struct WatchEventRow: View {
    let e: MatchEvent
    var body: some View {
        let away = e.team == "away"
        let neutral = e.team.isEmpty || ["ht", "ft", "start", "period"].contains(e.type)
        if neutral {
            HStack(spacing: 6) {
                Rectangle().fill(C.line).frame(height: 1)
                Text(([e.label, e.score].filter { !$0.isEmpty }).joined(separator: " · ").upperGr).font(.system(size: 10, weight: .heavy)).foregroundStyle(C.muted).lineLimit(1).fixedSize()
                Rectangle().fill(C.line).frame(height: 1)
            }.padding(.vertical, 3)
        } else {
            HStack(alignment: .top, spacing: 6) {
                if away { Spacer(minLength: 16) }
                if !away { minute }
                VStack(alignment: away ? .trailing : .leading, spacing: 1) {
                    HStack(spacing: 4) {
                        if away { Text(e.label).font(.system(size: 12, weight: .semibold)).lineLimit(2) }
                        Text(eventIconW(e.type)).font(.system(size: 11))
                        if !away { Text(e.label).font(.system(size: 12, weight: .semibold)).lineLimit(2) }
                    }
                    if !e.text.isEmpty { Text(e.text).font(.system(size: 10)).foregroundStyle(C.text2).lineLimit(2).multilineTextAlignment(away ? .trailing : .leading) }
                    if !e.score.isEmpty, e.type.contains("goal") { Text(e.score).font(.system(size: 11, weight: .heavy).width(.condensed)).foregroundStyle(C.gold) }
                }
                if away { minute }
                if !away { Spacer(minLength: 16) }
            }
            .padding(.horizontal, 8).padding(.vertical, 6)
            .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(e.type.contains("goal") && !e.type.contains("miss") ? C.gold.opacity(0.16) : Color.white.opacity(0.07)))
        }
    }
    var minute: some View {
        Text(e.minute).font(.system(size: 13, weight: .heavy).width(.condensed)).foregroundStyle(C.gold).frame(minWidth: 22)
    }
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
                NavigationLink(value: WRoute.post(p)) { WatchNewsCard(p: p) }
                    .listRowBackground(Color.clear).listRowInsets(EdgeInsets(top: 4, leading: 0, bottom: 4, trailing: 0))
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
