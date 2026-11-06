import SwiftUI

/// Στήλες: 1 στο iPhone, περισσότερες στο iPad
let adaptiveCols = [GridItem(.adaptive(minimum: 340), spacing: 14, alignment: .top)]
let screenPad: CGFloat = 20

// MARK: - Τίτλοι

/// Μεγάλος τίτλος οθόνης («ΑΓΩΝΕΣ», «ΒΑΘΜΟΛΟΓΙΕΣ», «ΕΓΩ»)
struct ScreenTitle: View {
    let text: String
    var body: some View {
        Text(text.upperGr).font(F.disp(40)).foregroundStyle(C.text).frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, screenPad).padding(.top, 8)
    }
}

/// Κίτρινη κεκλιμένη ετικέτα + διακεκομμένη γραμμή + «Όλα ›» (όπως στο Android)
struct GoldHeader: View {
    let title: String
    var action: String? = nil
    var route: Route? = nil
    var body: some View {
        HStack(spacing: 10) {
            Text(title.upperGr).font(F.disp(19)).foregroundStyle(C.ink)
                .padding(.leading, 10).padding(.trailing, 16).padding(.vertical, 4)
                .background(SlantShape(k: 9).fill(C.gold).padding(.leading, -9))
                .padding(.leading, 9)
            Line().stroke(C.line2, style: StrokeStyle(lineWidth: 1, dash: [3, 4])).frame(height: 1)
            if let action, let route {
                NavigationLink(value: route) {
                    Text(action + " ›").font(F.body(14, .semibold)).foregroundStyle(C.gold).lineLimit(1)
                }
            }
        }
        .padding(.horizontal, screenPad).padding(.top, 22).padding(.bottom, 10)
    }
}

struct Line: Shape {
    func path(in r: CGRect) -> Path { var p = Path(); p.move(to: CGPoint(x: 0, y: r.midY)); p.addLine(to: CGPoint(x: r.maxX, y: r.midY)); return p }
}

struct SectionLabel: View {
    let text: String
    var body: some View {
        Text(text.upperGr).font(F.tag(12)).tracking(1.2).foregroundStyle(C.muted)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// Κίτρινη ετικέτα κατηγορίας (π.χ. «ΕΡΑΣΙΤΕΧΝΙΚΗ»)
struct Tag: View {
    let text: String
    var body: some View {
        Text(text.upperGr).font(F.tag(11)).tracking(0.9).foregroundStyle(C.ink)
            .padding(.horizontal, 10).padding(.vertical, 5)
            .background(Capsule().fill(C.gold))
    }
}

// MARK: - Κουμπιά γυαλιού

struct GlassCircle: View {
    let icon: String
    var size: CGFloat = 44
    var gold = false
    var action: () -> Void
    var body: some View {
        Button(action: action) {
            Image(systemName: icon).font(.system(size: size * 0.4, weight: .semibold))
                .foregroundStyle(gold ? C.ink : C.text)
                .frame(width: size, height: size)
                .background(gold ? AnyView(Circle().fill(C.goldGrad)) : AnyView(Color.clear))
                .glass(Circle(), tint: gold ? C.gold : nil, interactive: true)
        }.buttonStyle(.plain)
    }
}

/// Γυάλινο «dropdown» με μικρή ετικέτα πάνω (ΑΘΛΗΜΑ / ΔΙΟΡΓΑΝΩΣΗ)
struct GlassPicker: View {
    let label: String
    let value: String
    let options: [(String, String)]
    let pick: (String) -> Void
    var body: some View {
        Menu {
            ForEach(options, id: \.0) { o in Button(o.1) { pick(o.0) } }
        } label: {
            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 1) {
                    Text(label.upperGr).font(F.tag(10)).tracking(1).foregroundStyle(C.muted)
                    Text(value).font(F.body(15, .semibold)).foregroundStyle(C.text).lineLimit(2).multilineTextAlignment(.leading)
                }
                Spacer(minLength: 4)
                Image(systemName: "chevron.down").font(.system(size: 13, weight: .bold)).foregroundStyle(C.gold)
            }
            .padding(.horizontal, 18).padding(.vertical, 11)
            .frame(minHeight: 52)
            .glass(Capsule())
        }
    }
}

