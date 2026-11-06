# AEK Hub iOS — οδηγίες για τον Claude

Εφαρμογή **iPhone + iPad + Apple Watch** (SwiftUI) του aekhub.gr — αντίστοιχη του Android (`vagnt/aekhub-android`, Kotlin/Compose).
Μιλάμε **ελληνικά** με τον χρήστη (Βαγγέλης, όχι προγραμματιστής): απλά, βήμα-βήμα.

- **Ίδιο API με το Android** (`/wp-json/aekhub/v1/app/*`, κώδικας στο `vagnt/aekhub-site` → `plugins/aekhub-app/inc/api.php`). Μην αλλάζεις το API για χάρη του iOS χωρίς να ελέγξεις ότι δεν σπάει το Android.
- **Δεν υπάρχει Mac**: το build γίνεται ΜΟΝΟ στο GitHub Actions (`.github/workflows/build.yml`, `macos-15`, XcodeGen → `xcodebuild` χωρίς υπογραφή → `.ipa` στα Releases). Μετά από κάθε push έλεγξε το run· τα σφάλματα μεταγλώττισης εμφανίζονται ως `::error::`.
- Το `.xcodeproj` **δεν** μπαίνει στο repo — αλλαγές στόχων/ρυθμίσεων στο `project.yml`.
- Deployment: iOS 16, watchOS 9 → μην χρησιμοποιείς API iOS 17+ (π.χ. `.topBarTrailing`, `onChange` με 2 παραμέτρους) χωρίς `if #available`.
- Ανεκτικό JSON (`Shared/Models.swift`, τύπος `J`): ένα απρόσμενο πεδίο δεν πρέπει ποτέ να χαλάει οθόνη.
- Εικόνες aekhub.gr πάντα μέσω `Img.url(_, w:)` (CDN i0.wp.com) — κάποια πρωτότυπα είναι 4000px.
- Κανόνας τόνων (του χρήστη): ό,τι γράφεται με **κεφαλαία** → χωρίς τόνους (`.upperGr`)· πεζά μένουν με τόνους.
- **Sideload** (δωρεάν Apple ID): λήξη 7 ημερών, **χωρίς push**. Push/App Store όταν ο χρήστης γίνει Apple Developer (τότε: APNs/FCM, υπογραφή, `DEVELOPMENT_TEAM`).
- Κάθε έκδοση: `MARKETING_VERSION` στο `project.yml` (το build number = αριθμός run).

## Τι υπάρχει (0.1.0)
- iPhone/iPad: καρτέλες Ειδήσεις (αρχική: live/αντίστροφη μέτρηση, κύριο θέμα, τελευταία νέα, αγώνες, ενότητες) · Αγώνες (ανά μέρα, φίλτρο αθλήματος, παλαιότεροι) · Βαθμολογίες · Εγώ.
  Άρθρο σε WKWebView (βάση `https://aekhub.gr/` για embeds YouTube· γραμματοσειρές base64· links σε Safari μέσα στο app, μέγεθος γραμμάτων).
  Αγώνας: πίνακας σκορ, σκορ ανά περίοδο, χορηγός (μετρητής `view`), στιγμιότυπα, Πορεία (και ανά περίοδο/σετ), Στατιστικά, Συνθέσεις + γηπεδάκι, Παίκτες (βαθμοί / box score). Live ανανέωση 10″.
  Live γεγονός (Live Ticker). iPad: πλέγμα πολλών στηλών.
- Apple Watch: live/επόμενος αγώνας (σκορ ή αντίστροφη μέτρηση), live/επόμενοι/αποτελέσματα, νέα (κείμενο άρθρου), σελίδα αγώνα με γεγονότα.
- Δεν έγιναν ακόμα: ειδοποιήσεις, widgets/complications, σχόλια, αποθηκευμένα, ημερολόγιο, διαφημίσεις, analytics (το `aekhub-analytics` αναγνωρίζει το UA `AEKHubApp` ως «Εφαρμογή Android» — να προστεθεί iOS πριν στείλει hits).
