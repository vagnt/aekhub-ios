import Foundation
import UIKit
import Combine
import FirebaseCore
import FirebaseMessaging

/// 🔔 Κανονικές ειδοποιήσεις push (λογαριασμός Apple Developer): ίδια «θέματα» (FCM topics) με το Android,
/// οπότε ο server (aekhub-app → `aekhub_app_push`) στέλνει ένα μήνυμα και φτάνει σε Android και iPhone.
///   m_<άθλημα>_goals | _startend | _cards | _reminder · match_<id> · news_breaking
/// Μόλις το iPhone πάρει token (υπογραφή με push), οι τοπικές ειδοποιήσεις του Notifier σταματούν (όχι διπλές).
/// Χωρίς push (sideload με δωρεάν λογαριασμό) δεν έρχεται token → συνεχίζει το τοπικό σύστημα.
@MainActor
final class Push: NSObject, MessagingDelegate {
    static let shared = Push()
    private let d = UserDefaults.standard
    private var bag = Set<AnyCancellable>()
    /// Το τελευταίο token FCM μένει αποθηκευμένο: όταν το iOS ξυπνά την εφαρμογή στο παρασκήνιο για ένα Live Activity
    /// που άνοιξε μόνο του (σέντρα), το Firebase δεν έχει προλάβει να δώσει token — χωρίς αυτό το activity δεν ενημερωνόταν
    private(set) var token: String? = UserDefaults.standard.string(forKey: "fcm_token")

    /// Έχουμε κανονικό push σε αυτή τη συσκευή;
    var on: Bool { d.bool(forKey: "push_on") }

    func setup() {
        guard Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist") != nil, FirebaseApp.app() == nil else { return }
        FirebaseApp.configure()
        Messaging.messaging().delegate = self
        UIApplication.shared.registerForRemoteNotifications()
        // Κάθε αλλαγή στις ρυθμίσεις ειδοποιήσεων → γράψιμο/ξεγράψιμο στα θέματα (με μικρή καθυστέρηση)
        Prefs.shared.objectWillChange
            .debounce(for: .seconds(1.5), scheduler: RunLoop.main)
            .sink { [weak self] _ in self?.sync(); self?.share(); LiveActivities.shared.syncStart() }
            .store(in: &bag)
        share()
    }

    /// Ρυθμίσεις που χρειάζεται το Notification Service Extension (ήσυχες ώρες, spoilers) → App Group
    func share() {
        guard let g = UserDefaults(suiteName: "group.gr.aekhub.app") else { return }
        let p = Prefs.shared
        g.set(p.quiet, forKey: "quiet"); g.set(p.quietFrom, forKey: "quietFrom"); g.set(p.quietTo, forKey: "quietTo")
        g.set(p.quietAek, forKey: "quietAek"); g.set(p.quietUntil, forKey: "quietUntil"); g.set(p.spoiler, forKey: "spoiler")
    }

    nonisolated func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        Task { @MainActor in
            guard let t = fcmToken, !t.isEmpty else { return }
            if t != self.token { self.d.removeObject(forKey: "push_topics") } // νέο token → ξαναγράψου σε όλα
            self.token = t
            self.d.set(t, forKey: "fcm_token")
            self.d.set(true, forKey: "push_on")
            Notifier.shared.clearLocal()
            self.sync()
            LiveActivities.shared.fcmReady()
        }
    }

    /// Τα θέματα που θέλει ο χρήστης (ίδια λογική με το Android Push.topicsFor)
    func topics() -> Set<String> {
        let p = Prefs.shared
        var s = Set<String>()
        guard p.all else { return s }
        for sp in p.sports {
            for k in [Kinds.goals, Kinds.startend, Kinds.cards, Kinds.reminder] where p.kinds.contains("\(sp):\(k)") {
                s.insert("m_\(sp)_\(k)")
            }
        }
        if p.news {
            // Φίλτρο κατηγοριών: ios_news_<slug> (ο server στέλνει εκεί κάθε άρθρο της κύριας κατηγορίας του)
            let cats = AppState.shared.config?.categories ?? []
            let slugs = p.newsCats.compactMap { n in cats.first { $0.name == n }?.slug }
            if p.newsCats.isEmpty || slugs.isEmpty { s.insert("news_breaking") }
            else { for sl in slugs { s.insert("ios_news_" + sl.lowercased().replacingOccurrences(of: #"[^a-z0-9_\-]"#, with: "_", options: .regularExpression)) } }
        }
        for m in p.matchAlerts { s.insert("match_\(m)") }
        return s
    }

    /// Γράφει/ξεγράφει μόνο τη διαφορά από την προηγούμενη φορά
    func sync() {
        guard on, token != nil else { return }
        let cur = Set(d.stringArray(forKey: "push_topics") ?? [])
        let want = topics()
        guard cur != want else { return }
        let m = Messaging.messaging()
        for t in want.subtracting(cur) {
            m.subscribe(toTopic: t) { e in if e == nil { Task { @MainActor in Push.shared.mark(t, true) } } }
        }
        for t in cur.subtracting(want) {
            m.unsubscribe(fromTopic: t) { e in if e == nil { Task { @MainActor in Push.shared.mark(t, false) } } }
        }
    }

    private func mark(_ t: String, _ add: Bool) {
        var s = Set(d.stringArray(forKey: "push_topics") ?? [])
        if add { s.insert(t) } else { s.remove(t) }
        d.set(Array(s), forKey: "push_topics")
    }

    /// 🔔 Δοκιμή από τον server (ίδιο με το Android): δείχνει πού σπάει (server, Google, κινητό)
    func serverTest() async -> String {
        guard let t = token else { return "Δεν υπάρχει token push σε αυτή τη συσκευή (εγκατάσταση χωρίς push)." }
        guard let u = URL(string: Api.base + "/push-test") else { return "" }
        var r = URLRequest(url: u); r.httpMethod = "POST"
        r.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        r.httpBody = ("token=" + Api.q(t)).data(using: .utf8)
        guard let res = try? await URLSession.shared.data(for: r), let j = J.parse(res.0) else { return "Δεν απάντησε ο server." }
        return j["ok"].bool ? "✓ Εστάλη — θα έρθει σε λίγα δευτερόλεπτα." : ("✗ " + j["error"].str)
    }
}
