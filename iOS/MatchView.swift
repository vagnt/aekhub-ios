import SwiftUI

/// Σελίδα αγώνα: πίνακας σκορ + Πορεία / Στατιστικά / Συνθέσεις / Παίκτες. Live: ανανέωση κάθε 10″.
struct MatchView: View {
    let id: Int
    @State private var d: MatchDetail?
    @State private var error: String?
    @State private var tab = ""
    @State private var openURL: URL?
    @EnvironmentObject var prefs: Prefs

    init(id: Int) {
        self.id = id
        _d = State(initialValue: Api.shared.peek(Api.pMatch(id)).map(MatchDetail.init))
    }

    var body: some View {
        ScrollView {
            if let d {
                VStack(spacing: 0) {
                    MatchHeader(d: d)
                    if let s = d.sponsor, !s.logo.isEmpty { SponsorView(s: s) }
                    if !d.highlights.isEmpty { highlights(d) }
                    let tabs = tabsFor(d)
                    if d.resultOnly {
                        EmptyState(icon: "list.bullet.rectangle", text: d.card.finished ? "Ο αγώνας δεν καλύφθηκε live. Υπάρχει μόνο το τελικό αποτέλεσμα." : "Ο αγώνας δεν καλύπτεται live· ενημερώνεται το σκορ στο ημίχρονο και στο τέλος.")
                    } else if !tabs.isEmpty {
                        let cur = tabs.contains(tab) ? tab : tabs[0]
                        Picker("", selection: Binding(get: { cur }, set: { tab = $0 })) {
                            ForEach(tabs, id: \.self) { Text($0).tag($0) }
                        }
                        .pickerStyle(.segmented)
                        .padding(.horizontal, 16).padding(.vertical, 14)
                        Group {
                            switch cur {
                            case "Πορεία": TimelineSection(d: d)
                            case "Στατιστικά": StatsSection(d: d)
                            case "Συνθέσεις": LineupsSection(d: d)
                            default: PlayersSection(d: d)
                            }
                        }
                        .frame(maxWidth: 820)
                        .padding(.horizontal, 16)
                    }
                    info(d).frame(maxWidth: 820).padding(16)
                }
            } else if let error {
                EmptyState(icon: "wifi.exclamationmark", text: error) { Task { await load() } }
            } else {
                ProgressView().tint(C.gold).padding(80)
            }
        }
        .background(C.ink)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                if let c = d?.card { Text("\(c.home) – \(c.away)").font(F.body(14, .extra)).lineLimit(1) }
            }
            ToolbarItemGroup(placement: .navigationBarTrailing) {
                if let c = d?.card, !c.finished {
                    // 🔔 Ειδοποιήσεις για ΑΥΤΟΝ τον αγώνα (υπενθύμιση, σέντρα, γκολ, τελικό), ό,τι κι αν έχεις στις ρυθμίσεις
                    Button {
                        if prefs.matchAlerts.contains(id) { prefs.matchAlerts.remove(id) } else {
                            prefs.matchAlerts.insert(id)
                            Task { _ = await Notifier.shared.requestPermission(); await Notifier.shared.refresh(force: true) }
                        }
                    } label: { Image(systemName: prefs.matchAlerts.contains(id) ? "bell.fill" : "bell") }
                }
                if let l = d?.card.link, let u = URL(string: l) { ShareLink(item: u) { Image(systemName: "square.and.arrow.up") } }
            }
        }
        .refreshable { await load() }
        .sheet(item: $openURL) { SafariView(url: $0).ignoresSafeArea() }
        .task {
            Analytics.screen(4, id)
            await load()
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: (d?.card.live == true ? 10 : 120) * 1_000_000_000)
                await load()
                if d?.card.live == true { await Notifier.shared.refresh() }
            }
        }
    }

    func load() async {
        do { d = try await Api.shared.match(id); error = nil }
        catch { if d == nil { self.error = "Δεν φόρτωσε ο αγώνας.\n" + error.localizedDescription } }
    }

    func tabsFor(_ d: MatchDetail) -> [String] {
        var t: [String] = []
        if !d.events.isEmpty || !d.groups.isEmpty || (d.card.live && d.timeline) { t.append("Πορεία") }
        if !d.stats.isEmpty { t.append("Στατιστικά") }
        if d.hasLineups || d.pitch != nil { t.append("Συνθέσεις") }
        if let x = d.extra, x.hasRatings || x.hasBox { t.append("Παίκτες") }
        return t
    }

    func highlights(_ d: MatchDetail) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            GoldHeader(title: "Στιγμιότυπα")
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(d.highlights, id: \.self) { h in
                        Button { openURL = URL(string: h.url) } label: {
                            VStack(alignment: .leading, spacing: 6) {
                                ZStack {
                                    NetImage(url: h.thumb, w: 500).frame(width: 220, height: 124).clipped()
                                    VideoBadge()
                                }.clipShape(RoundedRectangle(cornerRadius: 10))
                                Text(h.title).font(F.body(12, .bold)).foregroundStyle(C.text).lineLimit(2).frame(width: 220, alignment: .leading)
                            }
                        }.buttonStyle(.plain)
                    }
                }.padding(.horizontal, 16)
            }
        }
    }

    func info(_ d: MatchDetail) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            let c = d.card
            row("trophy", [c.competition, c.matchday].filter { !$0.isEmpty }.joined(separator: " · "))
            row("calendar", Fmt.dayHeader(c.date).capitalized(with: Fmt.gr) + (c.time.isEmpty ? "" : " · " + c.time))
            row("mappin.and.ellipse", c.venue)
            row("tv", c.broadcast)
            row("person.badge.shield.checkmark", d.referee.isEmpty ? "" : "Διαιτητής: " + d.referee)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14).background(RoundedRectangle(cornerRadius: 12).fill(C.panel))
    }
    @ViewBuilder func row(_ icon: String, _ t: String) -> some View {
        if !t.isEmpty {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: icon).foregroundStyle(C.gold).frame(width: 20)
                Text(t).font(F.body(13, .bold)).foregroundStyle(C.text2)
            }
        }
    }
}

