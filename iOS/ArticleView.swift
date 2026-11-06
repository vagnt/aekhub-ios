import SwiftUI
import WebKit
import SafariServices

/// Άρθρο: όλο το άρθρο σε ένα WKWebView (κείμενο, φωτογραφίες, embeds YouTube/X/Instagram δουλεύουν όπως στο site).
struct ArticleView: View {
    let id: Int
    let card: PostCard?
    @State private var post: Post?
    @State private var error: String?
    @AppStorage("articleSize") private var size: Double = 17
    @State private var openURL: URL?
    @State private var showComments = false
    @State private var comments = 0
    @EnvironmentObject var prefs: Prefs
    @Environment(\.dismiss) var dismiss

    init(id: Int, card: PostCard?) {
        self.id = id; self.card = card
        _post = State(initialValue: Api.shared.peek(Api.pPost(id)).map(Post.init))
    }

    var link: URL? { (post?.link ?? card?.link).flatMap { URL(string: $0) } }

    var body: some View {
        ZStack(alignment: .top) {
            Group {
                if let p = post {
                    ArticleWeb(html: ArticleHTML.page(p, size: size), onLink: { openURL = $0 })
                } else if let error {
                    EmptyState(icon: "wifi.exclamationmark", text: error) { Task { await load() } }.padding(.top, 120)
                } else {
                    VStack(alignment: .leading, spacing: 16) {
                        if let c = card {
                            FillImage(url: c.image, w: 1200, height: 360)
                            Text(c.title.upperGr).font(F.disp(34)).foregroundStyle(C.text).padding(.horizontal, screenPad)
                        }
                        ProgressView().tint(C.gold).frame(maxWidth: .infinity)
                        Spacer()
                    }
                }
            }
            .ignoresSafeArea(edges: .top)

            // Πάνω: πίσω · (Aa, 🔖, κοινοποίηση) — γυαλί πάνω από τη φωτογραφία
            HStack {
                GlassCircle(icon: "chevron.left") { dismiss() }
                Spacer()
                HStack(spacing: 2) {
                    Menu {
                        Button { size = max(14, size - 1) } label: { Label("Μικρότερα γράμματα", systemImage: "textformat.size.smaller") }
                        Button { size = min(26, size + 1) } label: { Label("Μεγαλύτερα γράμματα", systemImage: "textformat.size.larger") }
                    } label: { Text("Aa").font(.system(size: 17, weight: .bold)).frame(width: 46, height: 44) }
                    if let c = post?.card ?? card {
                        Button { prefs.toggleSaved(c) } label: {
                            Image(systemName: prefs.isSaved(id) ? "bookmark.fill" : "bookmark").font(.system(size: 17, weight: .semibold)).frame(width: 46, height: 44)
                        }
                    }
                    if let u = link { ShareLink(item: u) { Image(systemName: "square.and.arrow.up").font(.system(size: 17, weight: .semibold)).frame(width: 46, height: 44) } }
                }
                .foregroundStyle(C.ink)
                .buttonStyle(.plain)
                .padding(.horizontal, 4)
                .glass(Capsule(), tint: C.gold)
            }
            .padding(.horizontal, 16).padding(.top, 4)
        }
        .background(C.ink.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
        // Κάτω: Σχόλια (γυαλί) + Κοινοποίηση (κίτρινο)
        .safeAreaInset(edge: .bottom) {
            if post != nil {
                HStack(spacing: 12) {
                    Button { showComments = true } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "text.bubble").foregroundStyle(C.gold)
                            Text(comments > 0 ? "Σχόλια (\(comments))" : "Σχόλια").font(F.body(17, .semibold)).foregroundStyle(C.text)
                        }
                        .padding(.horizontal, 24).frame(height: 58)
                        .glass(Capsule(), interactive: true)
                    }.buttonStyle(.plain)
                    if let u = link {
                        ShareLink(item: u) {
                            HStack(spacing: 8) {
                                Image(systemName: "square.and.arrow.up")
                                Text("Κοινοποίηση").font(F.body(17, .semibold))
                            }
                            .foregroundStyle(C.ink)
                            .frame(maxWidth: .infinity).frame(height: 58)
                            .background(Capsule().fill(C.goldGrad).shadow(color: C.gold.opacity(0.4), radius: 14, y: 4))
                        }
                    }
                }
                .padding(.horizontal, 16).padding(.bottom, 4)
            }
        }
        .sheet(item: $openURL) { SafariView(url: $0).ignoresSafeArea() }
        .sheet(isPresented: $showComments) { CommentsView(postId: id, title: post?.title ?? "") }
        .task {
            Analytics.screen(1, id)
            await load()
            if let j = try? await CommentsApi.call("comments/\(id)?sort=new&page=1") { comments = j["total"].int }
        }
    }

    func load() async {
        do { post = try await Api.shared.post(id); error = nil }
        catch { if post == nil { self.error = "Δεν φόρτωσε το άρθρο.\n" + error.localizedDescription } }
    }
}

