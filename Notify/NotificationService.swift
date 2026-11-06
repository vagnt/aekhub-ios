import UserNotifications

/// Τρέχει στο iPhone για κάθε ειδοποίηση push, πριν εμφανιστεί (όπως το Android φιλτράρει στο κινητό):
/// • 🌙 Ήσυχες ώρες / «σίγαση για λίγο» → έρχεται αθόρυβα (χωρίς ήχο/banner, μόνο στο Κέντρο ειδοποιήσεων).
///   Εξαίρεση: γκολ της ΑΕΚ, αν το έχει επιλέξει ο χρήστης.
/// • 🙈 Χωρίς spoilers → σβήνει το σκορ από τον τίτλο/κείμενο των αγώνων.
/// Οι ρυθμίσεις έρχονται από το app μέσω App Group (`group.gr.aekhub.app`).
final class NotificationService: UNNotificationServiceExtension {
    private var handler: ((UNNotificationContent) -> Void)?
    private var content: UNMutableNotificationContent?

    override func didReceive(_ request: UNNotificationRequest, withContentHandler contentHandler: @escaping (UNNotificationContent) -> Void) {
        handler = contentHandler
        guard let c = request.content.mutableCopy() as? UNMutableNotificationContent else { contentHandler(request.content); return }
        content = c
        let d = UserDefaults(suiteName: "group.gr.aekhub.app")
        let info = c.userInfo
        let isMatch = !((info["match"] as? String) ?? "").isEmpty

        if isMatch, d?.bool(forKey: "spoiler") == true {
            c.title = Self.noScore(c.title)
            c.body = Self.noScore(c.body)
        }
        if let d, Self.quiet(d) {
            let aekGoal = ((info["kind"] as? String) == "goals" || c.title.hasPrefix("Γκολ"))
                && ((info["aekScored"] as? String) == "1" || c.title.contains("ΑΕΚ [") || c.title.contains("] ΑΕΚ"))
            if !(aekGoal && d.bool(forKey: "quietAek")) {
                c.sound = nil
                if #available(iOS 15.0, *) { c.interruptionLevel = .passive }
            }
        }
        contentHandler(c)
    }

    override func serviceExtensionTimeWillExpire() {
        if let handler, let content { handler(content) }
    }

    /// «ΑΕΚ [1]–0 Χ» → «ΑΕΚ – Χ»
    static func noScore(_ s: String) -> String {
        s.replacingOccurrences(of: #"\s*\[?\d+\]?\s*[–-]\s*\[?\d+\]?\s*"#, with: " – ", options: .regularExpression)
    }

    /// Ίδιος κανόνας με το Prefs.isQuiet του app (ώρα Ελλάδας, και πέρα από τα μεσάνυχτα)
    static func quiet(_ d: UserDefaults) -> Bool {
        let now = Date()
        if d.double(forKey: "quietUntil") > now.timeIntervalSince1970 { return true }
        guard d.bool(forKey: "quiet") else { return false }
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "Europe/Athens") ?? .current
        let c = cal.dateComponents([.hour, .minute], from: now)
        let m = (c.hour ?? 0) * 60 + (c.minute ?? 0)
        let f = d.integer(forKey: "quietFrom"), t = d.integer(forKey: "quietTo")
        return f <= t ? (m >= f && m < t) : (m >= f || m < t)
    }
}
