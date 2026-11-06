import Foundation

enum Fmt {
    static let athensTZ = TimeZone(identifier: "Europe/Athens")!
    static let gr = Locale(identifier: "el_GR")
    static let days = ["Κυριακή", "Δευτέρα", "Τρίτη", "Τετάρτη", "Πέμπτη", "Παρασκευή", "Σάββατο"]
    static let daysShort = ["Κυρ", "Δευ", "Τρί", "Τετ", "Πέμ", "Παρ", "Σάβ"]
    static let monthsShort = ["ΙΑΝ", "ΦΕΒ", "ΜΑΡ", "ΑΠΡ", "ΜΑΪ", "ΙΟΥΝ", "ΙΟΥΛ", "ΑΥΓ", "ΣΕΠ", "ΟΚΤ", "ΝΟΕ", "ΔΕΚ"]
    static let monthsGen = ["Ιανουαρίου", "Φεβρουαρίου", "Μαρτίου", "Απριλίου", "Μαΐου", "Ιουνίου", "Ιουλίου", "Αυγούστου", "Σεπτεμβρίου", "Οκτωβρίου", "Νοεμβρίου", "Δεκεμβρίου"]

    static var cal: Calendar = { var c = Calendar(identifier: .gregorian); c.timeZone = athensTZ; return c }()

    private static let isoF: ISO8601DateFormatter = ISO8601DateFormatter()
    static func iso(_ s: String) -> Date? { isoF.date(from: s) }

    private static let ymd: DateFormatter = { let f = DateFormatter(); f.locale = Locale(identifier: "en_US_POSIX"); f.timeZone = athensTZ; f.dateFormat = "yyyy-MM-dd"; return f }()
    private static let ymdhm: DateFormatter = { let f = DateFormatter(); f.locale = Locale(identifier: "en_US_POSIX"); f.timeZone = athensTZ; f.dateFormat = "yyyy-MM-dd HH:mm"; return f }()

    static func day(_ s: String) -> Date? { ymd.date(from: s) }
    static func ymdString(_ d: Date) -> String { ymd.string(from: d) }
    static func athens(date: String, time: String) -> Date? {
        guard !date.isEmpty else { return nil }
        return ymdhm.date(from: date + " " + (time.isEmpty ? "00:00" : time)) ?? ymd.date(from: date)
    }

    /// «6 Νοεμβρίου 2026»
    static func postDate(_ iso: String, withYear: Bool = true) -> String {
        guard let d = Fmt.iso(iso) else { return "" }
        let c = cal.dateComponents([.day, .month, .year], from: d)
        return "\(c.day!) \(monthsGen[c.month! - 1])" + (withYear ? " \(c.year!)" : "")
    }
    /// «πριν 5′», «πριν 3 ώρες», αλλιώς ημερομηνία
    static func ago(_ iso: String) -> String {
        guard let d = Fmt.iso(iso) else { return "" }
        let s = Date().timeIntervalSince(d)
        if s < 60 { return "τώρα" }
        if s < 3600 { return "πριν \(Int(s / 60))′" }
        if s < 86400 { let h = Int(s / 3600); return h == 1 ? "πριν 1 ώρα" : "πριν \(h) ώρες" }
        return postDate(iso, withYear: false)
    }
    /// «ΣΑΒΒΑΤΟ 8 ΝΟΕΜΒΡΙΟΥ»
    static func dayHeader(_ ymdS: String) -> String {
        guard let d = day(ymdS) else { return ymdS }
        let c = cal.dateComponents([.day, .month, .weekday], from: d)
        return (days[c.weekday! - 1] + " \(c.day!) " + monthsGen[c.month! - 1]).upperGr
    }
    /// «Σάβ 8/11»
    static func shortDay(_ ymdS: String) -> String {
        guard let d = day(ymdS) else { return ymdS }
        let c = cal.dateComponents([.day, .month, .weekday], from: d)
        return daysShort[c.weekday! - 1] + " \(c.day!)/\(c.month!)"
    }
    static func isToday(_ ymdS: String) -> Bool { ymdS == ymdString(Date()) }
}

extension String {
    /// Κεφαλαία χωρίς τόνους (κανόνας του χρήστη: ό,τι είναι κεφαλαία → χωρίς τόνους).
    var upperGr: String { folding(options: .diacriticInsensitive, locale: Fmt.gr).uppercased(with: Fmt.gr) }

