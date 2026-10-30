# Orbit integration test log

End-to-end acceptance journeys. Run them once the backend, the Farmer app, the FA app, the HO portal, the farmer
web pages and staging infra are built. Fill Result (Pass / Fail / Blocked / N/A), Date, Tester and Notes (defect
link, build numbers if they changed mid-run). Every row cites the requirement IDs it covers; the coverage table at
the end maps all 58 IDs to journeys.

## How to run

**Builds under test** (fill before starting)

| Item | Version |
|---|---|
| Backend image tag (one image: api, worker, migrate) | |
| Farmer app build (`mobile/apps/farmer`) | |
| FA app build (`mobile/apps/fa`) | |
| HO portal (`web/apps/ho-portal`) / farmer-web (`web/apps/farmer-web`) build | |
| Infra commit (`infra/envs/staging`) | |

**Environment**
- Staging on AWS (region per the open decision), deployed from `infra/envs/staging`, with real SMS through the
  chosen provider (DLT test templates) to whitelisted test SIMs, real FCM push, and S3 for photos and voice notes.
- Seed: staging seed with 2 districts (D1, D2), a pilot mandal M1 in D1 with 6+ villages, one village V9 with no FA
  allocation, approved masters (one issue whose rule names a Shanmukha product, one issue that is salt only), and
  the users in "Roles" below. Never use real farmer data.
- Devices: one low-end Android (₹7-10k, Android 8 or 9, 2 GB RAM) for the farmer; two FA phones (one mid-range,
  one low-end); a laptop with Chrome for HO; a phone browser for the H10 mobile view and the farmer web page.
- Network: airplane mode for offline steps; a throttled 2G/3G profile (Android developer options or a shaping
  router) for NFR-05; outdoor noon sunlight for NFR-02.
- Time-based steps (72 h temp password, 48 h FA offline, next-day missed visits, season boundary): back-date the
  relevant timestamps with an audited staging-only script in `tools/` (backlog, `tools/implementation-plan.md`
  item 11), or wait. Note which in Notes.
- Before the run: `migrate status` from the same image tag shows every migration applied (`00001`-`00021` and
  `00026`). Before each section: api `/readyz` is 200 and the worker's `:8081/readyz` is 200 (events and SMS
  depend on it).
- SMS templates: staging uses DLT test templates; note in Notes if any template still has a placeholder ID.

**Roles needed**

| Role | Who | Notes |
|---|---|---|
| Farmer A | New phone, self sign-up | Low-end phone, Telugu |
| Farmer B | Enrolled by FA-1 offline | Basic phone is enough for SMS; smartphone for app steps |
| Farmer C | Self-signed up, then enrolled by FA-1 (merge) | |
| FA-1 | Pilot FA, allocated to mandal M1 | Mid-range phone |
| FA-2 | Replacement FA for hand-over | Low-end phone |
| FA-3 | FA in district D2 | For "other FA" and scope checks |
| HO admin | Issues logins, allocations, devices | TOTP on a phone |
| HO agronomy 1 and 2 | Rules and product advisories (maker-checker) | Two different people (dev seed: `agronomy@orbit.dev`, `agronomy2@orbit.dev`) |
| HO finance | Role checks (money in Phase 2) | |
| HO ops (all districts) and HO ops-D1 (scoped to D1) | Advisories, farmers, scope checks | |

## A. Farmer sign-up and new-farmer alerts

