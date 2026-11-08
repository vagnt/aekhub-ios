import Foundation
import UserNotifications
import BackgroundTasks
import UIKit

/// 🔔 Ειδοποιήσεις ΧΩΡΙΣ push (δωρεάν λογαριασμός Apple):
/// - Υπενθύμιση 30′ πριν: προγραμματίζεται στο ίδιο το κινητό → έρχεται ΠΑΝΤΑ, ακόμα και με κλειστό app.
/// - Σέντρα / γκολ / ημίχρονο / τελικό / νέα άρθρα: το app ελέγχει όσο είναι ανοιχτό (κάθε 15″ σε live) και στο
///   παρασκήνιο όποτε του επιτρέψει το iOS (μπορεί να αργήσουν λεπτά). Με λογαριασμό Developer → κανονικό push.
@MainActor
final class Notifier: NSObject, UNUserNotificationCenterDelegate {
    static let shared = Notifier()
    static let bgId = "gr.aekhub.app.refresh"
    private let center = UNUserNotificationCenter.current()
    private let d = UserDefaults.standard
    private var lastCheck = Date.distantPast

    func setup() {
        center.delegate = self
        BGTaskScheduler.shared.register(forTaskWithIdentifier: Notifier.bgId, using: nil) { task in
            Task { @MainActor in
                Notifier.shared.scheduleBG()
                let ok = await Notifier.shared.refresh(force: true)
                task.setTaskCompleted(success: ok)
            }
            task.expirationHandler = { task.setTaskCompleted(success: false) }
        }
    }

    func requestPermission() async -> Bool {
        (try? await center.requestAuthorization(options: [.alert, .sound, .badge])) ?? false
    }
    func status() async -> UNAuthorizationStatus { await center.notificationSettings().authorizationStatus }

    /// Επόμενος έλεγχος στο παρασκήνιο (το iOS αποφασίζει πότε· ζητάμε ~15′)
    func scheduleBG() {
        let r = BGAppRefreshTaskRequest(identifier: Notifier.bgId)
        r.earliestBeginDate = Date(timeIntervalSinceNow: 15 * 60)
        try? BGTaskScheduler.shared.submit(r)
    }

    /// Φέρνει αγώνες (και νέα, αν τα θέλει) και ελέγχει για αλλαγές. Από οθόνες: το πολύ κάθε 10″.
    @discardableResult
    func refresh(force: Bool = false) async -> Bool {
        if !force && Date().timeIntervalSince(lastCheck) < 10 { return true }
        lastCheck = Date()
        guard let list = try? await Api.shared.matches() else { return false }
        check(list.items)
        if Prefs.shared.news, Prefs.shared.all, let h = try? await Api.shared.home() { checkNews(h) }
        return true
    }

    // MARK: Αγώνες

    private struct St: Codable { var st: String; var h: String; var a: String; var live: Bool }

