import SwiftUI
import UserNotifications

/// «Εγώ» (σχέδιο iOS 26): Ειδοποιήσεις · Κατηγορίες ειδήσεων · Αγώνες που ακολουθώ (ανά άθλημα + είδη) · Γενικά · Πληροφορίες
struct MeView: View {
    @EnvironmentObject var app: AppState
    @EnvironmentObject var p: Prefs
    @AppStorage("articleSize") private var size: Double = 17
    @State private var status: UNAuthorizationStatus = .authorized
    @State private var showCal = false
    @State private var diag = ""
    @Environment(\.openURL) var openURL

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                ScreenTitle(text: "Εγώ").padding(.horizontal, -screenPad)

                if status == .denied {
                    Button { if let u = URL(string: UIApplication.openSettingsURLString) { openURL(u) } } label: {
                        Text("⚠ Οι ειδοποιήσεις είναι κλειστές στις Ρυθμίσεις του iPhone — πάτα για να τις ανοίξεις.")
                            .font(F.body(14, .semibold)).foregroundStyle(C.ink).padding(14).frame(maxWidth: .infinity, alignment: .leading)
                            .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(C.goldGrad))
                    }.buttonStyle(.plain)
                }

                label("Ειδοποιήσεις")
                group {
                    toggle("Ειδοποιήσεις", "Γενικός διακόπτης για όλη την εφαρμογή", $p.all)
                    divider
                    toggle("Live Activities", "Ζωντανό σκορ στην κλειδωμένη οθόνη και στο Dynamic Island", $p.liveActivities)
                    divider
                    toggle("Νέα άρθρα", "Το νεότερο θέμα κάθε φορά (όχι καταιγισμός)", $p.news)
                    divider
                    Button { Notifier.shared.test() } label: {
                        HStack { Text("🔔 Δοκιμή ειδοποίησης").font(F.body(17, .semibold)).foregroundStyle(C.gold); Spacer() }.padding(.vertical, 14)
                    }.buttonStyle(.plain)
                }

                if p.news, let cats = app.config?.categories, !cats.isEmpty {
                    label("Κατηγορίες ειδήσεων")
                    group {
                        FlowLayout(spacing: 8) {
                            ForEach(cats) { c in
                                pill(c.name, p.newsCats.isEmpty || p.newsCats.contains(c.name)) {
                                    if p.newsCats.isEmpty { p.newsCats = Set(cats.map(\.name)).subtracting([c.name]) }
                                    else if p.newsCats.contains(c.name) { p.newsCats.remove(c.name) } else { p.newsCats.insert(c.name) }
                                    if p.newsCats.count == cats.count { p.newsCats = [] }
                                }
                            }
                        }.padding(.vertical, 16)
                    }
                }

                label("Αγώνες που ακολουθώ")
                group {
                    ForEach(Array(sportList.enumerated()), id: \.offset) { i, item in
                        let sp = item.0
                        if i > 0 { divider }
                        toggle(item.1, nil, Binding(get: { p.sports.contains(sp) }, set: { on in if on { p.sports.insert(sp) } else { p.sports.remove(sp) } }))
                        if p.sports.contains(sp) {
                            FlowLayout(spacing: 8) {
                                ForEach(kinds(sp), id: \.0) { k in
                                    pill(k.1, p.kinds.contains("\(sp):\(k.0)")) { p.toggleKind(sp, k.0) }
                                }
                            }.padding(.bottom, 14)
                        }
                    }
                }
                Text("Η υπενθύμιση 30′ πριν έρχεται πάντα. Σέντρα, γκολ, ημίχρονο και τελικό: αμέσως όσο το app είναι ανοιχτό· με κλειστό app όποτε επιτρέψει το iOS. Άμεσες παντού όταν μπει στο App Store.")
                    .font(F.body(12)).foregroundStyle(C.muted).padding(.horizontal, 6)

                label("Γενικά")
                group {
                    toggle("Χωρίς spoilers", "Ειδοποιήσεις αγώνων χωρίς το σκορ", $p.spoiler)
                    divider
                    toggle("Ήσυχες ώρες", "Καμία ειδοποίηση τη νύχτα", $p.quiet)
                    if p.quiet {
                        DatePicker("Από", selection: timeBinding(\.quietFrom), displayedComponents: .hourAndMinute).font(F.body(16)).padding(.vertical, 6)
                        DatePicker("Έως", selection: timeBinding(\.quietTo), displayedComponents: .hourAndMinute).font(F.body(16)).padding(.vertical, 6)
                        toggle("Τα γκολ της ΑΕΚ περνάνε", nil, $p.quietAek)
                    }
                    divider
                    VStack(alignment: .leading, spacing: 6) {
                        HStack { Text("Μέγεθος γραμμάτων άρθρων").font(F.body(17, .semibold)); Spacer(); Text("\(Int(size))").font(F.body(17, .bold)).foregroundStyle(C.gold) }
                        Slider(value: $size, in: 14...26, step: 1).tint(C.gold)
                    }.padding(.vertical, 12)
                    divider
                    toggle("Ανώνυμα στατιστικά", "Ποια άρθρα και αγώνες διαβάζονται — χωρίς προσωπικά στοιχεία", $p.stats)
                }

                label("Περισσότερα")
                group {
                    NavigationLink(value: Route.saved) { nav("bookmark", "Αποθηκευμένα άρθρα", p.saved.isEmpty ? "Κανένα ακόμα" : "\(p.saved.count)") }
                    divider
                    Button { showCal = true } label: { nav("calendar.badge.plus", "Το πρόγραμμα στο ημερολόγιο", "") }.buttonStyle(.plain)
                    ForEach(app.config?.socials ?? [], id: \.self) { so in
                        divider
                        Link(destination: URL(string: so.url) ?? URL(string: Api.site)!) { nav("arrow.up.right.square", so.label.isEmpty ? so.key.capitalized : so.label, so.handle) }
                    }
                    divider
                    Link(destination: URL(string: Api.site)!) { nav("globe", "aekhub.gr", "") }
                    divider
                    Link(destination: URL(string: Api.site + "/politiki-aporritou/")!) { nav("lock.shield", "Πολιτική απορρήτου", "") }
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text("AEK Hub \(Api.version) (build \(Api.build)) · iOS").font(F.body(12, .semibold)).foregroundStyle(C.text2)
                    Text(diag).font(F.body(11)).foregroundStyle(C.muted)
                }.padding(.horizontal, 6).padding(.top, 10)
            }
            .padding(.horizontal, screenPad).padding(.bottom, 24)
        }
        .background(C.ink)
        .sheet(isPresented: $showCal) { CalendarSheet().environmentObject(AppState.shared) }
        .task {
            Analytics.screen(6, name: "me")
            status = await Notifier.shared.status()
            let f = DateFormatter(); f.dateFormat = "d/M HH:mm:ss"
            diag = (Api.shared.lastOk.map { "Τελευταία σύνδεση: " + f.string(from: $0) } ?? "Καμία σύνδεση ακόμη") + (Api.shared.lastErr.isEmpty ? "" : "\nΤελευταίο σφάλμα: " + Api.shared.lastErr)
        }
        .onChange(of: p.all) { on in if on { Task { _ = await Notifier.shared.requestPermission(); status = await Notifier.shared.status() } } }
        .onDisappear { Task { await Notifier.shared.refresh(force: true) } }
    }

    var sportList: [(String, String)] {
        let fromCfg = (app.config?.sports ?? []).map { ($0.key, $0.name) }
        return fromCfg.isEmpty ? Kinds.sports.map { ($0, Sports.label($0)) } : fromCfg
    }
    func kinds(_ sp: String) -> [(String, String)] {
        var r: [(String, String)] = []
        if sp.hasPrefix("volleyball") { r.append((Kinds.goals, "Κάθε σετ")) }
        else if !Kinds.noGoals.contains(sp) { r.append((Kinds.goals, "Γκολ")) }
        r.append((Kinds.startend, "Σέντρα · Ημίχρονο · Τελικό"))
        r.append((Kinds.reminder, "Υπενθύμιση 30′"))
        return r
    }

    func label(_ t: String) -> some View {
        Text(t.upperGr).font(F.tag(12)).tracking(1.4).foregroundStyle(C.muted).padding(.horizontal, 6).padding(.top, 16)
    }
    func group<V: View>(@ViewBuilder _ c: () -> V) -> some View {
        VStack(alignment: .leading, spacing: 0) { c() }.padding(.horizontal, 16).card(24)
    }
    var divider: some View { Rectangle().fill(C.line).frame(height: 1) }
    func toggle(_ t: String, _ sub: String?, _ b: Binding<Bool>) -> some View {
        Toggle(isOn: b) {
            VStack(alignment: .leading, spacing: 2) {
                Text(t).font(F.body(17, .semibold)).foregroundStyle(C.text)
                if let sub { Text(sub).font(F.body(13)).foregroundStyle(C.muted) }
            }
        }
        .toggleStyle(GoldToggle())
        .padding(.vertical, 12)
    }
    func pill(_ t: String, _ on: Bool, _ tap: @escaping () -> Void) -> some View {
        Button(action: tap) {
            Text(t).font(F.body(14, .semibold)).foregroundStyle(on ? C.gold : C.muted)
                .padding(.horizontal, 13).padding(.vertical, 8)
                .background(Capsule().fill(on ? C.gold.opacity(0.14) : .clear))
                .overlay(Capsule().stroke(on ? C.gold.opacity(0.8) : C.line2, lineWidth: 1))
        }.buttonStyle(.plain)
    }
    func nav(_ icon: String, _ t: String, _ sub: String) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon).font(.system(size: 17)).foregroundStyle(C.gold).frame(width: 24)
            Text(t).font(F.body(17)).foregroundStyle(C.text)
            Spacer()
            if !sub.isEmpty { Text(sub).font(F.body(14)).foregroundStyle(C.muted) }
            Image(systemName: "chevron.right").font(.system(size: 13, weight: .semibold)).foregroundStyle(C.muted)
        }
        .padding(.vertical, 14).contentShape(Rectangle())
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

