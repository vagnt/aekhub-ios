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
                        score(a, s, 44).lineLimit(1).minimumScaleFactor(0.55)
                    }
                }
                DynamicIslandExpandedRegion(.bottom) {
                    VStack(spacing: 6) {
                        if s.status != "finished" && hasClock(a) { bar(s.progress, segments(a)) }
                        HStack {
                            Text(footLine(a, s).isEmpty ? (a.venue.isEmpty ? " " : a.venue) : footLine(a, s)).font(.system(size: 13)).foregroundStyle(.white.opacity(0.8)).lineLimit(1)
                            Spacer()
                            Text(a.competition).font(.system(size: 13)).foregroundStyle(.white.opacity(0.6)).lineLimit(1)
                        }
                    }.padding(.horizontal, 8)
                }
            } compactLeading: {
                // Μαζεμένο Dynamic Island + μπάρα του Mac: σήμα + σκορ γηπεδούχου … σκορ + σήμα φιλοξενούμενου (όπως Apple Sports)
                HStack(spacing: 5) {
                    crest(a.home, a.aek == "home", 20)
                    VStack(spacing: -1) {
                        Text(s.ph ?? s.sh).font(.system(size: 15, weight: .heavy)).monospacedDigit()
                            .foregroundStyle(a.aek == "home" ? C.gold : .white)
                        compactTag(s)
                    }
                }
            } compactTrailing: {
                HStack(spacing: 5) {
                    VStack(spacing: -1) {
                        Text(s.pa ?? s.sa).font(.system(size: 15, weight: .heavy)).monospacedDigit()
                            .foregroundStyle(a.aek == "away" ? C.gold : .white)
                        compactTag(s, right: true)
                    }
                    crest(a.away, a.aek == "away", 20)
                }
            } minimal: {
                crest(a.aek == "away" ? a.away : a.home, true, 22)
            }
            .widgetURL(URL(string: "aekhub://match/\(a.matchId)"))
            .keylineTint(C.gold)
    }

    @ViewBuilder static func status(_ s: LiveMatchAttributes.ContentState) -> some View {
        if s.status == "finished" { Text("ΤΕΛΙΚΟ").font(.system(size: 12, weight: .heavy)).foregroundStyle(C.gold) }
        else {
            HStack(spacing: 4) {
                Circle().fill(C.live).frame(width: 7, height: 7)
                Text("LIVE").font(.system(size: 12, weight: .heavy)).foregroundStyle(C.live)
            }
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

/// Apple Watch / CarPlay (μικρή οθόνη): σήματα στις άκρες, ΕΝΑ κείμενο σκορ στη μέση που μικραίνει αν δεν χωράει.
/// Βόλεϊ: τα σετ (μόνο ο αριθμός, σε κουτάκι) κάτω από κάθε σήμα (όχι δίπλα στο σκορ — εκεί δεν χωρούσαν και έκοβαν τους πόντους).
struct SmallView: View {
    let a: LiveMatchAttributes
    let s: LiveMatchAttributes.ContentState
    var body: some View {
        VStack(spacing: 3) {
            HStack(spacing: 4) {
                side(a.home, a.aek == "home", s.ph != nil ? s.sh : nil)
                Spacer(minLength: 0)
                (Text(s.ph ?? s.sh).foregroundColor(a.aek == "home" ? C.gold : .white)
                 + Text("–").foregroundColor(.white.opacity(0.4))
                 + Text(s.pa ?? s.sa).foregroundColor(a.aek == "away" ? C.gold : .white))
                    .font(F.disp(32)).monospacedDigit()
                    .lineLimit(1).minimumScaleFactor(0.5).layoutPriority(1)
                Spacer(minLength: 0)
                side(a.away, a.aek == "away", s.ph != nil ? s.sa : nil)
            }
            Group {
                if s.status == "finished" { Text("ΤΕΛΙΚΟ").foregroundStyle(C.gold) }
                else if isBreak(s) { Text(stage(a, s) ?? "ΗΜΙΧΡΟΝΟ").foregroundStyle(C.gold) }
                else {
                    // ίδια λογική με τη μεγάλη οθόνη, σε μικρό: φάση (κίτρινο) + λεπτό όσο τρέχει
                    HStack(spacing: 4) {
                        Circle().fill(C.live).frame(width: 6, height: 6)
                        if let st = shortStage(a, s) { Text(st).foregroundStyle(C.gold) }
                        if s.per == nil { minuteText(s).foregroundStyle(.white) }
                    }
                }
            }
            .font(.system(size: 12, weight: .heavy)).lineLimit(1)
        }
        .padding(.horizontal, 8).padding(.vertical, 6)
    }
    /// Σήμα + από κάτω: τα σετ (βόλεϊ) ή τα 3 πρώτα γράμματα
    @ViewBuilder func side(_ n: String, _ aek: Bool, _ sets: String?) -> some View {
        VStack(spacing: 2) {
            crest(n, aek, 28)
            if let sets {
                setBadge(sets, aek, 30) // μόνο ο αριθμός σε κουτάκι, όπως στη μεγάλη οθόνη
            } else {
                Text(String(n.upperGr.prefix(3))).font(.system(size: 10, weight: .heavy)).foregroundStyle(aek ? C.gold : .white.opacity(0.85))
            }
        }
        .frame(width: 40)
    }
}

/// Πολύ μικρή ένδειξη κάτω από το σκορ στο μαζεμένο Dynamic Island: αριστερά λεπτό/σετ (κόκκινο), δεξιά τα σετ στο βόλεϊ
@ViewBuilder func compactTag(_ s: LiveMatchAttributes.ContentState, right: Bool = false) -> some View {
    let t: Text = {
        if s.status == "finished" { return Text(right ? "" : "ΤΕΛ").foregroundColor(C.gold) }
        if ["halftime", "ht", "break", "eth"].contains(s.status) { return Text(right ? "" : "ΗΜ").foregroundColor(C.gold) }
        if right { return Text(s.ph != nil ? "σετ \(s.sh)–\(s.sa)" : "").foregroundColor(.white.opacity(0.6)) }
        if let per = s.per { return Text(per.replacingOccurrences(of: "ΣΕΤ ", with: "Σ")).foregroundColor(C.live) }
        if s.status.count == 2, s.status.hasPrefix("q") { return Text("Q" + s.status.dropFirst()).foregroundColor(C.live) }
        if s.status == "ot" { return Text("ΠΑΡ").foregroundColor(C.live) }
        return minuteText(s).foregroundColor(C.live)
    }()
    t.font(.system(size: 8, weight: .heavy)).lineLimit(1).frame(maxWidth: 34)
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
        if let st = stage(a, s) { Text(st).font(.system(size: max(9, size * 0.22), weight: .heavy)).tracking(0.8).foregroundStyle(C.gold).lineLimit(1).minimumScaleFactor(0.7) }
        HStack(spacing: size * 0.16) {
            if s.ph != nil { setBadge(s.sh, a.aek == "home", size) }
            Text(s.ph ?? s.sh).foregroundStyle(a.aek == "home" ? C.gold : .white)
            Text("–").foregroundStyle(.white.opacity(0.35))
            Text(s.pa ?? s.sa).foregroundStyle(a.aek == "away" ? C.gold : .white)
            if s.ph != nil { setBadge(s.sa, a.aek == "away", size) }
        }
        .font(F.disp(size)).monospacedDigit()
        // ⏱ λεπτό/χρόνος στο κέντρο, κάτω από το σκορ (πάνω δεξιά μένει μόνο το LIVE — ζήτησε ο χρήστης)
        if s.status != "finished" && s.per == nil && !isBreak(s) && hasClock(a) {
            minuteText(s).font(.system(size: max(10, size * 0.27), weight: .heavy)).monospacedDigit()
                .foregroundStyle(.white).lineLimit(1).minimumScaleFactor(0.7)
        }
    }
}

/// 🏐 Σετ δίπλα στους πόντους (μικρό κουτάκι)
func setBadge(_ v: String, _ aek: Bool, _ size: CGFloat) -> some View {
    Text(v).font(F.disp(size * 0.5)).monospacedDigit()
        .foregroundStyle(aek ? C.ink : .white)
        .frame(minWidth: size * 0.5).padding(.vertical, 1)
        .background(RoundedRectangle(cornerRadius: 5).fill(aek ? C.gold : Color.white.opacity(0.18)))
}

/// Φάση πάνω από το σκορ — ΙΔΙΑ λογική σε όλα τα αθλήματα (ζήτησε ο χρήστης, όπως το «ΣΕΤ 2» του βόλεϊ)
func stage(_ a: LiveMatchAttributes, _ s: LiveMatchAttributes.ContentState) -> String? {
    if let per = s.per { return per }
    let wp = a.sport == "waterpolo"
    switch s.status {
    case "finished", "upcoming", "postponed": return nil
    case "prematch": return "ΣΕ ΛΙΓΟ Η ΕΝΑΡΞΗ"
    case "q1", "q2", "q3", "q4":
        let n = s.status.dropFirst()
        return wp ? "\(n)η ΠΕΡΙΟΔΟΣ" : "\(n)ο ΔΕΚΑΛΕΠΤΟ"
    case "ot": return "ΠΑΡΑΤΑΣΗ"
    case "halftime", "ht", "break": return ["basketball", "waterpolo"].contains(a.sport) ? "ΔΙΑΛΕΙΜΜΑ" : "ΗΜΙΧΡΟΝΟ"
    case "live": return ["basketball", "waterpolo"].contains(a.sport) ? nil : "1ο ΗΜΙΧΡΟΝΟ"
    case "live2": return "2ο ΗΜΙΧΡΟΝΟ"
    case "et1": return "1η ΠΑΡΑΤΑΣΗ"
    case "eth": return "ΔΙΑΛΕΙΜΜΑ ΠΑΡΑΤΑΣΗΣ"
    case "et2": return "2η ΠΑΡΑΤΑΣΗ"
    case "penalties": return "ΠΕΝΑΛΤΙ"
    default: return nil
    }
}

/// Σύντομη φάση για ρολόι / CarPlay (λίγος χώρος)
func shortStage(_ a: LiveMatchAttributes, _ s: LiveMatchAttributes.ContentState) -> String? {
    if let per = s.per { return per }
    switch s.status {
    case "q1", "q2", "q3", "q4": return (a.sport == "waterpolo" ? "Π" : "Q") + s.status.dropFirst()
    case "live": return ["basketball", "waterpolo"].contains(a.sport) ? nil : "1ο ΗΜ"
    case "live2": return "2ο ΗΜ"
    case "et1", "et2", "ot": return "ΠΑΡ"
    default: return nil
    }
}

/// Διάλειμμα: δεν δείχνουμε λεπτό πάνω δεξιά (η φάση φαίνεται πάνω από το σκορ)
func isBreak(_ s: LiveMatchAttributes.ContentState) -> Bool { ["halftime", "ht", "break", "eth", "penalties", "prematch"].contains(s.status) }

/// Μπάρα χρόνου μόνο σε αθλήματα με ρολόι (όχι βόλεϊ)
func hasClock(_ a: LiveMatchAttributes) -> Bool { a.sport != "volleyball" }

/// Κάτω γραμμή: σκορ ανά σετ/περίοδο (βόλεϊ πάντα, τα άλλα στο τελικό) αλλιώς τελευταίο γεγονός
func footLine(_ a: LiveMatchAttributes, _ s: LiveMatchAttributes.ContentState) -> String {
    if !s.periods.isEmpty && (a.sport == "volleyball" || s.status == "finished") { return s.periods.joined(separator: " · ") }
    return s.last
}

/// Τμήματα της μπάρας: μπάσκετ/πόλο 4 περίοδοι, τα άλλα 2 ημίχρονα
func segments(_ a: LiveMatchAttributes) -> Int { ["basketball", "waterpolo"].contains(a.sport) ? 4 : 2 }

/// Μπάρα χρόνου χωρισμένη ανά περίοδο/ημίχρονο: σήμα (ρόμβος) στο τέλος κάθε περιόδου,
/// χρυσό όταν έχει περάσει, και φωτεινή «κεφαλή» στο σημείο που βρίσκεται ο αγώνας.
func bar(_ p: Double, _ n: Int = 2) -> some View {
    let p = max(0, min(1, p)), gap: CGFloat = 4
    return GeometryReader { g in
        let w = g.size.width, seg = (w - gap * CGFloat(n - 1)) / CGFloat(n)
        ZStack(alignment: .leading) {
            ForEach(0..<n, id: \.self) { i in
                let f = max(0, min(1, p * Double(n) - Double(i)))
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.white.opacity(0.13))
                    Capsule().fill(C.goldGrad).frame(width: seg * CGFloat(f)).opacity(f > 0 ? 1 : 0)
                }
                .frame(width: seg, height: 4)
                .offset(x: CGFloat(i) * (seg + gap))
            }
            // σήματα τέλους περιόδου / ημιχρόνου
            ForEach(1..<n, id: \.self) { i in
                let done = p >= Double(i) / Double(n) - 0.0001
                RoundedRectangle(cornerRadius: 1.5)
                    .fill(done ? C.gold : Color(white: 0.22))
                    .overlay(RoundedRectangle(cornerRadius: 1.5).stroke(done ? Color.white.opacity(0.55) : Color.white.opacity(0.35), lineWidth: 1))
                    .frame(width: 7, height: 7).rotationEffect(.degrees(45))
                    .shadow(color: done ? C.gold.opacity(0.7) : .clear, radius: 3)
                    .offset(x: CGFloat(i) * (seg + gap) - gap / 2 - 3.5)
            }
            // κεφαλή προόδου
            if p > 0 && p < 1 && abs(p * Double(n) - (p * Double(n)).rounded()) > 0.01 {
                let i = min(n - 1, Int(p * Double(n))), f = p * Double(n) - Double(i)
                Circle().fill(Color.white).frame(width: 6, height: 6)
                    .shadow(color: C.gold, radius: 4)
                    .offset(x: CGFloat(i) * (seg + gap) + seg * CGFloat(f) - 3)
            }
        }.frame(height: 10)
    }.frame(height: 10)
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
                    }
                }
            }
            HStack {
                VStack(spacing: 4) { crest(a.home, a.aek == "home", 42); name(a.home, a.aek == "home") }.frame(minWidth: 60, maxWidth: 90)
                Spacer(minLength: 4)
                score(a, s, 52).lineLimit(1).minimumScaleFactor(0.55).layoutPriority(1)
                Spacer(minLength: 4)
                VStack(spacing: 4) { crest(a.away, a.aek == "away", 42); name(a.away, a.aek == "away") }.frame(minWidth: 60, maxWidth: 90)
            }
            if s.status != "finished" && hasClock(a) { bar(s.progress, segments(a)) }
            HStack {
                Text(footLine(a, s).isEmpty ? (a.venue.isEmpty ? " " : a.venue) : footLine(a, s)).font(.system(size: 13)).foregroundStyle(.white.opacity(0.75)).lineLimit(1)
                Spacer()
            }
        }
        .padding(16)
    }
}
