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

## Τι υπάρχει (0.2.0)
- iPhone/iPad: καρτέλες Ειδήσεις (αρχική: live/αντίστροφη μέτρηση, κύριο θέμα, τελευταία νέα, αγώνες, ενότητες) · Αγώνες (ανά μέρα, φίλτρο αθλήματος, παλαιότεροι, 📅 ημερολόγιο) · Βαθμολογίες · Εγώ.
  Άρθρο σε WKWebView (βάση `https://aekhub.gr/` για embeds YouTube· γραμματοσειρές base64· links σε Safari μέσα στο app, μέγεθος γραμμάτων, 🔖 αποθήκευση, 💬 σχόλια).
  Αγώνας: πίνακας σκορ, σκορ ανά περίοδο, χορηγός (μετρητής `view`), στιγμιότυπα, Πορεία (και ανά περίοδο/σετ), Στατιστικά, Συνθέσεις + γηπεδάκι, Παίκτες (βαθμοί / box score), 🔔 ειδοποιήσεις για τον αγώνα. Live ανανέωση 10″.
  Live γεγονός (Live Ticker). iPad: πλέγμα πολλών στηλών. Οθόνη υποδοχής (πρώτο άνοιγμα, ζητά άδεια ειδοποιήσεων).
- **🔔 Ειδοποιήσεις ΧΩΡΙΣ push** (`iOS/Notifier.swift`, ρυθμίσεις ίδιες με το Android: ανά άθλημα + είδη goals/startend/reminder, νέα άρθρα με κατηγορίες, χωρίς spoilers, ήσυχες ώρες):
  υπενθύμιση 30′ = τοπικά προγραμματισμένη (έρχεται πάντα)· σέντρα/γκολ/σετ/ημίχρονο/τελικό/νέο άρθρο = σύγκριση με την προηγούμενη κατάσταση (`n_state`) όταν το app είναι ανοιχτό (live 10–15″) ή στο παρασκήνιο με `BGAppRefreshTask` (`gr.aekhub.app.refresh`, το iOS αποφασίζει πότε → μπορεί να αργήσουν). Μορφή όπως ο server: «Γκολ · ΑΕΚ [1]–0 Χ».
  Όταν γίνει Apple Developer: κανονικό push (FCM/APNs) από το `aekhub-push` και το τοπικό σύστημα μένει μόνο για υπενθυμίσεις.
- **Widgets** (`Widgets/`, extension `gr.aekhub.app.widgets`): ⚽ Αγώνας (small/medium + οθόνη κλειδώματος circular/rectangular/inline) · 📅 Πρόγραμμα · 📰 Νέα · 🏆 Βαθμολογία (πρωτάθλημα με την ΑΕΚ). Φέρνουν μόνα τους δεδομένα (χωρίς App Group)· links `aekhub://match/ID`, `post/ID`, `matches`, `standings`, `news`.
- **Apple Watch**: live/επόμενος αγώνας (σκορ ή αντίστροφη μέτρηση), live/επόμενοι/αποτελέσματα, νέα (κείμενο άρθρου), σελίδα αγώνα με γεγονότα· **complications** (`WatchWidgets/`: circular/rectangular/inline/corner).
- 💬 Σχόλια (`/app/comments/{id}`, header `X-Aek-Device`), 🔖 αποθηκευμένα (τοπικά, `saved.json`), 📅 ημερολόγιο (ICS `amc_ics` → webcal/Google/Outlook), συντομεύσεις εικονιδίου (Αγώνες/Βαθμολογίες/Αναζήτηση).
- 📊 Στατιστικά: `/aekhub/v1/hit` με `s:15` (= «Εφαρμογή iOS», θέμα 2.10.5) + παλμός `/aekhub-an/v1/ping`· UA `AEKHubApp/x (iOS)` → os 10 «Εφαρμογή iOS» στο `aekhub-analytics` 1.4.0. Διακόπτης στο «Εγώ».
- Δεν έγιναν: διαφημίσεις (ζήτησε ο χρήστης να μη γίνουν), Live Activities/Dynamic Island (θέλουν push για να ενημερώνονται με κλειστό app).
