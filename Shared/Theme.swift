import SwiftUI
#if canImport(UIKit)
import UIKit
#endif
#if os(iOS)
import Vision
#endif

/// Design system «iOS 26 · Liquid Glass» (το σχέδιο του χρήστη) — ίδια χρώματα με το Android/site.
enum C {
    static let ink = Color(hex: 0x0B0B0A)       // Μαύρο
    static let ink2 = Color(hex: 0x0E0E0D)
    static let panel = Color(hex: 0x151514)     // Επιφάνεια
    static let panel2 = Color(hex: 0x1E1E1C)    // Επιφάνεια 2
    static let panel3 = Color(hex: 0x262624)
    static let line = Color(hex: 0x2C2C29)      // Γραμμή
    static let line2 = Color(hex: 0x3A3935)
    static let text = Color(hex: 0xF3F1E9)      // Κείμενο
    static let text2 = Color(hex: 0xCFCBBE)
    static let muted = Color(hex: 0x9A968A)     // Σιγαστό
    static let gold = Color(hex: 0xF9CF1C)      // Κίτρινο ΑΕΚ
    static let gold2 = Color(hex: 0xE0B400)
    static let live = Color(hex: 0xFF453A)      // Live
    static let win = Color(hex: 0x34C759)       // Θετικό
    static let loss = Color(hex: 0xFF453A)
    static let goldGrad = LinearGradient(colors: [Color(hex: 0xFFE14D), Color(hex: 0xF2C200)], startPoint: .top, endPoint: .bottom)
}

extension Color {
    init(hex: UInt32) {
        self.init(.sRGB, red: Double((hex >> 16) & 0xFF) / 255, green: Double((hex >> 8) & 0xFF) / 255, blue: Double(hex & 0xFF) / 255, opacity: 1)
    }
    init?(hexString: String) {
        guard let (r, g, b) = hexRGB(hexString) else { return nil }
        self.init(.sRGB, red: r, green: g, blue: b, opacity: 1)
    }
}

/// Τίτλοι: στενή γραμματοσειρά της μάρκας (Sofia Sans Extra Condensed 800/900)· όλα τα υπόλοιπα: σύστημα (SF Pro).
enum F {
    enum W { case regular, medium, semibold, bold, heavy }
    /// Κείμενο: Manrope (όπως στο Android/site)· στο ρολόι η γραμματοσειρά του συστήματος
    static func body(_ size: CGFloat, _ w: W = .regular) -> Font {
        #if os(watchOS)
        let wt: Font.Weight
        switch w { case .regular: wt = .regular; case .medium: wt = .medium; case .semibold: wt = .semibold; case .bold: wt = .bold; case .heavy: wt = .heavy }
        return .system(size: size, weight: wt)
        #else
        let n: String
        switch w {
        case .regular, .medium: n = "ManropeExtraLight-Medium"
        case .semibold, .bold: n = "ManropeExtraLight-Bold"
        case .heavy: n = "ManropeExtraLight-ExtraBold"
        }
        return .custom(n, fixedSize: size)
        #endif
    }
    /// Στενή γραμματοσειρά (τίτλοι, σκορ, ώρες)
    static func disp(_ size: CGFloat, black: Bool = true) -> Font {
        #if os(watchOS)
        return .system(size: size, weight: .heavy).width(.condensed)
        #else
        return .custom(black ? "SofiaSansExtraCondensed-Black" : "SofiaSansExtraCondensed-ExtraBold", fixedSize: size)
        #endif
    }
    /// Ετικέτα: κεφαλαία, bold, +8% απόσταση
    static func tag(_ size: CGFloat = 11) -> Font { body(size, .heavy) }
}

// MARK: - Liquid Glass (iOS 26) με εναλλακτικό υλικό για παλιότερα iOS