    func check(_ items: [MatchCard]) {
        let p = Prefs.shared
        var state = (try? JSONDecoder().decode([String: St].self, from: d.data(forKey: "n_state") ?? Data())) ?? [:]
        let first = state.isEmpty
        LiveActivities.shared.prefetch(items)
        for m in items {
            if m.live || m.finished { LiveActivities.shared.update(m) }
            let key = String(m.id)
            let now = St(st: m.status, h: m.scoreHome, a: m.scoreAway, live: m.live)
            defer { state[key] = now }
            guard !first, let prev = state[key] else { continue }
            if prev.st == now.st && prev.h == now.h && prev.a == now.a && prev.live == now.live { continue }
            let sp = m.sport
            // Σέντρα
            if !prev.live && m.live && (prev.st == "upcoming" || prev.st == "prematch") && p.wants(sp, Kinds.startend, match: m.id) {
                post(m, title: (sp.contains("football") ? "Σέντρα" : "Ξεκίνησε") + " · " + line(m, score: false), body: [m.competition, m.broadcast.isEmpty ? "" : "📺 " + m.broadcast].filter { !$0.isEmpty }.joined(separator: " · "), aek: false)
            }
            // Σκορ (γκολ / σετ)
            let ph = Int(prev.h) ?? 0, pa = Int(prev.a) ?? 0, nh = Int(now.h) ?? 0, na = Int(now.a) ?? 0
            if m.live || m.finished, (nh != ph || na != pa), !Kinds.noGoals.contains(sp), p.wants(sp, Kinds.goals, match: m.id) {
                let up = nh + na > ph + pa
                let side = nh != ph ? "home" : "away"
                let vb = sp.hasPrefix("volleyball")
                let t = up ? (vb ? "Τέλος σετ" : "Γκολ") : (vb ? "Διόρθωση σκορ" : "Ακυρώθηκε γκολ")
                post(m, title: t + " · " + line(m, mark: up ? side : ""), body: m.competition, aek: side == m.aek && up)
            }
            // Ημίχρονο / τέλος περιόδου
            if prev.st != now.st, ["halftime", "ht", "break", "eth"].contains(now.st), p.wants(sp, Kinds.startend, match: m.id) {
                post(m, title: (m.statusLabel.isEmpty ? "Ημίχρονο" : m.statusLabel) + " · " + line(m), body: m.competition, aek: false)
            }
            // Τελικό
            if prev.st != "finished" && m.finished && p.wants(sp, Kinds.startend, match: m.id) {
                var t = "Τελικό · " + line(m)
                if !m.penHome.isEmpty { t += " (πέν. \(m.penHome)–\(m.penAway))" }
                let w = m.aekWon
                post(m, title: t, body: w == true ? "Νίκη για την Ένωση! 💛🖤" : m.competition, aek: false)
            }
        }
        // Κράτα μόνο όσους βλέπουμε ακόμα
        let ids = Set(items.map { String($0.id) })
        state = state.filter { ids.contains($0.key) }
        if let data = try? JSONEncoder().encode(state) { d.set(data, forKey: "n_state") }
        scheduleReminders(items)
    }

    /// «ΑΕΚ [1]–0 Παναθηναϊκός» (σε [ ] το σκορ της ομάδας που σκόραρε)
    private func line(_ m: MatchCard, score: Bool = true, mark: String = "") -> String {
        if !score || Prefs.shared.spoiler { return "\(m.home) – \(m.away)" }
        let h = mark == "home" ? "[\(m.scoreHome)]" : m.scoreHome
        let a = mark == "away" ? "[\(m.scoreAway)]" : m.scoreAway
        return "\(m.home) \(h)–\(a) \(m.away)"
    }

    private func post(_ m: MatchCard, title: String, body: String, aek: Bool) {
        if Push.shared.on { return } // έρχονται από τον server (push)
        if Prefs.shared.isQuiet() && !(aek && Prefs.shared.quietAek) { return }
        let c = UNMutableNotificationContent()
        c.title = Sports.emoji(m.sport) + " " + title
        c.body = body
        c.sound = .default
        c.threadIdentifier = "m\(m.id)"
        c.userInfo = ["url": "aekhub://match/\(m.id)"]
        center.add(UNNotificationRequest(identifier: "m\(m.id)-\(UUID().uuidString.prefix(6))", content: c, trigger: nil))
    }

