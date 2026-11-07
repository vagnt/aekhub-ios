#if os(iOS)
import UIKit

/// Λογότυπα ομάδων για τα Live Activities (κλειδωμένη οθόνη, Dynamic Island, Apple Watch, CarPlay).
/// Τα Live Activities δεν κατεβάζουν εικόνες από το internet → το app τα κατεβάζει μικρά (72px PNG)
/// στον κοινό φάκελο (App Group) και το widget τα διαβάζει από εκεί. Χωρίς App Group / χωρίς αρχείο → αρχικά γράμματα.
enum LiveLogos {
    static let group = "group.gr.aekhub.app"
    static var dir: URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: group)?.appendingPathComponent("logos", isDirectory: true)
    }
    static func key(_ name: String) -> String {
        var h: UInt64 = 5381
        for b in name.lowercased().trimmingCharacters(in: .whitespaces).utf8 { h = (h &* 33) &+ UInt64(b) }
        return String(h, radix: 16)
    }
    static func file(_ name: String) -> URL? { dir?.appendingPathComponent(key(name) + ".png") }

    static func image(_ name: String) -> UIImage? {
        guard !name.isEmpty, let u = file(name) else { return nil }
        return UIImage(contentsOfFile: u.path)
    }

    /// Σβήνει λογότυπα που δεν χρειάστηκαν 45 μέρες (ώστε ο φάκελος να μένει λίγα KB)
    static func trim() {
        guard let d = dir, let fs = try? FileManager.default.contentsOfDirectory(at: d, includingPropertiesForKeys: [.contentModificationDateKey]) else { return }
        let old = Date().addingTimeInterval(-45 * 86400)
        for f in fs where ((try? f.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate ?? .distantPast) < old {
            try? FileManager.default.removeItem(at: f)
        }
    }

    /// Κατεβάζει (μία φορά την εβδομάδα) το λογότυπο μιας ομάδας
    static func cache(_ name: String, _ logo: String) async {
        guard !name.isEmpty, !logo.isEmpty, let d = dir, let f = file(name) else { return }
        if let a = try? FileManager.default.attributesOfItem(atPath: f.path), let t = a[.modificationDate] as? Date, t > Date().addingTimeInterval(-7 * 86400) { return }
        guard let u = Img.url(logo, w: 160), let (data, _) = try? await URLSession.shared.data(from: u), let img = UIImage(data: data) else { return }
        let side: CGFloat = 72
        let fmt = UIGraphicsImageRendererFormat(); fmt.scale = 1
        let png = UIGraphicsImageRenderer(size: CGSize(width: side, height: side), format: fmt).pngData { _ in
            let s = min(side / img.size.width, side / img.size.height)
            let w = img.size.width * s, h = img.size.height * s
            img.draw(in: CGRect(x: (side - w) / 2, y: (side - h) / 2, width: w, height: h))
        }
        try? FileManager.default.createDirectory(at: d, withIntermediateDirectories: true)
        try? png.write(to: f, options: .atomic)
    }
}
#endif
