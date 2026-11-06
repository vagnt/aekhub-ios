import SwiftUI

/// Σελίδα αγώνα (σχέδιο iOS 26): θολό φόντο, γυάλινα κουμπιά, κίτρινο πανό διοργάνωσης, μεγάλα λογότυπα,
/// σκορ/VS, γήπεδο & κανάλι, «Powered by», καρτέλες Σύνοψη · Σύνθεση · Στατιστικά · Πορεία (· Παίκτες). Live: ανανέωση 10″.
struct MatchView: View {
    let id: Int
    @State private var d: MatchDetail?
    @State private var error: String?
    @State private var tab = ""
    @State private var openURL: URL?
    @EnvironmentObject var prefs: Prefs
    @Environment(\.dismiss) var dismiss

    init(id: Int) {
        self.id = id
        _d = State(initialValue: Api.shared.peek(Api.pMatch(id)).map(MatchDetail.init))
    }

    var body: some View {
        ZStack(alignment: .top) {
            backdrop
            ScrollView {
                VStack(spacing: 0) {
                    Color.clear.frame(height: 64)
                    if let d {
                        MatchHeader(d: d)
                        if let s = d.sponsor, !s.logo.isEmpty { SponsorView(s: s) }
                        let tabs = tabsFor(d)
                        let cur = tabs.contains(tab) ? tab : tabs[0]
                        SegTabs(tabs: tabs, sel: Binding(get: { cur }, set: { tab = $0 }))
                            .padding(.horizontal, screenPad).padding(.top, 18).padding(.bottom, 16)
                        Group {
                            switch cur {
                            case "Σύνθεση": LineupsSection(d: d)
                            case "Στατιστικά": StatsSection(d: d)
                            case "Πορεία": TimelineSection(d: d)
                            case "Παίκτες": PlayersSection(d: d)
                            default: SummarySection(d: d, openURL: $openURL)
                            }
                        }
                        .frame(maxWidth: 820)
                        .padding(.horizontal, screenPad)
                    } else if let error {
                        EmptyState(icon: "wifi.exclamationmark", text: error) { Task { await load() } }
                    } else {
                        ProgressView().tint(C.gold).padding(80)
                    }
                }
                .padding(.bottom, 40)
            }
            topBar
        }
        .background(C.ink.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
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

    /// Θολή φωτογραφία πίσω από την κεφαλίδα
    var backdrop: some View {
        ZStack {
            if let bg = d?.bg, !bg.isEmpty, !bg.contains("hero-bg") { NetImage(url: bg, w: 800) } else { Image("HeroBg").resizable().scaledToFill() }
        }
        .frame(height: 520).frame(maxWidth: .infinity).clipped()
        .blur(radius: 18).opacity(0.55)
        .overlay(LinearGradient(colors: [C.ink.opacity(0.2), C.ink.opacity(0.6), C.ink], startPoint: .top, endPoint: .bottom))
        .ignoresSafeArea(edges: .top)
    }

    var topBar: some View {
        HStack(spacing: 10) {
            GlassCircle(icon: "chevron.left") { dismiss() }
            Spacer()
            if let l = d?.card.link, let u = URL(string: l) {
                ShareLink(item: u) {
                    Image(systemName: "square.and.arrow.up").font(.system(size: 17, weight: .semibold)).foregroundStyle(C.text)
                        .frame(width: 44, height: 44).glass(Circle(), interactive: true)
                }
            }
            if let c = d?.card, !c.finished {
                // 🔔 Ειδοποιήσεις για ΑΥΤΟΝ τον αγώνα (υπενθύμιση, σέντρα, γκολ, τελικό + Live Activity)
                let on = prefs.matchAlerts.contains(id)
                GlassCircle(icon: on ? "bell.fill" : "bell", gold: on) {
                    if on { prefs.matchAlerts.remove(id) } else {
                        prefs.matchAlerts.insert(id)
                        Task { _ = await Notifier.shared.requestPermission(); await Notifier.shared.refresh(force: true) }
                    }
                }
            }
        }
        .padding(.horizontal, 16).padding(.top, 4)
    }

    func load() async {
        do {
            let x = try await Api.shared.match(id)
            d = x; error = nil
            LiveActivities.shared.update(x.card)
        }
        catch { if d == nil { self.error = "Δεν φόρτωσε ο αγώνας.\n" + error.localizedDescription } }
    }

    func tabsFor(_ d: MatchDetail) -> [String] {
        var t = ["Σύνοψη"]
        if d.resultOnly { return t }
        if d.hasLineups || d.pitch != nil { t.append("Σύνθεση") }
        if !d.stats.isEmpty { t.append("Στατιστικά") }
        if !d.events.isEmpty || !d.groups.isEmpty || (d.card.live && d.timeline) { t.append("Πορεία") }
        if let x = d.extra, x.hasRatings || x.hasBox { t.append("Παίκτες") }
        return t
    }
}

/// Γυάλινες καρτέλες (segmented)
struct SegTabs: View {
    let tabs: [String]
    @Binding var sel: String
    @Namespace private var ns
    var body: some View {
        HStack(spacing: 2) {
            ForEach(tabs, id: \.self) { t in
                let on = t == sel
                Button { withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) { sel = t } } label: {
                    Text(t).font(F.body(tabs.count > 4 ? 13 : 15, on ? .semibold : .medium)).foregroundStyle(on ? C.text : C.text2)
                        .lineLimit(1).minimumScaleFactor(0.8)
                        .frame(maxWidth: .infinity).frame(height: 40)
                        .background { if on { Capsule().fill(Color.white.opacity(0.14)).matchedGeometryEffect(id: "seg", in: ns) } }
                        .contentShape(Capsule())
                }.buttonStyle(.plain)
            }
        }
        .padding(4)
        .glass(Capsule())
    }
}

// MARK: - Κεφαλίδα (πανό, ημερομηνία, κατάσταση, ομάδες, σκορ)

struct MatchHeader: View {
    let d: MatchDetail
    var c: MatchCard { d.card }
    var body: some View {
        VStack(spacing: 14) {
            let banner = [c.competition, c.matchday].filter { !$0.isEmpty }.joined(separator: " · ")
            if !banner.isEmpty {
                Text(banner.upperGr).font(F.disp(17)).foregroundStyle(C.ink).multilineTextAlignment(.center).lineLimit(2)
                    .padding(.horizontal, 26).padding(.vertical, 7)
                    .background(SlantShape(k: 12).fill(C.gold))
                    .padding(.horizontal, screenPad)
            }
            Text((Fmt.dayHeader(c.date) + (c.time.isEmpty ? "" : " · " + c.time))).font(F.body(15, .semibold)).tracking(0.8).foregroundStyle(C.text2)
            statusChip
            HStack(alignment: .top, spacing: 4) {
                team(c.home, c.homeLogo, c.aek == "home", d.scorersHome)
                VStack(spacing: 6) {
                    if c.upcoming && !c.hasScore {
                        Text("VS").font(F.disp(40)).foregroundStyle(C.text.opacity(0.35)).padding(.top, 22)
                    } else {
                        HStack(spacing: 10) {
                            Text(c.scoreHome).foregroundStyle(col(true))
                            Text("–").foregroundStyle(C.muted.opacity(0.6))
                            Text(c.scoreAway).foregroundStyle(col(false))
                        }.font(F.disp(68)).monospacedDigit().minimumScaleFactor(0.6).lineLimit(1).padding(.top, 8)
                        if !c.penHome.isEmpty { Text("Πέναλτι \(c.penHome)–\(c.penAway)").font(F.body(13, .semibold)).foregroundStyle(C.text2) }
                        if let ht = d.extra?.htScore, !ht.isEmpty, c.sport.contains("football") || c.sport == "futsal" {
                            Text("Ημίχρονο \(ht)").font(F.body(12)).foregroundStyle(C.muted)
                        }
                    }
                }.frame(minWidth: 130)
                team(c.away, c.awayLogo, c.aek == "away", d.scorersAway)
            }
            .padding(.horizontal, 10)
            if !d.periods.isEmpty { periods }
            HStack(spacing: 10) {
                if !c.venue.isEmpty { chip("mappin.and.ellipse", c.venue) }
                if !c.broadcast.isEmpty { chip("tv", c.broadcast) }
            }
            .padding(.horizontal, screenPad)
        }
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder var statusChip: some View {
        if c.live {
            LiveBadge(m: c, size: 13).padding(.horizontal, 14).padding(.vertical, 7).glass(Capsule(), tint: C.live.opacity(0.25))
        } else {
            let (t, col): (String, Color) = c.finished ? ("ΤΕΛΙΚΟ", C.text2) : c.postponed ? ("ΑΝΑΒΟΛΗ", C.muted) : ("ΕΠΕΡΧΟΜΕΝΟ", C.gold)
            Text(t).font(F.tag(12)).tracking(1).foregroundStyle(col)
                .padding(.horizontal, 16).padding(.vertical, 8)
                .glass(Capsule(), tint: c.finished || c.postponed ? nil : Color(hex: 0x2E4A2E))
        }
    }

    func col(_ home: Bool) -> Color {
        let isAek = home ? c.aek == "home" : c.aek == "away"
        if c.live { return isAek ? C.gold : C.text }
        guard let x = Int(c.scoreHome), let y = Int(c.scoreAway) else { return C.text }
        let mine = home ? x : y, their = home ? y : x
        return mine >= their ? (isAek ? C.gold : C.text) : C.text.opacity(0.5)
    }

    func team(_ name: String, _ logo: String, _ aek: Bool, _ scorers: [String]) -> some View {
        VStack(spacing: 10) {
            TeamLogo(url: logo, size: 80, name: name)
            TeamName(name: name, aek: aek, size: 21)
            ForEach(scorers, id: \.self) { s in
                Text(s).font(F.body(12)).foregroundStyle(C.text2).multilineTextAlignment(.center).lineLimit(2)
            }
        }.frame(maxWidth: .infinity)
    }

    func chip(_ icon: String, _ t: String) -> some View {
        HStack(spacing: 7) {
            Image(systemName: icon).font(.system(size: 13, weight: .semibold)).foregroundStyle(C.gold)
            Text(t).font(F.body(14, .semibold)).foregroundStyle(C.text).lineLimit(1)
        }
        .padding(.horizontal, 14).frame(height: 38)
        .glass(Capsule())
    }

    var periods: some View {
        Grid(horizontalSpacing: 0, verticalSpacing: 8) {
            GridRow {
                Text("").frame(width: 86)
                ForEach(Array(d.periods.enumerated()), id: \.offset) { _, p in Text(p.label).font(F.tag(11)).foregroundStyle(C.muted).frame(maxWidth: .infinity) }
            }
            GridRow {
                Text(c.home.upperGr).font(F.disp(15)).lineLimit(1).frame(width: 86, alignment: .leading)
                ForEach(Array(d.periods.enumerated()), id: \.offset) { _, p in Text(p.home).font(F.body(15, .semibold)).monospacedDigit().frame(maxWidth: .infinity) }
            }
            GridRow {
                Text(c.away.upperGr).font(F.disp(15)).lineLimit(1).frame(width: 86, alignment: .leading)
                ForEach(Array(d.periods.enumerated()), id: \.offset) { _, p in Text(p.away).font(F.body(15, .semibold)).monospacedDigit().frame(maxWidth: .infinity) }
            }
        }
        .foregroundStyle(C.text)
        .padding(14).card(20)
        .frame(maxWidth: 560)
        .padding(.horizontal, screenPad)
    }
}

/// Σύνοψη: ειδοποίηση 30′ πριν, μόνο-αποτέλεσμα, στιγμιότυπα, στοιχεία αγώνα
struct SummarySection: View {
    let d: MatchDetail
    @Binding var openURL: URL?
    @EnvironmentObject var prefs: Prefs
    var body: some View {
        VStack(spacing: 14) {
            if !d.card.finished {
                let on = prefs.matchAlerts.contains(d.id) || prefs.wants(d.card.sport, Kinds.reminder)
                Button {
                    if prefs.matchAlerts.contains(d.id) { prefs.matchAlerts.remove(d.id) }
                    else { prefs.matchAlerts.insert(d.id); Task { _ = await Notifier.shared.requestPermission(); await Notifier.shared.refresh(force: true) } }
                } label: {
                    HStack(spacing: 14) {
                        Image(systemName: on ? "bell.fill" : "bell").font(.system(size: 20, weight: .semibold)).foregroundStyle(C.ink)
                            .frame(width: 48, height: 48).background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(C.goldGrad))
                        VStack(alignment: .leading, spacing: 3) {
                            Text(on ? "Ειδοποίηση 30′ πριν" : "Ενεργοποίησε ειδοποιήσεις").font(F.body(17, .semibold)).foregroundStyle(C.text)
                            Text("Σέντρα, γκολ, ημίχρονο και τελικό — και ως Live Activity στην κλειδωμένη οθόνη.").font(F.body(14)).foregroundStyle(C.muted).multilineTextAlignment(.leading)
                        }
                        Spacer(minLength: 0)
                    }
                    .padding(16).card(24)
                }.buttonStyle(.plain)
            }
            if d.resultOnly {
                Text(d.card.finished ? "Ο αγώνας δεν καλύφθηκε live. Υπάρχει μόνο το τελικό αποτέλεσμα." : "Ο αγώνας δεν καλύπτεται live· ενημερώνεται το σκορ στο ημίχρονο και στο τέλος.")
                    .font(F.body(15)).foregroundStyle(C.text2).padding(16).frame(maxWidth: .infinity, alignment: .leading).card(24)
            }
            if !d.highlights.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    SectionLabel(text: "Στιγμιότυπα")
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(d.highlights, id: \.self) { h in
                                Button { openURL = URL(string: h.url) } label: {
                                    VStack(alignment: .leading, spacing: 6) {
                                        ZStack { NetImage(url: h.thumb, w: 500).frame(width: 230, height: 130).clipped(); VideoBadge() }
                                            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                                        Text(h.title).font(F.body(13, .semibold)).foregroundStyle(C.text).lineLimit(2).frame(width: 230, alignment: .leading)
                                    }
                                }.buttonStyle(.plain)
                            }
                        }
                    }
                }
            }
            // Τελευταία γεγονότα (live)
            let evs = (d.groups.isEmpty ? d.events : d.groups.flatMap(\.events)).filter { $0.type != "point" }.prefix(4)
            if !evs.isEmpty && !d.resultOnly {
                VStack(spacing: 0) { ForEach(Array(evs.enumerated()), id: \.offset) { EventRow(e: $0.element, d: d) } }
                    .padding(.horizontal, 14).card(24)
            }
            VStack(alignment: .leading, spacing: 10) {
                let c = d.card
                row("trophy", [c.competition, c.matchday].filter { !$0.isEmpty }.joined(separator: " · "))
                row("calendar", Fmt.dayHeader(c.date).capitalized(with: Fmt.gr) + (c.time.isEmpty ? "" : " · " + c.time))
                row("mappin.and.ellipse", c.venue)
                row("tv", c.broadcast)
                row("person.badge.shield.checkmark", d.referee.isEmpty ? "" : "Διαιτητής: " + d.referee)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16).card(24)
        }
    }
    @ViewBuilder func row(_ icon: String, _ t: String) -> some View {
        if !t.isEmpty {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: icon).foregroundStyle(C.gold).frame(width: 20)
                Text(t).font(F.body(15)).foregroundStyle(C.text2)
            }
        }
    }
}

