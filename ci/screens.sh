#!/bin/bash
# Screenshots από τον προσομοιωτή (iPhone + iPad) — για έλεγχο εμφάνισης χωρίς συσκευή
set -x
APP="$1"; OUT="$2"; mkdir -p "$OUT"
shoot() { # $1 = όνομα συσκευής, $2 = πρόθεμα
  UDID=$(xcrun simctl list devices available | grep -m1 "$1" | grep -oE '[0-9A-F-]{36}')
  [ -z "$UDID" ] && { echo "δεν βρέθηκε $1"; return; }
  xcrun simctl boot "$UDID" || true
  xcrun simctl bootstatus "$UDID" -b
  xcrun simctl status_bar "$UDID" override --time "20:29" --batteryLevel 100 --cellularBars 4 || true
  xcrun simctl install "$UDID" "$APP"
  xcrun simctl launch "$UDID" gr.aekhub.app -shots YES
  sleep 12; xcrun simctl io "$UDID" screenshot "$OUT/$2-1-home.png"
  # κύλιση της αρχικής (2η οθόνη)
  xcrun simctl terminate "$UDID" gr.aekhub.app; xcrun simctl launch "$UDID" gr.aekhub.app -shots YES -open "news" -scroll 1; sleep 10
  xcrun simctl io "$UDID" screenshot "$OUT/$2-1b-home.png"
  for u in matches standings me notifs "match/$MATCH" "match/$MATCH2"; do
    xcrun simctl terminate "$UDID" gr.aekhub.app; xcrun simctl launch "$UDID" gr.aekhub.app -shots YES -open "$u"; sleep 10
    xcrun simctl io "$UDID" screenshot "$OUT/$2-$(echo $u | tr '/' '-').png"
  done
  # σελίδα αγώνα: κάθε καρτέλα (κυλισμένη ως τις καρτέλες)
  for t in Πορεία Στατιστικά Συνθέσεις Παίκτες; do
    xcrun simctl terminate "$UDID" gr.aekhub.app; xcrun simctl launch "$UDID" gr.aekhub.app -shots YES -open "match/$MATCH" -mtab "$t" -scroll 1; sleep 10
    xcrun simctl io "$UDID" screenshot "$OUT/$2-mt-$t.png"
  done
  xcrun simctl terminate "$UDID" gr.aekhub.app; xcrun simctl launch "$UDID" gr.aekhub.app -shots YES -open "match/$MATCH2" -mtab Πορεία -scroll 1; sleep 10
  xcrun simctl io "$UDID" screenshot "$OUT/$2-mt-basket.png"
  xcrun simctl shutdown "$UDID"
}
# ⌚ Apple Watch
watch() {
  WAPP="$(dirname "$APP")/../Debug-watchsimulator/AEKHubWatch.app"
  UDID=$(xcrun simctl list devices available | grep -m1 -E "Apple Watch (Series 1[01]|Ultra).*\(" | grep -oE '[0-9A-F-]{36}')
  [ -z "$UDID" ] && { echo "δεν βρέθηκε ρολόι"; xcrun simctl list devices available | grep -i watch; return; }
  xcrun simctl boot "$UDID" || true
  xcrun simctl bootstatus "$UDID" -b
  xcrun simctl install "$UDID" "$WAPP" || { ls "$(dirname "$WAPP")"; return; }
  xcrun simctl launch "$UDID" gr.aekhub.app.watchkitapp; sleep 14
  xcrun simctl io "$UDID" screenshot "$OUT/watch-1-home.png"
  for u in "match/$MATCH" "match/$MATCH2" standings; do
    xcrun simctl terminate "$UDID" gr.aekhub.app.watchkitapp; xcrun simctl launch "$UDID" gr.aekhub.app.watchkitapp -open "$u"; sleep 12
    xcrun simctl io "$UDID" screenshot "$OUT/watch-$(echo $u | tr '/' '-').png"
  done
  xcrun simctl shutdown "$UDID"
}
watch
shoot "iPhone 17 Pro (" phone
shoot "iPad Pro 13" ipad
ls -la "$OUT"