// MARK: - Πίνακας σκορ

struct MatchHeader: View {
    let d: MatchDetail
    var c: MatchCard { d.card }
    var body: some View {
        VStack(spacing: 14) {
            Text([c.sportLabel, c.competition].filter { !$0.isEmpty }.joined(separator: " · ").upperGr)
                .font(F.body(11, .extra)).foregroundStyle(C.text2).lineLimit(1).padding(.top, 14)
            HStack(alignment: .top) {
                team(c.home, c.homeLogo, d.scorersHome)
                VStack(spacing: 6) {
                    if c.upcoming && !c.hasScore {
                        Text(c.time.isEmpty ? "–" : c.time).font(F.disp(46, black: true)).foregroundStyle(C.text)
                        Text(Fmt.shortDay(c.date)).font(F.body(13, .bold)).foregroundStyle(C.text2)
                    } else {
                        HStack(spacing: 6) {
                            Text(c.scoreHome).foregroundStyle(lead(c.scoreHome, c.scoreAway))
                            Text("–").foregroundStyle(C.muted)
                            Text(c.scoreAway).foregroundStyle(lead(c.scoreAway, c.scoreHome))
                        }.font(F.disp(60, black: true)).monospacedDigit().minimumScaleFactor(0.6).lineLimit(1)
                        if !c.penHome.isEmpty { Text("Πέναλτι \(c.penHome)–\(c.penAway)").font(F.body(12, .extra)).foregroundStyle(C.text2) }
                        if let ht = d.extra?.htScore, !ht.isEmpty, c.sport.contains("football") || c.sport == "futsal" {
                            Text("Ημίχρονο \(ht)").font(F.body(11, .bold)).foregroundStyle(C.muted)
                        }
                    }
                    MatchStatus(m: c, big: true)
                }.frame(minWidth: 130)
                team(c.away, c.awayLogo, d.scorersAway)
            }
            .padding(.horizontal, 10)
            if !d.periods.isEmpty { periods }
        }
        .padding(.bottom, 16)
        .frame(maxWidth: .infinity)
        .background(
            ZStack {
                Image("HeroBg").resizable().scaledToFill().opacity(0.45)
                LinearGradient(colors: [C.ink.opacity(0.35), C.ink], startPoint: .top, endPoint: .bottom)
            }.clipped()
        )
    }

