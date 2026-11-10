import SwiftUI
import WebKit
import SafariServices
import AVKit

/// Άρθρο — όπως το Android ArticleScreen: φωτογραφία (ολόκληρη) ή βίντεο (παίζει σε pop up) · κατηγορία/χρόνος ·
/// τίτλος · περίληψη · συντάκτης με φωτογραφία · κείμενο (WKWebView που παίρνει το ύψος του, ώστε να μπαίνουν
/// διαφημίσεις ανάμεσα) · «Διάβασε επίσης». Πάνω: πίσω / Aa / 🔖 / κοινοποίηση στη μπάρα του συστήματος.
struct ArticleView: View {
    let id: Int
    let card: PostCard?
    @State private var post: Post?
    @State private var error: String?
    private let size: Double = 17   // σταθερό μέγεθος γραμμάτων (ο χρήστης έβγαλε τη ρύθμιση)
    @State private var openURL: URL?
    @State private var showComments = false
    @State private var showVideo = false
    @State private var comments = 0
    @State private var more: [PostCard] = []
    @State private var heights: [Int: CGFloat] = [:]
    @ObservedObject var prefs = Prefs.shared
    @ObservedObject var app = AppState.shared
    @ObservedObject private var ads = Ads.shared
    @Environment(\.dismiss) var dismiss

    init(id: Int, card: PostCard?) {
        self.id = id; self.card = card
        _post = State(initialValue: Api.shared.peek(Api.pPost(id)).map(Post.init))
    }

    var link: URL? { (post?.link ?? card?.link).flatMap { URL(string: $0) } }
    var scale: CGFloat { CGFloat(size) / 17 }
    var adsIn: Bool { (app.config?.ads.article ?? false) && !ads.adFree }

