import WidgetKit
import SwiftUI
import ActivityKit

/// Live Activity αγώνα: κλειδωμένη οθόνη + Dynamic Island (σχέδιο «Live Activity — Κλειδωμένη οθόνη / Dynamic Island»)
struct LiveMatchWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: LiveMatchAttributes.self) { ctx in
            AdaptiveView(a: ctx.attributes, s: ctx.state)
                .activityBackgroundTint(Color.black.opacity(0.78))
                .activitySystemActionForegroundColor(C.gold)
                .widgetURL(URL(string: "aekhub://match/\(ctx.attributes.matchId)"))
        } dynamicIsland: { ctx in
            Self.island(ctx)
        }
        .smallFamilyIfAvailable()
    }

    static func island(_ ctx: ActivityViewContext<LiveMatchAttributes>) -> DynamicIsland {
            let a = ctx.attributes, s = ctx.state
            return DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    VStack(spacing: 4) { crest(a.home, a.aek == "home", 40); name(a.home, a.aek == "home") }.padding(.leading, 6)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    VStack(spacing: 4) { crest(a.away, a.aek == "away", 40); name(a.away, a.aek == "away") }.padding(.trailing, 6)
                }
                DynamicIslandExpandedRegion(.center) {
                    VStack(spacing: 2) {
                        Self.status(s)
                        score(a, s, 44)
                    }
                }
                DynamicIslandExpandedRegion(.bottom) {
                    VStack(spacing: 6) {
                        if s.status != "finished" && hasClock(a) { bar(s.progress) }
                        HStack {
                            Text(footLine(a, s).isEmpty ? s.phase : footLine(a, s)).font(.system(size: 13)).foregroundStyle(.white.opacity(0.8)).lineLimit(1)
                            Spacer()
                            Text(a.competition).font(.system(size: 13)).foregroundStyle(.white.opacity(0.6)).lineLimit(1)
                        }
                    }.padding(.horizontal, 8)
                }
            } compactLeading: {
                Image("HubLogo").resizable().scaledToFit().frame(width: 22, height: 22).clipShape(Circle())
            } compactTrailing: {
                HStack(spacing: 4) {
                    Text("\(s.ph ?? s.sh)–\(s.pa ?? s.sa)").font(.system(size: 15, weight: .heavy)).foregroundStyle(s.goal ? C.gold : .white).monospacedDigit()
                    if s.status != "finished" { minuteText(s).font(.system(size: 12, weight: .bold)).foregroundStyle(C.live).lineLimit(1).frame(maxWidth: 44) }
                }
            } minimal: {
                Image("HubLogo").resizable().scaledToFit().frame(width: 22, height: 22).clipShape(Circle())
            }
            .widgetURL(URL(string: "aekhub://match/\(a.matchId)"))
            .keylineTint(C.gold)
    }

    @ViewBuilder static func status(_ s: LiveMatchAttributes.ContentState) -> some View {
        if s.status == "finished" { Text("ΤΕΛΙΚΟ").font(.system(size: 12, weight: .heavy)).foregroundStyle(C.gold) }
        else if ["halftime", "ht", "break", "eth"].contains(s.status) { Text("ΗΜΙΧΡΟΝΟ").font(.system(size: 12, weight: .heavy)).foregroundStyle(C.gold) }
        else {
            HStack(spacing: 4) { Circle().fill(C.live).frame(width: 7, height: 7); minuteText(s).font(.system(size: 13, weight: .bold)).foregroundStyle(.white).frame(maxWidth: 52) }
        }
    }
}

/// iOS 18+: μικρή εμφάνιση (.small) για Apple Watch (Smart Stack) και CarPlay, με τα λογότυπα.
extension WidgetConfiguration {
    func smallFamilyIfAvailable() -> some WidgetConfiguration {
        if #available(iOS 18.0, *) { return self.supplementalActivityFamilies([.small, .medium]) }
        else { return self }
    }
}

