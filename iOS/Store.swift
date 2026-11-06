import Foundation
import SwiftUI

/// Ανώνυμο «αποτύπωμα συσκευής» (ίδια λογική με το Android): τυχαίος κωδικός, μία φορά.
enum Device {
    static var id: String {
        let d = UserDefaults.standard
        if let s = d.string(forKey: "deviceId") { return s }
        let s = UUID().uuidString.lowercased()
        d.set(s, forKey: "deviceId")
        return s
    }
    static var isPad: Bool { UIDevice.current.userInterfaceIdiom == .pad }
}

/// Ρυθμίσεις ειδοποιήσεων (ίδια είδη με το Android: goals · startend · reminder · cards)
enum Kinds {
    static let goals = "goals", startend = "startend", reminder = "reminder", cards = "cards"
    static let sports = ["football", "basketball", "volleyball", "handball", "women_football", "futsal", "waterpolo"]
    /// Ενεργά από την αρχή
    static let hot = ["football", "women_football", "basketball", "volleyball", "handball"]
    /// Αθλήματα χωρίς ειδοποίηση σε κάθε σκορ (μόνο φάσεις και τελικό)
    static let noGoals: Set<String> = ["basketball", "handball", "futsal", "waterpolo"]
    static func defaults() -> Set<String> {
        var s = Set<String>()
        for sp in sports { s.insert("\(sp):\(reminder)"); s.insert("\(sp):\(goals)"); s.insert("\(sp):\(startend)") }
        return s
    }
}

@MainActor
final class Prefs: ObservableObject {
    static let shared = Prefs()
    private let d = UserDefaults.standard

    @Published var all: Bool { didSet { d.set(all, forKey: "n_all") } }
    @Published var sports: Set<String> { didSet { d.set(Array(sports), forKey: "n_sports") } }
    @Published var kinds: Set<String> { didSet { d.set(Array(kinds), forKey: "n_kinds") } }
    @Published var news: Bool { didSet { d.set(news, forKey: "n_news") } }
    @Published var newsCats: Set<String> { didSet { d.set(Array(newsCats), forKey: "n_news_cats") } }
    @Published var quiet: Bool { didSet { d.set(quiet, forKey: "n_quiet") } }
    @Published var quietFrom: Int { didSet { d.set(quietFrom, forKey: "n_qf") } }
    @Published var quietTo: Int { didSet { d.set(quietTo, forKey: "n_qt") } }
    @Published var quietAek: Bool { didSet { d.set(quietAek, forKey: "n_qaek") } }
    @Published var spoiler: Bool { didSet { d.set(spoiler, forKey: "n_spoiler") } }
    @Published var matchAlerts: Set<Int> { didSet { d.set(Array(matchAlerts), forKey: "n_alerts") } }
    @Published var mutedMatches: Set<Int> { didSet { d.set(Array(mutedMatches), forKey: "n_muted") } }
    /// «Σίγαση για λίγο» (1 ώρα, 2 ώρες, ως το πρωί): ως πότε
    @Published var quietUntil: Double { didSet { d.set(quietUntil, forKey: "n_quntil") } }
    @Published var stats: Bool { didSet { d.set(stats, forKey: "stats_on") } }
    @Published var liveActivities: Bool { didSet { d.set(liveActivities, forKey: "n_la"); if !liveActivities { LiveActivities.shared.endAll() } } }
    @Published var saved: [PostCard] { didSet { saveSaved() } }
    /// Ιστορικό ανάγνωσης (τα 30 τελευταία άρθρα)
    @Published var history: [PostCard] { didSet { store(history, "history.json") } }
    /// Εξοικονόμηση δεδομένων: μικρότερες εικόνες
    @Published var dataSaver: Bool { didSet { d.set(dataSaver, forKey: "data_saver") } }
    @Published var introDone: Bool { didSet { d.set(introDone, forKey: "intro_done") } }

    init() {
        all = d.object(forKey: "n_all") as? Bool ?? true
        sports = Set(d.stringArray(forKey: "n_sports") ?? Kinds.hot)
        kinds = Set(d.stringArray(forKey: "n_kinds") ?? Array(Kinds.defaults()))
        news = d.object(forKey: "n_news") as? Bool ?? false
        newsCats = Set(d.stringArray(forKey: "n_news_cats") ?? [])
        quiet = d.bool(forKey: "n_quiet")
        quietFrom = d.object(forKey: "n_qf") as? Int ?? 60
        quietTo = d.object(forKey: "n_qt") as? Int ?? 480
        quietAek = d.object(forKey: "n_qaek") as? Bool ?? true
        spoiler = d.bool(forKey: "n_spoiler")
        matchAlerts = Set((d.array(forKey: "n_alerts") as? [Int]) ?? [])
        mutedMatches = Set((d.array(forKey: "n_muted") as? [Int]) ?? [])
        quietUntil = d.double(forKey: "n_quntil")
        stats = d.object(forKey: "stats_on") as? Bool ?? true
        liveActivities = d.object(forKey: "n_la") as? Bool ?? true
        introDone = d.bool(forKey: "intro_done")
        saved = []
        history = []
        dataSaver = d.bool(forKey: "data_saver")
        saved = loadSaved()
        history = read("history.json")
    }

