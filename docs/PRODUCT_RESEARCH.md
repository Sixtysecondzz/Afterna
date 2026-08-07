# Product Research Brief — Afterna (iPhone-first conversation memory)

**Document status:** Competitive research brief for PRODUCT_RESEARCH.md  
**Research date:** August 7, 2026  
**Product thesis:** An iPhone-native app that turns real-world conversations (meetings, interviews, lectures, inspections, appointments) into durable, searchable memory—inspired by Granola’s usefulness, but broader than desktop video meetings.

---

## 1. Executive summary

The AI meeting-notes category is crowded and **desktop/bot-centric**. Leaders (Otter, Fireflies, Fathom, Read, Granola, Zoom/Teams natives) optimize for scheduled video calls. Hardware (Plaud) and always-on wearables (Limitless—acquired/sunset for new buyers) address in-person capture but add device cost, subscriptions, and privacy optics.

**The open wedge:** professionals who live on iPhone and need trustworthy memory for **in-person and phone-first conversations**—where meeting bots don’t join, system-audio capture is blocked on iOS, Apple’s built-ins stop at transcript/summary, and Granola’s mobile app is a secondary recorder/viewer.

**Initial positioning (one wedge):**  
**Field-heavy solo professionals on iPhone** (consultants, inspectors, clinicians in private practice, journalists, real-estate agents, tutors) who need “record → structure → recall → follow-up” without a bot, without buying a pin, and without a Mac-first workflow.

---

## 2. Competitor matrix

Pricing shown in USD. Prefer vendor pages; secondary sources noted where official pages are incomplete or region-variable.