    var body: some View {
        GeometryReader { g in
            let aside = g.size.width > 1050 && !more.isEmpty
            HStack(alignment: .top, spacing: 0) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        hero(wide: g.size.width > 700, top: Self.notchTop(g.safeAreaInsets.top))
                        if let p = post {
                            head(p).padding(.horizontal, 20).padding(.top, 18)
                            bodyParts(p).padding(.top, 14)
                            if !aside { related.padding(.horizontal, 16).padding(.top, 18) }
                        } else if let error {
                            EmptyState(icon: "wifi.exclamationmark", text: error) { Task { await load() } }.padding(.top, 40)
                        } else {
                            if let c = card {
                                Text(c.title.upperGr).font(F.disp(34)).foregroundStyle(C.text).padding(.horizontal, 20).padding(.top, 18)
                            }
                            ProgressView().tint(C.gold).frame(maxWidth: .infinity).padding(40)
                        }
                    }
                    .padding(.bottom, 110)
                    .frame(maxWidth: 760).frame(maxWidth: .infinity)
                }
                .ignoresSafeArea(edges: .top)
                if aside {
                    ScrollView { related.padding(.top, 90).padding(.horizontal, 8).padding(.bottom, 40) }
                        .frame(width: 360).ignoresSafeArea(edges: .top)
                        .background(C.ink2)
                }
            }
        }
        .background(C.ink.ignoresSafeArea())
        .navigationBarBackButtonHidden(true)
        .toolbar(.visible, for: .navigationBar)
        .toolbarBackground(.hidden, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                NavIcon(icon: "chevron.left") { dismiss() }
            }
            ToolbarItemGroup(placement: .navigationBarTrailing) {
                if let c = post?.card ?? card {
                    NavIcon(icon: prefs.isSaved(id) ? "bookmark.fill" : "bookmark", tint: C.gold) { haptic(); prefs.toggleSaved(c) }
                }
                if let u = link { ShareLink(item: u) { NavIconLabel(icon: "square.and.arrow.up") } }
            }
        }
        // Κάτω: Σχόλια (γυαλί) + Κοινοποίηση (κίτρινο)
        .safeAreaInset(edge: .bottom) {
            if post != nil {
                HStack(spacing: 12) {
                    Button { showComments = true } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "text.bubble").foregroundStyle(C.gold)
                            Text(comments > 0 ? "Σχόλια (\(comments))" : "Σχόλια").font(F.body(16, .semibold)).foregroundStyle(C.text)
                        }
                        .padding(.horizontal, 22).frame(height: 54)
                        .glass(Capsule(), interactive: true)
                    }.buttonStyle(.plain)
                    if let u = link {
                        ShareLink(item: u) {
                            HStack(spacing: 8) {
                                Image(systemName: "square.and.arrow.up")
                                Text("Κοινοποίηση").font(F.body(16, .semibold))
                            }
                            .foregroundStyle(C.ink)
                            .frame(maxWidth: .infinity).frame(height: 54)
                            .background(Capsule().fill(C.goldGrad).shadow(color: C.gold.opacity(0.4), radius: 14, y: 4))
                        }
                    }
                }
                .frame(maxWidth: 560)
                .padding(.horizontal, 16).padding(.bottom, 4)
            }
        }
        .sheet(item: $openURL) { SafariView(url: $0).ignoresSafeArea() }
        .sheet(isPresented: $showComments) { CommentsView(postId: id, title: post?.title ?? "") }
        .fullScreenCover(isPresented: $showVideo) {
            if let v = post?.videoInfo { VideoPopup(title: post?.title ?? "", v: v) }
        }
        .onDisappear { Ads.shared.onArticleClosed() }
        .task {
            Analytics.screen(1, id)
            await load()
            async let c = try? CommentsApi.call("comments/\(id)?sort=new&page=1")
            async let f = try? Api.shared.feed(nil, page: 1)
            let (cc, ff) = await (c, f)
            if let cc { comments = cc["total"].int }
            if let ff { more = Array(ff.items.filter { $0.id != id }.prefix(5)) }
        }
    }

    func load() async {
        do { post = try await Api.shared.post(id); error = nil; if let c = post?.card { prefs.addHistory(c) } }
        catch { if post == nil { self.error = "Δεν φόρτωσε το άρθρο.\n" + error.localizedDescription } }
    }

    // MARK: Φωτογραφία / βίντεο

    /// Μόνο το ύψος του νοτς / της ώρας (ΟΧΙ και της μπάρας με τα κουμπιά): η φωτογραφία ξεκινά ακριβώς κάτω από το νοτς
    /// και τα κουμπιά (πίσω, αποθήκευση, κοινοποίηση) κάθονται πάνω της (ζήτησε ο χρήστης)
    static func notchTop(_ fallback: CGFloat) -> CGFloat {
        let w = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.flatMap(\.windows).first { $0.isKeyWindow }
        if let t = w?.safeAreaInsets.top, t > 0 { return t }
        return min(fallback, 59)
    }

    /// Πάνω από τη φωτογραφία (ώρα / νοτς): η ίδια φωτογραφία θολή, σαν να συνεχίζει — η καθαρή ξεκινά κάτω από το νοτς
    func notchStrip(_ url: String, _ top: CGFloat) -> some View {
        ZStack(alignment: .bottom) {
            Color.black
            if !url.isEmpty {
                FillImage(url: url, w: 300, height: top + 80).blur(radius: 18).scaleEffect(1.25, anchor: .bottom)
                    .opacity(0.9)
            }
            LinearGradient(colors: [.black.opacity(0.35), .black.opacity(0.05)], startPoint: .top, endPoint: .bottom)
        }
        .frame(height: max(top, 20), alignment: .bottom).clipped()
    }

    @ViewBuilder func hero(wide: Bool, top: CGFloat) -> some View {
        let img = post?.image ?? card?.image ?? ""
        if let v = post?.videoInfo, !(v.embed.isEmpty && v.html.isEmpty) {
            // Video post: το βίντεο πάνω, παίζει σε pop up
            let th = v.thumb.isEmpty ? img : v.thumb
            VStack(spacing: 0) {
                notchStrip(th, top)
                Button { haptic(); showVideo = true } label: {
                    ZStack(alignment: .bottomLeading) {
                        FillImage(url: th, w: 1400).aspectRatio(16 / 9, contentMode: .fit)
                        LinearGradient(colors: [.black.opacity(0.35), .clear, .clear, .black.opacity(0.6)], startPoint: .top, endPoint: .bottom)
                        Image(systemName: "play.fill").font(.system(size: 34, weight: .bold)).foregroundStyle(C.ink)
                            .frame(width: 76, height: 76).background(Circle().fill(C.gold)).shadow(color: .black.opacity(0.4), radius: 12)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                        Text("▶ ΔΕΣ ΤΟ ΒΙΝΤΕΟ").font(F.body(12, .heavy)).tracking(0.8).foregroundStyle(.white).padding(14)
                    }
                }
                .buttonStyle(.plain)
            }
        } else if !img.isEmpty {
            VStack(spacing: 0) {
                notchStrip(img, top)
                NaturalImage(url: img, w: 1400, maxH: wide ? 640 : 520)
                    .overlay(alignment: .top) {
                        LinearGradient(colors: [.black.opacity(0.45), .clear], startPoint: .top, endPoint: .bottom).frame(height: 90) // να φαίνονται τα κουμπιά πάνω στη φωτό
                    }
            }
        } else {
            Color.clear.frame(height: top + 56)
        }
    }

    // MARK: Τίτλος, περίληψη, συντάκτης

    func head(_ p: Post) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                if !p.category.isEmpty { Tag(text: p.category) }
                Text("⏱ \(p.minutes)′ ανάγνωση").font(F.body(11, .heavy)).foregroundStyle(C.text2)
                    .padding(.horizontal, 8).padding(.vertical, 4).background(RoundedRectangle(cornerRadius: 6).fill(C.panel2))
            }
            Text(p.title.upperGr).font(F.disp(34 * scale)).foregroundStyle(C.text).lineSpacing(-2).fixedSize(horizontal: false, vertical: true)
            if !p.excerpt.isEmpty {
                HStack(alignment: .top, spacing: 12) {
                    RoundedRectangle(cornerRadius: 2).fill(C.gold).frame(width: 3)
                    Text(p.excerpt).font(F.body(17 * scale, .semibold)).foregroundStyle(C.text).lineSpacing(5).fixedSize(horizontal: false, vertical: true)
                }
            }
            HStack(spacing: 12) {
                AuthorAvatar(url: p.authorAvatar, name: p.author)
                VStack(alignment: .leading, spacing: 2) {
                    Text(p.author.isEmpty ? "AEK Hub" : p.author).font(F.body(15, .heavy)).foregroundStyle(C.text)
                    Text(Fmt.postDate(p.date)).font(F.body(12)).foregroundStyle(C.muted)
                }
                Spacer(minLength: 0)
                if let u = link {
                    ShareLink(item: u) {
                        Image(systemName: "square.and.arrow.up").font(.system(size: 17, weight: .semibold)).foregroundStyle(C.gold)
                            .frame(width: 40, height: 40).background(Circle().fill(C.panel2))
                    }
                }
            }
            .padding(12)
            .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(C.panel))
            if !p.imageCaption.isEmpty && p.videoInfo == nil {
                Text("📷 " + p.imageCaption.plainText).font(F.body(11)).foregroundStyle(C.muted)
            }
        }
    }

    // MARK: Κείμενο (σε κομμάτια, με διαφημίσεις ανάμεσα όπως στο Android: μετά την 3η και την 8η παράγραφο + στο τέλος)

    @ViewBuilder func bodyParts(_ p: Post) -> some View {
        let parts = adsIn ? ArticleHTML.split(p.html) : [p.html]
        VStack(spacing: 0) {
            ForEach(parts.indices, id: \.self) { i in
                ArticleWeb(html: ArticleHTML.body(parts[i], size: size), onLink: { openURL = $0 }) { h in
                    if abs((heights[i] ?? 0) - h) > 1 { heights[i] = h }
                }
                .frame(height: heights[i] ?? 1)
                if adsIn { BannerAd(place: "article", medium: true).padding(.horizontal, 16) }
            }
        }
    }

    @ViewBuilder var related: some View {
        if !more.isEmpty {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 10) {
                    Rectangle().fill(C.gold).frame(width: 4, height: 22)
                    Text("ΔΙΑΒΑΣΕ ΕΠΙΣΗΣ").font(F.disp(22)).foregroundStyle(C.text)
                }.padding(.bottom, 4)
                ForEach(more) { PostRow(p: $0) }
                if let so = app.config?.socials, !so.isEmpty {
                    SocialSection(list: so).padding(.top, 14)
                }
            }
        }
    }
}

