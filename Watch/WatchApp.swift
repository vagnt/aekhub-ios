import SwiftUI

/// AEK Hub για Apple Watch: live/επόμενος αγώνας με αντίστροφη μέτρηση, αγώνες, τελευταία νέα.
@main
struct AEKHubWatchApp: App {
    var body: some Scene {
        WindowGroup {
            NavigationStack { WatchHome() }
                .tint(C.gold)
        }
    }
}

struct WatchHome: View {
    @State private var home: HomeData? = Api.shared.peek(Api.pHome).map(HomeData.init)
    @State private var list: MatchList? = Api.shared.peek(Api.pMatches()).map(MatchList.init)
    @State private var error = false

    var body: some View {
        List {
            if let m = home?.liveHero?.match ?? home?.next {
                NavigationLink(value: m.id) { WatchHero(m: m) }
                    .listRowBackground(RoundedRectangle(cornerRadius: 14).fill(m.live ? C.live.opacity(0.25) : C.panel2))
            }

            let live = (list?.items ?? []).filter { $0.live }
            let today = Fmt.ymdString(Date())
            let recent = (list?.items ?? []).filter { $0.finished && $0.date <= today }.sorted { ($0.date, $0.time) > ($1.date, $1.time) }.prefix(4)
            let next = (list?.items ?? []).filter { $0.upcoming && $0.date >= today }.sorted { ($0.date, $0.time) < ($1.date, $1.time) }.prefix(5)

            if !live.isEmpty {
                Section("Live τώρα") { ForEach(live) { m in NavigationLink(value: m.id) { WatchMatchRow(m: m) } } }
            }
            if !next.isEmpty {
                Section("Επόμενοι") { ForEach(Array(next)) { m in NavigationLink(value: m.id) { WatchMatchRow(m: m) } } }
            }
            if !recent.isEmpty {
                Section("Αποτελέσματα") { ForEach(Array(recent)) { m in NavigationLink(value: m.id) { WatchMatchRow(m: m) } } }
            }
            if let h = home {
                let posts = ([h.featured].compactMap { $0 } + h.top).prefix(8)
                Section("Νέα") {
                    ForEach(Array(posts)) { p in
                        NavigationLink(value: p) {
                            VStack(alignment: .leading, spacing: 3) {
                                Text(p.title).font(.system(size: 14, weight: .semibold)).lineLimit(4)
                                Text(Fmt.ago(p.date)).font(.system(size: 11)).foregroundStyle(C.muted)
                            }.padding(.vertical, 2)
                        }
                    }
                }
            }
            if home == nil && list == nil {
                if error {
                    VStack(spacing: 6) {
                        Text("Χωρίς σύνδεση").font(.headline)
                        Button("Ξανά") { Task { await load() } }
                    }
                } else { ProgressView() }
            }
        }
        .navigationTitle("AEK Hub")
        .navigationDestination(for: Int.self) { WatchMatchView(id: $0) }
        .navigationDestination(for: PostCard.self) { WatchPostView(card: $0) }
        .task {
            await load()
            while !Task.isCancelled {
                let live = list?.items.contains { $0.live } == true
                try? await Task.sleep(nanoseconds: (live ? 15 : 120) * 1_000_000_000)
                await load()
            }
        }
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

/// Η μεγάλη κάρτα: live σκορ ή αντίστροφη μέτρηση
struct WatchHero: View {
    let m: MatchCard
    var body: some View {
        VStack(spacing: 4) {
            Text(m.live ? "LIVE" : "ΕΠΟΜΕΝΟΣ").font(.system(size: 11, weight: .heavy)).foregroundStyle(m.live ? C.live : C.gold)
            HStack {
                TeamLogo(url: m.homeLogo, size: 30)
                Spacer()
                if m.live || m.hasScore {
                    Text("\(m.scoreHome)–\(m.scoreAway)").font(.system(size: 28, weight: .heavy).width(.condensed)).monospacedDigit()
                } else {
                    Text(m.time).font(.system(size: 22, weight: .heavy).width(.condensed))
                }
                Spacer()
                TeamLogo(url: m.awayLogo, size: 30)
            }
            Text("\(m.home) – \(m.away)").font(.system(size: 12, weight: .semibold)).lineLimit(1).minimumScaleFactor(0.7)
            if m.live {
                TimelineView(.periodic(from: .now, by: 15)) { ctx in
                    Text(liveMinute(m.clock, fallback: m.minute.isEmpty ? m.statusLabel : m.minute, now: ctx.date)).font(.system(size: 12, weight: .bold)).foregroundStyle(C.live)
                }
            } else if let ko = m.kickoffDate, ko > Date() {
                Text(ko, style: .relative).font(.system(size: 12, weight: .bold)).foregroundStyle(C.gold).multilineTextAlignment(.center)
                Text(Fmt.shortDay(m.date)).font(.system(size: 11)).foregroundStyle(C.muted)
            }
        }
        .padding(.vertical, 6)
        .frame(maxWidth: .infinity)
    }
}

struct WatchMatchRow: View {
    let m: MatchCard
    var body: some View {
        HStack(spacing: 6) {
            VStack(alignment: .leading, spacing: 2) {
                Text(m.home).lineLimit(1)
                Text(m.away).lineLimit(1)
            }.font(.system(size: 13, weight: .semibold))
            Spacer(minLength: 2)
            if m.upcoming && !m.hasScore {
                VStack(alignment: .trailing, spacing: 1) {
                    Text(m.time).font(.system(size: 13, weight: .bold)).foregroundStyle(C.gold)
                    Text(Fmt.shortDay(m.date)).font(.system(size: 10)).foregroundStyle(C.muted)
                }
            } else {
                VStack(alignment: .trailing, spacing: 2) {
                    Text(m.scoreHome); Text(m.scoreAway)
                }.font(.system(size: 15, weight: .heavy)).monospacedDigit().foregroundStyle(m.live ? C.gold : C.text)
            }
        }
    }
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
                    Text(c.competition).font(.system(size: 11)).foregroundStyle(C.muted).lineLimit(1)
                    WatchHero(m: c)
                    if !d.scorersHome.isEmpty || !d.scorersAway.isEmpty {
                        HStack(alignment: .top) {
                            VStack(alignment: .leading) { ForEach(d.scorersHome, id: \.self) { Text($0) } }
                            Spacer()
                            VStack(alignment: .trailing) { ForEach(d.scorersAway, id: \.self) { Text($0) } }
                        }.font(.system(size: 11)).foregroundStyle(C.text2)
                    }
                    let evs = d.groups.isEmpty ? d.events : d.groups.flatMap(\.events)
                    ForEach(Array(evs.prefix(25).enumerated()), id: \.offset) { _, e in
                        HStack(alignment: .top, spacing: 6) {
                            Text(e.minute).font(.system(size: 11, weight: .bold)).foregroundStyle(C.gold).frame(width: 30, alignment: .trailing)
                            Text(eventIconW(e.type)).font(.system(size: 11))
                            VStack(alignment: .leading, spacing: 1) {
                                Text(e.label).font(.system(size: 12, weight: .semibold))
                                if !e.text.isEmpty { Text(e.text).font(.system(size: 11)).foregroundStyle(C.text2) }
                            }
                            Spacer(minLength: 0)
                        }
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

struct WatchPostView: View {
    let card: PostCard
    @State private var post: Post?
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 8) {
                NetImage(url: card.image, w: 400).frame(height: 90).frame(maxWidth: .infinity).clipped().clipShape(RoundedRectangle(cornerRadius: 8))
                Text(card.title).font(.system(size: 15, weight: .bold))
                Text(Fmt.ago(card.date)).font(.system(size: 11)).foregroundStyle(C.muted)
                if let p = post { Text(p.html.plainText).font(.system(size: 13)) }
                else if !card.excerpt.isEmpty { Text(card.excerpt).font(.system(size: 13)).foregroundStyle(C.text2); ProgressView() }
            }
        }
        .task { post = try? await Api.shared.post(card.id) }
    }
}
