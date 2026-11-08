import SwiftUI

// Τα κοινά κομμάτια — ΠΙΣΤΗ ΑΝΤΙΓΡΑΦΗ του Android (ui/components: Cards.kt, MatchUi.kt, Countdown.kt, Social.kt, Common.kt)

let adaptiveCols = [GridItem(.adaptive(minimum: 320), spacing: 24, alignment: .top)]
let screenPad: CGFloat = 16

/// Πλάτος περιεχομένου σε iPad (όπως το sidePad του Android): κεντραρισμένο, όχι απλωμένο σε όλη την οθόνη
extension View {
    func readable(_ max: CGFloat = 760) -> some View { frame(maxWidth: max).frame(maxWidth: .infinity) }
}

func haptic(_ s: UIImpactFeedbackGenerator.FeedbackStyle = .light) { UIImpactFeedbackGenerator(style: s).impactOccurred() }

// MARK: - Τίτλοι

/// «ΑΓΩΝΕΣ», «ΒΑΘΜΟΛΟΓΙΕΣ» (disp 32)
struct ScreenTitle: View {
    let text: String
    var body: some View {
        Text(text.upperGr).font(F.disp(32)).foregroundStyle(C.text).lineLimit(1).minimumScaleFactor(0.7)
    }
}

/// Κεκλιμένο σχήμα μόνο δεξιά (όπως οι κίτρινες ετικέτες του site)
struct SlantRight: Shape {
    func path(in r: CGRect) -> Path {
        let k = r.height * 0.35
        var p = Path()
        p.move(to: .zero); p.addLine(to: CGPoint(x: r.maxX, y: 0)); p.addLine(to: CGPoint(x: r.maxX - k, y: r.maxY)); p.addLine(to: CGPoint(x: 0, y: r.maxY)); p.closeSubpath()
        return p
    }
}

/// Τίτλος ενότητας: κίτρινη κεκλιμένη ετικέτα + γραμμή + «Όλα ›»
struct GoldHeader: View {
    let title: String
    var action: String? = nil
    var route: Route? = nil
    var body: some View {
        HStack(spacing: 0) {
            Text(title.upperGr).font(F.disp(22)).foregroundStyle(C.ink).lineLimit(1).minimumScaleFactor(0.65)
                .padding(.leading, 14).padding(.trailing, 26).padding(.vertical, 6)
                .background(SlantRight().fill(C.gold))
                .layoutPriority(1)
            Rectangle().fill(C.line).frame(height: 1).padding(.horizontal, 10)
            if let action, let route {
                NavigationLink(value: route) {
                    Text(action + " ›").font(F.body(13, .heavy)).foregroundStyle(C.gold).lineLimit(1).fixedSize()
                }
            }
        }
    }
}

struct SectionLabel: View {
    let text: String
    var body: some View {
        Text(text.upperGr).font(F.body(12, .heavy)).tracking(1).foregroundStyle(C.muted)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct Tag: View {
    let text: String
    var body: some View {
        Text(text.upperGr).font(F.body(11, .heavy)).tracking(0.5).foregroundStyle(C.ink)
            .padding(.horizontal, 8).padding(.vertical, 4)
            .background(RoundedRectangle(cornerRadius: 6).fill(C.gold))
    }
}

struct PlayBadge: View {
    var size: CGFloat = 40
    var body: some View {
        Image(systemName: "play.fill").font(.system(size: size * 0.4, weight: .bold)).foregroundStyle(C.ink)
            .frame(width: size, height: size).background(Circle().fill(C.gold))
    }
}
typealias VideoBadge = PlayBadge

// MARK: - Γυάλινα κουμπιά (iOS 26)

struct GlassCircle: View {
    let icon: String
    var size: CGFloat = 44
    var gold = false
    var tint: Color = C.text
    var action: () -> Void
    var body: some View {
        Button { haptic(); action() } label: {
            Image(systemName: icon).font(.system(size: size * 0.42, weight: .semibold))
                .foregroundStyle(gold ? C.ink : tint)
                .frame(width: size, height: size)
                .background { if gold { Circle().fill(C.gold) } }
                .glass(Circle(), tint: gold ? C.gold : nil, interactive: true)
        }.buttonStyle(.plain)
    }
}

/// Λίστα επιλογής στο στυλ του app (Android AekDropdown)
struct AekDropdown: View {
    let label: String
    let value: String
    let options: [(String, String)]
    let pick: (String) -> Void
    var body: some View {
        Menu {
            ForEach(options, id: \.0) { o in Button { haptic(); pick(o.0) } label: { if o.1 == value { Label(o.1, systemImage: "checkmark") } else { Text(o.1) } } }
        } label: {
            VStack(alignment: .leading, spacing: 1) {
                Text(label.upperGr).font(F.body(9, .heavy)).tracking(1).foregroundStyle(C.muted)
                HStack(spacing: 4) {
                    Text(value).font(F.body(14, .heavy)).foregroundStyle(C.text).lineLimit(1)
                    Spacer(minLength: 2)
                    if options.count > 1 { Image(systemName: "chevron.down").font(.system(size: 12, weight: .bold)).foregroundStyle(C.gold) }
                }
            }
            .padding(.horizontal, 12).padding(.vertical, 8)
            .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(C.panel))
            .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(C.line2, lineWidth: 1))
        }
        .disabled(options.count <= 1)
    }
}

