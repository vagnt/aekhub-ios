import SwiftUI

/// Match Center του site (1.124–1.150) περασμένο στο iOS app — ΧΩΡΙΣ αλλαγές στον server:
/// τα φτιάχνει το app από όσα ήδη στέλνει το `/app/match`, `/app/matches` και `/app/standings`.
/// 📺 κανάλια με λογότυπα + «▶ Δες το» · 🏆 λογότυπο διοργάνωσης · «Πριν τη σέντρα» (αντίστροφη μέτρηση,
/// πληροφορίες, οδηγίες, φόρμα ΑΕΚ, τελευταίες αναμετρήσεις, βαθμολογία) · «Μετά τον αγώνα» (μόνο αποτέλεσμα).

// MARK: - 📺 Κανάλια (ίδιος κατάλογος με το Match Center → 📺 Κανάλια)

struct TVChannel: Hashable {
    let name, label, logo, url: String
    var youtube: Bool { name.lowercased().contains("youtube") }
    /// Τι γράφεται δίπλα στο λογότυπο (με λογότυπο: μόνο το όνομα καναλιού YouTube, π.χ. «AEK AC TV»)
    var text: String { !label.isEmpty ? label : (logo.isEmpty && !youtube ? name : "") }
}

enum Channels {
    static let site = "https://aekhub.gr/wp-content/plugins/aek-match-center/assets/"
    /// [όνομα, λέξεις (κόμμα), link, αρχείο λογοτύπου]
    static let catalog: [(String, String, String, String)] = {
        let nova = "https://www.novasports.gr/", mag = "https://www.magentatv.gr/", ert = "https://www.ertflix.gr/"
        var L: [(String, String, String, String)] = [
            ("ΕΡΤ1", "ερτ1, ert1, ερτ 1", ert, "2"), ("ΕΡΤ2 Σπορ", "ερτ2, ert2, ερτ 2, ερτ σπορ, ert sport, ερτ2 σπορ, ert2 sport", ert, "3"),
            ("ΕΡΤ3", "ερτ3, ert3, ερτ 3", ert, "4"), ("ΕΡΤ News", "ερτ news, ert news", ert, "184"), ("ERT World", "ert world, ert cosmos, ερτ world", ert, "44"),
            ("Alpha", "alpha", "https://www.alphatv.gr/live/", "34"), ("Star", "star channel, star", "https://www.star.gr/tv/live-stream/", "33"),
            ("Mega", "mega", "https://www.megatv.com/live/", "266"), ("ANT1", "ant1, αντ1, antenna", "https://www.antenna.gr/live", "269"),
            ("Open", "open beyond, open", "https://www.tvopen.gr/live", "37"), ("ΣΚΑΪ", "σκαι, skai", "https://www.skai.gr/live", "30"),
            ("One Channel", "one channel", "", "27"), ("Action 24", "action 24, action24", "", "43"), ("Kontra", "kontra", "", "42"),
            ("Blue Sky", "blue sky", "", "193"), ("Attica TV", "attica", "", "197"), ("Ena Channel", "ena channel", "", "84"),
            ("Novasports News", "novasports news", nova, "6"), ("Novasports Start", "novasports start", nova, "89"), ("Novasports Prime", "novasports prime", nova, "91"),
            ("Novasports Premier League", "novasports premier league", nova, "177"),
            ("Novasports 1 League", "novasports 1 league, novasports1 league, novasports 1 l", nova, "311"), ("Novasports 2 League", "novasports 2 league, novasports2 league, novasports 2 l", nova, "310"),
            ("Novasports 1", "novasports 1", nova, "23"), ("Novasports 2", "novasports 2", nova, "24"), ("Novasports 3", "novasports 3", nova, "25"),
            ("Novasports 4", "novasports 4", nova, "26"), ("Novasports 5", "novasports 5", nova, "28"), ("Novasports 6", "novasports 6", nova, "90"),
            ("Novasports Extra 1", "novasports extra 1, novasportsextra1", nova, "165"), ("Novasports Extra 2", "novasports extra 2, novasportsextra2", nova, "166"), ("Novasports Extra 3", "novasports extra 3, novasportsextra3", nova, "167"),
            ("Magenta Sport Highlights", "magenta sport highlights, magenta sport hl", mag, "220"),
            ("Magenta Sport 1 League", "magenta sport 1 league, magenta sport1 l, cosmote sport 1 league", mag, "276"), ("Magenta Sport 2 League", "magenta sport 2 league, magenta sport2 l, cosmote sport 2 league", mag, "277"),
            ("Magenta Sport 3 League", "magenta sport 3 league, magenta sport3 l, cosmote sport 3 league", mag, "278"), ("Magenta Sport 4 League", "magenta sport 4 league, magenta sport4 l, cosmote sport 4 league", mag, "275"),
            ("Magenta Sport 4K", "magenta sport 4k, cosmote sport 4k", mag, "252"),
            ("Eurosport 1", "eurosport 1, eurosport1", "", "29"), ("Eurosport 2", "eurosport 2, eurosport2", "", "31"),
            // χωρίς λογότυπο (γράφεται το όνομα)
            ("Cosmote Sport", "cosmote", mag, ""), ("Novasports", "nova", nova, ""), ("ΕΡΤ", "ερτ, ert, ertflix", ert, ""),
            ("Sport FM", "sport fm, sportfm, sport-fm", "https://www.sport-fm.gr/", ""), ("AEK TV", "aek tv, αεκ tv, aektv", "", ""),
            ("YouTube", "youtube", "", ""), ("Facebook", "facebook", "", ""), ("EuroLeague TV", "euroleague tv", "https://euroleague.tv/", ""), ("DAZN", "dazn", "https://www.dazn.com/", ""),
        ]
        let magIds = ["211", "212", "213", "214", "215", "216", "217", "218", "219"]
        for i in 1...9 { L.append(("Magenta Sport \(i)", "magenta sport \(i), cosmote sport \(i)", mag, magIds[i - 1])) }
        for i in 1...6 { L.append(("ERT Sports \(i)", "ert sports \(i), ερτ sports \(i), ertflix sports \(i)", ert, "ert\(i)")) }
        return L
    }()

