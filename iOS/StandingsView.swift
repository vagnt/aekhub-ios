import SwiftUI

/// Βαθμολογίες όλων των διοργανώσεων (ίδιοι πίνακες με το site)
struct StandingsView: View {
    @State private var items: [Standing] = Api.shared.peek(Api.pStandings)?["items"].list(Standing.init) ?? []
    @State private var sel = 0
    @State private var error: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                if items.isEmpty {
                    if let error { EmptyState(icon: "wifi.exclamationmark", text: error) { Task { await load() } } }
                    else { ProgressView().tint(C.gold).frame(maxWidth: .infinity).padding(60) }
                } else {
                    ChipRow(items: items.map { (String($0.id), $0.title) }, selected: String(current.id)) { k in
                        sel = items.firstIndex { String($0.id) == k } ?? 0
                    }.padding(.vertical, 10)
                    StandingTable(s: current).padding(.horizontal, 16).frame(maxWidth: 820)
                }
            }.padding(.bottom, 24)
        }
        .background(C.ink)
        .navigationTitle("Βαθμολογίες")
        .navigationBarTitleDisplayMode(.inline)
        .refreshable { await load() }
        .task { Analytics.screen(6, name: "standings"); await load() }
    }

    var current: Standing { items[min(sel, items.count - 1)] }

    func load() async {
        do { items = try await Api.shared.standings(); error = nil }
        catch { if items.isEmpty { self.error = "Δεν φόρτωσαν οι βαθμολογίες.\n" + error.localizedDescription } }
    }
}

struct StandingTable: View {
    let s: Standing
    var draws: Bool { s.style.contains("d") || s.style == "wdl" }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 10) {
                if !s.leagueLogo.isEmpty { TeamLogo(url: s.leagueLogo, size: 30) }
                VStack(alignment: .leading, spacing: 2) {
                    Text(s.title.upperGr).font(F.disp(22, black: true)).foregroundStyle(C.text)
                    if !s.league.isEmpty && s.league != s.title { Text(s.league).font(F.body(12, .bold)).foregroundStyle(C.muted) }
                }
            }.padding(14)

            Grid(alignment: .leading, horizontalSpacing: 6, verticalSpacing: 0) {
                GridRow {
                    Text("#").frame(width: 30)
                    Text("Ομάδα").frame(maxWidth: .infinity, alignment: .leading)
                    Text("Αγ").gridColumnAlignment(.trailing)
                    Text("Ν").gridColumnAlignment(.trailing)
                    if draws { Text("Ι").gridColumnAlignment(.trailing) }
                    Text("Η").gridColumnAlignment(.trailing)
                    Text("Β").gridColumnAlignment(.trailing)
                }
                .font(F.body(11, .extra)).foregroundStyle(C.muted).padding(.vertical, 8)
                ForEach(s.rows, id: \.self) { r in
                    GridRow {
                        HStack(spacing: 4) {
                            RoundedRectangle(cornerRadius: 2).fill(zone(r.pos) ?? .clear).frame(width: 4, height: 22)
                            Text("\(r.pos)").font(F.body(13, .extra)).frame(width: 22)
                        }
                        HStack(spacing: 8) {
                            TeamLogo(url: r.logo, size: 22)
                            Text(r.name).font(F.body(14, r.aek ? .extra : .bold)).lineLimit(1)
                        }.frame(maxWidth: .infinity, alignment: .leading)
                        Text(r.played)
                        Text(r.won)
                        if draws { Text(r.drawn) }
                        Text(r.lost)
                        Text(r.points).font(F.body(14, .extra)).foregroundStyle(r.aek ? C.ink : C.gold)
                    }
                    .font(F.body(13, .bold)).monospacedDigit()
                    .foregroundStyle(r.aek ? C.ink : C.text)
                    .padding(.vertical, 8).padding(.trailing, 8)
                    .background(r.aek ? C.gold : Color.clear)
                    .overlay(alignment: .bottom) { Rectangle().fill(C.line).frame(height: 1).opacity(r.aek ? 0 : 0.7) }
                }
            }

            let zs = s.zones.filter { !$0.label.isEmpty }
            if !zs.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(zs, id: \.self) { z in
                        HStack(spacing: 8) {
                            RoundedRectangle(cornerRadius: 2).fill(Color(hexString: z.color) ?? C.gold).frame(width: 10, height: 10)
                            Text(z.label).font(F.body(12, .bold)).foregroundStyle(C.text2)
                        }
                    }
                }.padding(14)
            }
        }
        .background(RoundedRectangle(cornerRadius: 14).fill(C.panel))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    func zone(_ pos: Int) -> Color? {
        s.zones.first { pos >= $0.from && pos <= $0.to }.map { Color(hexString: $0.color) ?? C.gold }
    }
}