extension View {
    /// Γυαλί σε σχήμα κάψουλας/κύκλου/στρογγυλεμένου: μόνο για πλοήγηση, κουμπιά πάνω από εικόνα, φύλλα.
    @ViewBuilder func glass<S: Shape>(_ shape: S, tint: Color? = nil, interactive: Bool = false) -> some View {
        #if os(iOS) && compiler(>=6.2)
        if #available(iOS 26.0, *) {
            self.glassEffect(tint.map { Glass.regular.tint($0).interactive(interactive) } ?? Glass.regular.interactive(interactive), in: shape)
        } else { self.glassFallback(shape, tint: tint) }
        #else
        self.glassFallback(shape, tint: tint)
        #endif
    }
    @ViewBuilder func glassFallback<S: Shape>(_ shape: S, tint: Color?) -> some View {
        self
            #if os(iOS)
            .background(shape.fill(.ultraThinMaterial))
            #endif
            .background(shape.fill((tint ?? C.panel2).opacity(tint == nil ? 0.55 : 0.85)))
            .overlay(shape.stroke(LinearGradient(colors: [.white.opacity(0.22), .white.opacity(0.04)], startPoint: .top, endPoint: .bottom), lineWidth: 1))
            .clipShape(shape)
    }
    /// Κάρτα περιεχομένου (όχι γυαλί): στέρεη επιφάνεια με λεπτό περίγραμμα, ακτίνα 28
    func card(_ r: CGFloat = 24, fill: Color = C.panel) -> some View {
        self.background(RoundedRectangle(cornerRadius: r, style: .continuous).fill(fill))
            .overlay(RoundedRectangle(cornerRadius: r, style: .continuous).stroke(C.line, lineWidth: 1))
    }
}

/// Φόρτωση εικόνων με δική μας μνήμη (γρήγορο ξανα-άνοιγμα, γνωστό μέγεθος εικόνας → σωστό κάδρο).
/// Βρίσκει και το «σημαντικό σημείο» κάθε φωτογραφίας (πρόσωπα, αλλιώς ό,τι τραβάει το μάτι — Vision του iPhone),
/// ώστε όταν η φωτογραφία γεμίζει ένα κουτί άλλου σχήματος να κόβεται γύρω από αυτό (όχι κεφάλια).
@MainActor
final class ImageLoader: ObservableObject {
    static let cache: NSCache<NSURL, UIImage> = { let c = NSCache<NSURL, UIImage>(); c.totalCostLimit = 80 << 20; return c }()
    /// Σημαντικό σημείο ανά εικόνα (0–1, πάνω-αριστερά = 0,0)
    static var focals: [URL: CGPoint] = [:]
    @Published var image: UIImage?
    @Published var focal = CGPoint(x: 0.5, y: 0.35)
    private var url: URL?
    private var task: Task<Void, Never>?

    func load(_ u: URL?, focus: Bool = false) {
        guard u != url else { return }
        url = u; task?.cancel()
        guard let u else { image = nil; return }
        if let i = ImageLoader.cache.object(forKey: u as NSURL), !focus || ImageLoader.focals[u] != nil {
            image = i; if let f = ImageLoader.focals[u] { focal = f }; return
        }
        image = nil
        task = Task { [weak self] in
            var img = ImageLoader.cache.object(forKey: u as NSURL)
            if img == nil {
                guard let res = try? await URLSession.shared.data(from: u), !Task.isCancelled else { return }
                let d = res.0
                img = await Task.detached(priority: .userInitiated) { () -> UIImage? in
                    #if os(iOS)
                    return UIImage(data: d)?.preparingForDisplay() ?? UIImage(data: d)
                    #else
                    return UIImage(data: d)
                    #endif
                }.value
                guard let i = img, !Task.isCancelled else { return }
                ImageLoader.cache.setObject(i, forKey: u as NSURL, cost: Int(i.size.width * i.size.height * i.scale * i.scale * 4))
            }
            // μόνο αν η εικόνα ζητείται ΑΚΟΜΑ (αλλιώς μια παλιά λήψη έγραφε πάνω στη νέα: λάθος σήμα ομάδας)
            guard let i = img, let self, self.url == u, !Task.isCancelled else { return }
            // η φωτογραφία φαίνεται ΑΜΕΣΩΣ· το έξυπνο κάδρο έρχεται μετά, σε δική του ουρά (δεν μπλοκάρει τίποτα)
            withAnimation(.easeOut(duration: 0.2)) { self.image = i }
            #if os(iOS)
            if focus, ImageLoader.focals[u] == nil {
                Focus.queue.async {
                    let f = Focus.point(i) ?? CGPoint(x: 0.5, y: 0.35)
                    Task { @MainActor [weak self] in
                        ImageLoader.focals[u] = f
                        guard let self, self.url == u else { return }
                        withAnimation(.easeOut(duration: 0.25)) { self.focal = f }
                    }
                }
            }
            #endif
        }
    }
}

