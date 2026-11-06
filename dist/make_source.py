#!/usr/bin/env python3
"""Φτιάχνει/ενημερώνει το source.json (μορφή AltStore/SideStore) στο δημόσιο repo aekhub-ios-dist.
Χρήση: make_source.py <φάκελος dist repo> <έκδοση> <build> <url .ipa> <μέγεθος σε bytes>"""
import json, sys, os, datetime

d, ver, build, url, size = sys.argv[1], sys.argv[2], sys.argv[3], sys.argv[4], int(sys.argv[5])
raw = "https://raw.githubusercontent.com/vagnt/aekhub-ios-dist/main/"
path = os.path.join(d, "source.json")
try:
    old = json.load(open(path, encoding="utf-8"))
    versions = old["apps"][0].get("versions", [])
except Exception:
    versions = []

new = {
    "version": ver,
    "buildVersion": build,
    "date": datetime.datetime.now(datetime.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
    "localizedDescription": f"AEK Hub {ver} (build {build})",
    "downloadURL": url,
    "size": size,
    "minOSVersion": "16.0",
}
versions = [new] + [v for v in versions if v.get("buildVersion") != build][:9]

src = {
    "name": "AEK Hub",
    "identifier": "gr.aekhub.source",
    "subtitle": "Η εφαρμογή του aekhub.gr",
    "description": "Η επίσημη εφαρμογή του AEK Hub για iPhone και iPad.",
    "iconURL": raw + "icon.png",
    "website": "https://aekhub.gr",
    "tintColor": "#F9CF1C",
    "featuredApps": ["gr.aekhub.app"],
    "apps": [{
        "name": "AEK Hub",
        "bundleIdentifier": "gr.aekhub.app",
        "developerName": "AEK Hub",
        "subtitle": "Όλη η ΑΕΚ, όλα τα τμήματα",
        "localizedDescription": "Ειδήσεις, live αγώνες όλων των τμημάτων της ΑΕΚ (σκορ, πορεία, ενδεκάδες, στατιστικά, βαθμοί παικτών), βαθμολογίες, widgets και ειδοποιήσεις.",
        "iconURL": raw + "icon.png",
        "tintColor": "#F9CF1C",
        "category": "news",
        "screenshots": [],
        "versions": versions,
        "appPermissions": {"entitlements": [], "privacy": {}},
        # παλιά πεδία (για παλιότερα AltStore/SideStore)
        "version": ver, "versionDate": new["date"], "downloadURL": url, "size": size,
    }],
    "news": [],
}
json.dump(src, open(path, "w", encoding="utf-8"), ensure_ascii=False, indent=2)
print("source.json:", ver, build)
