import SwiftUI

/// Αρχική — όπως το Android HomeScreen: αντίστροφη μέτρηση · έκτακτο · social · κατηγορίες (πλακίδια) · live ·
/// κύριο θέμα · τελευταία νέα · επόμενοι αγώνες · ενότητες κατηγοριών · social.
/// iPad: «περιοδικό» — μεγάλο κύριο θέμα με πλακίδια, ενότητες σε στήλες και δεξιά στήλη «Σήμερα» (αγώνες, βαθμολογία).
struct HomeView: View {
    @ObservedObject var app = AppState.shared
    @Environment(\.horizontalSizeClass) var hsc
    @Environment(\.scenePhase) private var phase
    @State private var data: HomeData? = Api.shared.peek(Api.pHome).map(HomeData.init)
    @State private var matches: [MatchCard] = Api.shared.peek(Api.pMatches()).map { MatchList($0).items } ?? []
    @State private var table: Standing?
    @State private var error: String?
    /// Αλλάζει όταν ήρθαν ΝΕΑ δεδομένα → η αρχική ξαναφτιάχνεται ολόκληρη (αλλιώς κάρτες με δική τους
    /// κατάσταση — αντίστροφη μέτρηση, εικόνες — κρατούσαν τα παλιά μέχρι να βγεις και να ξαναμπείς)
    @State private var gen = 0
    @State private var refreshing = false

    var wide: Bool { hsc == .regular }

    var body: some View {
        GeometryReader { g in
            ScrollViewReader { proxy in
                ScrollView {
                    Color.clear.frame(height: 0).id("top")
                    if wide {
                        padBody(g.size.width)
                    } else {
                        LazyVStack(alignment: .leading, spacing: 12) {
                            header
                            if refreshing { ProgressView().tint(C.gold).frame(maxWidth: .infinity).padding(.vertical, 4) }
                            if let d = data { content(d).id(gen) }
                            else if let error { EmptyState(icon: "wifi.exclamationmark", text: error) { Task { await load() } } }
                            else { SkeletonList() }
                        }
                        .padding(.bottom, 28)
                    }
                }
                // Πάτημα στο «Ειδήσεις» ενώ είσαι ήδη εκεί: πάνω-πάνω + φρέσκα (ζήτησε ο χρήστης)
                .onChange(of: app.reselectN) { _ in
                    guard app.reselectTab == .home else { return }
                    withAnimation(.easeOut(duration: 0.3)) { proxy.scrollTo("top", anchor: .top) }
                    Task { refreshing = true; await load(); gen += 1; refreshing = false; haptic(.soft) }
                }
                .onChange(of: data?.top.count ?? 0) { _ in
                    if UserDefaults.standard.bool(forKey: "scroll") { DispatchQueue.main.asyncAfter(deadline: .now() + 1) { proxy.scrollTo("latest", anchor: .top) } }
                }
            }
        }
        .background(C.ink)
        .refreshable { haptic(); await load(); gen += 1 }
        // Γυρνώντας στην εφαρμογή: φρέσκα αμέσως (αλλιώς το κύριο θέμα/φωτό έμενε παλιό έως 1′)
        .onChange(of: phase) { p in if p == .active { Task { await load() } } }
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
            if !wide { LogoTitle(h: 30) } else {
                VStack(alignment: .leading, spacing: 2) {
                    Text(Fmt.dayHeader(Fmt.ymdString(Date())).upperGr).font(F.body(12, .heavy)).tracking(1).foregroundStyle(C.gold)
                    Text("ΕΙΔΗΣΕΙΣ").font(F.disp(44)).foregroundStyle(C.text)
                }
            }
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
        .padding(.horizontal, wide ? 0 : screenPad).padding(.top, wide ? 18 : 6).padding(.bottom, 2)
    }
    func icon(_ n: String) -> some View {
        Image(systemName: n).font(.system(size: 17, weight: .semibold)).foregroundStyle(C.text).frame(width: 42, height: 42)
    }

