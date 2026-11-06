import SwiftUI

/// Αγώνες: άθλημα (dropdown) · εβδομάδα με μέρες · μία μέρα τη φορά με μεγάλες κάρτες (όπως στο σχέδιο/Android)
struct MatchesView: View {
    @EnvironmentObject var app: AppState
    @State private var sport = ""
    @State private var list: MatchList? = Api.shared.peek(Api.pMatches()).map(MatchList.init)
    @State private var sel = ""
    @State private var error: String?
    @State private var loading = false
    @State private var showCal = false

    var today: String { Fmt.ymdString(Date()) }
    var items: [MatchCard] { list?.items ?? [] }
    var days: [String] { Array(Set(items.map(\.date))).sorted() }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .bottom) {
                    ScreenTitle(text: "Αγώνες").padding(.horizontal, -screenPad)
                    Spacer()
                    GlassCircle(icon: "calendar.badge.plus", size: 44) { showCal = true }
                }
                .padding(.horizontal, screenPad)

                GlassPicker(label: "Άθλημα", value: sport.isEmpty ? "Όλα τα αθλήματα" : (app.config?.sports.first { $0.key == sport }?.name ?? Sports.label(sport)),
                            options: [("", "Όλα τα αθλήματα")] + (app.config?.sports ?? []).map { ($0.key, $0.name) }) { k in
                    sport = k; sel = ""
                    list = Api.shared.peek(Api.pMatches(sport: k)).map(MatchList.init)
                    Task { await load() }
                }
                .padding(.horizontal, screenPad)

                weekStrip
                dayNav

                let dayItems = items.filter { $0.date == sel }.sorted { $0.time < $1.time }
                if list == nil {
                    if let error { EmptyState(icon: "wifi.exclamationmark", text: error) { Task { await load() } } }
                    else { ProgressView().tint(C.gold).frame(maxWidth: .infinity).padding(60) }
                } else if dayItems.isEmpty {
                    VStack(spacing: 14) {
                        EmptyState(icon: "calendar", text: "Δεν υπάρχουν αγώνες αυτή τη μέρα.")
                        if let n = days.first(where: { $0 > sel }) {
                            Button { withAnimation { sel = n } } label: {
                                Text("Επόμενοι αγώνες · " + Fmt.shortDay(n)).font(F.body(15, .bold)).foregroundStyle(C.ink)
                                    .padding(.horizontal, 20).padding(.vertical, 12).background(Capsule().fill(C.goldGrad))
                            }.buttonStyle(.plain)
                        }
                    }
                } else {
                    LazyVGrid(columns: adaptiveCols, spacing: 14) { ForEach(dayItems) { MatchCardBig(m: $0) } }
                        .padding(.horizontal, screenPad)
                }
            }
            .padding(.bottom, 24)
        }
        .background(C.ink)
        .refreshable { await load() }
        .sheet(isPresented: $showCal) { CalendarSheet().environmentObject(AppState.shared) }
        .task {
            Analytics.screen(6, name: "matches")
            pickDefault()
            await load()
            while !Task.isCancelled {
                let live = items.contains { $0.live }
                try? await Task.sleep(nanoseconds: (live ? 15 : 90) * 1_000_000_000)
                await load()
            }
        }
    }

    // MARK: Εβδομάδα

    var week: [String] {
        guard let d = Fmt.day(sel.isEmpty ? today : sel) else { return [] }
        let wd = Fmt.cal.component(.weekday, from: d) // 1 = Κυριακή
        let start = Fmt.cal.date(byAdding: .day, value: -(wd - 1), to: d)!
        return (0..<7).map { Fmt.ymdString(Fmt.cal.date(byAdding: .day, value: $0, to: start)!) }
    }

    var weekStrip: some View {
        HStack(spacing: 0) {
            ForEach(week, id: \.self) { d in
                let on = d == sel, isToday = d == today
                let has = days.contains(d)
                Button { withAnimation(.easeOut(duration: 0.2)) { sel = d }; ensureLoaded(d) } label: {
                    VStack(spacing: 3) {
                        Text(isToday ? "ΣΗΜ" : weekday(d)).font(F.body(12, .semibold)).foregroundStyle(on ? C.ink : C.muted)
                        Text(dayNum(d)).font(F.disp(26)).foregroundStyle(on ? C.ink : (has ? C.text : C.muted))
                        Circle().fill(has ? (on ? C.ink : C.gold) : .clear).frame(width: 4, height: 4)
                    }
                    .frame(width: 44, height: 70)
                    .background(Capsule().fill(on ? AnyShapeStyle(C.goldGrad) : AnyShapeStyle(Color.clear)))
                    .overlay(Capsule().stroke(isToday && !on ? C.gold : .clear, lineWidth: 1.5))
                    .frame(maxWidth: .infinity)
                }.buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 12)
    }

    var dayNav: some View {
        HStack {
            GlassCircle(icon: "chevron.left", size: 36) { step(-1) }
            Spacer()
            VStack(spacing: 2) {
                Text(relative(sel)).font(F.tag(11)).tracking(1).foregroundStyle(C.muted)
                Text(Fmt.dayHeader(sel.isEmpty ? today : sel)).font(F.disp(22)).foregroundStyle(C.text).lineLimit(1).minimumScaleFactor(0.7)
            }
            Spacer()
            GlassCircle(icon: "chevron.right", size: 36) { step(1) }
        }
        .padding(.horizontal, screenPad)
    }

    func weekday(_ d: String) -> String {
        guard let x = Fmt.day(d) else { return "" }
        return Fmt.daysShort[Fmt.cal.component(.weekday, from: x) - 1].upperGr
    }
    func dayNum(_ d: String) -> String { Fmt.day(d).map { String(Fmt.cal.component(.day, from: $0)) } ?? "" }
    func relative(_ d: String) -> String {
        guard let a = Fmt.day(today), let b = Fmt.day(d.isEmpty ? today : d) else { return "" }
        let n = Fmt.cal.dateComponents([.day], from: a, to: b).day ?? 0
        switch n {
        case 0: return "ΣΗΜΕΡΑ"
        case 1: return "ΑΥΡΙΟ"
        case -1: return "ΧΘΕΣ"
        case 2...: return "ΣΕ \(n) ΜΕΡΕΣ"
        default: return "ΠΡΙΝ \(-n) ΜΕΡΕΣ"
        }
    }

    /// Βέλη: στην επόμενη/προηγούμενη μέρα ΜΕ αγώνες (αν δεν υπάρχει, μία μέρα)
    func step(_ dir: Int) {
        let cur = sel.isEmpty ? today : sel
        let target = dir > 0 ? days.first { $0 > cur } : days.last { $0 < cur }
        let next = target ?? Fmt.day(cur).flatMap { Fmt.cal.date(byAdding: .day, value: dir, to: $0) }.map(Fmt.ymdString) ?? cur
        withAnimation(.easeOut(duration: 0.2)) { sel = next }
        ensureLoaded(next)
    }

    func pickDefault() {
        guard sel.isEmpty else { return }
        if days.contains(today) || items.isEmpty { sel = today; return }
        sel = days.first { $0 >= today } ?? days.last ?? today
    }

    /// Μέρα έξω από όσα έχουμε φορτώσει → φέρε το διάστημα γύρω της
    func ensureLoaded(_ d: String) {
        guard let l = list, !l.from.isEmpty, !l.to.isEmpty, d < l.from || d > l.to else { return }
        Task { await load(around: d) }
    }

    func load(around d: String? = nil) async {
        guard !loading else { return }
        loading = true; defer { loading = false }
        do {
            var from: String? = nil, to: String? = nil
            let c = d ?? ((list.map { sel < $0.from || sel > $0.to } ?? false) ? sel : nil)
            if let c, let x = Fmt.day(c) {
                from = Fmt.ymdString(Fmt.cal.date(byAdding: .day, value: -10, to: x)!)
                to = Fmt.ymdString(Fmt.cal.date(byAdding: .day, value: 14, to: x)!)
            }
            let l = try await Api.shared.matches(from: from, to: to, sport: sport.isEmpty ? nil : sport)
            list = l; error = nil
            pickDefault()
            if from == nil && sport.isEmpty { Notifier.shared.check(l.items) }
        } catch { if list == nil { self.error = "Δεν φόρτωσαν οι αγώνες.\n" + error.localizedDescription } }
    }
}
