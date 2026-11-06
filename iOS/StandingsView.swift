import SwiftUI

/// Βαθμολογίες: Άθλημα + Διοργάνωση (γυάλινα dropdown) → πίνακας με ζώνες, η ΑΕΚ τονισμένη (όπως στο σχέδιο)
struct StandingsView: View {
    @State private var items: [Standing] = Api.shared.peek(Api.pStandings)?["items"].list(Standing.init) ?? []
    @State private var sport = ""
    @State private var sel = 0
    @State private var error: String?

    var sports: [String] { var seen: [String] = []; for s in items where !seen.contains(s.sport) { seen.append(s.sport) }; return seen }
    var inSport: [Standing] { items.filter { sport.isEmpty || $0.sport == sport } }
    var current: Standing? { inSport.first { $0.id == sel } ?? inSport.first }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                ScreenTitle(text: "Βαθμολογίες")
                if items.isEmpty {
                    if let error { EmptyState(icon: "wifi.exclamationmark", text: error) { Task { await load() } } }
                    else { ProgressView().tint(C.gold).frame(maxWidth: .infinity).padding(60) }
                } else if let s = current {
                    HStack(spacing: 10) {
                        GlassPicker(label: "Άθλημα", value: s.sport, options: sports.map { ($0, $0) }) { k in
                            sport = k; sel = items.first { $0.sport == k }?.id ?? 0
                        }
                        .frame(maxWidth: 200)
                        GlassPicker(label: "Διοργάνωση", value: s.title, options: inSport.map { (String($0.id), $0.title) }) { k in sel = Int(k) ?? 0 }
                    }
                    .padding(.horizontal, screenPad)
                    StandingTable(s: s).padding(.horizontal, 12).frame(maxWidth: 820)
                }
            }.padding(.bottom, 24)
        }
        .background(C.ink)
        .refreshable { await load() }
        .task { Analytics.screen(6, name: "standings"); await load() }
    }

    func load() async {
        do {
            items = try await Api.shared.standings(); error = nil
            if sport.isEmpty, let first = items.first { sport = first.sport; sel = first.id }
        } catch { if items.isEmpty { self.error = "Δεν φόρτωσαν οι βαθμολογίες.\n" + error.localizedDescription } }
    }
}

struct StandingTable: View {
    let s: Standing
    var draws: Bool { s.style.contains("d") }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 10) {
                if !s.leagueLogo.isEmpty { TeamLogo(url: s.leagueLogo, size: 28) }
                Text(s.title.upperGr).font(F.disp(24)).foregroundStyle(C.text).lineLimit(1).minimumScaleFactor(0.7)
            }
            .padding(.horizontal, 18).padding(.top, 18).padding(.bottom, 10)

            Grid(alignment: .leading, horizontalSpacing: 0, verticalSpacing: 0) {
                GridRow {
                    Text("#").frame(width: 46, alignment: .center)
                    Text("ΟΜΑΔΑ").frame(maxWidth: .infinity, alignment: .leading)
                    num("ΑΓ"); num("Ν"); if draws { num("Ι") }; num("Η"); num("+/−", w: 40)
                    Text("Β").foregroundStyle(C.gold).frame(width: 36, alignment: .center)
                }
                .font(F.tag(11)).tracking(0.8).foregroundStyle(C.muted).padding(.vertical, 8)

                ForEach(s.rows, id: \.self) { r in
                    GridRow {
                        Text("\(r.pos)").font(F.body(13, .bold)).foregroundStyle(r.aek ? C.ink : C.text2)
                            .frame(width: 26, height: 26)
                            .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(r.aek ? C.gold : C.panel3))
                            .frame(width: 46)
                        HStack(spacing: 8) {
                            TeamLogo(url: r.logo, size: 22, name: r.name)
                            Text(r.name.upperGr).font(F.disp(17)).foregroundStyle(r.aek ? C.gold : C.text).lineLimit(1).minimumScaleFactor(0.75)
                        }.frame(maxWidth: .infinity, alignment: .leading)
                        num(r.played); num(r.won); if draws { num(r.drawn) }; num(r.lost)
                        Text(gd(r)).font(F.body(14, .medium)).foregroundStyle(gdColor(r)).frame(width: 40, alignment: .center).monospacedDigit()
                        Text(r.points).font(F.body(16, .heavy)).foregroundStyle(r.aek ? C.gold : C.text).frame(width: 36, alignment: .center).monospacedDigit()
                    }
                    .font(F.body(14)).foregroundStyle(C.text2)
                    .padding(.vertical, 12)
                    .background(r.aek ? C.gold.opacity(0.13) : Color.clear)
                    .overlay(alignment: .leading) { Rectangle().fill(zone(r.pos) ?? .clear).frame(width: 3) }
                }
            }

            let zs = s.zones.filter { !$0.label.isEmpty }
            if !zs.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(zs, id: \.self) { z in
                        HStack(spacing: 8) {
                            RoundedRectangle(cornerRadius: 2).fill(Color(hexString: z.color) ?? C.gold).frame(width: 10, height: 10)
                            Text(z.label).font(F.body(13)).foregroundStyle(C.text2)
                        }
                    }
                }.padding(16)
            }
        }
        .background(RoundedRectangle(cornerRadius: 28, style: .continuous).fill(C.panel))
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 28, style: .continuous).stroke(C.line, lineWidth: 1))
    }

    func num(_ t: String, w: CGFloat = 30) -> some View { Text(t).frame(width: w, alignment: .center).monospacedDigit() }
    func gdVal(_ r: StandingRow) -> Int? { guard let f = Int(r.gf), let a = Int(r.ga) else { return nil }; return f - a }
    func gd(_ r: StandingRow) -> String { guard let v = gdVal(r) else { return "" }; return v > 0 ? "+\(v)" : (v < 0 ? "−\(-v)" : "0") }
    func gdColor(_ r: StandingRow) -> Color { guard let v = gdVal(r) else { return C.muted }; return v > 0 ? C.win : (v < 0 ? C.live : C.muted) }
    func zone(_ pos: Int) -> Color? {
        s.zones.first { pos >= $0.from && pos <= $0.to }.map { Color(hexString: $0.color) ?? C.gold }
    }
}
