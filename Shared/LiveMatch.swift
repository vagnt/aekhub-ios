#if os(iOS)
import ActivityKit
import Foundation

/// Live Activity αγώνα (κλειδωμένη οθόνη + Dynamic Island + Apple Watch + CarPlay). Ενημερώνεται με push από τον server
/// (aekhub-app → inc/live-activity.php: ΙΔΙΑ ονόματα πεδίων) και από το app όσο είναι ανοιχτό. Λογότυπα δεν χωράνε (όριο 4KB) → ονόματα.
struct LiveMatchAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var sh: String
        var sa: String
        var status: String      // live / halftime / finished …
        var minute: String      // «67′», «Q3 · 05:12», «Σετ 3»
        var phase: String       // «Β′ ημίχρονο»
        var last: String        // «66′ Γκολ ΑΕΚ»
        var progress: Double    // 0…1 (ποδόσφαιρο: λεπτό/90)
        var periods: [String]   // «Q1 18–15» …
        var goal: Bool          // μόλις μπήκε γκολ της ΑΕΚ
        var clk: Double? = nil  // χρονική στιγμή (epoch, δευτ.) του 0′ → το λεπτό «τρέχει» μόνο του χωρίς push
        var ph: String? = nil   // 🏐 βόλεϊ live: πόντοι του τρέχοντος σετ (μεγάλα)· τότε sh/sa = σετ (μικρά)
        var pa: String? = nil
        var per: String? = nil  // «ΣΕΤ 2» / «TIE-BREAK»
    }
    var matchId: Int
    var home: String
    var away: String
    var aek: String          // home / away
    var sport: String
    var competition: String
    var venue: String
    var kickoff: Date?
    var hlogo: String? = nil   // links λογοτύπων (ο server τα στέλνει στην έναρξη με push → το app τα κατεβάζει στο παρασκήνιο)
    var alogo: String? = nil
}
#endif