struct AdaptiveView: View {
    let a: LiveMatchAttributes
    let s: LiveMatchAttributes.ContentState
    var body: some View {
        if #available(iOS 18.0, *) { FamilyView(a: a, s: s) } else { LockView(a: a, s: s) }
    }
}

@available(iOS 18.0, *)
struct FamilyView: View {
    @Environment(\.activityFamily) var family
    let a: LiveMatchAttributes
    let s: LiveMatchAttributes.ContentState
    var body: some View {
        if family == .small { SmallView(a: a, s: s) } else { LockView(a: a, s: s) }
    }
}

/// Apple Watch / CarPlay: δύο σήματα, σκορ, λεπτό
struct SmallView: View {
    let a: LiveMatchAttributes
    let s: LiveMatchAttributes.ContentState
    var body: some View {
        VStack(spacing: 4) {
            HStack(spacing: 6) {
                VStack(spacing: 2) { crest(a.home, a.aek == "home", 30); short(a.home, a.aek == "home") }
                Spacer(minLength: 2)
                score(a, s, 34).lineLimit(1).minimumScaleFactor(0.6)
                Spacer(minLength: 2)
                VStack(spacing: 2) { crest(a.away, a.aek == "away", 30); short(a.away, a.aek == "away") }
            }
            Group {
                if s.status == "finished" { Text("ΤΕΛΙΚΟ").foregroundStyle(C.gold) }
                else if ["halftime", "ht", "break", "eth"].contains(s.status) { Text("ΗΜΙΧΡΟΝΟ").foregroundStyle(C.gold) }
                else { HStack(spacing: 4) { Circle().fill(C.live).frame(width: 6, height: 6); minuteText(s).foregroundStyle(.white) } }
            }
            .font(.system(size: 12, weight: .heavy)).lineLimit(1)
        }
        .padding(.horizontal, 8).padding(.vertical, 6)
    }
    func short(_ n: String, _ aek: Bool) -> some View {
        Text(String(n.upperGr.prefix(3))).font(.system(size: 10, weight: .heavy)).foregroundStyle(aek ? C.gold : .white.opacity(0.85))
    }
}

/// Λεπτό αγώνα: με `clk` «τρέχει» μόνο του (67:12) ακόμα και χωρίς νέο push· αλλιώς το κείμενο της πηγής.
func minuteText(_ s: LiveMatchAttributes.ContentState) -> Text {
    if let z = s.clk, !["finished", "halftime", "eth", "penalties"].contains(s.status), z > 0 {
        return Text(Date(timeIntervalSince1970: z), style: .timer).monospacedDigit()
    }
    return Text(s.minute)
}

func crest(_ n: String, _ aek: Bool, _ size: CGFloat) -> some View {
    ZStack {
        if let img = LiveLogos.image(n) { Image(uiImage: img).resizable().scaledToFit() }
        else if aek { Image("HubLogo").resizable().scaledToFit().clipShape(Circle()) }
        else { Circle().fill(Color.white.opacity(0.12)); Text(String(n.upperGr.prefix(3))).font(.system(size: size * 0.3, weight: .heavy)).foregroundStyle(.white) }
    }.frame(width: size, height: size)
}

func name(_ n: String, _ aek: Bool) -> some View {
    Text(n.upperGr).font(F.disp(14)).foregroundStyle(aek ? C.gold : .white).lineLimit(1).minimumScaleFactor(0.6)
}

func score(_ a: LiveMatchAttributes, _ s: LiveMatchAttributes.ContentState, _ size: CGFloat) -> some View {
    VStack(spacing: 0) {
        if let per = s.per { Text(per).font(.system(size: max(9, size * 0.22), weight: .heavy)).tracking(0.8).foregroundStyle(C.gold) }
        HStack(spacing: size * 0.16) {
            if s.ph != nil { setBadge(s.sh, a.aek == "home", size) }
            Text(s.ph ?? s.sh).foregroundStyle(a.aek == "home" ? C.gold : .white)
            Text("–").foregroundStyle(.white.opacity(0.35))
            Text(s.pa ?? s.sa).foregroundStyle(a.aek == "away" ? C.gold : .white)
            if s.ph != nil { setBadge(s.sa, a.aek == "away", size) }
        }
        .font(F.disp(size)).monospacedDigit()
    }
}