struct SponsorView: View {
    let s: Sponsor
    @Environment(\.openURL) var open
    var body: some View {
        VStack(spacing: 6) {
            Rectangle().fill(LinearGradient(colors: [.clear, C.gold.opacity(0.35), .clear], startPoint: .leading, endPoint: .trailing)).frame(height: 1).padding(.horizontal, 40)
            Text(s.label).font(F.body(13)).foregroundStyle(C.muted).padding(.top, 8)
            Button { if let u = URL(string: s.click) { open(u) } } label: {
                NetImage(url: s.logo, w: 600, mode: .fit)
                    .frame(width: s.w > 0 ? CGFloat(s.w) : 240, height: CGFloat(max(28, s.h)))
            }.buttonStyle(.plain)
            if !s.note.isEmpty { Text(s.note).font(F.body(10)).foregroundStyle(C.muted) }
        }
        .padding(.top, 18)
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

/// Γραμμή πορείας: λεπτό (κίτρινο) · εικονίδιο · γεγονός & παίκτης · σκορ/ομάδα δεξιά, διακεκομμένη γραμμή από κάτω
struct EventRow: View {
    let e: MatchEvent
    var d: MatchDetail? = nil
    var body: some View {
        let big = e.type.contains("goal") && !e.type.contains("miss")
        VStack(spacing: 0) {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                Text(e.minute).font(F.disp(19)).foregroundStyle(C.gold).frame(width: 44, alignment: .leading).monospacedDigit()
                Text(eventIcon(e.type)).font(.system(size: 15)).frame(width: 24)
                VStack(alignment: .leading, spacing: 2) {
                    Text(e.label).font(F.body(16, big ? .semibold : .medium)).foregroundStyle(big ? C.text : C.text2)
                    if !e.text.isEmpty { Text(e.text).font(F.body(15)).foregroundStyle(C.text) }
                }
                Spacer(minLength: 4)
                VStack(alignment: .trailing, spacing: 2) {
                    if !e.score.isEmpty { Text(e.score).font(F.body(15, .semibold)).foregroundStyle(C.muted).monospacedDigit() }
                    if let d, !e.team.isEmpty {
                        Text(e.team == "home" ? d.card.home : d.card.away).font(F.body(12)).foregroundStyle(e.team == d.card.aek ? C.gold : C.muted).lineLimit(1)
                    }
                }
            }
            .padding(.vertical, 12)
            Line().stroke(C.line, style: StrokeStyle(lineWidth: 1, dash: [3, 4])).frame(height: 1)
        }
    }
}

struct TimelineSection: View {
    let d: MatchDetail
    var body: some View {
        VStack(spacing: 12) {
            if d.groups.isEmpty {
                if d.events.isEmpty { EmptyState(icon: "clock", text: "Η πορεία του αγώνα θα εμφανιστεί εδώ.") }
                else {
                    VStack(spacing: 0) { ForEach(Array(d.events.enumerated()), id: \.offset) { EventRow(e: $0.element, d: d) } }
                        .padding(.horizontal, 16).card(24)
                }
            } else {
                ForEach(Array(d.groups.enumerated()), id: \.offset) { _, g in GroupBlock(g: g, d: d) }
            }
        }
    }
}

/// Περίοδος/σετ: «Q2 16–22 ⌄» — live η τρέχουσα ανοιχτή, οι προηγούμενες μαζεμένες
private struct GroupBlock: View {
    let g: EventGroup
    let d: MatchDetail
    @State private var open: Bool
    init(g: EventGroup, d: MatchDetail) { self.g = g; self.d = d; _open = State(initialValue: g.open) }
    var body: some View {
        VStack(spacing: 0) {
            Button { withAnimation(.easeOut(duration: 0.2)) { open.toggle() } } label: {
                HStack(spacing: 10) {
                    Text(g.label.upperGr).font(F.disp(22)).foregroundStyle(C.gold)
                    Text(g.score).font(F.body(16, .semibold)).foregroundStyle(C.text).monospacedDigit()
                    Spacer()
                    Image(systemName: "chevron.down").font(.system(size: 13, weight: .bold)).foregroundStyle(C.text2).rotationEffect(.degrees(open ? 180 : 0))
                }
                .padding(.vertical, 14).contentShape(Rectangle())
            }.buttonStyle(.plain)
            if open { ForEach(Array(g.events.enumerated()), id: \.offset) { EventRow(e: $0.element, d: d) } }
        }
        .padding(.horizontal, 16).card(24)
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
                        Text(s.home + (s.type == "pct" ? "%" : "")).font(F.body(14, .bold)).foregroundStyle(h >= a ? C.text : C.text2)
                        Spacer()
                        Text(s.label).font(F.body(12, .bold)).foregroundStyle(C.text2).multilineTextAlignment(.center)
                        Spacer()
                        Text(s.away + (s.type == "pct" ? "%" : "")).font(F.body(14, .bold)).foregroundStyle(a >= h ? C.text : C.text2)
                    }
                    GeometryReader { g in
                        HStack(spacing: 4) {
                            HStack { Spacer(minLength: 0); Capsule().fill(C.gold.opacity(h >= a ? 1 : 0.45)).frame(width: (g.size.width / 2 - 2) * CGFloat(h / tot)) }
                            HStack { Capsule().fill(C.text.opacity(a >= h ? 0.9 : 0.4)).frame(width: (g.size.width / 2 - 2) * CGFloat(a / tot)); Spacer(minLength: 0) }
                        }
                    }.frame(height: 6)
                }
            }
        }
        .padding(16).card(24)
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
        Text(String(format: "%.1f", r)).font(F.body(11, .bold)).foregroundStyle(gold ? C.ink : C.text)
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
            Text(name.upperGr).font(F.disp(21)).foregroundStyle(C.text).lineLimit(1)
            Spacer()
        }.padding(14).background(C.ink2)
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
            .background(RoundedRectangle(cornerRadius: 24, style: .continuous).fill(C.panel))
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).stroke(C.line, lineWidth: 1))
        }
    }
    func line(_ p: Player) -> some View {
        HStack(spacing: 10) {
            Text(p.number).font(F.body(12, .bold)).foregroundStyle(aek ? C.gold : C.text2).frame(width: 26, alignment: .trailing).monospacedDigit()
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
                Text(d.card.home.upperGr + (p.formationHome.isEmpty ? "" : "  " + p.formationHome)).font(F.body(12, .bold))
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
                Text((p.formationAway.isEmpty ? "" : p.formationAway + "  ") + d.card.away.upperGr).font(F.body(12, .bold))
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
                Text(pl.number).font(F.body(12, .bold)).foregroundStyle(fg)
                if pl.goals > 0 { Text(pl.goals > 1 ? "⚽\(pl.goals)" : "⚽").font(.system(size: 10)).offset(x: 15, y: -12) }
                if pl.red { RoundedRectangle(cornerRadius: 1).fill(C.loss).frame(width: 7, height: 10).offset(x: -15, y: -12) }
                else if pl.yellow { RoundedRectangle(cornerRadius: 1).fill(Color.yellow).frame(width: 7, height: 10).offset(x: -15, y: -12) }
                if !pl.out.isEmpty { Image(systemName: "arrow.down.circle.fill").font(.system(size: 11)).foregroundStyle(C.loss, .white).offset(x: 15, y: 11) }
            }
            Text(last).font(F.body(10, .bold)).foregroundStyle(.white).lineLimit(1).shadow(color: .black, radius: 2).frame(maxWidth: 70)
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
                            Text(r.number).font(F.body(12, .bold)).foregroundStyle(C.muted).frame(width: 24, alignment: .trailing)
                            VStack(alignment: .leading, spacing: 1) {
                                Text(r.name).font(F.body(14, .bold)).foregroundStyle(C.text).lineLimit(1)
                                if star { Text("ΠΑΙΚΤΗΣ ΑΓΩΝΑ").font(F.body(9, .bold)).foregroundStyle(C.gold) }
                            }
                            Spacer()
                            RatingPill(r: r.rating, gold: star)
                        }
                        .padding(.vertical, 7)
                        .overlay(alignment: .bottom) { Rectangle().fill(C.line).frame(height: 1).opacity(0.6) }
                    }
                    if rows.count > 5 {
                        Button(all ? "Λιγότεροι" : "Όλοι οι παίκτες") { withAnimation { all.toggle() } }
                            .font(F.body(13, .bold)).foregroundStyle(C.gold).padding(.top, 10)
                    }
                }.padding(12)
            }
            .background(RoundedRectangle(cornerRadius: 24, style: .continuous).fill(C.panel))
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).stroke(C.line, lineWidth: 1))
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
                    }.font(F.body(11, .bold)).foregroundStyle(C.muted)
                    ForEach(rows.sorted { $0.pts > $1.pts }, id: \.self) { r in
                        GridRow {
                            Text((r.starter ? "• " : "") + r.name).lineLimit(1).foregroundStyle(C.text)
                            Text("\(r.min)"); Text("\(r.pts)").foregroundStyle(C.gold); Text("\(r.reb)"); Text("\(r.ast)")
                        }.font(F.body(13, .bold)).monospacedDigit().foregroundStyle(C.text2)
                    }
                }.padding(12)
            }
            .background(RoundedRectangle(cornerRadius: 24, style: .continuous).fill(C.panel))
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).stroke(C.line, lineWidth: 1))
        }
    }
}
