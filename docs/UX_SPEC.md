# UX_SPEC.md
## Afterna — UX Specification

**Quality bar:** Apple Notes / Journal / Things 3 / Bear / Linear / Granola  
**Platform:** iPhone-first (iOS 17+ target)  
**Tone:** Calm, precise, private. Not “AI chatbot chrome.”

---

## 1. Product north star

Help someone **capture a real conversation once**, then **find what mattered later**—without feeling surveilled, gimmicky, or overwhelmed.

**One sentence promise:**  
*Private conversation memory that turns talk into something you can trust and search.*

**Brand test:** If you remove the nav, the first screen still feels like *this* product—quiet paper/ink atmosphere, one clear capture control, memory as the hero—not a generic AI dashboard.

---

## 2. Design principles

1. **Capture is sacred** — Recording UX is faster and clearer than browsing.
2. **Memory over feed** — Home is a living memory surface, not a chat log of an assistant.
3. **Privacy visible** — “Audio deleted after transcription” is a product feature, not a footer.
4. **One job per screen** — No stats strips, promo chips, or feature galleries in the hero.
5. **Apple-native motion** — Purposeful transitions; no bounce-spam or generative glitter.
6. **Soft monetisation** — Ads never interrupt an active recording; rewards feel optional and fair.
7. **Australian-leaning English** — Clear, warm, unpretentious (not US startup hype, not legalese).

---

## 3. Information architecture

```
Tab bar (3)
├── Memories          # Home / library
├── Capture           # Dedicated record mode (centre emphasis)
└── Search            # Global search + filters

Modal / push stacks
├── Memory Detail
├── Recording Session (full-screen)
├── Processing / Transcript Review
├── Settings → Data & Privacy / Credits & Minutes / Appearance
├── First-run Privacy & Consent
└── Recording Credits sheet (rewarded ad)
```

Optional later: Collections/Notebooks, People, Places—**not MVP**.

---

## 4. Core screens

### 4.1 First-run (3 beats max)

1. **Brand + promise** — Product name large; one line; atmospheric full-bleed backdrop (paper grain / soft coastal dusk light—not purple AI nebula).
2. **How it works** — Record → transcript → searchable memory; audio deleted by default.
3. **Consent awareness** — Recording laws vary; tell others when appropriate; Continue.

Mic permission is **not** requested here—wait for first Capture.

### 4.2 Memories (Home)

**Purpose:** Browse and reopen past conversations.

- Large title: product name or “Memories”
- Primary list: date groupings (Today / Yesterday / This Week) with title + 1-line excerpt
- Subtle left accent or timestamp typography—not cards-in-cards
- Empty state: single illustration-quality still (notebook + mic metaphor), one CTA “Capture a conversation”
- Pull to refresh only if sync exists; otherwise omit
- No banners above the fold on day one

### 4.3 Capture (centre tab)

**Purpose:** Start recording with zero ambiguity.

- Near-full-bleed calm surface
- Giant record control (not a floating AI orb)
- Secondary: “Voice note” vs “Conversation” if needed—default Conversation
- Privacy line under control: “Audio is deleted after transcription”
- Free minutes + credit balance as quiet text, not a progress ring of doom
- Tap Record → brief education if first time → system mic prompt → Recording Session

### 4.4 Recording Session (full-screen)

**Purpose:** Make recording state unmistakable and interruption-safe.

**Visible always:**
- Pulsing but restrained record indicator + elapsed time
- Waveform or level meter (thin, Notes-like—not equalizer club visualiser)
- Pause / Resume / Finish
- Lock screen / Live Activity parity: “Recording · 12:04”

**Behaviour:**
- Screen can dim; recording continues
- Phone call / Siri interruption → clear paused state + “Tap to resume”
- Finish → Processing screen (not chat)
- Accidental leave: confirm “Stop and save?” 

**Never during recording:** interstitial ads, ATT prompts, rating prompts, upsell sheets.

### 4.5 Processing / Transcript Review

**Purpose:** Trust the pipeline.

States: Uploading → Transcribing → Summarising → Ready  
Each state has plain language + cancel where safe.

Review screen:
- Editable title (auto from summary)
- Transcript with light structure (paragraphs; speaker labels if diarisation on)
- Summary block above transcript (short)
- Actions: Save · Retry · Delete audio now · Delete all
- Show purge confirmation: “Audio removed”

### 4.6 Memory Detail

**Purpose:** Read and recall.

