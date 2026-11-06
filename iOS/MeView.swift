import SwiftUI
import UserNotifications

/// «Εγώ»: γρήγορα πλακίδια (αποθηκευμένα, ιστορικό, ημερολόγιο, ειδοποιήσεις) · συνέχισε να διαβάζεις ·
/// χωρίς διαφημίσεις · ανάγνωση (γράμματα, εξοικονόμηση δεδομένων) · εφαρμογή (μνήμη, απόρρητο) · social.
struct MeView: View {
    @EnvironmentObject var app: AppState
    @EnvironmentObject var p: Prefs
    @ObservedObject private var ads = Ads.shared
    @Environment(\.horizontalSizeClass) var hsc
    @AppStorage("articleSize") private var size: Double = 17
    @State private var showCal = false
    @State private var status: UNAuthorizationStatus = .authorized
    @State private var tick = 0
    @State private var cache = 0
    @State private var busy = false
    @AppStorage("c_blocked") private var blockedRaw = ""

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                ScreenTitle(text: "Εγώ").padding(.top, 14)

                // Γρήγορα πλακίδια
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: hsc == .regular ? 4 : 2), spacing: 12) {
                    NavigationLink(value: Route.notifs) {
                        tile("bell.fill", "Ειδοποιήσεις", status == .denied ? "Κλειστές στο iPhone" : (p.all ? "\(p.sports.count) αθλήματα" : "Κλειστές"), on: p.all && status != .denied)
                    }.buttonStyle(.plain)
                    NavigationLink(value: Route.saved) { tile("bookmark.fill", "Αποθηκευμένα", "\(p.saved.count) άρθρα", on: true) }.buttonStyle(.plain)
                    NavigationLink(value: Route.history) { tile("clock.fill", "Ιστορικό", "\(p.history.count) άρθρα", on: true) }.buttonStyle(.plain)
                    Button { showCal = true } label: { tile("calendar", "Ημερολόγιο", "Οι αγώνες στο iPhone", on: true) }.buttonStyle(.plain)
                }

                // Συνέχισε να διαβάζεις
                if !p.history.isEmpty {
                    HStack {
                        SectionLabel(text: "Συνέχισε να διαβάζεις")
                        Spacer()
                        NavigationLink(value: Route.history) { Text("Όλα ›").font(F.body(13, .heavy)).foregroundStyle(C.gold) }.buttonStyle(.plain)
                    }
                    VStack(spacing: 0) { ForEach(p.history.prefix(3)) { PostRow(p: $0) } }
                }

                // Χωρίς διαφημίσεις (rewarded)
                if let cfg = app.config?.ads, cfg.enabled, cfg.rewardOn {
                    if ads.adFree {
                        HStack(spacing: 12) {
                            iconBox("checkmark.seal.fill", true)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Χωρίς διαφημίσεις").font(F.body(15, .heavy)).foregroundStyle(C.text)
                                Text("μέχρι " + until(ads.adFreeUntil) + " · ευχαριστούμε! 💛").font(F.body(12)).foregroundStyle(C.gold)
                            }
                            Spacer()
                        }.padding(16).card(18)
                    } else {
                        Button {
                            busy = true
                            ads.showReward(hours: cfg.rewardHours) { _ in busy = false }
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: "play.rectangle.fill").font(.system(size: 20)).foregroundStyle(C.ink).frame(width: 44, height: 44).background(Circle().fill(C.ink.opacity(0.12)))
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("\(cfg.rewardHours) ώρες χωρίς διαφημίσεις").font(F.body(16, .heavy))
                                    Text(ads.rewardReady ? "Δες ένα σύντομο βίντεο χορηγού" : "Ετοιμάζεται…").font(F.body(12, .semibold)).opacity(0.75)
                                }
                                Spacer()
                                if busy { ProgressView().tint(C.ink) } else { Image(systemName: "chevron.right").font(.system(size: 14, weight: .bold)) }
                            }
                            .foregroundStyle(C.ink).padding(14)
                            .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(C.goldGrad))
                        }
                        .buttonStyle(.plain).disabled(!ads.rewardReady || busy)
                    }
                }

                SectionLabel(text: "Ανάγνωση")
                group {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 12) {
                            iconBox("textformat.size", true)
                            Text("Μέγεθος γραμμάτων άρθρων").font(F.body(15, .heavy)).foregroundStyle(C.text)
                            Spacer()
                            Text("\(Int(size))").font(F.body(15, .heavy)).foregroundStyle(C.gold)
                        }
                        Slider(value: $size, in: 14...26, step: 1).tint(C.gold).padding(.leading, 52)
                        Text("Έτσι θα φαίνεται το κείμενο του άρθρου.").font(.custom("ManropeExtraLight-Medium", fixedSize: size)).foregroundStyle(C.text2).padding(.leading, 52)
                    }.padding(.horizontal, 16).padding(.vertical, 12)
                    sep
                    toggle("arrow.down.circle", "Εξοικονόμηση δεδομένων", "Μικρότερες εικόνες: λιγότερα MB όταν δεν έχεις Wi-Fi.", $p.dataSaver)
                }

                SectionLabel(text: "Εφαρμογή")
                group {
                    toggle("chart.line.uptrend.xyaxis", "Ανώνυμα στατιστικά", "Βοηθούν να βελτιώνουμε το AEK Hub (ποια άρθρα και αγώνες διαβάζονται). Χωρίς προσωπικά στοιχεία.", $p.stats)
                    sep
                    rowButton("trash", "Καθάρισμα μνήμης", cache > 0 ? "Προσωρινά αρχεία: " + ByteCountFormatter.string(fromByteCount: Int64(cache), countStyle: .file) : "Εικόνες και αποθηκευμένες σελίδες") {
                        Api.shared.clearCache(); ImageLoader.cache.removeAllObjects(); haptic(.medium); cache = Api.shared.cacheBytes
                    }
                    if !blockedRaw.isEmpty {
                        sep
                        rowButton("person.crop.circle.badge.xmark", "Κρυμμένοι χρήστες σχολίων (\(blockedRaw.split(separator: "\n").count))", "Πάτα για να ξαναβλέπεις τα σχόλιά τους") { blockedRaw = "" }
                    }
                    if ads.privacyButton {
                        sep
                        rowButton("hand.raised", "Ρυθμίσεις απορρήτου", "Διαφημίσεις & συγκατάθεση") { ads.showPrivacy() }
                    }
                    sep
                    if let u = URL(string: Api.site) {
                        ShareLink(item: u, subject: Text("AEK Hub"), message: Text("Όλα για την ΑΕΚ στο AEK Hub 💛🖤")) {
                            rowLabel("square.and.arrow.up", "Πες το σε έναν φίλο", "Μοιράσου το AEK Hub")
                        }.buttonStyle(.plain)
                        sep
                    }
                    Link(destination: URL(string: Api.site + "/politiki-aporritou/")!) { rowLabel("lock.shield", "Πολιτική απορρήτου", "aekhub.gr") }.buttonStyle(.plain)
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
            .padding(.horizontal, hsc == .regular ? 28 : screenPad).padding(.bottom, 32)
            .readable(hsc == .regular ? 900 : 680)
        }
        .background(C.ink)
        .sheet(isPresented: $showCal) { CalendarSheet().environmentObject(AppState.shared) }
        .task {
            Analytics.screen(6, name: "me")
            status = await Notifier.shared.status()
            cache = Api.shared.cacheBytes
            while !Task.isCancelled { try? await Task.sleep(nanoseconds: 2_000_000_000); tick += 1 }
        }
    }

    func until(_ t: Double) -> String {
        let f = DateFormatter(); f.locale = Locale(identifier: "el_GR"); f.dateFormat = "EEE HH:mm"
        return f.string(from: Date(timeIntervalSince1970: t))
    }

    func tile(_ icon: String, _ title: String, _ sub: String, on: Bool) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Image(systemName: icon).font(.system(size: 18, weight: .semibold)).foregroundStyle(on ? C.ink : C.muted)
                .frame(width: 38, height: 38).background(Circle().fill(on ? C.gold : C.panel3))
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(F.body(15, .heavy)).foregroundStyle(C.text).lineLimit(1)
                Text(sub).font(F.body(12)).foregroundStyle(on ? C.muted : C.live).lineLimit(1).minimumScaleFactor(0.8)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .card(18)
        .contentShape(Rectangle())
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
    func toggle(_ icon: String, _ t: String, _ sub: String, _ b: Binding<Bool>) -> some View {
        Toggle(isOn: b) {
            HStack(alignment: .top, spacing: 12) {
                iconBox(icon, b.wrappedValue)
                VStack(alignment: .leading, spacing: 3) {
                    Text(t).font(F.body(15, .heavy)).foregroundStyle(b.wrappedValue ? C.text : C.text2)
                    Text(sub).font(F.body(12)).foregroundStyle(C.muted)
                }
            }
        }.toggleStyle(GoldToggle()).padding(.horizontal, 16).padding(.vertical, 14)
    }
    func rowLabel(_ icon: String, _ t: String, _ sub: String) -> some View {
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
    }
    func rowButton(_ icon: String, _ t: String, _ sub: String, _ action: @escaping () -> Void) -> some View {
        Button(action: action) { rowLabel(icon, t, sub) }.buttonStyle(.plain)
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
