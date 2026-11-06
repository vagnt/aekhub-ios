import SwiftUI

/// 📅 Το πρόγραμμα της ΑΕΚ στο ημερολόγιο (ίδιο με το «Στο κινητό μου» του site):
/// αθλήματα + υπενθύμιση → Ημερολόγιο iPhone (webcal) / Google / Outlook / αντιγραφή. Μία φορά και τέλος.
struct CalendarSheet: View {
    @EnvironmentObject var app: AppState
    @Environment(\.dismiss) var dismiss
    @Environment(\.openURL) var openURL
    @State private var sel: Set<String> = []
    @State private var alarm = "60"
    @State private var copied = false

    var groups: [CalGroup] {
        if let g = app.config?.calendar?.groups, !g.isEmpty { return g }
        return (app.config?.sports ?? []).map { CalGroup(J(["k": $0.key, "l": $0.name])) }
    }
    var feed: String { app.config?.calendar?.feed.isEmpty == false ? app.config!.calendar!.feed : Api.site + "/?amc_ics=1" }
    var url: String {
        feed + (sel.isEmpty ? "" : "&s=" + groups.map(\.k).filter { sel.contains($0) }.joined(separator: ",")) + (alarm == "0" ? "" : "&a=" + alarm)
    }
    var webcal: String { url.replacingOccurrences(of: "^https?://", with: "webcal://", options: .regularExpression) }
    var name: String { (app.config?.calendar?.name ?? "AEK Hub") + (sel.isEmpty ? "" : " · " + groups.filter { sel.contains($0.k) }.map(\.l).joined(separator: " + ")) }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("ΤΟ ΠΡΟΓΡΑΜΜΑ ΤΗΣ ΑΕΚ ΣΤΟ ΗΜΕΡΟΛΟΓΙΟ ΣΟΥ").font(F.disp(24, black: true)).foregroundStyle(C.text)
                    Text("Μία φορά και τέλος: νέοι αγώνες, αλλαγές ώρας και τελικά σκορ περνάνε μόνα τους.").font(F.body(13, .medium)).foregroundStyle(C.text2)
                    label("ΑΘΛΗΜΑΤΑ")
                    FlowChips(items: [("", "Όλα", "")] + groups.map { ($0.k, $0.l, $0.c) }, isOn: { $0.isEmpty ? sel.isEmpty : sel.contains($0) }) { k in
                        if k.isEmpty { sel = [] } else if sel.contains(k) { sel.remove(k) } else { sel.insert(k) }
                    }
                    label("ΥΠΕΝΘΥΜΙΣΗ")
                    FlowChips(items: [("0", "Καμία", ""), ("30", "30′ πριν", ""), ("60", "1 ώρα", ""), ("180", "3 ώρες", ""), ("1440", "1 μέρα", "")], isOn: { $0 == alarm }) { alarm = $0 }
                    go("calendar", "Ημερολόγιο iPhone / iPad", "Συνδρομή · πάτα «Εγγραφή»") { if let u = URL(string: webcal) { openURL(u) } }
                    go("g.circle", "Google Calendar", "Αν χρησιμοποιείς Google") { if let u = URL(string: "https://calendar.google.com/calendar/r?cid=" + Api.q(webcal)) { openURL(u) } }
                    go("envelope", "Outlook", "Microsoft") { if let u = URL(string: "https://outlook.live.com/calendar/0/addfromweb?url=" + Api.q(url) + "&name=" + Api.q(name)) { openURL(u) } }
                    go(copied ? "checkmark" : "doc.on.doc", copied ? "Αντιγράφηκε ✓" : "Αντιγραφή link", "για οποιαδήποτε άλλη εφαρμογή") { UIPasteboard.general.string = url; copied = true }
                    Text("Για να το βγάλεις: Ρυθμίσεις → Ημερολόγιο → Λογαριασμοί → Συνδρομές.").font(F.body(12, .medium)).foregroundStyle(C.muted)
                }.padding(18)
            }
            .background(C.ink2)
            .toolbar { ToolbarItem(placement: .navigationBarTrailing) { Button("Κλείσιμο") { dismiss() } } }
        }
        .preferredColorScheme(.dark)
    }

    func label(_ t: String) -> some View { Text(t).font(F.body(11, .bold)).foregroundStyle(C.gold) }
    func go(_ icon: String, _ t: String, _ sub: String, _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon).foregroundStyle(C.gold).frame(width: 38, height: 38).background(Circle().fill(C.panel3))
                VStack(alignment: .leading, spacing: 2) {
                    Text(t).font(F.body(14, .bold)).foregroundStyle(C.text)
                    Text(sub).font(F.body(12, .medium)).foregroundStyle(C.muted)
                }
                Spacer()
            }
            .padding(12).background(RoundedRectangle(cornerRadius: 14).fill(C.panel)).overlay(RoundedRectangle(cornerRadius: 14).stroke(C.line))
        }.buttonStyle(.plain)
    }
}

/// Τσιπάκια που αναδιπλώνονται σε γραμμές
struct FlowChips: View {
    let items: [(String, String, String)]
    let isOn: (String) -> Bool
    let tap: (String) -> Void
    var body: some View {
        FlowLayout(spacing: 8) {
            ForEach(items, id: \.0) { it in
                let on = isOn(it.0)
                Button { tap(it.0) } label: {
                    HStack(spacing: 6) {
                        if !it.2.isEmpty { Circle().fill(Color(hexString: it.2) ?? C.gold).frame(width: 8, height: 8) }
                        Text(it.1).font(F.body(13, on ? .bold : .bold)).foregroundStyle(on ? C.ink : C.text)
                    }
                    .padding(.horizontal, 12).padding(.vertical, 7)
                    .background(Capsule().fill(on ? C.gold : C.panel2)).overlay(Capsule().stroke(on ? C.gold : C.line))
                }.buttonStyle(.plain)
            }
        }
    }
}

struct FlowLayout: Layout {
    var spacing: CGFloat = 8
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let w = proposal.width ?? 360
        var x: CGFloat = 0, y: CGFloat = 0, rowH: CGFloat = 0
        for s in subviews {
            let sz = s.sizeThatFits(.unspecified)
            if x + sz.width > w && x > 0 { x = 0; y += rowH + spacing; rowH = 0 }
            x += sz.width + spacing; rowH = max(rowH, sz.height)
        }
        return CGSize(width: w, height: y + rowH)
    }
    func placeSubviews(in b: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = b.minX, y = b.minY, rowH: CGFloat = 0
        for s in subviews {
            let sz = s.sizeThatFits(.unspecified)
            if x + sz.width > b.maxX && x > b.minX { x = b.minX; y += rowH + spacing; rowH = 0 }
            s.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(sz))
            x += sz.width + spacing; rowH = max(rowH, sz.height)
        }
    }
}