- Title, date/time, duration
- Summary
- Transcript
- “Ask this memory” (optional MVP+: constrained Q&A on *this* item only—not a general chatbot home)
- Share sheet exports text; warn if others’ voices may be included
- Delete

### 4.7 Search

**Purpose:** Find a phrase, person mention, or theme.

- Instant search field
- Recent searches
- Results: title + highlighted snippet + date
- Empty: helpful examples (“try ‘invoice’, ‘flight’, ‘Mum said’”)

### 4.8 Settings

Groups:
- **Account** — Sign in with Apple, App Lock (Face ID)
- **Capture** — Announce reminder toggle, keep-audio override (off)
- **Credits & Minutes** — free pool remaining, credit balance, earn credit, daily reward remaining
- **Data & Privacy** — policy, export, delete account, providers list (human-readable)
- **Appearance** — Light / Dark / System; text size respects Dynamic Type
- **About**

### 4.9 Recording Credits / Rewarded Ad sheet

- Soft limit reached: sheet, not hard wall mid-recording if already started
- Copy pattern:
  - “You've used your free recording time.”
  - “Watch an ad to earn 1 Recording Credit”
  - Primary CTA: **Watch Ad · +1 Credit**
- Do **not** surface dollar economics or “+N minutes” as the hero (minutes-per-credit is internal / remote `reward_minutes`)
- Show remaining daily reward allowance quietly (e.g. “3 of 6 available today”)
- Remaining free daily/weekly allotment clarity
- Never shame; never fake urgency timers

---

## 5. Recording state UX (detail)

| State | UI | Haptics | System |
|---|---|---|---|
| Idle | Record CTA | Light on tap | — |
| Requesting mic | Inline explanation | — | System dialog |
| Mic denied | Settings CTA | Warning | — |
| Recording | Red/ink accent time + meter | Soft heartbeat optional every 60s (off by default) | Orange mic dot |
| Paused | Amber pause badge | — | — |
| Interrupted | Banner + Resume | Rigid | Handle AVAudioSession |
| Finishing | Disable double-finish | Success | — |
| Background | Live Activity | — | audio background mode |
| Failed upload | Retry / Keep offline / Delete | Error | Bounded audio TTL |

**Accessibility:** VoiceOver labels for all controls; Reduce Motion disables waveform pulse; high-contrast mode supported.

---

## 6. Motion language (ship 2–3 intentional motions)

1. **Capture bloom** — Record button expands into full-screen session (matched geometry).
2. **Ink settle** — New memory row fades/slides into Memories with paper-like ease.
3. **Purge breath** — After audio delete, a brief status line settles to “Audio removed” (no confetti).

Avoid: parallax overload, shimmer skeletons forever, generative particle backgrounds.

---

## 7. Content & microcopy (AU-leaning)

- Prefer “memories”, “conversations”, “transcript” over “synergies”, “copilot”, “agents”
- Errors: “Couldn’t transcribe this one. Retry or delete the audio.”
- Privacy: “We keep the text you need. We don’t keep the recording by default.”
- Ads: “Earn more minutes” not “Go Premium to unlock your brain”

---

## 8. Monetisation UX constraints

1. **No ads** on Recording, Live Activity, Processing, Transcript, Ask AI, Settings.
2. **Conversation Summary:** preferably none at launch (`ads_on_summary_enabled=false`).
3. **Home/History:** in-feed **sponsored native card** every 4–6 conversation rows (`native_feed_interval`)—part of the feed, not a glued banner.
4. **Search results:** occasional in-feed native (same or sparser interval).
5. Rewarded ads only from Credits sheet when out of free minutes/credits.
6. Remote config drives all placement/interval/caps.
4. Soft limit: finish in-progress recording even if minutes hit zero mid-way; apply limit at next start.
5. Subscriptions: **not** in MVP UX (see UNIT_ECONOMICS).

---

## 9. MVP screen checklist

- [ ] First-run (3 steps)
- [ ] Memories list + empty state
- [ ] Capture tab
- [ ] Recording Session + interruption recovery
- [ ] Processing + Review
- [ ] Memory Detail
- [ ] Search
- [ ] Settings (privacy, minutes, app lock)
- [ ] Soft limit + Recording Credits sheet (+1 Credit)
- [ ] Zero ads asserted on active recording UI
- [ ] Export / delete account flows

---

## 10. Explicit non-goals (MVP)

- Multi-player shared notebooks
- Always-on ambient wearable mode
- General-purpose AI chat tab
- Gamified streaks / XP
- Heavy onboarding feature tour
