import SwiftUI

/// Πρόγραμμα & αποτελέσματα όλων των τμημάτων, ανά μέρα, με φίλτρο αθλήματος.
struct MatchesView: View {
    @EnvironmentObject var app: AppState
    @State private var sport = ""
    @State private var list: MatchList? = Api.shared.peek(Api.pMatches()).map(MatchList.init)
    @State private var from: String?
    @State private var error: String?
    @State private var loading = false
    @State private var scrolled = false

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0, pinnedViews: []) {
                    ChipRow(items: [("", "Όλα")] + (app.config?.sports ?? []).map { ($0.key, $0.name) }, selected: sport) { k in
                        sport = k; scrolled = false; from = nil
                        list = Api.shared.peek(Api.pMatches(sport: k)).map(MatchList.init)
                        Task { await load() }
                    }.padding(.vertical, 10)

                    if let l = list {
                        Button { Task { await older(l) } } label: {
                            Label("Παλαιότεροι αγώνες", systemImage: "chevron.up").font(F.body(13, .extra)).foregroundStyle(C.gold)
                                .frame(maxWidth: .infinity).padding(.vertical, 10)
                        }
                        let days = Dictionary(grouping: l.items, by: \.date)
                        ForEach(days.keys.sorted(), id: \.self) { d in
                            VStack(alignment: .leading, spacing: 8) {
                                HStack(spacing: 8) {
                                    Text(Fmt.dayHeader(d)).font(F.body(12, .extra)).foregroundStyle(Fmt.isToday(d) ? C.gold : C.text2)
                                    if Fmt.isToday(d) { Text("ΣΗΜΕΡΑ").font(F.body(10, .extra)).foregroundStyle(C.ink).padding(.horizontal, 6).padding(.vertical, 2).background(Capsule().fill(C.gold)) }
                                }.padding(.top, 14)
                                LazyVGrid(columns: adaptiveCols, spacing: 10) {
                                    ForEach(days[d]!.sorted { $0.time < $1.time }) { MatchRow(m: $0) }
                                }
                            }
                            .padding(.horizontal, 16)
                            .id(d)
                        }
                        if l.items.isEmpty { EmptyState(icon: "calendar", text: "Δεν υπάρχουν αγώνες σε αυτό το διάστημα.") }
                    } else if let error {
                        EmptyState(icon: "wifi.exclamationmark", text: error) { Task { await load() } }
                    } else {
                        ProgressView().tint(C.gold).frame(maxWidth: .infinity).padding(60)
                    }
                }.padding(.bottom, 24)
            }
            .onChange(of: list?.items.count ?? 0) { _ in scrollToToday(proxy) }
            .onAppear { scrollToToday(proxy) }
        }
        .background(C.ink)
        .navigationTitle("Αγώνες")
        .navigationBarTitleDisplayMode(.inline)
        .refreshable { await load() }
        .task {
            await load()
            while !Task.isCancelled {
                let live = list?.items.contains { $0.live } == true
                try? await Task.sleep(nanoseconds: (live ? 15 : 90) * 1_000_000_000)
                await load()
            }
        }
    }

    /// Πρώτη φορά: πήγαινε στη σημερινή (ή την πρώτη επόμενη) μέρα
    func scrollToToday(_ proxy: ScrollViewProxy) {
        guard !scrolled, let l = list, !l.items.isEmpty else { return }
        let today = Fmt.ymdString(Date())
        if let d = Set(l.items.map(\.date)).sorted().first(where: { $0 >= today }) {
            scrolled = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { proxy.scrollTo(d, anchor: .top) }
        }
    }

    func load() async {
        guard !loading else { return }
        loading = true; defer { loading = false }
        do {
            let to = list?.to.isEmpty == false ? list?.to : nil
            list = try await Api.shared.matches(from: from, to: from == nil ? nil : to, sport: sport.isEmpty ? nil : sport)
            error = nil
        } catch { if list == nil { self.error = "Δεν φόρτωσαν οι αγώνες.\n" + error.localizedDescription } }
    }

    /// 21 μέρες πιο πίσω
    func older(_ l: MatchList) async {
        guard let f = Fmt.day(l.from.isEmpty ? Fmt.ymdString(Date()) : l.from),
              let nf = Fmt.cal.date(byAdding: .day, value: -21, to: f) else { return }
        from = Fmt.ymdString(nf)
        scrolled = true
        await load()
    }
}
