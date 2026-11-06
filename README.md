# AEK Hub — iPhone / iPad / Apple Watch

Native εφαρμογή (Swift + SwiftUI) για το aekhub.gr — η ίδια με το app Android (`vagnt/aekhub-android`).

- **Δεδομένα**: `https://aekhub.gr/wp-json/aekhub/v1/app/*` (plugin «AEK Hub App» στο `vagnt/aekhub-site`) — ίδιο API με το Android.
- **Build**: κάθε push φτιάχνει **ανυπόγραφο .ipa** (iPhone + iPad + Apple Watch μέσα) στα **Releases** (GitHub Actions, Mac της GitHub).
- **Εγκατάσταση (sideload)**: κατέβασε το `.ipa` από τα Releases → **Sideloadly** (ή AltStore) σε υπολογιστή → σύνδεσε το iPhone με καλώδιο → σύρε το .ipa → Apple ID → Start.
  Με δωρεάν Apple ID η εφαρμογή λήγει σε **7 μέρες** (ξαναπέρασμα· ο AltStore το κάνει μόνος του). Το ρολόι παίρνει την εφαρμογή από το iPhone (Watch app → «Διαθέσιμες εφαρμογές» → Εγκατάσταση).
- **Ειδοποιήσεις push**: μόνο με πληρωμένο λογαριασμό Apple Developer (θα προστεθούν τότε, μαζί με το App Store).

## Δομή
```
project.yml          XcodeGen (το .xcodeproj φτιάχνεται στο build — σε Mac: brew install xcodegen && xcodegen generate)
Shared/              Models (ανεκτικό JSON), Api, Theme, Util — κοινά για iPhone και ρολόι
iOS/                 Εφαρμογή iPhone/iPad (Ειδήσεις, Αγώνες, Βαθμολογίες, Εγώ, Άρθρο, Αγώνας live, Live γεγονός)
Watch/               Εφαρμογή Apple Watch (live/επόμενος αγώνας, αγώνες, νέα)
Resources/Fonts      Manrope & Sofia Sans Extra Condensed (OFL) — ίδιες με site/Android
```
