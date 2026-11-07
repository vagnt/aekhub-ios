import WidgetKit
import SwiftUI
import UIKit

// Widgets iPhone/iPad: ⚽ Αγώνας (και οθόνη κλειδώματος) · 📅 Πρόγραμμα · 📰 Νέα · 🏆 Βαθμολογία.
// Τα widgets φέρνουν μόνα τους τα δεδομένα από το aekhub.gr (ίδιο API με το app).

@main
struct AEKWidgets: WidgetBundle {
    var body: some Widget {
        MatchWidget()
        ScheduleWidget()
        NewsWidget()
        StandingsWidget()
        if #available(iOS 18.0, *) { LiveMatchWidget18() } else { LiveMatchWidget() }
    }
}

// MARK: - Βοηθητικά

enum WImg {
    static func load(_ s: String, w: Int) async -> UIImage? {
        guard let u = Img.url(s, w: w), let (d, _) = try? await URLSession.shared.data(from: u) else { return nil }
        guard let img = UIImage(data: d) else { return nil }
        // μικρό, για να χωράει στο όριο μνήμης των widgets
        let maxSide = CGFloat(w)
        let k = min(1, maxSide / max(img.size.width, img.size.height))
        if k >= 1 { return img }
        let sz = CGSize(width: img.size.width * k, height: img.size.height * k)
        return UIGraphicsImageRenderer(size: sz).image { _ in img.draw(in: CGRect(origin: .zero, size: sz)) }
    }
}

extension View {
    @ViewBuilder func widgetBG(_ c: Color = C.ink) -> some View {
        if #available(iOSApplicationExtension 17.0, *) { containerBackground(for: .widget) { c } }
        else { background(c) }
    }
}

struct LogoImg: View {
    let img: UIImage?
    var size: CGFloat
    var body: some View {
        if let img { Image(uiImage: img).resizable().scaledToFit().frame(width: size, height: size) }
        else { Circle().fill(C.panel3).frame(width: size, height: size) }
    }
}

func scoreOrTime(_ m: MatchCard) -> String {
    (m.live || m.finished || m.hasScore) ? "\(m.scoreHome)–\(m.scoreAway)" : (m.time.isEmpty ? "–" : m.time)
}
func statusText(_ m: MatchCard, _ now: Date = Date()) -> String {
    if m.live { let mn = liveMinute(m.clock, fallback: m.minute, now: now); return mn.isEmpty ? (m.statusLabel.isEmpty ? "LIVE" : m.statusLabel) : mn }
    if m.finished { return "ΤΕΛΙΚΟ" }
    if m.postponed { return "ΑΝΑΒΟΛΗ" }
    return Fmt.shortDay(m.date)
}

// MARK: - ⚽ Αγώνας (επόμενος / live)

struct MatchEntry: TimelineEntry {
    let date: Date
    let m: MatchCard?
    var homeImg: UIImage? = nil
    var awayImg: UIImage? = nil
}

struct MatchProvider: TimelineProvider {
    func placeholder(in context: Context) -> MatchEntry { MatchEntry(date: Date(), m: nil) }
    func getSnapshot(in context: Context, completion: @escaping (MatchEntry) -> Void) {
        Task { completion(await load(images: !context.family.isAccessory)) }
    }
    func getTimeline(in context: Context, completion: @escaping (Timeline<MatchEntry>) -> Void) {
        Task {
            let e = await load(images: !context.family.isAccessory)
            var next = Date().addingTimeInterval(30 * 60)
            if let m = e.m {
                if m.live { next = Date().addingTimeInterval(2 * 60) }
                else if let ko = m.kickoffDate, ko > Date() { next = min(next, ko.addingTimeInterval(60)) }
            }
            completion(Timeline(entries: [e], policy: .after(next)))
        }
    }
    func load(images: Bool) async -> MatchEntry {
        let h = (try? await Api.shared.home()) ?? Api.shared.peek(Api.pHome).map(HomeData.init)
        guard let m = h?.liveHero?.match ?? h?.next else { return MatchEntry(date: Date(), m: nil) }
        var e = MatchEntry(date: Date(), m: m)
        if images {
            async let a = WImg.load(m.homeLogo, w: 120)
            async let b = WImg.load(m.awayLogo, w: 120)
            e.homeImg = await a; e.awayImg = await b
        }
        return e
    }
}