    static func norm(_ s: String) -> String { s.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Fmt.gr).lowercased() }
    /// χωρίς κενά/παύλες («Novasports1» = «Nova Sports 1»)
    static func cmp(_ s: String) -> String { norm(s).replacingOccurrences(of: #"[\s\-_.]+"#, with: "", options: .regularExpression) }

    private static func match(_ re: String, _ s: String) -> [String]? {
        guard let r = try? NSRegularExpression(pattern: re, options: [.caseInsensitive]),
              let m = r.firstMatch(in: s, range: NSRange(s.startIndex..., in: s)) else { return nil }
        return (0..<m.numberOfRanges).map { i in Range(m.range(at: i), in: s).map { String(s[$0]) } ?? "" }
    }

    /// «Cosmote Sport 1 · YouTube: AEK AC TV https://…» → κανάλια
    static func parse(_ raw: String) -> [TVChannel] {
        var urls: [String] = []
        var txt = raw
        while let m = match(#"https?://\S+"#, txt), let r = txt.range(of: m[0]) {
            urls.append(m[0]); txt.replaceSubrange(r, with: " @@U\(urls.count - 1)@@ ")
        }
        let parts = txt.replacingOccurrences(of: #"\s*(?:·|,|/|\+|\||&| και )\s*"#, with: "\u{1F}", options: .regularExpression).components(separatedBy: "\u{1F}")
        var out: [TVChannel] = []
        for part in parts {
            var p = part.trimmingCharacters(in: .whitespaces), url = ""
            if let m = match(#"@@U(\d+)@@"#, p), let i = Int(m[1]), i < urls.count {
                url = urls[i]; p = p.replacingOccurrences(of: #"\s*@@U\d+@@\s*"#, with: " ", options: .regularExpression).trimmingCharacters(in: .whitespaces)
            }
            if p.isEmpty {
                if !url.isEmpty, let last = out.popLast() { out.append(TVChannel(name: last.name, label: last.label, logo: last.logo, url: url)) }
                continue
            }
            var lab = ""
            if let m = match(#"^(youtube|facebook|twitch)\s*(?:[:\-–]\s*(.+)|\((.+)\))$"#, p) {
                lab = (m[2].isEmpty ? m[3] : m[2]).trimmingCharacters(in: .whitespaces); p = m[1]
            }
            let np = cmp(p)
            var hit: (String, String, String, String)?
            var best = 0
            for c in catalog {
                for k in c.1.split(separator: ",") {
                    let kk = cmp(String(k)); if !kk.isEmpty, np.contains(kk), kk.count > best { hit = c; best = kk.count }
                }
            }
            out.append(TVChannel(name: hit?.0 ?? p, label: lab, logo: (hit?.3 ?? "").isEmpty ? "" : site + "channels/ch-" + hit!.3 + ".png",
                                 url: !url.isEmpty ? url : (hit?.2 ?? "")))
        }
        return out
    }
}

/// 🏆 Έτοιμα λογότυπα γνωστών διοργανώσεων (ίδια αρχεία με το Match Center 1.141)
enum CompLogo {
    static func url(_ comp: String, sport: String) -> String {
        guard !comp.isEmpty else { return "" }
        let k = Channels.cmp(comp.components(separatedBy: " · ").first ?? comp)
        let fb = sport == "football" || sport.isEmpty, bk = sport == "basketball"
        var f = ""
        if bk && (k.contains("basketballchampionsleague") || k.contains("bcl")) { f = "bcl" }
        else if bk && (k.contains("gbl") || k.contains("basketleague")) { f = "gbl" }
        else if fb && k.contains("championsleague") { f = "ucl" }
        else if fb && k.contains("europaleague") { f = "uel" }
        else if fb && k.contains("conferenceleague") { f = "uecl" }
        else if fb && k.contains("superleague") && !k.contains("γυναικων") { f = "superleague" }
        else if fb && (k.contains("κυπελλοελλαδος") || k.contains("κυπελλοελλαδας")) { f = "greekcup" }
        return f.isEmpty ? "" : Channels.site + "comps/" + f + ".png"
    }
}

/// Λογότυπο χωρίς πλαίσιο/κύκλο (κανάλια, διοργανώσεις)
struct PlainLogo: View {
    let url: String
    var h: CGFloat = 24
    var maxW: CGFloat = 90
    @StateObject private var l = ImageLoader()
    var body: some View {
        Group {
            if let i = l.image { Image(uiImage: i).resizable().scaledToFit() } else { Color.clear }
        }
        .frame(maxWidth: maxW).frame(height: h)
        .task(id: url) { l.load(Img.url(url, w: 240)) }
    }
}

/// Ένα κανάλι: λογότυπο (ή όνομα) + ετικέτα
struct ChannelBadge: View {
    let c: TVChannel
    var h: CGFloat = 22
    var body: some View {
        HStack(spacing: 6) {
            if c.youtube && c.logo.isEmpty {
                Image(systemName: "play.rectangle.fill").font(.system(size: h * 0.9)).foregroundStyle(Color(hex: 0xFF0000))
            } else if !c.logo.isEmpty {
                PlainLogo(url: c.logo, h: h, maxW: h * 4)
            }
            if !c.text.isEmpty { Text(c.text).font(F.body(12.5, .heavy)).foregroundStyle(C.text).lineLimit(1) }
        }
    }
}

// MARK: - Λέξεις ανά άθλημα / τμήμα

enum MatchWords {
    /// (τίτλος ενότητας, ετικέτα ώρας) — Match Center 1.132
    static func kick(_ sport: String) -> (String, String) {
        switch sport {
        case "basketball": return ("Πριν το τζάμπολ", "Τζάμπολ")
        case _ where sport.hasPrefix("volleyball"): return ("Πριν το πρώτο σερβίς", "Πρώτο σερβίς")
        case "waterpolo": return ("Πριν την έναρξη", "Έναρξη")
        default: return ("Πριν τη σέντρα", "Σέντρα")
        }
    }
    /// «Σάββατο 8 Νοεμβρίου» (πεζά, με τόνους)
    static func longDay(_ s: String) -> String {
        guard let d = Fmt.day(s) else { return s }
        let c = Fmt.cal.dateComponents([.day, .month, .weekday], from: d)
        guard let wd = c.weekday, let dd = c.day, let mm = c.month else { return s }
        return Fmt.days[wd - 1] + " \(dd) " + Fmt.monthsGen[mm - 1]
    }
    /// Τμήμα: «Ποδόσφαιρο Ανδρών», «Ποδόσφαιρο U19», «Μπάσκετ Γυναικών»
    static func squad(_ m: MatchCard) -> String {
        let t = (m.competition + " " + m.home + " " + m.away).upperGr
        let w = m.sport == "women_football" || t.contains("ΓΥΝΑΙΚ") || t.contains("WOMEN") || t.contains("LADIES")
        var age = ""
        if let r = t.range(of: #"\b[UΚK]\s?-?\s?(1[0-9]|2[0-3])\b"#, options: .regularExpression) {
            age = "U" + t[r].filter(\.isNumber)
        } else if t.contains("ΝΕΩΝ") || t.contains("ΕΦΗΒΩΝ") || t.contains("YOUTH") || t.contains("ΑΚΑΔΗΜ") { age = "U19" }
        let base = m.sport == "women_football" ? "Ποδόσφαιρο" : (m.sportLabel.isEmpty ? Sports.label(m.sport) : m.sportLabel)
        let clean = base.replacingOccurrences(of: " Γυναικών", with: "").replacingOccurrences(of: " Ανδρών", with: "")
        return clean + (age.isEmpty ? "" : " " + age) + (w ? " Γυναικών" : (age.isEmpty ? " Ανδρών" : ""))
    }
    /// ίδιο τμήμα (για φόρμα/αναμετρήσεις: U19 ≠ ανδρών)
    static func sameSquad(_ a: MatchCard, _ b: MatchCard) -> Bool { a.sport == b.sport && squad(a) == squad(b) }
    /// όνομα ομάδας για σύγκριση (χωρίς ΠΑΕ/ΚΑΕ/FC…)
    static func team(_ n: String) -> String {
        Channels.norm(n).replacingOccurrences(of: #"\b(παε|καε|ασπ|αο|ας|γσ|fc|bc|ae)\b\.?"#, with: "", options: .regularExpression)
            .trimmingCharacters(in: .whitespaces)
    }
    static func sameTeam(_ a: String, _ b: String) -> Bool {
        let x = team(a), y = team(b)
        return !x.isEmpty && !y.isEmpty && (x == y || x.contains(y) || y.contains(x))
    }
}

// MARK: - Δεδομένα «Πριν / Μετά» (φόρμα, αναμετρήσεις, επόμενος, βαθμολογία)

@MainActor
final class MatchAround: ObservableObject {
    @Published var form: [MatchCard] = []
    @Published var h2h: [MatchCard] = []
    @Published var next: MatchCard?
    @Published var table: Standing?
    private var loadedFor = 0

    func load(_ m: MatchCard, wantNext: Bool) async {
        guard loadedFor != m.id else { return }
        loadedFor = m.id
        let today = Date()
        let from = Fmt.ymdString(Fmt.cal.date(byAdding: .day, value: -400, to: today) ?? today)
        let to = Fmt.ymdString(Fmt.cal.date(byAdding: .day, value: wantNext ? 60 : 0, to: today) ?? today)
        let tl = Task { try? await Api.shared.matches(from: from, to: to, sport: m.sport) }
        let ts = Task { try? await Api.shared.standings() }
        let list = (await tl.value)?.items ?? []
        let tables = (await ts.value) ?? []

        let opp = m.aek == "home" ? m.away : m.home
        let past = list.filter { $0.id != m.id && $0.finished && $0.hasScore && MatchWords.sameSquad($0, m) }
            .sorted { ($0.kickoffDate ?? .distantPast) > ($1.kickoffDate ?? .distantPast) }
        form = Array(past.filter { !$0.aek.isEmpty }.prefix(7))
        h2h = m.aek.isEmpty ? [] : Array(past.filter { x in !x.aek.isEmpty && MatchWords.sameTeam(x.aek == "home" ? x.away : x.home, opp) }.prefix(5))
        if wantNext {
            let todayS = Fmt.ymdString(today)
            next = list.filter { $0.id != m.id && !$0.finished && !$0.postponed && $0.date >= todayS && MatchWords.sameSquad($0, m) }
                .sorted { ($0.kickoffDate ?? .distantFuture) < ($1.kickoffDate ?? .distantFuture) }.first
        }
        table = Self.pick(tables, m)
    }

    /// Η βαθμολογία της διοργάνωσης του αγώνα (όνομα χωρίς τη φάση, ίδιο άθλημα αν γίνεται)
    static func pick(_ all: [Standing], _ m: MatchCard) -> Standing? {
        let base = Channels.cmp(m.competition.components(separatedBy: " · ").first ?? "")
        guard base.count >= 4 else { return nil }
        let sp = Channels.cmp(m.sportLabel)
        func score(_ s: Standing) -> Int {
            let names = [s.league, s.title].map(Channels.cmp).filter { $0.count >= 4 }
            var v = 0
            for n in names {
                if n == base { v = max(v, 3) }
                else if n.hasPrefix(base) || base.hasPrefix(n) { v = max(v, 2) }
                else if n.contains(base) || base.contains(n) { v = max(v, 1) }
            }
            if v > 0 && !sp.isEmpty && Channels.cmp(s.sport) == sp { v += 3 }
            return v
        }
        let best = all.map { ($0, score($0)) }.filter { $0.1 > 0 && !$0.0.rows.isEmpty }.max { $0.1 < $1.1 }
        return best?.0
    }
}

// MARK: - Τίτλος + πλαίσιο

struct ExtraBox<Content: View>: View {
    let title: String
    var sub: String = ""
    @ViewBuilder let content: () -> Content
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(title.upperGr).font(F.body(12, .heavy)).tracking(1).foregroundStyle(C.gold)
                if !sub.isEmpty { Text(sub).font(F.body(11.5)).foregroundStyle(C.muted).lineLimit(1) }
                Spacer(minLength: 0)
            }
            content()
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(C.panel))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(C.line, lineWidth: 1))
    }
}

