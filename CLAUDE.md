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

## 0.7.0 — προετοιμασία App Store
- **AdMob πραγματικό**: `ADMOB_APP_ID` = `ca-app-pub-7943059111940021~6196572715` (ad units iOS στο wp-admin → 🍏).
- **Δήλωση απορρήτου** `Resources/Privacy/PrivacyInfo.xcprivacy` (tracking με ATT, device ID/advertising data/αλληλεπίδραση/σχόλια/όνομα/crash· UserDefaults CA92.1 + 1C8F.1, file timestamp C617.1).
- **Σχόλια (Apple 1.2)**: όροι πριν το 1ο σχόλιο (`c_terms`, link `/oroi-xrisis/`, μηδενική ανοχή) · μενού ⋯ ανά σχόλιο: Αναφορά + **Απόκρυψη χρήστη** (`c_blocked`, ανά όνομα, όχι στα AEK HUB)· αναίρεση από Εγώ → «Κρυμμένοι χρήστες σχολίων».
- **Push όπως Android**: φίλτρο κατηγοριών = topics `ios_news_<slug>` αντί για `news_breaking` (server aekhub-app 1.5.2)· **Notification Service Extension** `AEKHubNotify` (`Notify/`, App Group `group.gr.aekhub.app`, ρυθμίσεις από `Push.share()`): ήσυχες ώρες → αθόρυβη (`.passive`, χωρίς ήχο· εξαίρεση γκολ ΑΕΚ αν `quietAek`), χωρίς spoilers → σβήνει το σκορ από τίτλο/κείμενο.
- **Screenshots App Store**: `ci/appstore.sh` (iPhone 17 Pro Max 6,9″, iPad Pro 13″, ρολόι· `-noads YES`, ώρα 9:41) → artifact `appstore`, με «[appstore]» στο commit ή χειροκίνητο run.
- **Κείμενα σελίδας**: `appstore/listing.md` (όνομα «AEK Hub – ΑΕΚ Νέα & Live Σκορ», κατηγορία Αθλητικά, contact@aekhub.gr). Ο χρήστης **ΔΕΝ θέλει «ανεπίσημη»** πουθενά (news site).
- ⚠ 7/11/2026: τα jobs του GitHub Actions δεν ξεκίνησαν («recent account payments have failed or your spending limit needs to be increased») → θέλει διόρθωση χρέωσης στο GitHub ή δημόσιο repo. Από εδώ και πέρα το job `screens` τρέχει ΜΟΝΟ με «[screens]»/«[appstore]» στο commit ή χειροκίνητα (εξοικονόμηση λεπτών macOS).

## 0.6.0 — Apple Developer (Team `H3BX78S223`, ενεργό ως 7/11/2027)
- **TestFlight αυτόματα**: job `testflight` στο `build.yml` → archive με αυτόματη υπογραφή (`-allowProvisioningUpdates` + κλειδί App Store Connect API από τα secrets `ASC_ISSUER_ID`/`ASC_KEY_ID`/`ASC_KEY_P8`, ρόλος Admin) → `-exportArchive` με `ci/ExportOptions.plist` (`app-store-connect`, `destination: upload`). Το archive ξαναδοκιμάζεται έως 3 φορές (την 1η το Xcode «δεν βρίσκει» τα προφίλ που μόλις κατέβασε). Build number = αριθμός run. Η εφαρμογή στο App Store Connect: «AEK Hub», bundle `gr.aekhub.app`. Πρώτο ανέβασμα: build 26 (6/11/2026).
- **Push** (`iOS/Push.swift`, Firebase Messaging 11.x μέσω SPM, `Resources/Firebase/GoogleService-Info.plist`, entitlement `aps-environment`): ίδια topics με το Android (`m_<άθλημα>_<είδος>`, `match_<id>`, `news_breaking`), sync μόνο της διαφοράς (`push_topics`). Ο server (aekhub-app 1.5.1) βάζει κομμάτι `apns` με alert σε κάθε μήνυμα. Μόλις έρθει token (`push_on`) σταματούν οι τοπικές ειδοποιήσεις/υπενθυμίσεις του `Notifier` (όχι διπλές)· στα sideload χωρίς push συνεχίζει το τοπικό. ⚠ Κατηγορίες ειδήσεων / ήσυχες ώρες / spoilers δεν φιλτράρονται στο iPhone με push (ο server στέλνει σε όλο το topic).
- Το κλειδί APNs (Key ID DG5W2ULMZA) στάλθηκε κατά λάθος στη συνομιλία → προτάθηκε στον χρήστη να το ανακαλέσει και να βάλει νέο στο Firebase.

