import SwiftUI

/// Σελίδα αγώνα — ΠΙΣΤΗ ΑΝΤΙΓΡΑΦΗ του Android MatchScreen: κεφαλίδα (φόντο, κίτρινο πανό, ημερομηνία, κατάσταση,
/// σήματα, σκορ σε κουτιά, σκόρερ, γήπεδο/κανάλι, διαιτητής) · χορηγός · live εικόνα · στιγμιότυπα ·
/// καρτέλες Πορεία / Στατιστικά / Συνθέσεις / Παίκτες. iPad οριζόντια: Πορεία αριστερά, τα υπόλοιπα δεξιά.
struct MatchView: View {
    let id: Int
    @State private var d: MatchDetail?
    @State private var error = false
    @State private var tab = ""
    @State private var openURL: URL?
    @EnvironmentObject var prefs: Prefs
    @Environment(\.dismiss) var dismiss
    @Environment(\.horizontalSizeClass) var hsc

    init(id: Int) {
        self.id = id
        _d = State(initialValue: Api.shared.peek(Api.pMatch(id)).map(MatchDetail.init))
    }

    var body: some View {
        Group {
            if let d { content(d) }
            else if error { EmptyState(icon: "wifi.exclamationmark", text: "Δεν φόρτωσε. Έλεγξε τη σύνδεση.") { Task { await load() } } }
            else { ProgressView().tint(C.gold).frame(maxWidth: .infinity, maxHeight: .infinity) }
        }
        .background(C.ink.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
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
        do {
            let x = try await Api.shared.match(id)
            if let old = d, old.card.scoreHome != x.card.scoreHome || old.card.scoreAway != x.card.scoreAway { haptic(.heavy) }
            d = x; error = false
            LiveActivities.shared.update(x.card)
        } catch { if d == nil { self.error = true } }
    }

    func tabsFor(_ d: MatchDetail) -> [String] {
        var t: [String] = []
        if !d.events.isEmpty || (d.card.live && d.timeline) { t.append("Πορεία") }
        if !d.stats.isEmpty || !d.periods.isEmpty { t.append("Στατιστικά") }
        if d.hasLineups { t.append("Συνθέσεις") }
        if d.extra?.hasAnalysis == true { t.append("Παίκτες") }
        return t
    }

    @ViewBuilder func content(_ d: MatchDetail) -> some View {
        let tabs = tabsFor(d)
        let split = hsc == .regular && tabs.contains("Πορεία") && tabs.count > 1
        let rTabs = split ? tabs.filter { $0 != "Πορεία" } : tabs
        let cur = rTabs.contains(tab) ? tab : (rTabs.first ?? "")
        ScrollView {
            VStack(spacing: 14) {
                MatchHero(d: d, alert: prefs.alertOn(d.card), back: { dismiss() }) { prefs.toggleMatchAlert(d.card) }
                Group {
                    if let s = d.sponsor, !s.logo.isEmpty || !s.name.isEmpty { SponsorBlock(s: s) }
                    if let s = d.stream { StreamCard(s: s) { openURL = URL(string: s.url) } }
                    if !d.highlights.isEmpty { highlights(d) }
                    if split {
                        HStack(alignment: .top, spacing: 8) {
                            VStack(spacing: 14) { TimelineSection(d: d) }.frame(maxWidth: .infinity)
                            VStack(spacing: 14) {
                                if rTabs.count > 1 { TabBar(tabs: rTabs, sel: Binding(get: { cur }, set: { tab = $0 })) }
                                section(cur, d)
                            }.frame(maxWidth: .infinity)
                        }
                    } else {
                        if tabs.count > 1 { TabBar(tabs: tabs, sel: Binding(get: { cur }, set: { tab = $0 })) }
                        section(cur, d).readable(820)
                    }
                    noCoverage(d)
                }
            }
            .padding(.bottom, 28)
        }
        .refreshable { haptic(); await load() }
    }

    @ViewBuilder func section(_ t: String, _ d: MatchDetail) -> some View {
        switch t {
        case "Πορεία": TimelineSection(d: d)
        case "Στατιστικά": StatsSection(d: d)
        case "Συνθέσεις": LineupsSection(d: d)
        case "Παίκτες": if let x = d.extra { PlayersSection(d: d, x: x) }
        default: EmptyView()
        }
    }

    /// «Μόνο αποτέλεσμα» / δεν καλύφθηκε live
    @ViewBuilder func noCoverage(_ d: MatchDetail) -> some View {
        let ro = d.resultOnly && !d.card.upcoming && !d.card.postponed
        let none = tabsFor(d).isEmpty && !d.liveScore && !d.card.live && d.card.finished
        if ro || none {
            let ht = (d.extra?.htScore ?? "").replacingOccurrences(of: "-", with: "–")
            HStack(spacing: 14) {
                Image(systemName: "info.circle").font(.system(size: 20)).foregroundStyle(C.gold).frame(width: 44, height: 44).background(Circle().fill(C.panel3))
                VStack(alignment: .leading, spacing: 3) {
                    Text("ΜΟΝΟ ΑΠΟΤΕΛΕΣΜΑ").font(F.disp(18)).foregroundStyle(C.text)
                    Text((ro ? "Ο αγώνας δεν καλύπτεται live· ενημερώνεται το σκορ στο ημίχρονο και στο τέλος." : "Ο αγώνας δεν καλύφθηκε live. Υπάρχει μόνο το τελικό αποτέλεσμα.") + (ht.isEmpty ? "" : "\nΗμίχρονο: \(ht)"))
                        .font(F.body(13)).foregroundStyle(C.text2)
                }
                Spacer(minLength: 0)
            }
            .padding(16)
            .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(C.panel))
            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(C.line, lineWidth: 1))
            .padding(.horizontal, screenPad)
        }
    }

    func highlights(_ d: MatchDetail) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionTitle(text: "Στιγμιότυπα").padding(.horizontal, screenPad)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(d.highlights, id: \.self) { h in
                        Button { openURL = URL(string: h.url) } label: {
                            VStack(alignment: .leading, spacing: 6) {
                                ZStack { FillImage(url: h.thumb, w: 500, height: 118); PlayBadge(size: 40) }
                                    .frame(width: 210, height: 118).background(C.panel2).clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                                Text(h.title).font(F.body(13, .bold)).foregroundStyle(C.text).lineLimit(2).multilineTextAlignment(.leading).frame(width: 210, alignment: .leading)
                            }
                        }.buttonStyle(.plain)
                    }
                }.padding(.horizontal, screenPad)
            }
        }
    }
}

