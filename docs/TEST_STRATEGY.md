# TEST_STRATEGY.md
## Afterna — Quality Engineering Strategy

**Quality bar:** Recording never silently fails; privacy promises are testable; soft limits never corrupt a session mid-capture.

---

## 1. Test principles

1. **Audio path is Sev-1** — Treat recording/interruption bugs like payment bugs.
2. **Privacy as acceptance criteria** — “Audio deleted after transcription” must be automated.
3. **Real devices over simulators** for mic, background, calls, Bluetooth.
4. **Providers will fail** — Chaos tests for STT/LLM/timeouts are release gates.
5. **Monetisation must not break trust** — Ads never appear on Recording/Processing.

---

## 2. Test layers

| Layer | Scope | Tools (examples) |
|---|---|---|
| Unit | Redaction, minute accounting, state machines | XCTest |
| Integration | Upload → STT → purge pipeline | Local fakes + contract tests |
| UI | Capture, permissions, soft limit sheets | XCUITest |
| Device lab | Calls, route changes, background | Physical iPhones |
| Soak / stress | Long recordings, storage pressure | Overnight device runs |
| Privacy | Retention, export, delete account | Integration + manual audit |
| Growth/ASO | Screenshot flows, first-run | Snapshot tests |

---

## 3. Critical state machine under test

`Idle → RequestingPermission → Recording ⇄ Paused → Finishing → Uploading → Transcribing → Summarising → Ready`  
Parallel: `Interrupted`, `MicDenied`, `ProviderFailed`, `RetryWindow`, `Purged`.

Every transition needs unit tests; illegal transitions must be impossible.

---

## 4. Audio & recording test matrix

### 4.1 Happy path

| Case | Expect |
|---|---|
| 15s conversation | Transcript saved; audio gone |
| 12 min conversation | Completes; memory searchable |
| Pause/resume ×3 | Continuous timeline or clear segments |
| Lock screen during record | Continues; Live Activity accurate |
| Switch apps during record | Continues with `audio` background mode |

### 4.2 Interruptions (must pass on device)

| Interruption | Expect |
|---|---|
| Incoming phone call | Recording pauses; post-call resume prompt |
| Outgoing call | Same |
| Siri activation | Pause or recoverable stop; no corrupt file |
| Alarm / Timer | Recover session |
| Headphones unplug | Route change; keep recording or clean pause |
| Bluetooth connect mid-session | No crash; audible continuity or explicit pause |
| Another app takes audio session | Interrupted UI; user can resume/finish |
| Low Power Mode | Still records; maybe warn on thermal |

### 4.3 Permission & privacy UX

| Case | Expect |
|---|---|
| First mic prompt accept | Starts recording |
| Deny | Settings CTA; no crash loops |
| Deny then allow in Settings | Recovers on next foreground |
| Restricted mic (MDM) | Clear unsupported state |
| ATT deny (if used) | Ads degrade gracefully; capture unaffected |

### 4.4 Duration & stress

| Case | Expect |
|---|---|
| 60 min continuous | File integrity; battery note acceptable |
| 90–120 min | Either supported or hard-stop with save |
| Storage almost full | Preflight warning; no silent fail |
| Rapid start/stop 50× | No zombie sessions / orphan audio |
| Kill app while recording | On relaunch: recover or offer salvage |
| Airplane mode finish | Queued upload; audio TTL respected |
| Offline 24h+ | Purge or user prompt per policy |

### 4.5 Audio quality conditions

| Case | Notes |
|---|---|
| Café noise | STT may degrade; app still completes |
| Two speakers overlapping | Diarisation best-effort |
| AU accents / Māori / Indian English names | Golden transcript set |
| Near-silent room | Warn “low audio levels” |
| Wind / walking | No crash; user-visible quality caveat |

Maintain a **golden audio corpus** (licensed/internal) with expected transcript snippets.

---

## 5. Provider failure tests

Use fault injection against STT/LLM/upload.

| Failure | Expect |
|---|---|
| Upload 401/403 | Re-auth; no data loss |
| Upload 500 × N | Exponential backoff; then user Retry |
| STT timeout | Retry; show status |
| STT 429 rate limit | Respect Retry-After; soft UX |
| STT empty transcript | “No speech detected”; offer delete |
| LLM summary fail | Save transcript without summary; non-blocking |
| Partial network drop mid-upload | Resume or restart chunk safely |
| Provider returns other user’s data | Impossible by contract tests (ID binding) |
| Malformed JSON | Safe error; no crash |
| Clock skew | Signed URL refresh |

**Chaos gate:** 10% injected 500s in staging must not orphan audio beyond TTL without UI.

