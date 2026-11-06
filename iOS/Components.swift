import SwiftUI

/// Στήλες: 1 στο iPhone, περισσότερες στο iPad / οριζόντια
let adaptiveCols = [GridItem(.adaptive(minimum: 340), spacing: 14, alignment: .top)]

/// Κίτρινος τίτλος ενότητας (όπως το sp-section-title του site) + «Όλα ›»
struct GoldHeader: View {
    let title: String
    var action: String? = nil
    var onTap: (() -> Void)? = nil
    var body: some View {
        HStack(spacing: 10) {
            Circle().fill(C.gold).frame(width: 9, height: 9)
            Text(title.upperGr).font(F.disp(24, black: true)).foregroundStyle(C.text).lineLimit(1)
            Color.clear.frame(height: 1).overlay(
                GeometryReader { g in Path { p in p.move(to: .zero); p.addLine(to: CGPoint(x: g.size.width, y: 0)) }
                    .stroke(C.line2, style: StrokeStyle(lineWidth: 1, dash: [4, 4])) }
            ).opacity(0.8)
            if let action, let onTap {
                Button(action: onTap) {
                    HStack(spacing: 2) { Text(action).font(F.body(13, .extra)); Image(systemName: "chevron.right").font(.system(size: 11, weight: .bold)) }
                        .foregroundStyle(C.gold)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 18).padding(.bottom, 8)
    }
}

struct SectionLabel: View {
    let text: String
    var body: some View {
        Text(text.upperGr).font(F.body(11, .extra)).foregroundStyle(C.muted).tracking(0.8)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct Chip: View {
    let label: String
    let on: Bool
    let tap: () -> Void
    var body: some View {
        Button(action: tap) {
            Text(label).font(F.body(13, on ? .extra : .bold))
                .foregroundStyle(on ? C.ink : C.text)
                .padding(.horizontal, 14).padding(.vertical, 8)
                .background(Capsule().fill(on ? C.gold : C.panel2))
        }.buttonStyle(.plain)
    }
}

struct ChipRow: View {
    let items: [(String, String)]
    let selected: String
    let pick: (String) -> Void
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) { ForEach(items, id: \.0) { it in Chip(label: it.1, on: it.0 == selected) { pick(it.0) } } }
                .padding(.horizontal, 16)
        }
    }
}

struct VideoBadge: View {
    var body: some View {
        Image(systemName: "play.fill").font(.system(size: 12, weight: .bold)).foregroundStyle(C.ink)
            .frame(width: 30, height: 30).background(Circle().fill(C.gold))
    }
}

/// Μεγάλη κάρτα άρθρου (κύριο θέμα)
struct PostHero: View {
    let p: PostCard
    var body: some View {
        NavigationLink(value: Route.post(p.id, p)) {
            ZStack(alignment: .bottomLeading) {
                NetImage(url: p.image, w: 1200).frame(maxWidth: .infinity).frame(height: 250).clipped()
                LinearGradient(colors: [.clear, .black.opacity(0.92)], startPoint: .center, endPoint: .bottom)
                VStack(alignment: .leading, spacing: 8) {
                    if !p.category.isEmpty {
                        Text(p.category.upperGr).font(F.body(10, .extra)).foregroundStyle(C.ink)
                            .padding(.horizontal, 8).padding(.vertical, 4).background(RoundedRectangle(cornerRadius: 4).fill(C.gold))
                    }
                    Text(p.title).font(F.disp(30, black: true)).foregroundStyle(.white).multilineTextAlignment(.leading).lineLimit(4)
                    Text(Fmt.ago(p.date)).font(F.body(12, .bold)).foregroundStyle(C.text2)
                }.padding(16)
                if p.video { VideoBadge().padding(14).frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing) }
            }
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .padding(.horizontal, 16)
        }.buttonStyle(.plain)
    }
}