    func lead(_ a: String, _ b: String) -> Color {
        guard let x = Int(a), let y = Int(b), c.finished else { return c.live ? C.gold : C.text }
        return x >= y ? C.text : C.text2.opacity(0.7)
    }

    func team(_ name: String, _ logo: String, _ scorers: [String]) -> some View {
        VStack(spacing: 8) {
            TeamLogo(url: logo, size: 64)
            Text(name.upperGr).font(F.disp(19, black: true)).foregroundStyle(C.text).multilineTextAlignment(.center).lineLimit(2).minimumScaleFactor(0.7)
            ForEach(scorers, id: \.self) { s in
                Text(s).font(F.body(11, .bold)).foregroundStyle(C.text2).multilineTextAlignment(.center).lineLimit(2)
            }
        }.frame(maxWidth: .infinity)
    }

    var periods: some View {
        VStack(spacing: 6) {
            SectionLabel(text: "Σκορ ανά περίοδο").frame(maxWidth: .infinity)
            Grid(horizontalSpacing: 0, verticalSpacing: 6) {
                GridRow {
                    Text("").frame(width: 80)
                    ForEach(d.periods, id: \.self) { Text($0.label).font(F.body(11, .extra)).foregroundStyle(C.muted).frame(maxWidth: .infinity) }
                }
                GridRow {
                    Text(c.home).font(F.body(12, .extra)).lineLimit(1).frame(width: 80, alignment: .leading)
                    ForEach(d.periods, id: \.self) { Text($0.home).font(F.body(13, .extra)).monospacedDigit().frame(maxWidth: .infinity) }
                }
                GridRow {
                    Text(c.away).font(F.body(12, .extra)).lineLimit(1).frame(width: 80, alignment: .leading)
                    ForEach(d.periods, id: \.self) { Text($0.away).font(F.body(13, .extra)).monospacedDigit().frame(maxWidth: .infinity) }
                }
            }
            .foregroundStyle(C.text)
            .padding(12).background(RoundedRectangle(cornerRadius: 12).fill(C.panel.opacity(0.9)))
        }
        .frame(maxWidth: 560)
        .padding(.horizontal, 16)
    }
}

struct SponsorView: View {
    let s: Sponsor
    @Environment(\.openURL) var open
    var body: some View {
        VStack(spacing: 4) {
            Text(s.label).font(F.body(10, .bold)).foregroundStyle(C.muted)
            Button { if let u = URL(string: s.click) { open(u) } } label: {
                NetImage(url: s.logo, w: 600, mode: .fit)
                    .frame(width: s.w > 0 ? CGFloat(s.w) : nil, height: CGFloat(max(24, s.h)))
            }.buttonStyle(.plain)
            if !s.note.isEmpty { Text(s.note).font(F.body(9, .bold)).foregroundStyle(C.muted) }
        }
        .padding(.vertical, 10)
        .onAppear { Api.shared.ping(s.view) }
    }
}

// MARK: - Πορεία