/// Φωτογραφία συντάκτη (gravatar) — αν λείπει, αρχικά σε κύκλο
struct AuthorAvatar: View {
    let url: String
    let name: String
    var size: CGFloat = 46
    var body: some View {
        ZStack {
            Circle().fill(C.panel2)
            Text(initials).font(.system(size: size * 0.33, weight: .heavy)).foregroundStyle(C.gold)
            if !url.isEmpty { NetImage(url: url, w: 200).clipShape(Circle()) }
        }
        .frame(width: size, height: size)
        .overlay(Circle().stroke(C.gold, lineWidth: 1.5))
    }
    var initials: String {
        let s = name.split(separator: " ").prefix(2).compactMap { $0.first.map(String.init) }.joined().uppercased()
        return s.isEmpty ? "AH" : s
    }
}

// MARK: - Κουμπιά μπάρας (στο iOS 26 μπαίνουν μόνα τους σε γυαλί· πριν, σκούρος κύκλος)

var liquidBars: Bool {
    #if compiler(>=6.2)
    if #available(iOS 26.0, *) { return true }
    #endif
    return false
}

struct NavIconLabel: View {
    var icon: String? = nil
    var text: String? = nil
    var tint: Color = C.text
    var body: some View {
        Group {
            if let icon { Image(systemName: icon).font(.system(size: 17, weight: .semibold)) }
            else if let text { Text(text).font(.system(size: 16, weight: .bold)) }
        }
        .foregroundStyle(tint)
        .frame(width: 40, height: 40)
        .background { if !liquidBars { Circle().fill(Color.black.opacity(0.55)) } }
        .contentShape(Circle())
    }
}

