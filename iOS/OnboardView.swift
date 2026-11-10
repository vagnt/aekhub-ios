import SwiftUI

/// 🔔 Πρώτο άνοιγμα, μόλις ο χρήστης δεχτεί τις ειδοποιήσεις (ζήτησε ο χρήστης): «Τι θέλεις να μαθαίνεις;»
/// Τρία βήματα: αθλήματα → τι από τους αγώνες → ειδήσεις. Όλα αλλάζουν αργότερα από Εγώ → Ειδοποιήσεις.
struct OnboardView: View {
    var done: () -> Void
    @ObservedObject var p = Prefs.shared
    @ObservedObject var app = AppState.shared
    @State private var step = 0
    @State private var kinds: Set<String> = [Kinds.goals, Kinds.startend, Kinds.reminder]

    var sportList: [(String, String)] {
        let c = (app.config?.sports ?? []).map { ($0.key, $0.name) }
        return c.isEmpty ? Kinds.sports.map { ($0, Sports.label($0)) } : c
    }

    var body: some View {
        ZStack {
            LinearGradient(colors: [C.gold.opacity(0.16), C.ink, C.ink], startPoint: .top, endPoint: .center).ignoresSafeArea()
            C.ink.opacity(0.0001).ignoresSafeArea()
            VStack(spacing: 0) {
                // πρόοδος
                HStack(spacing: 6) {
                    ForEach(0..<3) { i in Capsule().fill(i <= step ? C.gold : Color.white.opacity(0.14)).frame(height: 4) }
                }
                .padding(.horizontal, 24).padding(.top, 18)

                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        switch step {
                        case 0: sportsStep
                        case 1: kindsStep
                        default: newsStep
                        }
                    }
                    .padding(.horizontal, 24).padding(.top, 26).padding(.bottom, 30)
                    .frame(maxWidth: 560).frame(maxWidth: .infinity)
                    .id(step)
                    .transition(.asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity), removal: .move(edge: .leading).combined(with: .opacity)))
                }

                HStack(spacing: 12) {
                    if step > 0 {
                        Button { haptic(.soft); withAnimation(.spring(response: 0.35)) { step -= 1 } } label: {
                            Image(systemName: "chevron.left").font(.system(size: 17, weight: .bold)).foregroundStyle(C.text)
                                .frame(width: 56, height: 56).background(Circle().fill(Color.white.opacity(0.08)))
                        }.buttonStyle(.plain)
                    }
                    Button { next() } label: {
                        Text(step < 2 ? "Συνέχεια" : "Έτοιμο").font(F.body(17, .heavy)).foregroundStyle(C.ink)
                            .frame(maxWidth: .infinity).frame(height: 56)
                            .background(Capsule().fill(C.gold))
                    }.buttonStyle(.plain)
                }
                .padding(.horizontal, 24).padding(.bottom, 14)
                .frame(maxWidth: 560)
                Button { finish() } label: { Text("Τα ρυθμίζω αργότερα").font(F.body(13, .bold)).foregroundStyle(C.muted) }
                    .buttonStyle(.plain).padding(.bottom, 10)
            }
        }
        .preferredColorScheme(.dark)
    }

    // MARK: Βήματα

    func title(_ big: String, _ small: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(big.upperGr).font(F.disp(40)).foregroundStyle(C.text).fixedSize(horizontal: false, vertical: true)
            Text(small).font(F.body(15)).foregroundStyle(C.muted).fixedSize(horizontal: false, vertical: true)
        }
    }

    var sportsStep: some View {
        VStack(alignment: .leading, spacing: 18) {
            title("Ποια ΑΕΚ ακολουθείς;", "Διάλεξε τα τμήματα για τα οποία θέλεις ειδοποιήσεις.")
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                ForEach(sportList, id: \.0) { sp in
                    let on = p.sports.contains(sp.0)
                    Button {
                        haptic(.soft)
                        if on { p.sports.remove(sp.0) } else { p.sports.insert(sp.0) }
                    } label: {
                        VStack(alignment: .leading, spacing: 10) {
                            HStack {
                                Text(Self.emoji(sp.0)).font(.system(size: 30))
                                Spacer()
                                Image(systemName: on ? "checkmark.circle.fill" : "circle").font(.system(size: 22, weight: .semibold))
                                    .foregroundStyle(on ? C.gold : C.muted)
                            }
                            Text(sp.1).font(F.body(15, .heavy)).foregroundStyle(C.text).lineLimit(2).minimumScaleFactor(0.8)
                        }
                        .padding(14).frame(maxWidth: .infinity, minHeight: 104, alignment: .topLeading)
                        .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(on ? C.gold.opacity(0.14) : C.panel))
                        .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).strokeBorder(on ? C.gold : C.line, lineWidth: on ? 1.5 : 1))
                    }.buttonStyle(.plain)
                }
            }
            Button {
                haptic(.soft)
                let all = Set(sportList.map(\.0))
                p.sports = p.sports.isSuperset(of: all) ? [] : all
            } label: {
                Text(p.sports.isSuperset(of: Set(sportList.map(\.0))) ? "Καθαρισμός" : "Όλα τα τμήματα").font(F.body(14, .heavy)).foregroundStyle(C.gold)
            }.buttonStyle(.plain)
        }
    }

    var kindsStep: some View {
        VStack(alignment: .leading, spacing: 18) {
            title("Τι θέλεις να μαθαίνεις;", "Για τους αγώνες των τμημάτων που διάλεξες.")
            VStack(spacing: 0) {
                kindRow("soccerball", "Γκολ & σκορ", "Κάθε γκολ στο ποδόσφαιρο, κάθε σετ στο βόλεϊ.", Kinds.goals)
                Rectangle().fill(C.line).frame(height: 1).padding(.leading, 68)
                kindRow("flag.checkered", "Σέντρα, ημίχρονο, τελικό", "Οι φάσεις του αγώνα και το τελικό σκορ.", Kinds.startend)
                Rectangle().fill(C.line).frame(height: 1).padding(.leading, 68)
                kindRow("alarm", "Υπενθύμιση", "30′ πριν από την έναρξη.", Kinds.reminder)
                Rectangle().fill(C.line).frame(height: 1).padding(.leading, 68)
                kindRow("rectangle.portrait.fill", "Κάρτες", "Κίτρινες και κόκκινες κάρτες.", Kinds.cards)
            }
            .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(C.panel))
            Toggle(isOn: $p.liveActivities) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Ζωντανό σκορ στην οθόνη κλειδώματος").font(F.body(15, .heavy)).foregroundStyle(C.text)
                    Text("Και στο Dynamic Island / ρολόι, όσο παίζει η ΑΕΚ.").font(F.body(12.5)).foregroundStyle(C.muted)
                }
            }
            .tint(C.gold).padding(16)
            .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(C.panel))
        }
    }

    func kindRow(_ icon: String, _ t: String, _ sub: String, _ k: String) -> some View {
        let on = kinds.contains(k)
        return Button {
            haptic(.soft)
            if on { kinds.remove(k) } else { kinds.insert(k) }
        } label: {
            HStack(spacing: 14) {
                iconBox(icon, on)
                VStack(alignment: .leading, spacing: 3) {
                    Text(t).font(F.body(15, .heavy)).foregroundStyle(C.text)
                    Text(sub).font(F.body(12.5)).foregroundStyle(C.muted).fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 8)
                Image(systemName: on ? "checkmark.circle.fill" : "circle").font(.system(size: 22, weight: .semibold)).foregroundStyle(on ? C.gold : C.muted)
            }
            .padding(14).contentShape(Rectangle())
        }.buttonStyle(.plain)
    }

    var newsStep: some View {
        VStack(alignment: .leading, spacing: 18) {
            title("Και οι ειδήσεις;", "Ειδοποίηση για κάθε νέο θέμα του AEK Hub.")
            Toggle(isOn: $p.news) {
                Text("Νέα άρθρα").font(F.body(16, .heavy)).foregroundStyle(C.text)
            }
            .tint(C.gold).padding(16)
            .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(C.panel))
            if p.news, let cats = app.config?.categories, !cats.isEmpty {
                Text(p.newsCats.isEmpty ? "Από όλες τις κατηγορίες — ή διάλεξε μόνο κάποιες:" : "Μόνο από αυτές:")
                    .font(F.body(13)).foregroundStyle(C.muted)
                FlowLayout(spacing: 8) {
                    chip("Όλες", p.newsCats.isEmpty) { p.newsCats = [] }
                    ForEach(cats) { c in chip(c.name, p.newsCats.contains(c.name)) { if p.newsCats.contains(c.name) { p.newsCats.remove(c.name) } else { p.newsCats.insert(c.name) } } }
                }
            }
            Text("Όλα αλλάζουν όποτε θες από Εγώ → Ειδοποιήσεις.").font(F.body(12.5)).foregroundStyle(C.muted).padding(.top, 6)
        }
    }

    func chip(_ t: String, _ on: Bool, _ tap: @escaping () -> Void) -> some View {
        Button { haptic(.soft); tap() } label: {
            Text(t).font(F.body(13.5, .heavy)).foregroundStyle(on ? C.ink : C.text)
                .padding(.horizontal, 14).padding(.vertical, 9)
                .background(Capsule().fill(on ? C.gold : C.panel))
                .overlay(Capsule().strokeBorder(on ? .clear : C.line, lineWidth: 1))
        }.buttonStyle(.plain)
    }

    // MARK: Ενέργειες

    func next() {
        haptic(.medium)
        if step < 2 { withAnimation(.spring(response: 0.35)) { step += 1 } } else { finish() }
    }

    func finish() {
        // τα είδη ισχύουν για όλα τα αθλήματα (ανά άθλημα αλλάζουν από τις Ειδοποιήσεις)
        var k = Set<String>()
        for sp in Kinds.sports + sportList.map(\.0) { for x in kinds { k.insert("\(sp):\(x)") } }
        p.kinds = k
        p.all = true
        done()
    }

    static func emoji(_ s: String) -> String {
        switch s {
        case "football": return "⚽️"
        case "women_football": return "⚽️"
        case "basketball": return "🏀"
        case "volleyball": return "🏐"
        case "handball": return "🤾"
        case "futsal": return "🥅"
        case "waterpolo": return "🤽"
        default: return "🏟"
        }
    }
}