/// Καρτέλες: σκούρο πάνελ, η επιλεγμένη κίτρινη
struct TabBar: View {
    let tabs: [String]
    @Binding var sel: String
    var body: some View {
        HStack(spacing: 0) {
            ForEach(tabs, id: \.self) { t in
                let on = t == sel
                Button { haptic(); withAnimation(.easeOut(duration: 0.15)) { sel = t } } label: {
                    Text(t).font(F.body(13, on ? .heavy : .bold)).foregroundStyle(on ? C.ink : C.text2).lineLimit(1).minimumScaleFactor(0.8)
                        .frame(maxWidth: .infinity).padding(.vertical, 10)
                        .background(RoundedRectangle(cornerRadius: 9, style: .continuous).fill(on ? C.gold : .clear))
                        .contentShape(Rectangle())
                }.buttonStyle(.plain)
            }
        }
        .padding(4)
        .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(C.panel))
        .padding(.horizontal, screenPad)
        .readable(820)
    }
}

/// Τίτλος ενότητας αγώνα: κίτρινος κύκλος › + τίτλος
struct SectionTitle: View {
    let text: String
    var body: some View {
        HStack(spacing: 10) {
            Text("›").font(F.disp(20)).foregroundStyle(C.ink).frame(width: 26, height: 26).background(Circle().fill(C.gold))
            Text(text.upperGr).font(F.disp(24)).foregroundStyle(C.text)
            Spacer(minLength: 0)
        }
    }
}

// MARK: - Κεφαλίδα (Hero)

struct MatchHero: View {
    let d: MatchDetail
    let alert: Bool
    let back: () -> Void
    let toggleAlert: () -> Void
    var c: MatchCard { d.card }

    var body: some View {
        VStack(spacing: 10) {
            HStack {
                round("chevron.left", C.text, back)
                Spacer()
                if let u = URL(string: c.link), !c.link.isEmpty {
                    ShareLink(item: u) {
                        Image(systemName: "square.and.arrow.up").font(.system(size: 18, weight: .semibold)).foregroundStyle(C.text)
                            .frame(width: 44, height: 44).glass(Circle(), interactive: true)
                    }
                }
                if c.upcoming { round(alert ? "bell.fill" : "bell", C.gold) { haptic(.medium); toggleAlert() } }
            }
            .padding(.horizontal, 12)

            let comp = [c.competition, c.matchday].filter { !$0.isEmpty }.joined(separator: " · ")
            if !comp.isEmpty {
                Text(comp.upperGr).font(F.disp(17)).foregroundStyle(C.ink).lineLimit(1).minimumScaleFactor(0.6)
                    .padding(.horizontal, 18).padding(.vertical, 6)
                    .background(SlantShape(k: 8).fill(C.gold))
                    .frame(maxWidth: 340)
                    .padding(.horizontal, 24)
            }
            Text(Fmt.dayHeader(c.date) + (c.time.isEmpty ? "" : " · " + c.time)).font(F.body(12, .heavy)).tracking(1).foregroundStyle(C.text2)
            StatusPill(c: c)

            HStack(alignment: .center, spacing: 0) {
                teamCol(c.homeLogo, c.home, c.aek == "home")
                if c.upcoming || c.postponed {
                    Text("VS").font(F.disp(36)).foregroundStyle(C.line2).padding(.horizontal, 6)
                } else {
                    HStack(spacing: 6) {
                        ScoreBox(v: c.scoreHome.isEmpty ? "0" : c.scoreHome, aek: c.aek == "home")
                        Text(":").font(F.disp(34)).foregroundStyle(C.muted)
                        ScoreBox(v: c.scoreAway.isEmpty ? "0" : c.scoreAway, aek: c.aek == "away")
                    }
                }
                teamCol(c.awayLogo, c.away, c.aek == "away")
            }
            .padding(.horizontal, 12)

            if !c.penHome.isEmpty && !c.penAway.isEmpty { Text("Πέναλτι \(c.penHome)–\(c.penAway)").font(F.body(13, .heavy)).foregroundStyle(C.gold) }

            if !d.scorersHome.isEmpty || !d.scorersAway.isEmpty {
                Rectangle().fill(C.line2).frame(height: 1).padding(.horizontal, 24)
                HStack(alignment: .top, spacing: 16) {
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(d.scorersHome, id: \.self) { s in HStack(spacing: 5) { Text(s).font(F.body(12, .bold)).foregroundStyle(C.text2); sportIcon } }
                    }.frame(maxWidth: .infinity, alignment: .leading)
                    VStack(alignment: .trailing, spacing: 4) {
                        ForEach(d.scorersAway, id: \.self) { s in HStack(spacing: 5) { sportIcon; Text(s).font(F.body(12, .bold)).foregroundStyle(C.text2) } }
                    }.frame(maxWidth: .infinity, alignment: .trailing)
                }
                .padding(.horizontal, 20)
            }

            HStack(spacing: 8) {
                if !c.venue.isEmpty { chip("mappin.and.ellipse", c.venue) }
                if !c.broadcast.isEmpty { chip("tv", c.broadcast) }
            }
            .padding(.horizontal, screenPad)
            if !d.referee.isEmpty { Text("Διαιτητής: " + d.referee).font(F.body(12)).foregroundStyle(C.muted) }
        }
        .padding(.bottom, 18)
        .frame(maxWidth: .infinity)
        .background {
            // το φόντο ανεβαίνει και κάτω από τη μπάρα κατάστασης
            ZStack {
                Color.clear.overlay(Image("HeroBg").resizable().scaledToFill(), alignment: .top).clipped()
                LinearGradient(stops: [.init(color: C.ink.opacity(0.55), location: 0), .init(color: C.ink.opacity(0.86), location: 0.55), .init(color: C.ink, location: 1)], startPoint: .top, endPoint: .bottom)
                RadialGradient(colors: [C.gold.opacity(0.16), .clear], center: .top, startRadius: 0, endRadius: 360)
            }
            .padding(.top, -160)
        }
        .overlay(alignment: .bottom) {
            LinearGradient(colors: [.clear, C.gold, .clear], startPoint: .leading, endPoint: .trailing).frame(height: 2)
        }
    }

    var sportIcon: some View {
        Image(systemName: c.sport == "basketball" ? "basketball.fill" : (c.sport.hasPrefix("volleyball") ? "volleyball.fill" : "soccerball"))
            .font(.system(size: 11)).foregroundStyle(C.gold)
    }

    func round(_ icon: String, _ tint: Color, _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon).font(.system(size: 18, weight: .semibold)).foregroundStyle(tint)
                .frame(width: 44, height: 44).glass(Circle(), interactive: true)
        }.buttonStyle(.plain)
    }

    func teamCol(_ logo: String, _ name: String, _ aek: Bool) -> some View {
        VStack(spacing: 8) {
            TeamLogo(url: logo, size: 66, name: name)
            Text(name.upperGr).font(F.disp(19)).foregroundStyle(aek ? C.gold : C.text).multilineTextAlignment(.center).lineLimit(2).minimumScaleFactor(0.6)
        }
        .frame(maxWidth: .infinity)
    }

    func chip(_ icon: String, _ t: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon).font(.system(size: 13)).foregroundStyle(C.gold)
            Text(t).font(F.body(12, .bold)).foregroundStyle(C.text).lineLimit(1)
        }
        .padding(.horizontal, 12).padding(.vertical, 6)
        .background(Capsule().fill(C.ink.opacity(0.5)))
        .overlay(Capsule().stroke(C.line2, lineWidth: 1))
    }
}