| ID | Req IDs | Steps | Expected | Result | Date | Tester | Notes |
|---|---|---|---|---|---|---|---|
| A-01 | FAR-01, FAR-02, FAR-03, NFR-01, NFR-03 | Farmer A opens the app on the low-end phone; enters phone; taps Send OTP; tries Resend at once; enters a wrong OTP, then the right one | App opens in Telugu; Listen plays the step prompt; Resend unlocks after 30 s; the OTP SMS is in SMS Retriever format (`<#>`, app hash on the last line) and the code fills in without a tap; wrong OTP shows Telugu error with attempts left (`otp_invalid`); right OTP signs in. One input per step | | | | |
| A-02 | FAR-04, INT-01, NFR-06 | Farmer A, still `pending_profile`, sees the consent screen (F1a) before the village picker, listens, taps "OK, I agree" | Programme consent stored at once (before any village is picked) with notice version and `audio_played`; `GET /v1/farmer/me/consents` shows it; partner consents stay off | | | | |
| A-03 | FA-10, ADM-01, ADM-02, ADM-04 | Farmer A picks district, mandal, village in M1 (voice-assisted list) and completes the profile | Home opens. Within minutes FA-1 gets a `new_farmer` alert (Alerts tab and push) with name, village and phone, in Telugu when FA-1's first language is Telugu (`title_te`); HO overview (H1) shows a new-farmer alert naming the farmer, area and the FA notified; KPI counts go up by one | | | | |
| A-04 | ADM-02, ADM-04 | A new farmer self-signs up in village V9 (no FA allocated) | HO gets a `farmer_without_fa` alert; H1 "Farmers without an FA" (`FarmerStats.unassigned`) goes up by one; no FA alert; farmer home shows no FA card and Look for FAs shows the mandal/district FAs if any | | | | |
| A-05 | FAR-02 | Farmer switches to English on the login screen, signs in, signs out, signs in again | English persists after login and re-login; later SMS to this farmer are in English | | | | |
| A-06 | FAR-01, WF-01 | Check the welcome SMS for Farmer A and the audit log | Telugu welcome SMS received under its DLT template; audit shows OTP sign-up and profile completion with actor and time | | | | |

## B. FA login and devices

| ID | Req IDs | Steps | Expected | Result | Date | Tester | Notes |
|---|---|---|---|---|---|---|---|
| B-01 | FA-01, ADM-03 | HO admin issues an FA login for FA-1 (H2); FA-1 logs in with the code and temp password | Login works; every call except password change returns 403 `password_change_required`; app shows the change-password screen; after the change the app refreshes and downloads the snapshot | | | | |
| B-02 | FA-01, NFR-07 | Issue a login for FA-2; back-date the temp password by 72 h; FA-2 tries to log in; HO resets the password; FA-2 logs in | First attempt fails with `temp_password_expired` (Telugu/English message); after reset, login and forced change work | | | | |
| B-03 | FA-01 | A login ID that was never created in Admin tries to log in | Rejected; no self sign-up path exists in the FA app | | | | |
| B-04 | NFR-04, NFR-07 | FA-1 sets a 4-digit PIN; airplane mode; kill and reopen the app; unlock with PIN; set phone clock 8 days ahead | PIN unlocks offline; after 7 days offline the app demands a full online login | | | | |
| B-05 | NFR-07 | Enter the wrong PIN until the limit (`pin_max_attempts`, 5) | PIN is disabled and a full password login is needed; unsynced records are kept (the build plan said wipe; open decision in `mobile/implementation-plan.md`) | | | | |
| B-06 | NFR-07 | FA-2 "loses" the phone: HO revokes the device (H2, `POST /v1/admin/devices/{device_id}/revoke`); FA-2 phone goes online | Next heartbeat returns `wipe: true`; app deletes local data and returns to login; any API call from that device gets 401 `device_revoked`; audit has the revoke | | | | |
| B-07 | NFR-07 | HO signs FA-1 out of all devices | FA-1 must log in again on every device | | | | |

## C. FA offline enrolment, visit and sync

