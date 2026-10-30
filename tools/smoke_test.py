"""End-to-end smoke test against a running Orbit API + worker loaded with dev seed data.

Usage (from the repo root, after `make dev-up`, `make migrate`, `make backend-seed`, with `make backend-run-api` and
`make backend-run-worker` running):
    python3 tools/smoke_test.py
Env: ORBIT_API (default http://localhost:8080), ORBIT_PG_CONTAINER (default orbit-postgres-1).
Uses the dev fixed OTP 123456 and the seed logins, so it only works against a dev environment. It creates a few
farmers each run and revokes the FA device it signs in with; rerunning is safe.
"""
import base64, gzip, hashlib, hmac, json, os, struct, sys, tempfile, time, uuid
import urllib.request, urllib.error

BASE = os.environ.get("ORBIT_API", "http://localhost:8080")
PG_CONTAINER = os.environ.get("ORBIT_PG_CONTAINER", "orbit-postgres-1")
# The HO admin's TOTP secret is kept between runs so later runs can log in.
TOTP_FILE = os.path.join(tempfile.gettempdir(), "orbit-smoke-admin-totp.txt")
NS = uuid.UUID("5b0f1a52-6f0e-4c1d-9a51-0b17c0de5eed")
sid = lambda name: str(uuid.uuid5(NS, name))
fails = []


def call(method, path, body=None, token=None, headers=None, expect=None):
    data = json.dumps(body).encode() if body is not None else None
    req = urllib.request.Request(BASE + path, data=data, method=method)
    req.add_header("Content-Type", "application/json")
    if token:
        req.add_header("Authorization", "Bearer " + token)
    for k, v in (headers or {}).items():
        req.add_header(k, v)
    try:
        with urllib.request.urlopen(req) as r:
            status, raw, hdrs = r.status, r.read(), r.headers
    except urllib.error.HTTPError as e:
        status, raw, hdrs = e.code, e.read(), e.headers
    if hdrs.get("Content-Encoding") == "gzip":
        raw = gzip.decompress(raw)
    out = json.loads(raw) if raw else None
    ok = expect is None or status == expect
    print(("PASS" if ok else "FAIL"), status, method, path)
    if not ok:
        fails.append(f"{method} {path}: {status} {raw[:300]!r}")
    return status, out, hdrs


def check(cond, what):
    print(("PASS" if cond else "FAIL"), "  ", what)
    if not cond:
        fails.append(what)