struct StatusPill: View {
    let c: MatchCard
    var body: some View {
        TimelineView(.periodic(from: .now, by: 15)) { ctx in
            let (txt, col): (String, Color) = {
                if c.live {
                    let mn = liveMinute(c.clock, fallback: c.minute, now: ctx.date)
                    return ("LIVE" + (!mn.isEmpty ? " · \(mn)" : (!c.phase.isEmpty ? " · " + c.phase.upperGr : "")), C.live)
                }
                if c.finished { return ("ΤΕΛΙΚΟ ΑΠΟΤΕΛΕΣΜΑ", C.text2) }
                if c.postponed { return ("ΑΝΑΒΟΛΗ", C.muted) }
                return ("ΕΠΕΡΧΟΜΕΝΟ", C.gold)
            }()
            HStack(spacing: 6) {
                if c.live { LiveDot(size: 7) }
                Text(txt).font(F.body(11, .heavy)).tracking(1).foregroundStyle(col)
            }
            .padding(.horizontal, 12).padding(.vertical, 5)
            .background(Capsule().fill(C.ink.opacity(0.6)))
            .overlay(Capsule().stroke(col.opacity(0.5), lineWidth: 1))
        }
    }
}

struct ScoreBox: View {
    let v: String
    let aek: Bool
    var body: some View {
        Text(v).font(F.disp(48)).foregroundStyle(aek ? C.gold : C.text).monospacedDigit().minimumScaleFactor(0.5)
            .frame(width: 60, height: 70)
            .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(C.panel))
            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(aek ? C.gold : C.line2, lineWidth: 1))
    }
}

/// 🤝 «Powered by» (μικρό πάνω, λογότυπο μεγάλο και ελεύθερο — ρυθμίζεται από το backend)
struct SponsorBlock: View {
    let s: Sponsor
    @Environment(\.openURL) var open
    var body: some View {
        Button { if let u = URL(string: s.click), !s.click.isEmpty { open(u) } } label: {
            VStack(spacing: 8) {
                Text(s.label).font(F.body(12, .bold)).foregroundStyle(C.muted)
                if !s.logo.isEmpty {
                    NetImage(url: s.logo, w: 600, mode: .fit).frame(width: s.w > 0 ? CGFloat(s.w) : nil, height: CGFloat(max(24, s.h)))
                } else if !s.name.isEmpty { Text(s.name).font(F.body(22, .heavy)).foregroundStyle(C.text) }
                if !s.note.isEmpty { Text(s.note).font(F.body(11)).foregroundStyle(C.muted) }
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
        .padding(.horizontal, screenPad)
        .onAppear { Api.shared.ping(s.view) }
    }
}

struct StreamCard: View {
    let s: StreamInfo
    let open: () -> Void
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                HStack(spacing: 5) {
                    if s.state == "live" { LiveDot(size: 7, color: .white) }
                    Text(s.state == "replay" ? "REPLAY" : "LIVE").font(F.body(11, .heavy)).foregroundStyle(.white)
                }
                .padding(.horizontal, 8).padding(.vertical, 3).background(RoundedRectangle(cornerRadius: 6).fill(s.state == "live" ? C.live : C.panel3))
                Text(s.label.upperGr).font(F.disp(20)).foregroundStyle(C.text).lineLimit(1).minimumScaleFactor(0.7)
            }
            Button(action: open) {
                ZStack {
                    FillImage(url: s.thumb, w: 900).aspectRatio(16 / 9, contentMode: .fit)
                    C.ink.opacity(0.35)
                    VStack(spacing: 8) {
                        PlayBadge(size: 64)
                        Text(s.state == "replay" ? "Πάτα για να δεις τον αγώνα" : "Πάτα για να δεις το live").font(F.body(13, .heavy)).foregroundStyle(.white)
                    }
                }
                .background(C.panel2)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            }.buttonStyle(.plain)
            if !s.kicker.isEmpty { Text(s.kicker).font(F.body(12)).foregroundStyle(C.muted) }
        }
        .padding(.horizontal, screenPad)
    }
}