struct NavIcon: View {
    let icon: String
    var tint: Color = C.text
    var action: () -> Void
    var body: some View {
        Button(action: action) { NavIconLabel(icon: icon, tint: tint) }.buttonStyle(.plain)
    }
}

// MARK: - Βίντεο σε pop up (όπως Android VideoDialog)

struct VideoPopup: View {
    let title: String
    let v: VideoInfo
    @Environment(\.dismiss) var dismiss
    var isFile: Bool { v.embed.range(of: #"\.(mp4|m4v|mov|m3u8)(\?|$)"#, options: [.regularExpression, .caseInsensitive]) != nil }
    var body: some View {
        ZStack {
            Color.black.opacity(0.94).ignoresSafeArea().onTapGesture { dismiss() }
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top, spacing: 10) {
                    Text(title).font(F.body(15, .heavy)).foregroundStyle(C.text).lineLimit(2)
                    Spacer(minLength: 0)
                    Button { dismiss() } label: {
                        Image(systemName: "xmark").font(.system(size: 16, weight: .bold)).foregroundStyle(C.text)
                            .frame(width: 40, height: 40).background(Circle().fill(C.panel2))
                    }.buttonStyle(.plain)
                }
                Group {
                    if isFile, let u = URL(string: v.embed) {
                        FilePlayer(url: u)
                    } else {
                        EmbedPlayer(html: v.html, embed: v.embed)
                    }
                }
                .aspectRatio(16 / 9, contentMode: .fit)
                .background(Color.black)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .padding(12)
            .frame(maxWidth: 1000)
        }
        .preferredColorScheme(.dark)
    }
}

struct FilePlayer: View {
    let url: URL
    @State private var player: AVPlayer?
    var body: some View {
        VideoPlayer(player: player)
            .onAppear { player = AVPlayer(url: url); player?.play() }
            .onDisappear { player?.pause() }
    }
}

/// Ο επίσημος player της υπηρεσίας (YouTube, FirstView, Facebook…) σε iframe, με βάση το aekhub.gr
struct EmbedPlayer: UIViewRepresentable {
    let html: String
    let embed: String
    func makeUIView(context: Context) -> WKWebView {
        let cfg = WKWebViewConfiguration()
        cfg.allowsInlineMediaPlayback = true
        cfg.mediaTypesRequiringUserActionForPlayback = []
        let w = WKWebView(frame: .zero, configuration: cfg)
        w.isOpaque = false; w.backgroundColor = .black; w.scrollView.isScrollEnabled = false
        let inner = html.isEmpty
            ? "<iframe src=\"\(ArticleHTML.esc(embed))\" allow=\"autoplay; encrypted-media; fullscreen; picture-in-picture\" referrerpolicy=\"strict-origin-when-cross-origin\" allowfullscreen></iframe>"
            : html
        let page = """
        <!doctype html><html><head><meta name="viewport" content="width=device-width,initial-scale=1,maximum-scale=1">
        <style>html,body{margin:0;height:100%;background:#000;overflow:hidden}iframe,video{position:absolute;inset:0;width:100%;height:100%;border:0}</style></head>
        <body>\(inner)</body></html>
        """
        w.loadHTMLString(page, baseURL: URL(string: Api.site + "/"))
        return w
    }
    func updateUIView(_ w: WKWebView, context: Context) {}
    static func dismantleUIView(_ w: WKWebView, coordinator: ()) { w.loadHTMLString("", baseURL: nil) }
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

// MARK: - Κείμενο σε WKWebView που παίρνει το ύψος του περιεχομένου

struct ArticleWeb: UIViewRepresentable {
    let html: String
    var onLink: (URL) -> Void
    var onHeight: (CGFloat) -> Void

