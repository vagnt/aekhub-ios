import Foundation
import ActivityKit
import WidgetKit

/// Ξεκινά / ενημερώνει / κλείνει τα Live Activities των αγώνων (ρύθμιση «Live Activities» στο «Εγώ»).
/// Με push (λογαριασμός Developer): κάθε activity δίνει token στον server (`/app/la-token`) → ο server
/// στέλνει σκορ/κατάσταση μέσω Firebase ακόμα και με κλειστή εφαρμογή. iOS 17.2+: token «push-to-start» →
/// ο server το ανοίγει μόνος του όταν ξεκινά αγώνας που ακολουθείς.
@MainActor
final class LiveActivities {
    static let shared = LiveActivities()
    private var lastScore: [Int: String] = [:]
    private var watched = Set<String>()
    private var startToken: String?
    private var tokens: [Int: String] = [:]   // αγώνας → token activity (ξαναστέλνεται αν το FCM token ήρθε αργότερα)

    private func find(_ id: Int) -> Activity<LiveMatchAttributes>? {
        Activity<LiveMatchAttributes>.activities.first { $0.attributes.matchId == id }
    }

    /// Στο άνοιγμα του app (και όταν το iOS το ξυπνά για activity που ξεκίνησε με push)
    func observe() {
        Task.detached(priority: .background) { LiveLogos.trim() }
        for a in Activity<LiveMatchAttributes>.activities { watch(a) }
        Task { for await a in Activity<LiveMatchAttributes>.activityUpdates { self.watch(a) } }
        if #available(iOS 17.2, *) {
            Task {
                if let t = Activity<LiveMatchAttributes>.pushToStartToken { self.startToken = Self.hex(t); self.syncStart() }
                for await t in Activity<LiveMatchAttributes>.pushToStartTokenUpdates { self.startToken = Self.hex(t); self.syncStart() }
            }
        }
    }

    /// Παρακολουθεί token + τέλος ενός activity και τα λέει στον server
    private func watch(_ a: Activity<LiveMatchAttributes>) {
        guard !watched.contains(a.id) else { return }
        watched.insert(a.id)
        let mid = a.attributes.matchId
        // Λογότυπα χωρίς να ανοίξει ο χρήστης την εφαρμογή: όταν ο server ανοίγει το activity, το iOS ξυπνά το app στο
        // παρασκήνιο → κατεβάζουμε τα σήματα (links από τα attributes) και ξανασχεδιάζουμε το activity
        let at = a.attributes
        if LiveLogos.image(at.home) == nil || LiveLogos.image(at.away) == nil {
            Task.detached(priority: .utility) {
                await LiveLogos.cache(at.home, at.hlogo ?? "")
                await LiveLogos.cache(at.away, at.alogo ?? "")
                if LiveLogos.image(at.home) != nil || LiveLogos.image(at.away) != nil { await a.update(a.content) }
            }
        }
        Task {
            for await t in a.pushTokenUpdates {
                let h = Self.hex(t); self.tokens[mid] = h
                await Self.send(["kind": "update", "match": "\(mid)", "token": h])
            }
        }
        Task {
            for await s in a.activityStateUpdates where s == .ended || s == .dismissed {
                self.tokens[mid] = nil
                await Self.send(["kind": "end", "match": "\(mid)"]); break
            }
        }
    }

    /// Μόλις έρθει το token FCM: ό,τι δεν στάλθηκε ξαναστέλνεται
    func fcmReady() {
        for (mid, h) in tokens { Task { await Self.send(["kind": "update", "match": "\(mid)", "token": h]) } }
        UserDefaults.standard.removeObject(forKey: "la_start_sig")
        syncStart()
    }

    /// Αθλήματα/αγώνες που ακολουθείς → στον server, για να ξέρει σε ποιους να ανοίξει Live Activity
    func syncStart() {
        guard let t = startToken else { return }
        let p = Prefs.shared
        let on = p.liveActivities && p.all && ActivityAuthorizationInfo().areActivitiesEnabled
        var f = ["kind": "start", "token": t]
        if on {
            f["sports"] = p.sports.sorted().joined(separator: ",")
            f["matches"] = p.matchAlerts.union(p.laPins).map(String.init).joined(separator: ",")
        } else { f["off"] = "1" }
        let sig = f.sorted { $0.key < $1.key }.map { "\($0.key)=\($0.value)" }.joined(separator: "&") + "|" + (Push.shared.token ?? "")
        guard UserDefaults.standard.string(forKey: "la_start_sig") != sig else { return }
        Task { if await Self.send(f) { UserDefaults.standard.set(sig, forKey: "la_start_sig") } }
    }

    @discardableResult
    private static func send(_ f: [String: String]) async -> Bool {
        guard let fcm = Push.shared.token, let u = URL(string: Api.base + "/la-token") else { return false }
        var all = f; all["fcm"] = fcm; all["device"] = Device.id
        var r = URLRequest(url: u); r.httpMethod = "POST"
        r.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        r.httpBody = all.map { "\($0.key)=\(Api.q($0.value))" }.joined(separator: "&").data(using: .utf8)
        guard let (d, _) = try? await URLSession.shared.data(for: r), let j = J.parse(d) else { return false }
        return j["ok"].bool
    }

    private static func hex(_ d: Data) -> String { d.map { String(format: "%02x", $0) }.joined() }

    /// Λογότυπα των αγώνων της ΑΕΚ από πριν (ώστε να υπάρχουν και όταν το Live Activity ανοίξει με push, με κλειστό app)
    private var logosDone = Set<String>()
    func prefetch(_ items: [MatchCard]) {
        for m in items where !m.aek.isEmpty && !m.finished {
            for (n, l) in [(m.home, m.homeLogo), (m.away, m.awayLogo)] where !l.isEmpty && !logosDone.contains(n) {
                logosDone.insert(n)
                Task.detached(priority: .utility) { await LiveLogos.cache(n, l) }
            }
        }
    }

    /// Από κάθε φρέσκια κατάσταση αγώνα (λίστα αγώνων, σελίδα αγώνα, έλεγχος παρασκηνίου)
    private var ccAt = Date.distantPast
    func update(_ m: MatchCard, last: String = "", periods: [String]? = nil) {
        prefetch([m])
        // 🎛 Control Center: φρέσκο σκορ το πολύ ανά λεπτό
        if #available(iOS 18.0, *), m.live || m.finished, Date().timeIntervalSince(ccAt) > 60 {
            ccAt = Date(); ControlCenter.shared.reloadControls(ofKind: "gr.aekhub.control.match")
        }
        let p = Prefs.shared
        guard p.liveActivities, p.all, ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        let follow = p.laPins.contains(m.id) || p.matchAlerts.contains(m.id) || p.sports.contains(m.sport)
        let existing = find(m.id)
        guard existing != nil || (m.live && follow) else { return }

        let score = "\(m.scoreHome)-\(m.scoreAway)"
        let prev = lastScore[m.id]
        lastScore[m.id] = score
        var goal = false
        if let prev, prev != score, m.sport == "football" { // «ΓΚΟΛ!» μόνο στο ποδόσφαιρο ανδρών (ζήτησε ο χρήστης)
            let ph = Int(prev.split(separator: "-").first ?? "") ?? 0, pa = Int(prev.split(separator: "-").last ?? "") ?? 0
            goal = (m.aek == "home" && (Int(m.scoreHome) ?? 0) > ph) || (m.aek == "away" && (Int(m.scoreAway) ?? 0) > pa)
        }
        var st = LiveMatchAttributes.ContentState(
            sh: m.scoreHome.isEmpty ? "0" : m.scoreHome, sa: m.scoreAway.isEmpty ? "0" : m.scoreAway,
            status: m.status, minute: m.live ? liveMinute(m.clock, fallback: m.minute.isEmpty ? m.statusLabel : m.minute) : (m.finished ? "ΤΕΛΙΚΟ" : m.time),
            phase: m.statusLabel, last: last.isEmpty ? (existing?.content.state.last ?? "") : last, progress: progress(m), periods: [], goal: goal)
        st.clk = clockZero(m)
        st.periods = periods ?? existing?.content.state.periods ?? []
        // 🏐 Βόλεϊ live: μεγάλο = πόντοι του σετ («2ο Σετ · 12–8» από την πηγή), μικρά = σετ — όπως ο server
        if m.sport == "volleyball" && m.live {
            let set = (Int(st.sh) ?? 0) + (Int(st.sa) ?? 0) + 1
            st.per = set >= 5 ? "TIE-BREAK" : "ΣΕΤ \(set)"
            st.minute = st.per ?? ""
            if let r = m.minute.range(of: #"(\d+)\s*[–-]\s*(\d+)\s*$"#, options: .regularExpression) {
                let nums = m.minute[r].split(whereSeparator: { !$0.isNumber }).map(String.init)
                if nums.count == 2 { st.ph = nums[0]; st.pa = nums[1] }
            }
            if st.ph == nil { st.ph = existing?.content.state.ph ?? "0"; st.pa = existing?.content.state.pa ?? "0" }
            st.periods = Array(st.periods.prefix(max(0, set - 1)))
        }
        let content = ActivityContent(state: st, staleDate: Date().addingTimeInterval(m.live ? 30 * 60 : 3600))

        if let a = existing {
            Task {
                if m.finished {
                    await a.end(content, dismissalPolicy: .after(Date().addingTimeInterval(30 * 60)))
                    lastScore[m.id] = nil
                } else {
                    await a.update(content, alertConfiguration: goal ? AlertConfiguration(title: "ΓΚΟΛ!", body: "\(m.home) \(m.scoreHome)–\(m.scoreAway) \(m.away)", sound: .default) : nil)
                }
            }
        } else if m.live {
            let attrs = LiveMatchAttributes(matchId: m.id, home: m.home, away: m.away, aek: m.aek, sport: m.sport, competition: m.competition, venue: m.venue, kickoff: m.kickoffDate, hlogo: m.homeLogo, alogo: m.awayLogo)
            // Με push: token για ενημερώσεις από τον server (με κλειστή εφαρμογή)
            let a = (try? Activity.request(attributes: attrs, content: content, pushType: Push.shared.on ? .token : nil))
                ?? (try? Activity.request(attributes: attrs, content: content, pushType: nil))
            if let a { watch(a) }
        }
    }

    /// Στιγμή του 0′ για ρολόι που μετράει προς τα πάνω (ποδόσφαιρο/χάντμπολ/futsal) — όπως ο server
    func clockZero(_ m: MatchCard) -> Double? {
        guard m.live, let c = m.clock, c.s > 0,
              ["football", "women_football", "handball", "futsal"].contains(m.sport),
              !["halftime", "eth", "penalties", "prematch"].contains(m.status) else { return nil }
        let z = (c.s - c.b * 60000) / 1000
        return z > Date().timeIntervalSince1970 - 4 * 3600 ? z : nil
    }

    func progress(_ m: MatchCard) -> Double {
        if m.finished { return 1 }
        guard m.live else { return 0 }
        // Ίδια λογική με τον server (aekhub_la_progress): μπάσκετ/πόλο ανά Q, βόλεϊ ανά σετ, αλλιώς λεπτό
        if m.status.count == 2, m.status.hasPrefix("q"), let q = Int(m.status.dropFirst()) { return (Double(q) - 0.5) / 4 }
        if m.status == "ot" { return 0.98 }
        if m.sport == "volleyball" {
            let n = Double(m.minute.filter(\.isNumber).prefix(1)) ?? 1
            return min(5, max(1, n)) / 5 - 0.1
        }
        if ["halftime", "eth"].contains(m.status) { return 0.5 }
        let mn = Double(liveMinute(m.clock, fallback: m.minute).filter(\.isNumber).prefix(3)) ?? 0
        let total: Double = m.sport.contains("football") ? 90 : (m.sport == "futsal" ? 40 : (m.sport == "handball" ? 60 : 40))
        return min(1, mn / total)
    }

    /// Μπορεί αυτή η συσκευή να δείξει Live Activity;
    var available: Bool { ActivityAuthorizationInfo().areActivitiesEnabled }
    func isOn(_ id: Int) -> Bool { find(id) != nil }
    func end(_ id: Int) { if let a = find(id) { Task { await a.end(nil, dismissalPolicy: .immediate) } } }

    func endAll() {
        for a in Activity<LiveMatchAttributes>.activities { Task { await a.end(nil, dismissalPolicy: .immediate) } }
        syncStart()
    }
}
