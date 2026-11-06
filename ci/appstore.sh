#!/bin/bash
# Screenshots για τη σελίδα του App Store: iPhone 6,9″ (17 Pro Max) + iPad 13″, χωρίς διαφημίσεις, ώρα 9:41
set -x
APP="$1"; OUT="$2"; mkdir -p "$OUT"
shoot() { # $1 = συσκευή, $2 = πρόθεμα
  UDID=$(xcrun simctl list devices available | grep -m1 "$1" | grep -oE '[0-9A-F-]{36}')
  [ -z "$UDID" ] && { echo "δεν βρέθηκε $1"; xcrun simctl list devices available; return; }
  xcrun simctl boot "$UDID" || true
  xcrun simctl bootstatus "$UDID" -b
  xcrun simctl status_bar "$UDID" override --time "9:41" --batteryState charged --batteryLevel 100 --cellularBars 4 --wifiBars 3 || true
  xcrun simctl install "$UDID" "$APP"
  n=1
  for u in news "match/$MATCH" "match/$MATCH|Πορεία" "match/$MATCH|Συνθέσεις" matches standings "post/$POST" "match/$MATCH2|Πορεία"; do
    o="${u%%|*}"; t=""; [[ "$u" == *"|"* ]] && t="${u##*|}"
    xcrun simctl terminate "$UDID" gr.aekhub.app 2>/dev/null
    if [ -n "$t" ]; then xcrun simctl launch "$UDID" gr.aekhub.app -shots YES -noads YES -open "$o" -mtab "$t" -scroll 1
    else xcrun simctl launch "$UDID" gr.aekhub.app -shots YES -noads YES -open "$o"; fi
    sleep 12
    xcrun simctl io "$UDID" screenshot "$OUT/$2-$n.png"; n=$((n+1))
  done
  xcrun simctl shutdown "$UDID"
}
watch() {
  WAPP="$(dirname "$APP")/../Debug-watchsimulator/AEKHubWatch.app"
  UDID=$(xcrun simctl list devices available | grep -m1 -E "Apple Watch (Ultra|Series 1[01] \(46mm\)).*\(" | grep -oE '[0-9A-F-]{36}')
  [ -z "$UDID" ] && return
  xcrun simctl boot "$UDID" || true; xcrun simctl bootstatus "$UDID" -b
  xcrun simctl install "$UDID" "$WAPP" || return
  n=1
  for u in "" "match/$MATCH" feed standings; do
    xcrun simctl terminate "$UDID" gr.aekhub.app.watchkitapp 2>/dev/null
    if [ -n "$u" ]; then xcrun simctl launch "$UDID" gr.aekhub.app.watchkitapp -open "$u"; else xcrun simctl launch "$UDID" gr.aekhub.app.watchkitapp; fi
    sleep 14; xcrun simctl io "$UDID" screenshot "$OUT/watch-$n.png"; n=$((n+1))
  done
  xcrun simctl shutdown "$UDID"
}
shoot "iPhone 17 Pro Max" iphone69
shoot "iPad Pro 13" ipad13
watch
ls -la "$OUT"
