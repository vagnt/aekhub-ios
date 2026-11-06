import SwiftUI
import UserNotifications

/// 🔔 Οι ειδοποιήσεις σου (ίδιες επιλογές με το Android): ανά άθλημα, είδη, νέα άρθρα, ήσυχες ώρες.
struct NotifSettingsView: View {
    @EnvironmentObject var app: AppState
    @ObservedObject var p = Prefs.shared
    @State private var status: UNAuthorizationStatus = .notDetermined
    @State private var open: Set<String> = []
    @Environment(\.openURL) var openURL

    var body: some View {
        List {
            Section {
                if status == .denied {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Οι ειδοποιήσεις είναι κλειστές στις Ρυθμίσεις του iPhone.").font(F.body(14, .extra))
                        Button("Άνοιγμα Ρυθμίσεων") { if let u = URL(string: UIApplication.openSettingsURLString) { openURL(u) } }.foregroundStyle(C.gold)
                    }
                } else if status == .notDetermined {
                    Button { Task { _ = await Notifier.shared.requestPermission(); await refreshStatus() } } label: {
                        Label("Άνοιξέ τες", systemImage: "bell.badge").font(F.body(15, .extra)).foregroundStyle(C.gold)
                    }
                }
                Toggle(isOn: $p.all) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Ειδοποιήσεις AEK Hub").font(F.body(15, .extra))
                        Text(p.all ? "Ενεργές, με τις επιλογές σου παρακάτω" : "Κλειστές").font(F.body(12, .medium)).foregroundStyle(p.all ? C.gold : C.muted)
                    }
                }
                Button("🔔 Δοκιμή ειδοποίησης") { Notifier.shared.test() }.foregroundStyle(C.gold)
            } footer: {
                Text("Η υπενθύμιση 30′ πριν έρχεται πάντα. Σέντρα, γκολ, ημίχρονο και τελικό έρχονται αμέσως όσο το app είναι ανοιχτό· με κλειστό app όποτε επιτρέψει το iOS (μπορεί να αργήσουν). Άμεσες παντού θα γίνουν όταν μπει στο App Store.")
                    .font(F.body(11, .medium))
            }
            .listRowBackground(C.panel)

            Section {
                Button(allOn ? "✓ Όλα επιλεγμένα — πάτα για να τα ξεχωρίσεις" : "Επιλογή όλων") {
                    p.sports = allOn ? [] : Set(sportList.map(\.0))
                }.font(F.body(13, .extra)).foregroundStyle(C.gold)
                ForEach(sportList, id: \.0) { item in
                    let sp = item.0, name = item.1
                    let follow = p.sports.contains(sp)
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text(Sports.emoji(sp) + " " + name).font(F.body(15, .extra))
                            Spacer()
                            if follow {
                                Button { if open.contains(sp) { open.remove(sp) } else { open.insert(sp) } } label: {
                                    Image(systemName: open.contains(sp) ? "chevron.up" : "chevron.down").foregroundStyle(C.text2)
                                }.buttonStyle(.plain)
                            }
                            Toggle("", isOn: Binding(get: { follow }, set: { on in if on { p.sports.insert(sp) } else { p.sports.remove(sp) } })).labelsHidden()
                        }
                        if follow && open.contains(sp) {
                            ForEach(kindRows(sp), id: \.0) { row in
                                let k = row.0, t = row.1, sub = row.2
                                Toggle(isOn: Binding(get: { p.kinds.contains("\(sp):\(k)") }, set: { _ in p.toggleKind(sp, k) })) {
                                    VStack(alignment: .leading, spacing: 1) {
                                        Text(t).font(F.body(14, .bold))
                                        Text(sub).font(F.body(11, .medium)).foregroundStyle(C.muted)
                                    }
                                }.padding(.leading, 8)
                            }
                        }
                    }
                }
            } header: { Text("ΑΝΑ ΑΘΛΗΜΑ").font(F.body(11, .extra)) }
            .listRowBackground(C.panel)

            Section {
                Toggle(isOn: $p.news) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("📰 Νέα άρθρα").font(F.body(15, .extra))
                        Text("Το νεότερο θέμα κάθε φορά (όχι καταιγισμός).").font(F.body(12, .medium)).foregroundStyle(C.muted)
                    }
                }
                if p.news, let cats = app.config?.categories, !cats.isEmpty {
                    FlowChips(items: [("", "Όλες", "")] + cats.map { ($0.name, $0.name, "") }, isOn: { $0.isEmpty ? p.newsCats.isEmpty : p.newsCats.contains($0) }) { k in
                        if k.isEmpty { p.newsCats = [] } else if p.newsCats.contains(k) { p.newsCats.remove(k) } else { p.newsCats.insert(k) }
                    }.padding(.vertical, 4)
                }
            } header: { Text("ΕΙΔΗΣΕΙΣ").font(F.body(11, .extra)) }
            .listRowBackground(C.panel)

            Section {
                Toggle(isOn: $p.spoiler) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Χωρίς spoilers").font(F.body(15, .extra))
                        Text("Ειδοποιήσεις αγώνων χωρίς το σκορ.").font(F.body(12, .medium)).foregroundStyle(C.muted)
                    }
                }
                Toggle(isOn: $p.quiet) { Text("🌙 Ήσυχες ώρες κάθε μέρα").font(F.body(15, .extra)) }
                if p.quiet {
                    DatePicker("Από", selection: timeBinding(\.quietFrom), displayedComponents: .hourAndMinute)
                    DatePicker("Έως", selection: timeBinding(\.quietTo), displayedComponents: .hourAndMinute)
                    Toggle("Τα γκολ της ΑΕΚ περνάνε", isOn: $p.quietAek)
                }
            } header: { Text("ΓΕΝΙΚΑ").font(F.body(11, .extra)) }
            .listRowBackground(C.panel)
        }
        .tint(C.gold)
        .scrollContentBackground(.hidden)
        .background(C.ink)
        .navigationTitle("Ειδοποιήσεις")
        .navigationBarTitleDisplayMode(.inline)
        .task { await refreshStatus() }
        .onDisappear { Task { await Notifier.shared.refresh(force: true) } }
    }

    func refreshStatus() async { status = await Notifier.shared.status() }

    var sportList: [(String, String)] {
        let fromCfg = (app.config?.sports ?? []).map { ($0.key, $0.name) }
        return fromCfg.isEmpty ? Kinds.sports.map { ($0, Sports.label($0)) } : fromCfg
    }
    var allOn: Bool { sportList.allSatisfy { p.sports.contains($0.0) } }

    func kindRows(_ sp: String) -> [(String, String, String)] {
        var r: [(String, String, String)] = [(Kinds.startend, "Σέντρα, ημίχρονο, τελικό", "Αρχή και τέλος του αγώνα.")]
        if sp.hasPrefix("volleyball") { r.append((Kinds.goals, "Κάθε σετ", "Μόλις τελειώνει σετ — για όποιον κι αν το κερδίσει.")) }
        else if !Kinds.noGoals.contains(sp) { r.append((Kinds.goals, "Γκολ", "Τη στιγμή που μπαίνει — για την ΑΕΚ και τον αντίπαλο (και αν ακυρωθεί).")) }
        r.append((Kinds.reminder, "Υπενθύμιση 30′ πριν", "Με την ώρα, το γήπεδο και πού μεταδίδεται."))
        return r
    }

    func timeBinding(_ kp: ReferenceWritableKeyPath<Prefs, Int>) -> Binding<Date> {
        Binding(get: {
            let m = p[keyPath: kp]
            return Fmt.cal.date(bySettingHour: m / 60, minute: m % 60, second: 0, of: Date()) ?? Date()
        }, set: { d in
            let c = Fmt.cal.dateComponents([.hour, .minute], from: d)
            p[keyPath: kp] = (c.hour ?? 0) * 60 + (c.minute ?? 0)
        })
    }
}