/// Τσιπάκια (ροή/αναζήτηση)
struct ChipRow: View {
    let items: [(String, String)]
    let selected: String
    var dots = false
    let pick: (String) -> Void
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(items, id: \.0) { it in
                    let on = it.0 == selected
                    Button { haptic(); pick(it.0) } label: {
                        Text(it.1).font(F.body(13, on ? .heavy : .bold)).foregroundStyle(on ? C.ink : C.text)
                            .padding(.horizontal, 14).frame(minHeight: 36)
                            .background(Capsule().fill(on ? C.gold : C.panel2))
                    }.buttonStyle(.plain)
                }
            }.padding(.horizontal, screenPad)
        }
    }
}

// MARK: - Άρθρα

/// Κύριο θέμα: η φωτογραφία ΟΛΟΚΛΗΡΗ (16:9) και από κάτω κατηγορία, τίτλος, ημερομηνία
struct FeaturedCard: View {
    let p: PostCard
    var height: CGFloat = 300
    var titleSize: CGFloat = 30
    var body: some View {
        NavigationLink(value: Route.post(p.id, p)) {
            VStack(alignment: .leading, spacing: 0) {
                FillImage(url: p.image, w: 1400).aspectRatio(16 / 9, contentMode: .fit)
                    .overlay(alignment: .bottom) { LinearGradient(colors: [.clear, C.panel.opacity(0.9)], startPoint: .top, endPoint: .bottom).frame(height: 40) }
                    .overlay(alignment: .topTrailing) { if p.video { PlayBadge(size: 46).padding(14) } }
                VStack(alignment: .leading, spacing: 8) {
                    if !p.category.isEmpty { Tag(text: p.category) }
                    Text(p.title.upperGr).font(F.disp(titleSize)).foregroundStyle(C.text).lineLimit(4).multilineTextAlignment(.leading).minimumScaleFactor(0.8)
                        .lineSpacing(-4).fixedSize(horizontal: false, vertical: true)
                    Text(Fmt.postDate(p.date)).font(F.body(12)).foregroundStyle(C.text2)
                }
                .padding(.horizontal, 16).padding(.top, 4).padding(.bottom, 16)
            }
            .background(C.panel)
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .postMenu(p)
    }
}
typealias PostHero = FeaturedCard

/// Γραμμή άρθρου (112×78, γωνία 12)
struct PostRow: View {
    let p: PostCard
    var body: some View {
        NavigationLink(value: Route.post(p.id, p)) {
            HStack(alignment: .center, spacing: 12) {
                ZStack {
                    if p.image.isEmpty { RoundedRectangle(cornerRadius: 12).fill(C.panel2).overlay(Image("HubLogo").resizable().scaledToFit().frame(width: 40)) }
                    else { FillImage(url: p.image, w: 360, height: 78) }
                    if p.video { PlayBadge(size: 30) }
                }
                .frame(width: 112, height: 78).background(C.panel2).clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                VStack(alignment: .leading, spacing: 5) {
                    if !p.category.isEmpty { Text(p.category.upperGr).font(F.body(11, .heavy)).tracking(0.5).foregroundStyle(C.gold).lineLimit(1) }
                    Text(p.title).font(F.body(15, .bold)).foregroundStyle(C.text).lineLimit(3).multilineTextAlignment(.leading).lineSpacing(1)
                    Text(Fmt.postDate(p.date, withYear: false)).font(F.body(12)).foregroundStyle(C.muted)
                }
                Spacer(minLength: 0)
            }
            .padding(.vertical, 6)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .postMenu(p)
    }
}

/// Μεσαία κάρτα: πρώτο άρθρο κάθε ενότητας (εικόνα 190, γωνία 16)
struct PostCardMedium: View {
    let p: PostCard
    var body: some View {
        NavigationLink(value: Route.post(p.id, p)) {
            VStack(alignment: .leading, spacing: 8) {
                ZStack {
                    FillImage(url: p.image, w: 900, height: 190)
                    if p.video { PlayBadge(size: 52) }
                }
                .frame(height: 190).background(C.panel2).clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                Text(p.title).font(F.body(18, .heavy)).foregroundStyle(C.text).lineLimit(3).multilineTextAlignment(.leading)
                Text(Fmt.postDate(p.date, withYear: false)).font(F.body(12)).foregroundStyle(C.muted)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .postMenu(p)
    }
}

/// Παρατεταμένο πάτημα σε άρθρο: αποθήκευση / κοινοποίηση (όπως σε κάθε καλό app iPhone)
struct PostMenu: ViewModifier {
    let p: PostCard
    @ObservedObject var prefs = Prefs.shared
    func body(content: Content) -> some View {
        content.contextMenu {
            Button { prefs.toggleSaved(p) } label: { Label(prefs.isSaved(p.id) ? "Αφαίρεση από αποθηκευμένα" : "Αποθήκευση", systemImage: prefs.isSaved(p.id) ? "bookmark.slash" : "bookmark") }
            if let u = URL(string: p.link) { ShareLink(item: u) { Label("Κοινοποίηση", systemImage: "square.and.arrow.up") } }
        }
    }
}
extension View { func postMenu(_ p: PostCard) -> some View { modifier(PostMenu(p: p)) } }

// MARK: - Αγώνες

func matchMeta(_ m: MatchCard) -> String { [m.sportLabel, m.competition].filter { !$0.isEmpty }.joined(separator: " · ").upperGr }

func liveText(_ m: MatchCard, _ now: Date = Date()) -> String {
    let mn = liveMinute(m.clock, fallback: m.minute, now: now)
    if !mn.isEmpty { return mn }
    if !m.phase.isEmpty { return m.phase.upperGr }
    return m.statusLabel.upperGr
}

struct LiveTag: View {
    let m: MatchCard
    var prefix = "LIVE · "
    var body: some View {
        TimelineView(.periodic(from: .now, by: 15)) { ctx in
            HStack(spacing: 5) {
                LiveDot(size: 7, color: .white)
                Text((prefix + liveText(m, ctx.date)).trimmingCharacters(in: CharacterSet(charactersIn: " ·"))).font(F.body(11, .heavy)).foregroundStyle(.white).lineLimit(1)
            }
            .padding(.horizontal, 8).padding(.vertical, 3)
            .background(RoundedRectangle(cornerRadius: 6).fill(C.live))
        }
    }
}

/// Λογότυπο + όνομα (TeamCell)
struct TeamCell: View {
    let logo: String
    let name: String
    let aek: Bool
    var size: CGFloat = 48
    var font: CGFloat = 16
    var body: some View {
        VStack(spacing: 6) {
            TeamLogo(url: logo, size: size, name: name)
            Text(name.upperGr).font(F.disp(font)).foregroundStyle(aek ? C.gold : C.text)
                .multilineTextAlignment(.center).lineLimit(2).minimumScaleFactor(0.6)
                .frame(maxWidth: .infinity)
        }
        .frame(maxWidth: .infinity)
    }
}

/// Κέντρο κάρτας αγώνα: ώρα, σκορ ή LIVE
struct MatchCenter: View {
    let m: MatchCard
    var body: some View {
        VStack(spacing: 4) {
            if m.live {
                HStack(spacing: 0) {
                    Text(m.scoreHome.isEmpty ? "0" : m.scoreHome).foregroundStyle(m.aek == "home" ? C.gold : C.text)
                    Text(" : ").font(F.disp(26)).foregroundStyle(C.muted)
                    Text(m.scoreAway.isEmpty ? "0" : m.scoreAway).foregroundStyle(m.aek == "away" ? C.gold : C.text)
                }.font(F.disp(32)).monospacedDigit()
                TimelineView(.periodic(from: .now, by: 15)) { ctx in
                    HStack(spacing: 5) { LiveDot(size: 7); Text(liveText(m, ctx.date)).font(F.body(12, .heavy)).foregroundStyle(C.live).lineLimit(1) }
                }
            } else if m.finished && !m.scoreHome.isEmpty {
                Text("\(m.scoreHome) : \(m.scoreAway)").font(F.disp(26)).foregroundStyle(.white).monospacedDigit()
                    .padding(.horizontal, 10).padding(.vertical, 1)
                    .background(RoundedRectangle(cornerRadius: 8).fill(m.aekWon == true ? C.win : (m.aekWon == false ? C.loss : C.panel3)))
                Text(m.penHome.isEmpty ? "ΤΕΛΙΚΟ" : "ΠΕΝ. \(m.penHome)-\(m.penAway)").font(F.body(10, .heavy)).foregroundStyle(C.muted)
            } else if m.postponed {
                Text("ΑΝΑΒΟΛΗ").font(F.body(12, .heavy)).foregroundStyle(C.muted)
            } else {
                Text("VS").font(F.body(10, .heavy)).tracking(2).foregroundStyle(C.muted)
                Text(m.time.isEmpty ? "—" : m.time).font(F.disp(28)).foregroundStyle(C.gold)
            }
        }
        .frame(width: 96)
    }
}

/// iPad: η λίστα αγώνων ανοίγει τον αγώνα δεξιά (όχι σε νέα οθόνη)
private struct MatchPickKey: EnvironmentKey { static let defaultValue: ((Int) -> Void)? = nil }
private struct MatchSelKey: EnvironmentKey { static let defaultValue: Int? = nil }
extension EnvironmentValues {
    var matchPick: ((Int) -> Void)? { get { self[MatchPickKey.self] } set { self[MatchPickKey.self] = newValue } }
    var matchSel: Int? { get { self[MatchSelKey.self] } set { self[MatchSelKey.self] = newValue } }
}

/// Κάρτα αγώνα (λίστα αγώνων) — Android MatchCardView
struct MatchCardView: View {
    let m: MatchCard
    @ObservedObject var prefs = Prefs.shared
    @Environment(\.matchPick) var pick
    @Environment(\.matchSel) var sel
    var body: some View {
        if let pick {
            Button { haptic(.soft); pick(m.id) } label: { card.overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(C.gold, lineWidth: sel == m.id ? 2 : 0)) }
                .buttonStyle(.plain)
        } else {
            NavigationLink(value: Route.match(m.id)) { card }.buttonStyle(.plain)
        }
    }
    var card: some View {
            VStack(spacing: 0) {
                HStack {
                    Text(matchMeta(m)).font(F.body(11, .heavy)).tracking(0.4).foregroundStyle(C.gold).lineLimit(1)
                    Spacer()
                    if m.upcoming {
                        let on = prefs.alertOn(m)
                        Button {
                            haptic(.medium)
                            prefs.toggleMatchAlert(m)
                        } label: {
                            Image(systemName: on ? "bell.fill" : "bell").font(.system(size: 17)).foregroundStyle(on ? C.gold : C.muted).frame(width: 40, height: 40)
                        }.buttonStyle(.plain)
                    } else { Color.clear.frame(width: 40, height: 40) }
                }
                HStack(spacing: 0) {
                    TeamCell(logo: m.homeLogo, name: m.home, aek: m.aek == "home")
                    MatchCenter(m: m)
                    TeamCell(logo: m.awayLogo, name: m.away, aek: m.aek == "away")
                }
                .padding(.trailing, 10)
                let foot = [m.broadcast, m.venue].filter { !$0.isEmpty }
                if !foot.isEmpty {
                    HStack(spacing: 4) {
                        if !m.broadcast.isEmpty { Image(systemName: "tv").font(.system(size: 12)).foregroundStyle(C.gold) }
                        Text(foot.joined(separator: "  ·  ")).font(F.body(12)).foregroundStyle(C.text2).lineLimit(1)
                    }
                    .padding(.top, 10).padding(.trailing, 10)
                }
            }
            .padding(.leading, 14).padding(.trailing, 4).padding(.top, 4).padding(.bottom, 14)
            .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(C.panel))
            .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(m.live ? C.live : C.line, lineWidth: 1))
            .contentShape(Rectangle())
    }
}

/// Μικρή κάρτα «Επόμενοι αγώνες» (250)
struct MatchMini: View {
    let m: MatchCard
    var body: some View {
        NavigationLink(value: Route.match(m.id)) {
            VStack(alignment: .leading, spacing: 10) {
                Text(matchMeta(m)).font(F.body(10, .heavy)).foregroundStyle(C.gold).lineLimit(1)
                HStack(spacing: 0) {
                    TeamCell(logo: m.homeLogo, name: m.home, aek: m.aek == "home")
                    MatchCenter(m: m)
                    TeamCell(logo: m.awayLogo, name: m.away, aek: m.aek == "away")
                }
                if !m.live {
                    Text(miniDate(m) + (m.broadcast.isEmpty ? "" : "  ·  " + m.broadcast)).font(F.body(11, .bold)).foregroundStyle(C.text2).lineLimit(1)
                }
            }
            .padding(12).frame(width: 250)
            .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(C.panel))
            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(m.live ? C.live : C.line, lineWidth: 1))
        }.buttonStyle(.plain)
    }
    func miniDate(_ m: MatchCard) -> String {
        guard let d = Fmt.day(m.date) else { return m.date }
        let c = Fmt.cal.dateComponents([.day, .month, .weekday], from: d)
        return Fmt.daysShort[c.weekday! - 1].upperGr + " \(c.day!) " + Fmt.monthsShort[c.month! - 1]
    }
}

