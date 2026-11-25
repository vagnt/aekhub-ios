# AEK Hub iOS — οδηγίες για τον Claude

Εφαρμογή **iPhone + iPad + Apple Watch** (SwiftUI) του aekhub.gr, **στο App Store** (Team `H3BX78S223`, bundle `gr.aekhub.app`) — αντίστοιχη του Android (`vagnt/aekhub-android`, Kotlin/Compose).
Μιλάμε **ελληνικά** με τον χρήστη (Βαγγέλης, όχι προγραμματιστής): απλά, βήμα-βήμα.

## 📚 Λεπτομέρειες
Το αρχείο αυτό μένει **μικρό** (φορτώνεται σε κάθε μήνυμα = κόστος). Όλο το ιστορικό (εκδόσεις, Live Activities, push, διαφημίσεις, splash, ρολόι, iPad, App Store, διανομή) είναι στο **`docs/claude/history.md`** — **διάβασε την ενότητα που αφορά τη δουλειά** πριν αλλάξεις κάτι εκεί (π.χ. `grep -n` για «Live Activity», «Splash», «Ρολόι»).
Νέα λειτουργία/κανόνας του χρήστη → γράψ' τα στο `docs/claude/history.md` (στο ίδιο commit). Εδώ μόνο ό,τι ισχύει **παντού**.

## Build & έκδοση
- **Δεν υπάρχει Mac**: build ΜΟΝΟ στο GitHub Actions (`.github/workflows/build.yml`, XcodeGen → `xcodebuild`). Μετά από κάθε push έλεγξε το run (σφάλματα = `::error::`). Job `testflight` ανεβάζει αυτόματα στο TestFlight.
- Το `.xcodeproj` **δεν** μπαίνει στο repo — στόχοι/ρυθμίσεις στο `project.yml`. Κάθε έκδοση: `MARKETING_VERSION` στο `project.yml` (build number = αριθμός run).
- ⛔ **ΟΧΙ screenshots/«[screens]»/«[appstore]» χωρίς να το ζητήσει ο χρήστης** (κρατούν τους runners macOS 20–30′).
- Νέα capabilities (App Groups κ.λπ.): πρώτα χειροκίνητα από τον χρήστη στο developer.apple.com — η αυτόματη υπογραφή δεν τα φτιάχνει.

## Κανόνες κώδικα
- **Ίδιο API με το Android** (`/wp-json/aekhub/v1/app/*`, `vagnt/aekhub-site` → `plugins/aekhub-app`). Μην αλλάζεις το API χωρίς να ελέγξεις ότι δεν σπάει το Android.
- Deployment iOS 16 / watchOS 9 → API iOS 17+ μόνο με `if #available` (⚠ το `WidgetBundle` ΔΕΝ το δέχεται).
- Ανεκτικό JSON (`Shared/Models.swift`, τύπος `J`): απρόσμενο πεδίο ποτέ δεν χαλάει οθόνη.
- **Live Activity**: τα κλειδιά του `ContentState` (`Shared/LiveMatch.swift`) = ίδια με τον server (`aekhub-app/inc/live-activity.php`)· νέα πεδία ΜΟΝΟ optional.
- Εικόνες aekhub.gr πάντα μέσω `Img.url(_, w:)` (CDN i0.wp.com).
- **Κανόνας τόνων**: **κεφαλαία** → χωρίς τόνους (`.upperGr`)· πεζά με τόνους.
- **Μαθήματα από crash — ποτέ ξανά**:
  - `@EnvironmentObject` για `AppState`/`Prefs` → πάντα `@ObservedObject var x = AppState.shared / Prefs.shared`.
  - `Int(...)` για χρόνους σε ms/μεγάλους αριθμούς στο Shared (ρολόι 32-bit) → `Int64`.
  - `async let` → ανεξάρτητα `Task { }` + `await .value`.
  - Ειδοποιήσεις: εκδοχές με `withCompletionHandler` + `DispatchQueue.main` (όχι async).
  - Vision/ανάλυση εικόνας ΠΟΤΕ στο cooperative pool → `Focus.queue`.
