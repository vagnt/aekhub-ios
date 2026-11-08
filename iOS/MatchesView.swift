import SwiftUI

/// Αγώνες μέρα-μέρα (Android MatchesScreen): λωρίδα ημερών που κυλάει (45 μέρες πίσω – 90 μπροστά),
/// σύρσιμο αριστερά/δεξιά για αλλαγή μέρας, «Επιστροφή στο σήμερα», άθλημα (dropdown), 📅 ημερολόγιο.
struct MatchesView: View {
    @ObservedObject var app = AppState.shared
    @Environment(\.horizontalSizeClass) var hsc
    @State private var sport = ""
    @State private var list: [MatchCard]?
    @State private var error = false
    @State private var page = MatchesView.back
    @State private var showCal = false
    /// iPad: ο αγώνας που φαίνεται δεξιά
    @State private var selected: Int?

    static let back = 45
    static let fwd = 90
    let today = Fmt.cal.startOfDay(for: Date())
    var days: [Date] { (0...(MatchesView.back + MatchesView.fwd)).map { Fmt.cal.date(byAdding: .day, value: $0 - MatchesView.back, to: today)! } }
    var startS: String { Fmt.ymdString(days.first!) }
    var endS: String { Fmt.ymdString(days.last!) }
    var byDay: [String: [MatchCard]] { Dictionary(grouping: list ?? [], by: \.date) }