    func load() async {
        let before = Api.shared.sig(Api.pHome) &+ Api.shared.sig(Api.pMatches())
        // ανεξάρτητα Task (όχι `async let`: όταν η φόρτωση ακυρωνόταν στη μέση — π.χ. πάτημα «Ειδήσεις»
        // ή επιστροφή στην εφαρμογή — το iOS 26 έκλεινε την εφαρμογή, crash build 76)
        let w = wide
        let th = Task { try? await Api.shared.home() }
        let tl = Task { try? await Api.shared.matches() }
        let ts = Task { await HomeView.tables(w) }
        let hh = await th.value, ll = await tl.value, ss = await ts.value
        if Task.isCancelled { return }
        if Api.shared.sig(Api.pHome) &+ Api.shared.sig(Api.pMatches()) != before { gen += 1 }
        if let hh { data = hh; error = nil } else if data == nil { error = "Δεν φόρτωσε. Έλεγξε τη σύνδεση." }
        if let ll {
            matches = ll.items; Notifier.shared.check(ll.items)
            Ads.shared.aekLive = ll.items.contains { $0.live && !$0.aek.isEmpty }
        }
        if let ss {
            table = ss.first { $0.rows.contains { $0.aek } && ($0.sport.lowercased().contains("ποδ") || $0.sport.lowercased().contains("foot")) }
                ?? ss.first { $0.rows.contains { $0.aek } }
        }
    }

    static func tables(_ w: Bool) async -> [Standing]? { w ? (try? await Api.shared.standings()) : nil }

    // MARK: - iPhone (όπως Android)