/// Live αγώνας στην αρχική (LiveBar)
struct LiveBar: View {
    let m: MatchCard
    var body: some View {
        NavigationLink(value: Route.match(m.id)) {
            VStack(spacing: 10) {
                HStack(spacing: 8) {
                    LiveTag(m: m)
                    Text(matchMeta(m)).font(F.body(11, .heavy)).foregroundStyle(C.gold).lineLimit(1)
                    Spacer(minLength: 0)
                    Image(systemName: "chevron.right").font(.system(size: 13, weight: .bold)).foregroundStyle(C.muted)
                }
                HStack(spacing: 8) {
                    HStack(spacing: 8) {
                        TeamLogo(url: m.homeLogo, size: 40, name: m.home)
                        Text(m.home.upperGr).font(F.disp(18)).foregroundStyle(m.aek == "home" ? C.gold : C.text).lineLimit(2).minimumScaleFactor(0.7)
                        Spacer(minLength: 0)
                    }
                    Text("\(m.scoreHome.isEmpty ? "0" : m.scoreHome) : \(m.scoreAway.isEmpty ? "0" : m.scoreAway)").font(F.disp(36)).foregroundStyle(C.text).monospacedDigit().fixedSize()
                    HStack(spacing: 8) {
                        Spacer(minLength: 0)
                        Text(m.away.upperGr).font(F.disp(18)).foregroundStyle(m.aek == "away" ? C.gold : C.text).lineLimit(2).multilineTextAlignment(.trailing).minimumScaleFactor(0.7)
                        TeamLogo(url: m.awayLogo, size: 40, name: m.away)
                    }
                }
            }
            .padding(.horizontal, 14).padding(.vertical, 12)
            .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(LinearGradient(colors: [Color(hex: 0x2A1513), C.panel], startPoint: .top, endPoint: .bottom)))
            .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(C.live, lineWidth: 1.5))
        }.buttonStyle(.plain)
    }
}