func eventIcon(_ t: String) -> String {
    switch t {
    case "goal", "penalty_goal", "pen_goal": return "⚽"
    case "own_goal", "og": return "⚽"
    case "missed_penalty", "pen_miss", "penalty_miss": return "❌"
    case "yellow": return "🟨"
    case "red": return "🟥"
    case "second_yellow", "yellow_red": return "🟨🟥"
    case "sub", "substitution": return "🔄"
    case "var": return "📺"
    case "ht", "halftime": return "⏸"
    case "ft", "end": return "🏁"
    case "start", "kickoff", "ko": return "▶️"
    case "point": return "•"
    case "info", "note": return "ℹ️"
    default:
        if t.hasSuffix("_start") { return "▶️" }
        if t.hasSuffix("_end") || t.hasPrefix("set") { return "⏸" }
        if t.contains("goal") { return "⚽" }
        if t.contains("time") || t.contains("timeout") { return "⏱" }
        return "•"
    }
}

struct EventRow: View {
    let e: MatchEvent
    var body: some View {
        let big = e.type.contains("goal") || e.type == "red"
        HStack(alignment: .top, spacing: 10) {
            Text(e.minute).font(F.body(12, .extra)).foregroundStyle(C.gold).frame(width: 42, alignment: .trailing).monospacedDigit()
            Text(eventIcon(e.type)).font(.system(size: 15)).frame(width: 26)
            VStack(alignment: .leading, spacing: 2) {
                Text(e.label + (e.score.isEmpty ? "" : " · " + e.score)).font(F.body(big ? 14 : 13, .extra)).foregroundStyle(big ? C.text : C.text2)
                if !e.text.isEmpty { Text(e.text).font(F.body(13, .bold)).foregroundStyle(C.text) }
            }
            Spacer(minLength: 0)
            if !e.team.isEmpty { RoundedRectangle(cornerRadius: 2).fill(e.team == "home" ? C.gold : C.text2.opacity(0.6)).frame(width: 4, height: 28) }
        }
        .padding(.vertical, 9).padding(.horizontal, 10)
        .background(RoundedRectangle(cornerRadius: 10).fill(big ? C.panel2 : C.panel))
    }
}

struct TimelineSection: View {
    let d: MatchDetail
    var body: some View {
        VStack(spacing: 6) {
            if d.groups.isEmpty {
                if d.events.isEmpty { EmptyState(icon: "clock", text: "Η πορεία του αγώνα θα εμφανιστεί εδώ.") }
                ForEach(Array(d.events.enumerated()), id: \.offset) { EventRow(e: $0.element) }
            } else {
                ForEach(Array(d.groups.enumerated()), id: \.offset) { _, g in GroupBlock(g: g) }
            }
        }
    }
}

private struct GroupBlock: View {
    let g: EventGroup
    @State private var open: Bool
    init(g: EventGroup) { self.g = g; _open = State(initialValue: g.open) }
    var body: some View {
        VStack(spacing: 6) {
            Button { withAnimation { open.toggle() } } label: {
                HStack {
                    Text(g.label.upperGr).font(F.disp(20, black: true)).foregroundStyle(C.gold)
                    Text(g.score).font(F.body(14, .extra)).foregroundStyle(C.text)
                    Spacer()
                    Image(systemName: open ? "chevron.up" : "chevron.down").foregroundStyle(C.text2)
                }.padding(12).background(RoundedRectangle(cornerRadius: 10).fill(C.panel3))
            }.buttonStyle(.plain)
            if open { ForEach(Array(g.events.enumerated()), id: \.offset) { EventRow(e: $0.element) } }
        }
    }
}

// MARK: - Στατιστικά