    /// ⏰ Υπενθύμιση 30′ πριν (τοπικά προγραμματισμένη → έρχεται και με κλειστό app)
    func scheduleReminders(_ items: [MatchCard]) {
        if Push.shared.on { return } // τις υπενθυμίσεις τις στέλνει ο server
        let p = Prefs.shared
        center.getPendingNotificationRequests { reqs in
            let old = reqs.map(\.identifier).filter { $0.hasPrefix("rem-") }
            Task { @MainActor in
                self.center.removePendingNotificationRequests(withIdentifiers: old)
                var n = 0
                for m in items where m.upcoming && n < 40 {
                    guard p.wants(m.sport, Kinds.reminder, match: m.id), let ko = m.kickoffDate else { continue }
                    let at = ko.addingTimeInterval(-30 * 60)
                    guard at > Date().addingTimeInterval(30) else { continue }
                    let c = UNMutableNotificationContent()
                    c.title = Sports.emoji(m.sport) + " Σε 30′ · \(m.home) – \(m.away)"
                    c.body = [m.time, m.competition, m.venue, m.broadcast.isEmpty ? "" : "📺 " + m.broadcast].filter { !$0.isEmpty }.joined(separator: " · ")
                    c.sound = .default
                    c.userInfo = ["url": "aekhub://match/\(m.id)"]
                    let comps = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: at)
                    self.center.add(UNNotificationRequest(identifier: "rem-\(m.id)", content: c, trigger: UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)))
                    n += 1
                }
            }
        }
    }

    // MARK: Νέα άρθρα

    func checkNews(_ h: HomeData) {
        if Push.shared.on { return }
        let p = Prefs.shared
        let posts = ([h.featured].compactMap { $0 } + h.top)
        guard let newest = posts.max(by: { $0.id < $1.id }) else { return }
        let last = d.integer(forKey: "n_last_post")
        d.set(max(last, newest.id), forKey: "n_last_post")
        guard last > 0 else { return }
        // μόνο το νεότερο νέο άρθρο (όχι καταιγισμός)
        let fresh = posts.filter { $0.id > last && (p.newsCats.isEmpty || p.newsCats.contains($0.category)) }.sorted { $0.id > $1.id }
        guard let a = fresh.first, !p.isQuiet() else { return }
        let c = UNMutableNotificationContent()
        c.title = a.category.isEmpty ? "AEK Hub" : a.category
        c.body = a.title
        c.sound = .default
        c.userInfo = ["url": "aekhub://post/\(a.id)"]
        center.add(UNNotificationRequest(identifier: "p\(a.id)", content: c, trigger: nil))
    }

    /// Ήρθε κανονικό push: σβήνουν οι τοπικά προγραμματισμένες υπενθυμίσεις (αλλιώς θα έρχονταν διπλές)
    func clearLocal() {
        center.getPendingNotificationRequests { reqs in
            let ids = reqs.map(\.identifier).filter { $0.hasPrefix("rem-") }
            UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ids)
        }
    }

    func test() {
        let c = UNMutableNotificationContent()
        c.title = "⚽ Δοκιμή · ΑΕΚ [1]–0 Αντίπαλος"
        c.body = "Έτσι θα φαίνονται οι ειδοποιήσεις του AEK Hub."
        c.sound = .default
        center.add(UNNotificationRequest(identifier: "test", content: c, trigger: UNTimeIntervalNotificationTrigger(timeInterval: 3, repeats: false)))
    }

    // MARK: Delegate

    // ⚠ ΜΑΘΗΜΑ (build 48: «πατάω την ειδοποίηση και κλείνει η εφαρμογή»): οι async εκδοχές αυτών των μεθόδων
    // καλούν το completion της Apple εκτός main thread (και το Firebase τις «τυλίγει») → crash. Πάντα completionHandler + main.
    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification,
                                            withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        // ⚽ Ήρθε ο σκόρερ (goalupd): αλλάζει αθόρυβα το κείμενο της ίδιας ειδοποίησης — χωρίς δεύτερο banner/ήχο
        if (notification.request.content.userInfo["kind"] as? String) == "goalupd" { completionHandler([.list]); return }
        completionHandler([.banner, .list, .sound])
    }

    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse,
                                            withCompletionHandler completionHandler: @escaping () -> Void) {
        let info = response.notification.request.content.userInfo
        // Τοπικές: url = aekhub://… · Push του server: match / post (ίδια δεδομένα με το Android· μπορεί να έρθουν ως κείμενο ή αριθμός)
        func num(_ k: String) -> Int { if let s = info[k] as? String { return Int(s) ?? 0 }; return (info[k] as? NSNumber)?.intValue ?? 0 }
        let url = info["url"] as? String ?? ""
        let target: URL? = url.hasPrefix("aekhub://") ? URL(string: url)
            : num("match") > 0 ? URL(string: "aekhub://match/\(num("match"))")
            : num("post") > 0 ? URL(string: "aekhub://post/\(num("post"))") : nil
        let web: URL? = target == nil ? URL(string: url).flatMap { $0.host?.contains("aekhub.gr") == true ? $0 : nil } : nil
        DispatchQueue.main.async {
            completionHandler()
            // Λίγη καθυστέρηση: αν η εφαρμογή ήταν κλειστή, πρώτα να στηθεί η οθόνη και μετά να ανοίξει ο αγώνας
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                Task { @MainActor in
                    if let target { AppState.shared.open(target) } else if let web { UIApplication.shared.open(web) }
                }
            }
        }
    }
}
