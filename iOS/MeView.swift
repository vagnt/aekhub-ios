import SwiftUI

/// «Εγώ»: social, ρυθμίσεις ανάγνωσης, ειδοποιήσεις (έρχονται με λογαριασμό Apple Developer), πληροφορίες.
struct MeView: View {
    @EnvironmentObject var app: AppState
    @AppStorage("articleSize") private var size: Double = 17
    @State private var diag = ""

    var body: some View {
        List {
            Section {
                HStack(spacing: 14) {
                    Image("HubLogo").resizable().scaledToFit().frame(width: 56, height: 56).clipShape(RoundedRectangle(cornerRadius: 12))
                    VStack(alignment: .leading, spacing: 3) {
                        Text("AEK Hub").font(F.disp(26, black: true)).foregroundStyle(C.text)
                        Text("Όλη η ΑΕΚ, όλα τα τμήματα").font(F.body(13, .bold)).foregroundStyle(C.muted)
                    }
                }.listRowBackground(C.panel)
            }

            Section {
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: "bell.badge").foregroundStyle(C.gold).font(.system(size: 20))
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Ειδοποιήσεις").font(F.body(15, .extra)).foregroundStyle(C.text)
                        Text("Στο iPhone οι ειδοποιήσεις (γκολ, σέντρα, τελικό, έκτακτα) ενεργοποιούνται όταν η εφαρμογή μπει στο App Store. Μέχρι τότε, άνοιξε το app για live σκορ.")
                            .font(F.body(12, .medium)).foregroundStyle(C.text2)
                    }
                }.listRowBackground(C.panel)
            } header: { Text("ΕΙΔΟΠΟΙΗΣΕΙΣ").font(F.body(11, .extra)) }

            Section {
                VStack(alignment: .leading, spacing: 8) {
                    HStack { Text("Μέγεθος γραμμάτων άρθρων").font(F.body(14, .bold)); Spacer(); Text("\(Int(size))").font(F.body(14, .extra)).foregroundStyle(C.gold) }
                    Slider(value: $size, in: 14...26, step: 1).tint(C.gold)
                    Text("Η ΑΕΚ είναι κάτι παραπάνω από μια ομάδα.").font(.custom("ManropeExtraLight-Medium", size: size)).foregroundStyle(C.text2)
                }.listRowBackground(C.panel)
            } header: { Text("ΑΝΑΓΝΩΣΗ").font(F.body(11, .extra)) }

            if let s = app.config?.socials, !s.isEmpty {
                Section {
                    ForEach(s, id: \.self) { so in
                        Link(destination: URL(string: so.url) ?? URL(string: Api.site)!) {
                            HStack {
                                Text(so.label.isEmpty ? so.key.capitalized : so.label).font(F.body(14, .bold)).foregroundStyle(C.text)
                                Spacer()
                                Text(so.handle).font(F.body(12, .bold)).foregroundStyle(C.muted)
                                Image(systemName: "arrow.up.right").font(.system(size: 12)).foregroundStyle(C.gold)
                            }
                        }.listRowBackground(C.panel)
                    }
                } header: { Text("ΑΚΟΛΟΥΘΗΣΕ ΜΑΣ").font(F.body(11, .extra)) }
            }

            Section {
                Link("Άνοιξε το aekhub.gr", destination: URL(string: Api.site)!).listRowBackground(C.panel)
                Link("Πολιτική απορρήτου", destination: URL(string: Api.site + "/politiki-aporritou/")!).listRowBackground(C.panel)
            }.font(F.body(14, .bold)).foregroundStyle(C.gold)

            Section {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Έκδοση \(Api.version) (build \(Api.build)) · iOS").font(F.body(12, .bold)).foregroundStyle(C.text2)
                    Text(diag).font(F.body(11, .medium)).foregroundStyle(C.muted)
                }.listRowBackground(C.panel)
            } header: { Text("ΠΛΗΡΟΦΟΡΙΕΣ").font(F.body(11, .extra)) }
        }
        .scrollContentBackground(.hidden)
        .background(C.ink)
        .navigationTitle("Εγώ")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            let f = DateFormatter(); f.dateFormat = "d/M HH:mm:ss"
            diag = (Api.shared.lastOk.map { "Τελευταία σύνδεση: " + f.string(from: $0) } ?? "Καμία σύνδεση ακόμη") + (Api.shared.lastErr.isEmpty ? "" : "\nΤελευταίο σφάλμα: " + Api.shared.lastErr)
        }
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
                        if e.live { HStack(spacing: 6) { LiveDot(); Text("LIVE").font(F.body(12, .extra)).foregroundStyle(C.live) } }
                        else if !e.statusLabel.isEmpty { Text(e.statusLabel.upperGr).font(F.body(11, .extra)).foregroundStyle(C.muted) }
                        Text(e.title).font(F.disp(30, black: true)).foregroundStyle(C.text)
                    }.padding(.horizontal, 16)
                    ForEach(e.updates) { u in
                        VStack(alignment: .leading, spacing: 6) {
                            HStack(spacing: 8) {
                                Text([u.minute, u.time].first { !$0.isEmpty } ?? "").font(F.body(12, .extra)).foregroundStyle(C.gold)
                                if !u.typeLabel.isEmpty { Text(u.typeLabel.upperGr).font(F.body(10, .extra)).foregroundStyle(C.muted) }
                            }
                            if !u.title.isEmpty { Text(u.title).font(F.body(15, .extra)).foregroundStyle(C.text) }
                            if !u.text.isEmpty { Text(u.text.plainText).font(F.body(14, .medium)).foregroundStyle(C.text2) }
                            if !u.thumb.isEmpty { NetImage(url: u.thumb, w: 800).frame(height: 180).frame(maxWidth: .infinity).clipped().clipShape(RoundedRectangle(cornerRadius: 10)) }
                            if let l = [u.video, u.link].first(where: { !$0.isEmpty }), let url = URL(string: l) {
                                Button { openURL = url } label: { Label(u.video.isEmpty ? "Άνοιγμα" : "Δες το βίντεο", systemImage: u.video.isEmpty ? "link" : "play.fill") }
                                    .font(F.body(13, .extra)).foregroundStyle(C.gold)
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
            await load()
            while !Task.isCancelled { try? await Task.sleep(nanoseconds: 20_000_000_000); await load() }
        }
    }
    func load() async { if let x = try? await Api.shared.event(id) { e = x } }
}
