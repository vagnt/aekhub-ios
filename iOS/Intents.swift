import AppIntents

/// 🗣 Siri + Αναζήτηση iPhone (Spotlight) + εφαρμογή Συντομεύσεις: «Πότε παίζει η ΑΕΚ;», «Σκορ ΑΕΚ».
/// Η Siri δεν μιλά ελληνικά → φράσεις και στα αγγλικά· στην Αναζήτηση φαίνονται ως κουμπιά.
struct NextMatchIntent: AppIntent {
    static var title: LocalizedStringResource = "Πότε παίζει η ΑΕΚ"
    static var description = IntentDescription("Ο επόμενος ή ο τωρινός αγώνας της ΑΕΚ.")
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let s = AEKNow.sentence(await AEKNow.match())
        return .result(dialog: IntentDialog(stringLiteral: s))
    }
}

struct ScoreIntent: AppIntent {
    static var title: LocalizedStringResource = "Σκορ ΑΕΚ"
    static var description = IntentDescription("Το σκορ της ΑΕΚ τώρα (ή πότε παίζει).")
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let s = AEKNow.sentence(await AEKNow.match(), scoreOnly: true)
        return .result(dialog: IntentDialog(stringLiteral: s))
    }
}

struct OpenMatchesIntent: AppIntent {
    static var title: LocalizedStringResource = "Αγώνες ΑΕΚ"
    static var description = IntentDescription("Ανοίγει τους αγώνες στο AEK Hub.")
    static var openAppWhenRun: Bool = true
    @MainActor func perform() async throws -> some IntentResult {
        AppState.shared.shortcut("matches")
        return .result()
    }
}

struct AEKShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(intent: NextMatchIntent(), phrases: [
            "Πότε παίζει η ΑΕΚ στο \(.applicationName)",
            "Επόμενος αγώνας \(.applicationName)",
            "When does AEK play in \(.applicationName)",
            "\(.applicationName) next match",
        ])
        AppShortcut(intent: ScoreIntent(), phrases: [
            "Σκορ ΑΕΚ στο \(.applicationName)",
            "Τι κάνει η ΑΕΚ στο \(.applicationName)",
            "AEK score in \(.applicationName)",
            "\(.applicationName) score",
        ])
        AppShortcut(intent: OpenMatchesIntent(), phrases: [
            "Αγώνες στο \(.applicationName)",
            "Open matches in \(.applicationName)",
        ])
    }
}