    var body: some View {
        Group {
            if hsc == .regular {
                // iPad: λίστα αριστερά, ο αγώνας ανοιχτός δεξιά (όπως Mail/Apple Sports)
                let cur = selected ?? autoSel
                HStack(spacing: 0) {
                    listColumn.frame(width: 440)
                    Rectangle().fill(C.line).frame(width: 1).ignoresSafeArea()
                    ZStack {
                        if let id = cur { MatchView(id: id, embedded: true).id(id).transition(.opacity) }
                        else {
                            VStack(spacing: 12) {
                                Image(systemName: "sportscourt").font(.system(size: 44)).foregroundStyle(C.gold)
                                Text("Διάλεξε έναν αγώνα").font(F.disp(26)).foregroundStyle(C.text)
                                Text("Θα ανοίξει εδώ, με πορεία, στατιστικά και συνθέσεις.").font(F.body(14)).foregroundStyle(C.muted)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .animation(.easeOut(duration: 0.2), value: cur)
                }
                .environment(\.matchPick, { (id: Int) in selected = id })
                .environment(\.matchSel, cur)
            } else {
                listColumn
            }
        }
        .background(C.ink)
        .sheet(isPresented: $showCal) { CalendarSheet().environmentObject(AppState.shared) }
        .onChange(of: page) { _ in haptic(.soft); selected = nil }
        .task {
            Analytics.screen(6, name: "matches")
            list = Api.shared.peek(Api.pMatches(from: startS, to: endS, sport: nil)).map { MatchList($0).items }
            await load()
            while !Task.isCancelled {
                let live = list?.contains { $0.live } == true
                try? await Task.sleep(nanoseconds: (live ? 15 : 90) * 1_000_000_000)
                await load()
            }
        }
    }

    /// iPad: χωρίς επιλογή → ο live αγώνας της μέρας ή ο πρώτος
    var autoSel: Int? {
        let ms = (byDay[Fmt.ymdString(days[page])] ?? []).sorted { $0.time < $1.time }
        return (ms.first { $0.live } ?? ms.first)?.id
    }

    var listColumn: some View {
        VStack(spacing: 0) {
            HStack {
                ScreenTitle(text: "Αγώνες")
                Spacer()
                Button { showCal = true } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "calendar").font(.system(size: 15, weight: .semibold))
                        Text("Στο ημερολόγιο").font(F.body(13, .heavy))
                    }
                    .foregroundStyle(C.ink).padding(.horizontal, 12).padding(.vertical, 8)
                    .background(Capsule().fill(C.gold))
                }.buttonStyle(.plain)
            }
            .padding(.horizontal, screenPad).padding(.top, 14).padding(.bottom, 8)

            let opts = [("", "Όλα τα αθλήματα")] + (app.config?.sports ?? []).map { ($0.key, $0.name) }
            AekDropdown(label: "Άθλημα", value: opts.first { $0.0 == sport }?.1 ?? "Όλα τα αθλήματα", options: opts) { k in
                sport = k
                list = Api.shared.peek(Api.pMatches(from: startS, to: endS, sport: k)).map { MatchList($0).items }
                Task { await load() }
            }
            .padding(.horizontal, screenPad).padding(.bottom, 10)

            strip
            dayHeader

            if list == nil {
                if error { EmptyState(icon: "wifi.exclamationmark", text: "Δεν φόρτωσε. Έλεγξε τη σύνδεση.") { Task { await load() } } }
                else { ProgressView().tint(C.gold).frame(maxWidth: .infinity).padding(40) }
                Spacer()
            } else {
                TabView(selection: $page) {
                    ForEach(days.indices, id: \.self) { i in dayPage(i).tag(i) }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
            }
        }
        .background(C.ink)
    }

    // MARK: Λωρίδα ημερών (κυλάει, ακολουθεί τη σελίδα)

    var strip: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 4) {
                    ForEach(days.indices, id: \.self) { i in
                        let d = days[i]
                        let on = i == page
                        let isToday = i == MatchesView.back
                        let has = byDay[Fmt.ymdString(d)]
                        Button { withAnimation(.easeInOut(duration: 0.25)) { page = i } } label: {
                            VStack(spacing: 1) {
                                Text(isToday ? "ΣΗΜ." : Fmt.daysShort[Fmt.cal.component(.weekday, from: d) - 1].upperGr)
                                    .font(F.body(10, .heavy)).foregroundStyle(on ? C.ink : (isToday ? C.gold : C.muted))
                                Text("\(Fmt.cal.component(.day, from: d))").font(F.body(17, .heavy)).foregroundStyle(on ? C.ink : C.text2)
                                Circle().fill(has == nil ? Color.clear : (has!.contains { $0.live } ? C.live : (on ? C.ink : C.gold))).frame(width: 5, height: 5)
                            }
                            .frame(width: 50).padding(.vertical, 7)
                            .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(on ? C.gold : Color.clear))
                            .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(isToday && !on ? C.gold : .clear, lineWidth: 1))
                        }
                        .buttonStyle(.plain)
                        .id(i)
                    }
                }
                .padding(.horizontal, 12)
            }
            .frame(height: 62)
            .onAppear { proxy.scrollTo(page, anchor: .center) }
            .onChange(of: page) { p in withAnimation(.easeOut(duration: 0.25)) { proxy.scrollTo(p, anchor: .center) } }
        }
    }

    var dayHeader: some View {
        let cur = days[page]
        let rel = page - MatchesView.back
        return VStack(spacing: 6) {
            HStack {
                Button { go(page - 1) } label: { Image(systemName: "chevron.left").font(.system(size: 17, weight: .semibold)).foregroundStyle(C.text).frame(width: 44, height: 44) }
                Spacer()
                VStack(spacing: 1) {
                    Text(rel == 0 ? "ΣΗΜΕΡΑ" : rel == 1 ? "ΑΥΡΙΟ" : rel == -1 ? "ΧΘΕΣ" : rel > 0 ? "ΣΕ \(rel) ΜΕΡΕΣ" : "ΠΡΙΝ \(-rel) ΜΕΡΕΣ")
                        .font(F.body(10, .heavy)).foregroundStyle(rel == 0 ? C.gold : C.muted)
                    Text(Fmt.dayHeader(Fmt.ymdString(cur))).font(F.disp(20)).foregroundStyle(C.text).lineLimit(1).minimumScaleFactor(0.65)
                }
                Spacer()
                Button { go(page + 1) } label: { Image(systemName: "chevron.right").font(.system(size: 17, weight: .semibold)).foregroundStyle(C.text).frame(width: 44, height: 44) }
            }
            .padding(.horizontal, 4)
            if rel != 0 {
                Button { go(MatchesView.back) } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.uturn.backward").font(.system(size: 13, weight: .bold))
                        Text("Επιστροφή στο σήμερα").font(F.body(13, .heavy))
                    }
                    .foregroundStyle(C.ink).padding(.horizontal, 14).padding(.vertical, 7)
                    .background(Capsule().fill(C.gold))
                }.buttonStyle(.plain)
                .transition(.scale.combined(with: .opacity))
            }
        }
        .padding(.top, 6).padding(.bottom, 4)
        .animation(.easeOut(duration: 0.2), value: rel == 0)
    }

    func go(_ i: Int) { withAnimation(.easeInOut(duration: 0.25)) { page = min(max(0, i), days.count - 1) } }

    @ViewBuilder func dayPage(_ i: Int) -> some View {
        let ms = (byDay[Fmt.ymdString(days[i])] ?? []).sorted { $0.time < $1.time }
        ScrollView {
            if ms.isEmpty {
                VStack(spacing: 16) {
                    Text("Δεν υπάρχουν αγώνες αυτή τη μέρα.").font(F.body(15, .bold)).foregroundStyle(C.text2).padding(.top, 30)
                    let next = days.indices.first { $0 > i && byDay[Fmt.ymdString(days[$0])] != nil }
                    let prev = days.indices.last { $0 < i && byDay[Fmt.ymdString(days[$0])] != nil }
                    if let t = next ?? prev {
                        Button { go(t) } label: {
                            Text((t == next ? "Επόμενος αγώνας: " : "Τελευταίος αγώνας: ") + short(days[t]) + (t == next ? " ›" : ""))
                                .font(F.body(14, .heavy)).foregroundStyle(C.gold).padding(.horizontal, 16).padding(.vertical, 10)
                                .overlay(RoundedRectangle(cornerRadius: 12).stroke(C.gold, lineWidth: 1))
                        }.buttonStyle(.plain)
                    }
                }
                .frame(maxWidth: .infinity).padding(24)
            } else {
                LazyVStack(spacing: 12) {
                    ForEach(Array(ms.enumerated()), id: \.element.id) { k, m in
                        MatchCardView(m: m)
                        if k == min(1, ms.count - 1), AppState.shared.config?.ads.matches == true { BannerAd(place: "matches") }
                    }
                }
                .padding(16)
            }
        }
        .refreshable { haptic(); await load() }
    }

    func short(_ d: Date) -> String {
        let c = Fmt.cal.dateComponents([.day, .month, .weekday], from: d)
        return Fmt.daysShort[c.weekday! - 1].upperGr + " \(c.day!) " + Fmt.monthsShort[c.month! - 1]
    }

    func load() async {
        do {
            let l = try await Api.shared.matches(from: startS, to: endS, sport: sport.isEmpty ? nil : sport)
            list = l.items; error = false
        } catch { if list == nil { self.error = true } }
    }
}