#if os(iOS)
/// Πού «κοιτάει» μια φωτογραφία: πρόσωπα (όλα μαζί) → αλλιώς το πιο ενδιαφέρον σημείο → αλλιώς λίγο πάνω από το κέντρο.
enum Focus {
    /// Δική της σειριακή ουρά χαμηλής προτεραιότητας: μία ανάλυση τη φορά, ποτέ στα threads της εφαρμογής
    static let queue = DispatchQueue(label: "gr.aekhub.focus", qos: .utility)

    static func point(_ img: UIImage) -> CGPoint? {
        guard let src = img.cgImage else { return nil }
        // μικρό αντίγραφο (≤256px): αρκεί για πρόσωπα/κάδρο και είναι πολύ γρήγορο
        let k = min(1, 256 / CGFloat(max(src.width, src.height)))
        let w = max(1, Int(CGFloat(src.width) * k)), h = max(1, Int(CGFloat(src.height) * k))
        guard let ctx = CGContext(data: nil, width: w, height: h, bitsPerComponent: 8, bytesPerRow: 0,
                                  space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue) else { return nil }
        ctx.interpolationQuality = .low
        ctx.draw(src, in: CGRect(x: 0, y: 0, width: w, height: h))
        guard let cg = ctx.makeImage() else { return nil }
        let handler = VNImageRequestHandler(cgImage: cg, options: [:])
        let faces = VNDetectFaceRectanglesRequest()
        try? handler.perform([faces])
        // Vision: 0–1 με αρχή κάτω-αριστερά
        if let fs = faces.results, !fs.isEmpty {
            let u = fs.map(\.boundingBox).reduce(fs[0].boundingBox) { $0.union($1) }
            // λίγο πάνω από τα πρόσωπα, για να χωράει και το κεφάλι ολόκληρο
            return CGPoint(x: u.midX, y: max(0, 1 - u.midY - u.height * 0.15))
        }
        let sal = VNGenerateAttentionBasedSaliencyImageRequest()
        try? handler.perform([sal])
        if let o = sal.results?.first?.salientObjects, !o.isEmpty {
            let u = o.map(\.boundingBox).reduce(o[0].boundingBox) { $0.union($1) }
            return CGPoint(x: u.midX, y: max(0, 1 - u.maxY + u.height * 0.35))
        }
        return CGPoint(x: 0.5, y: 0.35)
    }
}
#endif

/// Εικόνα από το δίκτυο με γκρι φόντο μέχρι να φορτώσει.
struct NetImage: View {
    let url: String
    var w: Int = 800
    var mode: ContentMode = .fill
    @StateObject private var l = ImageLoader()
    var body: some View {
        Group {
            if let i = l.image { Image(uiImage: i).resizable().aspectRatio(contentMode: mode) }
            else { Rectangle().fill(C.panel2) }
        }
        .task(id: url) { l.load(Img.url(url, w: w)) }
    }
}

/// Φωτογραφία που ΓΕΜΙΖΕΙ πάντα το κουτί της (χωρίς κενά), κομμένη γύρω από τα πρόσωπα / το σημαντικό σημείο
/// (όχι στο κέντρο στα τυφλά → δεν κόβονται κεφάλια). Όταν το σχήμα ταιριάζει, φαίνεται σχεδόν ολόκληρη.
struct WholeImage: View {
    let url: String
    var w: Int = 800
    @StateObject private var l = ImageLoader()
    var body: some View {
        GeometryReader { g in
            if let i = l.image, i.size.width > 0, i.size.height > 0, g.size.width > 0, g.size.height > 0 {
                let s = max(g.size.width / i.size.width, g.size.height / i.size.height)
                let sw = i.size.width * s, sh = i.size.height * s
                // θέση ώστε το σημαντικό σημείο να πέφτει όσο πιο κοντά στο κέντρο γίνεται, χωρίς κενά
                let x = min(0, max(g.size.width - sw, g.size.width / 2 - l.focal.x * sw))
                let y = min(0, max(g.size.height - sh, g.size.height / 2 - l.focal.y * sh))
                Image(uiImage: i).resizable().frame(width: sw, height: sh)
                    .offset(x: x, y: y)
                    .frame(width: g.size.width, height: g.size.height, alignment: .topLeading)
                    .clipped()
            } else {
                Rectangle().fill(C.panel2)
            }
        }
        .task(id: url) { l.load(Img.url(url, w: w), focus: true) }
    }
}

