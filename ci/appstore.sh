#!/bin/bash
# Screenshots για τη σελίδα του App Store: iPhone 6,9″ (17 Pro Max) + iPad 13″, χωρίς διαφημίσεις, ώρα 9:41
set -x
APP="$1"; OUT="$2"; mkdir -p "$OUT"
# όριο χρόνου σε κάθε εντολή προσομοιωτή (κόλλησε 26/11 > 1 ώρα χωρίς να βγει τίποτα)
t() { local s=$1; shift; "$@" & local p=$!; ( sleep "$s"; kill -9 $p 2>/dev/null && echo "⏱ έληξε ($s″): $*" ) & local w=$!; wait $p; local r=$?; kill $w 2>/dev/null; return $r; }
shoot() { # $1 = συσκευή, $2 = πρόθεμα
  UDID=$(xcrun simctl list devices available | grep -m1 "$1" | grep -oE '[0-9A-F-]{36}')
  [ -z "$UDID" ] && { echo "δεν βρέθηκε $1"; xcrun simctl list devices available; return; }
  t 120 xcrun simctl boot "$UDID" || true
  t 300 xcrun simctl bootstatus "$UDID" -b
  t 30 xcrun simctl status_bar "$UDID" override --time "9:41" --batteryState charged --batteryLevel 100 --cellularBars 4 --wifiBars 3 || true
  t 180 xcrun simctl install "$UDID" "$APP" || return
  n=1
  for u in news "match/$MATCH" "match/$MATCH|Πορεία" "match/$MATCH|Συνθέσεις" "match/$MATCH3" matches standings "post/$POST" "match/$MATCH2|Πορεία"; do
    o="${u%%|*}"; t=""; [[ "$u" == *"|"* ]] && t="${u##*|}"
    t 20 xcrun simctl terminate "$UDID" gr.aekhub.app 2>/dev/null
    if [ -n "$t" ]; then t 60 xcrun simctl launch "$UDID" gr.aekhub.app -shots YES -noads YES -open "$o" -mtab "$t" -scroll 1
    else t 60 xcrun simctl launch "$UDID" gr.aekhub.app -shots YES -noads YES -open "$o"; fi
    sleep 12
    t 60 xcrun simctl io "$UDID" screenshot "$OUT/$2-$n.png"; echo "📸 $2-$n"; n=$((n+1))
  done
  t 60 xcrun simctl shutdown "$UDID"
}
watch() {
  WAPP="$(dirname "$APP")/../Debug-watchsimulator/AEKHubWatch.app"
  UDID=$(xcrun simctl list devices available | grep -m1 -E "Apple Watch (Ultra|Series 1[01] \(46mm\)).*\(" | grep -oE '[0-9A-F-]{36}')
  [ -z "$UDID" ] && return
  t 120 xcrun simctl boot "$UDID" || true; t 300 xcrun simctl bootstatus "$UDID" -b || return
  t 180 xcrun simctl install "$UDID" "$WAPP" || return
  n=1
  for u in "" "match/$MATCH" feed standings; do
    t 20 xcrun simctl terminate "$UDID" gr.aekhub.app.watchkitapp 2>/dev/null
    if [ -n "$u" ]; then t 60 xcrun simctl launch "$UDID" gr.aekhub.app.watchkitapp -open "$u"; else t 60 xcrun simctl launch "$UDID" gr.aekhub.app.watchkitapp; fi
    sleep 14; t 60 xcrun simctl io "$UDID" screenshot "$OUT/watch-$n.png"; n=$((n+1))
  done
  t 60 xcrun simctl shutdown "$UDID"
}
shoot "iPhone 17 Pro Max" iphone69
shoot "iPad Pro 13" ipad13
watch
ls -la "$OUT"
