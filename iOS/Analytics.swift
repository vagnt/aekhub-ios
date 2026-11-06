import Foundation

/// Ανώνυμα στατιστικά στο aekhub.gr (ίδια με το Android, πηγή 15 = «Εφαρμογή iOS» → 📊 Analytics του site).
/// kind: 1 άρθρο · 2 αρχική · 3 κατηγορία · 4 αγώνας · 5 σελίδα · 6 άλλο. Χωρίς cookies/προσωπικά στοιχεία· κλείνει από «Εγώ».
enum Analytics {
    private static var seen: [String: Date] = [:]
    private static var curKind = 2
    private static var curOid = 0

    private static func send(_ path: String, _ body: String) {
        guard let u = URL(string: Api.site + path) else { return }
        var r = URLRequest(url: u)
        r.httpMethod = "POST"
        r.setValue("text/plain", forHTTPHeaderField: "Content-Type")
        r.setValue("AEKHubApp/\(Api.version) (iOS)", forHTTPHeaderField: "User-Agent")
        r.httpBody = body.data(using: .utf8)
        URLSession.shared.dataTask(with: r).resume()
    }

    @MainActor static var on: Bool { Prefs.shared.stats }

    /// Άνοιξε οθόνη (καρτέλες μία φορά ανά 30′, άρθρα/αγώνες ανά 5′, κατηγορίες ανά 10′ — όπως στο Android)
    @MainActor static func screen(_ kind: Int, _ oid: Int = 0, name: String = "") {
        curKind = kind; curOid = oid
        guard on else { return }
        let key = "\(kind):\(oid):\(name)"
        let win: TimeInterval = kind == 1 || kind == 4 ? 300 : (kind == 3 ? 600 : 1800)
        if let t = seen[key], Date().timeIntervalSince(t) < win { return }
        seen[key] = Date()
        send("/wp-json/aekhub/v1/hit", "{\"k\":\(kind),\"o\":\(oid),\"s\":15,\"v\":\(Device.isPad ? 2 : 1),\"d\":\"\(Device.id)\"}")
    }

    /// 🔴 «Live τώρα»: παλμός κάθε 60″ όσο είναι ανοιχτό· leave = βγήκε από την εφαρμογή
    @MainActor static func ping(leave: Bool = false) {
        guard on else { return }
        send("/wp-json/aekhub-an/v1/ping", "{\"k\":\(curKind),\"o\":\(curOid),\"d\":\"\(Device.id)\"" + (leave ? ",\"x\":1}" : "}"))
    }
}