| Competitor | Primary mode | Capture model | Platforms | Consumer vs business | Entry paid price (typical) | Free tier | Privacy / consent posture | Mobile-first strength | Key weakness |
|---|---|---|---|---|---|---|---|---|---|
| **Granola** | AI-enhanced meeting notes | Bot-free device audio (desktop); mic on mobile | Mac, Windows, iOS (+ Android in some reviews) | Prosumer → team | **$14/user/mo** Business; Enterprise **$35+** | Free Basic (history capped ~30 days) | Training opt-out; bot-free reduces participant friction; SOC2 claimed; HIPAA unclear | Moderate (iOS good for in-person; weak for virtual calls on phone) | Desktop-first; iOS can’t capture Zoom/Meet/Teams system audio; no durable audio replay (audio often deleted post-transcript) |
| **Otter** | Meeting notetaker + chat | Calendar bot + in-app recording | Web, iOS, Android | SMB → enterprise | **$16.99/mo** Pro monthly; **$8.33–8.49/user/mo** annual; Business **~$20–30** | Free: **300 min/mo**, 30 min/conversation | Class-action consent/training litigation (2025–2026); bot fatigue | Strong apps, but experience is bot/calendar-centric | Minute shrinkflation, billing complaints, consent risk, accent/overlap accuracy issues |
| **Fireflies** | Conversation intelligence | Bot (+ Chrome bot-free option) | Web, desktop, iOS/Android | SMB → enterprise | **$10/seat/mo** Pro annual (**$18** monthly); Business **$19** annual (**$29** monthly); Enterprise **$39** annual | Free: unlimited transcription, **400 min** storage/team | SOC2/GDPR; HIPAA on Enterprise; BIPA suits reported | Secondary to bot workflow | Bot optics; AI credits for advanced features; storage gates free/Pro |
| **Fathom** | Free-first call notetaker | Bot; bot-free beta (Mac) | Desktop-focused; Zoom/Meet/Teams | Individual → sales teams | Free forever core; Premium **$16** annual / **$20** monthly; Team **$15** / **$19**; Business **$25** / **$34** | Very generous unlimited recordings/transcripts | Relatively trusted; CRM/coaching upsell | Weak for pure phone/in-person daily carry | Video-meeting native; advanced AI capped on free |
| **Plaud** | Hardware + app | Wearable/card recorder → cloud AI | iOS/Android + devices | Consumer pro → teams | Device **~$159–189**; Pro **$17.99/mo** or **$99.99/yr** (~$8.33/mo); Unlimited **$29.99/mo** or **$239.99/yr** (~$19.99–20/mo) | Starter **300 min/mo** with device | Claims ISO/SOC2/GDPR/HIPAA; cloud processing | Strong for in-person; needs hardware | Hardware + subscription TCO; minute caps; cloud dependency |
| **Limitless** | Always-on pendant memory | Wearable continuous capture | Pendant + app (legacy) | Consumer / power user | **No longer sold** (Meta acq. Dec 2025); existing users free Unlimited through ~2026 | N/A for new users | High privacy scrutiny; consent required; regional shutdowns (EU/UK etc.) | Was best ambient mobile story | Acquisition cliff; regulatory/regional risk; category trust damage |
| **Notion AI** | Workspace + meeting notes | In-app mic/system audio (desktop best) | Web, desktop, mobile | Knowledge-work teams | Full AI Meeting Notes on **Business ~$20/member/mo** annual | Limited AI trial on Free/Plus | Sub-processors for transcription; Enterprise ZDR options | Mobile can record mic; not a conversation OS | Gated to Business; manual `/meet` trigger; weak for unplanned field capture |
| **Apple Voice Memos** | System recorder | On-device mic | iOS/macOS | Consumer | Free (device) | Free | Strong privacy brand; on-device transcription | Excellent capture UX | Transcript ≠ structured memory; weak cross-conversation search/actions |
| **Apple Notes (+ Apple Intelligence)** | Notes + audio | Mic; call recordings → Notes | iOS | Consumer | Free (device / Apple Intelligence hardware) | Free | On-device AI summaries where available; call recording announces to parties | Best “already installed” path | Generic summaries; no domain templates, CRM, recall graph, or retention product |
| **Google Recorder** | On-device transcript | Mic; on-device ASR | **Pixel-only** | Consumer | Free | Free | Strong on-device privacy story | Best Android native analog | Not on iPhone; limited collaboration/export workflow |
| **Microsoft Teams transcription** | Platform native | Meeting recording/transcript | Teams ecosystem | Enterprise | Base M365/Teams; **Teams Premium ~$10/user/mo** for Intelligent Recap | Depends on license | Enterprise controls; E2EE can disable AI | Mobile exists inside Teams | Locked to Teams meetings; not a general life/field memory product |
| **Zoom AI Companion** | Platform native | Zoom meetings + expanding My Notes | Zoom Workplace | Prosumer → enterprise | Included with paid Workplace (Pro ~**$14–16/user/mo** band); standalone Companion ~**$10/mo**; ZoomMate from ~**$20** | Limited Basic AI | Enterprise admin controls | Improving; still Zoom-gravity | Weak outside Zoom; not a dedicated conversation memory system |
| **Krisp** | Noise cancel + notetaker | Bot-free desktop audio (+ mobile) | Desktop + mobile | Individual → enterprise | Core **$8/mo** annual (**$16** monthly); Advanced **$15** / **$30** | 7-day trial (no durable free meeting plan) | SOC2/GDPR; HIPAA enterprise; claims no model training | Secondary; noise cancel is the brand | Notes quality trails specialists; calendar-centric onboarding |
| **Read AI** | Meeting + engagement metrics | Bot / meeting join | Desktop + mobile | Teams / managers | Pro **$19.75/mo** (**$15** annual); Enterprise **$29.75** (**$22.50** annual) | Free: **5 meetings/mo** | Enterprise security tiers | Present but not phone-first | Meeting-platform gravity; coaching analytics over field memory |

### Sources (pricing & product claims)

- Granola pricing: https://www.granola.ai/pricing  
- Otter pricing: https://otter.ai/pricing  
- Fireflies pricing: https://fireflies.ai/pricing  
- Fathom pricing: https://www.fathom.ai/pricing  
- Plaud plan pricing: https://www.plaud.ai/pages/plaud-ai-plan-pricing  
- Limitless status: https://www.limitless.ai/  
- Notion AI Meeting Notes: https://www.notion.com/help/ai-meeting-notes  
- Krisp pricing: https://krisp.ai/pricing/  
- Read AI pricing: https://www.read.ai/plans-pricing  
- Teams Premium: https://www.microsoft.com/en-us/microsoft-teams/premium  
- Zoom AI Companion announcement: https://news.zoom.com/zoom-launches-ai-companion-3-0/  
- Apple Voice Memos transcription: https://support.apple.com/guide/iphone/view-a-transcription-iph00953a982/ios  
- Apple Notes audio/transcription: https://support.apple.com/guide/iphone/record-and-transcribe-audio-iphbe11247b5/ios  
- Google Recorder (Pixel): https://support.google.com/pixelphone/answer/9516618  
- Otter consent litigation coverage: https://www.npr.org/2025/08/15/g-s1-83087/otter-ai-transcription-class-action-lawsuit  

---

## 3. What users value (cross-competitor)