/// Γραμμή άρθρου (εικόνα αριστερά)
struct PostRow: View {
    let p: PostCard
    var body: some View {
        NavigationLink(value: Route.post(p.id, p)) {
            HStack(alignment: .top, spacing: 12) {
                ZStack {
                    NetImage(url: p.image, w: 400).frame(width: 118, height: 82).clipped()
                    if p.video { VideoBadge().scaleEffect(0.8) }
                }.clipShape(RoundedRectangle(cornerRadius: 10))
                VStack(alignment: .leading, spacing: 6) {
                    Text(p.title).font(F.body(15, .extra)).foregroundStyle(C.text).lineLimit(3).multilineTextAlignment(.leading)
                    HStack(spacing: 6) {
                        if !p.category.isEmpty { Text(p.category).foregroundStyle(C.gold) }
                        Text(Fmt.ago(p.date)).foregroundStyle(C.muted)
                    }.font(F.body(11, .bold)).lineLimit(1)
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 16).padding(.vertical, 8)
            .contentShape(Rectangle())
        }.buttonStyle(.plain)
    }
}

/// Πλακίδιο άρθρου για οριζόντιες λίστες
struct PostTile: View {
    let p: PostCard
    var width: CGFloat = 240
    var body: some View {
        NavigationLink(value: Route.post(p.id, p)) {
            VStack(alignment: .leading, spacing: 8) {
                ZStack {
                    NetImage(url: p.image, w: 600).frame(width: width, height: width * 0.58).clipped()
                    if p.video { VideoBadge() }
                }.clipShape(RoundedRectangle(cornerRadius: 12))
                Text(p.title).font(F.body(14, .extra)).foregroundStyle(C.text).lineLimit(3).multilineTextAlignment(.leading)
                    .frame(width: width, alignment: .leading)
                Text(Fmt.ago(p.date)).font(F.body(11, .bold)).foregroundStyle(C.muted)
            }
        }.buttonStyle(.plain)
    }
}

/// Κατάσταση αγώνα: live λεπτό / ΤΕΛΙΚΟ / ώρα
struct MatchStatus: View {
    let m: MatchCard
    var big = false
    var body: some View {
        TimelineView(.periodic(from: .now, by: 15)) { ctx in
            if m.live {
                HStack(spacing: 5) {
                    LiveDot(size: big ? 8 : 6)
                    Text(liveText(ctx.date)).font(F.body(big ? 13 : 11, .extra)).foregroundStyle(C.live)
                }
            } else if m.finished {
                Text(big ? "ΤΕΛΙΚΟ ΑΠΟΤΕΛΕΣΜΑ" : "ΤΕΛ").font(F.body(big ? 12 : 10, .extra)).foregroundStyle(C.muted)
            } else if m.postponed {
                Text("ΑΝΑΒΟΛΗ").font(F.body(big ? 12 : 10, .extra)).foregroundStyle(C.muted)
            } else {
                Text(m.time.isEmpty ? "—" : m.time).font(F.body(big ? 14 : 12, .extra)).foregroundStyle(C.gold)
            }
        }
    }
    func liveText(_ now: Date) -> String {
        let mn = liveMinute(m.clock, fallback: m.minute, now: now)
        if !m.phase.isEmpty && mn.isEmpty { return m.phase.upperGr }
        if !mn.isEmpty { return mn }
        return m.statusLabel.isEmpty ? "LIVE" : m.statusLabel.upperGr
    }
}

/// Γραμμή αγώνα (λίστα αγώνων)
struct MatchRow: View {
    let m: MatchCard
    var showDate = false
    var body: some View {
        NavigationLink(value: Route.match(m.id)) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 6) {
                    Text(Sports.emoji(m.sport))
                    Text([m.competition, m.matchday].filter { !$0.isEmpty }.joined(separator: " · ")).lineLimit(1)
                    Spacer()
                    if showDate { Text(Fmt.shortDay(m.date)).foregroundStyle(C.text2) }
                }.font(F.body(11, .bold)).foregroundStyle(C.muted)
                HStack(spacing: 10) {
                    VStack(alignment: .leading, spacing: 6) {
                        team(m.home, m.homeLogo, m.aek == "home", score: m.scoreHome, pen: m.penHome)
                        team(m.away, m.awayLogo, m.aek == "away", score: m.scoreAway, pen: m.penAway)
                    }
                    Rectangle().fill(C.line).frame(width: 1, height: 44)
                    VStack(spacing: 4) {
                        MatchStatus(m: m)
                        if m.finished, let w = m.aekWon {
                            Text(w ? "Ν" : "Η").font(F.body(10, .extra)).foregroundStyle(.white)
                                .frame(width: 18, height: 18).background(RoundedRectangle(cornerRadius: 4).fill(w ? C.win : C.loss))
                        } else if m.finished, m.aekWon == nil, m.hasScore {
                            Text("Ι").font(F.body(10, .extra)).foregroundStyle(C.ink).frame(width: 18, height: 18).background(RoundedRectangle(cornerRadius: 4).fill(C.muted))
                        }
                    }.frame(width: 64)
                }
            }
            .padding(12)
            .background(RoundedRectangle(cornerRadius: 12).fill(m.live ? C.panel2 : C.panel))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(m.live ? C.live.opacity(0.6) : C.line, lineWidth: 1))
            .contentShape(Rectangle())
        }.buttonStyle(.plain)
    }

    @ViewBuilder func team(_ name: String, _ logo: String, _ isAek: Bool, score: String, pen: String) -> some View {
        HStack(spacing: 8) {
            TeamLogo(url: logo, size: 22)
            Text(name).font(F.body(14, isAek ? .extra : .bold)).foregroundStyle(isAek ? C.text : C.text2).lineLimit(1)
            Spacer(minLength: 4)
            if !m.upcoming || m.hasScore {
                Text(score + (pen.isEmpty ? "" : " (\(pen))")).font(F.disp(22, black: true)).foregroundStyle(m.live ? C.gold : C.text).monospacedDigit()
            }
        }
    }
}

