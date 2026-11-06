import SwiftUI

/// Τα χρώματα του aekhub.gr (ίδια με το Android)
enum C {
    static let ink = Color(hex: 0x0B0B0A)
    static let ink2 = Color(hex: 0x10100E)
    static let panel = Color(hex: 0x151513)
    static let panel2 = Color(hex: 0x1C1B18)
    static let panel3 = Color(hex: 0x242320)
    static let line = Color(hex: 0x2A2924)
    static let line2 = Color(hex: 0x37352F)
    static let text = Color(hex: 0xF3F1E9)
    static let text2 = Color(hex: 0xCFCBBE)
    static let muted = Color(hex: 0x8E8A7C)
    static let gold = Color(hex: 0xF9CF1C)
    static let live = Color(hex: 0xFF4B3E)
    static let win = Color(hex: 0x1A9B54)
    static let loss = Color(hex: 0xD63638)
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

/// Γραμματοσειρές: Manrope (κείμενο) και Sofia Sans Extra Condensed (τίτλοι/σκορ), όπως στο site/Android.
/// Στο ρολόι: του συστήματος (πιο ευανάγνωστες στη μικρή οθόνη).
enum F {
    enum W { case medium, bold, extra }
    static func body(_ size: CGFloat, _ w: W = .medium) -> Font {
        #if os(watchOS)
        return .system(size: size, weight: w == .medium ? .medium : (w == .bold ? .semibold : .bold))
        #else
        let n: String
        switch w { case .medium: n = "ManropeExtraLight-Medium"; case .bold: n = "ManropeExtraLight-Bold"; case .extra: n = "ManropeExtraLight-ExtraBold" }
        return .custom(n, size: size, relativeTo: .body)
        #endif
    }
    static func disp(_ size: CGFloat, black: Bool = false) -> Font {
        #if os(watchOS)
        return .system(size: size, weight: .heavy).width(.condensed)
        #else
        return .custom(black ? "SofiaSansExtraCondensed-Black" : "SofiaSansExtraCondensed-ExtraBold", fixedSize: size)
        #endif
    }
}

/// Εικόνα από το δίκτυο με γκρι φόντο μέχρι να φορτώσει.
struct NetImage: View {
    let url: String
    var w: Int = 800
    var mode: ContentMode = .fill
    var body: some View {
        AsyncImage(url: Img.url(url, w: w), transaction: Transaction(animation: .easeOut(duration: 0.2))) { ph in
            switch ph {
            case .success(let img): img.resizable().aspectRatio(contentMode: mode)
            default: Rectangle().fill(C.panel2)
            }
        }
    }
}

/// Λογότυπο ομάδας (μικρό, μέσω CDN)
struct TeamLogo: View {
    let url: String
    var size: CGFloat = 28
    var body: some View {
        AsyncImage(url: Img.url(url, w: 160)) { ph in
            if case .success(let img) = ph { img.resizable().scaledToFit() }
            else { Circle().fill(C.panel3) }
        }
        .frame(width: size, height: size)
    }
}

/// Κόκκινη τελεία που «αναπνέει» (live)
struct LiveDot: View {
    var size: CGFloat = 8
    @State private var on = false
    var body: some View {
        Circle().fill(C.live).frame(width: size, height: size)
            .opacity(on ? 0.35 : 1)
            .onAppear { withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) { on = true } }
    }
}