// MARK: - ⏳ Αντίστροφη μέτρηση

struct KickCountdown: View {
    let date: Date
    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { ctx in
            let s = max(0, Int(date.timeIntervalSince(ctx.date)))
            let v = [s / 86400, s % 86400 / 3600, s % 3600 / 60, s % 60]
            let l = ["ΜΕΡΕΣ", "ΩΡΕΣ", "ΛΕΠΤΑ", "ΔΕΥΤ."]
            HStack(spacing: 8) {
                ForEach(0..<4, id: \.self) { i in
                    VStack(spacing: 2) {
                        Text(String(format: "%02d", v[i])).font(F.disp(28)).monospacedDigit().foregroundStyle(C.text)
                        Text(l[i]).font(F.body(9.5, .heavy)).tracking(0.5).foregroundStyle(C.muted)
                    }
                    .frame(maxWidth: .infinity).padding(.vertical, 8)
                    .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(C.panel2))
                }
            }
        }
    }
}

// MARK: - Μικρό scoreboard (φόρμα / αναμετρήσεις / επόμενος)

struct MiniScoreRow: View {
    let m: MatchCard
    var body: some View {
        NavigationLink(value: Route.match(m.id)) {
            HStack(spacing: 8) {
                VStack(alignment: .leading, spacing: 1) {
                    Text(Fmt.shortDay(m.date)).font(F.body(10.5, .heavy)).foregroundStyle(C.muted)
                    if !m.competition.isEmpty {
                        Text((m.competition.components(separatedBy: " · ").first ?? "").upperGr).font(F.body(9, .heavy)).foregroundStyle(C.muted).lineLimit(1)
                    }
                }.frame(width: 62, alignment: .leading)
                side(m.homeLogo, m.home, m.aek == "home", trailing: true)
                HStack(spacing: 3) {
                    Text(m.scoreHome).foregroundStyle(m.aek == "home" ? C.gold : C.text)
                    Text("–").foregroundStyle(C.muted)
                    Text(m.scoreAway).foregroundStyle(m.aek == "away" ? C.gold : C.text)
                }.font(F.disp(17)).monospacedDigit().frame(minWidth: 44)
                side(m.awayLogo, m.away, m.aek == "away", trailing: false)
                res
            }
            .padding(.vertical, 7)
            .contentShape(Rectangle())
        }.buttonStyle(.plain)
    }
    func side(_ logo: String, _ name: String, _ aek: Bool, trailing: Bool) -> some View {
        HStack(spacing: 5) {
            if trailing { Spacer(minLength: 0) }
            if !trailing { TeamLogo(url: logo, size: 20, name: name) }
            Text(name.upperGr).font(F.body(11, .heavy)).foregroundStyle(aek ? C.gold : C.text2).lineLimit(1).minimumScaleFactor(0.7)
            if trailing { TeamLogo(url: logo, size: 20, name: name) }
            if !trailing { Spacer(minLength: 0) }
        }.frame(maxWidth: .infinity)
    }
    @ViewBuilder var res: some View {
        let w = m.aekWon
        Text(w == nil ? "Ι" : (w! ? "Ν" : "Η")).font(F.body(11, .heavy)).foregroundStyle(w == true ? C.ink : C.text)
            .frame(width: 22, height: 22)
            .background(RoundedRectangle(cornerRadius: 6).fill(w == nil ? C.panel3 : (w! ? C.win : C.live)))
    }
}