extension URL: Identifiable { public var id: String { absoluteString } }

struct SafariView: UIViewControllerRepresentable {
    let url: URL
    func makeUIViewController(context: Context) -> SFSafariViewController {
        let c = SFSafariViewController(url: url)
        c.preferredControlTintColor = UIColor(C.gold)
        c.preferredBarTintColor = UIColor(C.ink)
        return c
    }
    func updateUIViewController(_ c: SFSafariViewController, context: Context) {}
}

struct ArticleWeb: UIViewRepresentable {
    let html: String
    var onLink: (URL) -> Void

    func makeCoordinator() -> Coord { Coord(onLink: onLink) }

    func makeUIView(context: Context) -> WKWebView {
        let cfg = WKWebViewConfiguration()
        cfg.allowsInlineMediaPlayback = true
        cfg.mediaTypesRequiringUserActionForPlayback = []
        let w = WKWebView(frame: .zero, configuration: cfg)
        w.isOpaque = false
        w.backgroundColor = UIColor(C.ink)
        w.scrollView.backgroundColor = UIColor(C.ink)
        w.scrollView.contentInsetAdjustmentBehavior = .never
        w.navigationDelegate = context.coordinator
        w.allowsLinkPreview = true
        return w
    }

    func updateUIView(_ w: WKWebView, context: Context) {
        context.coordinator.onLink = onLink
        guard context.coordinator.loaded != html else { return }
        context.coordinator.loaded = html
        // Βάση https://aekhub.gr/ ώστε τα embeds (π.χ. YouTube) να βλέπουν σωστό referrer
        w.loadHTMLString(html, baseURL: URL(string: Api.site + "/"))
    }

    final class Coord: NSObject, WKNavigationDelegate {
        var onLink: (URL) -> Void
        var loaded = ""
        init(onLink: @escaping (URL) -> Void) { self.onLink = onLink }
        func webView(_ w: WKWebView, decidePolicyFor a: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            // Πάτημα σε link → ανοίγει σε Safari μέσα στο app (όχι μέσα στο άρθρο)
            if a.navigationType == .linkActivated, let u = a.request.url, a.targetFrame?.isMainFrame != false {
                if u.scheme == "http" || u.scheme == "https" { onLink(u) } else { UIApplication.shared.open(u) }
                decisionHandler(.cancel); return
            }
            decisionHandler(.allow)
        }
    }
}

enum ArticleHTML {
    /// Οι γραμματοσειρές του app μέσα στο HTML (base64), αφού η σελίδα «ζει» στο https://aekhub.gr/.
    static let fontsCSS: String = {
        func face(_ file: String, _ fam: String, _ w: Int) -> String {
            guard let u = Bundle.main.url(forResource: file, withExtension: "ttf"), let d = try? Data(contentsOf: u) else { return "" }
            return "@font-face{font-family:'\(fam)';font-weight:\(w);src:url(data:font/ttf;base64,\(d.base64EncodedString())) format('truetype');}"
        }
        return face("Manrope-Medium", "Manrope", 500) + face("Manrope-ExtraBold", "Manrope", 800) + face("SofiaSans-Black", "Sofia", 900)
    }()

    static func esc(_ s: String) -> String {
        s.replacingOccurrences(of: "&", with: "&amp;").replacingOccurrences(of: "<", with: "&lt;").replacingOccurrences(of: ">", with: "&gt;").replacingOccurrences(of: "\"", with: "&quot;")
    }