extension WidgetFamily {
    var isAccessory: Bool {
        if #available(iOSApplicationExtension 16.0, *) { return self == .accessoryCircular || self == .accessoryRectangular || self == .accessoryInline }
        return false
    }
}

struct MatchWidgetView: View {
    @Environment(\.widgetFamily) var family
    let e: MatchEntry
    var body: some View {
        Group {
            if let m = e.m {
                switch family {
                case .accessoryInline: inline(m)
                case .accessoryCircular: circular(m)
                case .accessoryRectangular: rect(m)
                case .systemMedium: medium(m)
                default: small(m)
                }
            } else {
                VStack(spacing: 6) { Image(systemName: "soccerball"); Text("Κανένας αγώνας").font(.caption2) }.foregroundStyle(C.muted)
            }
        }
        .widgetURL(URL(string: e.m.map { "aekhub://match/\($0.id)" } ?? "aekhub://matches"))
        .widgetBG(family.isAccessory ? .clear : C.ink)
    }

    func inline(_ m: MatchCard) -> some View {
        if m.live || m.finished { return Text("\(Sports.emoji(m.sport)) \(m.home) \(m.scoreHome)–\(m.scoreAway) \(m.away)") }
        return Text("\(Sports.emoji(m.sport)) \(m.home)–\(m.away) \(Fmt.shortDay(m.date)) \(m.time)")
    }

    @ViewBuilder func circular(_ m: MatchCard) -> some View {
        ZStack {
            AccessoryWidgetBackground()
            VStack(spacing: 0) {
                Text(Sports.emoji(m.sport)).font(.system(size: 11))
                if m.live || m.finished || m.hasScore {
                    Text("\(m.scoreHome)–\(m.scoreAway)").font(.system(size: 15, weight: .heavy)).minimumScaleFactor(0.6)
                } else if let ko = m.kickoffDate, ko > Date(), ko.timeIntervalSinceNow < 86400 {
                    Text(ko, style: .timer).font(.system(size: 11, weight: .bold)).multilineTextAlignment(.center).minimumScaleFactor(0.5)
                } else {
                    Text(m.time).font(.system(size: 14, weight: .heavy))
                }
            }
        }
    }