struct StatsSection: View {
    let d: MatchDetail
    var body: some View {
        VStack(spacing: 14) {
            HStack {
                TeamLogo(url: d.card.homeLogo, size: 26); Spacer(); TeamLogo(url: d.card.awayLogo, size: 26)
            }
            ForEach(d.stats, id: \.self) { s in
                let h = num(s.home)
                let a = num(s.away)
                let tot = max(h + a, 0.0001)
                VStack(spacing: 6) {
                    HStack {
                        Text(s.home + (s.type == "pct" ? "%" : "")).font(F.body(14, .extra)).foregroundStyle(h >= a ? C.text : C.text2)
                        Spacer()
                        Text(s.label).font(F.body(12, .bold)).foregroundStyle(C.text2).multilineTextAlignment(.center)
                        Spacer()
                        Text(s.away + (s.type == "pct" ? "%" : "")).font(F.body(14, .extra)).foregroundStyle(a >= h ? C.text : C.text2)
                    }
                    GeometryReader { g in
                        HStack(spacing: 4) {
                            HStack { Spacer(minLength: 0); Capsule().fill(h >= a ? C.gold : C.line2).frame(width: (g.size.width / 2 - 2) * CGFloat(h / tot)) }
                            HStack { Capsule().fill(a > h ? C.text2 : C.line2).frame(width: (g.size.width / 2 - 2) * CGFloat(a / tot)); Spacer(minLength: 0) }
                        }
                    }.frame(height: 6)
                }
            }
        }
        .padding(14).background(RoundedRectangle(cornerRadius: 12).fill(C.panel))
    }
    /// «35/66» → 35/66 (%) · «0.87» → 0.87 · «12» → 12
    func num(_ s: String) -> Double {
        let p = s.split(separator: "/")
        if p.count == 2, let x = Double(p[0].trimmingCharacters(in: .whitespaces)), let y = Double(p[1].trimmingCharacters(in: .whitespaces)), y > 0 { return x / y }
        return Double(s.replacingOccurrences(of: "%", with: "").replacingOccurrences(of: ",", with: ".").trimmingCharacters(in: .whitespaces)) ?? 0
    }
}

// MARK: - Συνθέσεις

func ratingColor(_ r: Double) -> Color {
    r >= 8 ? Color(hex: 0x3B82F6) : r >= 7 ? C.win : r >= 6 ? Color(hex: 0xE3B505) : Color(hex: 0xE8772E)
}

struct RatingPill: View {
    let r: Double
    var gold = false
    var body: some View {
        Text(String(format: "%.1f", r)).font(F.body(11, .extra)).foregroundStyle(gold ? C.ink : C.text)
            .padding(.horizontal, 6).padding(.vertical, 2)
            .background(Capsule().fill(gold ? C.gold : C.ink))
            .overlay(Capsule().stroke(gold ? C.gold : ratingColor(r), lineWidth: 1.5))
    }
}

struct LineupsSection: View {
    let d: MatchDetail
    var body: some View {
        VStack(spacing: 14) {
            if let p = d.pitch, !p.home.isEmpty || !p.away.isEmpty { PitchView(p: p, d: d) }
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 300), spacing: 12, alignment: .top)], spacing: 12) {
                TeamList(name: d.card.home, logo: d.card.homeLogo, lineup: d.lineupHome, subs: d.subsHome, coach: d.coachHome, aek: d.card.aek == "home")
                TeamList(name: d.card.away, logo: d.card.awayLogo, lineup: d.lineupAway, subs: d.subsAway, coach: d.coachAway, aek: d.card.aek == "away")
            }
        }
    }
}

struct TeamPanelHeader: View {
    let name: String
    let logo: String
    var body: some View {
        HStack(spacing: 10) {
            TeamLogo(url: logo, size: 26)
            Text(name.upperGr).font(F.disp(20, black: true)).foregroundStyle(C.text).lineLimit(1)
            Spacer()
        }.padding(12).background(C.ink2)
    }
}

