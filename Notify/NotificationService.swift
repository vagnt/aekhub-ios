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
        // 🖼 Εικόνα του άρθρου/αγώνα (το `image` του server): μικρογραφία δεξιά, μεγάλη όταν ανοίγει η ειδοποίηση
        guard let raw = info["image"] as? String, let url = Self.small(raw) else { contentHandler(c); return }
        var rq = URLRequest(url: url, timeout: 20)
        rq.setValue("image/jpeg,image/png;q=0.9", forHTTPHeaderField: "Accept") // όχι webp: το iOS δεν το δέχεται ως συνημμένο
        let task = URLSession.shared.downloadTask(with: rq) { [weak self] tmp, resp, _ in
            if let tmp, (resp as? HTTPURLResponse)?.statusCode ?? 200 < 400 {
                let ext = (resp?.mimeType?.contains("png") ?? false) ? "png" : "jpg"
                let dst = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + "." + ext)
                if (try? FileManager.default.moveItem(at: tmp, to: dst)) != nil,
                   let a = try? UNNotificationAttachment(identifier: "img", url: dst, options: nil) {
                    c.attachments = [a]
                }
            }
            DispatchQueue.main.async { self?.finish() }
        }
        task.resume()
    }

    /// Μικρότερη εικόνα από το CDN (κάποια πρωτότυπα είναι 4000px) — γρήγορο κατέβασμα, λίγα δεδομένα
    static func small(_ raw: String) -> URL? {
        guard var u = URLComponents(string: raw.trimmingCharacters(in: .whitespaces)), let host = u.host, u.scheme?.hasPrefix("http") == true else { return nil }
        if host.hasSuffix("aekhub.gr") || host.hasSuffix("files.wordpress.com") {
            return URL(string: "https://i0.wp.com/" + host + u.path + "?w=900&strip=all")
        }
        if host.hasPrefix("i0.wp.com") || host.hasPrefix("i1.wp.com") || host.hasPrefix("i2.wp.com") {
            u.queryItems = [URLQueryItem(name: "w", value: "900"), URLQueryItem(name: "strip", value: "all")]
            return u.url
        }
        return u.url
    }

    override func serviceExtensionTimeWillExpire() { finish() } // δεν πρόλαβε η εικόνα → χωρίς εικόνα

    /// Μία φορά μόνο
    private func finish() {
        if let handler, let content { self.handler = nil; handler(content) }
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