    @ViewBuilder func content(_ d: HomeData) -> some View {
        let pad = screenPad
        Group {
            // ⏱ Αντίστροφη μέτρηση (ίδιος αγώνας με την αρχική του site)
            if let n = d.next, !n.live, !n.finished { NextMatchCountdown(m: n).padding(.top, 4) }
            breaking(d)
            if !d.socials.isEmpty { SocialStrip(list: d.socials) }
        }
        .padding(.horizontal, pad)

        if let cats = app.config?.categories, !cats.isEmpty { CategoryMenu(items: cats) }

        Group {
            liveAndFeatured(d, height: 300)

            if !d.top.isEmpty {
                GoldHeader(title: "Τελευταία νέα", action: "Ροή ειδήσεων", route: .feed).padding(.top, 8).id("latest")
                VStack(spacing: 0) { ForEach(d.top) { PostRow(p: $0) } }
                if d.top.count > 3 { BannerAd(place: "home") }
            }

            // Επόμενοι αγώνες: της αρχικής + το ποδόσφαιρο από τη λίστα αγώνων (όπως στο Android)
            if !nextMatches(d).isEmpty {
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

        // Ενότητες: τίτλος + μεσαία κάρτα + 3 γραμμές · διαφήμιση μετά από κάθε ενότητα (κάρτα χορηγού/native ↔ banner)
        let secs = d.sections.filter { !$0.items.isEmpty }
        ForEach(Array(secs.enumerated()), id: \.element.id) { i, s in
            VStack(alignment: .leading, spacing: 12) {
                GoldHeader(title: s.name, action: "Όλα", route: .category(s.slug, s.name))
                if let first = s.items.first { PostCardMedium(p: first) }
                ForEach(s.items.dropFirst().prefix(3)) { PostRow(p: $0) }
                if i % 2 == 0 { FeedAd() } else { BannerAd(place: "home") }
            }
            .padding(.top, 14)
            .padding(.horizontal, pad)
        }

        if !d.socials.isEmpty { SocialSection(list: d.socials).padding(.horizontal, pad).padding(.top, 16) }
    }

    @ViewBuilder func breaking(_ d: HomeData) -> some View {
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
    }

    /// Live αγώνες ΑΕΚ + κύριο θέμα (ή live hero αγώνα/γεγονότος)
    @ViewBuilder func liveAndFeatured(_ d: HomeData, height: CGFloat, featured: Bool = true) -> some View {
        let lh = d.liveHero
        let heroId = lh?.type == "match" ? lh?.id : nil
        ForEach(matches.filter { $0.live && !$0.aek.isEmpty && $0.id != heroId }) { LiveBar(m: $0) }
        if let lh, lh.type == "match", let m = lh.match {
            LiveMatchHero(m: matches.first { $0.id == m.id } ?? m, image: lh.image)
            PresentedBy(place: "live")
        } else if let lh, lh.type == "event" {
            LiveEventHero(id: lh.id, title: lh.title, image: lh.image)
        } else if featured, let f = d.featured {
            FeaturedCard(p: f, height: height)
        }
    }

    func nextMatches(_ d: HomeData) -> [MatchCard] {
        let lastDay = d.matches.map(\.date).max() ?? ""
        let fb = matches.filter { $0.sport == "football" && $0.upcoming && !$0.aek.isEmpty }.sorted { ($0.date, $0.time) < ($1.date, $1.time) }
        let fbIn = fb.enumerated().filter { $0.offset == 0 || $0.element.date <= lastDay }.map(\.element)
        var seen = Set<Int>()
        return (d.matches + fbIn).filter { !$0.live && seen.insert($0.id).inserted }.sorted { ($0.date, $0.time) < ($1.date, $1.time) }
    }

    // MARK: - iPad / tablet (νέο σχέδιο 12/11/2026, εγκρίθηκε από τον χρήστη)
    // Πάνω: μπάρα αγώνων ΑΕΚ σε όλο το πλάτος · αριστερά: κύριο θέμα + 2 μεσαία, μετά ενότητες ανά κατηγορία
    // δεξιά: «Ροή ειδήσεων» με ώρα + μικρή βαθμολογία (η ΑΕΚ με τον από πάνω και τον από κάτω).

    @ViewBuilder func padBody(_ w: CGFloat) -> some View {
        let rail = w > 980
        VStack(alignment: .leading, spacing: 20) {
            header
            if let d = data {
                Group {
                    PadMatchStrip(items: stripMatches(d)) { app.tab = .matches }
                        .padding(.horizontal, -28)
                    breaking(d)
                    HStack(alignment: .top, spacing: 28) {
                        padMain(d, cols: rail ? 4 : 3).frame(maxWidth: .infinity, alignment: .leading)
                        if rail { padRail(d).frame(width: 320) }
                    }
                    if !rail { padRail(d) }
                    if !d.socials.isEmpty { SocialSection(list: d.socials).padding(.top, 10).readable(760) }
                }.id(gen)
            } else if let error {
                EmptyState(icon: "wifi.exclamationmark", text: error) { Task { await load() } }
            } else { SkeletonList() }
        }
        .padding(.horizontal, 28).padding(.bottom, 36)
    }

    /// Μπάρα αγώνων: live πρώτα, μετά οι επόμενοι, μετά τα 3 τελευταία αποτελέσματα
    func stripMatches(_ d: HomeData) -> [MatchCard] {
        let mine = matches.filter { !$0.aek.isEmpty }
        let live = mine.filter(\.live)
        var seen = Set(live.map(\.id))
        let next = (nextMatches(d)).filter { seen.insert($0.id).inserted }.prefix(8)
        let done = mine.filter { $0.finished && seen.insert($0.id).inserted }.sorted { ($0.date, $0.time) > ($1.date, $1.time) }.prefix(3)
        return live + Array(next) + Array(done)
    }

    @ViewBuilder func padMain(_ d: HomeData, cols: Int) -> some View {
        let grid = Array(repeating: GridItem(.flexible(), spacing: 18, alignment: .top), count: cols)
        VStack(alignment: .leading, spacing: 22) {
            // live γεγονός/αγώνας-hero (αν υπάρχει) αντί για κύριο θέμα
            if let lh = d.liveHero, lh.type == "match" || lh.type == "event" {
                liveAndFeatured(d, height: 420, featured: false)
            }
            if let f = d.featured {
                ViewThatFits(in: .horizontal) {
                    HStack(alignment: .top, spacing: 20) {
                        PadHero(p: f, height: 440).frame(minWidth: 520)
                        VStack(spacing: 20) { ForEach(d.top.prefix(2)) { PadSideCard(p: $0) } }.frame(width: 300)
                    }
                    VStack(spacing: 18) {
                        PadHero(p: f, height: 400)
                        HStack(alignment: .top, spacing: 18) { ForEach(d.top.prefix(2)) { PadSideCard(p: $0) } }
                    }
                }
            }
            let secs = d.sections.filter { !$0.items.isEmpty }
            ForEach(Array(secs.enumerated()), id: \.element.id) { i, s in
                VStack(alignment: .leading, spacing: 14) {
                    GoldHeader(title: s.name, action: "Όλα", route: .category(s.slug, s.name))
                    LazyVGrid(columns: grid, spacing: 20) { ForEach(s.items.prefix(cols)) { PostTile(p: $0, titleSize: 16) } }
                    if i % 2 == 1 { BannerAd(place: "home") }
                }
            }
        }
    }

    /// Δεξιά: ροή ειδήσεων (ώρα · κατηγορία · τίτλος) + μικρή βαθμολογία
    @ViewBuilder func padRail(_ d: HomeData) -> some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 8) {
                    LiveDot(size: 8, color: C.live)
                    Text("ΡΟΗ ΕΙΔΗΣΕΩΝ").font(F.disp(24)).foregroundStyle(C.text)
                }
                .padding(.bottom, 6)
                ForEach(Array(d.top.dropFirst(2).prefix(9))) { p in
                    NavigationLink(value: Route.post(p.id, p)) {
                        HStack(alignment: .top, spacing: 12) {
                            Text(Fmt.clockOrDay(p.date)).font(F.disp(18)).foregroundStyle(C.gold).frame(width: 46, alignment: .leading)
                            VStack(alignment: .leading, spacing: 3) {
                                if !p.category.isEmpty { Text(p.category.upperGr).font(F.body(10, .heavy)).foregroundStyle(C.muted).lineLimit(1) }
                                Text(p.title).font(F.body(14, .bold)).foregroundStyle(C.text).lineLimit(3).multilineTextAlignment(.leading)
                            }
                            Spacer(minLength: 0)
                        }
                        .padding(.vertical, 10)
                        .overlay(alignment: .bottom) { Rectangle().fill(C.line).frame(height: 1) }
                        .contentShape(Rectangle())
                    }.buttonStyle(.plain)
                }
                NavigationLink(value: Route.feed) {
                    Text("Όλη η ροή →").font(F.body(13, .heavy)).foregroundStyle(C.gold).padding(.top, 12)
                }.buttonStyle(.plain)
            }
            .padding(18).card(20)
            if let t = table { AekTable(s: t) { app.tab = .standings } }
            BannerAd(place: "home", medium: true)
        }
    }
}