    func rect(_ m: MatchCard) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(m.live ? "🔴 LIVE · \(statusText(m))" : "\(Sports.emoji(m.sport)) \(m.competition)").font(.system(size: 11, weight: .semibold)).lineLimit(1)
            HStack {
                Text(m.home).lineLimit(1); Spacer(); if m.live || m.hasScore { Text(m.scoreHome).fontWeight(.heavy) }
            }.font(.system(size: 14, weight: .semibold))
            HStack {
                Text(m.away).lineLimit(1); Spacer(); if m.live || m.hasScore { Text(m.scoreAway).fontWeight(.heavy) }
            }.font(.system(size: 14, weight: .semibold))
            if !(m.live || m.hasScore), let ko = m.kickoffDate {
                (Text("\(Fmt.shortDay(m.date)) \(m.time) · σε ") + Text(ko, style: .relative)).font(.system(size: 11)).lineLimit(1)
            }
        }
    }

    func small(_ m: MatchCard) -> some View {
        VStack(spacing: 6) {
            Text(m.live ? "● LIVE · \(statusText(m))" : (m.finished ? "ΤΕΛΙΚΟ" : "ΕΠΟΜΕΝΟΣ ΑΓΩΝΑΣ")).font(F.tag(10)).tracking(0.8).foregroundStyle(m.live ? C.live : C.gold).lineLimit(1)
            HStack {
                LogoImg(img: e.homeImg, size: 40)
                Spacer()
                if !(m.live || m.hasScore) { Text("VS").font(F.body(12, .bold)).foregroundStyle(C.muted) }
                Spacer()
                LogoImg(img: e.awayImg, size: 40)
            }
            if m.live || m.hasScore {
                Text("\(m.scoreHome)–\(m.scoreAway)").font(F.disp(38)).foregroundStyle(m.live ? C.gold : C.text).monospacedDigit()
            } else {
                Text(m.time).font(F.disp(38)).foregroundStyle(C.gold)
                Text(Fmt.dayHeader(m.date).capitalized(with: Fmt.gr)).font(F.body(11)).foregroundStyle(C.muted).lineLimit(1).minimumScaleFactor(0.7)
            }
        }
    }

    func medium(_ m: MatchCard) -> some View {
        VStack(spacing: 8) {
            HStack {
                Text(m.live ? "🔴 LIVE" : (m.finished ? "ΤΕΛΙΚΟ" : "ΕΠΟΜΕΝΟΣ ΑΓΩΝΑΣ")).font(F.body(11, .bold)).foregroundStyle(m.live ? C.live : C.gold)
                Spacer()
                Text(Sports.emoji(m.sport) + " " + m.competition).font(F.body(10, .bold)).foregroundStyle(C.muted).lineLimit(1)
            }
            HStack(alignment: .center) {
                side(m.home, e.homeImg)
                VStack(spacing: 3) {
                    if m.live || m.hasScore {
                        Text("\(m.scoreHome)–\(m.scoreAway)").font(F.disp(40, black: true)).foregroundStyle(m.live ? C.gold : C.text)
                        Text(statusText(m)).font(F.body(11, .bold)).foregroundStyle(m.live ? C.live : C.muted)
                    } else {
                        Text(Fmt.shortDay(m.date)).font(F.body(11, .bold)).foregroundStyle(C.text2)
                        Text(m.time).font(F.disp(32, black: true)).foregroundStyle(C.text)
                        if let ko = m.kickoffDate, ko > Date(), ko.timeIntervalSinceNow < 86400 * 2 {
                            Text(ko, style: .timer).font(F.body(12, .bold)).foregroundStyle(C.gold).multilineTextAlignment(.center)
                        }
                    }
                }.frame(maxWidth: .infinity)
                side(m.away, e.awayImg)
            }
            if !m.broadcast.isEmpty { Text("📺 " + m.broadcast).font(F.body(10, .bold)).foregroundStyle(C.muted).lineLimit(1) }
        }
    }
    func side(_ n: String, _ img: UIImage?) -> some View {
        VStack(spacing: 4) {
            LogoImg(img: img, size: 40)
            Text(n.upperGr).font(F.disp(14, black: true)).foregroundStyle(C.text).lineLimit(2).multilineTextAlignment(.center).minimumScaleFactor(0.7)
        }.frame(width: 90)
    }
}

struct MatchWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "match", provider: MatchProvider()) { MatchWidgetView(e: $0) }
            .configurationDisplayName("Αγώνας ΑΕΚ")
            .description("Ο επόμενος αγώνας με αντίστροφη μέτρηση — ή το live σκορ.")
            .supportedFamilies([.systemSmall, .systemMedium, .accessoryCircular, .accessoryRectangular, .accessoryInline])
    }
}

// MARK: - 📅 Πρόγραμμα

struct ListEntry: TimelineEntry { let date: Date; let items: [MatchCard] }

struct ScheduleProvider: TimelineProvider {
    func placeholder(in context: Context) -> ListEntry { ListEntry(date: Date(), items: []) }
    func getSnapshot(in context: Context, completion: @escaping (ListEntry) -> Void) { Task { completion(await load()) } }
    func getTimeline(in context: Context, completion: @escaping (Timeline<ListEntry>) -> Void) {
        Task {
            let e = await load()
            let live = e.items.contains { $0.live }
            completion(Timeline(entries: [e], policy: .after(Date().addingTimeInterval(live ? 180 : 1800))))
        }
    }
    func load() async -> ListEntry {
        let l = (try? await Api.shared.matches()) ?? Api.shared.peek(Api.pMatches()).map(MatchList.init)
        let today = Fmt.ymdString(Date())
        let items = (l?.items ?? []).filter { $0.live || ($0.upcoming && $0.date >= today) }
            .sorted { ($0.live ? 0 : 1, $0.date, $0.time) < ($1.live ? 0 : 1, $1.date, $1.time) }
        return ListEntry(date: Date(), items: Array(items.prefix(8)))
    }
}

