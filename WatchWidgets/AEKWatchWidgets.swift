import WidgetKit
import SwiftUI

// Complications Apple Watch: ο επόμενος αγώνας (αντίστροφη μέτρηση) ή το live σκορ, πάνω στο καντράν.

@main
struct AEKWatchWidgets: WidgetBundle {
    var body: some Widget {
        WatchMatchComplication()
        WatchNewsComplication()
    }
}

struct WEntry: TimelineEntry { let date: Date; let m: MatchCard? }

struct WProvider: TimelineProvider {
    func placeholder(in context: Context) -> WEntry { WEntry(date: Date(), m: nil) }
    func getSnapshot(in context: Context, completion: @escaping (WEntry) -> Void) { Task { completion(await load()) } }
    func getTimeline(in context: Context, completion: @escaping (Timeline<WEntry>) -> Void) {
        Task {
            let e = await load()
            var next = Date().addingTimeInterval(30 * 60)
            if let m = e.m {
                if m.live { next = Date().addingTimeInterval(3 * 60) }
                else if let ko = m.kickoffDate, ko > Date() { next = min(next, ko.addingTimeInterval(60)) }
            }
            completion(Timeline(entries: [e], policy: .after(next)))
        }
    }
    func load() async -> WEntry {
        let h = (try? await Api.shared.home()) ?? Api.shared.peek(Api.pHome).map(HomeData.init)
        return WEntry(date: Date(), m: h?.liveHero?.match ?? h?.next)
    }
}

struct WView: View {
    @Environment(\.widgetFamily) var family
    let e: WEntry
    var body: some View {
        Group {
            if let m = e.m {
                switch family {
                case .accessoryInline:
                    Text(m.live || m.hasScore ? "\(m.home) \(m.scoreHome)–\(m.scoreAway) \(m.away)" : "\(m.home)–\(m.away) \(m.time)")
                case .accessoryRectangular:
                    VStack(alignment: .leading, spacing: 0) {
                        Text(m.live ? "🔴 LIVE" : Sports.emoji(m.sport) + " " + Fmt.shortDay(m.date) + " " + m.time).font(.system(size: 12, weight: .bold)).foregroundStyle(m.live ? C.live : C.gold)
                        HStack { Text(m.home).lineLimit(1); Spacer(); if m.live || m.hasScore { Text(m.scoreHome).fontWeight(.heavy) } }
                        HStack { Text(m.away).lineLimit(1); Spacer(); if m.live || m.hasScore { Text(m.scoreAway).fontWeight(.heavy) } }
                    }.font(.system(size: 14, weight: .semibold))
                case .accessoryCorner:
                    Text(Sports.emoji(m.sport)).font(.system(size: 20))
                        .widgetLabel { Text(m.live || m.hasScore ? "\(m.scoreHome)–\(m.scoreAway)" : m.time) }
                default:
                    ZStack {
                        AccessoryWidgetBackground()
                        VStack(spacing: 0) {
                            Text(Sports.emoji(m.sport)).font(.system(size: 10))
                            if m.live || m.hasScore {
                                Text("\(m.scoreHome)–\(m.scoreAway)").font(.system(size: 14, weight: .heavy)).minimumScaleFactor(0.6)
                            } else if let ko = m.kickoffDate, ko > Date(), ko.timeIntervalSinceNow < 86400 {
                                Text(ko, style: .timer).font(.system(size: 10, weight: .bold)).multilineTextAlignment(.center).minimumScaleFactor(0.5)
                            } else {
                                Text(m.time).font(.system(size: 13, weight: .heavy))
                            }
                        }
                    }
                }
            } else {
                Image(systemName: "soccerball")
            }
        }
        .modifier(WBG())
    }
}

struct WBG: ViewModifier {
    func body(content: Content) -> some View {
        if #available(watchOS 10.0, *) { content.containerBackground(for: .widget) { Color.clear } }
        else { content }
    }
}

struct WatchMatchComplication: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "watchmatch", provider: WProvider()) { WView(e: $0) }
            .configurationDisplayName("Αγώνας ΑΕΚ")
            .description("Επόμενος αγώνας ή live σκορ.")
            .supportedFamilies([.accessoryCircular, .accessoryRectangular, .accessoryInline, .accessoryCorner])
    }
}

// MARK: - 📰 Τελευταίο νέο (complication)

struct NEntry: TimelineEntry { let date: Date; let p: PostCard? }

struct NProvider: TimelineProvider {
    func placeholder(in context: Context) -> NEntry { NEntry(date: Date(), p: nil) }
    func getSnapshot(in context: Context, completion: @escaping (NEntry) -> Void) { Task { completion(await load()) } }
    func getTimeline(in context: Context, completion: @escaping (Timeline<NEntry>) -> Void) {
        Task { completion(Timeline(entries: [await load()], policy: .after(Date().addingTimeInterval(20 * 60)))) }
    }
    func load() async -> NEntry {
        let h = (try? await Api.shared.home()) ?? Api.shared.peek(Api.pHome).map(HomeData.init)
        // το νεότερο άρθρο (κύριο θέμα ή «Τελευταία νέα»)
        let all = [h?.featured].compactMap { $0 } + (h?.top ?? [])
        return NEntry(date: Date(), p: all.max { $0.date < $1.date })
    }
}

struct NView: View {
    @Environment(\.widgetFamily) var family
    let e: NEntry
    var body: some View {
        Group {
            if let p = e.p {
                switch family {
                case .accessoryInline:
                    Text("📰 " + p.title)
                case .accessoryCircular:
                    ZStack {
                        AccessoryWidgetBackground()
                        VStack(spacing: 0) {
                            Image(systemName: "newspaper.fill").font(.system(size: 14))
                            Text(Fmt.ago(p.date)).font(.system(size: 9, weight: .bold)).minimumScaleFactor(0.6)
                        }
                    }
                default:
                    VStack(alignment: .leading, spacing: 1) {
                        Text("AEK HUB" + (p.category.isEmpty ? "" : " · " + p.category.upperGr)).font(.system(size: 11, weight: .heavy)).foregroundStyle(C.gold).lineLimit(1)
                        Text(p.title).font(.system(size: 13, weight: .semibold)).lineLimit(3)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            } else {
                Image(systemName: "newspaper")
            }
        }
        .widgetURL(URL(string: e.p.map { "aekhub://post/\($0.id)" } ?? "aekhub://news"))
        .modifier(WBG())
    }
}

struct WatchNewsComplication: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "watchnews", provider: NProvider()) { NView(e: $0) }
            .configurationDisplayName("Τελευταίο νέο")
            .description("Το πιο πρόσφατο άρθρο του AEK Hub.")
            .supportedFamilies([.accessoryRectangular, .accessoryInline, .accessoryCircular])
    }
}