## 0.5.0 (ζήτησε ο χρήστης)
- **Μπάρα καρτελών**: μόνο οι 4 καρτέλες, στο κέντρο, μεγαλύτερη (η αναζήτηση είναι πάνω στην αρχική).
- **Άρθρο** (`iOS/ArticleView.swift`): πίσω/Aa/🔖/κοινοποίηση στη **μπάρα του συστήματος** (`.toolbar`) — τα δικά μας κουμπιά πάνω από το WKWebView δεν πατιόντουσαν. Επικεφαλίδα native (φωτογραφία ολόκληρη, τίτλος, περίληψη, **φωτογραφία συντάκτη** `authorAvatar`), κείμενο σε WKWebView που παίρνει το ύψος του (ResizeObserver → `h`), κομμένο μετά την 3η/8η παράγραφο για διαφήμιση. **Video post** → εικόνα με ▶ → **pop up** (`VideoPopup`, iframe με βάση aekhub.gr ή AVPlayer για mp4). «Διάβασε επίσης» (στο iPad δεξιά). Ιστορικό ανάγνωσης (`Prefs.history`).
- **Φωτογραφίες**: ~~ολόκληρες με θολό φόντο~~ → **0.7.0 (ζήτησε ο χρήστης: «full στα πλαίσια, να μην κόβει κεφάλια»)**: `WholeImage` ΓΕΜΙΖΕΙ πάντα το κουτί και κόβει γύρω από το «σημαντικό σημείο» (`Focus.point`: πρόσωπα με Vision → αλλιώς saliency → αλλιώς 0.5/0.35), cache `ImageLoader.focals`· `NaturalImage` = φυσικό σχήμα (άρθρο). Δικός μας `ImageLoader` (NSCache) αντί για AsyncImage. Κύριο θέμα: εικόνα 16:9 και ο τίτλος ΚΑΤΩ (όχι πάνω στη φωτογραφία).
- **iPad από την αρχή**: πλαϊνή στήλη τύπου Apple News (καρτέλες, αναζήτηση, αποθηκευμένα, κατηγορίες, LIVE)· σε κάθετο iPad στενή με εικονίδια. Αρχική = περιοδικό (μεγάλο κύριο θέμα + πλακίδια `PostTile`, ενότητες σε πλέγμα) + δεξιά στήλη «ΣΗΜΕΡΑ ΣΤΗΝ ΑΕΚ» (αντίστροφη μέτρηση, πρόγραμμα, μίνι βαθμολογία). Αγώνες: λίστα αριστερά, αγώνας δεξιά (`MatchView(embedded:)`, `matchPick`). Βαθμολογίες: διοργανώσεις αριστερά, πίνακας δεξιά με «ΓΚΟΛ».
- **Εγώ**: πλακίδια (Ειδοποιήσεις/Αποθηκευμένα/Ιστορικό/Ημερολόγιο), «Συνέχισε να διαβάζεις», rewarded «Χ ώρες χωρίς διαφημίσεις», εξοικονόμηση δεδομένων (`data_saver` → μικρότερες εικόνες στο `Img.url`), καθάρισμα μνήμης, ρυθμίσεις απορρήτου (UMP), «Πες το σε έναν φίλο».
- **Διαφημίσεις** (`iOS/Ads.swift`, Google Mobile Ads 11.x + UMP μέσω SPM στο `project.yml`): ίδιες θέσεις/κανόνες με το Android — banner αρχικής (μετά τα «Τελευταία», μετά από ενότητες εναλλάξ με κάρτα χορηγού/native), ροή κάθε `everyN`, άρθρο (μετά την 3η/8η παράγραφο + τέλος, 300×250), λίστα αγώνων, βαθμολογίες, fullscreen όταν κλείνει άρθρο (κάθε Ν, κενό λεπτών, ποτέ όσο παίζει η ΑΕΚ), splash χορηγού (1/4 ώρες), «Παρουσιάζεται από». Ad units iOS από το wp-admin (`ads.ios`, aekhub-app 1.5.0)· κενό = δοκιμαστικά Google. **App ID** στο `project.yml` → `ADMOB_APP_ID` (τώρα το δοκιμαστικό της Google). Σειρά στο άνοιγμα: ειδοποιήσεις → συγκατάθεση GDPR (UMP) → ATT → AdMob. Στο `-shots` χωρίς παράθυρα.