struct ScheduleView: View {
    @Environment(\.widgetFamily) var family
    let e: ListEntry
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack { Text("ΠΡΟΓΡΑΜΜΑ").font(F.body(11, .bold)).foregroundStyle(C.gold); Spacer(); Image("Logo").resizable().scaledToFit().frame(height: 14) }
            if e.items.isEmpty { Spacer(); Text("Δεν υπάρχουν προγραμματισμένοι αγώνες.").font(F.body(12, .bold)).foregroundStyle(C.muted); Spacer() }
            ForEach(e.items.prefix(family == .systemLarge ? 8 : 3)) { m in
                Link(destination: URL(string: "aekhub://match/\(m.id)")!) {
                    HStack(spacing: 8) {
                        Text(Sports.emoji(m.sport)).font(.system(size: 13))
                        VStack(alignment: .leading, spacing: 0) {
                            Text("\(m.home) – \(m.away)").font(F.body(13, .bold)).foregroundStyle(C.text).lineLimit(1)
                            Text(m.competition).font(F.body(10, .bold)).foregroundStyle(C.muted).lineLimit(1)
                        }
                        Spacer(minLength: 4)
                        VStack(alignment: .trailing, spacing: 0) {
                            Text(scoreOrTime(m)).font(F.body(13, .bold)).foregroundStyle(m.live ? C.gold : C.text)
                            Text(statusText(m)).font(F.body(10, .bold)).foregroundStyle(m.live ? C.live : C.muted)
                        }
                    }
                }
            }
            Spacer(minLength: 0)
        }
        .widgetURL(URL(string: "aekhub://matches"))
        .widgetBG()
    }
}

struct ScheduleWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "schedule", provider: ScheduleProvider()) { ScheduleView(e: $0) }
            .configurationDisplayName("Πρόγραμμα ΑΕΚ")
            .description("Οι επόμενοι αγώνες όλων των τμημάτων (και όσοι παίζονται τώρα).")
            .supportedFamilies([.systemMedium, .systemLarge])
    }
}

// MARK: - 📰 Νέα

struct NewsEntry: TimelineEntry { let date: Date; let items: [PostCard]; var imgs: [Int: UIImage] = [:] }

struct NewsProvider: TimelineProvider {
    func placeholder(in context: Context) -> NewsEntry { NewsEntry(date: Date(), items: []) }
    func getSnapshot(in context: Context, completion: @escaping (NewsEntry) -> Void) { Task { completion(await load(context.family)) } }
    func getTimeline(in context: Context, completion: @escaping (Timeline<NewsEntry>) -> Void) {
        Task { completion(Timeline(entries: [await load(context.family)], policy: .after(Date().addingTimeInterval(20 * 60)))) }
    }
    func load(_ f: WidgetFamily) async -> NewsEntry {
        let h = (try? await Api.shared.home()) ?? Api.shared.peek(Api.pHome).map(HomeData.init)
        let posts = Array((([h?.featured].compactMap { $0 }) + (h?.top ?? [])).prefix(f == .systemLarge ? 4 : 3))
        var e = NewsEntry(date: Date(), items: posts)
        for (i, p) in posts.enumerated() where i < 5 {
            if let img = await WImg.load(p.image, w: i == 0 ? 500 : 200) { e.imgs[p.id] = img }
        }
        return e
    }
}

struct NewsView: View {
    @Environment(\.widgetFamily) var family
    let e: NewsEntry
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if family == .systemLarge, let f = e.items.first {
                Link(destination: URL(string: "aekhub://post/\(f.id)")!) {
                    ZStack(alignment: .bottomLeading) {
                        if let img = e.imgs[f.id] { Image(uiImage: img).resizable().scaledToFill() } else { C.panel2 }
                        LinearGradient(colors: [.clear, .black.opacity(0.9)], startPoint: .top, endPoint: .bottom)
                        VStack(alignment: .leading, spacing: 6) {
                            if !f.category.isEmpty {
                                Text(f.category.upperGr).font(F.tag(10)).foregroundStyle(C.ink).padding(.horizontal, 8).padding(.vertical, 3).background(Capsule().fill(C.gold))
                            }
                            Text(f.title.upperGr).font(F.disp(20)).foregroundStyle(.white).lineLimit(2)
                        }.padding(14)
                    }
                    .frame(height: 175).clipped()
                }
                .padding(.horizontal, -16).padding(.top, -16)
            } else {
                HStack { Image("Logo").resizable().scaledToFit().frame(height: 14); Spacer(); Text("ΤΕΛΕΥΤΑΙΑ ΝΕΑ").font(F.tag(10)).foregroundStyle(C.gold) }
            }
            ForEach(family == .systemLarge ? Array(e.items.dropFirst().prefix(3)) : Array(e.items.prefix(3))) { p in
                Link(destination: URL(string: "aekhub://post/\(p.id)")!) {
                    HStack(alignment: .top, spacing: 10) {
                        if let img = e.imgs[p.id] { Image(uiImage: img).resizable().scaledToFill().frame(width: 58, height: 44).clipShape(RoundedRectangle(cornerRadius: 10)) }
                        VStack(alignment: .leading, spacing: 2) {
                            if !p.category.isEmpty { Text(p.category.upperGr).font(F.tag(9)).foregroundStyle(C.gold).lineLimit(1) }
                            Text(p.title).font(F.body(13, .semibold)).foregroundStyle(C.text).lineLimit(2)
                        }
                        Spacer(minLength: 0)
                    }
                }
            }
            Spacer(minLength: 0)
        }
        .widgetURL(URL(string: "aekhub://news"))
        .widgetBG()
    }
}