/// Live αγώνας στη θέση του κύριου θέματος (LiveMatchHero, 250)
struct LiveMatchHero: View {
    let m: MatchCard
    let image: String
    var body: some View {
        NavigationLink(value: Route.match(m.id)) {
            ZStack {
                if image.isEmpty { Color.clear.overlay(Image("HeroBg").resizable().scaledToFill()).clipped() } else { FillImage(url: image, w: 1200, height: 250) }
                LinearGradient(colors: [C.ink.opacity(0.55), C.ink.opacity(0.95)], startPoint: .top, endPoint: .bottom)
                VStack {
                    HStack { LiveTag(m: m); Spacer(); Text(matchMeta(m)).font(F.body(10, .heavy)).foregroundStyle(C.gold).lineLimit(1) }
                    Spacer()
                    HStack(spacing: 0) {
                        TeamCell(logo: m.homeLogo, name: m.home, aek: m.aek == "home", size: 58, font: 17)
                        Text("\(m.scoreHome.isEmpty ? "0" : m.scoreHome) : \(m.scoreAway.isEmpty ? "0" : m.scoreAway)").font(F.disp(52)).foregroundStyle(C.text).monospacedDigit().fixedSize()
                        TeamCell(logo: m.awayLogo, name: m.away, aek: m.aek == "away", size: 58, font: 17)
                    }
                    Spacer()
                    Text("ΠΑΤΑ ΓΙΑ ΤΟ MATCH CENTER ›").font(F.body(11, .heavy)).tracking(1).foregroundStyle(C.gold)
                }.padding(16)
            }
            .frame(height: 250)
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(C.live, lineWidth: 1.5))
        }.buttonStyle(.plain)
    }
}

