import SwiftUI
#if canImport(UIKit)
import UIKit
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
@MainActor
final class ImageLoader: ObservableObject {
    static let cache: NSCache<NSURL, UIImage> = { let c = NSCache<NSURL, UIImage>(); c.totalCostLimit = 120 << 20; return c }()
    @Published var image: UIImage?
    private var url: URL?
    private var task: Task<Void, Never>?

    func load(_ u: URL?) {
        guard u != url else { return }
        url = u; task?.cancel()
        guard let u else { image = nil; return }
        if let i = ImageLoader.cache.object(forKey: u as NSURL) { image = i; return }
        image = nil
        task = Task { [weak self] in
            guard let (d, _) = try? await URLSession.shared.data(from: u), !Task.isCancelled else { return }
            let img: UIImage? = await Task.detached(priority: .userInitiated) { () -> UIImage? in
                #if os(iOS)
                return UIImage(data: d)?.preparingForDisplay() ?? UIImage(data: d)
                #else
                return UIImage(data: d)
                #endif
            }.value
            guard let img, !Task.isCancelled else { return }
            ImageLoader.cache.setObject(img, forKey: u as NSURL, cost: Int(img.size.width * img.size.height * img.scale * img.scale * 4))
            withAnimation(.easeOut(duration: 0.2)) { self?.image = img }
        }
    }
}

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
        .onAppear { l.load(Img.url(url, w: w)) }
        .onChange(of: url) { _ in l.load(Img.url(url, w: w)) }
    }
}

/// Φωτογραφία ΟΛΟΚΛΗΡΗ και κεντραρισμένη μέσα σε κουτί: αν το σχήμα της ταιριάζει περίπου με το κουτί γεμίζει
/// (χάνεται ελάχιστο), αλλιώς φαίνεται όλη και το υπόλοιπο γεμίζει με θολό αντίγραφό της (όπως Apple News).
struct WholeImage: View {
    let url: String
    var w: Int = 800
    @StateObject private var l = ImageLoader()
    var body: some View {
        GeometryReader { g in
            if let i = l.image, i.size.height > 0, g.size.height > 0 {
                let ri = i.size.width / i.size.height, rb = g.size.width / g.size.height
                if abs(log(ri / rb)) < 0.18 {
                    Image(uiImage: i).resizable().scaledToFill().frame(width: g.size.width, height: g.size.height).clipped()
                } else {
                    ZStack {
                        Image(uiImage: i).resizable().scaledToFill().frame(width: g.size.width, height: g.size.height)
                            .blur(radius: 22, opaque: true).overlay(Color.black.opacity(0.28)).clipped()
                        Image(uiImage: i).resizable().scaledToFit().frame(width: g.size.width, height: g.size.height)
                    }
                }
            } else {
                Rectangle().fill(C.panel2)
            }
        }
        .onAppear { l.load(Img.url(url, w: w)) }
        .onChange(of: url) { _ in l.load(Img.url(url, w: w)) }
    }
}

/// Εικόνα σε κουτί σταθερού ύψους, χωρίς ποτέ να το μεγαλώνει (αλλιώς το scaledToFill «φαρδαίνει» την οθόνη).
/// Η φωτογραφία φαίνεται ολόκληρη (WholeImage).
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
        .onAppear { l.load(Img.url(url, w: w)) }
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
        .onAppear { l.load(Img.url(url, w: 160)) }
        .onChange(of: url) { _ in l.load(Img.url(url, w: 160)) }
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
