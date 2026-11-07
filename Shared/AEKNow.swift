import Foundation

/// «Πότε παίζει η ΑΕΚ;» / «Σκορ ΑΕΚ» — για Siri, Αναζήτηση iPhone και Control Center.
/// Ο αγώνας είναι ο ίδιος με την αντίστροφη μέτρηση της αρχικής (`/app/home` → `next`: live → επιλεγμένος → επόμενος).
enum AEKNow {
    static func match() async -> MatchCard? { (try? await Api.shared.home())?.next }

    private static func df(_ f: String) -> DateFormatter {
        let d = DateFormatter(); d.locale = Locale(identifier: "el_GR"); d.dateFormat = f; return d
    }
    static func opp(_ m: MatchCard) -> String { m.aek == "away" ? m.home : m.away }
    static func when(_ m: MatchCard) -> String {
        guard let k = m.kickoffDate else { return [m.date, m.time].filter { !$0.isEmpty }.joined(separator: " ") }
        let cal = Calendar.current
        let day = cal.isDateInToday(k) ? "σήμερα" : (cal.isDateInTomorrow(k) ? "αύριο" : df("EEEE d/M").string(from: k))
        return "\(day) στις \(df("HH:mm").string(from: k))"
    }
    static func score(_ m: MatchCard) -> String {
        "\(m.home) \(m.scoreHome.isEmpty ? "0" : m.scoreHome)–\(m.scoreAway.isEmpty ? "0" : m.scoreAway) \(m.away)"
    }

    /// Πρόταση για τη Siri
    static func sentence(_ m: MatchCard?, scoreOnly: Bool = false) -> String {
        guard let m else { return "Δεν βρήκα προγραμματισμένο αγώνα της ΑΕΚ." }
        if m.live {
            let mn = liveMinute(m.clock, fallback: m.minute.isEmpty ? m.statusLabel : m.minute)
            return "Τώρα: \(score(m))" + (mn.isEmpty ? "." : ", \(mn).")
        }
        if m.finished { return "Τελικό: \(score(m))." }
        let comp = m.competition.isEmpty ? "" : " για \(m.competition)"
        return (scoreOnly ? "Η ΑΕΚ δεν παίζει τώρα. " : "") + "Η ΑΕΚ παίζει \(when(m)) με \(opp(m))\(comp)."
    }

    /// Σύντομο (Control Center): «ΑΕΚ 2–1 · 67′» ή «Κυρ 20:00 · Ολυμπιακός»
    static func short(_ m: MatchCard?) -> String {
        guard let m else { return "ΑΕΚ" }
        if m.live { return "\(m.scoreHome)–\(m.scoreAway) · " + liveMinute(m.clock, fallback: m.minute) }
        if m.finished { return "Τελικό \(m.scoreHome)–\(m.scoreAway)" }
        guard let k = m.kickoffDate else { return opp(m) }
        let d = Calendar.current.isDateInToday(k) ? "Σήμερα" : df("EEE").string(from: k)
        return "\(d) \(df("HH:mm").string(from: k)) · \(opp(m))"
    }
}