/// iPad: κύριο θέμα — φωτογραφία σε όλο το κουτί, ο τίτλος πάνω της (κεφαλαία, Sofia)
struct PadHero: View {
    let p: PostCard
    var height: CGFloat = 440
    var body: some View {
        NavigationLink(value: Route.post(p.id, p)) {
            Color.clear.frame(height: height)
                .overlay(FillImage(url: p.image, w: 1600))
                .overlay(LinearGradient(colors: [.clear, .black.opacity(0.35), .black.opacity(0.92)], startPoint: .center, endPoint: .bottom))
                .overlay { if p.video { PlayBadge(size: 64) } }
                .overlay(alignment: .bottomLeading) {
                    VStack(alignment: .leading, spacing: 10) {
                        if !p.category.isEmpty {
                            Text(p.category.upperGr).font(F.body(12, .heavy)).foregroundStyle(C.ink)
                                .padding(.horizontal, 10).padding(.vertical, 4).background(RoundedRectangle(cornerRadius: 8).fill(C.gold))
                        }
                        Text(p.title.upperGr).font(F.disp(44)).foregroundStyle(.white).lineLimit(3).minimumScaleFactor(0.7)
                            .multilineTextAlignment(.leading).shadow(color: .black.opacity(0.5), radius: 6)
                        Text(Fmt.ago(p.date)).font(F.body(13, .semibold)).foregroundStyle(C.text2)
                    }
                    .padding(28)
                }
                .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .postMenu(p)
    }
}

/// iPad: μεσαίο θέμα δίπλα στο κύριο (φωτό πάνω, κατηγορία, τίτλος)
struct PadSideCard: View {
    let p: PostCard
    var body: some View {
        NavigationLink(value: Route.post(p.id, p)) {
            VStack(alignment: .leading, spacing: 0) {
                Color.clear.frame(height: 130).overlay(FillImage(url: p.image, w: 700)).clipped()
                    .overlay { if p.video { PlayBadge(size: 40) } }
                VStack(alignment: .leading, spacing: 6) {
                    if !p.category.isEmpty { Text(p.category.upperGr).font(F.body(11, .heavy)).foregroundStyle(C.gold).lineLimit(1) }
                    Text(p.title).font(F.body(16, .heavy)).foregroundStyle(C.text).lineLimit(3).multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(Fmt.ago(p.date)).font(F.body(12)).foregroundStyle(C.muted)
                }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .card(18)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .postMenu(p)
    }
}

/// iPad: μπάρα αγώνων ΑΕΚ (live · επόμενοι · αποτελέσματα με Ν/Ι/Η)
struct PadMatchStrip: View {
    let items: [MatchCard]
    var all: () -> Void
    var body: some View {
        if !items.isEmpty {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    Text("ΑΓΩΝΕΣ\nΑΕΚ").font(F.disp(20)).foregroundStyle(C.gold).lineSpacing(-4).frame(width: 66, alignment: .leading)
                    ForEach(items) { m in
                        NavigationLink(value: Route.match(m.id)) { PadStripCard(m: m) }.buttonStyle(.plain)
                    }
                    Button(action: all) {
                        Text("Όλοι οι αγώνες →").font(F.body(13, .heavy)).foregroundStyle(C.gold).padding(.horizontal, 10)
                    }.buttonStyle(.plain)
                }
                .padding(.horizontal, 28).padding(.vertical, 14)
            }
            .background(C.ink2)
            .overlay(alignment: .bottom) { Rectangle().fill(C.line).frame(height: 1) }
            .overlay(alignment: .top) { Rectangle().fill(C.line).frame(height: 1) }
        }
    }
}

struct PadStripCard: View {
    let m: MatchCard
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                if m.live {
                    LiveDot(size: 6, color: C.live)
                    Text(("LIVE " + (m.minute.isEmpty ? "" : m.minute)).upperGr).font(F.body(11, .heavy)).foregroundStyle(C.live).lineLimit(1)
                } else if m.finished {
                    Text("ΤΕΛΙΚΟ").font(F.body(11, .heavy)).foregroundStyle(C.muted)
                } else {
                    Text(m.shortDay + " · " + m.time).font(F.body(11, .heavy)).foregroundStyle(C.gold).lineLimit(1)
                }
                Spacer(minLength: 4)
                if m.finished, let w = m.aekWon.map({ $0 ? "Ν" : "Η" }) ?? (m.hasScore ? "Ι" : nil) {
                    Text(w).font(F.body(11, .heavy)).foregroundStyle(w == "Ν" ? C.win : w == "Η" ? C.loss : C.text2)
                        .padding(.horizontal, 6).background(RoundedRectangle(cornerRadius: 5).fill((w == "Ν" ? C.win : w == "Η" ? C.loss : C.muted).opacity(0.18)))
                } else {
                    Text(m.sportLabel).font(F.body(10, .bold)).foregroundStyle(C.muted).lineLimit(1)
                }
            }
            row(m.homeLogo, m.home, m.scoreHome, m.aek == "home")
            row(m.awayLogo, m.away, m.scoreAway, m.aek == "away")
        }
        .padding(.horizontal, 14).padding(.vertical, 10)
        .frame(width: 210)
        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(m.live ? C.live.opacity(0.14) : C.panel))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(m.live ? C.live.opacity(0.5) : C.line, lineWidth: 1))
    }
    func row(_ logo: String, _ name: String, _ score: String, _ aek: Bool) -> some View {
        HStack(spacing: 8) {
            TeamLogo(url: logo, size: 20, name: name)
            Text(name.upperGr).font(F.disp(18)).foregroundStyle(aek ? C.gold : C.text).lineLimit(1).minimumScaleFactor(0.7)
            Spacer(minLength: 4)
            if m.live || m.hasScore { Text(score).font(F.disp(20)).foregroundStyle(aek ? C.gold : C.text).monospacedDigit() }
        }
    }
}