| ID | Req IDs | Steps | Expected | Result | Date | Tester | Notes |
|---|---|---|---|---|---|---|---|
| C-01 | FAR-04, INT-01 | Online, FA-1 starts enrolling Farmer B: lookup by phone, then request consent OTP; Farmer B reads the code; FA verifies | Lookup says `new`; Farmer B gets the Telugu consent SMS; verify returns a proof the app stores (valid 7 days) | | | | |
| C-02 | FA-06, FA-07, NFR-04, SYS-03 | Airplane mode. Step 1 farmer (village from the offline list), step 2 plot by GPS walk, step 3 crop, sowing date and season | Each step saves offline ("saved offline, syncs when online"); poor GPS accuracy is flagged; area shows in acres/guntas; the season picker offers the open season codes from the snapshot (current one first); season created on the plot | | | | |
| C-03 | FA-06 | Still offline, add a second plot by pin plus typed area | Saved offline with area source "typed" | | | | |
| C-04 | FA-04, FA-05 | Still offline, tap call on Farmer B (dialler opens), then plan a visit for tomorrow morning | Visit shows in the calendar as Planned | | | | |
| C-05 | FA-08, FA-09, WF-02 | Still offline, log a visit: stage, issue (pest), severity high, 3 photos, pick the salt from the approved list (issue with a product); add a second issue that is salt only; set next visit | First issue shows the Shanmukha product; second shows "salt only"; no free-text product field exists; visit saved offline | | | | |
| C-06 | FA-07, SYS-01, SYS-03, ADM-01 | Turn network on; do not open the app | Background sync sends commands (all `applied`), then photos upload; Sync status shows 0 pending; HO H7 shows Farmer B, both plots (server area), season and the visit with photos and advice; overview visit counts update | | | | |
| C-07 | FA-07 | Force a re-send of the same batch (kill the app mid-sync, or replay the request) | No duplicate farmer, plot, season or visit; repeated commands return the stored results | | | | |
| C-08 | FAR-10, FAR-11, FA-05, FA-08, FAR-12 | Farmer B: check SMS; sign in to the app with OTP | Welcome SMS and visit-advice SMS (Telugu, with link); My visits shows the visit with stage, issues, advice and photo count; next-visit banner shows the planned date | | | | |
| C-09 | FAR-04, INT-01, NFR-06 | Enrol another farmer offline with no consent proof; sync; later get a proof and record consent | Farmer is created with `consent_pending` in the snapshot; after `RecordConsent` syncs, the flag clears and the consent row exists | | | | |
| C-10 | FA-09, WF-02 | Agronomy retires the rule FA-1 has offline; FA-1 logs a visit with it offline, then syncs | Visit is saved; that issue is kept as `unresolved` (no salt); visit is not rejected; HO sees the issue as unresolved on the visit detail | | | | |
| C-11 | FA-03, FA-04, ADM-04 | FA-1 online opens Farmers near me (list and map) | Only farmers in FA-1's allocation; nearest first; call button opens the dialler; map works with saved offline tiles in airplane mode | | | | |
| C-12 | FA-06, SYS-01 | Online, FA-1 enrols a new farmer with a photo (upload before the enrolment syncs); later FA-1 changes the photo from Farmer 360 (UpdateFarmer). Farmer A sets their own photo in My farm. Replay one EnrolFarmer with another farmer's photo key | Photo shows in H7 Farmer 360 (`photo_url`), FA-1's Farmer 360 and the farmer's Home; the replayed enrolment is applied with the photo dropped (audit meta notes it); an UpdateFarmer with a key outside the farmer's prefix is `rejected` | | | | |

## D. Merges and conflicts

| ID | Req IDs | Steps | Expected | Result | Date | Tester | Notes |
|---|---|---|---|---|---|---|---|
| D-01 | FA-07, SYS-01 | Farmer C self-signs up (village in M1). FA-1, offline, enrols Farmer C's phone as new, then syncs | Command result `merged` with `merged_into`; app shows "Already registered" with the existing name; one farmer in H7 with both sources in history | | | | |
| D-02 | FA-07 | FA-1 enrols a phone already assigned to FA-3 (lookup first, then offline anyway) | Lookup says `other_fa`; the offline command is `rejected` with `registered_with_another_fa`; app shows the Telugu reason and the local record is marked failed | | | | |
| D-03 | FA-07, WF-01 | FA-1 offline edits Farmer B's name; HO edits the same farmer in H7; FA-1 syncs; choose "Keep mine" | Result `conflict` with both values; app shows "Keep mine / Keep HO's"; Keep mine re-sends with the new expected_version and is applied; audit shows both edits and the choice | | | | |
| D-04 | FA-07 | Repeat D-03 and choose "Keep HO's" | Local change is dropped; snapshot shows HO's value; nothing re-sent | | | | |

## E. Farmer app

