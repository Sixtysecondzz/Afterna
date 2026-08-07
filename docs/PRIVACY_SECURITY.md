# PRIVACY_SECURITY.md
## Afterna — Privacy & Security Policy Spec

**Status:** Product/engineering guidance (not legal advice)  
**Market posture:** Australian-leaning English-speaking launch; privacy-aware globally  
**Last updated:** 2026-08-07

> **Disclaimer:** This document is an internal product and engineering brief. It does **not** claim legal compliance with the Australian Privacy Act, GDPR, CCPA/CPRA, App Store rules, or state/territory recording laws. Engage qualified counsel before launch, especially for recording consent UX copy, privacy policy text, and data-processing agreements with transcription/LLM providers.

---

## 1. Product data model (what we touch)

| Data class | Examples | Sensitivity | Default retention |
|---|---|---|---|
| Raw audio | Mic captures, temporary buffers | Very high | Prefer **delete after successful transcription** |
| Transcripts | Text of conversations | High | User-controlled; soft-delete + hard purge |
| AI memory artefacts | Summaries, entities, “remember this”, embeddings | High | Same as transcripts unless user opts out |
| Account metadata | Email/Sign in with Apple, device IDs | Medium | While account active |
| Usage analytics | Feature events, crash logs | Low–medium | Aggregated / short TTL |
| Ad identifiers | IDFA (only if ATT authorised) | Medium | Per ATT + ad SDK policy |

**Design principle:** The durable product is **searchable memory text**, not a permanent audio archive.

---

## 2. Regulatory relevance (high-level)

### 2.1 Australian Privacy Act 1988 (APPs)

**Relevance:** High if you collect personal information about individuals in Australia (including app users and potentially identifiable third parties captured in recordings/transcripts).

**Product implications (not compliance claims):**
- Publish a clear, plain-English privacy policy (collection, purposes, overseas disclosure, retention, access/correction, complaints).
- Minimise collection: do not keep raw audio longer than needed for transcription quality/retry.
- Be transparent about **overseas processing** (typical STT/LLM APCs are US/EU).
- Support access, correction, and deletion pathways that a real user can complete without emailing support for weeks.
- If you become an APP entity under the Act’s thresholds/definitions, APP obligations apply more formally—confirm with counsel as you scale.

**Third-party conversations:** Transcripts may contain personal information about people who are not the account holder. Treat that as a first-class privacy risk: consent UX, short retention, no social graphing by default, no training on user content by default.

### 2.2 GDPR / UK GDPR

**Relevance:** Medium–high for EU/UK users and any EU-hosted processing; treat as a design target even if AU-first.

**Product implications:**
- Lawful basis candidates (counsel to choose): **consent** for mic/recording and optional features; **contract** for core account service; **legitimate interests** only with documented balancing where appropriate.
- Rights UX: access, deletion, portability (export), restriction, objection to certain processing.
- DPIA recommended before launch (special-category risk if health/voice biometrics appear; avoid building voiceprints unless essential).
- SCCs / transfer mechanisms for non-EEA processors; prefer providers with DPA + clear retention + no-training defaults.
- Soft opt-in for marketing; hard consent for ads tracking (ATT + GDPR consent layering if you expand to EU).

### 2.3 CCPA / CPRA (California)

**Relevance:** Medium if California residents use the app or you “sell”/“share” personal information for cross-context behavioural advertising.

**Product implications:**
- “Do Not Sell or Share My Personal Information” if ad SDKs create share/sale semantics.
- Disclose categories collected/sold/shared; honour deletion and known-agent requests.
- Prefer **contextual / non-tracking ads** + ATT opt-in only after value is proven—reduces CCPA surface and improves privacy brand.

### 2.4 Cross-framework product stance

| Stance | Default |
|---|---|
| Data minimisation | On |
| Audio after transcription | Delete by default |
| Provider model training on user content | Off / contractually prohibited |
| Cross-app tracking ads | Off until ATT + clear value |
| Local-first / E2EE ambition | Phase 2+ (see §6) |
| Privacy as brand | Primary differentiator vs generic “AI note” apps |

---

## 3. Australian recording consent — awareness only (not legal advice)

Australia does **not** have a single uniform “one-party vs two-party” rule for private conversations. Rules are primarily **state/territory surveillance devices legislation**, plus federal telecom interception rules for communications in transit.

### 3.1 High-level public summaries (verify with counsel)

Sources commonly summarise roughly as follows (laws change; exceptions exist; disclosure/use may be separately restricted):

| Jurisdiction (typical summary) | Often characterised as |
|---|---|
| Victoria, Queensland, Northern Territory | Participant (“one-party”) recording more commonly permitted |
| NSW, SA, WA, Tasmania, ACT | Often characterised as requiring broader / all-party consent, with jurisdiction-specific exceptions |