def totp(secret_b32):
    key = base64.b32decode(secret_b32 + "=" * (-len(secret_b32) % 8), casefold=True)
    msg = struct.pack(">Q", int(time.time()) // 30)
    h = hmac.new(key, msg, hashlib.sha1).digest()
    o = h[-1] & 15
    return "%06d" % ((struct.unpack(">I", h[o:o + 4])[0] & 0x7FFFFFFF) % 1000000)


def wait_for(fn, what, secs=15):
    for _ in range(secs * 2):
        if fn():
            check(True, what)
            return
        time.sleep(0.5)
    check(False, what)


def farmer_login(phone, device_key):
    for _ in range(5):
        st, _, h = call("POST", "/v1/auth/otp/request", {"phone": phone})
        if st != 429:
            break
        wait = int(h.get("Retry-After") or 30)
        print(f"    rate limited (expected for repeat runs); waiting {wait}s")
        time.sleep(wait + 1)
    check(st == 200, f"OTP request for {phone}")
    return call("POST", "/v1/auth/otp/verify",
                {"phone": phone, "code": "123456", "device": {"device_key": device_key}}, expect=200)[1]


# --- 1. Seeded farmer signs in with OTP and sees home ---
r = farmer_login("9000000102", "venk-phone-1")  # Venkatesh; accepts a 10-digit number
ravi_tok = r["tokens"]["access_token"]
_, home, _ = call("GET", "/v1/farmer/me", token=ravi_tok, expect=200)
print("    home keys:", sorted(home.keys()))
check(json.dumps(home).find("Suresh") >= 0, "Venkatesh's home shows FA Suresh")

# --- 2. New farmer self sign-up, picks Kondapur ---
new_phone = "+9190000%05d" % (int(time.time()) % 100000)
r = farmer_login(new_phone, "new-" + new_phone[1:])
new_tok = r["tokens"]["access_token"]
check(r.get("is_new") is True, "self sign-up is a new farmer")
new_farmer_id = r["farmer_id"]
st, _, _ = call("POST", "/v1/farmer/me/consents", {"purpose": "programme", "granted": True, "notice_version": "v1"},
                token=new_tok)
check(st in (200, 201), f"pending_profile farmer records consent ({st})")
_, cs, _ = call("GET", "/v1/farmer/me/consents", token=new_tok, expect=200)
check("programme" in json.dumps(cs), "consent can be given during sign-up, before the village is picked")
_, vs, _ = call("GET", "/v1/farmer/villages?q=kond", token=new_tok, expect=200)
check(any(v["id"] == sid("village:kondapur") for v in vs["items"]), "village search finds Kondapur")
call("POST", "/v1/farmer/me/complete-profile",
     {"name": "Smoke Farmer", "language": "te", "village_id": sid("village:kondapur")}, token=new_tok, expect=200)

# --- 3. FA logs in, pulls snapshot, enrols + logs a visit offline ---
_, r, _ = call("POST", "/v1/auth/fa/login",
               {"code": "FA-KDP-014", "password": "fa-dev-pass", "device": {"device_key": "suresh-%d" % int(time.time())}}, expect=200)
fa_tok = r["tokens"]["access_token"]
_, snap, h = call("GET", "/v1/fa/sync/snapshot", token=fa_tok, headers={"Accept-Encoding": "gzip"}, expect=200)
etag = h.get("ETag")
print("    snapshot sections:", sorted(snap["sections"].keys()), "etag", etag)
check(len(snap["sections"].get("farmers", [])) >= 2, "snapshot has Suresh's farmers")

wait_for(lambda: any("Smoke" in json.dumps(a) or a.get("kind") == "new_farmer"
                     for a in (call("GET", "/v1/fa/alerts", token=fa_tok)[1] or {}).get("items", [])),
         "FA gets a new-farmer alert for the self sign-up")
# Background work for the sign-up has settled, so an unchanged snapshot is a 304.
time.sleep(2)
_, _, h = call("GET", "/v1/fa/sync/snapshot", token=fa_tok, headers={"Accept-Encoding": "gzip"}, expect=200)
etag = h.get("ETag")
call("GET", "/v1/fa/sync/snapshot", token=fa_tok, headers={"If-None-Match": etag}, expect=304)

enrol_phone = "+9191111%05d" % (int(time.time()) % 100000)
farmer_id, plot_id, season_id, visit_id = (str(uuid.uuid4()) for _ in range(4))
call("POST", "/v1/fa/consent-otp/request", {"phone": enrol_phone}, token=fa_tok, expect=200)
_, proof, _ = call("POST", "/v1/fa/consent-otp/verify", {"phone": enrol_phone, "code": "123456"}, token=fa_tok, expect=200)
_, lk, _ = call("GET", "/v1/fa/farmers/lookup?phone=" + enrol_phone.replace("+", "%2B"), token=fa_tok, expect=200)
check(lk.get("status") == "new", f"phone lookup before enrolment says new ({lk.get('status')})")
now = time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime())
cmds = [
    {"id": str(uuid.uuid4()), "type": "EnrolFarmer", "client_created_at": now, "payload": {
        "farmer_id": farmer_id, "phone": enrol_phone, "name": "Enrolled Farmer", "language": "te",
        "village_id": sid("village:gachibowli"),
        "consent": {"purposes": ["programme"], "otp_proof": proof["otp_proof"], "audio_played": True, "notice_version": "v1"}}},
    {"id": str(uuid.uuid4()), "type": "SavePlot", "payload": {
        "plot_id": plot_id, "farmer_id": farmer_id, "label": "Plot 1", "pin": {"lat": 17.44, "lng": 78.35},
        "area_acres": 1.5, "area_source": "typed"}},
    {"id": str(uuid.uuid4()), "type": "StartSeason", "payload": {
        "season_id": season_id, "farmer_id": farmer_id, "plot_id": plot_id, "season_code": "kharif-2026",
        "crop_id": sid("crop:cotton"), "sowing_date": "2026-07-01"}},
    {"id": str(uuid.uuid4()), "type": "LogVisit", "payload": {
        "visit_id": visit_id, "farmer_id": farmer_id, "plot_id": plot_id, "season_id": season_id,
        "visited_at": now, "location": {"lat": 17.44, "lng": 78.35}, "farmer_present": True,
        "issues": [{"issue_visit_id": str(uuid.uuid4()), "issue_id": sid("issue:cotton:pink-bollworm"),
                    "severity": "moderate", "advisory_rule_id": sid("rule:pbw:v1")}],
        "photos": [], "next_visit": None}},
]
_, res, _ = call("POST", "/v1/fa/sync/commands", {"commands": cmds}, token=fa_tok, expect=200)
for c, rr in zip(cmds, res["results"]):
    check(rr["status"] == "applied", f"{c['type']} -> {rr['status']} {rr.get('error') or ''}")