/// Live γεγονός στη θέση του κύριου θέματος
struct LiveEventHero: View {
    let id: Int
    let title: String
    let image: String
    var body: some View {
        NavigationLink(value: Route.event(id)) {
            ZStack(alignment: .bottomLeading) {
                if image.isEmpty { Color.clear.overlay(Image("HeroBg").resizable().scaledToFill()).clipped() } else { FillImage(url: image, w: 1200, height: 250) }
                LinearGradient(stops: [.init(color: .clear, location: 0.2), .init(color: C.ink, location: 1)], startPoint: .top, endPoint: .bottom)
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 5) { LiveDot(size: 7, color: .white); Text("LIVE ΤΩΡΑ").font(F.body(11, .heavy)).foregroundStyle(.white) }
                        .padding(.horizontal, 8).padding(.vertical, 3).background(RoundedRectangle(cornerRadius: 6).fill(C.live))
                    Text(title.upperGr).font(F.disp(28)).foregroundStyle(C.text).lineLimit(3)
                }.padding(16)
            }
            .frame(height: 250)
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(C.live, lineWidth: 1.5))
        }.buttonStyle(.plain)
    }
}

/// ⏱ Αντίστροφη μέτρηση (Android NextMatchCountdown)
struct NextMatchCountdown: View {
    let m: MatchCard
    var body: some View {
        if let ko = m.kickoffDate, ko > Date(), !m.live, !m.finished {
            NavigationLink(value: Route.match(m.id)) {
                VStack(spacing: 10) {
                    HStack(spacing: 8) {
                        Text("ΕΠΟΜΕΝΟΣ ΑΓΩΝΑΣ").font(F.body(11, .heavy)).foregroundStyle(C.gold).lineLimit(1).fixedSize()
                        Text(m.competition.isEmpty ? m.sportLabel : m.competition).font(F.body(11, .bold)).foregroundStyle(C.muted).lineLimit(1)
                        Spacer(minLength: 0)
                        Text(whenText(ko)).font(F.body(11, .bold)).foregroundStyle(C.text2).lineLimit(1).fixedSize()
                    }
                    HStack(spacing: 8) {
                        HStack(spacing: 8) {
                            TeamLogo(url: m.homeLogo, size: 30, name: m.home)
                            Text(m.home.upperGr).font(F.disp(15)).foregroundStyle(m.aek == "home" ? C.gold : C.text).lineLimit(1).minimumScaleFactor(0.65)
                            Spacer(minLength: 0)
                        }
                        Text("VS").font(F.body(12, .heavy)).foregroundStyle(C.muted)
                        HStack(spacing: 8) {
                            Spacer(minLength: 0)
                            Text(m.away.upperGr).font(F.disp(15)).foregroundStyle(m.aek == "away" ? C.gold : C.text).lineLimit(1).minimumScaleFactor(0.65)
                            TeamLogo(url: m.awayLogo, size: 30, name: m.away)
                        }
                    }
                    TimelineView(.periodic(from: .now, by: 1)) { ctx in
                        let s = max(0, Int(ko.timeIntervalSince(ctx.date)))
                        HStack(spacing: 8) {
                            cell(s / 86400, "ΜΕΡΕΣ"); cell(s % 86400 / 3600, "ΩΡΕΣ"); cell(s % 3600 / 60, "ΛΕΠΤΑ"); cell(s % 60, "ΔΕΥΤ.")
                        }
                    }
                }
                .padding(.horizontal, 14).padding(.vertical, 12)
                .background(RoundedRectangle(cornerRadius: 22, style: .continuous).fill(LinearGradient(colors: [Color(hex: 0x1D1B13), C.panel, Color(hex: 0x221C05)], startPoint: .topLeading, endPoint: .bottomTrailing)))
                .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).stroke(C.gold.opacity(0.35), lineWidth: 1))
            }.buttonStyle(.plain)
        }
    }
    func whenText(_ d: Date) -> String {
        let c = Fmt.cal.dateComponents([.day, .month, .weekday, .hour, .minute], from: d)
        return Fmt.daysShort[c.weekday! - 1] + " \(c.day!)/\(c.month!) · " + String(format: "%02d:%02d", c.hour!, c.minute!)
    }
    func cell(_ v: Int, _ l: String) -> some View {
        VStack(spacing: 0) {
            Text(String(format: "%02d", v)).font(F.disp(22)).foregroundStyle(C.gold).monospacedDigit()
            Text(l).font(F.body(9, .heavy)).foregroundStyle(C.muted)
        }
        .frame(maxWidth: .infinity).padding(.vertical, 7)
        .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(C.ink))
    }
}

