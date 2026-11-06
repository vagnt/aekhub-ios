import SwiftUI

/// Βαθμολογίες — ΠΙΣΤΗ ΑΝΤΙΓΡΑΦΗ του Android StandingsScreen: Άθλημα → Διοργάνωση (δύο λίστες) → ένας πίνακας.
struct StandingsView: View {
    @State private var list: [Standing]? = Api.shared.peek(Api.pStandings)?["items"].list(Standing.init)
    @State private var sport = ""
    @State private var sel = 0
    @State private var error = false
    @Environment(\.horizontalSizeClass) var hsc

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ScreenTitle(text: "Βαθμολογίες").padding(.horizontal, hsc == .regular ? 28 : screenPad).padding(.top, 14).padding(.bottom, 8)
            if let l = list, !l.isEmpty {
                let sports = unique(l.map { $0.sport.isEmpty ? "Άλλα" : $0.sport })
                let sp = sports.contains(sport) ? sport : sports[0]
                let ofSport = l.filter { ($0.sport.isEmpty ? "Άλλα" : $0.sport) == sp }
                if hsc == .regular && UIScreen.main.bounds.width > UIScreen.main.bounds.height {
                    // iPad: όλες οι διοργανώσεις αριστερά (ανά άθλημα), ο πίνακας δεξιά
                    let t = l.first { $0.id == sel } ?? l.first { $0.rows.contains { $0.aek } } ?? l[0]
                    HStack(alignment: .top, spacing: 24) {
                        ScrollView {
                            VStack(alignment: .leading, spacing: 4) {
                                ForEach(sports, id: \.self) { spn in
                                    Text(spn.upperGr).font(F.body(11, .heavy)).tracking(1).foregroundStyle(C.muted).padding(.top, 14).padding(.bottom, 4).padding(.horizontal, 12)
                                    ForEach(l.filter { ($0.sport.isEmpty ? "Άλλα" : $0.sport) == spn }) { x in
                                        let on = x.id == t.id
                                        Button { haptic(.soft); sel = x.id } label: {
                                            HStack(spacing: 10) {
                                                if !x.leagueLogo.isEmpty { NetImage(url: x.leagueLogo, w: 80, mode: .fit).frame(width: 22, height: 22) }
                                                Text(x.league.isEmpty ? x.title : x.league).font(F.body(14, on ? .heavy : .medium)).foregroundStyle(on ? C.ink : C.text).lineLimit(2).multilineTextAlignment(.leading)
                                                Spacer(minLength: 0)
                                                if let a = x.rows.first(where: { $0.aek }) { Text("\(a.pos)η").font(F.body(12, .heavy)).foregroundStyle(on ? C.ink : C.gold) }
                                            }
                                            .padding(.horizontal, 12).padding(.vertical, 10)
                                            .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(on ? C.gold : .clear))
                                            .contentShape(Rectangle())
                                        }.buttonStyle(.plain)
                                    }
                                }
                            }.padding(.bottom, 30)
                        }
                        .frame(width: 270)
                        ScrollView {
                            VStack(spacing: 12) {
                                PresentedBy(place: "standings")
                                StandingTable(s: t, wide: UIScreen.main.bounds.width > 1150)
                                BannerAd(place: "home")
                            }.padding(.top, 8).padding(.bottom, 28).frame(maxWidth: 820)
                        }
                        .refreshable { haptic(); await load() }
                    }
                    .padding(.horizontal, 28)
                } else {
                    let t = ofSport.first { $0.id == sel } ?? ofSport.first { $0.rows.contains { $0.aek } } ?? ofSport[0]
                    HStack(spacing: 10) {
                        AekDropdown(label: "Άθλημα", value: sp, options: sports.map { ($0, $0) }) { sport = $0; sel = 0 }
                            .frame(width: 150)
                        AekDropdown(label: "Διοργάνωση", value: t.league.isEmpty ? t.title : t.league, options: ofSport.map { (String($0.id), $0.league.isEmpty ? $0.title : $0.league) }) { sel = Int($0) ?? 0 }
                            .frame(maxWidth: .infinity)
                    }
                    .padding(.horizontal, hsc == .regular ? 28 : screenPad).padding(.vertical, 4)
                    ScrollView {
                        VStack(spacing: 10) {
                            PresentedBy(place: "standings")
                            StandingTable(s: t)
                            BannerAd(place: "home")
                        }
                        .padding(.top, 8).padding(.bottom, 28).padding(.horizontal, hsc == .regular ? 28 : screenPad)
                        .readable(820)
                    }
                    .refreshable { haptic(); await load() }
                }
            } else if list != nil {
                Text("Δεν υπάρχουν βαθμολογίες ακόμα.").font(F.body(15)).foregroundStyle(C.muted).padding(24)
                Spacer()
            } else if error {
                EmptyState(icon: "wifi.exclamationmark", text: "Δεν φόρτωσε. Έλεγξε τη σύνδεση.") { Task { await load() } }
                Spacer()
            } else {
                ProgressView().tint(C.gold).frame(maxWidth: .infinity).padding(40)
                Spacer()
            }
        }
        .background(C.ink)
        .task {
            Analytics.screen(6, name: "standings")
            while !Task.isCancelled {
                await load()
                try? await Task.sleep(nanoseconds: 120_000_000_000)
            }
        }
    }

    func unique(_ a: [String]) -> [String] { var s = Set<String>(); return a.filter { s.insert($0).inserted } }

    func load() async {
        do { list = try await Api.shared.standings(); error = false } catch { if list == nil { self.error = true } }
    }
}

