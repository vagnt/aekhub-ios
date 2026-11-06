import Foundation

// Όλα τα δεδομένα έρχονται από το aekhub.gr (/wp-json/aekhub/v1/app/*) — ΙΔΙΟ API με το app Android.
// Ανεκτική ανάγνωση JSON: αριθμός αντί για κείμενο (ή το αντίστροφο), null ή πεδίο που λείπει
// δεν χαλάνε ποτέ την οθόνη — παίρνουν απλώς την προεπιλογή.

struct J {
    let v: Any?
    init(_ v: Any?) { self.v = (v is NSNull) ? nil : v }
    static func parse(_ data: Data) -> J? {
        guard let o = try? JSONSerialization.jsonObject(with: data, options: [.fragmentsAllowed]) else { return nil }
        return J(o)
    }
    subscript(_ k: String) -> J { J((v as? [String: Any])?[k]) }
    var exists: Bool { v != nil }
    var isObject: Bool { v is [String: Any] }
    var str: String {
        switch v {
        case let s as String: return s
        case let n as NSNumber:
            if CFGetTypeID(n) == CFBooleanGetTypeID() { return n.boolValue ? "1" : "" }
            let d = n.doubleValue
            return d == d.rounded() && abs(d) < 1e15 ? String(Int64(d)) : String(d)
        default: return ""
        }
    }
    var int: Int {
        if let n = v as? NSNumber { return n.intValue }
        if let s = v as? String { return Int(s) ?? Int(Double(s) ?? 0) }
        return 0
    }
    var double: Double {
        if let n = v as? NSNumber { return n.doubleValue }
        if let s = v as? String { return Double(s.replacingOccurrences(of: ",", with: ".")) ?? 0 }
        return 0
    }
    var bool: Bool {
        if let n = v as? NSNumber { return n.boolValue }
        if let s = v as? String { return s == "1" || s == "true" }
        return false
    }
    func bool(_ def: Bool) -> Bool { exists ? bool : def }
    var arr: [J] { (v as? [Any])?.map { J($0) } ?? [] }
    var strs: [String] { arr.map(\.str) }
    func list<T>(_ f: (J) -> T) -> [T] { arr.map(f) }
    func opt<T>(_ f: (J) -> T) -> T? { isObject ? f(self) : nil }
}

struct Category: Identifiable, Hashable { let slug, name, icon: String; var id: String { slug }
    init(_ j: J) { slug = j["slug"].str; name = j["name"].str; icon = j["icon"].str.isEmpty ? "eagle" : j["icon"].str }
}
struct SportItem: Hashable { let key, name: String; init(_ j: J) { key = j["key"].str; name = j["name"].str } }
struct Social: Hashable { let key, label, url, handle: String
    init(_ j: J) { key = j["key"].str; label = j["label"].str; url = j["url"].str; handle = j["handle"].str }
}
struct CalGroup: Hashable { let k, l, c: String; let n: Int
    init(_ j: J) { k = j["k"].str; l = j["l"].str; c = j["c"].str; n = j["n"].int }
}
struct CalConfig { let feed, name: String; let groups: [CalGroup]
    init(_ j: J) { feed = j["feed"].str; name = j["name"].str.isEmpty ? "AEK Hub" : j["name"].str; groups = j["groups"].list(CalGroup.init) }
}
struct AppConfig {
    let site: String
    let categories: [Category]
    let sports: [SportItem]
    let socials: [Social]
    let calendar: CalConfig?
    init(_ j: J) {
        site = j["site"].str; categories = j["categories"].list(Category.init); sports = j["sports"].list(SportItem.init)
        socials = j["socials"].list(Social.init); calendar = j["calendar"].opt(CalConfig.init)
    }
}

struct PostCard: Identifiable, Hashable {
    let id: Int
    let title, excerpt, date, image, category, link: String
    let video: Bool
    init(_ j: J) {
        id = j["id"].int; title = j["title"].str.htmlDecoded; excerpt = j["excerpt"].str.htmlDecoded; date = j["date"].str
        image = j["image"].str; category = j["category"].str.htmlDecoded; link = j["link"].str; video = j["video"].bool
    }
}

struct Feed { let page, pages: Int; let featured: PostCard?; let items: [PostCard]
    init(_ j: J) { page = max(1, j["page"].int); pages = max(1, j["pages"].int); featured = j["featured"].opt(PostCard.init); items = j["items"].list(PostCard.init) }
}

struct VideoInfo { let url, embed, html, thumb: String
    init(_ j: J) { url = j["url"].str; embed = j["embed"].str; html = j["html"].str; thumb = j["thumb"].str }
}