// MARK: - Κατηγορίες & social

func catIcon(_ k: String) -> String {
    switch k {
    case "football": return "nav_football"
    case "basketball": return "nav_basketball"
    case "erasitechniki": return "nav_erasitechniki"
    case "hubplus": return "nav_hubplus"
    case "programma": return "nav_programma"
    case "home": return "nav_home"
    default: return "Eagle"
    }
}

/// Μενού κατηγοριών: πλακίδια με τα εικονίδια του site (84×92)
struct CategoryMenu: View {
    let items: [Category]
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(items) { c in
                    NavigationLink(value: Route.category(c.slug, c.name)) {
                        VStack(spacing: 6) {
                            Image(catIcon(c.icon)).resizable().scaledToFit().frame(width: 38, height: 38)
                            Text(c.name).font(F.body(11, .heavy)).foregroundStyle(C.text).lineLimit(1).minimumScaleFactor(0.7)
                        }
                        .padding(8).frame(width: 84, height: 92)
                        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(C.panel))
                        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(C.line, lineWidth: 1))
                    }.buttonStyle(.plain)
                }
            }.padding(.horizontal, screenPad)
        }
    }
}

func socialGrad(_ k: String) -> LinearGradient {
    let cs: [Color]
    switch k {
    case "facebook": cs = [Color(hex: 0x1877F2), Color(hex: 0x0E5FD0)]
    case "instagram": cs = [Color(hex: 0xFEDA75), Color(hex: 0xFA7E1E), Color(hex: 0xD62976), Color(hex: 0x962FBF), Color(hex: 0x4F5BD5)]
    case "youtube": cs = [Color(hex: 0xFF0000), Color(hex: 0xC4302B)]
    case "tiktok": cs = [Color(hex: 0x25F4EE), Color(hex: 0x000000), Color(hex: 0xFE2C55)]
    default: cs = [Color(hex: 0x2A2A2A), .black]
    }
    return LinearGradient(colors: cs, startPoint: .topLeading, endPoint: .bottomTrailing)
}
func socialIcon(_ k: String) -> String { ["facebook", "instagram", "youtube", "tiktok"].contains(k) ? "soc_" + k : "soc_x" }
func socialCta(_ k: String) -> String {
    switch k {
    case "instagram": return "Stories & reels από κάθε ματς"
    case "youtube": return "Βίντεο, συνεντεύξεις, στιγμιότυπα"
    case "tiktok": return "Τα πιο viral της ΑΕΚ"
    case "facebook": return "Συζήτηση με την κερκίδα"
    default: return "Πρώτοι στα έκτακτα"
    }
}