/// Πίνακας βαθμολογίας: ζώνη (4px) · θέση σε κουτάκι · σήμα · όνομα · ΑΓ Ν (Ι) Η · +/- · Β
struct StandingTable: View {
    let s: Standing
    var wide = false
    var wdl: Bool { s.style != "wl" }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                if !s.leagueLogo.isEmpty { NetImage(url: s.leagueLogo, w: 120, mode: .fit).frame(width: 34, height: 34) }
                Text(s.title.upperGr).font(F.disp(22)).foregroundStyle(C.text).lineLimit(2)
                Spacer(minLength: 0)
            }
            .padding(14)

            // κεφαλίδα
            HStack(spacing: 0) {
                Color.clear.frame(width: 4)
                Text("#").frame(width: 34)
                Text("ΟΜΑΔΑ").frame(maxWidth: .infinity, alignment: .leading)
                ForEach(wdl ? ["ΑΓ", "Ν", "Ι", "Η"] : ["ΑΓ", "Ν", "Η"], id: \.self) { Text($0).frame(width: 26, alignment: .trailing) }
                if wide { Text("ΓΚΟΛ").frame(width: 62, alignment: .trailing) }
                Text("+/-").frame(width: 34, alignment: .trailing)
                Text("Β").foregroundStyle(C.gold).frame(width: 40, alignment: .trailing).padding(.trailing, 10)
            }
            .font(F.body(10, .heavy)).foregroundStyle(C.muted).padding(.vertical, 6)

            ForEach(s.rows, id: \.self) { r in
                let z = s.zones.first { r.pos >= $0.from && r.pos <= $0.to }
                HStack(spacing: 0) {
                    Rectangle().fill(z.flatMap { Color(hexString: $0.color) } ?? C.panel).frame(width: 4)
                    Text("\(r.pos)").font(F.body(12, .heavy)).foregroundStyle(r.aek ? C.ink : C.text2)
                        .frame(width: 24, height: 24).background(RoundedRectangle(cornerRadius: 6).fill(r.aek ? C.gold : C.panel3))
                        .frame(width: 34)
                    HStack(spacing: 8) {
                        TeamLogo(url: r.logo, size: 24, name: r.name)
                        Text(r.name.upperGr).font(F.disp(wide ? 19 : 16)).foregroundStyle(r.aek ? C.gold : C.text).lineLimit(1).minimumScaleFactor(0.65)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    num(r.played); num(r.won); if wdl { num(r.drawn) }; num(r.lost)
                    if wide { num(r.gf.isEmpty ? "" : "\(r.gf):\(r.ga)", w: 62) }
                    num(diff(r), color: diffColor(r), w: 34)
                    Text(r.points).font(F.disp(18)).foregroundStyle(r.aek ? C.gold : C.text).frame(width: 40, alignment: .trailing).padding(.trailing, 10)
                }
                .frame(height: 46)
                .background(r.aek ? C.gold.opacity(0.13) : .clear)
            }

            let zs = s.zones.filter { !$0.label.isEmpty }
            if !zs.isEmpty {
                FlowLayout(spacing: 14) {
                    ForEach(zs, id: \.self) { z in
                        HStack(spacing: 6) {
                            Rectangle().fill(Color(hexString: z.color) ?? C.gold).frame(width: 12, height: 3)
                            Text(z.label).font(F.body(11, .bold)).foregroundStyle(C.text2)
                        }
                    }
                }
                .padding(14)
            }
        }
        .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(C.panel))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    func num(_ v: String, color: Color = C.text2, w: CGFloat = 26) -> some View {
        Text(v).font(F.body(13, .bold)).foregroundStyle(color).monospacedDigit().lineLimit(1).minimumScaleFactor(0.7).frame(width: w, alignment: .trailing)
    }
    func diff(_ r: StandingRow) -> String {
        guard let f = Int(r.gf), let a = Int(r.ga) else { return "" }
        let d = f - a
        return d > 0 ? "+\(d)" : "\(d)"
    }
    func diffColor(_ r: StandingRow) -> Color {
        let d = diff(r)
        return d.hasPrefix("+") ? C.win : (d.hasPrefix("-") ? C.loss : C.text2)
    }
}