struct Post: Identifiable {
    let id: Int
    let title, excerpt, date, image, imageCaption, category, link, author, authorAvatar, html: String
    let minutes: Int
    let video: Bool
    let videoInfo: VideoInfo?
    init(_ j: J) {
        id = j["id"].int; title = j["title"].str.htmlDecoded; excerpt = j["excerpt"].str.htmlDecoded; date = j["date"].str
        image = j["image"].str; imageCaption = j["imageCaption"].str; category = j["category"].str.htmlDecoded; link = j["link"].str
        author = j["author"].str; authorAvatar = j["authorAvatar"].str; html = j["html"].str
        minutes = max(1, j["minutes"].int); video = j["video"].bool; videoInfo = j["videoInfo"].opt(VideoInfo.init)
    }
}

/// Ρολόι αγώνα: b = λεπτά που είχαν περάσει στο s (ms epoch), l = διάρκεια περιόδου.
struct Clock: Hashable { let b, s, l: Double
    init(_ j: J) { b = j["b"].double; s = j["s"].double; l = j["l"].exists ? j["l"].double : 45 }
}

/// Κοινά πεδία κάρτας αγώνα και σελίδας αγώνα.
struct MatchCard: Identifiable, Hashable {
    let id: Int
    let sport, sportLabel, status, statusLabel, phase, minute, date, time: String
    let live: Bool
    let clock: Clock?
    let home, away, homeLogo, awayLogo, homeColor, awayColor, homeNum, awayNum: String
    let scoreHome, scoreAway, penHome, penAway: String
    let competition, matchday, venue, broadcast, aek, link, kickoff: String

    init(_ j: J) {
        id = j["id"].int; sport = j["sport"].str.isEmpty ? "football" : j["sport"].str; sportLabel = j["sportLabel"].str
        status = j["status"].str.isEmpty ? "upcoming" : j["status"].str; statusLabel = j["statusLabel"].str; phase = j["phase"].str
        live = j["live"].bool; minute = j["minute"].str; clock = j["clock"].opt(Clock.init); date = j["date"].str; time = j["time"].str
        home = j["home"].str; away = j["away"].str; homeLogo = j["homeLogo"].str; awayLogo = j["awayLogo"].str
        homeColor = j["homeColor"].str; awayColor = j["awayColor"].str; homeNum = j["homeNum"].str; awayNum = j["awayNum"].str
        scoreHome = j["scoreHome"].str; scoreAway = j["scoreAway"].str; penHome = j["penHome"].str; penAway = j["penAway"].str
        competition = j["competition"].str; matchday = j["matchday"].str; venue = j["venue"].str; broadcast = j["broadcast"].str
        aek = j["aek"].str; link = j["link"].str; kickoff = j["kickoff"].str
    }

    var finished: Bool { status == "finished" }
    var upcoming: Bool { status == "upcoming" }
    var postponed: Bool { status == "postponed" }
    var hasScore: Bool { !scoreHome.isEmpty || !scoreAway.isEmpty }

    /// nil = ισοπαλία / άγνωστο, true = νίκη ΑΕΚ, false = ήττα
    var aekWon: Bool? {
        guard let h = Int(scoreHome), let a = Int(scoreAway), !aek.isEmpty else { return nil }
        var mine = aek == "home" ? h : a, their = aek == "home" ? a : h
        if mine == their, let ph = Int(penHome), let pa = Int(penAway) { mine = aek == "home" ? ph : pa; their = aek == "home" ? pa : ph }
        return mine == their ? nil : mine > their
    }

    /// Ώρα σέντρας (ώρα Ελλάδας): kickoff ISO αν υπάρχει, αλλιώς date + time.
    var kickoffDate: Date? {
        if !kickoff.isEmpty, let d = Fmt.iso(kickoff) { return d }
        return Fmt.athens(date: date, time: time)
    }
}

struct MatchList { let today, from, to: String; let items: [MatchCard]
    init(_ j: J) { today = j["today"].str; from = j["from"].str; to = j["to"].str; items = j["items"].list(MatchCard.init) }
}