| ID | Req IDs | Steps | Expected | Result | Date | Tester | Notes |
|---|---|---|---|---|---|---|---|
| E-01 | FAR-05, FAR-07, NFR-08 | Farmer B opens Home | Name, village, crop, acreage, current stage, plan badge, FA card with one-tap call (dialler opens with FA-1's number), next visit. Weather: see P-01 | | | | |
| E-02 | FAR-08, FAR-09, ADM-04 | Look for FAs; switch filter Village / Mandal / District; tap call and chat | List follows Admin allocation for each level; call opens the dialler; chat opens the chosen chat app | | | | |
| E-03 | FAR-10, FA-09 | My visits: switch plots; open a visit | Timeline per plot with date, FA name, stage, issue, advice (Shanmukha product or salt only), photo count; no competitor brand anywhere | | | | |
| E-04 | NFR-08, FA-10, WF-01 | Farmer B taps "Call me back" | FA-1 gets a `callback` alert (push and Alerts tab, Telugu for a Telugu FA); farmer sees the open request and can cancel it | | | | |
| E-05 | WF-01 | Request again; FA-1 calls and logs a visit for Farmer B; sync | The open call-back closes automatically on the visit; farmer no longer sees it; audit shows `visits.callback_closed` | | | | |
| E-06 | FAR-06, FAR-16 | Tap a Premium tile on Home | Padlock shown; tap opens the upgrade screen (payment itself is Phase 2) | | | | |
| E-07 | SYS-03 | My farm: add a plot, start a season (pick from the offered season codes), close a season | Season picker lists `season_codes.all_open` from `GET /v1/farmer/crops`; plot and season saved; visible in H7 Farmer 360 and in FA-1's next snapshot | | | | |
| E-08 | INT-02, NFR-05 | Airplane mode; open Home, My visits, My Crop Advisory | Last saved data shows with an offline banner; no crash or blank screen | | | | |

## F. Consents

| ID | Req IDs | Steps | Expected | Result | Date | Tester | Notes |
|---|---|---|---|---|---|---|---|
| F-01 | FAR-04, INT-01, NFR-06, WF-01 | Farmer B grants the `soil_partner` consent, then withdraws it | Current state shown correctly after each step; both stored with notice version; audit shows both | | | | |
| F-02 | INT-01, NFR-06 | Farmer withdraws programme consent; HO sends a promotional advisory to them | The farmer is skipped at send time for the promotional advisory | | | | |
| F-03 | INT-01 | Review outbound calls in staging logs | No partner (soil, schemes, loyalty, weather with farmer data) receives farmer data without a consent row; re-run when partner adapters ship | | | | |

## G. Advisory

| ID | Req IDs | Steps | Expected | Result | Date | Tester | Notes |
|---|---|---|---|---|---|---|---|
| G-01 | ADM-05, FAR-13 | HO ops drafts an advisory "From HO", target crop + mandal M1 + stage, channels push, SMS, in-app; previews the count; submits | Preview count shown; submitted without approval (service class); status moves scheduled to sending to sent | | | | |
| G-02 | ADM-05, ADM-08, WF-02 | Agronomy 1 drafts an advisory "From CIV" naming a Shanmukha product; submits; tries to approve it; Agronomy 2 approves | Status `pending_approval`; Agronomy 1's approval is refused (403, "approved by someone other than its author"); Agronomy 2's works; SMS uses the promotional template | | | | |
| G-03 | ADM-05 | Schedule an advisory for 22:00 IST | In-app notice appears at send time; SMS and push wait until 07:00 IST | | | | |
| G-04 | FAR-12, FAR-13, FAR-03, ADM-05 | Farmer B receives the advisory: push, inbox, SMS with link; opens the link in the phone browser; plays the voice note | Notice tagged HO or CIV in My Crop Advisory; unread badge clears on read; the SMS has the title (at most 30 characters) and the link on the farmer-web host (`FARMER_WEB_BASE_URL`), not the body; web page shows text and plays audio; H9 recipients list shows Farmer B by name and masked phone with per-channel status and "listened" | | | | |
| G-05 | ADM-05, FAR-13 | Preview: crop only; crop + mandal; + stage; + plan | Each filter narrows the count; counts match a direct database query on staging | | | | |
| G-06 | ADM-05 | Cancel an advisory before it starts sending | Status `cancelled`; nobody receives it | | | | |
| G-07 | NFR-07, ADM-05 | HO ops-D1 targets a D2 mandal | Refused (403, own districts only) | | | | |
| G-08 | ADM-05, ADM-08, WF-02 | HO ops drafts a product-naming advisory and submits; Agronomy 1 rejects with a note; Agronomy 1 edits the draft (H3 edit, `PATCH`), fixes the wording and resubmits; Agronomy 1 tries to approve; Agronomy 2 approves | After the reject the advisory is a draft showing the note; the edit saves (`updated_by` = Agronomy 1); Agronomy 1's approval is refused (403, author or last editor); Agronomy 2's works; editing a `pending_approval` advisory is 409 `invalid_status` | | | | |

## H. HO scope, masters and territory

| ID | Req IDs | Steps | Expected | Result | Date | Tester | Notes |
|---|---|---|---|---|---|---|---|
| H-01 | NFR-07, ADM-04 | Sign in as HO ops-D1; open farmers, farmer detail by URL for a D2 farmer, FAs, visits, alerts, audit, advisories, devices | Only D1 data everywhere; D2 records are not found or forbidden. Known gap: HO notes to FAs ignore district scope (expect Fail until fixed) | | | | |
| H-02 | NFR-07 | Finance tries to issue an FA login; ops tries to approve a rule; admin tries to approve a product advisory | Each refused with 403; UI hides the actions | | | | |
| H-03 | ADM-08, WF-02, FA-09 | Agronomy 1 drafts a new rule version (issue to salt to product), submits; Agronomy 1 tries to approve; Agronomy 2 approves; FA-1 syncs | Self-approval refused; after approval the masters version goes up; FA-1's snapshot returns 200 with a new ETag (304 before); visit log shows the new product; old visits keep the old rule version | | | | |
| H-04 | FA-02, ADM-03, ADM-04 | Set-up: a support FA also has a farmer in one of FA-1's villages. HO hands FA-1's allocations to FA-2 (`allocations/handover`), then reassigns with `from_fa_id` = FA-1, `to_fa_id` = FA-2 and the affected `village_ids` (`farmer-reassignments`); repeat both calls; deactivate FA-1 | Only FA-1's farmers move; the support FA's farmer stays; the repeat moves nothing; farmers get a Telugu SMS with FA-2's name and phone; open planned visits and call-backs move to FA-2; FA-2's snapshot has them, FA-1's login no longer works; farmer Home and Look for FAs show FA-2 | | | | |
| H-05 | ADM-04 | Import villages by CSV; allocate an FA to a village, a mandal and a district; end an allocation | Import reports rows added and rejected; allocation changes show in Look for FAs and Farmers near me | | | | |
| H-06 | FA-10 | HO sends a note to FA-1 (H2) with Telugu title and body; FA-1 acknowledges it offline, then syncs | Note appears in Alerts and as a push in FA-1's first language; ack applied after sync | | | | |
| H-07 | SYS-01 | HO deactivates Farmer B, then reactivates | Farmer drops out of FA-1's snapshot and advisory targeting; history kept; returns after reactivation | | | | |

## I. Scheduled jobs

| ID | Req IDs | Steps | Expected | Result | Date | Tester | Notes |
|---|---|---|---|---|---|---|---|
| I-01 | NFR-04, ADM-01 | FA-3 does not sync for 48 h (back-date last sync) | One `fa_offline` HO alert per FA per day on H1; H2 "Not synced 24 h" (`not_synced_since`) lists FA-3 | | | | |
| I-02 | FA-05 | Leave a planned visit for yesterday unlogged | Within an hour after IST midnight it becomes `missed`; it shows in the overdue list and the FA calendar | | | | |
| I-03 | SYS-03 | HO runs a season rollover for a season code | Every active season of that code closes; farmers and FAs see it | | | | |

## J. Audit trail

| ID | Req IDs | Steps | Expected | Result | Date | Tester | Notes |
|---|---|---|---|---|---|---|---|
| J-01 | WF-01, WF-02, NFR-07 | Open the audit chain for Farmer B (H8, `getAuditChain`) | Shows enrolment, consent, plots, season, visit, advice with rule version, notices, reassignment, each with actor, device, time and request ID; HO actors shown by name (HO user directory) | | | | |
| J-02 | WF-01, NFR-07 | Search the audit log by actor FA-1 and a date range; pick 20 random writes from the week | Every write is present with before/after; no secrets or OTP codes in entries | | | | |

## K. Security and rate limits

| ID | Req IDs | Steps | Expected | Result | Date | Tester | Notes |
|---|---|---|---|---|---|---|---|
| K-01 | NFR-07 | Call `/v1/fa/*` with a farmer token, `/v1/admin/*` with an FA token, any surface with no token | 403, 403, 401 | | | | |
| K-02 | NFR-07 | HO admin disables an HO user who is signed in | Their next call gets 401 `session_revoked` | | | | |
| K-03 | NFR-07 | Refresh a session, then reuse the old refresh token after 60 s | 401 `refresh_reused`; the whole session family is revoked | | | | |
| K-04 | FAR-01, NFR-07 | Request OTP 6 times in an hour for one phone; then 6 wrong codes | 429 `rate_limited` with Retry-After on the 6th send; after 5 wrong codes a new OTP is needed | | | | |
| K-05 | NFR-07 | New HO user signs in the first time; enrols TOTP; then enters a wrong TOTP | TOTP set-up required; wrong code gives `totp_invalid` | | | | |
| K-06 | NFR-07 | Open a farmer web link with a tampered token, an expired token, and a token for another notice | 401, 401, 403 | | | | |
| K-07 | NFR-07, FA-07 | FA-1 sends a LogVisit for a farmer assigned to FA-3 | Command `rejected`; no visit saved | | | | |
| K-08 | NFR-07 | Send a sync batch of 201 commands; send a body over the size cap | 400 `validation_failed`; 413 `payload_too_large` | | | | |
| K-09 | NFR-07 | Scan the repo and the built apps for secrets (gitleaks); check the APK for API keys | No secrets; staging and prod secrets only in Secrets Manager | | | | |

## L. Resilience

| ID | Req IDs | Steps | Expected | Result | Date | Tester | Notes |
|---|---|---|---|---|---|---|---|
| L-01 | NFR-04, NFR-05 | Make Redis unreachable on staging for 15 min; do farmer OTP login, FA sync, HO lists, an OTP send burst | `/readyz` 200 `degraded`; everything works, slower; OTP limits still enforced (Postgres fallback) | | | | |
| L-02 | NFR-04 | Reboot RDS with failover during an FA sync | Brief 503s; app retries (`retry_from`); no lost or duplicated commands | | | | |
| L-03 | SYS-02 | Make the SMS provider fail (bad credentials in staging) | OTP request returns 503 with a clear message; advisory SMS deliveries go `failed` and retry; H9 shows status | | | | |
| L-04 | SYS-02 | Switch SMS provider by config only | Messages flow through the new provider; no app release | | | | |
| L-05 | WF-01 | Stop the worker for 10 min while farmers sign up and FAs sync; restart | Alerts, SMS and notices arrive after restart, once each | | | | |
| L-06 | SYS-01 | Deploy a new backend while the previous app builds are installed | Old app builds keep working (no breaking change on `/v1/farmer`, `/v1/fa`) | | | | |
| L-07 | SYS-01, NFR-04 | FA-1 has 3 unsynced records. Raise `APP_MIN_VERSION_FA` (and later `APP_MIN_VERSION_FARMER`) above the installed build and roll the api | Within 5 minutes `GET /v1/auth/app-config` returns the new `min_version` and the heartbeat says `update_required: true`; the FA app pushes its outbox first, then blocks with "Update the app" and the store link; nothing is lost; the farmer app blocks at start; lowering the value unblocks | | | | |
| L-08 | NFR-04 | Block the worker task's access to Postgres for 2 minutes, then restore; also stop the worker task | Worker `:8081/readyz` goes 503 and back to 200, `/healthz` stays 200; the stopped task trips the "running count below desired" alarm and ECS starts a new one | | | | |

## M. Non-functional checks

Targets marked "proposed" are not in the requirements; confirm them with the product owner before the run.

| ID | Req IDs | Steps | Expected | Result | Date | Tester | Notes |
|---|---|---|---|---|---|---|---|
| M-01 | NFR-01, FAR-03 | Walk every farmer screen (F1-F11, states) in Telugu and tap Listen on each | All text Telugu; every screen has Listen and the prompt matches the step | | | | |
| M-02 | NFR-02 | Usability test with 5-10 farmers in the pilot mandal, outdoors at noon | Tasks done without help; text readable in sunlight; contrast per `design/implementation-plan.md` | | | | |
| M-03 | NFR-03 | Count inputs per step in sign-up, consent, village, call-back | One input per step | | | | |
| M-04 | NFR-04 | FA-1 works a full day offline: enrol 5 farmers, log 10 visits with photos, plan 5 visits; sync in the evening | Everything synced, none lost or duplicated; time to sync recorded | | | | |
| M-05 | NFR-05 | Throttle to 3G and to 2G; cold-open farmer Home; measure data per Home load | Home loads on both (proposed: under 5 s on 3G, under 10 s on 2G; under 50 KB per load) | | | | |
| M-06 | NFR-05 | Measure FA snapshot for a territory of ~300 farmers | Under 1 MB gzipped (build plan); 304 when unchanged | | | | |
| M-07 | NFR-05 | Check app sizes and cold start on the low-end phone | Farmer app download under 20 MB (build plan); proposed cold start under 4 s | | | | |
| M-08 | NFR-06 | See F-01 to F-03 | Consent before any vendor share | | | | |
| M-09 | NFR-07 | See section J and K | Audit complete; access controlled | | | | |
| M-10 | NFR-08 | Query farmers with an allocated FA; check 20 of them in the app | FA card on Home for each | | | | |
| M-11 | SYS-01 | Edit a farmer in H7; check FA app (after sync) and farmer app | Same value everywhere without re-entry | | | | |

## P. Not built yet: placeholders

Run these when the feature ships. Until then mark Result "N/A (not built yet)".

| ID | Req IDs | Steps | Expected | Result | Date | Tester | Notes |
|---|---|---|---|---|---|---|---|
| P-01 | FAR-05, INT-02 | Weather strip on Home; airplane mode | Local weather for the farm; last saved weather offline. **Not built yet** (weather feed undecided) | | | | |
| P-02 | ADM-08 | Crop-stage alert rules and stage reminders (calendar module, F11) | Reminder SMS the evening before a stage task. **Not built yet** | | | | |
| P-03 | FAR-14, FAR-15 | AI bot in Telugu by text and voice; ask about a pest; ask for a dose | Answers common questions; never names a chemical, dose or brand; offers Send photo and Call FA. **Phase 3, not built yet** | | | | |
| P-04 | ADM-09 | Engagement analytics (H6) | Funnel and KPIs refresh daily. **Phase 3, not built yet** | | | | |
| P-05 | INT-01, SYS-02 | Soil lab, schemes, loyalty adapters | Data shared only with consent; partner switch needs no release. **Phase 3, not built yet** | | | | |

### Phase 2 money journeys (not built yet)

| ID | Req IDs | Steps | Expected | Result | Date | Tester | Notes |
|---|---|---|---|---|---|---|---|
| Q-01 | FAR-16, FAR-17, PLN-01 | Farmer upgrades to Premium with Razorpay (UPI); fail one payment; try opening a Premium feature with a modified app | Success upgrades at once; failure leaves Free; server blocks Premium without a valid plan. **Not built yet** | | | | |
| Q-02 | PLN-02 | Admin changes Premium price and contents | Applies to new purchases without a release. **Not built yet** | | | | |
| Q-03 | FAR-18, ADM-06 | Farmer books a service; HO schedules, marks done with proof; farmer pays | Status visible to farmer and Admin; paid after Razorpay confirms. **Not built yet** | | | | |
| Q-04 | FAR-19, FA-11, ADM-07, WF-01 | Farmer uploads a bill; FA checks it; HO approves; a duplicate bill is uploaded | Pending, then 5% cashback (capped by MRP) on HO approval; duplicate caught; audit chain complete. **Not built yet** | | | | |
| Q-05 | FAR-20, ADM-07 | Cancel an approved invoice | Reversal entry; balances (Pending, Available, Withdrawn, Reversed) match the ledger. **Not built yet** | | | | |
| Q-06 | FAR-21 | Withdraw before and after ID check (UPI name match + selfie + Finance review) | Blocked before; allowed after. **Not built yet** | | | | |
| Q-07 | NFR-07 | Payout above ₹5,000; approver of the bill tries to release its payout | Needs a second Finance/Admin approval; same person refused. **Not built yet** | | | | |
| Q-08 | FA-11 | FA rejects an invoice | Farmer notified in Telugu with the reason. **Not built yet** | | | | |
| Q-09 | FAR-17 | Penny test in production; reconciliation report | Matches the bank. **Not built yet** | | | | |

## Coverage

| Req ID | Covered by | | Req ID | Covered by |
|---|---|---|---|---|
| SYS-01 | C-06, C-12, D-01, H-07, L-06, L-07, M-11 | | FA-07 | C-02, C-06, C-07, D-01..D-04, K-07 |
| SYS-02 | L-03, L-04, P-05 | | FA-08 | C-05, C-08 |
| SYS-03 | C-02, C-06, E-07, I-03 | | FA-09 | C-05, C-10, E-03, H-03 |
| FAR-01 | A-01, A-06, K-04 | | FA-10 | A-03, E-04, H-06 |
| FAR-02 | A-01, A-05 | | FA-11 | Q-04, Q-08 (not built yet) |
| FAR-03 | A-01, G-04, M-01 | | ADM-01 | A-03, C-06, I-01 |
| FAR-04 | A-02, C-01, C-09, F-01 | | ADM-02 | A-03, A-04 |
| FAR-05 | E-01 (profile part); weather P-01 (not built yet) | | ADM-03 | B-01, H-04 |
| FAR-06 | E-06 | | ADM-04 | A-03, A-04, C-11, E-02, H-01, H-04, H-05 |
| FAR-07 | E-01 | | ADM-05 | G-01..G-08 |
| FAR-08 | E-02 | | ADM-06 | Q-03 (not built yet) |
| FAR-09 | E-02 | | ADM-07 | Q-04, Q-05 (not built yet) |
| FAR-10 | C-08, E-03 | | ADM-08 | G-02, G-08, H-03; alert rules P-02 (not built yet) |
| FAR-11 | C-08 | | ADM-09 | P-04 (Phase 3, not built yet) |
| FAR-12 | C-08, G-04 | | WF-01 | A-06, D-03, E-04, E-05, F-01, J-01, J-02, L-05, Q-04 |
| FAR-13 | G-01, G-04, G-05 | | WF-02 | C-05, C-10, G-02, G-08, H-03, J-01 |
| FAR-14 | P-03 (Phase 3, not built yet) | | INT-01 | A-02, C-01, C-09, F-01..F-03, P-05 |
| FAR-15 | P-03 (Phase 3, not built yet) | | INT-02 | E-08; weather part P-01 (not built yet) |
| FAR-16 | E-06 (padlock), Q-01 | | NFR-01 | A-01, M-01 |
| FAR-17 | Q-01, Q-09 (not built yet) | | NFR-02 | M-02 |
| FAR-18 | Q-03 (not built yet) | | NFR-03 | A-01, M-03 |
| FAR-19 | Q-04 (not built yet) | | NFR-04 | B-04, C-02, I-01, L-01, L-02, L-07, L-08, M-04 |
| FAR-20 | Q-05 (not built yet) | | NFR-05 | E-08, L-01, M-05, M-06, M-07 |
| FAR-21 | Q-06 (not built yet) | | NFR-06 | A-02, C-09, F-01, F-02, M-08 |
| PLN-01 | Q-01 (not built yet) | | NFR-07 | B-02, B-04..B-07, G-07, H-01, H-02, J-01, J-02, K-01..K-09, M-09, Q-07 |
| PLN-02 | Q-02 (not built yet) | | NFR-08 | E-01, E-04, M-10 |
| FA-01 | B-01, B-02, B-03 | | | |
| FA-02 | H-04 (per-person logins plus hand-over; the shared-login reading of FA-02 is a Phase 0 decision) | | | |
| FA-03 | C-11 | | | |
| FA-04 | C-04, C-11 | | | |
| FA-05 | C-04, C-08, I-02 | | | |
| FA-06 | C-02, C-03, C-12 | | | |