/// Μικρή κάρτα αγώνα για οριζόντια λίστα (αρχική)
struct MatchMini: View {
    let m: MatchCard
    var body: some View {
        NavigationLink(value: Route.match(m.id)) {
            VStack(spacing: 8) {
                HStack {
                    Text(Sports.emoji(m.sport) + " " + (m.sportLabel.isEmpty ? Sports.label(m.sport) : m.sportLabel)).lineLimit(1)
                    Spacer()
                    if !m.live { Text(Fmt.shortDay(m.date)) }
                }.font(F.body(10, .extra)).foregroundStyle(C.muted)
                HStack {
                    TeamLogo(url: m.homeLogo, size: 36)
                    Spacer()
                    if m.upcoming && !m.hasScore { MatchStatus(m: m, big: true) }
                    else { Text("\(m.scoreHome)–\(m.scoreAway)").font(F.disp(28, black: true)).foregroundStyle(m.live ? C.gold : C.text).monospacedDigit() }
                    Spacer()
                    TeamLogo(url: m.awayLogo, size: 36)
                }
                Text("\(m.home) – \(m.away)").font(F.body(12, .bold)).foregroundStyle(C.text2).lineLimit(1)
                if !m.upcoming { MatchStatus(m: m) }
            }
            .padding(12).frame(width: 230)
            .background(RoundedRectangle(cornerRadius: 14).fill(m.live ? C.panel2 : C.panel))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(m.live ? C.live.opacity(0.6) : C.line, lineWidth: 1))
        }.buttonStyle(.plain)
    }
}