// MARK: - Πορεία (κεντρική γραμμή: γηπεδούχοι αριστερά, φιλοξενούμενοι δεξιά)

private let GOAL: Set<String> = ["goal", "penalty_goal", "own_goal", "seven_m_score", "pen_score", "pen_so_score", "two_pointer", "three_pointer", "free_throw", "set_won"]

struct TimelineSection: View {
    let d: MatchDetail
    var body: some View {
        VStack(spacing: 0) {
            TimelineHeader(d: d)
            if d.events.isEmpty {
                Text("Η πορεία θα εμφανιστεί μόλις γραφτούν τα πρώτα γεγονότα.").font(F.body(13)).foregroundStyle(C.muted).multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity).padding(16).background(C.panel).padding(.horizontal, screenPad)
            } else if !d.groups.isEmpty {
                ForEach(Array(d.groups.enumerated()), id: \.offset) { _, g in PeriodGroup(g: g, d: d) }
            } else {
                let evs = d.card.finished ? Array(d.events.reversed()) : d.events
                ForEach(Array(evs.enumerated()), id: \.offset) { _, e in TimelineRow(e: e, d: d) }
            }
        }
    }
}

struct TimelineHeader: View {
    let d: MatchDetail
    var body: some View {
        HStack(spacing: 6) {
            HStack(spacing: 6) {
                TeamLogo(url: d.card.homeLogo, size: 20, name: d.card.home)
                Text(d.card.home.upperGr).font(F.disp(15)).foregroundStyle(d.card.aek == "home" ? C.gold : C.text).lineLimit(1).minimumScaleFactor(0.6)
                Spacer(minLength: 0)
            }
            Text("\(d.card.scoreHome.isEmpty ? "0" : d.card.scoreHome) - \(d.card.scoreAway.isEmpty ? "0" : d.card.scoreAway)").font(F.disp(20)).foregroundStyle(C.ink)
                .padding(.horizontal, 10).padding(.vertical, 2).background(RoundedRectangle(cornerRadius: 8).fill(C.gold))
            HStack(spacing: 6) {
                Spacer(minLength: 0)
                Text(d.card.away.upperGr).font(F.disp(15)).foregroundStyle(d.card.aek == "away" ? C.gold : C.text).lineLimit(1).minimumScaleFactor(0.6)
                TeamLogo(url: d.card.awayLogo, size: 20, name: d.card.away)
            }
        }
        .padding(12)
        .background(TopRounded(r: 16).fill(C.panel))
        .padding(.horizontal, screenPad)
    }
}

/// Περίοδος/σετ: κεφαλίδα με σκορ, ανοιχτή ή μαζεμένη
struct PeriodGroup: View {
    let g: EventGroup
    let d: MatchDetail
    @State private var open: Bool
    init(g: EventGroup, d: MatchDetail) { self.g = g; self.d = d; _open = State(initialValue: g.open) }
    var body: some View {
        VStack(spacing: 6) {
            Button { haptic(); withAnimation(.easeOut(duration: 0.2)) { open.toggle() } } label: {
                HStack(spacing: 10) {
                    Circle().fill(g.open ? C.live : C.gold).frame(width: 8, height: 8)
                    Text(g.label.upperGr).font(F.disp(20)).foregroundStyle(C.text)
                    if !g.score.isEmpty {
                        Text(g.score).font(F.disp(17)).foregroundStyle(C.ink).padding(.horizontal, 8).padding(.vertical, 1).background(RoundedRectangle(cornerRadius: 6).fill(C.gold))
                    }
                    Spacer()
                    Text("\(g.events.count)").font(F.body(12, .bold)).foregroundStyle(C.muted)
                    Image(systemName: open ? "chevron.up" : "chevron.down").font(.system(size: 14, weight: .bold)).foregroundStyle(C.text2)
                }
                .padding(.horizontal, 14).padding(.vertical, 11)
                .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(C.ink2))
                .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(open ? C.gold.opacity(0.45) : C.line, lineWidth: 1))
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .padding(.horizontal, screenPad)
            if open { VStack(spacing: 0) { ForEach(Array(g.events.enumerated()), id: \.offset) { TimelineRow(e: $0.element, d: d) } } }
        }
        .padding(.top, 10)
    }
}

