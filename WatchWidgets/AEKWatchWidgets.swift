import WidgetKit
import SwiftUI

// Complications Apple Watch: ο επόμενος αγώνας (αντίστροφη μέτρηση) ή το live σκορ, πάνω στο καντράν.

@main
struct AEKWatchWidgets: WidgetBundle {
    var body: some Widget { WatchMatchComplication() }
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