/// Τσιπάκια: «Όλα» κίτρινο, τα άλλα με κίτρινη τελεία
struct ChipRow: View {
    let items: [(String, String)]
    let selected: String
    var dots = true
    let pick: (String) -> Void
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(items, id: \.0) { it in
                    let on = it.0 == selected
                    Button { pick(it.0) } label: {
                        HStack(spacing: 7) {
                            if dots && !it.0.isEmpty && !on { Circle().fill(C.gold).frame(width: 7, height: 7) }
                            Text(it.1).font(F.body(15, .semibold)).foregroundStyle(on ? C.ink : C.text)
                        }
                        .padding(.horizontal, 18).frame(height: 42)
                        .background(on ? AnyView(Capsule().fill(C.goldGrad).shadow(color: C.gold.opacity(0.35), radius: 10)) : AnyView(Capsule().fill(C.panel)))
                        .overlay(Capsule().stroke(on ? Color.clear : C.line, lineWidth: 1))
                    }.buttonStyle(.plain)
                }
            }.padding(.horizontal, screenPad)
        }
    }
}

struct VideoBadge: View {
    var body: some View {
        Image(systemName: "play.fill").font(.system(size: 13, weight: .bold)).foregroundStyle(C.ink)
            .frame(width: 34, height: 34).background(Circle().fill(C.gold))
    }
}

// MARK: - Άρθρα

/// Μεγάλη κάρτα κύριου θέματος (ακτίνα 28)
struct PostHero: View {
    let p: PostCard
    var height: CGFloat = 330
    var body: some View {
        NavigationLink(value: Route.post(p.id, p)) {
            ZStack(alignment: .bottomLeading) {
                NetImage(url: p.image, w: 1200).frame(maxWidth: .infinity).frame(height: height).clipped()
                LinearGradient(colors: [.clear, .black.opacity(0.35), .black.opacity(0.92)], startPoint: .top, endPoint: .bottom)
                VStack(alignment: .leading, spacing: 10) {
                    if !p.category.isEmpty { Tag(text: p.category) }
                    Text(p.title.upperGr).font(F.disp(30)).foregroundStyle(.white).multilineTextAlignment(.leading).lineLimit(4).minimumScaleFactor(0.8)
                    Text(Fmt.postDate(p.date)).font(F.body(13)).foregroundStyle(C.text2)
                }.padding(20)
                if p.video { VideoBadge().padding(16).frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing) }
            }
            .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 28, style: .continuous).stroke(C.line, lineWidth: 1))
            .padding(.horizontal, screenPad)
        }.buttonStyle(.plain)
    }
}