/// Μικρή βαθμολογία: η ΑΕΚ με την ομάδα από πάνω και από κάτω
struct AekTable: View {
    let s: Standing
    var open: () -> Void
    var body: some View {
        let i = s.rows.firstIndex { $0.aek } ?? 0
        let lo = max(0, min(i - 1, s.rows.count - 3)), hi = min(s.rows.count, lo + 3)
        VStack(alignment: .leading, spacing: 4) {
            Text((s.league.isEmpty ? s.title : s.league).upperGr).font(F.body(12, .heavy)).foregroundStyle(C.gold).lineLimit(1).padding(.bottom, 6)
            ForEach(Array(s.rows[lo..<hi]), id: \.self) { r in
                HStack(spacing: 10) {
                    Text("\(r.pos)").font(F.body(13, .heavy)).foregroundStyle(r.aek ? C.ink : C.muted).frame(width: 20)
                    TeamLogo(url: r.logo, size: 20, name: r.name)
                    Text(r.name.upperGr).font(F.disp(17)).foregroundStyle(r.aek ? C.ink : C.text).lineLimit(1)
                    Spacer(minLength: 4)
                    Text(r.points).font(F.disp(19)).foregroundStyle(r.aek ? C.ink : C.text)
                }
                .padding(.horizontal, 10).frame(height: 36)
                .background(RoundedRectangle(cornerRadius: 9).fill(r.aek ? C.gold : .clear))
            }
            Button(action: open) {
                Text("Όλη η βαθμολογία →").font(F.body(13, .heavy)).foregroundStyle(C.gold).padding(.top, 8)
            }.buttonStyle(.plain)
        }
        .padding(16).card(20)
    }
}