struct SocialDot: View {
    let s: Social
    var size: CGFloat = 36
    @Environment(\.openURL) var open
    var body: some View {
        Button { if let u = URL(string: s.url) { open(u) } } label: {
            Image(socialIcon(s.key)).resizable().renderingMode(.template).scaledToFit().foregroundStyle(.white)
                .frame(width: size * 0.5, height: size * 0.5)
                .frame(width: size, height: size).background(Circle().fill(socialGrad(s.key)))
        }.buttonStyle(.plain)
    }
}

/// Λωρίδα «Ακολούθησέ μας» (κορυφή αρχικής)
struct SocialStrip: View {
    let list: [Social]
    var body: some View {
        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 0) {
                Text("ΑΚΟΛΟΥΘΗΣΕ ΜΑΣ").font(F.disp(16)).foregroundStyle(C.gold).lineLimit(1).minimumScaleFactor(0.7)
                Text(list.first { !$0.handle.isEmpty }?.handle ?? "AEK Hub").font(F.body(11, .bold)).foregroundStyle(C.muted).lineLimit(1)
            }
            Spacer(minLength: 0)
            ForEach(list, id: \.self) { SocialDot(s: $0) }
        }
        .padding(.horizontal, 12).padding(.vertical, 8)
        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(C.panel))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(C.line, lineWidth: 1))
    }
}

