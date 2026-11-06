import Foundation

/// Όλα τα δεδομένα από το aekhub.gr (plugin «AEK Hub App»). Ίδια λογική με το Android:
/// - κάθε λήψη πάει ΠΑΝΤΑ στον server (POST → καμία cache WordPress.com/CDN), με επιστροφή σε GET αν ο server δεν δέχεται POST·
/// - η τελευταία απάντηση κάθε οθόνης μένει στον δίσκο, ώστε η οθόνη να ανοίγει ΑΜΕΣΩΣ και μετά να ανανεώνεται.
final class Api {
    static let site = "https://aekhub.gr"
    static let base = site + "/wp-json/aekhub/v1/app"
    static let shared = Api()

    private let session: URLSession
    private let dir: URL
    private var usePost = true
    private let lock = NSLock()
    private var mem: [String: Data] = [:]

    private(set) var lastOk: Date?
    private(set) var lastErr = ""

    static var version: String { Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0" }
    static var build: String { Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "0" }

    init() {
        let c = URLSessionConfiguration.default
        c.requestCachePolicy = .reloadIgnoringLocalCacheData
        c.urlCache = nil
        c.timeoutIntervalForRequest = 20
        #if os(watchOS)
        let plat = "watchOS"
        #else
        let plat = "iOS"
        #endif
        c.httpAdditionalHeaders = ["User-Agent": "AEKHubApp/\(Api.version) (\(plat))", "Cache-Control": "no-cache"]
        session = URLSession(configuration: c)
        dir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0].appendingPathComponent("api", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        // Εικόνες: μεγάλη cache (AsyncImage χρησιμοποιεί το URLCache.shared)
        URLCache.shared = URLCache(memoryCapacity: 40 << 20, diskCapacity: 300 << 20)
    }

    enum ApiError: LocalizedError {
        case http(Int), notJSON
        var errorDescription: String? {
            switch self { case .http(let c): return "Σφάλμα server (\(c))"; case .notJSON: return "Μη αναμενόμενη απάντηση" }
        }
    }

    private func file(_ path: String) -> URL {
        var h: UInt64 = 1469598103934665603
        for b in path.utf8 { h = (h ^ UInt64(b)) &* 1099511628211 }
        return dir.appendingPathComponent(String(h, radix: 16) + ".json")
    }

    private func remember(_ path: String, _ data: Data) { lock.lock(); mem[path] = data; lock.unlock() }

    /// Η αποθηκευμένη απάντηση (χωρίς δίκτυο).
    func peek(_ path: String) -> J? {
        lock.lock(); let m = mem[path]; lock.unlock()
        if let m { return J.parse(m) }
        guard let d = try? Data(contentsOf: file(path)) else { return nil }
        lock.lock(); mem[path] = d; lock.unlock()
        return J.parse(d)
    }

    func get(_ path: String) async throws -> J {
        let url = URL(string: Api.base + path + (path.contains("?") ? "&" : "?") + "_=\(Int(Date().timeIntervalSince1970 * 1000))")!
        func req(_ post: Bool) -> URLRequest {
            var r = URLRequest(url: url)
            if post { r.httpMethod = "POST"; r.httpBody = Data() }
            return r
        }
        do {
            var (data, resp) = try await session.data(for: req(usePost))
            var code = (resp as? HTTPURLResponse)?.statusCode ?? 0
            if usePost && (code == 404 || code == 405) {
                usePost = false
                (data, resp) = try await session.data(for: req(false))
                code = (resp as? HTTPURLResponse)?.statusCode ?? 0
            }
            guard (200..<300).contains(code) else { throw ApiError.http(code) }
            guard let first = data.first(where: { !($0 == 32 || $0 == 10 || $0 == 13 || $0 == 9) }), first == UInt8(ascii: "{") || first == UInt8(ascii: "["),
                  let j = J.parse(data) else { throw ApiError.notJSON }
            remember(path, data)
            try? data.write(to: file(path), options: .atomic)
            lastOk = Date()
            return j
        } catch {
            lastErr = (path.components(separatedBy: "?").first ?? path) + " → " + error.localizedDescription
            throw error
        }
    }

    static func q(_ v: String) -> String { v.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed.subtracting(CharacterSet(charactersIn: "&=+?"))) ?? v }

    // Διαδρομές (ίδιες με το Android)
    static let pHome = "/home"
    static let pConfig = "/config"
    static let pStandings = "/standings"
    static func pFeed(_ cat: String?, page: Int = 1) -> String { "/feed?page=\(page)&per=12" + ((cat ?? "").isEmpty ? "" : "&cat=" + q(cat!)) }
    static func pSearch(_ s: String, page: Int = 1) -> String { "/feed?page=\(page)&s=" + q(s) }
    static func pPost(_ id: Int) -> String { "/post/\(id)" }
    static func pMatch(_ id: Int) -> String { "/match/\(id)" }
    static func pEvent(_ id: Int) -> String { "/event/\(id)" }
    static func pMatches(from: String? = nil, to: String? = nil, sport: String? = nil) -> String {
        var p: [String] = []
        if let from { p.append("from=" + from) }
        if let to { p.append("to=" + to) }
        if let sport, !sport.isEmpty { p.append("sport=" + q(sport)) }
        return "/matches" + (p.isEmpty ? "" : "?" + p.joined(separator: "&"))
    }

    func home() async throws -> HomeData { HomeData(try await get(Api.pHome)) }
    func config() async throws -> AppConfig { AppConfig(try await get(Api.pConfig)) }
    func feed(_ cat: String?, page: Int) async throws -> Feed { Feed(try await get(Api.pFeed(cat, page: page))) }
    func search(_ s: String, page: Int = 1) async throws -> Feed { Feed(try await get(Api.pSearch(s, page: page))) }
    func post(_ id: Int) async throws -> Post { Post(try await get(Api.pPost(id))) }
    func match(_ id: Int) async throws -> MatchDetail { MatchDetail(try await get(Api.pMatch(id))) }
    func matches(from: String? = nil, to: String? = nil, sport: String? = nil) async throws -> MatchList { MatchList(try await get(Api.pMatches(from: from, to: to, sport: sport))) }
    func standings() async throws -> [Standing] { try await get(Api.pStandings)["items"].list(Standing.init) }
    func event(_ id: Int) async throws -> EventDetail { EventDetail(try await get(Api.pEvent(id))) }

    /// Μέτρηση εμφάνισης/κλικ χορηγού (GET σε διεύθυνση του site)· αθόρυβα.
    func ping(_ url: String) {
        guard url.hasPrefix("http"), let u = URL(string: url) else { return }
        session.dataTask(with: u).resume()
    }
}

extension Api {
    /// Μέγεθος προσωρινών αρχείων (εικόνες + αποθηκευμένες απαντήσεις)
    var cacheBytes: Int {
        let files = (try? FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: [.fileSizeKey])) ?? []
        return URLCache.shared.currentDiskUsage + files.reduce(0) { $0 + ((try? $1.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0) }
    }
    /// Καθάρισμα: φεύγουν οι εικόνες και οι παλιές απαντήσεις (ξαναφορτώνονται από το δίκτυο)
    func clearCache() {
        URLCache.shared.removeAllCachedResponses()
        for f in (try? FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil)) ?? [] { try? FileManager.default.removeItem(at: f) }
    }
}