1. **Trustworthy capture without social friction** — bot-free or clearly consented recording; no surprise “Notetaker joined.”  
2. **Useful notes, not raw transcripts** — decisions, owners, next steps, domain-structured summaries (Granola/Plaud templates win hearts).  
3. **Recall across time** — “What did we agree last month?” / cross-meeting chat (Granola Chat, Otter/Fireflies Ask).  
4. **Speed to value** — record → notes in minutes; minimal setup.  
5. **Works where work actually happens** — video calls *and* in-person; phone calls; hallway; site visits.  
6. **Export into existing systems** — Notion, Slack, CRM, email follow-ups.  
7. **Privacy control** — retention settings, delete/export, no training on my data (increasingly table stakes).  
8. **Predictable pricing** — resentment when minutes are cut (Otter) or advanced AI is credit-metered (Fireflies).

---

## 4. Common complaints & UX pain points

| Theme | Evidence pattern | Implication for us |
|---|---|---|
| **Bot fatigue / consent** | Otter class actions; Fireflies BIPA suits; Reddit horror stories of auto-join | Prefer user-initiated, on-device or bot-free; built-in consent UX |
| **Minute / credit traps** | Otter Pro cut 6,000→1,200 min; Fireflies AI credits | Transparent limits; avoid bait-and-switch |
| **Billing & cancellation friction** | Otter BBB/Trustpilot patterns | Apple IAP clarity; easy cancel; honest renewals |
| **Accuracy cliffs** | Accents, overlap, jargon, noisy rooms | Domain vocabulary; speaker labeling; offline/noisy-field modes |
| **Desktop gravity** | Granola best on Mac; Fathom/Fireflies video-call native | iPhone-first workflows for non-laptop moments |
| **iOS sandbox** | No app system-audio from Zoom on iPhone | Own the in-person + Phone-call + mic-on-speakerphone niches |
| **Hardware TCO** | Plaud $159+ + $100–240/yr AI | Software-only path that feels as “set and forget” as a pin |
| **Acquisition / sunset risk** | Limitless → Meta; regional kills | Independence + data export as trust features |
| **Apple “good enough”** | Voice Memos/Notes/call recording free | Must beat Apple on structure, memory, actions—not raw transcription |

---

## 5. Target audiences

### Primary wedge (recommended)

**iPhone-carrying field & appointment professionals** who have many **non-Zoom conversations**:

- Independent consultants / coaches  
- Home inspectors, contractors, insurance adjusters  
- Real-estate agents  
- Journalists / podcasters (interview workflow)  
- Private-practice clinicians / therapists (privacy-sensitive; later HIPAA)  
- Tutors, educators, lecture note-takers  
- Recruiters doing in-person / phone screens  

**Jobs to be done**

1. Capture what was said without typing.  
2. Leave with structured notes + action items.  
3. Find a detail weeks later.  
4. Send a clean follow-up in one tap.

### Secondary (post-wedge)

- Startup founders who already love Granola on Mac but lose context on the go  
- Sales ICs who do mix of Zoom + site visits  
- Small professional firms (2–10) sharing a client conversation library  

### Explicit non-goals for v1

- Replacing Gong/Fireflies conversation intelligence for large sales orgs  
- Always-on ambient wearables  
- Enterprise SSO-first GTM  

---

## 6. Top user problems (ranked)

1. **Memory decay after real conversations** — details vanish after inspections, client walks, interviews.  
2. **Bot tools don’t cover the phone in your pocket** — in-person and cellular calls are underserved.  
3. **Consent anxiety** — fear of recording others / legal risk / awkward bots.  
4. **Transcript dump without structure** — Apple/Google give text; users still rewrite.  
5. **Fragmentation** — notes in Voice Memos, Notes, email, CRM, sticky notes.  
6. **Hard recall** — “Where did they say the warranty expires?”  
7. **Follow-up drag** — knowing what to send next is still manual.  
8. **Privacy distrust of cloud notetakers** after lawsuits and wearable backlash.

---

## 7. Feature gaps in the market

| Gap | Who comes closest | Still missing |
|---|---|---|
| iPhone-native conversation OS (not a meeting bot viewer) | Granola iOS, Plaud app, Apple Notes | End-to-end memory product with templates + recall + actions |
| Structured templates for non-meeting contexts | Plaud (10k+ templates) | Lightweight, beautiful Apple-native UX without hardware |
| Consent-first capture UX | Apple call recording announcement | General in-person consent flows + audit trail |
| Cross-conversation personal memory (consumer-grade) | Limitless (dying), Granola Chat | Portable, private, phone-first “ask my life/work” |
| Offline / poor-connectivity field capture | Google Recorder (Pixel) | iPhone offline record → later enhance |
| Actionability (tasks, follow-up drafts, calendar) | Zoom Companion, Otter workflows | Tight iOS Shortcuts / Reminders / Mail integration |
| Speaker + place + client entity linking | CRM bots (Fireflies/Fathom Business) | Lightweight personal CRM for solos without Salesforce |
| Trust differentiation post-lawsuit | Krisp “no training,” Granola bot-free | Clear defaults: no training, retention sliders, local-first options |