/// iPad: κύριο θέμα — μεγάλη φωτογραφία ολόκληρη, τίτλος από κάτω
struct PadLead: View {
    let p: PostCard
    var body: some View { FeaturedCard(p: p, titleSize: 40) }
}

/// Πλακίδιο άρθρου (iPad): φωτογραφία 16:9 ολόκληρη · κατηγορία · τίτλος · ώρα
struct PostTile: View {
    let p: PostCard
    var titleSize: CGFloat = 18
    var body: some View {
        NavigationLink(value: Route.post(p.id, p)) {
            VStack(alignment: .leading, spacing: 8) {
                FillImage(url: p.image, w: 900).aspectRatio(16 / 9, contentMode: .fit)
                    .overlay { if p.video { PlayBadge(size: 44) } }
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                if !p.category.isEmpty { Text(p.category.upperGr).font(F.body(11, .heavy)).tracking(0.5).foregroundStyle(C.gold).lineLimit(1) }
                Text(p.title).font(F.body(titleSize, .heavy)).foregroundStyle(C.text).lineLimit(3).multilineTextAlignment(.leading).fixedSize(horizontal: false, vertical: true)
                Text(Fmt.ago(p.date)).font(F.body(12)).foregroundStyle(C.muted)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .postMenu(p)
    }
}

/// Γραμμή αγώνα στη στήλη «Σήμερα»
struct RailMatch: View {
    let m: MatchCard
    var body: some View {
        NavigationLink(value: Route.match(m.id)) {
            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(matchMeta(m)).font(F.body(10, .heavy)).foregroundStyle(C.gold).lineLimit(1)
                    HStack(spacing: 6) { TeamLogo(url: m.homeLogo, size: 20, name: m.home); Text(m.home).font(F.body(14, .bold)).foregroundStyle(C.text).lineLimit(1) }
                    HStack(spacing: 6) { TeamLogo(url: m.awayLogo, size: 20, name: m.away); Text(m.away).font(F.body(14, .bold)).foregroundStyle(C.text).lineLimit(1) }
                }
                Spacer(minLength: 4)
                VStack(alignment: .trailing, spacing: 2) {
                    Text(m.shortDay).font(F.body(11, .heavy)).foregroundStyle(C.muted)
                    Text(m.time.isEmpty ? "—" : m.time).font(F.disp(24)).foregroundStyle(C.gold)
                }
            }
            .padding(.horizontal, 14).padding(.vertical, 12)
            .contentShape(Rectangle())
        }.buttonStyle(.plain)
    }
}