struct TimelineRow: View {
    let e: MatchEvent
    let d: MatchDetail
    var body: some View {
        let minute = (!e.minute.isEmpty && e.minute.last!.isNumber) ? e.minute + "′" : e.minute
        ZStack {
            Rectangle().fill(C.line2).frame(width: 2)
            if e.team != "home" && e.team != "away" {
                // Ουδέτερο (έναρξη, ημίχρονο, λήξη, VAR…): στη μέση
                VStack(spacing: 1) {
                    Text((e.label.isEmpty ? e.text : e.label).upperGr).font(F.body(11, .heavy)).tracking(0.8).foregroundStyle(C.text2).multilineTextAlignment(.center)
                    if !e.label.isEmpty && !e.text.isEmpty { Text(e.text).font(F.disp(15)).foregroundStyle(C.gold).multilineTextAlignment(.center) }
                    if !minute.isEmpty { Text(minute).font(F.disp(16)).foregroundStyle(C.gold) }
                }
                .frame(minWidth: 120)
                .padding(.horizontal, 16).padding(.vertical, 8)
                .background(Capsule().fill(C.ink2)).overlay(Capsule().stroke(C.line2, lineWidth: 1))
            } else {
                let home = e.team == "home"
                let goal = GOAL.contains(e.type)
                let ours = e.team == d.card.aek && !d.card.aek.isEmpty
                HStack(spacing: 0) {
                    HStack { Spacer(minLength: 0); if home { side(goal, ours, true) } }.frame(maxWidth: .infinity)
                    Text(minute.isEmpty ? "·" : minute).font(F.disp(15)).foregroundStyle(goal ? C.ink : C.text)
                        .frame(minWidth: 28).padding(.horizontal, 8).padding(.vertical, 3)
                        .background(Capsule().fill(goal ? C.gold : C.ink))
                        .overlay(Capsule().stroke(goal ? C.gold : C.text2, lineWidth: 1.5))
                        .padding(.horizontal, 6)
                    HStack { if !home { side(goal, ours, false) }; Spacer(minLength: 0) }.frame(maxWidth: .infinity)
                }
            }
        }
        .padding(.horizontal, 10).padding(.vertical, 7)
        .background(C.panel)
        .padding(.horizontal, screenPad)
    }

    func side(_ goal: Bool, _ ours: Bool, _ home: Bool) -> some View {
        let txt = VStack(alignment: home ? .trailing : .leading, spacing: 1) {
            Text(e.label.upperGr).font(F.body(9, .heavy)).tracking(0.6).foregroundStyle(goal ? C.gold : C.muted)
            if !e.text.isEmpty { Text(e.text).font(F.body(13, goal ? .heavy : .bold)).foregroundStyle(ours && goal ? C.gold : C.text).multilineTextAlignment(home ? .trailing : .leading) }
            if !e.score.isEmpty { Text(e.score).font(F.disp(13)).foregroundStyle(C.gold) }
        }
        return HStack(spacing: 8) {
            if home { txt; EventIcon(type: e.type) } else { EventIcon(type: e.type); txt }
        }
    }
}

struct EventIcon: View {
    let type: String
    var body: some View {
        switch type {
        case "yellow", "sanction_yellow": RoundedRectangle(cornerRadius: 2).fill(C.gold).frame(width: 11, height: 15)
        case "red", "sanction_red", "second_yellow", "technical_foul", "flagrant_foul", "exclusion_perm": RoundedRectangle(cornerRadius: 2).fill(C.live).frame(width: 11, height: 15)
        case "susp_2min", "exclusion_20s", "personal_foul": RoundedRectangle(cornerRadius: 2).fill(Color(hex: 0xF08A24)).frame(width: 11, height: 15)
        case "sub": Image(systemName: "arrow.up.arrow.down").font(.system(size: 15, weight: .bold)).foregroundStyle(C.win)
        case "goal", "penalty_goal", "own_goal", "seven_m_score", "pen_score", "pen_so_score": ball("soccerball")
        case "two_pointer", "three_pointer", "free_throw": ball("basketball.fill")
        case "set_won": ball("volleyball.fill")
        case "var": Image(systemName: "tv").font(.system(size: 15)).foregroundStyle(C.text2)
        default: Image(systemName: "info.circle").font(.system(size: 15)).foregroundStyle(C.muted)
        }
    }
    func ball(_ n: String) -> some View {
        Image(systemName: n).font(.system(size: 14, weight: .bold)).foregroundStyle(C.ink).frame(width: 24, height: 24).background(Circle().fill(C.gold))
    }
}

// MARK: - Στατιστικά

struct StatsSection: View {
    let d: MatchDetail
    var body: some View {
        VStack(spacing: 14) {
            if !d.periods.isEmpty {
                SectionLabel(text: "Σκορ ανά περίοδο")
                VStack(spacing: 8) {
                    ForEach(Array(d.periods.enumerated()), id: \.offset) { _, p in
                        HStack {
                            Text(p.label).font(F.body(13)).foregroundStyle(C.text2)
                            Spacer()
                            Text(p.home).font(F.disp(18)).foregroundStyle(d.card.aek == "home" ? C.gold : C.text).frame(width: 36, alignment: .trailing)
                            Text(p.away).font(F.disp(18)).foregroundStyle(d.card.aek == "away" ? C.gold : C.text).frame(width: 36, alignment: .trailing)
                        }
                    }
                }
                .padding(12).background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(C.panel))
            }
            if !d.stats.isEmpty {
                let hc = d.card.aek == "home" ? C.gold : C.text2
                let ac = d.card.aek == "away" ? C.gold : C.text2
                VStack(spacing: 14) {
                    HStack { TeamLogo(url: d.card.homeLogo, size: 22, name: d.card.home); Spacer(); TeamLogo(url: d.card.awayLogo, size: 22, name: d.card.away) }
                    ForEach(Array(d.stats.enumerated()), id: \.offset) { _, s in
                        let h = num(s.home)
                        let a = num(s.away)
                        let tot = h + a > 0 ? h + a : 1
                        VStack(spacing: 6) {
                            HStack {
                                Text(s.home + (s.type == "pct" && !s.home.contains("%") ? "%" : "")).font(F.disp(18)).foregroundStyle(h >= a ? hc : C.text2)
                                Text(s.label).font(F.body(12, .bold)).foregroundStyle(C.text2).multilineTextAlignment(.center).frame(maxWidth: .infinity)
                                Text(s.away + (s.type == "pct" && !s.away.contains("%") ? "%" : "")).font(F.disp(18)).foregroundStyle(a >= h ? ac : C.text2)
                            }
                            HStack(spacing: 4) {
                                bar(CGFloat(h / tot), hc, trailing: true)
                                bar(CGFloat(a / tot), ac, trailing: false)
                            }.frame(height: 6)
                        }
                    }
                }
                .padding(14).background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(C.panel))
            }
        }
        .padding(.horizontal, screenPad)
    }
    func bar(_ f: CGFloat, _ c: Color, trailing: Bool) -> some View {
        GeometryReader { g in
            ZStack(alignment: trailing ? .trailing : .leading) {
                RoundedRectangle(cornerRadius: 3).fill(C.panel3)
                RoundedRectangle(cornerRadius: 3).fill(c).frame(width: g.size.width * max(0, min(1, f)))
            }
        }
    }
    func num(_ s: String) -> Double {
        Double((s.components(separatedBy: "/").first ?? s).replacingOccurrences(of: "%", with: "").replacingOccurrences(of: ",", with: ".").trimmingCharacters(in: .whitespaces)) ?? 0
    }
}