    func makeCoordinator() -> Coord { Coord(onLink: onLink, onHeight: onHeight) }

    func makeUIView(context: Context) -> WKWebView {
        let cfg = WKWebViewConfiguration()
        cfg.allowsInlineMediaPlayback = true
        cfg.mediaTypesRequiringUserActionForPlayback = []
        // Ύψος περιεχομένου → SwiftUI (ResizeObserver: αλλάζει και όταν φορτώνουν embeds)
        cfg.userContentController.add(WeakHandler(context.coordinator), name: "h")
        cfg.userContentController.addUserScript(WKUserScript(source: """
            (function(){var c=document.getElementById('c');if(!c)return;
            var f=function(){webkit.messageHandlers.h.postMessage(Math.ceil(c.getBoundingClientRect().height)+2)};
            new ResizeObserver(f).observe(c);window.addEventListener('load',f);f();})();
            """, injectionTime: .atDocumentEnd, forMainFrameOnly: true))
        let w = WKWebView(frame: CGRect(x: 0, y: 0, width: 360, height: 1), configuration: cfg)
        w.isOpaque = false
        w.backgroundColor = UIColor(C.ink)
        w.scrollView.backgroundColor = UIColor(C.ink)
        w.scrollView.isScrollEnabled = false
        w.scrollView.bounces = false
        w.scrollView.contentInsetAdjustmentBehavior = .never
        w.navigationDelegate = context.coordinator
        w.allowsLinkPreview = true
        return w
    }

    func updateUIView(_ w: WKWebView, context: Context) {
        context.coordinator.onLink = onLink
        context.coordinator.onHeight = onHeight
        guard context.coordinator.loaded != html else { return }
        context.coordinator.loaded = html
        // Βάση https://aekhub.gr/ ώστε τα embeds (π.χ. YouTube) να βλέπουν σωστό referrer
        w.loadHTMLString(html, baseURL: URL(string: Api.site + "/"))
    }

    final class Coord: NSObject, WKNavigationDelegate, WKScriptMessageHandler {
        var onLink: (URL) -> Void
        var onHeight: (CGFloat) -> Void
        var loaded = ""
        init(onLink: @escaping (URL) -> Void, onHeight: @escaping (CGFloat) -> Void) { self.onLink = onLink; self.onHeight = onHeight }
        func userContentController(_ u: WKUserContentController, didReceive m: WKScriptMessage) {
            if let h = (m.body as? NSNumber)?.doubleValue, h > 0 { DispatchQueue.main.async { self.onHeight(CGFloat(h)) } }
        }
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

/// Το WKUserContentController κρατά ισχυρά τον handler → ενδιάμεσος με weak, για να μη μένουν web views στη μνήμη
final class WeakHandler: NSObject, WKScriptMessageHandler {
    weak var target: WKScriptMessageHandler?
    init(_ t: WKScriptMessageHandler) { target = t }
    func userContentController(_ u: WKUserContentController, didReceive m: WKScriptMessage) { target?.userContentController(u, didReceive: m) }
}

enum ArticleHTML {
    /// Οι γραμματοσειρές του app μέσα στο HTML (base64), αφού η σελίδα «ζει» στο https://aekhub.gr/.
    static let fontsCSS: String = {
        func face(_ file: String, _ fam: String, _ w: Int) -> String {
            guard let u = Bundle.main.url(forResource: file, withExtension: "ttf"), let d = try? Data(contentsOf: u) else { return "" }
            return "@font-face{font-family:'\(fam)';font-weight:\(w);src:url(data:font/ttf;base64,\(d.base64EncodedString())) format('truetype');}"
        }
        return face("Manrope-Medium", "Manrope", 500) + face("Manrope-ExtraBold", "Manrope", 800)
    }()

