# 📥 Λήψεις App Store → aekhub.gr (wp-admin → 📱 AEK Hub App → 📥 Λήψεις). Τρέχει κάθε μέρα από το .github/workflows/downloads.yml.
# Παίρνει από το App Store Connect API τα Sales Reports (DAILY / SALES / SUMMARY) των τελευταίων ημερών,
# κρατά μόνο το AEK Hub (Apple ID 6831797578) και τα στέλνει στο site (POST /app/dl-report, κεφαλίδα X-Aek-Token).
# Τύποι προϊόντος Apple: 1/1F/1T = νέα λήψη · 3/3F/3T = ξανά-λήψη · 7/7F/7T = ενημέρωση.
import os, sys, time, gzip, json, csv, io, datetime, urllib.request, urllib.error, jwt

APP_ID = "6831797578"
SITE = "https://aekhub.gr/?rest_route=/aekhub/v1/app/dl-report"
kid, iss, key, vendor = (os.environ.get(k, "").strip() for k in ("ASC_KEY_ID", "ASC_ISSUER_ID", "ASC_KEY_P8", "ASC_VENDOR"))
token = os.environ.get("AEKHUB_DL_TOKEN", "").strip()
if not (kid and iss and key and vendor and token):
    print("::warning::Λείπουν secrets (ASC_VENDOR ή AEKHUB_DL_TOKEN) — βλ. wp-admin → 📱 AEK Hub App → 📥 Λήψεις"); sys.exit(0)
tok = jwt.encode({"iss": iss, "iat": int(time.time()), "exp": int(time.time()) + 1200, "aud": "appstoreconnect-v1"},
                 key, algorithm="ES256", headers={"kid": kid, "typ": "JWT"})

def report(day):
    q = ("filter[frequency]=DAILY&filter[reportType]=SALES&filter[reportSubType]=SUMMARY&filter[version]=1_0"
         f"&filter[vendorNumber]={vendor}&filter[reportDate]={day}")
    r = urllib.request.Request("https://api.appstoreconnect.apple.com/v1/salesReports?" + q,
                               headers={"Authorization": "Bearer " + tok, "Accept": "application/a-gzip"})
    try:
        with urllib.request.urlopen(r, timeout=60) as resp:
            raw = resp.read()
    except urllib.error.HTTPError as e:
        if e.code == 404: return None  # δεν βγήκε ακόμα / καμία κίνηση εκείνη τη μέρα
        print(f"::warning::{day}: HTTP {e.code} {e.read()[:300]!r}"); return None
    txt = gzip.decompress(raw).decode("utf-8")
    return list(csv.DictReader(io.StringIO(txt), delimiter="\t"))

days = {}
today = datetime.date.today()
for back in range(1, 11):  # οι τελευταίες 10 μέρες (συμπληρώνει κενά αν μια μέρα αργήσει η Apple)
    day = (today - datetime.timedelta(days=back)).isoformat()
    rows = report(day)
    if rows is None: continue
    agg = {"first": 0, "re": 0, "upd": 0, "dev": {}, "cc": {}}
    for row in rows:
        if row.get("Apple Identifier", "").strip() != APP_ID: continue
        t = row.get("Product Type Identifier", "").strip(); u = int(float(row.get("Units", "0") or 0))
        kind = "first" if t in ("1", "1F", "1T") else "re" if t in ("3", "3F", "3T") else "upd" if t in ("7", "7F", "7T") else None
        if not kind: continue
        agg[kind] += u
        if kind == "first":
            dv = row.get("Device", "").strip() or "?"; cc = row.get("Country Code", "").strip() or "?"
            agg["dev"][dv] = agg["dev"].get(dv, 0) + u; agg["cc"][cc] = agg["cc"].get(cc, 0) + u
    days[day] = agg
    print(f"{day}: νέες {agg['first']} · ξανά {agg['re']} · ενημερώσεις {agg['upd']}")

if not days:
    print("Καμία αναφορά ακόμα (η Apple βγάζει την πρώτη 1–2 μέρες μετά τις πρώτες λήψεις)."); sys.exit(0)
req = urllib.request.Request(SITE, data=json.dumps({"days": days}).encode(), method="POST",
                             headers={"Content-Type": "application/json", "X-Aek-Token": token, "User-Agent": "aekhub-ios-ci"})
try:
    with urllib.request.urlopen(req, timeout=60) as resp:
        print("site:", resp.read().decode()[:200])
except urllib.error.HTTPError as e:
    print(f"::error::Το site απάντησε {e.code}: {e.read()[:300]!r}"); sys.exit(1)