    /// HTML entities → χαρακτήρες (&#8217; &amp; &laquo; …)
    var htmlDecoded: String {
        guard contains("&") else { return self }
        var out = ""
        var i = startIndex
        let named: [String: String] = ["amp": "&", "quot": "\"", "apos": "'", "lt": "<", "gt": ">", "nbsp": " ", "laquo": "«", "raquo": "»",
                                       "hellip": "…", "ndash": "–", "mdash": "—", "rsquo": "’", "lsquo": "‘", "rdquo": "”", "ldquo": "“", "middot": "·", "euro": "€"]
        while i < endIndex {
            if self[i] == "&", let semi = self[i...].prefix(10).firstIndex(of: ";") {
                let ent = String(self[index(after: i)..<semi])
                var rep: String?
                if ent.hasPrefix("#x") || ent.hasPrefix("#X") { if let n = UInt32(ent.dropFirst(2), radix: 16), let u = Unicode.Scalar(n) { rep = String(Character(u)) } }
                else if ent.hasPrefix("#") { if let n = UInt32(ent.dropFirst()), let u = Unicode.Scalar(n) { rep = String(Character(u)) } }
                else { rep = named[ent] }
                if let r = rep { out += r; i = index(after: semi); continue }
            }
            out.append(self[i]); i = index(after: i)
        }
        return out
    }

    /// Απλό κείμενο από HTML (για το ρολόι και περιλήψεις): παράγραφοι → κενές γραμμές.
    var plainText: String {
        var s = self
        for t in ["</p>", "<br>", "<br />", "<br/>", "</h2>", "</h3>", "</li>", "</blockquote>"] { s = s.replacingOccurrences(of: t, with: t.hasPrefix("<br") ? "\n" : "\n\n", options: .caseInsensitive) }
        s = s.replacingOccurrences(of: "<(script|style|iframe|figure)[^>]*>[\\s\\S]*?</\\1>", with: "", options: [.regularExpression, .caseInsensitive])
        s = s.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
        s = s.htmlDecoded
        s = s.replacingOccurrences(of: "\n{3,}", with: "\n\n", options: .regularExpression)
        return s.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

enum Img {
    /// Εικόνες του aekhub.gr μέσω CDN (i0.wp.com, WebP, σωστό μέγεθος): κάποια πρωτότυπα είναι 4000px.
    static func url(_ s: String, w w0: Int) -> URL? {
        guard !s.isEmpty else { return nil }
        // 📉 Εξοικονόμηση δεδομένων (Εγώ): μικρότερες εικόνες
        let w = UserDefaults.standard.bool(forKey: "data_saver") ? max(120, w0 * 3 / 5) : w0
        if s.contains("i0.wp.com") || s.contains("i1.wp.com") || s.contains("i2.wp.com") {
            guard var c = URLComponents(string: s) else { return URL(string: s) }
            var q = (c.queryItems ?? []).filter { !["w", "fit", "resize"].contains($0.name) }
            q.append(URLQueryItem(name: "w", value: String(w)))
            c.queryItems = q
            return c.url
        }
        if let u = URL(string: s), u.host == "aekhub.gr" || u.host == "www.aekhub.gr", !u.path.hasSuffix(".svg") {
            return URL(string: "https://i0.wp.com/aekhub.gr" + u.path + "?w=\(w)&ssl=1")
        }
        return URL(string: s)
    }
}

/// Λεπτό αγώνα που «τρέχει» μόνο του (όταν το Match Center έχει ρολόι) — ίδιος τύπος με το Android.
func liveMinute(_ clock: Clock?, fallback: String, now: Date = Date()) -> String {
    guard let c = clock, c.s > 0 else { return fallback }
    let el = now.timeIntervalSince1970 * 1000 - c.s
    if el > 3 * 3_600_000 { return fallback }
    let min = Int(floor(c.b + max(0, el) / 60000.0)) + 1
    let end = Int(c.b + c.l)
    return min > end ? "\(end)+\(min - end)′" : "\(min)′"
}

/// Χρώμα από #RRGGBB → (r,g,b) 0…1
func hexRGB(_ hex: String) -> (Double, Double, Double)? {
    var h = hex.trimmingCharacters(in: .whitespaces)
    if h.hasPrefix("#") { h.removeFirst() }
    if h.count == 3 { h = h.map { "\($0)\($0)" }.joined() }
    guard h.count == 6, let v = UInt32(h, radix: 16) else { return nil }
    return (Double((v >> 16) & 0xFF) / 255, Double((v >> 8) & 0xFF) / 255, Double(v & 0xFF) / 255)
}

enum Sports {
    static func label(_ k: String) -> String {
        switch k {
        case "football": return "Ποδόσφαιρο"
        case "basketball": return "Μπάσκετ"
        case "volleyball": return "Βόλεϊ"
        case "handball": return "Χάντμπολ"
        case "women_football": return "Γυναικείο ποδόσφαιρο"
        case "futsal": return "Futsal"
        case "waterpolo": return "Πόλο"
        default: return k
        }
    }
    static func emoji(_ k: String) -> String {
        switch k {
        case "basketball": return "🏀"
        case "volleyball", "volleyball_w": return "🏐"
        case "handball": return "🤾"
        case "waterpolo": return "🤽"
        default: return "⚽"
        }
    }
}