/// Μικρή βαθμολογία: ΑΕΚ κίτρινη, αντίπαλος ανοιχτό γκρι
struct MiniTable: View {
    let s: Standing
    let m: MatchCard
    var body: some View {
        let opp = m.aek == "home" ? m.away : (m.aek == "away" ? m.home : "")
        VStack(spacing: 0) {
            HStack(spacing: 6) {
                Text("#").frame(width: 22)
                Text("ΟΜΑΔΑ").frame(maxWidth: .infinity, alignment: .leading)
                Text("ΑΓ").frame(width: 28)
                Text(s.style == "wdl" ? "Ν-Ι-Η" : "Ν-Η").frame(width: 58)
                Text("Β").frame(width: 30)
            }
            .font(F.body(10, .heavy)).foregroundStyle(C.muted).padding(.bottom, 6)
            ForEach(s.rows, id: \.self) { r in
                let isO = !r.aek && !opp.isEmpty && MatchWords.sameTeam(r.name, opp)
                HStack(spacing: 6) {
                    Text("\(r.pos)").frame(width: 22).foregroundStyle(r.aek ? C.gold : C.muted)
                    HStack(spacing: 6) {
                        TeamLogo(url: r.logo, size: 18, name: r.name)
                        Text(r.name).lineLimit(1).minimumScaleFactor(0.8)
                    }.frame(maxWidth: .infinity, alignment: .leading)
                    Text(r.played).frame(width: 28)
                    Text(s.style == "wdl" ? "\(r.won)-\(r.drawn)-\(r.lost)" : "\(r.won)-\(r.lost)").frame(width: 58)
                    Text(r.points).font(F.body(12.5, .heavy)).frame(width: 30)
                }
                .font(F.body(12, r.aek || isO ? .heavy : .medium)).monospacedDigit()
                .foregroundStyle(r.aek ? C.gold : (isO ? C.text : C.text2))
                .padding(.vertical, 6).padding(.horizontal, 4)
                .background(RoundedRectangle(cornerRadius: 8).fill(r.aek ? C.gold.opacity(0.12) : (isO ? C.panel3 : .clear)))
            }
        }
    }
}

