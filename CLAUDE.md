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

## Εμφάνιση (0.3.0) — ΣΧΕΔΙΟ ΤΟΥ ΧΡΗΣΤΗ «iOS 26 · Liquid Glass»
Ο χρήστης έδωσε σχέδιο (HTML «AEK Hub · iOS 26 · Live Activities») και ζήτησε **πιστή αντιγραφή του Android app** με αυτό το στυλ («είναι χάλια, δεν φαίνονται ωραία»). Κανόνες:
- Χρώματα: μαύρο #0B0B0A · επιφάνεια #151514 / #1E1E1C · κίτρινο #F9CF1C · κείμενο #F3F1E9 · σιγαστό #9A968A · live #FF453A · θετικό #34C759 · γραμμή #2C2C29 (`Shared/Theme.swift`).
- Τίτλοι/σκορ/ώρες: **Sofia Sans Extra Condensed** (`F.disp`), κεφαλαία χωρίς τόνους· όλα τα άλλα **SF Pro** (`F.body`).
- **Γυαλί** (`.glass(...)`: iOS 26 `glassEffect` όταν χτίζεται με Xcode 26, αλλιώς material) ΜΟΝΟ σε πλοήγηση/κουμπιά πάνω από εικόνα/φύλλα — όχι σε κάρτες, λίστες, πίνακες (`.card(24)`).
- Κάψουλα καρτελών που αιωρείται (Ειδήσεις · Αγώνες · Βαθμ. · Εγώ) + ξεχωριστό γυάλινο κουμπί αναζήτησης· κρύβεται σε εσωτερικές οθόνες. iPad: πλαϊνή στήλη με «LIVE ΤΩΡΑ».
- Ειδήσεις: λογότυπο + κάψουλα (ροή, αναζήτηση, 🔔) · τσιπάκια κατηγοριών · hero 28 · «ΤΕΛΕΥΤΑΙΑ ΝΕΑ» κεκλιμένη κίτρινη ετικέτα. Αγώνες: dropdown αθλήματος, εβδομάδα, μία μέρα τη φορά, μεγάλες κάρτες. Αγώνας: θολό φόντο, κίτρινο πανό διοργάνωσης, Σύνοψη/Σύνθεση/Στατιστικά/Πορεία(/Παίκτες). Βαθμολογίες: 2 dropdown. Άρθρο: φωτογραφία ως πάνω, κάτω «Σχόλια» + «Κοινοποίηση». Εγώ: ειδοποιήσεις + «Αγώνες που ακολουθώ» με τσιπάκια ειδών.
- **Live Activities** (`Shared/LiveMatch.swift`, `iOS/LiveActivities.swift`, `Widgets/LiveActivityWidget.swift`): ξεκινά όταν ένας ακολουθούμενος αγώνας είναι live και το app ανοιχτό· ενημερώνεται από το app (ανοιχτό + έλεγχοι παρασκηνίου) — χωρίς push δεν ενημερώνεται με κλειστό app για πολύ. Χωρίς λογότυπα (όριο 4KB).
- **Mac / Apple Watch**: με δωρεάν λογαριασμό το Sideloadly/AltStore ΔΕΝ περνάει την εφαρμογή ρολογιού (δηλώνει μόνο το iPhone)· λύση: Xcode στο Mac (`mac.sh` → XcodeGen → Signing: Personal Team σε 4 στόχους → Run AEKHub στο iPhone, μετά AEKHubWatch στο ρολόι).

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

## 📦 Διανομή σε φίλους (δωρεάν)
- Δημόσιο repo **`vagnt/aekhub-ios-dist`** (μόνο αρχεία, όχι κώδικας): σε κάθε build του κύριου branch το workflow ανεβάζει release με τα δύο .ipa και ενημερώνει το **`source.json`** (μορφή AltStore/SideStore, `dist/make_source.py`, κρατά τις 10 τελευταίες εκδόσεις· η πηγή δείχνει το .ipa **χωρίς ρολόι** για να χωράει στα όρια App IDs του δωρεάν λογαριασμού).
- Θέλει το secret **`DIST_TOKEN`** στο `aekhub-ios` (fine-grained token, Contents: Read and write, μόνο στο `aekhub-ios-dist`). Χωρίς αυτό τα βήματα απλώς παραλείπονται.
- Link πηγής για τους φίλους: `https://raw.githubusercontent.com/vagnt/aekhub-ios-dist/main/source.json` (AltStore/SideStore → Sources → «+»).