**Important caveats for product:**
- Phone call interception rules differ from in-person listening-device rules.
- Even where recording a conversation you are in may be permitted, **sharing, publishing, or uploading** that recording/transcript can be separately restricted.
- Cross-border / multi-state conversations and workplaces add complexity.
- This is **not** a legal determination. Do not ship jurisdiction-specific legal guarantees in UI.

### 3.2 Product UX requirement (conservative global default)

Because the app may be used across AU states and internationally, adopt a **consent-aware recording flow** as product policy:

1. **Pre-record interstitial** (first record + periodically):  
   “Recording laws vary by location. Only record if you’re allowed to—and tell others when appropriate.”
2. **Optional “announce recording” prompt** before each session (default ON for new users).
3. **In-session visible recording state** (see UX_SPEC): orange system mic indicator + strong in-app “Recording” affordance.
4. **No silent background recording** that starts without an explicit user gesture.
5. **No auto-upload of others’ voices** into social, share, or training pipelines.
6. Store a lightweight **consent acknowledgement timestamp** (product audit), not a fake “legal compliance certificate.”

Suggested `NSMicrophoneUsageDescription` (localise; keep honest):

> “Microphone access lets you capture conversations to create private transcripts and searchable memories. Audio is processed to text, then deleted by default.”

---

## 4. App Store privacy requirements

### 4.1 Privacy Nutrition Labels (App Store Connect)

Declare **actual** collection by the app **and** third-party SDKs (STT, LLM, analytics, ads, crash). Relevant categories for this product typically include:

- **Audio Data** (User Content) — if audio leaves the device or is stored, even briefly
- **Other User Content** — free-form transcripts / notes
- **Contact Info** — if account email collected
- **Identifiers** — User ID, Device ID; IDFA only if tracking
- **Usage Data / Diagnostics** — analytics, crashes
- **Product Interaction** — feature usage

For each: purpose (App Functionality, Analytics, Third-Party Advertising, etc.), linked-to-identity vs not, used for tracking vs not.

**Consistency rule:** Labels ↔ Privacy Manifests ↔ privacy policy ↔ runtime behaviour. Mismatches are a common rejection/enforcement cause.

### 4.2 Privacy Manifests & Required Reason APIs

- Ship `PrivacyInfo.xcprivacy` for the app; prefer SDKs that ship manifests.
- Justify Required Reason APIs if used (UserDefaults, file timestamps, etc.).
- Prefer privacy-preserving analytics (e.g. no IDFA; aggregate events).

### 4.3 App Tracking Transparency (ATT)

- Required before accessing IDFA / tracking across apps & sites.
- Do **not** ask ATT on first launch. Ask only after the user understands value, and only if you enable tracking ads.
- Prefer non-tracking ad units first (see UNIT_ECONOMICS.md).

### 4.4 Microphone & recording UX (Apple expectations)

- `NSMicrophoneUsageDescription` required; meaningful string.
- Request mic **just-in-time** at first record tap, after a short educational screen.
- While recording: system orange mic indicator; **also** clear in-app recording UI.
- Background recording only with `audio` background mode, active session, and user-initiated start; show Live Activity / prominent ongoing state.
- Denied mic: graceful empty state with Settings deep link—never crash or silent-fail loops.

---

## 5. Consent warnings & user education (copy principles)

| Moment | Goal | Tone |
|---|---|---|
| First-run privacy card | Set trust; audio→text→delete default | Calm, specific |
| Pre-mic system prompt context | Explain why mic | One sentence + benefit |
| Before multi-party capture | Consent awareness | Non-legalistic, responsible |
| Export / share | Warn that transcripts may include others | Clear |
| Ads / ATT | Separate from mic consent | Never bundle permissions |
| Provider outage | No silent retry forever with retained audio | Transparent |

**Do not claim:** “100% private,” “military-grade,” “GDPR compliant,” “legal to record anywhere.”

**Do claim (if true):** “Audio deleted after transcription by default,” “You can export/delete your memories,” “We don’t sell your transcripts.”

---

## 6. Encryption & security controls

### 6.1 Transport & at rest

| Layer | Requirement |
|---|---|
| TLS | TLS 1.2+ for all network; certificate pinning optional Phase 2 |
| Device storage | iOS Data Protection (Complete / Protected Unless Open) for audio buffers & DB |
| Keychain | Tokens, refresh keys only in Keychain |
| Server DB | Encryption at rest (provider default AES-256+); app-level field encryption for transcripts Phase 2 |
| Backups | Exclude ephemeral audio from iCloud backups; user opt-in for encrypted memory sync later |

### 6.2 Architecture preferences (security-aligned)

1. **Ephemeral audio pipeline:** record → encrypt-at-rest on device → upload over TLS → transcribe → confirm → **server + device audio purge**.
2. **Retry window:** keep audio only for a bounded retry TTL (e.g. 24h) if transcription fails; then purge or ask user.
3. **Least privilege APIs:** STT provider gets audio; LLM gets transcript chunks—not continuous raw mic stream unless streaming STT is chosen.
4. **No training clause** in vendor DPAs; prefer zero-retention STT where available.
5. **Auth:** Sign in with Apple first; optional passcode/Face ID lock for app open.
6. **Threat model docs:** account takeover, device theft, malicious insider at vendor, subpoena—document retention limits as risk reduction.