struct SavedView: View {
    @ObservedObject var p = Prefs.shared
    var body: some View {
        ScrollView {
            if p.saved.isEmpty { EmptyState(icon: "bookmark", text: "Δεν έχεις αποθηκεύσει άρθρα.\nΠάτα 🔖 πάνω σε ένα άρθρο για να το κρατήσεις εδώ.") }
            LazyVGrid(columns: adaptiveCols, spacing: 0) {
                ForEach(p.saved) { a in
                    PostRow(p: a).contextMenu { Button(role: .destructive) { p.toggleSaved(a) } label: { Label("Αφαίρεση", systemImage: "trash") } }
                }
            }
        }
        .background(C.ink)
        .navigationTitle("Αποθηκευμένα")
        .navigationBarTitleDisplayMode(.inline)
    }
}

/// Οθόνη υποδοχής (πρώτο άνοιγμα)
struct IntroView: View {
    var done: () -> Void
    @State private var page = 0
    var body: some View {
        ZStack {
            C.ink.ignoresSafeArea()
            Image("HeroBg").resizable().scaledToFill().opacity(0.25).ignoresSafeArea()
            VStack(spacing: 22) {
                Spacer()
                Image("HubLogo").resizable().scaledToFit().frame(width: 110, height: 110).clipShape(RoundedRectangle(cornerRadius: 24))
                TabView(selection: $page) {
                    slide("ΟΛΗ Η ΑΕΚ, ΟΛΑ ΤΑ ΤΜΗΜΑΤΑ", "Ειδήσεις, ποδόσφαιρο, μπάσκετ, βόλεϊ, χάντμπολ και όλη η ερασιτεχνική, σε ένα μέρος.").tag(0)
                    slide("LIVE ΑΓΩΝΕΣ", "Σκορ, πορεία, ενδεκάδες, στατιστικά και βαθμοί παικτών — λεπτό προς λεπτό.").tag(1)
                    slide("ΣΤΟ ΡΟΛΟΪ ΚΑΙ ΣΤΗΝ ΟΘΟΝΗ", "Widgets για την οθόνη αφετηρίας και κλειδώματος, και εφαρμογή για Apple Watch.").tag(2)
                }
                .tabViewStyle(.page(indexDisplayMode: .always))
                .frame(height: 200)
                Spacer()
                Button {
                    if page < 2 { withAnimation { page += 1 } }
                    else { Task { _ = await Notifier.shared.requestPermission(); done() } }
                } label: {
                    Text(page < 2 ? "ΣΥΝΕΧΕΙΑ" : "ΞΕΚΙΝΑ").font(F.body(16, .extra)).foregroundStyle(C.ink)
                        .frame(maxWidth: 420).padding(.vertical, 16).background(RoundedRectangle(cornerRadius: 14).fill(C.gold))
                }.padding(.horizontal, 24)
                Button("Παράλειψη", action: done).font(F.body(13, .bold)).foregroundStyle(C.muted).padding(.bottom, 20)
            }
        }
        .preferredColorScheme(.dark)
    }
    func slide(_ t: String, _ s: String) -> some View {
        VStack(spacing: 10) {
            Text(t).font(F.disp(30, black: true)).foregroundStyle(C.gold).multilineTextAlignment(.center)
            Text(s).font(F.body(15, .medium)).foregroundStyle(C.text2).multilineTextAlignment(.center).padding(.horizontal, 30)
        }
    }
}