/// Live γεγονός (π.χ. μεταγραφικό/ρεπορτάζ λεπτό-λεπτό) από το Live Ticker
struct EventView: View {
    let id: Int
    @State private var e: EventDetail?
    @State private var openURL: URL?

    var body: some View {
        ScrollView {
            if let e {
                VStack(alignment: .leading, spacing: 12) {
                    if !e.image.isEmpty { NetImage(url: e.image, w: 1200).frame(height: 210).frame(maxWidth: .infinity).clipped() }
                    VStack(alignment: .leading, spacing: 8) {
                        if e.live { HStack(spacing: 6) { LiveDot(); Text("LIVE").font(F.body(12, .bold)).foregroundStyle(C.live) } }
                        else if !e.statusLabel.isEmpty { Text(e.statusLabel.upperGr).font(F.body(11, .bold)).foregroundStyle(C.muted) }
                        Text(e.title).font(F.disp(30, black: true)).foregroundStyle(C.text)
                    }.padding(.horizontal, 16)
                    ForEach(e.updates) { u in
                        VStack(alignment: .leading, spacing: 6) {
                            HStack(spacing: 8) {
                                Text([u.minute, u.time].first { !$0.isEmpty } ?? "").font(F.body(12, .bold)).foregroundStyle(C.gold)
                                if !u.typeLabel.isEmpty { Text(u.typeLabel.upperGr).font(F.body(10, .bold)).foregroundStyle(C.muted) }
                            }
                            if !u.title.isEmpty { Text(u.title).font(F.body(15, .bold)).foregroundStyle(C.text) }
                            if !u.text.isEmpty { Text(u.text.plainText).font(F.body(14, .medium)).foregroundStyle(C.text2) }
                            if !u.thumb.isEmpty { NetImage(url: u.thumb, w: 800).frame(height: 180).frame(maxWidth: .infinity).clipped().clipShape(RoundedRectangle(cornerRadius: 10)) }
                            if let l = [u.video, u.link].first(where: { !$0.isEmpty }), let url = URL(string: l) {
                                Button { openURL = url } label: { Label(u.video.isEmpty ? "Άνοιγμα" : "Δες το βίντεο", systemImage: u.video.isEmpty ? "link" : "play.fill") }
                                    .font(F.body(13, .bold)).foregroundStyle(C.gold)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(14)
                        .background(RoundedRectangle(cornerRadius: 12).fill(u.highlight ? C.panel3 : C.panel))
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(u.highlight ? C.gold.opacity(0.6) : .clear))
                        .padding(.horizontal, 16)
                    }
                }.padding(.bottom, 24)
            } else { ProgressView().tint(C.gold).padding(80) }
        }
        .background(C.ink)
        .navigationBarTitleDisplayMode(.inline)
        .refreshable { await load() }
        .sheet(item: $openURL) { SafariView(url: $0).ignoresSafeArea() }
        .task {
            Analytics.screen(5, id, name: "event")
            await load()
            while !Task.isCancelled { try? await Task.sleep(nanoseconds: 20_000_000_000); await load() }
        }
    }
    func load() async { if let x = try? await Api.shared.event(id) { e = x } }
}