    static func page(_ p: Post, size: Double) -> String {
        var video = ""
        if let v = p.videoInfo {
            if !v.html.isEmpty { video = "<div class='vid'>\(v.html)</div>" }
            else if !v.embed.isEmpty { video = "<div class='vid'><iframe src='\(esc(v.embed))' allow='autoplay; encrypted-media; picture-in-picture; fullscreen' allowfullscreen></iframe></div>" }
        }
        let img = Img.url(p.image, w: 1400)?.absoluteString ?? p.image
        let hero = p.image.isEmpty ? "<div class='hero none'></div>" : "<div class='hero' style=\"background-image:url('\(esc(img))')\"></div>"
        let ini = p.author.split(separator: " ").prefix(2).compactMap { $0.first.map(String.init) }.joined().uppercased()
        return """
        <!doctype html><html lang="el"><head><meta charset="utf-8">
        <meta name="viewport" content="width=device-width,initial-scale=1,viewport-fit=cover">
        <style>
        \(fontsCSS)
        :root{color-scheme:dark}
        html,body{margin:0;background:#0B0B0A;color:#F3F1E9;-webkit-text-size-adjust:100%}
        body{font-family:-apple-system,system-ui,sans-serif;font-size:\(Int(size))px;line-height:1.6;padding-bottom:120px}
        .top{position:relative;min-height:62vh;display:flex;flex-direction:column;justify-content:flex-end}
        .hero{position:absolute;inset:0;background-size:cover;background-position:center 25%}
        .hero.none{background:#151514}
        .top:after{content:'';position:absolute;inset:0;background:linear-gradient(180deg,rgba(11,11,10,.15) 0%,rgba(11,11,10,.25) 35%,rgba(11,11,10,.85) 70%,#0B0B0A 100%)}
        .head{position:relative;z-index:2;padding:0 20px 6px}
        .tags{display:flex;gap:8px;align-items:center;margin-bottom:12px}
        .cat{background:#F9CF1C;color:#0B0B0A;font-weight:700;font-size:12px;letter-spacing:.08em;padding:6px 11px;border-radius:999px;text-transform:uppercase}
        .min{font-size:12px;font-weight:600;color:#F3F1E9;padding:5px 10px;border-radius:999px;background:rgba(255,255,255,.12);border:1px solid rgba(255,255,255,.18);-webkit-backdrop-filter:blur(12px)}
        h1.t{font-family:Sofia,-apple-system,sans-serif;font-weight:900;font-size:\(Int(size * 2))px;line-height:1.02;margin:0;text-transform:uppercase}
        .wrap{max-width:760px;margin:0 auto;padding:0 20px}
        .lead{font-size:1.02em;color:#CFCBBE;border-left:3px solid #F9CF1C;padding-left:14px;margin:18px 0}
        .author{display:flex;align-items:center;gap:12px;background:#151514;border:1px solid #2C2C29;border-radius:22px;padding:12px 14px;margin:6px 0 22px}
        .av{width:44px;height:44px;border-radius:50%;border:2px solid #F9CF1C;color:#F9CF1C;display:flex;align-items:center;justify-content:center;font-weight:700;font-size:15px;flex:none}
        .an{font-weight:600;font-size:16px}.ad{color:#9A968A;font-size:13px}
        .vid{position:relative;padding-top:56.25%;margin:0 0 18px;background:#000;border-radius:18px;overflow:hidden}.vid iframe{position:absolute;inset:0;width:100%;height:100%;border:0}
        a{color:#F9CF1C}
        h2,h3,h4{font-weight:700;line-height:1.25;margin:1.4em 0 .5em}
        h2{font-size:1.25em}h3{font-size:1.12em}
        strong,b{font-weight:700}
        img{max-width:100%;height:auto;border-radius:16px}
        figure{margin:18px 0}figcaption{font-size:13px;color:#9A968A;margin-top:6px}
        blockquote{margin:18px 0;padding:4px 0 4px 14px;border-left:3px solid #F9CF1C;color:#CFCBBE}
        iframe,video,embed{max-width:100%;border:0}
        .wp-block-embed__wrapper{position:relative}
        .wp-block-embed.is-type-video .wp-block-embed__wrapper{padding-top:56.25%}
        .wp-block-embed.is-type-video iframe{position:absolute;inset:0;width:100%;height:100%}
        table{width:100%;border-collapse:collapse;font-size:.9em}td,th{border-bottom:1px solid #2C2C29;padding:6px}
        hr{border:0;border-top:1px dashed #3A3935;margin:24px 0}
        </style></head><body>
        <div class="top">\(hero)
        <div class="head">
        <div class="tags">\(p.category.isEmpty ? "" : "<span class='cat'>\(esc(p.category))</span>")<span class="min">\(p.minutes)′ ανάγνωση</span></div>
        <h1 class="t">\(esc(p.title))</h1>
        </div></div>
        <div class="wrap">
        \(p.excerpt.isEmpty ? "" : "<p class='lead'>\(esc(p.excerpt))</p>")
        <div class="author"><div class="av">\(esc(ini.isEmpty ? "AH" : ini))</div><div><div class="an">\(esc(p.author.isEmpty ? "AEK Hub" : p.author))</div><div class="ad">\(esc(Fmt.postDate(p.date)))</div></div></div>
        \(video)
        \(p.html)
        </div></body></html>
        """
    }
}