extension MatchCard {
    var shortDay: String {
        guard let d = Fmt.day(date) else { return date }
        let c = Fmt.cal.dateComponents([.day, .month, .weekday], from: d)
        return Fmt.daysShort[c.weekday! - 1].upperGr + " \(c.day!)/\(c.month!)"
    }
}

/// Μικρή βαθμολογία (στήλη «Σήμερα»): οι 6 πρώτοι + η ΑΕΚ
struct MiniTable: View {
    let s: Standing
    var open: () -> Void
    var body: some View {
        let top = Array(s.rows.prefix(6))
        let rows = top.contains { $0.aek } ? top : top + s.rows.filter(\.aek)
        VStack(alignment: .leading, spacing: 0) {
            Text((s.league.isEmpty ? s.title : s.league).upperGr).font(F.disp(18)).foregroundStyle(C.text).lineLimit(1)
                .padding(.horizontal, 14).padding(.top, 14).padding(.bottom, 8)
            ForEach(rows, id: \.self) { r in
                HStack(spacing: 8) {
                    Text("\(r.pos)").font(F.body(12, .heavy)).foregroundStyle(r.aek ? C.ink : C.text2)
                        .frame(width: 22, height: 22).background(RoundedRectangle(cornerRadius: 6).fill(r.aek ? C.gold : C.panel3))
                    TeamLogo(url: r.logo, size: 20, name: r.name)
                    Text(r.name.upperGr).font(F.disp(15)).foregroundStyle(r.aek ? C.gold : C.text).lineLimit(1)
                    Spacer(minLength: 4)
                    Text(r.played).font(F.body(12, .bold)).foregroundStyle(C.muted).frame(width: 22, alignment: .trailing)
                    Text(r.points).font(F.disp(18)).foregroundStyle(r.aek ? C.gold : C.text).frame(width: 30, alignment: .trailing)
                }
                .padding(.horizontal, 14).frame(height: 36)
                .background(r.aek ? C.gold.opacity(0.12) : .clear)
            }
            Button(action: open) {
                Text("Όλη η βαθμολογία ›").font(F.body(13, .heavy)).foregroundStyle(C.gold).frame(maxWidth: .infinity).padding(.vertical, 12)
            }.buttonStyle(.plain)
        }
        .card(18)
    }
}