/// Μεγάλη ενότητα social (τέλος αρχικής)
struct SocialSection: View {
    let list: [Social]
    @Environment(\.openURL) var open
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                Image("Eagle").resizable().scaledToFit().frame(width: 40, height: 40)
                VStack(alignment: .leading, spacing: 0) {
                    Text("ΑΚΟΛΟΥΘΗΣΕ ΤΟ AEK HUB").font(F.disp(22)).foregroundStyle(C.text)
                    Text("Ό,τι γίνεται στην ΑΕΚ, πρώτα στα social μας").font(F.body(12)).foregroundStyle(C.muted)
                }
            }
            ForEach(list, id: \.self) { s in
                Button { if let u = URL(string: s.url) { open(u) } } label: {
                    HStack(spacing: 12) {
                        Image(socialIcon(s.key)).resizable().renderingMode(.template).scaledToFit().foregroundStyle(.white).frame(width: 22, height: 22)
                            .frame(width: 40, height: 40).background(Circle().fill(.black.opacity(0.25)))
                        VStack(alignment: .leading, spacing: 1) {
                            Text(s.label + (s.handle.isEmpty ? "" : "  " + s.handle)).font(F.body(15, .heavy)).foregroundStyle(.white).lineLimit(1)
                            Text(socialCta(s.key)).font(F.body(12, .bold)).foregroundStyle(.white.opacity(0.85)).lineLimit(1)
                        }
                        Spacer(minLength: 0)
                        Text("Follow").font(F.body(12, .heavy)).foregroundStyle(.black).padding(.horizontal, 12).padding(.vertical, 6).background(Capsule().fill(.white))
                    }
                    .padding(.horizontal, 14).padding(.vertical, 12)
                    .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(socialGrad(s.key)))
                }.buttonStyle(.plain)
            }
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(C.panel))
        .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(C.line, lineWidth: 1))
    }
}

// MARK: - Βοηθητικά

struct EmptyState: View {
    let icon: String
    let text: String
    var retry: (() -> Void)? = nil
    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: icon).font(.system(size: 30)).foregroundStyle(C.muted)
            Text(text).font(F.body(15, .bold)).foregroundStyle(C.text2).multilineTextAlignment(.center)
            if let retry {
                Button(action: retry) {
                    Text("Ξαναδοκίμασε").font(F.body(14, .heavy)).foregroundStyle(C.ink).padding(.horizontal, 22).padding(.vertical, 12)
                        .background(RoundedRectangle(cornerRadius: 12).fill(C.gold))
                }.buttonStyle(.plain)
            }
        }.padding(32).frame(maxWidth: .infinity)
    }
}

/// Σκελετός φόρτωσης (αντί για σκέτο spinner)
struct SkeletonList: View {
    var rows = 5
    @State private var on = false
    var body: some View {
        VStack(spacing: 14) {
            RoundedRectangle(cornerRadius: 20).fill(C.panel).frame(height: 220)
            ForEach(0..<rows, id: \.self) { _ in
                HStack(spacing: 12) {
                    RoundedRectangle(cornerRadius: 12).fill(C.panel).frame(width: 112, height: 78)
                    VStack(alignment: .leading, spacing: 8) {
                        RoundedRectangle(cornerRadius: 4).fill(C.panel).frame(width: 80, height: 10)
                        RoundedRectangle(cornerRadius: 4).fill(C.panel).frame(height: 14)
                        RoundedRectangle(cornerRadius: 4).fill(C.panel).frame(width: 140, height: 14)
                    }
                }
            }
        }
        .padding(.horizontal, screenPad)
        .opacity(on ? 0.45 : 1)
        .onAppear { withAnimation(.easeInOut(duration: 0.9).repeatForever()) { on = true } }
    }
}

struct LogoTitle: View {
    var h: CGFloat = 30
    var body: some View { Image("Logo").resizable().scaledToFit().frame(height: h) }
}

/// Διακόπτης στο χρώμα του app (Android: κίτρινο track, μαύρο thumb)
struct GoldToggle: ToggleStyle {
    func makeBody(configuration c: Configuration) -> some View {
        HStack(spacing: 12) {
            c.label
            Spacer(minLength: 8)
            Capsule().fill(c.isOn ? C.gold : C.line2).frame(width: 51, height: 31)
                .overlay(Circle().fill(c.isOn ? C.ink : C.muted).padding(4).offset(x: c.isOn ? 10 : -10))
                .animation(.spring(response: 0.25, dampingFraction: 0.8), value: c.isOn)
                .onTapGesture { haptic(); c.isOn.toggle() }
        }
        .contentShape(Rectangle())
    }
}