---

## 8. Differentiation opportunities (mobile-first)

1. **Own the “phone on the table” moment** — one-thumb start, Lock Screen / Dynamic Island / Live Activity, haptic stop, instant structured note.  
2. **Context packs** — Inspection, Interview, Appointment, Lecture, Sales Visit—not generic “meeting.”  
3. **Consent as product** — pre-session spoken/prompted notice; shareable consent receipt; jurisdiction hints.  
4. **Memory, not transcript** — entities (people, places, commitments), timeline, “ask across sessions.”  
5. **Apple-native craft** — Share Sheet, Shortcuts, Widgets, Focus filters, on-device where possible; iCloud or private cloud choice.  
6. **Beat hardware on friction** — no $159 pin; phone you already have.  
7. **Beat Apple on usefulness** — Writing Tools summary is not a follow-up email, punch-list, or client brief.  
8. **Bot-optional later** — if virtual meetings matter, add calendar bot *after* mobile wedge is solid—or partner—not as identity.

---

## 9. Onboarding, retention, pricing lessons

### Onboarding (what works)

- Time-to-first-note &lt; 60 seconds (record something immediately).  
- Template picker tied to persona (“I’m recording an inspection”).  
- Show the *structured* output before pitching subscription.  
- Avoid mandatory calendar OAuth on day one (Krisp/Fireflies-style friction).

### Retention drivers

- Habit loop: capture → review card → one-tap follow-up → archive.  
- Weekly “memory digest.”  
- Search that actually finds commitments.  
- Streak of saved hours (subtle, not gamified junk).

### Churn drivers to avoid

- Surprise minute exhaustion.  
- Notes trapped without export.  
- Privacy scare headlines.  
- Desktop-only features that make mobile feel like a thin client.

### Pricing recommendation (hypothesis)

| Tier | Price | Intent |
|---|---|---|
| Free | 3–5 sessions/mo or ~60–90 min | Prove quality |
| Pro | **$12–15/mo** or **$99–119/yr** | Unlimited personal memory; templates; ask-across |
| Pro+ | **$20–25/mo** | Longer retention, priority models, team share later |

Position under Plaud Unlimited TCO and near Granola Business ($14), with clearer consumer packaging than seat-based SaaS.

---

## 10. Transcription & technical limitations (market reality)

- **iOS cannot capture other apps’ system audio** → virtual meetings on iPhone require bot, screen-share hacks, or “speakerphone into mic” (quality loss).  
- **Overlapping speech & noise** degrade all vendors; field work needs enhancement + user correction UX.  
- **Speaker diarization** often generic (“Speaker 1”); renaming must be easy.  
- **Domain jargon** needs custom vocabulary.  
- **On-device vs cloud tradeoff:** privacy/latency vs model quality; hybrid (on-device draft, cloud enhance on Wi‑Fi) is a product advantage.  
- **Call recording:** Apple owns native Phone/FaceTime path with participant announcement; third parties are constrained—integrate with Notes/call artifacts rather than fight the OS.

---

## 11. Privacy concerns (category-level)

- Unauthorized bot recording & model training (Otter litigation).  
- Biometric/voiceprint claims (BIPA cases).  
- Always-on wearables social taboo (Limitless).  
- Cloud retention of sensitive client/medical/legal audio.  
- Cross-border processing & regional availability cliffs.

**Product principles**

1. Default: **do not train** on user audio/transcripts.  
2. User-controlled retention (e.g., 7 / 30 / 90 / forever).  
3. Easy export + hard delete.  
4. Explicit consent tooling before record.  
5. Clear in-product disclosure of processors.  
6. Roadmap: on-device transcription option; HIPAA only if wedge expands to clinics.

---

## 12. MVP recommendations

**Wedge:** Field & appointment professionals on iPhone.

### Must-have

1. One-tap record with Live Activity controls.  
2. High-quality transcript + **structured note** (summary, decisions, action items, open questions).  
3. **5–7 context templates** (Inspection, Client appointment, Interview, Lecture, Coaching session, Site visit, General).  
4. Library with full-text search + filters (person, tag, date, template).  
5. Ask-across-notes (personal RAG) for paid tier.  
6. Share: copy, PDF/Markdown, Mail draft follow-up.  
7. Consent prompt + optional spoken notice.  
8. Export/delete; no-training default.  
9. Apple Design: offline-capable capture; enhance when online.