_, res2, _ = call("POST", "/v1/fa/sync/commands", {"commands": cmds}, token=fa_tok, expect=200)
check([x["status"] for x in res2["results"]] == [x["status"] for x in res["results"]], "re-sending the batch is idempotent")
_, snap2, h2 = call("GET", "/v1/fa/sync/snapshot", token=fa_tok, headers={"If-None-Match": etag}, expect=200)
check(h2.get("ETag") != etag, "snapshot version moved after writes")

# --- 4. Enrolled farmer signs in and sees the visit advice notice ---
r = farmer_login(enrol_phone, "enrolled-1")
enr_tok = r["tokens"]["access_token"]
check(r["farmer_id"] == farmer_id, "OTP sign-in finds the FA-enrolled farmer (merge on phone)")


def has_advice():
    items = (call("GET", "/v1/farmer/notices", token=enr_tok)[1] or {}).get("items", [])
    return any(n.get("kind") == "visit_advice" for n in items)


wait_for(has_advice, "farmer inbox has the visit advice notice")
_, vh, _ = call("GET", "/v1/farmer/visits", token=enr_tok, expect=200)
check("Sample 5 SG" in json.dumps(vh, ensure_ascii=False), "visit history shows our product name")

# --- 5. Farmer asks for a call-back -> FA alert ---
call("POST", "/v1/farmer/callbacks", {"note": "Please call"}, token=ravi_tok)
wait_for(lambda: any(a.get("kind") == "callback"
                     for a in (call("GET", "/v1/fa/alerts", token=fa_tok)[1] or {}).get("items", [])),
         "FA gets a call-back alert")

