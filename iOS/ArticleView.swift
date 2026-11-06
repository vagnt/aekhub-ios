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

    init(id: Int, card: PostCard?) {
        self.id = id; self.card = card
        _post = State(initialValue: Api.shared.peek(Api.pPost(id)).map(Post.init))
    }

    var body: some View {
        Group {
            if let p = post {
                ArticleWeb(html: ArticleHTML.page(p, size: size), onLink: { openURL = $0 })
                    .ignoresSafeArea(edges: .bottom)
            } else if let error {
                EmptyState(icon: "wifi.exclamationmark", text: error) { Task { await load() } }
            } else {
                VStack(spacing: 16) {
                    if let c = card {
                        NetImage(url: c.image, w: 1200).frame(height: 230).frame(maxWidth: .infinity).clipped()
                        Text(c.title).font(F.disp(30, black: true)).foregroundStyle(C.text).padding(.horizontal, 16)
                    }
                    ProgressView().tint(C.gold)
                    Spacer()
                }
            }
        }
        .background(C.ink)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .navigationBarTrailing) {
                Menu {
                    Button { size = max(14, size - 1) } label: { Label("Μικρότερα γράμματα", systemImage: "textformat.size.smaller") }
                    Button { size = min(26, size + 1) } label: { Label("Μεγαλύτερα γράμματα", systemImage: "textformat.size.larger") }
                } label: { Image(systemName: "textformat.size") }
                if let l = post?.link ?? card?.link, let u = URL(string: l) {
                    ShareLink(item: u) { Image(systemName: "square.and.arrow.up") }
                }
            }
        }
        .sheet(item: $openURL) { SafariView(url: $0).ignoresSafeArea() }
        .task { await load() }
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
        let hero = video.isEmpty && !p.image.isEmpty
            ? "<figure class='hero'><img src='\(esc(Img.url(p.image, w: 1400)?.absoluteString ?? p.image))'>" + (p.imageCaption.isEmpty ? "" : "<figcaption>\(p.imageCaption)</figcaption>") + "</figure>"
            : video
        let meta = [p.author, Fmt.postDate(p.date), "\(p.minutes)′ ανάγνωση"].filter { !$0.isEmpty }.joined(separator: " · ")
        return """
        <!doctype html><html lang="el"><head><meta charset="utf-8">
        <meta name="viewport" content="width=device-width,initial-scale=1,viewport-fit=cover">
        <style>
        \(fontsCSS)
        :root{color-scheme:dark}
        html,body{margin:0;background:#0B0B0A;color:#F3F1E9;-webkit-text-size-adjust:100%}
        body{font-family:Manrope,-apple-system,sans-serif;font-weight:500;font-size:\(Int(size))px;line-height:1.65;padding-bottom:40px}
        .wrap{max-width:760px;margin:0 auto;padding:0 18px}
        .hero{margin:0 0 16px}.hero img{width:100%;display:block;max-height:60vh;object-fit:cover}
        .hero figcaption{font-size:12px;color:#8E8A7C;padding:6px 18px 0}
        .vid{position:relative;padding-top:56.25%;margin-bottom:16px;background:#000}.vid iframe{position:absolute;inset:0;width:100%;height:100%;border:0}
        .cat{display:inline-block;background:#F9CF1C;color:#0B0B0A;font-weight:800;font-size:11px;letter-spacing:.06em;padding:4px 8px;border-radius:4px;text-transform:uppercase}
        h1.t{font-family:Sofia,-apple-system,sans-serif;font-weight:900;font-size:\(Int(size * 1.9))px;line-height:1.02;margin:12px 0 10px;text-transform:none}
        .meta{color:#8E8A7C;font-size:13px;font-weight:800;margin-bottom:14px}
        .lead{font-size:1.06em;color:#CFCBBE;font-weight:800;border-left:3px solid #F9CF1C;padding-left:12px;margin:0 0 18px}
        a{color:#F9CF1C}
        h2,h3,h4{font-weight:800;line-height:1.25;margin:1.4em 0 .5em}
        h2{font-size:1.3em}h3{font-size:1.15em}
        strong,b{font-weight:800}
        img{max-width:100%;height:auto;border-radius:10px}
        figure{margin:16px 0}figcaption{font-size:12px;color:#8E8A7C;margin-top:6px}
        blockquote{margin:16px 0;padding:4px 0 4px 14px;border-left:3px solid #F9CF1C;color:#CFCBBE}
        iframe,video,embed{max-width:100%;border:0}
        .wp-block-embed__wrapper{position:relative}
        .wp-block-embed.is-type-video .wp-block-embed__wrapper{padding-top:56.25%}
        .wp-block-embed.is-type-video iframe{position:absolute;inset:0;width:100%;height:100%}
        table{width:100%;border-collapse:collapse;font-size:.9em}td,th{border-bottom:1px solid #2A2924;padding:6px}
        hr{border:0;border-top:1px dashed #37352F;margin:24px 0}
        </style></head><body>
        \(hero)
        <div class="wrap">
        \(p.category.isEmpty ? "" : "<span class='cat'>\(esc(p.category))</span>")
        <h1 class="t">\(esc(p.title))</h1>
        <div class="meta">\(esc(meta))</div>
        \(p.excerpt.isEmpty ? "" : "<p class='lead'>\(esc(p.excerpt))</p>")
        \(p.html)
        </div></body></html>
        """
    }
}