private struct TeamList: View {
    let name, logo: String
    let lineup, subs: [Player]
    let coach: String
    let aek: Bool
    var body: some View {
        if !lineup.isEmpty || !subs.isEmpty {
            VStack(alignment: .leading, spacing: 0) {
                TeamPanelHeader(name: name, logo: logo)
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(lineup, id: \.self) { line($0) }
                    if !subs.isEmpty { SectionLabel(text: "Αναπληρωματικοί").padding(.top, 10).padding(.bottom, 4); ForEach(subs, id: \.self) { line($0) } }
                    if !coach.isEmpty { Text("Προπ.: " + coach).font(F.body(12, .bold)).foregroundStyle(C.muted).padding(.top, 8) }
                }.padding(12)
            }
            .background(RoundedRectangle(cornerRadius: 12).fill(C.panel))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }
    func line(_ p: Player) -> some View {
        HStack(spacing: 10) {
            Text(p.number).font(F.body(12, .extra)).foregroundStyle(aek ? C.gold : C.text2).frame(width: 26, alignment: .trailing).monospacedDigit()
            Text(p.name + (p.captain ? " (C)" : "")).font(F.body(14, .bold)).foregroundStyle(C.text).lineLimit(1)
            if p.rating > 0 { RatingPill(r: p.rating) }
            Spacer(minLength: 0)
            if !p.role.isEmpty { Text(p.role).font(F.body(11, .bold)).foregroundStyle(C.muted) }
        }.padding(.vertical, 5)
    }
}

/// Γηπεδάκι με τις ενδεκάδες (γηπεδούχος πάνω, φιλοξενούμενος κάτω)
struct PitchView: View {
    let p: Pitch
    let d: MatchDetail
    var body: some View {
        VStack(spacing: 6) {
            HStack {
                Text(d.card.home.upperGr + (p.formationHome.isEmpty ? "" : "  " + p.formationHome)).font(F.body(12, .extra))
                Spacer()
            }.foregroundStyle(C.text)
            GeometryReader { g in
                let w = g.size.width, h = g.size.height
                ZStack {
                    Image("PitchBg").resizable().frame(width: w, height: h)
                    ForEach(Array(p.home.enumerated()), id: \.offset) { _, pl in
                        dot(pl, home: true).position(x: w * CGFloat((100 - pl.x) / 100), y: h * CGFloat(0.5 * (pl.y / 100) * 0.92 + 0.03))
                    }
                    ForEach(Array(p.away.enumerated()), id: \.offset) { _, pl in
                        dot(pl, home: false).position(x: w * CGFloat(pl.x / 100), y: h - h * CGFloat(0.5 * (pl.y / 100) * 0.92 + 0.03))
                    }
                }
            }
            .aspectRatio(500.0 / 698.0, contentMode: .fit)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            HStack {
                Spacer()
                Text((p.formationAway.isEmpty ? "" : p.formationAway + "  ") + d.card.away.upperGr).font(F.body(12, .extra))
            }.foregroundStyle(C.text)
        }
        .frame(maxWidth: 520)
    }

    func dot(_ pl: PitchPlayer, home: Bool) -> some View {
        let bg = Color(hexString: home ? d.card.homeColor : d.card.awayColor) ?? (home ? C.gold : .white)
        let fg = Color(hexString: home ? d.card.homeNum : d.card.awayNum) ?? C.ink
        let last = pl.name.split(separator: " ").last.map(String.init) ?? pl.name
        return VStack(spacing: 2) {
            ZStack {
                Circle().fill(bg).frame(width: 30, height: 30).overlay(Circle().stroke(.black.opacity(0.35), lineWidth: 1))
                Text(pl.number).font(F.body(12, .extra)).foregroundStyle(fg)
                if pl.goals > 0 { Text(pl.goals > 1 ? "⚽\(pl.goals)" : "⚽").font(.system(size: 10)).offset(x: 15, y: -12) }
                if pl.red { RoundedRectangle(cornerRadius: 1).fill(C.loss).frame(width: 7, height: 10).offset(x: -15, y: -12) }
                else if pl.yellow { RoundedRectangle(cornerRadius: 1).fill(Color.yellow).frame(width: 7, height: 10).offset(x: -15, y: -12) }
                if !pl.out.isEmpty { Image(systemName: "arrow.down.circle.fill").font(.system(size: 11)).foregroundStyle(C.loss, .white).offset(x: 15, y: 11) }
            }
            Text(last).font(F.body(10, .extra)).foregroundStyle(.white).lineLimit(1).shadow(color: .black, radius: 2).frame(maxWidth: 70)
            if pl.rating > 0 { RatingPill(r: pl.rating).scaleEffect(0.85) }
        }
    }
}

