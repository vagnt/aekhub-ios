# Σβήνει ΜΟΝΟ τα πιστοποιητικά ανάπτυξης (DEVELOPMENT / IOS_DEVELOPMENT) που φτιάχνει το Xcode σε κάθε build
# του GitHub (κάθε runner είναι καινούργιος → νέο πιστοποιητικό κάθε φορά → όριο της Apple).
# Το ζήτησε ο χρήστης (7/11/2026). ΠΟΤΕ τα Distribution: με αυτά υπογράφονται TestFlight/App Store.
import os, time, json, urllib.request, jwt
kid, iss, path = os.environ["ASC_KEY_ID"], os.environ["ASC_ISSUER_ID"], os.environ["AUTHKEY"]
tok = jwt.encode({"iss": iss, "iat": int(time.time()), "exp": int(time.time()) + 600, "aud": "appstoreconnect-v1"},
                 open(path).read(), algorithm="ES256", headers={"kid": kid, "typ": "JWT"})
def call(url, method="GET"):
    r = urllib.request.Request(url, method=method, headers={"Authorization": "Bearer " + tok})
    with urllib.request.urlopen(r, timeout=30) as resp:
        b = resp.read()
        return json.loads(b) if b else {}
base = "https://api.appstoreconnect.apple.com/v1/certificates"
dev = [c for c in call(base + "?limit=200").get("data", [])
       if c["attributes"].get("certificateType") in ("DEVELOPMENT", "IOS_DEVELOPMENT")]
print(f"Πιστοποιητικά ανάπτυξης: {len(dev)}")
for c in dev:
    try:
        call(base + "/" + c["id"], "DELETE"); print("✓ σβήστηκε", c["attributes"].get("name"))
    except Exception as e:
        print("✗", c["id"], e)
