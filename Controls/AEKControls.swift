import WidgetKit
import SwiftUI
import AppIntents

/// 🎛 Control Center / οθόνη κλειδώματος / κουμπί Ενέργειας (iOS 18+): «Αγώνας ΑΕΚ» — σκορ live ή ο επόμενος αγώνας·
/// με πάτημα ανοίγουν οι αγώνες. Ξεχωριστό extension (iOS 18) γιατί το WidgetBundle των widgets δεν δέχεται `if #available`.
@main
struct AEKControls: WidgetBundle {
    var body: some Widget { MatchControl() }
}

struct MatchControl: ControlWidget {
    static let kind = "gr.aekhub.control.match"
    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: Self.kind, provider: Provider()) { text in
            ControlWidgetButton(action: OpenURLIntent(URL(string: "aekhub://matches")!)) {
                Label(text, systemImage: "soccerball")
            }
        }
        .displayName("Αγώνας ΑΕΚ")
        .description("Το σκορ της ΑΕΚ ή ο επόμενος αγώνας· με πάτημα ανοίγουν οι αγώνες.")
    }

    struct Provider: ControlValueProvider {
        var previewValue: String { "Κυρ 20:00 · Ολυμπιακός" }
        func currentValue() async throws -> String { AEKNow.short(await AEKNow.match()) }
    }
}
