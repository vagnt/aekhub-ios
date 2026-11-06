import SwiftUI
import UserNotifications

/// 🔔 Ειδοποιήσεις — όπως στο Android: γενικός διακόπτης · ανά άθλημα (κάρτα που ανοίγει, με διακόπτη ανά είδος) ·
/// ειδήσεις με κατηγορίες · γενικά (Live Activity, ήσυχες ώρες, χωρίς spoilers) · δοκιμή.
struct NotifSettingsView: View {
    @EnvironmentObject var app: AppState
    @EnvironmentObject var p: Prefs
    @State private var status: UNAuthorizationStatus = .authorized
    @State private var open: Set<String> = []
    @Environment(\.openURL) var openURL
    @Environment(\.dismiss) var dismiss

    var sportList: [(String, String)] {
        let c = (app.config?.sports ?? []).map { ($0.key, $0.name) }
        return c.isEmpty ? Kinds.sports.map { ($0, Sports.label($0)) } : c
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                HStack(spacing: 6) {
                    Button { dismiss() } label: { Image(systemName: "chevron.left").font(.system(size: 19, weight: .semibold)).foregroundStyle(C.text).frame(width: 40, height: 44) }
                        .padding(.leading, -12)
                    ScreenTitle(text: "Ειδοποιήσεις")
                    Spacer()
                }
                if status == .denied || status == .notDetermined {
                    VStack(alignment: .leading, spacing: 10) {
                        Text(status == .denied ? "Οι ειδοποιήσεις είναι κλειστές για το AEK Hub στο iPhone σου." : "Δεν έχεις δώσει ακόμα άδεια για ειδοποιήσεις.")
                            .font(F.body(13)).foregroundStyle(C.text2)
                        Button {
                            if status == .denied { if let u = URL(string: UIApplication.openSettingsURLString) { openURL(u) } }
                            else { Task { _ = await Notifier.shared.requestPermission(); status = await Notifier.shared.status() } }
                        } label: {
                            Text("Άνοιξέ τες").font(F.body(14, .heavy)).foregroundStyle(C.ink).padding(.horizontal, 16).padding(.vertical, 10)
                                .background(RoundedRectangle(cornerRadius: 10).fill(C.gold))
                        }.buttonStyle(.plain)
                    }
                    .padding(14).frame(maxWidth: .infinity, alignment: .leading)
                    .background(RoundedRectangle(cornerRadius: 14).fill(C.panel2))
                }

                // Γενικός διακόπτης
                Button { haptic(); p.all.toggle() } label: {
                    HStack(spacing: 14) {
                        Image(systemName: p.all ? "bell.fill" : "bell.slash.fill").font(.system(size: 19)).foregroundStyle(p.all ? C.ink : C.muted)
                            .frame(width: 44, height: 44).background(Circle().fill(p.all ? C.gold : C.panel3))
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Ειδοποιήσεις AEK Hub").font(F.body(16, .heavy)).foregroundStyle(C.text)
                            Text(p.all ? "Ενεργές, με τις επιλογές σου παρακάτω" : "Κλειστές").font(F.body(12)).foregroundStyle(p.all ? C.gold : C.muted)
                        }
                        Spacer()
                        Toggle("", isOn: $p.all).toggleStyle(GoldToggle()).labelsHidden().fixedSize()
                    }
                    .padding(16)
                    .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(p.all ? C.panel : C.panel2))
                    .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(p.all ? C.gold : C.line, lineWidth: 1.5))
                }.buttonStyle(.plain)

                if !p.all {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Δεν θα λαμβάνεις καμία ειδοποίηση").font(F.body(15, .heavy)).foregroundStyle(C.text)
                        Text("Ούτε γκολ, ούτε νέα, ούτε υπενθυμίσεις αγώνων. Οι επιλογές σου ανά άθλημα μένουν αποθηκευμένες: άνοιξε τον διακόπτη και ξαναρχίζουν όπως ήταν.")
                            .font(F.body(13)).foregroundStyle(C.text2)
                    }
                    .padding(16).frame(maxWidth: .infinity, alignment: .leading)
                    .background(RoundedRectangle(cornerRadius: 16).fill(C.panel2))
                } else {
                    SectionLabel(text: "Ανά άθλημα")
                    let allOn = sportList.allSatisfy { sp in p.sports.contains(sp.0) && kindRows(sp.0).allSatisfy { p.kinds.contains("\(sp.0):\($0.kind)") } }
                    chip(allOn ? "✓ Όλα επιλεγμένα — πάτα για να τα ξεχωρίσεις" : "Επιλογή όλων", allOn) {
                        if allOn { p.sports = [] } else {
                            p.sports = Set(sportList.map(\.0))
                            for sp in sportList { for k in kindRows(sp.0) { p.kinds.insert("\(sp.0):\(k.kind)") } }
                        }
                    }
                    ForEach(sportList, id: \.0) { sp in sportCard(sp.0, sp.1) }

                    group("Ειδήσεις") {
                        toggleRow("bolt.fill", "Νέα άρθρα", "Το νεότερο θέμα κάθε φορά που ανεβαίνει κάτι καινούργιο (όχι καταιγισμός).", $p.news, last: !(p.news && !(app.config?.categories ?? []).isEmpty))
                        if p.news, let cats = app.config?.categories, !cats.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                Text(p.newsCats.isEmpty ? "Από όλες τις κατηγορίες. Πάτα για να διαλέξεις μόνο κάποιες." : "Μόνο από: " + p.newsCats.sorted().joined(separator: ", "))
                                    .font(F.body(12)).foregroundStyle(C.muted)
                                FlowLayout(spacing: 8) {
                                    chip("Όλες", p.newsCats.isEmpty) { p.newsCats = [] }
                                    ForEach(cats) { c in chip(c.name, p.newsCats.contains(c.name)) { if p.newsCats.contains(c.name) { p.newsCats.remove(c.name) } else { p.newsCats.insert(c.name) } } }
                                }
                            }
                            .padding(.horizontal, 16).padding(.bottom, 14)
                        }
                    }

                    group("Γενικά") {
                        toggleRow("dot.radiowaves.left.and.right", "Ζωντανός αγώνας στην οθόνη κλειδώματος", "Σκορ και λεπτό στην κλειδωμένη οθόνη και στο Dynamic Island (Live Activity) όσο παίζει αγώνας που ακολουθείς.", $p.liveActivities)
                        quietHours
                        sep
                        toggleRow("eye.slash", "Χωρίς spoilers", "Ειδοποιήσεις αγώνων χωρίς το σκορ.", $p.spoiler, last: true)
                    }

                    Button { haptic(.medium); Notifier.shared.test() } label: {
                        HStack(spacing: 12) {
                            iconBox("bell.badge", true)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Δοκιμή ειδοποίησης").font(F.body(15, .heavy)).foregroundStyle(C.text)
                                Text("Έρχεται σε 3″ — για να δεις ότι όλα δουλεύουν.").font(F.body(12)).foregroundStyle(C.muted)
                            }
                            Spacer()
                        }
                        .padding(16)
                        .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(C.panel))
                        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(C.line, lineWidth: 1))
                    }.buttonStyle(.plain)

                    Text("Η υπενθύμιση 30′ πριν έρχεται πάντα. Σέντρα, γκολ, ημίχρονο και τελικό έρχονται αμέσως όσο το app είναι ανοιχτό· με κλειστό app όποτε επιτρέψει το iOS (μπορεί να αργήσουν).")
                        .font(F.body(12)).foregroundStyle(C.muted)
                }
            }
            .padding(.horizontal, screenPad).padding(.top, 8).padding(.bottom, 32)
            .readable(680)
        }
        .background(C.ink)
        .toolbar(.hidden, for: .navigationBar)
        .task { status = await Notifier.shared.status() }
        .onChange(of: p.all) { on in if on { Task { _ = await Notifier.shared.requestPermission(); status = await Notifier.shared.status() } } }
        .onDisappear { Task { await Notifier.shared.refresh(force: true) } }
    }

    // MARK: Ανά άθλημα

    struct KindRow { let kind, title, sub, icon: String }
    func kindRows(_ sp: String) -> [KindRow] {
        var r: [KindRow] = []
        if sp.hasPrefix("volleyball") { r.append(KindRow(kind: Kinds.goals, title: "Κάθε σετ", sub: "Μόλις τελειώνει σετ — για όποιον κι αν το κερδίσει.", icon: "trophy.fill")) }
        else if !Kinds.noGoals.contains(sp) { r.append(KindRow(kind: Kinds.goals, title: "Γκολ", sub: "Τη στιγμή που μπαίνει — για την ΑΕΚ και για τον αντίπαλο (και αν ακυρωθεί).", icon: "trophy.fill")) }
        let se: String
        switch sp { case "basketball": se = "Τζάμπολ, δεκάλεπτα, τελικό"; case _ where sp.hasPrefix("volleyball"): se = "Έναρξη, κάθε σετ, τελικό"; case "waterpolo": se = "Έναρξη, περίοδοι, τελικό"; default: se = "Σέντρα, ημίχρονο, τελικό" }
        r.append(KindRow(kind: Kinds.startend, title: se, sub: "Το τελικό έρχεται με το σκορ.", icon: "flag.fill"))
        r.append(KindRow(kind: Kinds.reminder, title: "Υπενθύμιση 30′ πριν", sub: "Με την ώρα, το γήπεδο και πού μεταδίδεται.", icon: "alarm.fill"))
        return r
    }
    func sportIcon(_ k: String) -> String {
        switch k {
        case "basketball": return "basketball.fill"
        case _ where k.hasPrefix("volleyball"): return "volleyball.fill"
        case "handball": return "figure.handball"
        case "waterpolo": return "figure.pool.swim"
        default: return "soccerball"
        }
    }

    @ViewBuilder func sportCard(_ key: String, _ name: String) -> some View {
        let follow = p.sports.contains(key)
        let rows = kindRows(key)
        let onCount = rows.filter { p.kinds.contains("\(key):\($0.kind)") }.count
        let isOpen = open.contains(key)
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                iconBox(sportIcon(key), follow)
                VStack(alignment: .leading, spacing: 2) {
                    Text(name).font(F.body(16, .heavy)).foregroundStyle(follow ? C.text : C.text2)
                    Text(follow ? "Ακολουθείς · \(onCount) από \(rows.count) ειδοποιήσεις" : "Καμία ειδοποίηση από αυτό το τμήμα").font(F.body(12)).foregroundStyle(follow ? C.gold : C.muted)
                }
                Spacer(minLength: 4)
                if follow {
                    Image(systemName: "chevron.down").font(.system(size: 14, weight: .bold)).foregroundStyle(C.text2).rotationEffect(.degrees(isOpen ? 180 : 0))
                }
                Toggle("", isOn: Binding(get: { follow }, set: { on in
                    if on { p.sports.insert(key); open.insert(key) } else { p.sports.remove(key); open.remove(key) }
                })).toggleStyle(GoldToggle()).labelsHidden().fixedSize()
            }
            .padding(.leading, 16).padding(.trailing, 12).padding(.vertical, 14)
            .contentShape(Rectangle())
            .onTapGesture {
                haptic()
                withAnimation(.easeInOut(duration: 0.22)) {
                    if follow { if isOpen { open.remove(key) } else { open.insert(key) } }
                    else { p.sports.insert(key); open.insert(key) }
                }
            }
            if follow && isOpen {
                Rectangle().fill(C.line).frame(height: 1)
                ForEach(Array(rows.enumerated()), id: \.offset) { i, r in
                    let on = p.kinds.contains("\(key):\(r.kind)")
                    Toggle(isOn: Binding(get: { on }, set: { _ in p.toggleKind(key, r.kind) })) {
                        HStack(spacing: 12) {
                            Image(systemName: r.icon).font(.system(size: 17)).foregroundStyle(on ? C.gold : C.muted).frame(width: 22)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(r.title).font(F.body(14, .bold)).foregroundStyle(on ? C.text : C.text2)
                                Text(r.sub).font(F.body(11)).foregroundStyle(C.muted)
                            }
                        }
                    }
                    .toggleStyle(GoldToggle())
                    .padding(.leading, 16).padding(.trailing, 12).padding(.vertical, 10)
                    if i < rows.count - 1 { Rectangle().fill(C.line).frame(height: 1).padding(.leading, 48).padding(.trailing, 12) }
                }
                .transition(.opacity)
            }
        }
        .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(C.panel))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(follow ? C.gold.opacity(0.45) : C.line, lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    // MARK: Ήσυχες ώρες (σίγαση για λίγο + κάθε μέρα)

    var quietHours: some View {
        TimelineView(.periodic(from: .now, by: 30)) { ctx in
            let paused = p.quietUntil > ctx.date.timeIntervalSince1970
            let active = p.isQuiet(ctx.date)
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .top, spacing: 12) {
                    iconBox("moon.fill", active || p.quiet)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Ήσυχες ώρες").font(F.body(15, .heavy)).foregroundStyle(active || p.quiet ? C.text : C.text2)
                        Text((paused ? "🔕 Σίγαση ως τις \(hm(Date(timeIntervalSince1970: p.quietUntil)))." : active ? "🔕 Τώρα είναι ήσυχες ώρες (ως τις \(hm(p.quietTo)))." : p.quiet ? "Κάθε μέρα \(hm(p.quietFrom))–\(hm(p.quietTo)) το κινητό δεν χτυπάει." : "Κλείσε τις ειδοποιήσεις για λίγο ή για συγκεκριμένες ώρες κάθε μέρα.") + (p.quietAek ? " Εξαίρεση: τα γκολ της ΑΕΚ." : ""))
                            .font(F.body(12)).foregroundStyle(active ? C.gold : C.muted)
                    }
                }
                FlowLayout(spacing: 8) {
                    if paused { chip("✕ Τέλος σίγασης", true) { p.quietUntil = 0 } }
                    chip("1 ώρα", false) { p.quietUntil = Date().addingTimeInterval(3600).timeIntervalSince1970 }
                    chip("2 ώρες", false) { p.quietUntil = Date().addingTimeInterval(7200).timeIntervalSince1970 }
                    chip("8 ώρες", false) { p.quietUntil = Date().addingTimeInterval(8 * 3600).timeIntervalSince1970 }
                    chip("Ως τις \(hm(p.quietTo))", false) { p.quietUntil = nextMorning().timeIntervalSince1970 }
                }
                .padding(.leading, 52)
                Toggle(isOn: $p.quiet) { Text("Κάθε μέρα").font(F.body(13, .heavy)).foregroundStyle(p.quiet ? C.text : C.text2) }
                    .toggleStyle(GoldToggle()).padding(.leading, 52)
                if p.quiet {
                    HStack(spacing: 8) {
                        timeBox("Από", \.quietFrom)
                        Text("–").font(F.body(16, .heavy)).foregroundStyle(C.muted)
                        timeBox("Έως", \.quietTo)
                    }.padding(.leading, 52)
                }
                Toggle(isOn: $p.quietAek) { Text("Να περνάνε τα γκολ της ΑΕΚ").font(F.body(13, .heavy)).foregroundStyle(p.quietAek ? C.text : C.text2) }
                    .toggleStyle(GoldToggle()).padding(.leading, 52)
            }
            .padding(.horizontal, 16).padding(.vertical, 14)
        }
    }

    func hm(_ m: Int) -> String { String(format: "%02d:%02d", m / 60, m % 60) }
    func hm(_ d: Date) -> String { let c = Calendar.current.dateComponents([.hour, .minute], from: d); return String(format: "%02d:%02d", c.hour ?? 0, c.minute ?? 0) }
    func nextMorning() -> Date {
        var t = Calendar.current.date(bySettingHour: p.quietTo / 60, minute: p.quietTo % 60, second: 0, of: Date()) ?? Date()
        if t <= Date() { t = Calendar.current.date(byAdding: .day, value: 1, to: t) ?? t }
        return t
    }
    func timeBox(_ label: String, _ kp: ReferenceWritableKeyPath<Prefs, Int>) -> some View {
        VStack(spacing: 0) {
            Text(label.uppercased()).font(F.body(10, .heavy)).foregroundStyle(C.muted)
            DatePicker("", selection: Binding(get: {
                Calendar.current.date(bySettingHour: p[keyPath: kp] / 60, minute: p[keyPath: kp] % 60, second: 0, of: Date()) ?? Date()
            }, set: { d in
                let c = Calendar.current.dateComponents([.hour, .minute], from: d)
                p[keyPath: kp] = (c.hour ?? 0) * 60 + (c.minute ?? 0)
            }), displayedComponents: .hourAndMinute).labelsHidden().tint(C.gold)
        }
        .padding(.horizontal, 10).padding(.vertical, 6)
        .background(RoundedRectangle(cornerRadius: 12).fill(C.ink)).overlay(RoundedRectangle(cornerRadius: 12).stroke(C.line, lineWidth: 1))
    }

    // MARK: Βοηθητικά

    func group<V: View>(_ title: String, @ViewBuilder _ c: () -> V) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            SectionLabel(text: title).padding(.leading, 16).padding(.top, 14).padding(.bottom, 4)
            c()
        }
        .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(C.panel))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(C.line, lineWidth: 1))
    }
    var sep: some View { Rectangle().fill(C.line).frame(height: 1).padding(.leading, 68).padding(.trailing, 16) }
    @ViewBuilder func toggleRow(_ icon: String, _ t: String, _ sub: String, _ b: Binding<Bool>, last: Bool = false) -> some View {
        Toggle(isOn: b) {
            HStack(alignment: .top, spacing: 12) {
                iconBox(icon, b.wrappedValue)
                VStack(alignment: .leading, spacing: 4) {
                    Text(t).font(F.body(15, .heavy)).foregroundStyle(b.wrappedValue ? C.text : C.text2)
                    Text(sub).font(F.body(12)).foregroundStyle(C.muted)
                }
            }
        }
        .toggleStyle(GoldToggle())
        .padding(.horizontal, 16).padding(.vertical, 14)
        if !last { sep }
    }
    func chip(_ t: String, _ on: Bool, _ tap: @escaping () -> Void) -> some View {
        Button { haptic(); tap() } label: {
            Text(t).font(F.body(13, .heavy)).foregroundStyle(on ? C.ink : C.text2)
                .padding(.horizontal, 13).padding(.vertical, 7)
                .background(Capsule().fill(on ? C.gold : C.panel2))
                .overlay(Capsule().stroke(on ? C.gold : C.line2, lineWidth: 1))
        }.buttonStyle(.plain)
    }
}