struct MatchEvent: Hashable { let minute, type, label, team, text, score: String
    init(_ j: J) { minute = j["minute"].str; type = j["type"].str; label = j["label"].str; team = j["team"].str; text = j["text"].str; score = j["score"].str }
}
struct StatRow: Hashable { let label, type, home, away: String
    init(_ j: J) { label = j["label"].str; type = j["type"].str; home = j["home"].str; away = j["away"].str }
}
struct PeriodScore: Hashable { let label, home, away: String
    init(_ j: J) { label = j["label"].str; home = j["home"].str; away = j["away"].str }
}
struct EventGroup: Hashable { let label, score: String; let open: Bool; let events: [MatchEvent]
    init(_ j: J) { label = j["label"].str; score = j["score"].str; open = j["open"].bool; events = j["events"].list(MatchEvent.init) }
}
struct Player: Hashable { let number, name, role: String; let captain: Bool; let rating: Double
    init(_ j: J) { number = j["number"].str; name = j["name"].str; role = j["role"].str; captain = j["captain"].bool; rating = j["rating"].double }
}
struct StreamInfo { let url, embed, thumb, label, kicker, state: String
    init(_ j: J) { url = j["url"].str; embed = j["embed"].str; thumb = j["thumb"].str; label = j["label"].str; kicker = j["kicker"].str; state = j["state"].str }
}
struct Sponsor { let label, name, logo, note, click, view: String; let h, w: Int
    init(_ j: J) {
        label = j["label"].str.isEmpty ? "Powered by" : j["label"].str; name = j["name"].str; logo = j["logo"].str; note = j["note"].str
        click = j["click"].str; view = j["view"].str; h = j["h"].exists ? j["h"].int : 42; w = j["w"].int
    }
}
struct Highlight: Hashable { let title, url, embed, thumb: String
    init(_ j: J) { title = j["title"].str; url = j["url"].str; embed = j["embed"].str; thumb = j["thumb"].str }
}
struct PitchPlayer: Hashable { let number, name, out, inn: String; let x, y, rating: Double; let goals: Int; let yellow, red: Bool
    init(_ j: J) {
        number = j["number"].str; name = j["name"].str; out = j["out"].str; inn = j["in"].str
        x = j["x"].exists ? j["x"].double : 50; y = j["y"].exists ? j["y"].double : 50; rating = j["rating"].double
        goals = j["goals"].int; yellow = j["yellow"].bool; red = j["red"].bool
    }
}
struct Pitch { let home, away: [PitchPlayer]; let formationHome, formationAway: String
    init(_ j: J) { home = j["home"].list(PitchPlayer.init); away = j["away"].list(PitchPlayer.init); formationHome = j["formationHome"].str; formationAway = j["formationAway"].str }
}
struct RatingRow: Hashable { let number, name: String; let rating: Double
    init(_ j: J) { number = j["number"].str; name = j["name"].str; rating = j["rating"].double }
}
struct Potm { let name, number, team, side, rating: String
    init(_ j: J) { name = j["name"].str; number = j["number"].str; team = j["team"].str; side = j["side"].str; rating = j["rating"].str }
}
struct BoxRow: Hashable { let number, name: String; let min, pts, reb, ast: Int; let starter: Bool
    init(_ j: J) { number = j["number"].str; name = j["name"].str; min = j["min"].int; pts = j["pts"].int; reb = j["reb"].int; ast = j["ast"].int; starter = j["starter"].bool }
}
struct MatchExtra {
    let resultOnly: Bool
    let htScore: String
    let potm: Potm?
    let ratingsHome, ratingsAway: [RatingRow]
    let boxHome, boxAway: [BoxRow]
    let colorHome, colorAway, boxSrc: String
    init(_ j: J) {
        colorHome = j["colorHome"].str; colorAway = j["colorAway"].str; boxSrc = j["box"]["src"].str
        resultOnly = j["resultOnly"].bool; htScore = j["htScore"].str; potm = j["potm"].opt(Potm.init)
        ratingsHome = j["ratings"]["home"].list(RatingRow.init); ratingsAway = j["ratings"]["away"].list(RatingRow.init)
        boxHome = j["box"]["home"].list(BoxRow.init); boxAway = j["box"]["away"].list(BoxRow.init)
    }
    var hasRatings: Bool { !ratingsHome.isEmpty || !ratingsAway.isEmpty }
    var hasBox: Bool { !boxHome.isEmpty || !boxAway.isEmpty }
    var hasAnalysis: Bool { !resultOnly && (hasRatings || hasBox) }
}