/// Γραμμή άρθρου (εικόνα αριστερά, κατηγορία κίτρινη, τίτλος, ημερομηνία)
struct PostRow: View {
    let p: PostCard
    var body: some View {
        NavigationLink(value: Route.post(p.id, p)) {
            HStack(alignment: .top, spacing: 14) {
                ZStack {
                    if p.image.isEmpty { RoundedRectangle(cornerRadius: 16).fill(C.panel2).overlay(Image("HubLogo").resizable().scaledToFit().frame(width: 44).opacity(0.9)) }
                    else { NetImage(url: p.image, w: 400) }
                    if p.video { VideoBadge().scaleEffect(0.8) }
                }
                .frame(width: 112, height: 88).clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                VStack(alignment: .leading, spacing: 5) {
                    if !p.category.isEmpty { Text(p.category.upperGr).font(F.tag(11)).tracking(0.9).foregroundStyle(C.gold).lineLimit(1) }
                    Text(p.title).font(F.body(17, .semibold)).foregroundStyle(C.text).lineLimit(3).multilineTextAlignment(.leading)
                    Text(Fmt.postDate(p.date, withYear: false)).font(F.body(13)).foregroundStyle(C.muted)
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, screenPad).padding(.vertical, 9)
            .contentShape(Rectangle())
        }.buttonStyle(.plain)
    }
}

/// Πλακίδιο άρθρου για οριζόντιες λίστες
struct PostTile: View {
    let p: PostCard
    var width: CGFloat = 250
    var body: some View {
        NavigationLink(value: Route.post(p.id, p)) {
            VStack(alignment: .leading, spacing: 8) {
                ZStack {
                    NetImage(url: p.image, w: 600).frame(width: width, height: width * 0.6).clipped()
                    if p.video { VideoBadge() }
                }.clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                Text(p.title).font(F.body(15, .semibold)).foregroundStyle(C.text).lineLimit(3).multilineTextAlignment(.leading)
                    .frame(width: width, alignment: .leading)
                Text(Fmt.postDate(p.date, withYear: false)).font(F.body(12)).foregroundStyle(C.muted)
            }
        }.buttonStyle(.plain)
    }
}

// MARK: - Αγώνες

/// Κατάσταση αγώνα (live λεπτό / ΤΕΛΙΚΟ / ώρα)
func liveText(_ m: MatchCard, _ now: Date = Date()) -> String {
    let mn = liveMinute(m.clock, fallback: m.minute, now: now)
    if !mn.isEmpty { return mn }
    if !m.phase.isEmpty { return m.phase }
    return m.statusLabel.isEmpty ? "LIVE" : m.statusLabel
}

struct LiveBadge: View {
    let m: MatchCard
    var size: CGFloat = 13
    var body: some View {
        TimelineView(.periodic(from: .now, by: 15)) { ctx in
            HStack(spacing: 6) {
                LiveDot(size: size * 0.6)
                Text("LIVE · " + liveText(m, ctx.date)).font(.system(size: size, weight: .heavy)).foregroundStyle(C.live).lineLimit(1)
            }
        }
    }
}

/// Όνομα ομάδας: κεφαλαία, στενά· η ΑΕΚ κίτρινη
struct TeamName: View {
    let name: String
    let aek: Bool
    var size: CGFloat = 17
    var body: some View {
        Text(name.upperGr).font(F.disp(size)).foregroundStyle(aek ? C.gold : C.text)
            .multilineTextAlignment(.center).lineLimit(2).minimumScaleFactor(0.7)
    }
}

/// Μεγάλη κάρτα αγώνα (οθόνη Αγώνες): διοργάνωση + 🔔 · λογότυπα & ονόματα · VS + ώρα ή σκορ · κανάλι · γήπεδο
struct MatchCardBig: View {
    let m: MatchCard
    @EnvironmentObject var prefs: Prefs
    var body: some View {
        NavigationLink(value: Route.match(m.id)) {
            VStack(spacing: 12) {
                HStack(spacing: 8) {
                    Text(([m.sportLabel.isEmpty ? Sports.label(m.sport) : m.sportLabel, m.competition].filter { !$0.isEmpty }.joined(separator: " · ")).upperGr)
                        .font(F.tag(11)).tracking(0.8).foregroundStyle(C.gold).lineLimit(1)
                    Spacer()
                    if m.live { LiveBadge(m: m, size: 12) }
                    else if !m.finished {
                        Button {
                            if prefs.matchAlerts.contains(m.id) { prefs.matchAlerts.remove(m.id) }
                            else { prefs.matchAlerts.insert(m.id); Task { _ = await Notifier.shared.requestPermission(); await Notifier.shared.refresh(force: true) } }
                        } label: {
                            Image(systemName: prefs.matchAlerts.contains(m.id) || prefs.wants(m.sport, Kinds.reminder) ? "bell.fill" : "bell")
                                .font(.system(size: 16)).foregroundStyle(prefs.matchAlerts.contains(m.id) ? C.gold : C.muted)
                        }.buttonStyle(.plain)
                    }
                }
                HStack(alignment: .center, spacing: 6) {
                    side(m.home, m.homeLogo, m.aek == "home")
                    VStack(spacing: 2) {
                        if m.upcoming && !m.hasScore {
                            Text("VS").font(F.body(12, .bold)).foregroundStyle(C.muted)
                            Text(m.time.isEmpty ? "–" : m.time).font(F.disp(40)).foregroundStyle(C.gold).monospacedDigit()
                        } else {
                            HStack(spacing: 8) {
                                Text(m.scoreHome).foregroundStyle(scoreColor(home: true))
                                Text("–").foregroundStyle(C.muted)
                                Text(m.scoreAway).foregroundStyle(scoreColor(home: false))
                            }.font(F.disp(44)).monospacedDigit()
                            if m.finished { Text(m.penHome.isEmpty ? "ΤΕΛΙΚΟ" : "ΠΕΝ. \(m.penHome)–\(m.penAway)").font(F.tag(10)).tracking(1).foregroundStyle(C.muted) }
                            else if m.postponed { Text("ΑΝΑΒΟΛΗ").font(F.tag(10)).foregroundStyle(C.muted) }
                        }
                    }.frame(minWidth: 110)
                    side(m.away, m.awayLogo, m.aek == "away")
                }
                let foot = [m.broadcast, m.venue].filter { !$0.isEmpty }
                if !foot.isEmpty {
                    Text(foot.joined(separator: "  ·  ")).font(F.body(13)).foregroundStyle(C.muted).lineLimit(1)
                }
            }
            .padding(.horizontal, 18).padding(.vertical, 16)
            .background(RoundedRectangle(cornerRadius: 28, style: .continuous).fill(m.live ? C.panel2 : C.panel))
            .overlay(RoundedRectangle(cornerRadius: 28, style: .continuous).stroke(m.live ? C.live.opacity(0.55) : C.line, lineWidth: 1))
            .contentShape(Rectangle())
        }.buttonStyle(.plain)
    }
    func scoreColor(home: Bool) -> Color {
        if m.live { return (home ? m.aek == "home" : m.aek == "away") ? C.gold : C.text }
        guard m.finished, let h = Int(m.scoreHome), let a = Int(m.scoreAway) else { return C.text }
        let mine = home ? h : a, their = home ? a : h
        return mine >= their ? C.text : C.text.opacity(0.55)
    }
    func side(_ name: String, _ logo: String, _ aek: Bool) -> some View {
        VStack(spacing: 8) {
            TeamLogo(url: logo, size: 54, name: name)
            TeamName(name: name, aek: aek, size: 16)
        }.frame(maxWidth: .infinity)
    }
}

/// Μικρή κάρτα αγώνα για οριζόντια λίστα (αρχική)
struct MatchMini: View {
    let m: MatchCard
    var body: some View {
        NavigationLink(value: Route.match(m.id)) {
            VStack(spacing: 10) {
                HStack {
                    Text((m.sportLabel.isEmpty ? Sports.label(m.sport) : m.sportLabel).upperGr).font(F.tag(10)).tracking(0.8).foregroundStyle(C.gold).lineLimit(1)
                    Spacer()
                    if m.live { LiveBadge(m: m, size: 10) } else { Text(Fmt.shortDay(m.date)).font(F.body(11, .semibold)).foregroundStyle(C.muted) }
                }
                HStack {
                    TeamLogo(url: m.homeLogo, size: 38, name: m.home)
                    Spacer()
                    if m.upcoming && !m.hasScore { Text(m.time).font(F.disp(30)).foregroundStyle(C.gold) }
                    else { Text("\(m.scoreHome)–\(m.scoreAway)").font(F.disp(32)).foregroundStyle(m.live ? C.gold : C.text).monospacedDigit() }
                    Spacer()
                    TeamLogo(url: m.awayLogo, size: 38, name: m.away)
                }
                Text("\(m.home) – \(m.away)").font(F.body(12, .semibold)).foregroundStyle(C.text2).lineLimit(1)
            }
            .padding(14).frame(width: 240)
            .card(24, fill: m.live ? C.panel2 : C.panel)
        }.buttonStyle(.plain)
    }
}

/// ⏱ Επόμενος αγώνας με αντίστροφη μέτρηση (ίδιος αγώνας με τη μπάρα του site) ή live σκορ
struct CountdownCard: View {
    let m: MatchCard
    var body: some View {
        NavigationLink(value: Route.match(m.id)) {
            VStack(spacing: 14) {
                HStack {
                    if m.live { LiveBadge(m: m, size: 12) }
                    else { Text("ΕΠΟΜΕΝΟΣ ΑΓΩΝΑΣ").font(F.tag(11)).tracking(1).foregroundStyle(C.gold) }
                    Spacer()
                    Text(m.competition.upperGr).font(F.tag(10)).tracking(0.6).foregroundStyle(C.muted).lineLimit(1)
                }
                HStack(alignment: .center) {
                    side(m.home, m.homeLogo, m.aek == "home")
                    VStack(spacing: 2) {
                        if m.live || m.hasScore {
                            Text("\(m.scoreHome)–\(m.scoreAway)").font(F.disp(52)).foregroundStyle(C.gold).monospacedDigit()
                        } else {
                            Text("VS").font(F.body(12, .bold)).foregroundStyle(C.muted)
                            Text(m.time).font(F.disp(40)).foregroundStyle(C.gold)
                            Text(Fmt.shortDay(m.date)).font(F.body(12, .semibold)).foregroundStyle(C.text2)
                        }
                    }.frame(minWidth: 110)
                    side(m.away, m.awayLogo, m.aek == "away")
                }
                if !m.live, let ko = m.kickoffDate, ko > Date() {
                    TimelineView(.periodic(from: .now, by: 1)) { ctx in
                        let s = max(0, Int(ko.timeIntervalSince(ctx.date)))
                        HStack(spacing: 8) {
                            box(s / 86400, "ΜΕΡΕΣ"); box(s % 86400 / 3600, "ΩΡΕΣ"); box(s % 3600 / 60, "ΛΕΠΤΑ"); box(s % 60, "ΔΕΥΤ")
                        }
                    }
                }
            }
            .padding(18)
            .background(
                ZStack {
                    Image("HeroBg").resizable().scaledToFill().opacity(0.3)
                    LinearGradient(colors: [C.panel.opacity(0.3), C.ink.opacity(0.95)], startPoint: .top, endPoint: .bottom)
                }
            )
            .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 28, style: .continuous).stroke(m.live ? C.live.opacity(0.55) : C.gold.opacity(0.3), lineWidth: 1))
            .padding(.horizontal, screenPad)
        }.buttonStyle(.plain)
    }
    func side(_ name: String, _ logo: String, _ aek: Bool) -> some View {
        VStack(spacing: 8) {
            TeamLogo(url: logo, size: 58, name: name)
            TeamName(name: name, aek: aek, size: 17)
        }.frame(maxWidth: .infinity)
    }
    func box(_ v: Int, _ l: String) -> some View {
        VStack(spacing: 1) {
            Text(String(format: "%02d", v)).font(F.disp(28)).foregroundStyle(C.text).monospacedDigit()
            Text(l).font(F.tag(9)).tracking(0.8).foregroundStyle(C.muted)
        }.frame(maxWidth: .infinity).frame(height: 56).card(16, fill: C.panel2)
    }
}