struct NewsWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "news", provider: NewsProvider()) { NewsView(e: $0) }
            .configurationDisplayName("Νέα AEK Hub")
            .description("Τα τελευταία άρθρα του aekhub.gr.")
            .supportedFamilies([.systemMedium, .systemLarge])
    }
}

// MARK: - 🏆 Βαθμολογία

struct StandEntry: TimelineEntry { let date: Date; let s: Standing? }

struct StandProvider: TimelineProvider {
    func placeholder(in context: Context) -> StandEntry { StandEntry(date: Date(), s: nil) }
    func getSnapshot(in context: Context, completion: @escaping (StandEntry) -> Void) { Task { completion(await load()) } }
    func getTimeline(in context: Context, completion: @escaping (Timeline<StandEntry>) -> Void) {
        Task { completion(Timeline(entries: [await load()], policy: .after(Date().addingTimeInterval(3 * 3600)))) }
    }
    func load() async -> StandEntry {
        let l = (try? await Api.shared.standings()) ?? Api.shared.peek(Api.pStandings)?["items"].list(Standing.init) ?? []
        // Το πρωτάθλημα ποδοσφαίρου (ο πρώτος πίνακας με την ΑΕΚ)
        return StandEntry(date: Date(), s: l.first { $0.rows.contains { $0.aek } } ?? l.first)
    }
}

struct StandView: View {
    @Environment(\.widgetFamily) var family
    let e: StandEntry
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            if let s = e.s {
                HStack { Text(s.title.upperGr).font(F.disp(15, black: true)).foregroundStyle(C.gold).lineLimit(1); Spacer() }
                let rows = pick(s.rows)
                ForEach(rows, id: \.self) { r in
                    HStack(spacing: 6) {
                        Text("\(r.pos)").frame(width: 18, alignment: .trailing)
                        Text(r.name).lineLimit(1)
                        Spacer()
                        Text(r.played).frame(width: 22).foregroundStyle(r.aek ? C.ink : C.muted)
                        Text(r.points).frame(width: 26).fontWeight(.heavy)
                    }
                    .font(F.body(12, r.aek ? .bold : .bold))
                    .foregroundStyle(r.aek ? C.ink : C.text)
                    .padding(.vertical, 2).padding(.horizontal, 4)
                    .background(RoundedRectangle(cornerRadius: 4).fill(r.aek ? C.gold : .clear))
                }
            } else { Text("Βαθμολογία").foregroundStyle(C.muted) }
            Spacer(minLength: 0)
        }
        .widgetURL(URL(string: "aekhub://standings"))
        .widgetBG()
    }
    /// Μεγάλο: οι 10 πρώτοι (και η ΑΕΚ αν είναι πιο κάτω) · μεσαίο: γύρω από την ΑΕΚ
    func pick(_ r: [StandingRow]) -> [StandingRow] {
        let n = family == .systemLarge ? 12 : 4
        guard let i = r.firstIndex(where: { $0.aek }) else { return Array(r.prefix(n)) }
        let start = max(0, min(i - n / 2, r.count - n))
        return Array(r[start..<min(r.count, start + n)])
    }
}

struct StandingsWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "standings", provider: StandProvider()) { StandView(e: $0) }
            .configurationDisplayName("Βαθμολογία")
            .description("Η θέση της ΑΕΚ στο πρωτάθλημα.")
            .supportedFamilies([.systemMedium, .systemLarge])
    }
}