// MARK: - «Πριν τη σέντρα»

struct PreMatchSection: View {
    let d: MatchDetail
    @StateObject private var a = MatchAround()
    @State private var ha = "" // φόρμα: "" όλα · h εντός · a εκτός
    @Environment(\.openURL) var openURL
    var m: MatchCard { d.card }

    var body: some View {
        let w = MatchWords.kick(m.sport)
        let chans = Channels.parse(m.broadcast)
        VStack(alignment: .leading, spacing: 12) {
            SectionTitle(text: w.0)
            if let ko = m.kickoffDate, ko > Date() {
                ExtraBox(title: w.1 + " σε") { KickCountdown(date: ko) }
            }
            if !chans.isEmpty {
                ExtraBox(title: "Πού θα το δεις") {
                    VStack(spacing: 8) { ForEach(chans, id: \.self) { c in channelTile(c) } }
                }
            }
            ExtraBox(title: "Πληροφορίες") {
                VStack(spacing: 0) {
                    if !m.date.isEmpty { info(w.1, MatchWords.longDay(m.date) + (m.time.isEmpty ? "" : " · " + m.time)) }
                    if !m.venue.isEmpty { info("Γήπεδο", m.venue) }
                    if !m.competition.isEmpty {
                        HStack(spacing: 10) {
                            Text("Διοργάνωση").font(F.body(12)).foregroundStyle(C.muted).frame(width: 96, alignment: .leading)
                            let lg = CompLogo.url(m.competition, sport: m.sport)
                            if !lg.isEmpty { PlainLogo(url: lg, h: 22, maxW: 40) }
                            Text([m.competition, m.matchday].filter { !$0.isEmpty }.joined(separator: " · ")).font(F.body(13, .bold)).foregroundStyle(C.text)
                            Spacer(minLength: 0)
                        }.padding(.vertical, 7)
                    }
                    if !d.referee.isEmpty { info("Διαιτητής", d.referee) }
                    info("Τμήμα", MatchWords.squad(m))
                    if !m.venue.isEmpty, let u = URL(string: "http://maps.apple.com/?daddr=" + Api.q(m.venue)) {
                        Button { haptic(); openURL(u) } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "map.fill").font(.system(size: 14))
                                Text("Οδηγίες για το γήπεδο").font(F.body(13, .heavy))
                                Spacer(minLength: 0)
                                Image(systemName: "arrow.up.right").font(.system(size: 12, weight: .bold))
                            }
                            .foregroundStyle(C.gold).padding(12)
                            .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(C.gold.opacity(0.1)))
                        }.buttonStyle(.plain).padding(.top, 8)
                    }
                }
            }
            if !a.form.isEmpty {
                ExtraBox(title: "Φόρμα ΑΕΚ", sub: MatchWords.squad(m)) {
                    HStack(spacing: 6) {
                        seg("Όλα", ""); seg("Εντός", "h"); seg("Εκτός", "a"); Spacer(minLength: 0)
                        HStack(spacing: 3) {
                            ForEach(a.form.prefix(5), id: \.id) { x in
                                let r = x.aekWon
                                Circle().fill(r == nil ? C.muted : (r! ? C.win : C.live)).frame(width: 8, height: 8)
                            }
                        }
                    }
                    let f = a.form.filter { ha.isEmpty || ($0.aek == "home") == (ha == "h") }
                    if f.isEmpty { Text("Κανένας αγώνας με αυτό το φίλτρο.").font(F.body(12)).foregroundStyle(C.muted) }
                    VStack(spacing: 0) { ForEach(f, id: \.id) { x in MiniScoreRow(m: x) } }
                }
            }
            if !a.h2h.isEmpty {
                ExtraBox(title: "Τελευταίες αναμετρήσεις") { VStack(spacing: 0) { ForEach(a.h2h, id: \.id) { x in MiniScoreRow(m: x) } } }
            }
            if let t = a.table {
                ExtraBox(title: "Βαθμολογία", sub: t.title) { MiniTable(s: t, m: m) }
            }
        }
        .padding(.horizontal, screenPad)
        .task(id: m.id) { await a.load(m, wantNext: false) }
    }

    func info(_ k: String, _ v: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Text(k).font(F.body(12)).foregroundStyle(C.muted).frame(width: 96, alignment: .leading)
            Text(v).font(F.body(13, .bold)).foregroundStyle(C.text).frame(maxWidth: .infinity, alignment: .leading)
        }.padding(.vertical, 7)
    }
    func seg(_ t: String, _ v: String) -> some View {
        Button { haptic(); ha = v } label: {
            Text(t).font(F.body(11.5, .heavy)).foregroundStyle(ha == v ? C.ink : C.text2)
                .padding(.horizontal, 10).padding(.vertical, 5)
                .background(Capsule().fill(ha == v ? C.gold : C.panel2))
        }.buttonStyle(.plain)
    }
    func channelTile(_ c: TVChannel) -> some View {
        Button {
            if let u = URL(string: c.url), !c.url.isEmpty { haptic(); openURL(u) }
        } label: {
            HStack(spacing: 10) {
                ChannelBadge(c: c, h: 26)
                Spacer(minLength: 0)
                Text(m.time.isEmpty ? "Ζωντανά" : "Ζωντανά · " + m.time).font(F.body(11.5)).foregroundStyle(C.muted)
                if !c.url.isEmpty { Image(systemName: "arrow.up.right").font(.system(size: 11, weight: .bold)).foregroundStyle(C.gold) }
            }
            .padding(.horizontal, 12).padding(.vertical, 10)
            .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(C.panel2))
        }.buttonStyle(.plain).disabled(c.url.isEmpty)
    }
}