### Explicitly cut from MVP

- Meeting bots / calendar auto-join  
- Wearable hardware  
- Team admin / SSO  
- CRM two-way sync  
- Android  
- Always-on ambient listening  

### Success metrics

- D1: ≥1 completed session with saved structured note  
- W1: ≥3 sessions  
- Paid conversion after value moment (first “ask” or first follow-up send)  
- Retention: 4-week retention among users with ≥5 sessions  

---

## 13. Post-MVP roadmap

**Phase 2 — Memory depth**

- People/org entities; link sessions to clients  
- Commitments tracker + Reminders/Calendar integration  
- Custom templates; industry packs  
- Widgets / Shortcuts / Action Button  

**Phase 3 — Collaboration**

- Secure share links; client-ready reports  
- Light team workspaces (shared client folders)  
- Notion/Slack/Zapier  

**Phase 4 — Capture expansion**

- Optional meeting bot for Zoom/Meet/Teams (secondary)  
- Import Apple call-recording notes / Voice Memos  
- Watch / Lock Screen ultra-capture  

**Phase 5 — Trust & verticals**

- Stronger on-device path  
- HIPAA/BAA only if GTM proves clinical demand  
- Org retention policies  

---

## 14. Product risks

| Risk | Severity | Mitigation |
|---|---|---|
| Apple Notes/Voice Memos “good enough” | High | Win on structure, recall, templates, follow-ups |
| Granola expands iOS aggressively | High | Out-execute on field templates + consent + memory UX |
| Plaud owns in-person with hardware | Medium | Zero-hardware convenience; comparable AI quality |
| Consent/legal landmines | High | Consent UX; jurisdiction education; no stealth recording |
| Transcription cost margins | High | Hybrid models; fair limits; annual plans |
| Category stigma from lawsuits/wearables | Medium | Privacy-forward brand; bot-free; local options |
| Meta/Big Tech commoditization | Medium | Niche workflow depth & craft |
| Scope creep into Gong-land | Medium | Hold the wedge; say no to enterprise CI early |

---

## 15. Final positioning recommendation

### Pick ONE initial wedge

**Wedge audience:** iPhone-first **field & appointment professionals** (inspectors, agents, consultants, interviewers) who need conversation memory for **in-person and phone-era work**—not another Zoom bot.

### Positioning statement

> **Your iPhone, as a private chief of staff for real conversations.**  
> Capture what was said in the room or on the call, turn it into clear notes and next steps, and find any commitment later—without a meeting bot, without a wearable, without a laptop.

### Why this wedge wins

- Underserved vs Otter/Fireflies/Fathom (video-meeting gravity).  
- Clearer than “everyone who has meetings.”  
- Differentiated from Granola (Mac/desktop note enhancement) and Plaud (hardware).  
- Defensible against Apple by being a **memory + action** product, not a recorder.  
- Natural expansion later into light teams and optional virtual-meeting capture.

### Category name (working)

**AI Conversation Memory** (not “AI meeting notetaker”).

---

## 16. App name directions (not final names)

Premium, Apple-native feel—short, calm, memorable:

1. **Ledger** direction — quiet accountability for what was said (*Ledger*, *Said Ledger*).  
2. **Harbor** direction — safe place conversations land (*Harbor*, *Fair Harbor*).  
3. **Quill** direction — crafted notes, human + AI (*Quill*, *Fieldquill*).  
4. **Afterglow** direction — the clarity after the conversation (*Afterglow*, *Afterword*).  
5. **Kinetic/Clarity** direction — motion-to-memory, crisp recall (*Stillpoint*, *Clarity Desk*—prefer single tokens like *Stillpoint* / *Clarion*).

Evaluation criteria: App Store distinctiveness, trademark clearance, .app/.com availability, no “AI” suffix, speaks to memory/trust more than transcription commodity.

---

## 17. Appendix: competitive role map

```
Desktop video meetings ────────── Otter, Fireflies, Fathom, Read, Zoom, Teams
Bot-free desktop notes ────────── Granola, Krisp, Notion AI
Hardware in-person ────────────── Plaud (Limitless legacy)
OS free utilities ─────────────── Apple Notes/Voice Memos, Google Recorder
OPEN SPACE ────────────────────── iPhone-native conversation memory for field/appointments
```

---

*End of brief. All prices and legal statuses are as researched on August 7, 2026, and should be re-verified before investor or store listing use.*