// MARK: - Συνθέσεις: γήπεδο + λίστες

func ratingColor(_ r: Double) -> Color {
    r >= 8 ? Color(hex: 0x3D9BFF) : r >= 7 ? Color(hex: 0x22C38E) : r >= 6 ? Color(hex: 0xF2C230) : Color(hex: 0xF0703A)
}

struct RatingBadge: View {
    let r: Double
    var big = false
    var best = false
    var body: some View {
        Text(String(format: "%.1f", r)).font(F.body(big ? 18 : 12, .heavy)).foregroundStyle(best ? C.ink : ratingColor(r))
            .padding(.horizontal, big ? 12 : 8).padding(.vertical, big ? 5 : 2)
            .background(Capsule().fill(best ? C.gold : C.ink))
            .overlay(Capsule().stroke(best ? C.gold : ratingColor(r), lineWidth: 1.5))
    }
}

struct LineupsSection: View {
    let d: MatchDetail
    @Environment(\.horizontalSizeClass) var hsc
    var body: some View {
        VStack(spacing: 14) {
            if let p = d.pitch, !p.home.isEmpty || !p.away.isEmpty { PitchView(d: d, p: p) }
            // Δύο στήλες δίπλα-δίπλα (όπως στο Android)· σε πολύ στενή οθόνη η μία κάτω από την άλλη
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .top, spacing: 12) { lists }
                VStack(spacing: 12) { lists }
            }
            if !d.referee.isEmpty { Text("Διαιτητής: " + d.referee).font(F.body(13)).foregroundStyle(C.muted).frame(maxWidth: .infinity, alignment: .leading) }
        }
        .padding(.horizontal, screenPad)
    }
    @ViewBuilder var lists: some View {
        TeamList(name: d.card.home, logo: d.card.homeLogo, xi: d.lineupHome, subs: d.subsHome, coach: d.coachHome, aek: d.card.aek == "home")
        TeamList(name: d.card.away, logo: d.card.awayLogo, xi: d.lineupAway, subs: d.subsAway, coach: d.coachAway, aek: d.card.aek == "away")
    }
}

struct TeamList: View {
    let name, logo: String
    let xi, subs: [Player]
    let coach: String
    let aek: Bool
    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(spacing: 6) {
                TeamLogo(url: logo, size: 20, name: name)
                Text(name.upperGr).font(F.disp(17)).foregroundStyle(aek ? C.gold : C.text).lineLimit(1).minimumScaleFactor(0.6)
            }
            Rectangle().fill(aek ? C.gold : C.line2).frame(height: 2)
            ForEach(xi, id: \.self) { line($0) }
            if !subs.isEmpty { SectionLabel(text: "Αναπληρωματικοί").padding(.top, 4); ForEach(subs, id: \.self) { line($0) } }
            if !coach.isEmpty { Text("Προπ.: \(coach)").font(F.body(12)).foregroundStyle(C.muted).padding(.top, 4) }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(C.panel))
    }
    func line(_ p: Player) -> some View {
        HStack(spacing: 8) {
            Text(p.number).font(F.disp(16)).foregroundStyle(aek ? C.gold : C.muted).frame(width: 22, alignment: .leading)
            Text(p.name + (p.captain ? " (Κ)" : "")).font(F.body(13, .bold)).foregroundStyle(C.text).lineLimit(1).minimumScaleFactor(0.8)
            if p.rating > 0 { RatingBadge(r: p.rating) }
            Spacer(minLength: 0)
        }
    }
}

