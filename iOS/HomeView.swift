import SwiftUI

/// Αρχική — όπως το Android HomeScreen: αντίστροφη μέτρηση · έκτακτο · social · κατηγορίες (πλακίδια) · live ·
/// κύριο θέμα · τελευταία νέα · επόμενοι αγώνες · ενότητες κατηγοριών · social. iPad: 2–3 στήλες.
struct HomeView: View {
    @EnvironmentObject var app: AppState
    @Environment(\.horizontalSizeClass) var hsc
    @State private var data: HomeData? = Api.shared.peek(Api.pHome).map(HomeData.init)
    @State private var matches: [MatchCard] = Api.shared.peek(Api.pMatches()).map { MatchList($0).items } ?? []
    @State private var error: String?

    var wide: Bool { hsc == .regular }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 12) {
                header
                if let d = data { content(d) }
                else if let error { EmptyState(icon: "wifi.exclamationmark", text: error) { Task { await load() } } }
                else { SkeletonList() }
            }
            .padding(.bottom, 28)
        }
        .background(C.ink)
        .refreshable { haptic(); await load() }
        .task {
            Analytics.screen(2)
            await load()
            while !Task.isCancelled {
                let live = matches.contains { $0.live }
                try? await Task.sleep(nanoseconds: (live ? 15 : 60) * 1_000_000_000)
                await load()
            }
        }
    }

    var header: some View {
        HStack(spacing: 4) {
            LogoTitle(h: 30)
            Spacer()
            HStack(spacing: 0) {
                NavigationLink(value: Route.feed) { icon("clock.arrow.circlepath") }
                NavigationLink(value: Route.search) { icon("magnifyingglass") }
                NavigationLink(value: Route.notifs) { icon("bell") }
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 4)
            .glass(Capsule())
        }
        .padding(.horizontal, screenPad).padding(.top, 6).padding(.bottom, 2)
    }
    func icon(_ n: String) -> some View {
        Image(systemName: n).font(.system(size: 17, weight: .semibold)).foregroundStyle(C.text).frame(width: 42, height: 42)
    }

    func load() async {
        async let h = try? Api.shared.home()
        async let l = try? Api.shared.matches()
        let (hh, ll) = await (h, l)
        if let hh { data = hh; error = nil } else if data == nil { error = "Δεν φόρτωσε. Έλεγξε τη σύνδεση." }
        if let ll { matches = ll.items; Notifier.shared.check(ll.items) }
    }

    @ViewBuilder func content(_ d: HomeData) -> some View {
        let pad = wide ? 24.0 : screenPad
        Group {
            // ⏱ Αντίστροφη μέτρηση (ίδιος αγώνας με την αρχική του site)
            if let n = d.next, !n.live, !n.finished { NextMatchCountdown(m: n).padding(.top, 4) }

            if let b = d.breaking, !b.text.isEmpty {
                Link(destination: URL(string: b.url) ?? URL(string: Api.site)!) {
                    HStack(spacing: 10) {
                        Text("🚨 " + b.label).font(F.body(14, .heavy))
                        Text(b.text).font(F.body(14, .bold)).lineLimit(2)
                        Spacer(minLength: 0)
                    }
                    .foregroundStyle(C.text).padding(.horizontal, 12).padding(.vertical, 10)
                    .background(RoundedRectangle(cornerRadius: 12).fill(C.live))
                }
            }

            if !d.socials.isEmpty { SocialStrip(list: d.socials) }
        }
        .padding(.horizontal, pad)

        if let cats = app.config?.categories, !cats.isEmpty { CategoryMenu(items: cats).padding(.horizontal, wide ? 8 : 0) }

        Group {
            let lh = d.liveHero
            let heroId = lh?.type == "match" ? lh?.id : nil
            // Live αγώνες της ΑΕΚ (εκτός αυτού που είναι ήδη στη θέση του κύριου θέματος)
            ForEach(matches.filter { $0.live && !$0.aek.isEmpty && $0.id != heroId }) { LiveBar(m: $0) }

            if let lh, lh.type == "match", let m = lh.match {
                LiveMatchHero(m: matches.first { $0.id == m.id } ?? m, image: lh.image)
            } else if let lh, lh.type == "event" {
                LiveEventHero(id: lh.id, title: lh.title, image: lh.image)
            } else if wide, let f = d.featured, !d.top.isEmpty {
                // Tablet: κύριο θέμα δίπλα στα «Τελευταία νέα»
                HStack(alignment: .top, spacing: 24) {
                    FeaturedCard(p: f, height: 400).frame(maxWidth: .infinity)
                    VStack(alignment: .leading, spacing: 4) {
                        GoldHeader(title: "Τελευταία νέα", action: "Ροή ειδήσεων", route: .feed).padding(.bottom, 4)
                        ForEach(d.top.prefix(4)) { PostRow(p: $0) }
                    }.frame(maxWidth: .infinity)
                }
            } else if let f = d.featured {
                FeaturedCard(p: f, height: wide ? 380 : 300)
            }

            let topBeside = wide && lh == nil && d.featured != nil
            if !d.top.isEmpty && !topBeside {
                GoldHeader(title: "Τελευταία νέα", action: "Ροή ειδήσεων", route: .feed).padding(.top, 8)
                LazyVGrid(columns: wide ? adaptiveCols : [GridItem(.flexible())], spacing: 0) { ForEach(d.top) { PostRow(p: $0) } }
            }

            // Επόμενοι αγώνες: της αρχικής + το ποδόσφαιρο από τη λίστα αγώνων (όπως στο Android)
            let upcoming = nextMatches(d)
            if !upcoming.isEmpty {
                GoldHeader(title: "Επόμενοι αγώνες", action: "Όλοι", route: nil).padding(.top, 10)
                    .overlay(alignment: .trailing) {
                        Button { app.tab = .matches } label: { Text("Όλοι ›").font(F.body(13, .heavy)).foregroundStyle(C.gold) }.buttonStyle(.plain)
                    }
            }
        }
        .padding(.horizontal, pad)

        let upcoming = nextMatches(d)
        if !upcoming.isEmpty {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) { ForEach(upcoming) { MatchMini(m: $0) } }.padding(.horizontal, pad)
            }
        }

        // Ενότητες: τίτλος + μεσαία κάρτα + 3 γραμμές (iPad: σε στήλες)
        LazyVGrid(columns: wide ? adaptiveCols : [GridItem(.flexible())], alignment: .leading, spacing: 14) {
            ForEach(d.sections) { s in
                if !s.items.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        GoldHeader(title: s.name, action: "Όλα", route: .category(s.slug, s.name))
                        if let first = s.items.first { PostCardMedium(p: first) }
                        ForEach(s.items.dropFirst().prefix(3)) { PostRow(p: $0) }
                    }
                    .padding(.top, 14)
                }
            }
        }
        .padding(.horizontal, pad)

        if !d.socials.isEmpty { SocialSection(list: d.socials).padding(.horizontal, pad).padding(.top, 16).readable() }
    }

    func nextMatches(_ d: HomeData) -> [MatchCard] {
        let lastDay = d.matches.map(\.date).max() ?? ""
        let fb = matches.filter { $0.sport == "football" && $0.upcoming && !$0.aek.isEmpty }.sorted { ($0.date, $0.time) < ($1.date, $1.time) }
        let fbIn = fb.enumerated().filter { $0.offset == 0 || $0.element.date <= lastDay }.map(\.element)
        var seen = Set<Int>()
        return (d.matches + fbIn).filter { !$0.live && seen.insert($0.id).inserted }.sorted { ($0.date, $0.time) < ($1.date, $1.time) }
    }
}
