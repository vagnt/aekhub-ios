import Foundation
import ActivityKit

/// Ξεκινά / ενημερώνει / κλείνει τα Live Activities των αγώνων (ρύθμιση «Live Activities» στο «Εγώ»).
@MainActor
final class LiveActivities {
    static let shared = LiveActivities()
    private var lastScore: [Int: String] = [:]

    private func find(_ id: Int) -> Activity<LiveMatchAttributes>? {
        Activity<LiveMatchAttributes>.activities.first { $0.attributes.matchId == id }
    }

    /// Από κάθε φρέσκια κατάσταση αγώνα (λίστα αγώνων, σελίδα αγώνα, έλεγχος παρασκηνίου)
    func update(_ m: MatchCard, last: String = "") {
        let p = Prefs.shared
        guard p.liveActivities, p.all, ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        let follow = p.matchAlerts.contains(m.id) || p.sports.contains(m.sport)
        let existing = find(m.id)
        guard existing != nil || (m.live && follow) else { return }

        let score = "\(m.scoreHome)-\(m.scoreAway)"
        let prev = lastScore[m.id]
        lastScore[m.id] = score
        var goal = false
        if let prev, prev != score {
            let ph = Int(prev.split(separator: "-").first ?? "") ?? 0, pa = Int(prev.split(separator: "-").last ?? "") ?? 0
            goal = (m.aek == "home" && (Int(m.scoreHome) ?? 0) > ph) || (m.aek == "away" && (Int(m.scoreAway) ?? 0) > pa)
        }
        let st = LiveMatchAttributes.ContentState(
            sh: m.scoreHome.isEmpty ? "0" : m.scoreHome, sa: m.scoreAway.isEmpty ? "0" : m.scoreAway,
            status: m.status, minute: m.live ? liveMinute(m.clock, fallback: m.minute.isEmpty ? m.statusLabel : m.minute) : (m.finished ? "ΤΕΛΙΚΟ" : m.time),
            phase: m.statusLabel, last: last, progress: progress(m), periods: [], goal: goal)
        let content = ActivityContent(state: st, staleDate: Date().addingTimeInterval(m.live ? 20 * 60 : 3600))

        if let a = existing {
            Task {
                if m.finished {
                    await a.end(content, dismissalPolicy: .after(Date().addingTimeInterval(20 * 60)))
                    lastScore[m.id] = nil
                } else {
                    await a.update(content, alertConfiguration: goal ? AlertConfiguration(title: "ΓΚΟΛ!", body: "\(m.home) \(m.scoreHome)–\(m.scoreAway) \(m.away)", sound: .default) : nil)
                }
            }
        } else if m.live {
            let attrs = LiveMatchAttributes(matchId: m.id, home: m.home, away: m.away, aek: m.aek, sport: m.sport, competition: m.competition, venue: m.venue, kickoff: m.kickoffDate)
            _ = try? Activity.request(attributes: attrs, content: content, pushType: nil)
        }
    }

    func progress(_ m: MatchCard) -> Double {
        if m.finished { return 1 }
        guard m.live else { return 0 }
        let mn = Double(liveMinute(m.clock, fallback: m.minute).filter(\.isNumber).prefix(3)) ?? 0
        let total: Double = m.sport.contains("football") ? 90 : (m.sport == "futsal" ? 40 : (m.sport == "handball" ? 60 : 40))
        return min(1, mn / total)
    }

    func endAll() {
        for a in Activity<LiveMatchAttributes>.activities { Task { await a.end(nil, dismissalPolicy: .immediate) } }
    }
}