# --- 6. HO admin: TOTP enrolment, then admin reads ---
# Failed HO logins count towards a 15-minute lockout, so never send a guess: use the saved secret when there is one,
# and never reuse a code (they are single use), waiting for the next 30 s step if this run would repeat the last one.
def ho_login_with_code(secret):
    step = int(time.time()) // 30
    try:
        last = int(open(TOTP_FILE + ".step").read())
    except (OSError, ValueError):
        last = -1
    if step <= last:
        time.sleep(30 * (last + 1) - time.time() + 1)
    open(TOTP_FILE + ".step", "w").write(str(int(time.time()) // 30))
    return call("POST", "/v1/auth/ho/login",
                {"email": "admin@orbit.dev", "password": "orbit-dev-pass", "totp_code": totp(secret)})


secret = open(TOTP_FILE).read().strip() if os.path.exists(TOTP_FILE) else None
st, r = 0, None
if secret:
    st, r, _ = ho_login_with_code(secret)
if not secret or (st == 401 and (r or {}).get("error", {}).get("code") == "totp_enrolment_required"):
    st, r, _ = call("POST", "/v1/auth/ho/login", {"email": "admin@orbit.dev", "password": "orbit-dev-pass"})
    check(st == 401 and r["error"]["code"] == "totp_enrolment_required", "HO login asks for TOTP enrolment first")
    _, en, _ = call("POST", "/v1/auth/ho/totp/start", {"email": "admin@orbit.dev", "password": "orbit-dev-pass"}, expect=200)
    secret = en["secret"]
    open(TOTP_FILE, "w").write(secret)
    open(TOTP_FILE + ".step", "w").write(str(int(time.time()) // 30))
    call("POST", "/v1/auth/ho/totp/confirm",
         {"email": "admin@orbit.dev", "password": "orbit-dev-pass", "totp_code": totp(secret)}, expect=200)
    st, r, _ = ho_login_with_code(secret)
check(st == 200, f"HO admin logs in with TOTP ({st})")
ho_tok = r["tokens"]["access_token"]
_, fl, _ = call("GET", "/v1/admin/farmers?limit=50", token=ho_tok, expect=200)
check(len(fl["items"]) >= 4, f"admin farmer list has {len(fl['items'])} farmers")
call("GET", f"/v1/admin/farmers/{farmer_id}", token=ho_tok, expect=200)
_, vl, _ = call("GET", "/v1/admin/visits", token=ho_tok, expect=200)
check(any(v["id"] == visit_id for v in vl["items"]), "admin visit list has the logged visit")
_, al, _ = call("GET", "/v1/admin/alerts", token=ho_tok, expect=200)
check(len(al["items"]) >= 1, "HO alerts present")
_, au, _ = call("GET", "/v1/admin/audit?limit=100", token=ho_tok, expect=200)
check(len({a["action"] for a in au["items"]}) >= 4, "audit log has rows: " + ", ".join(sorted({a['action'] for a in au['items']}))[:200])
call("GET", "/v1/admin/masters/rules", token=ho_tok, expect=200)

# --- 6b. Review regressions and new endpoints ---
_, ac, h = call("GET", "/v1/auth/app-config?app=fa", expect=200)
check("min_version" in ac and "max-age" in (h.get("Cache-Control") or ""), "app-config serves min_version, cacheable")
_, up, _ = call("POST", "/v1/farmer/me/photo/upload-url", {"content_type": "image/jpeg", "bytes": 120000},
                token=new_tok, expect=200)
check(up["storage_key"].startswith("farmers/" + new_farmer_id + "/"), "farmer photo upload key is under the farmer")
_, d, _ = call("GET", "/v1/admin/ho-users/directory", token=ho_tok, expect=200)
check(any(u.get("name") == "Agronomy Reviewer" for u in d.get("items", d if isinstance(d, list) else [])),
      "HO user directory lists names")
_, vc, _ = call("GET", "/v1/admin/visits/counts?group_by=day&from=%s&to=%s" % (
    time.strftime("%Y-%m-%d", time.gmtime(time.time() - 6 * 86400)), time.strftime("%Y-%m-%d", time.gmtime())),
    token=ho_tok, expect=200)
check(len(vc.get("days") or []) == 7, "visit counts give a zero-filled 7-day series")
st, rr, _ = call("POST", "/v1/admin/farmer-reassignments",
                 {"to_fa_id": sid("fa:lakshmi"), "village_ids": [sid("village:kondapur")]}, token=ho_tok)
check(st == 400, f"reassign by village without from_fa_id is refused ({st})")
_, pv, _ = call("POST", "/v1/admin/advisories/preview", {"target": {
    "district_ids": [sid("district:rangareddy")], "village_ids": [sid("village:kondapur")]}}, token=ho_tok, expect=200)
import subprocess
want = int(subprocess.run(["docker", "exec", PG_CONTAINER, "psql", "-U", "orbit", "-d", "orbit", "-tAc",
    "select count(*) from farmers f where f.village_id = '%s' and f.status = 'active' and exists (select 1 from consents c "
    "where c.farmer_id = f.id and c.purpose = 'programme' and c.granted)" % sid("village:kondapur")],
    capture_output=True, text=True).stdout.strip())
check(pv["recipient_count"] == want, f"targeting Kondapur within the district reaches only Kondapur's {want} consented farmers (got {pv['recipient_count']})")
_, pv, _ = call("POST", "/v1/admin/advisories/preview", {"target": {"village_ids": [sid("village:mudimyal")]}}, token=ho_tok, expect=200)
check(pv["recipient_count"] == 0, f"targeting an empty village reaches nobody (got {pv['recipient_count']})")
_, fs, _ = call("GET", "/v1/admin/farmers/stats", token=ho_tok, expect=200)
print("    farmer stats:", fs)
_, fas, _ = call("GET", "/v1/admin/field-assistants/stats", token=ho_tok, expect=200)
print("    FA stats:", fas)
_, lf, _ = call("GET", "/v1/farmer/fas?level=village", token=ravi_tok, expect=200)
check("Suresh" in json.dumps(lf), "Look for FAs lists Suresh for Kondapur/Gachibowli")

# Self sign-up then the FA enrols the same phone offline, then plans and logs a visit (merge alias).
alias_phone = "+9192222%05d" % (int(time.time()) % 100000)
farmer_login(alias_phone, "alias-" + alias_phone[1:])
call("POST", "/v1/fa/consent-otp/request", {"phone": alias_phone}, token=fa_tok, expect=200)
_, ap, _ = call("POST", "/v1/fa/consent-otp/verify", {"phone": alias_phone, "code": "123456"}, token=fa_tok, expect=200)
af, apl, ase, av = (str(uuid.uuid4()) for _ in range(4))
alias_cmds = [
    {"id": str(uuid.uuid4()), "type": "EnrolFarmer", "payload": {
        "farmer_id": af, "phone": alias_phone, "name": "Alias Farmer", "language": "te",
        "village_id": sid("village:kondapur"),
        "consent": {"purposes": ["programme"], "otp_proof": ap["otp_proof"], "audio_played": True, "notice_version": "v1"}}},
    {"id": str(uuid.uuid4()), "type": "SavePlot", "payload": {
        "plot_id": apl, "farmer_id": af, "label": "Plot 1", "pin": {"lat": 17.46, "lng": 78.35},
        "area_acres": 2, "area_source": "typed"}},
    {"id": str(uuid.uuid4()), "type": "StartSeason", "payload": {
        "season_id": ase, "farmer_id": af, "plot_id": apl, "season_code": "kharif-2026", "crop_id": sid("crop:cotton")}},
    {"id": str(uuid.uuid4()), "type": "PlanVisit", "payload": {
        "visit_id": av, "farmer_id": af, "plot_id": apl, "season_id": ase,
        "planned_for": time.strftime("%Y-%m-%d", time.gmtime(time.time() + 86400)), "planned_slot": "morning"}},
    # A NUL byte must be rejected, not block the queue (review finding 2).
    {"id": str(uuid.uuid4()), "type": "UpdateFarmer", "payload": {
        "farmer_id": af, "expected_version": 1, "fields": {"name": "Bad\u0000Name"}}},
    {"id": str(uuid.uuid4()), "type": "AckAlert", "payload": {"alert_id": str(uuid.uuid4())}},
]
_, ar, _ = call("POST", "/v1/fa/sync/commands", {"commands": alias_cmds}, token=fa_tok, expect=200)
got = [r["status"] for r in ar["results"]]
print("    alias batch:", got, "retry_from:", ar.get("retry_from"))
check(got[:4] == ["merged", "applied", "applied", "applied"], "merge then plot/season/visit all go through")
check(len(got) == 6 and got[4] == "rejected" and ar.get("retry_from") is None, "NUL payload rejected and the queue moves on")

# --- 7. Revoke the FA device -> FA app is locked out ---
_, dl, _ = call("GET", f"/v1/admin/devices?subject_kind=fa&subject_id={sid('fa:suresh')}", token=ho_tok, expect=200)
dev = next(d for d in dl["items"] if d["revoked_at"] is None)
call("POST", f"/v1/admin/devices/{dev['id']}/revoke", {"reason": "Phone lost"}, token=ho_tok, expect=200)
st, r, _ = call("GET", "/v1/fa/sync/status", token=fa_tok)
check(st == 401, f"revoked device is refused ({st} {(r or {}).get('error', {}).get('code')})")

# --- 8. Wrong surface and no token ---
call("GET", "/v1/admin/farmers", token=ravi_tok, expect=403)
call("GET", "/v1/farmer/me", expect=401)

print("\n%d failure(s)" % len(fails))
for f in fails:
    print(" -", f)
sys.exit(1 if fails else 0)