/// 🏐 Σετ δίπλα στους πόντους (μικρό κουτάκι)
func setBadge(_ v: String, _ aek: Bool, _ size: CGFloat) -> some View {
    Text(v).font(F.disp(size * 0.5)).monospacedDigit()
        .foregroundStyle(aek ? C.ink : .white)
        .frame(minWidth: size * 0.5).padding(.vertical, 1)
        .background(RoundedRectangle(cornerRadius: 5).fill(aek ? C.gold : Color.white.opacity(0.18)))
}

/// Μπάρα χρόνου μόνο σε αθλήματα με ρολόι (όχι βόλεϊ)
func hasClock(_ a: LiveMatchAttributes) -> Bool { a.sport != "volleyball" }

/// Κάτω γραμμή: σκορ ανά σετ/περίοδο (βόλεϊ πάντα, τα άλλα στο τελικό) αλλιώς τελευταίο γεγονός
func footLine(_ a: LiveMatchAttributes, _ s: LiveMatchAttributes.ContentState) -> String {
    if !s.periods.isEmpty && (a.sport == "volleyball" || s.status == "finished") { return s.periods.joined(separator: " · ") }
    return s.last
}

func bar(_ p: Double) -> some View {
    GeometryReader { g in
        ZStack(alignment: .leading) {
            Capsule().fill(Color.white.opacity(0.15))
            Capsule().fill(C.goldGrad).frame(width: g.size.width * CGFloat(max(0, min(1, p))))
        }
    }.frame(height: 5)
}

/// Κλειδωμένη οθόνη
struct LockView: View {
    let a: LiveMatchAttributes
    let s: LiveMatchAttributes.ContentState
    var body: some View {
        VStack(spacing: 10) {
            HStack(spacing: 8) {
                Image("HubLogo").resizable().scaledToFit().frame(width: 20, height: 20).clipShape(RoundedRectangle(cornerRadius: 5))
                Text(a.competition.upperGr).font(.system(size: 12, weight: .bold)).tracking(0.8).foregroundStyle(.white.opacity(0.75)).lineLimit(1)
                Spacer()
                if s.status == "finished" { Text("ΤΕΛΙΚΟ").font(.system(size: 13, weight: .heavy)).foregroundStyle(C.gold) }
                else {
                    HStack(spacing: 5) {
                        Circle().fill(C.live).frame(width: 8, height: 8)
                        Text("LIVE").font(.system(size: 13, weight: .heavy)).foregroundStyle(C.live)
                        minuteText(s).font(.system(size: 14, weight: .heavy)).foregroundStyle(.white).frame(maxWidth: 56)
                    }
                }
            }
            HStack {
                VStack(spacing: 4) { crest(a.home, a.aek == "home", 42); name(a.home, a.aek == "home") }.frame(width: 90)
                Spacer()
                score(a, s, 52)
                Spacer()
                VStack(spacing: 4) { crest(a.away, a.aek == "away", 42); name(a.away, a.aek == "away") }.frame(width: 90)
            }
            if s.status != "finished" && hasClock(a) { bar(s.progress) }
            HStack {
                Text(footLine(a, s).isEmpty ? (a.venue.isEmpty ? " " : a.venue) : footLine(a, s)).font(.system(size: 13)).foregroundStyle(.white.opacity(0.75)).lineLimit(1)
                Spacer()
                Text(s.phase).font(.system(size: 13)).foregroundStyle(.white.opacity(0.75)).lineLimit(1)
            }
        }
        .padding(16)
    }
}