/// ⏱ Αντίστροφη μέτρηση για τον επόμενο αγώνα (ίδιος αγώνας με τη μπάρα «Επόμενος αγώνας» του site)
struct CountdownCard: View {
    let m: MatchCard
    var body: some View {
        NavigationLink(value: Route.match(m.id)) {
            VStack(spacing: 12) {
                HStack {
                    Text((m.live ? "ΤΩΡΑ LIVE" : "ΕΠΟΜΕΝΟΣ ΑΓΩΝΑΣ")).font(F.body(11, .extra)).foregroundStyle(m.live ? C.live : C.gold)
                    Spacer()
                    Text(Sports.emoji(m.sport) + " " + m.competition).font(F.body(11, .bold)).foregroundStyle(C.muted).lineLimit(1)
                }
                HStack(alignment: .center) {
                    side(m.home, m.homeLogo)
                    Spacer()
                    if m.live || m.hasScore {
                        VStack(spacing: 4) {
                            Text("\(m.scoreHome)–\(m.scoreAway)").font(F.disp(44, black: true)).foregroundStyle(C.gold).monospacedDigit()
                            MatchStatus(m: m)
                        }
                    } else {
                        VStack(spacing: 2) {
                            Text(Fmt.shortDay(m.date)).font(F.body(12, .bold)).foregroundStyle(C.text2)
                            Text(m.time).font(F.disp(34, black: true)).foregroundStyle(C.text)
                        }
                    }
                    Spacer()
                    side(m.away, m.awayLogo)
                }
                if !m.live, let ko = m.kickoffDate, ko > Date() {
                    TimelineView(.periodic(from: .now, by: 1)) { ctx in
                        let s = max(0, Int(ko.timeIntervalSince(ctx.date)))
                        HStack(spacing: 8) {
                            box(s / 86400, "ΜΕΡΕΣ"); box(s % 86400 / 3600, "ΩΡΕΣ"); box(s % 3600 / 60, "ΛΕΠΤΑ"); box(s % 60, "ΔΕΥΤ")
                        }
                    }
                }
                if !m.venue.isEmpty || !m.broadcast.isEmpty {
                    Text([m.venue, m.broadcast.isEmpty ? "" : "📺 " + m.broadcast].filter { !$0.isEmpty }.joined(separator: " · "))
                        .font(F.body(11, .bold)).foregroundStyle(C.muted).lineLimit(2).multilineTextAlignment(.center)
                }
            }
            .padding(16)
            .background(
                ZStack {
                    Image("HeroBg").resizable().scaledToFill().opacity(0.35)
                    LinearGradient(colors: [C.panel.opacity(0.4), C.ink.opacity(0.95)], startPoint: .top, endPoint: .bottom)
                }
            )
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(m.live ? C.live.opacity(0.6) : C.gold.opacity(0.35), lineWidth: 1))
            .padding(.horizontal, 16)
        }.buttonStyle(.plain)
    }
    func side(_ name: String, _ logo: String) -> some View {
        VStack(spacing: 6) {
            TeamLogo(url: logo, size: 54)
            Text(name.upperGr).font(F.disp(17, black: true)).foregroundStyle(C.text).lineLimit(2).multilineTextAlignment(.center).minimumScaleFactor(0.7)
        }.frame(width: 100)
    }
    func box(_ v: Int, _ l: String) -> some View {
        VStack(spacing: 2) {
            Text(String(format: "%02d", v)).font(F.disp(26, black: true)).foregroundStyle(C.ink).monospacedDigit()
            Text(l).font(F.body(8, .extra)).foregroundStyle(C.ink.opacity(0.7))
        }.frame(width: 58, height: 52).background(RoundedRectangle(cornerRadius: 8).fill(C.gold))
    }
}

struct EmptyState: View {
    let icon: String
    let text: String
    var retry: (() -> Void)? = nil
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: icon).font(.system(size: 34)).foregroundStyle(C.muted)
            Text(text).font(F.body(14, .bold)).foregroundStyle(C.text2).multilineTextAlignment(.center)
            if let retry { Button("Ξαναδοκίμασε", action: retry).font(F.body(14, .extra)).buttonStyle(.borderedProminent).tint(C.gold).foregroundStyle(C.ink) }
        }.padding(40).frame(maxWidth: .infinity)
    }
}

/// Λογότυπο AEK Hub στη μπάρα
struct LogoTitle: View {
    var body: some View { Image("Logo").resizable().scaledToFit().frame(height: 26) }
}