/// Γηπεδάκι (γηπεδούχοι πάνω, φιλοξενούμενοι κάτω), έως 520 πλάτος
struct PitchView: View {
    let d: MatchDetail
    let p: Pitch
    var body: some View {
        let top = (p.home + p.away).map(\.rating).max() ?? 0
        GeometryReader { g in
            let w = g.size.width, h = g.size.height
            ZStack(alignment: .topLeading) {
                Color.clear.overlay(Image("PitchBg").resizable().scaledToFill()).clipped()
                ForEach(Array(p.home.enumerated()), id: \.offset) { _, pl in
                    dot(pl, home: true, best: d.card.finished && pl.rating > 0 && pl.rating >= top)
                        .position(x: w * CGFloat((100 - pl.x) / 100), y: h * CGFloat(pl.y / 100 * 0.5 * 0.92 + 0.03) + 12)
                }
                ForEach(Array(p.away.enumerated()), id: \.offset) { _, pl in
                    dot(pl, home: false, best: d.card.finished && pl.rating > 0 && pl.rating >= top)
                        .position(x: w * CGFloat(pl.x / 100), y: h - h * CGFloat(pl.y / 100 * 0.5 * 0.92 + 0.03) + 12)
                }
                if !p.formationHome.isEmpty { Text(p.formationHome).font(F.body(11, .heavy)).foregroundStyle(.white.opacity(0.85)).padding(8).frame(maxWidth: .infinity, alignment: .topTrailing) }
                if !p.formationAway.isEmpty { Text(p.formationAway).font(F.body(11, .heavy)).foregroundStyle(.white.opacity(0.85)).padding(8).frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing) }
            }
        }
        .aspectRatio(500.0 / 770.0, contentMode: .fit)
        .frame(maxWidth: 520)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    func dot(_ pl: PitchPlayer, home: Bool, best: Bool) -> some View {
        let bg = Color(hexString: home ? d.card.homeColor : d.card.awayColor) ?? (home ? C.text2 : C.gold)
        let fg = Color(hexString: home ? d.card.homeNum : d.card.awayNum) ?? C.ink
        let last = pl.name.split(separator: " ").last.map(String.init) ?? pl.name
        return VStack(spacing: 0) {
            ZStack {
                Circle().fill(bg).frame(width: 36, height: 36)
                    .overlay(Circle().stroke(best ? C.gold : .white.opacity(0.85), lineWidth: 2))
                    .shadow(color: best ? C.gold : .clear, radius: 8)
                Text(pl.number).font(F.disp(17)).foregroundStyle(fg)
                if pl.goals > 0 {
                    Image(systemName: "soccerball").font(.system(size: 12)).foregroundStyle(C.ink).frame(width: 16, height: 16).background(Circle().fill(.white)).offset(x: 16, y: -14)
                }
                if pl.red || pl.yellow { RoundedRectangle(cornerRadius: 1).fill(pl.red ? C.live : C.gold).frame(width: 10, height: 14).offset(x: -17, y: -12) }
                if !pl.out.isEmpty {
                    Text("↓" + pl.out).font(F.body(10, .heavy)).foregroundStyle(.white).lineLimit(1)
                        .padding(.horizontal, 4).padding(.vertical, 1).background(RoundedRectangle(cornerRadius: 6).fill(C.loss)).fixedSize().offset(x: 24, y: 14)
                }
            }
            if pl.rating > 0 { RatingBadge(r: pl.rating, best: best).scaleEffect(0.9).offset(y: -6) }
            Text(last).font(F.body(11, .heavy)).foregroundStyle(.white).lineLimit(2).multilineTextAlignment(.center)
                .padding(.horizontal, 4).background(RoundedRectangle(cornerRadius: 4).fill(.black.opacity(0.45)))
                .frame(maxWidth: 84).offset(y: pl.rating > 0 ? -4 : 2)
        }
        .frame(width: 84)
    }
}

// MARK: - Παίκτες (βαθμολογία / διακριθέντες & box score)

struct PlayersSection: View {
    let d: MatchDetail
    let x: MatchExtra
    var colH: Color { Color(hexString: x.colorHome) ?? C.gold }
    var colA: Color { Color(hexString: x.colorAway) ?? C.text2 }
    var body: some View {
        VStack(spacing: 18) {
            if x.hasRatings {
                RatingsPanel(title: "Βαθμολογία παικτών", logo: d.card.homeLogo, name: d.card.home, col: colH, rows: x.ratingsHome, potm: x.potm, side: "home")
                RatingsPanel(title: "", logo: d.card.awayLogo, name: d.card.away, col: colA, rows: x.ratingsAway, potm: x.potm, side: "away")
            }
            if x.hasBox {
                BoxPanel(title: "Διακριθέντες", src: x.boxSrc, logo: d.card.homeLogo, name: d.card.home, col: colH, rows: x.boxHome)
                BoxPanel(title: "", src: x.boxSrc, logo: d.card.awayLogo, name: d.card.away, col: colA, rows: x.boxAway)
            }
        }
        .padding(.horizontal, screenPad)
    }
}

struct DashLine: View {
    var body: some View { Line().stroke(C.line2, style: StrokeStyle(lineWidth: 1, dash: [7, 4.5])).frame(height: 1) }
}
struct Line: Shape {
    func path(in r: CGRect) -> Path { var p = Path(); p.move(to: CGPoint(x: 0, y: r.midY)); p.addLine(to: CGPoint(x: r.maxX, y: r.midY)); return p }
}

/// Τίτλος + πάνελ με σκούρα κεφαλίδα ομάδας (όπως Συνθέσεις/Πορεία)
struct AxPanel<Content: View>: View {
    let title: String
    let logo: String
    let name: String
    let col: Color
    var tag = ""
    @ViewBuilder let content: () -> Content
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if !title.isEmpty { HStack(spacing: 10) { SectionTitle(text: title).fixedSize(); DashLine() } }
            VStack(spacing: 0) {
                HStack(spacing: 8) {
                    Circle().fill(col).frame(width: 10, height: 10)
                    TeamLogo(url: logo, size: 26, name: name)
                    Text(name.upperGr).font(F.disp(18)).foregroundStyle(C.text).lineLimit(1)
                    Spacer()
                }
                .padding(.horizontal, 16).padding(.vertical, 12).background(C.ink2)
                Rectangle().fill(C.line).frame(height: 1)
                VStack(spacing: 12) {
                    content()
                    if !tag.isEmpty { Text("Δεδομένα: \(tag)").font(F.body(10)).foregroundStyle(C.muted).frame(maxWidth: .infinity, alignment: .trailing) }
                }.padding(.horizontal, 16).padding(.vertical, 14)
            }
            .background(C.panel)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(C.line, lineWidth: 1))
        }
    }
}