// MARK: - Παίκτες (βαθμολογία / box score)

struct PlayersSection: View {
    let d: MatchDetail
    var body: some View {
        if let x = d.extra {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 300), spacing: 12, alignment: .top)], spacing: 12) {
                if x.hasRatings {
                    RatingsPanel(name: d.card.home, logo: d.card.homeLogo, rows: x.ratingsHome, potm: x.potm)
                    RatingsPanel(name: d.card.away, logo: d.card.awayLogo, rows: x.ratingsAway, potm: x.potm)
                }
                if x.hasBox {
                    BoxPanel(name: d.card.home, logo: d.card.homeLogo, rows: x.boxHome)
                    BoxPanel(name: d.card.away, logo: d.card.awayLogo, rows: x.boxAway)
                }
            }
        }
    }
}

private struct RatingsPanel: View {
    let name, logo: String
    let rows: [RatingRow]
    let potm: Potm?
    @State private var all = false
    var body: some View {
        if !rows.isEmpty {
            VStack(alignment: .leading, spacing: 0) {
                TeamPanelHeader(name: name, logo: logo)
                VStack(spacing: 0) {
                    ForEach(Array(rows.prefix(all ? rows.count : 5).enumerated()), id: \.offset) { _, r in
                        let star = potm != nil && potm!.name == r.name
                        HStack(spacing: 10) {
                            Text(r.number).font(F.body(12, .extra)).foregroundStyle(C.muted).frame(width: 24, alignment: .trailing)
                            VStack(alignment: .leading, spacing: 1) {
                                Text(r.name).font(F.body(14, .bold)).foregroundStyle(C.text).lineLimit(1)
                                if star { Text("ΠΑΙΚΤΗΣ ΑΓΩΝΑ").font(F.body(9, .extra)).foregroundStyle(C.gold) }
                            }
                            Spacer()
                            RatingPill(r: r.rating, gold: star)
                        }
                        .padding(.vertical, 7)
                        .overlay(alignment: .bottom) { Rectangle().fill(C.line).frame(height: 1).opacity(0.6) }
                    }
                    if rows.count > 5 {
                        Button(all ? "Λιγότεροι" : "Όλοι οι παίκτες") { withAnimation { all.toggle() } }
                            .font(F.body(13, .extra)).foregroundStyle(C.gold).padding(.top, 10)
                    }
                }.padding(12)
            }
            .background(RoundedRectangle(cornerRadius: 12).fill(C.panel))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }
}

private struct BoxPanel: View {
    let name, logo: String
    let rows: [BoxRow]
    var body: some View {
        if !rows.isEmpty {
            VStack(alignment: .leading, spacing: 0) {
                TeamPanelHeader(name: name, logo: logo)
                Grid(alignment: .leading, horizontalSpacing: 8, verticalSpacing: 7) {
                    GridRow {
                        Text("Παίκτης"); Text("Λεπ").gridColumnAlignment(.trailing); Text("Πόν").gridColumnAlignment(.trailing)
                        Text("Ριμ").gridColumnAlignment(.trailing); Text("Ασ").gridColumnAlignment(.trailing)
                    }.font(F.body(11, .extra)).foregroundStyle(C.muted)
                    ForEach(rows.sorted { $0.pts > $1.pts }, id: \.self) { r in
                        GridRow {
                            Text((r.starter ? "• " : "") + r.name).lineLimit(1).foregroundStyle(C.text)
                            Text("\(r.min)"); Text("\(r.pts)").foregroundStyle(C.gold); Text("\(r.reb)"); Text("\(r.ast)")
                        }.font(F.body(13, .bold)).monospacedDigit().foregroundStyle(C.text2)
                    }
                }.padding(12)
            }
            .background(RoundedRectangle(cornerRadius: 12).fill(C.panel))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }
}