    static func esc(_ s: String) -> String {
        s.replacingOccurrences(of: "&", with: "&amp;").replacingOccurrences(of: "<", with: "&lt;").replacingOccurrences(of: ">", with: "&gt;").replacingOccurrences(of: "\"", with: "&quot;")
    }

    /// Κόβει το κείμενο μετά την 3η (και την 8η) παράγραφο του πρώτου επιπέδου, για διαφήμιση ανάμεσα (όπως Android).
    static func split(_ html: String) -> [String] {
        let ns = html as NSString
        guard let re = try? NSRegularExpression(pattern: "<(/?)([a-zA-Z0-9]+)[^>]*>") else { return [html] }
        let containers: Set<String> = ["div", "figure", "blockquote", "ul", "ol", "table", "section", "iframe", "script", "aside", "details"]
        var depth = 0
        var ends: [Int] = []
        for m in re.matches(in: html, range: NSRange(location: 0, length: ns.length)) {
            let close = ns.substring(with: m.range(at: 1)) == "/"
            let tag = ns.substring(with: m.range(at: 2)).lowercased()
            if containers.contains(tag) {
                let selfClosing = ns.substring(with: m.range).hasSuffix("/>")
                if !selfClosing { depth = max(0, depth + (close ? -1 : 1)) }
            } else if tag == "p", close, depth == 0 {
                ends.append(m.range.location + m.range.length)
            }
        }
        var cuts: [Int] = []
        if ends.count > 5 { cuts.append(ends[2]) }
        if ends.count > 11 { cuts.append(ends[7]) }
        guard !cuts.isEmpty else { return [html] }
        var parts: [String] = []
        var last = 0
        for c in cuts { parts.append(ns.substring(with: NSRange(location: last, length: c - last))); last = c }
        parts.append(ns.substring(from: last))
        return parts
    }

    static func body(_ html: String, size: Double) -> String {
        """
        <!doctype html><html lang="el"><head><meta charset="utf-8">
        <meta name="viewport" content="width=device-width,initial-scale=1,maximum-scale=1">
        <style>
        \(fontsCSS)
        :root{color-scheme:dark}
        html,body{margin:0;padding:0;background:#0B0B0A;color:#F3F1E9;-webkit-text-size-adjust:100%}
        body{font-family:Manrope,-apple-system,system-ui,sans-serif;font-weight:500;font-size:\(Int(size))px;line-height:1.65}
        #c{padding:1px 20px}
        #c>*:first-child{margin-top:0}
        p{margin:0 0 1em}
        a{color:#F9CF1C}
        h2,h3,h4{font-weight:800;line-height:1.25;margin:1.4em 0 .5em}
        h2{font-size:1.25em}h3{font-size:1.12em}
        strong,b{font-weight:800}
        img{max-width:100%;height:auto;border-radius:16px;display:block;margin:0 auto}
        figure{margin:18px 0;max-width:100%!important}figcaption{font-size:13px;color:#9A968A;margin-top:6px}
        blockquote{margin:18px 0;padding:4px 0 4px 14px;border-left:3px solid #F9CF1C;color:#CFCBBE}
        blockquote.twitter-tweet,blockquote.instagram-media,blockquote.tiktok-embed{border:0;padding:0;color:inherit}
        iframe,video,embed{max-width:100%;border:0}
        .wp-block-embed__wrapper{position:relative}
        .wp-block-embed.is-type-video .wp-block-embed__wrapper{padding-top:56.25%}
        .wp-block-embed.is-type-video iframe{position:absolute;inset:0;width:100%;height:100%}
        table{width:100%;border-collapse:collapse;font-size:.9em}td,th{border-bottom:1px solid #2C2C29;padding:6px}
        hr{border:0;border-top:1px dashed #3A3935;margin:24px 0}
        ul,ol{padding-left:1.2em}
        </style></head><body><div id="c">
        \(html)
        </div></body></html>
        """
    }
}