---

## 6. Privacy & security tests

| Case | Expect |
|---|---|
| Post-success purge | Audio absent on device + server (API assert) |
| Failed job TTL | Auto-delete after configured window |
| Export | Contains transcripts; no audio by default |
| Delete memory | Search index + embeddings gone |
| Delete account | Cascade within SLA; subsequent auth fails |
| Analytics payloads | No raw transcript/PII fields |
| Screenshot in app switcher | Hide sensitive transcript if flagged |
| App Lock | Face ID gate on foreground |
| Backup exclusion | Ephemeral audio not in iCloud backup |
| Logging | Prod logs redacted |

Add **privacy CI job**: grep analytics events for forbidden keys.

---

## 7. Monetisation / credits tests

| Case | Expect |
|---|---|
| Under free pool | Record starts |
| At free pool + 0 credits mid-recording | Finishes successfully; next start blocked until credit earned or week reset |
| Rewarded complete | **+1 Recording Credit** once (no double-credit); balance reflects `reward_minutes` internally |
| Rewarded abandon | No credit |
| Hit `max_daily_rewards` | CTA disabled / clear “come back tomorrow” |
| Remote config change `reward_minutes` 5→3 | New redemptions use new value without app update |
| In-feed native interval | Sponsored card appears every `native_feed_interval` rows; not a glued banner |
| Native ad render fail | Layout stable on Home/History / Search |
| Ad on Summary/Transcript/Ask AI | Assert none (Summary respects `ads_on_summary_enabled=false`) |
| Ad while recording attempt | Impossible (assert no ad APIs in recording UI / Live Activity / Processing) |
| Clock manipulation | Server-authoritative quotas + daily reward counters |

---

## 8. UX / accessibility tests

- Dynamic Type xxxLarge: Recording controls still usable  
- VoiceOver: Record/Stop announcements correct  
- Reduce Motion: no essential info lost  
- Dark Mode snapshots for core screens  
- One-handed reachability on Capture  
- Offline empty/error copy reviewed

Snapshot suite: First-run, Memories empty/full, Capture, Recording, Processing, Soft limit sheet.

---

## 9. Performance budgets

| Metric | Budget |
|---|---|
| Cold start to interactive | < 2.0s on iPhone 12 class |
| Record button to metering | < 300ms after permission |
| Finish → upload start | < 1.0s |
| Memory list scroll | 60fps for 500 rows |
| Search latency local | < 100ms for 1k memories |
| Peak recording CPU | Profile; thermal warnings handled |

---

## 10. Release gates

### P0 (block release)

- [ ] Call interruption recovery
- [ ] Background recording + Live Activity accuracy
- [ ] Audio purge after successful STT
- [ ] Mic deny UX
- [ ] Provider failure leaves recoverable state
- [ ] No ads on Recording/Processing
- [ ] Soft limit doesn’t kill active recording
- [ ] Account delete works

### P1

- [ ] 60 min soak
- [ ] Bluetooth route changes
- [ ] Export
- [ ] Golden accent corpus smoke
- [ ] ATT/ad degradation

### P2

- [ ] Visual snapshots
- [ ] Analytics hygiene
- [ ] Battery regression vs prior build

---

## 11. Test environments

| Env | Purpose |
|---|---|
| Local mocks | Fast UI + state machine |
| Staging providers | Real STT/LLM with test keys |
| Production canary | 5% users; enhanced logging (redacted) |

Never use real user audio in CI. Synthetic + consenting staff corpus only.

---

## 12. Telemetry for quality (privacy-safe)

Events (no transcript bodies):
- `record_started`, `record_interrupted_reason`, `record_finished`
- `upload_failed_code`, `stt_failed_code`, `purge_success`
- `minutes_cap_hit`, `rewarded_completed`
- Durations & file sizes buckets

Alert if `purge_success` rate < 99% of successful STT for 1h.

---

## 13. Manual exploratory charters (each release)

1. **Café field test** — 20 min real conversation, lock phone, walk away, finish.
2. **Rude interruption test** — call + Siri + headphones dance.
3. **Privacy walkthrough** — record → confirm audio gone → export → delete account.
4. **Broke student test** — hit weekly cap → rewarded → record again.
5. **Distrustful user test** — deny ATT, deny tracking, use app fully.

---

## 14. Ownership

| Area | Owner |
|---|---|
| Audio session / interruptions | iOS platform engineer |
| Pipeline / purge | Backend + mobile |
| Provider contracts | Backend |
| Ad/minutes | Mobile + monetisation |
| Privacy acceptance | Privacy & Security Manager sign-off |
| Release gate | Quality Engineering Manager |