## 0.4.0 — ΠΙΣΤΗ ΑΝΤΙΓΡΑΦΗ ΤΟΥ ANDROID (ζήτησε ο χρήστης: «δες πώς είναι ακριβώς στο android, έτσι το θέλω»)
- Κάθε οθόνη αντιγράφει το αντίστοιχο αρχείο του `aekhub-android` (`ui/screens/*.kt`, `ui/components/*.kt`): ίδια σειρά, μεγέθη, γωνίες, κείμενα. Κείμενο **Manrope**, τίτλοι Sofia (όπως Android). Το γυαλί μένει μόνο στη μπάρα καρτελών και στα στρογγυλά κουμπιά.
- **Αρχική**: αντίστροφη μέτρηση · έκτακτο · «Ακολούθησέ μας» · πλακίδια κατηγοριών (εικονίδια `nav_*`) · LiveBar · κύριο θέμα 300 · Τελευταία νέα · Επόμενοι αγώνες (+ ποδόσφαιρο από τη λίστα αγώνων) · ενότητες (μεσαία κάρτα + 3) · social. iPad: κύριο θέμα δίπλα στα νέα, ενότητες σε στήλες.
- **Αγώνες**: λωρίδα ημερών που ΚΥΛΑΕΙ (45 πίσω – 90 μπροστά), σύρσιμο για αλλαγή μέρας, «Επιστροφή στο σήμερα», κάρτες MatchCardView.
- **Αγώνας**: ΧΩΡΙΣ «Σύνοψη» (ο χρήστης: «μαλακία» — το κείμενο ειδοποίησης ήταν από το σχέδιο, όχι για το app)· καρτέλες Πορεία/Στατιστικά/Συνθέσεις/Παίκτες όπως Android (πορεία με κεντρική γραμμή, σκορ σε κουτιά). iPad: Πορεία αριστερά.
- **Βαθμολογίες**: σειρές όπως Android (ζώνη μόνο αριστερά — παλιό λάθος: overlay σε GridRow έβαζε γραμμή σε κάθε στήλη).
- **Εγώ** → ξεχωριστή οθόνη **Ειδοποιήσεις** (ζήτησε ο χρήστης): κάρτα ανά άθλημα που ανοίγει/κλείνει με διακόπτη ανά είδος, ήσυχες ώρες με «σίγαση για λίγο».
- **Splash** όπως Android (`IntroSplash`: τα κομμάτια a/e/hub/k «χτίζουν» το λογότυπο).
- ⚠ Εικόνες με `scaledToFill` ΠΑΝΤΑ μέσα σε `FillImage`/`Color.clear.overlay(...)`: αλλιώς «φαρδαίνουν» την οθόνη (λάθος 0.3.0: κομμένα λογότυπα/τίτλοι).
- **📸 CI screenshots** (job `screens`, `ci/screens.sh`): χτίζει για προσομοιωτή iPhone 17 Pro + iPad Pro 13 και βγάζει εικόνες κάθε οθόνης (παράμετροι εκκίνησης `-shots YES -open match/ID -mtab Συνθέσεις -scroll 1`) → artifact `screens`. Κατέβασμα: `actions_get download_workflow_run_artifact` → curl. ΚΟΙΤΑ ΤΙΣ πριν πεις στον χρήστη ότι κάτι είναι έτοιμο.
- **⌚ Ρολόι — ειδήσεις** (ζήτησε ο χρήστης): στην αρχική ενότητα «Νέα» (8 τελευταία) + «Ροή ειδήσεων» (σελίδες, «Περισσότερα») + «Κατηγορίες» → ροή κατηγορίας· άρθρο με όλο το κείμενο (χωρίς βίντεο/embeds). Complication «Τελευταίο νέο» (rectangular/inline/circular) → ανοίγει το άρθρο (`aekhub://post/ID`, `onOpenURL` στο `WatchRoot`).
- Apple Watch με sideload: Sideloadly 0.71 υπογράφει εφαρμογές ρολογιού μόνο για πληρωμένο λογαριασμό («free coming next version»)· με δωρεάν μόνο Xcode.

## Εμφάνιση (0.3.0) — ΣΧΕΔΙΟ ΤΟΥ ΧΡΗΣΤΗ «iOS 26 · Liquid Glass» (αντικαταστάθηκε από την 0.4.0 όπου διαφέρει)
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