struct MatchDetail: Identifiable {
    let card: MatchCard
    var id: Int { card.id }
    let events: [MatchEvent]
    let groups: [EventGroup]
    let stats: [StatRow]
    let periods: [PeriodScore]
    let lineupHome, lineupAway, subsHome, subsAway: [Player]
    let coachHome, coachAway, referee: String
    let timeline: Bool
    let liveScore: Bool
    let scorersHome, scorersAway: [String]
    let stream: StreamInfo?
    let highlights: [Highlight]
    let sponsor: Sponsor?
    let pitch: Pitch?
    let extra: MatchExtra?
    let bg: String
    init(_ j: J) {
        card = MatchCard(j); bg = j["bg"].str; events = j["events"].list(MatchEvent.init); groups = j["groups"].list(EventGroup.init)
        stats = j["stats"].list(StatRow.init); periods = j["periods"].list(PeriodScore.init)
        lineupHome = j["lineupHome"].list(Player.init); lineupAway = j["lineupAway"].list(Player.init)
        subsHome = j["subsHome"].list(Player.init); subsAway = j["subsAway"].list(Player.init)
        coachHome = j["coachHome"].str; coachAway = j["coachAway"].str; referee = j["referee"].str
        timeline = j["timeline"].bool(true); liveScore = j["liveScore"].bool(true); scorersHome = j["scorersHome"].strs; scorersAway = j["scorersAway"].strs
        stream = j["stream"].opt(StreamInfo.init); highlights = j["highlights"].list(Highlight.init)
        sponsor = j["sponsor"].opt(Sponsor.init); pitch = j["pitch"].opt(Pitch.init); extra = j["extra"].opt(MatchExtra.init)
    }
    var resultOnly: Bool { extra?.resultOnly ?? false }
    var hasLineups: Bool { !lineupHome.isEmpty || !lineupAway.isEmpty }
}

struct HomeSection: Identifiable { let slug, name, icon: String; let items: [PostCard]; var id: String { slug }
    init(_ j: J) { slug = j["slug"].str; name = j["name"].str; icon = j["icon"].str; items = j["items"].list(PostCard.init) }
}
struct Breaking { let text, url, label: String
    init(_ j: J) { text = j["text"].str; url = j["url"].str; label = j["label"].str.isEmpty ? "ΕΚΤΑΚΤΟ" : j["label"].str }
}
struct LiveHero { let type: String; let id: Int; let title, image: String; let match: MatchCard?
    init(_ j: J) { type = j["type"].str; id = j["id"].int; title = j["title"].str; image = j["image"].str; match = j["match"].opt(MatchCard.init) }
}
struct HomeData {
    let next: MatchCard?
    let liveHero: LiveHero?
    let breaking: Breaking?
    let socials: [Social]
    let featured: PostCard?
    let top: [PostCard]
    let matches: [MatchCard]
    let sections: [HomeSection]
    init(_ j: J) {
        next = j["next"].opt(MatchCard.init); liveHero = j["liveHero"].opt(LiveHero.init); breaking = j["breaking"].opt(Breaking.init)
        socials = j["socials"].list(Social.init); featured = j["featured"].opt(PostCard.init); top = j["top"].list(PostCard.init)
        matches = j["matches"].list(MatchCard.init); sections = j["sections"].list(HomeSection.init)
    }
}

struct StandingRow: Hashable { let pos: Int; let name, logo, played, won, drawn, lost, gf, ga, points: String; let aek: Bool
    init(_ j: J) {
        pos = j["pos"].int; name = j["name"].str; logo = j["logo"].str; played = j["played"].str; won = j["won"].str; drawn = j["drawn"].str
        lost = j["lost"].str; gf = j["gf"].str; ga = j["ga"].str; points = j["points"].str; aek = j["aek"].bool
    }
}
struct Zone: Hashable { let from, to: Int; let label, color: String
    init(_ j: J) { from = j["from"].int; to = j["to"].int; label = j["label"].str; color = j["color"].str.isEmpty ? "#F9CF1C" : j["color"].str }
}
struct Standing: Identifiable, Hashable { let id: Int; let title, sport, league, style, leagueLogo: String; let zones: [Zone]; let rows: [StandingRow]
    init(_ j: J) {
        id = j["id"].int; title = j["title"].str; sport = j["sport"].str; league = j["league"].str
        style = j["style"].str.isEmpty ? "wdl" : j["style"].str; leagueLogo = j["leagueLogo"].str
        zones = j["zones"].list(Zone.init); rows = j["rows"].list(StandingRow.init)
    }
}

struct EventUpdate: Identifiable, Hashable { let id: Int; let time, minute, type, typeLabel, title, text, video, embed, thumb, link: String; let highlight: Bool
    init(_ j: J) {
        id = j["id"].int; time = j["time"].str; minute = j["minute"].str; type = j["type"].str; typeLabel = j["typeLabel"].str
        title = j["title"].str; text = j["text"].str; video = j["video"].str; embed = j["embed"].str; thumb = j["thumb"].str
        link = j["link"].str; highlight = j["highlight"].bool
    }
}
struct EventDetail { let id: Int; let title, image, statusLabel: String; let live: Bool; let updates: [EventUpdate]
    init(_ j: J) { id = j["id"].int; title = j["title"].str; image = j["image"].str; statusLabel = j["statusLabel"].str; live = j["live"].bool; updates = j["updates"].list(EventUpdate.init) }
}