### 6.3 Phase roadmap

| Phase | Security posture |
|---|---|
| MVP | TLS + Data Protection + delete-audio-after-STT + account delete/export |
| 1.1 | App lock, export ZIP, purge jobs with audit logs |
| 2.0 | Client-side encryption for transcripts (provider processes under short-lived keys or on-device STT where quality allows) |

---

## 7. Deletion, export, and user control

### 7.1 User-facing controls

- Delete single memory / conversation
- Delete all data
- Delete account (cascading purge)
- Export: JSON + Markdown (+ optional CSV entities); include transcripts, summaries, timestamps; **exclude audio by default** (audio usually already gone)
- Pause AI processing / “local drafts only” mode if offline capture exists

### 7.2 Operational SLAs (product targets)

| Action | Target |
|---|---|
| Soft delete in app | Immediate |
| Hard delete from primary DB | ≤ 30 days (aim ≤ 72 hours) |
| Object storage / audio | ≤ 24 hours after success; failed jobs ≤ retry TTL then purge |
| Vendor copies | Contractual deletion; verify via DPA + periodic vendor review |
| Export generation | ≤ 24 hours; preferably instant for <N MB |

### 7.3 “Right to be forgotten” practicalities

Embeddings, search indexes, caches, logs, and backups must be in the purge design—not only the UI row. Log redaction for support tooling.

---

## 8. Audio retention policy (default)

**Policy name:** *Transcript-first, audio-ephemeral*

1. **Default:** Delete raw audio on device and server after transcription succeeds and transcript is durable.
2. **User override (optional later):** “Keep audio for 7 days” for accuracy disputes—off by default; clear storage cost & privacy cost.
3. **Failed transcription:** Retain encrypted audio up to **24 hours** with visible “Retry / Delete” UI; auto-purge after TTL.
4. **No audio in marketing, model eval, or human review** without explicit opt-in.
5. **Caching:** No CDN caching of audio objects; short-lived signed URLs only.
6. **Support access:** Support cannot download user audio by default (should rarely exist).

---

## 9. Provider data retention risks

| Risk | Why it matters | Mitigations |
|---|---|---|
| STT vendor retains audio | Shadow copy outside your purge | Zero-retention / short-retention plans; DPA; prefer providers with explicit delete APIs |
| LLM vendor trains on prompts | Memories enter foundation models | Enterprise/no-train tiers; strip PII where feasible; minimise prompt size |
| Subprocessors | Audio routed through unknown regions | Vendor subprocessors list; region pinning if offered |
| Logs & traces | Transcripts in error logs | Structured logging with redaction; disable body logging in prod |
| Ads SDKs | Broad device signal collection | Delay ads; choose privacy-forward mediation; ATT gating |
| Analytics | Re-identifiable free text | Never send raw transcripts to analytics |
| Employee access | Insider risk | Role-based access, audit logs, no standing access to content |
| Legal compulsion | Warrants/subpoenas | Minimisation + short retention reduces blast radius; transparency report later |

**Vendor selection checklist:** DPA, SOC2/ISO, retention controls, no-train default, deletion API, AU/EU residency options, subprocessors, incident SLA, App Store privacy questionnaire support.

---

## 10. Security engineering requirements (MVP checklist)

- [ ] Mic permission just-in-time + denial UX
- [ ] Consent awareness screen (non-legal)
- [ ] Recording indicator (system + in-app + Live Activity if background)
- [ ] Encrypted ephemeral audio; purge after STT
- [ ] Accurate Privacy Nutrition Labels + manifests
- [ ] Privacy policy + in-app “Data & Privacy” settings
- [ ] Export + delete account
- [ ] Secrets not in client; short-lived upload tokens
- [ ] Rate limits & abuse controls on transcription minutes
- [ ] Dependency scanning / Xcode privacy report before submit
- [ ] Incident response runbook (audio leak = Sev-1)

---

## 11. Open questions for counsel / DPO

1. Whether APP entity status applies at launch scale.
2. Lawful bases and consent wording for multi-party conversations.
3. Whether voice data could be treated as biometric in any feature design.
4. Cross-border transfer mechanism for primary STT/LLM vendors.
5. Ad “sale/share” analysis under CPRA if mediation is introduced.
6. Children’s use: age gate / 17+ App Store rating posture.

---

## 12. Source anchors used for this brief

- Apple — [App Privacy Details](https://developer.apple.com/app-store/app-privacy-details/)
- Apple — Microphone usage description / privacy-sensitive data guidance
- Public AU commentary on state/territory listening-device consent differences (e.g. legal firm explainers)—**verify before relying**