struct RatingsPanel: View {
    let title, logo, name: String
    let col: Color
    let rows: [RatingRow]
    let potm: Potm?
    let side: String
    @State private var all = false
    var body: some View {
        let l = rows.filter { !$0.name.isEmpty }
        if !l.isEmpty {
            AxPanel(title: title, logo: logo, name: name, col: col) {
                VStack(spacing: 0) {
                    let shown = all ? l : Array(l.prefix(5))
                    ForEach(Array(shown.enumerated()), id: \.offset) { i, r in
                        let best = potm != nil && potm!.side == side && potm!.number == r.number
                        HStack(spacing: 10) {
                            Text("\(i + 1)").font(F.disp(19)).foregroundStyle(C.gold).frame(width: 24)
                            VStack(alignment: .leading, spacing: 0) {
                                HStack(spacing: 6) {
                                    Text(r.name).font(F.body(14, best ? .heavy : .bold)).foregroundStyle(best ? C.text : C.text2).lineLimit(1)
                                    if !r.number.isEmpty { Text("#\(r.number)").font(F.body(11, .bold)).foregroundStyle(C.muted) }
                                }
                                if best { Text("ΠΑΙΚΤΗΣ ΑΓΩΝΑ").font(F.body(9, .heavy)).foregroundStyle(C.gold) }
                            }
                            Spacer(minLength: 0)
                            RatingBadge(r: r.rating, best: best)
                        }
                        .padding(.vertical, 9)
                        .background(best ? C.gold.opacity(0.10) : .clear)
                        if i < shown.count - 1 { DashLine() }
                    }
                    if l.count > 5 {
                        Button(all ? "Λιγότεροι" : "Όλοι οι παίκτες (\(l.count))") { withAnimation { all.toggle() } }
                            .font(F.body(12, .heavy)).foregroundStyle(C.muted).padding(.top, 10)
                    }
                }
            }
        }
    }
}

struct BoxPanel: View {
    let title, src, logo, name: String
    let col: Color
    let rows: [BoxRow]
    var srcName: String { ["fm": "FotMob", "fs": "Flashscore", "ss": "Sofascore", "as": "API-Sports", "db": "AEK Hub"][src] ?? "" }
    var body: some View {
        if !rows.isEmpty {
            AxPanel(title: title, logo: logo, name: name, col: col, tag: srcName) {
                HStack(spacing: 8) {
                    ForEach(Array(rows.sorted { $0.pts > $1.pts }.prefix(3).enumerated()), id: \.offset) { i, r in
                        VStack(spacing: 2) {
                            Text("\(r.pts)").font(F.disp(36)).foregroundStyle(i == 0 ? C.gold : C.text)
                            Text(r.name).font(F.body(12, .bold)).foregroundStyle(C.text).lineLimit(1)
                            Text("\(r.reb) ριμπ. · \(r.ast) ασίστ").font(F.body(10)).foregroundStyle(C.muted).multilineTextAlignment(.center).lineLimit(2)
                        }
                        .frame(maxWidth: .infinity).padding(.vertical, 10).padding(.horizontal, 4)
                        .background(RoundedRectangle(cornerRadius: 10).fill(i == 0 ? C.gold.opacity(0.12) : C.ink2))
                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(i == 0 ? C.gold.opacity(0.35) : C.line, lineWidth: 1))
                    }
                }
                VStack(spacing: 0) {
                    HStack {
                        Text("ΠΑΙΚΤΗΣ").frame(maxWidth: .infinity, alignment: .leading)
                        ForEach(["ΛΕΠ", "ΠΟΝ", "ΡΙΜ", "ΑΣ"], id: \.self) { Text($0).frame(width: 36, alignment: .trailing) }
                    }
                    .font(F.body(10, .heavy)).foregroundStyle(C.muted).padding(.horizontal, 10).padding(.vertical, 8).background(C.ink2)
                    let mp = rows.map(\.pts).max() ?? 0, mr = rows.map(\.reb).max() ?? 0, ma = rows.map(\.ast).max() ?? 0
                    ForEach(Array(rows.enumerated()), id: \.offset) { _, r in
                        DashLine()
                        HStack {
                            Text(r.number).font(F.disp(16)).foregroundStyle(C.gold).frame(width: 26, alignment: .leading)
                            Text(r.name).font(F.body(13, r.starter ? .heavy : .medium)).foregroundStyle(C.text).lineLimit(1).frame(maxWidth: .infinity, alignment: .leading)
                            Text("\(r.min)′").font(F.body(13)).foregroundStyle(C.muted).frame(width: 36, alignment: .trailing)
                            Text("\(r.pts)").font(F.body(13, r.pts == mp ? .heavy : .medium)).foregroundStyle(r.pts == mp ? C.gold : C.text).frame(width: 36, alignment: .trailing)
                            Text("\(r.reb)").font(F.body(13, r.reb == mr ? .heavy : .medium)).foregroundStyle(r.reb == mr ? C.gold : C.text).frame(width: 36, alignment: .trailing)
                            Text("\(r.ast)").font(F.body(13, r.ast == ma ? .heavy : .medium)).foregroundStyle(r.ast == ma ? C.gold : C.text).frame(width: 36, alignment: .trailing)
                        }
                        .monospacedDigit()
                        .padding(.horizontal, 10).padding(.vertical, 8)
                    }
                }
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(C.line, lineWidth: 1))
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }
        }
    }
}

/// Στρογγυλεμένο μόνο πάνω
struct TopRounded: Shape {
    var r: CGFloat
    func path(in rect: CGRect) -> Path {
        Path(UIBezierPath(roundedRect: rect, byRoundingCorners: [.topLeft, .topRight], cornerRadii: CGSize(width: r, height: r)).cgPath)
    }
}
