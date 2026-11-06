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
  for u in matches standings me notifs "match/$MATCH" "match/$MATCH2"; do
    xcrun simctl terminate "$UDID" gr.aekhub.app; xcrun simctl launch "$UDID" gr.aekhub.app -shots YES; sleep 4
    xcrun simctl openurl "$UDID" "aekhub://$u"; sleep 7
    xcrun simctl io "$UDID" screenshot "$OUT/$2-$(echo $u | tr '/' '-').png"
  done
  xcrun simctl shutdown "$UDID"
}
shoot "iPhone 17 Pro (" phone
shoot "iPad Pro 13" ipad
ls -la "$OUT"