    /// Θέλει ο χρήστης αυτό το είδος σε αυτό το άθλημα; (ή έχει πατήσει 🔔 στον συγκεκριμένο αγώνα)
    func wants(_ sport: String, _ kind: String, match: Int = 0) -> Bool {
        guard all else { return false }
        if match > 0 && matchAlerts.contains(match) { return true }
        if match > 0 && mutedMatches.contains(match) { return false }
        return sports.contains(sport) && kinds.contains("\(sport):\(kind)")
    }

    func toggleKind(_ sport: String, _ kind: String) {
        let k = "\(sport):\(kind)"
        if kinds.contains(k) { kinds.remove(k) } else { kinds.insert(k) }
    }

    /// 🔔 του αγώνα: ενεργό αν το ζήτησες για αυτόν ή ακολουθείς το άθλημα (και δεν το έκλεισες για αυτόν)
    func alertOn(_ m: MatchCard) -> Bool {
        all && (matchAlerts.contains(m.id) || (!mutedMatches.contains(m.id) && sports.contains(m.sport) && kinds.contains("\(m.sport):\(Kinds.reminder)")))
    }
    func toggleMatchAlert(_ m: MatchCard) {
        if alertOn(m) {
            if matchAlerts.contains(m.id) { matchAlerts.remove(m.id) }
            if alertOn(m) { mutedMatches.insert(m.id) }
        } else {
            mutedMatches.remove(m.id)
            matchAlerts.insert(m.id)
            if !all { all = true }
            Task { _ = await Notifier.shared.requestPermission() }
        }
        Task { await Notifier.shared.refresh(force: true) }
    }

    /// Ήσυχες ώρες τώρα; (και πέρα από τα μεσάνυχτα, π.χ. 23:00–07:00)
    func isQuiet(_ now: Date = Date()) -> Bool {
        if quietUntil > now.timeIntervalSince1970 { return true }
        guard quiet else { return false }
        let c = Fmt.cal.dateComponents([.hour, .minute], from: now)
        let m = (c.hour ?? 0) * 60 + (c.minute ?? 0)
        return quietFrom <= quietTo ? (m >= quietFrom && m < quietTo) : (m >= quietFrom || m < quietTo)
    }

    // MARK: Αποθηκευμένα άρθρα
    private var savedURL: URL { FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent("saved.json") }
    private func loadSaved() -> [PostCard] {
        guard let data = try? Data(contentsOf: savedURL), let j = J.parse(data) else { return [] }
        return j.list(PostCard.init)
    }
    private func saveSaved() {
        let arr: [[String: Any]] = saved.map { ["id": $0.id, "title": $0.title, "excerpt": $0.excerpt, "date": $0.date, "image": $0.image, "category": $0.category, "link": $0.link, "video": $0.video] }
        if let data = try? JSONSerialization.data(withJSONObject: arr) { try? data.write(to: savedURL, options: .atomic) }
    }
    private func fileURL(_ n: String) -> URL { FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent(n) }
    private func read(_ n: String) -> [PostCard] {
        guard let data = try? Data(contentsOf: fileURL(n)), let j = J.parse(data) else { return [] }
        return j.list(PostCard.init)
    }
    private func store(_ l: [PostCard], _ n: String) {
        let arr: [[String: Any]] = l.map { ["id": $0.id, "title": $0.title, "excerpt": $0.excerpt, "date": $0.date, "image": $0.image, "category": $0.category, "link": $0.link, "video": $0.video] }
        if let data = try? JSONSerialization.data(withJSONObject: arr) { try? data.write(to: fileURL(n), options: .atomic) }
    }
    func addHistory(_ p: PostCard) {
        var h = history.filter { $0.id != p.id }
        h.insert(p, at: 0)
        history = Array(h.prefix(30))
    }
    func isSaved(_ id: Int) -> Bool { saved.contains { $0.id == id } }
    func toggleSaved(_ p: PostCard) {
        if let i = saved.firstIndex(where: { $0.id == p.id }) { saved.remove(at: i) } else { saved.insert(p, at: 0) }
    }
}

extension Post {
    var card: PostCard { PostCard(J(["id": id, "title": title, "excerpt": excerpt, "date": date, "image": image, "category": category, "link": link, "video": video])) }
}
