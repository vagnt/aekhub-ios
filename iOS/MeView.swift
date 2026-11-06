import SwiftUI
import UserNotifications

/// «Εγώ»: Ειδοποιήσεις (ξεχωριστή οθόνη) · αποθηκευμένα · ημερολόγιο · ανάγνωση · στατιστικά · social · πληροφορίες
struct MeView: View {
    @EnvironmentObject var app: AppState
    @EnvironmentObject var p: Prefs
    @AppStorage("articleSize") private var size: Double = 17
    @State private var showCal = false
    @State private var status: UNAuthorizationStatus = .authorized
    @State private var tick = 0

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                ScreenTitle(text: "Εγώ").padding(.top, 14)

                // Ειδοποιήσεις → ξεχωριστή οθόνη με όλα τα αθλήματα
                NavigationLink(value: Route.notifs) {
                    HStack(spacing: 14) {
                        Image(systemName: p.all ? "bell.fill" : "bell.slash.fill").font(.system(size: 19)).foregroundStyle(p.all ? C.ink : C.muted)
                            .frame(width: 44, height: 44).background(Circle().fill(p.all ? C.gold : C.panel3))
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Ειδοποιήσεις").font(F.body(16, .heavy)).foregroundStyle(C.text)
                            Text(status == .denied ? "Κλειστές στις Ρυθμίσεις του iPhone" : (p.all ? "Ενεργές · \(p.sports.count) αθλήματα" : "Κλειστές"))
                                .font(F.body(12)).foregroundStyle(status == .denied ? C.live : (p.all ? C.gold : C.muted))
                        }
                        Spacer()
                        Image(systemName: "chevron.right").font(.system(size: 14, weight: .bold)).foregroundStyle(C.muted)
                    }
                    .padding(16)
                    .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(p.all ? C.panel : C.panel2))
                    .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(p.all ? C.gold : C.line, lineWidth: 1.5))
                }.buttonStyle(.plain)

                group {
                    rowButton("calendar", "Το πρόγραμμα στο ημερολόγιο", "Όλοι οι αγώνες στο Ημερολόγιο του iPhone") { showCal = true }
                    sep
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 12) {
                            iconBox("textformat.size", true)
                            Text("Μέγεθος γραμμάτων άρθρων").font(F.body(15, .heavy)).foregroundStyle(C.text)
                            Spacer()
                            Text("\(Int(size))").font(F.body(15, .heavy)).foregroundStyle(C.gold)
                        }
                        Slider(value: $size, in: 14...26, step: 1).tint(C.gold).padding(.leading, 52)
                    }.padding(.horizontal, 16).padding(.vertical, 12)
                    sep
                    Toggle(isOn: $p.stats) {
                        HStack(alignment: .top, spacing: 12) {
                            iconBox("chart.line.uptrend.xyaxis", p.stats)
                            VStack(alignment: .leading, spacing: 3) {
                                Text("Ανώνυμα στατιστικά").font(F.body(15, .heavy)).foregroundStyle(p.stats ? C.text : C.text2)
                                Text("Βοηθούν να βελτιώνουμε το AEK Hub (ποια άρθρα και αγώνες διαβάζονται). Χωρίς προσωπικά στοιχεία.").font(F.body(12)).foregroundStyle(C.muted)
                            }
                        }
                    }.toggleStyle(GoldToggle()).padding(.horizontal, 16).padding(.vertical, 14)
                }

                SectionLabel(text: "Αποθηκευμένα άρθρα")
                if p.saved.isEmpty {
                    Text("Πάτα το σημαδάκι σε ένα άρθρο για να το βρίσκεις εδώ.").font(F.body(14)).foregroundStyle(C.muted)
                } else {
                    VStack(spacing: 0) { ForEach(p.saved) { PostRow(p: $0) } }
                }

                Link(destination: URL(string: Api.site + "/politiki-aporritou/")!) {
                    Text("Πολιτική απορρήτου").font(F.body(14, .bold)).foregroundStyle(C.gold).padding(.vertical, 4)
                }
                if let so = app.config?.socials, !so.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("ΑΚΟΛΟΥΘΗΣΕ ΤΟ AEK HUB").font(F.disp(18)).foregroundStyle(C.text)
                        HStack(spacing: 10) { ForEach(so, id: \.self) { SocialDot(s: $0, size: 46) } }
                    }
                    .padding(14).frame(maxWidth: .infinity, alignment: .leading)
                    .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(C.panel))
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text("AEK Hub \(Api.version) (build \(Api.build))").font(F.body(12)).foregroundStyle(C.muted)
                    Text(diag).font(F.body(11)).foregroundStyle(C.muted).id(tick)
                }.padding(.top, 8)
            }
            .padding(.horizontal, screenPad).padding(.bottom, 32)
            .readable(680)
        }
        .background(C.ink)
        .sheet(isPresented: $showCal) { CalendarSheet().environmentObject(AppState.shared) }
        .task {
            Analytics.screen(6, name: "me")
            status = await Notifier.shared.status()
            while !Task.isCancelled { try? await Task.sleep(nanoseconds: 2_000_000_000); tick += 1 }
        }
    }

    var diag: String {
        let f = DateFormatter(); f.dateFormat = "HH:mm:ss"
        return "Server: " + (Api.shared.lastOk.map { "τελευταία επιτυχία " + f.string(from: $0) } ?? "καμία επιτυχής σύνδεση ακόμη") + (Api.shared.lastErr.isEmpty ? "" : "\nσφάλμα: " + Api.shared.lastErr)
    }

    func group<V: View>(@ViewBuilder _ c: () -> V) -> some View {
        VStack(spacing: 0) { c() }
            .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(C.panel))
            .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(C.line, lineWidth: 1))
    }
    var sep: some View { Rectangle().fill(C.line).frame(height: 1).padding(.leading, 68).padding(.trailing, 16) }
    func rowButton(_ icon: String, _ t: String, _ sub: String, _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                iconBox(icon, true)
                VStack(alignment: .leading, spacing: 2) {
                    Text(t).font(F.body(15, .heavy)).foregroundStyle(C.text)
                    Text(sub).font(F.body(12)).foregroundStyle(C.muted)
                }
                Spacer()
                Image(systemName: "chevron.right").font(.system(size: 13, weight: .bold)).foregroundStyle(C.muted)
            }
            .padding(.horizontal, 16).padding(.vertical, 14).contentShape(Rectangle())
        }.buttonStyle(.plain)
    }
}

/// Τετράγωνο εικονίδιο (40, γωνία 12): κίτρινο όταν είναι ενεργό
func iconBox(_ icon: String, _ on: Bool) -> some View {
    Image(systemName: icon).font(.system(size: 18, weight: .semibold)).foregroundStyle(on ? C.gold : C.muted)
        .frame(width: 40, height: 40)
        .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(on ? C.gold.opacity(0.16) : C.panel2))
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
                    if !e.image.isEmpty { FillImage(url: e.image, w: 1200, height: 210) }
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
                            if !u.thumb.isEmpty { FillImage(url: u.thumb, w: 800, height: 180).clipShape(RoundedRectangle(cornerRadius: 10)) }
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