// MARK: - «Μετά τον αγώνα» (αγώνες «Μόνο αποτέλεσμα» μετά τη λήξη — Match Center 1.148)

struct PostMatchSection: View {
    let d: MatchDetail
    @StateObject private var a = MatchAround()
    var m: MatchCard { d.card }
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionTitle(text: "Μετά τον αγώνα")
            ExtraBox(title: "Επόμενος αγώνας", sub: MatchWords.squad(m)) {
                if let n = a.next {
                    NavigationLink(value: Route.match(n.id)) {
                        VStack(spacing: 10) {
                            if !n.competition.isEmpty {
                                Text([n.competition, n.matchday].filter { !$0.isEmpty }.joined(separator: " · ").upperGr)
                                    .font(F.body(10.5, .heavy)).foregroundStyle(C.muted).lineLimit(1)
                            }
                            HStack(spacing: 8) {
                                team(n.homeLogo, n.home, n.aek == "home")
                                Text("VS").font(F.disp(22)).foregroundStyle(C.line2)
                                team(n.awayLogo, n.away, n.aek == "away")
                            }
                            Text(Fmt.dayHeader(n.date) + (n.time.isEmpty ? "" : " · " + n.time)).font(F.body(11.5, .heavy)).foregroundStyle(C.text2)
                            if !n.venue.isEmpty { Text(n.venue).font(F.body(11.5)).foregroundStyle(C.muted) }
                            let ch = Channels.parse(n.broadcast)
                            if !ch.isEmpty { HStack(spacing: 10) { ForEach(ch, id: \.self) { ChannelBadge(c: $0, h: 18) } } }
                            if let ko = n.kickoffDate, ko > Date() { KickCountdown(date: ko) }
                        }
                        .frame(maxWidth: .infinity)
                    }.buttonStyle(.plain)
                } else {
                    Text("Δεν έχει οριστεί ακόμα ο επόμενος αγώνας.").font(F.body(12.5)).foregroundStyle(C.muted)
                }
            }
            if let t = a.table { ExtraBox(title: "Βαθμολογία", sub: t.title) { MiniTable(s: t, m: m) } }
        }
        .padding(.horizontal, screenPad)
        .task(id: m.id) { await a.load(m, wantNext: true) }
    }
    func team(_ logo: String, _ name: String, _ aek: Bool) -> some View {
        VStack(spacing: 6) {
            TeamLogo(url: logo, size: 40, name: name)
            Text(name.upperGr).font(F.body(12, .heavy)).foregroundStyle(aek ? C.gold : C.text).multilineTextAlignment(.center).lineLimit(2).minimumScaleFactor(0.7)
        }.frame(maxWidth: .infinity)
    }
}