struct EmptyState: View {
    let icon: String
    let text: String
    var retry: (() -> Void)? = nil
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: icon).font(.system(size: 34)).foregroundStyle(C.muted)
            Text(text).font(F.body(15, .medium)).foregroundStyle(C.text2).multilineTextAlignment(.center)
            if let retry {
                Button(action: retry) {
                    Text("Ξαναδοκίμασε").font(F.body(15, .bold)).foregroundStyle(C.ink).padding(.horizontal, 22).padding(.vertical, 12).background(Capsule().fill(C.goldGrad))
                }.buttonStyle(.plain)
            }
        }.padding(40).frame(maxWidth: .infinity)
    }
}

/// Το λογότυπο aek·hub
struct LogoTitle: View {
    var h: CGFloat = 34
    var body: some View { Image("Logo").resizable().scaledToFit().frame(height: h) }
}

/// Κίτρινος διακόπτης
struct GoldToggle: ToggleStyle {
    func makeBody(configuration c: Configuration) -> some View {
        HStack {
            c.label
            Spacer(minLength: 12)
            Capsule().fill(c.isOn ? AnyShapeStyle(C.goldGrad) : AnyShapeStyle(C.panel3)).frame(width: 52, height: 32)
                .overlay(Circle().fill(.white).padding(3).shadow(color: .black.opacity(0.25), radius: 2, y: 1)
                    .offset(x: c.isOn ? 10 : -10))
                .animation(.spring(response: 0.25, dampingFraction: 0.8), value: c.isOn)
                .onTapGesture { c.isOn.toggle() }
        }
        .contentShape(Rectangle())
    }
}