/// Εικόνα σε κουτί σταθερού ύψους, χωρίς ποτέ να το μεγαλώνει (αλλιώς το scaledToFill «φαρδαίνει» την οθόνη).
/// Γεμίζει το κουτί με έξυπνο κάδρο (WholeImage).
struct FillImage: View {
    let url: String
    var w: Int = 800
    var height: CGFloat? = nil
    var body: some View {
        Color.clear
            .frame(maxWidth: .infinity)
            .frame(height: height)
            .overlay(WholeImage(url: url, w: w))
            .clipped()
    }
}

/// Φωτογραφία στο φυσικό της σχήμα (πλάτος οθόνης), όλη, με όριο ύψους· πολύ κάθετες → θολό φόντο στα πλάγια.
struct NaturalImage: View {
    let url: String
    var w: Int = 1400
    var maxH: CGFloat = 520
    @StateObject private var l = ImageLoader()
    var body: some View {
        Group {
            if let i = l.image, i.size.width > 0 {
                Color.clear
                    .aspectRatio(max(i.size.width / i.size.height, 0.1), contentMode: .fit)
                    .frame(maxWidth: .infinity).frame(maxHeight: maxH)
                    .overlay(WholeImage(url: url, w: w))
                    .clipped()
            } else {
                Color.clear.aspectRatio(16 / 9, contentMode: .fit).frame(maxWidth: .infinity).background(C.panel2)
            }
        }
        .task(id: url) { l.load(Img.url(url, w: w)) }
    }
}

/// Λογότυπο ομάδας (CDN, μικρό)· αν λείπει → κύκλος με τα αρχικά
struct TeamLogo: View {
    let url: String
    var size: CGFloat = 28
    var name: String = ""
    @StateObject private var l = ImageLoader()
    var body: some View {
        ZStack {
            if let i = l.image { Image(uiImage: i).resizable().scaledToFit() }
            else {
                Circle().fill(C.panel3).overlay(Text(String(name.upperGr.prefix(3))).font(.system(size: max(8, size / 3.4), weight: .heavy)).foregroundStyle(C.text2))
            }
        }
        .frame(width: size, height: size)
        .task(id: url) { l.load(Img.url(url, w: 160)) }
    }
}

/// Κόκκινη τελεία που «αναπνέει» (live)
struct LiveDot: View {
    var size: CGFloat = 8
    var color: Color = C.live
    @State private var on = false
    var body: some View {
        Circle().fill(color).frame(width: size, height: size)
            .overlay(Circle().stroke(color.opacity(0.35), lineWidth: 3).scaleEffect(on ? 1.9 : 1).opacity(on ? 0 : 1))
            .onAppear { withAnimation(.easeOut(duration: 1.2).repeatForever(autoreverses: false)) { on = true } }
    }
}

/// Κεκλιμένη κίτρινη ετικέτα (όπως στο Android: «ΤΕΛΕΥΤΑΙΑ ΝΕΑ», πανό διοργάνωσης)
struct SlantShape: Shape {
    var k: CGFloat = 10
    func path(in r: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: r.minX + k, y: r.minY)); p.addLine(to: CGPoint(x: r.maxX, y: r.minY))
        p.addLine(to: CGPoint(x: r.maxX - k, y: r.maxY)); p.addLine(to: CGPoint(x: r.minX, y: r.maxY)); p.closeSubpath()
        return p
    }
}
