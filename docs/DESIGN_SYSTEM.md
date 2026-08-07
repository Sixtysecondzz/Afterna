# DESIGN_SYSTEM.md
## Afterna — Design System

**Inspiration:** Apple Notes, Journal, Things, Bear, Linear, Granola  
**Anti-inspiration:** Generic purple AI gradients, cream+terracotta “LLM brochure”, neon dark-mode SaaS

---

## 1. Visual direction

**Name of the look:** *Coastal Ink*

Quiet daylight surfaces, charcoal ink type, a single eucalyptus/sea-glass accent for primary actions, and paper-grain atmosphere. Feels like a well-made notebook app that happens to use AI—not an AI wrapper that happens to have a list.

**Mood board keywords:** paper, ink, harbour light, quiet confidence, tactile, private.

---

## 2. Colour tokens

Use semantic tokens; support Light / Dark / High Contrast.

### 2.1 Light (default)

| Token | Hex | Role |
|---|---|---|
| `--bg-base` | `#F3F1EC` | Warm stone page (not cream cliché #F4F1EA clone—slightly greyer) |
| `--bg-elevated` | `#FFFDF9` | Sheets, grouped content |
| `--bg-recessed` | `#E7E4DD` | Inset wells, search field fill |
| `--ink-primary` | `#1C1B19` | Primary text |
| `--ink-secondary` | `#5E5A54` | Secondary text |
| `--ink-tertiary` | `#8A847C` | Meta / timestamps |
| `--line-subtle` | `#D5D0C7` | Hairlines (use sparingly) |
| `--accent` | `#2F6F68` | Eucalyptus — primary actions |
| `--accent-pressed` | `#255851` | Pressed |
| `--accent-soft` | `#D9E8E5` | Selected rows / chips (rare) |
| `--record` | `#C23B2A` | Recording / destructive emphasis |
| `--record-soft` | `#F3D4CF` | Recording background wash |
| `--warning` | `#B76E1B` | Interruptions / pause |
| `--success` | `#2F6F68` | Align with accent; avoid neon green |
| `--focus-ring` | `#2F6F68` @ 40% | Accessibility focus |

### 2.2 Dark

| Token | Hex | Role |
|---|---|---|
| `--bg-base` | `#121411` | Deep olive-black (not pure #000 void) |
| `--bg-elevated` | `#1C1F1B` | Cards/sheets if needed |
| `--bg-recessed` | `#0E100E` | Insets |
| `--ink-primary` | `#F2EFE8` | Text |
| `--ink-secondary` | `#B8B3AA` | Secondary |
| `--ink-tertiary` | `#8A857C` | Meta |
| `--line-subtle` | `#2A2E29` | Hairlines |
| `--accent` | `#6FBBB2` | Lighter eucalyptus |
| `--record` | `#E35A48` | Recording |

### 2.3 Atmosphere (not flat fill)

- Soft vertical gradient on Capture: `--bg-base` → slightly cooler `#E8EEEB`
- Optional 3–5% noise/grain overlay (CGPattern or asset), Disable with Reduce Transparency
- Memory detail: subtle top wash only—no photo collage hero

**Avoid:** purple/indigo gradients, glow shadows, glassmorphism stacks, rainbow AI avatars.

---

## 3. Typography

**Do not use** Inter, Roboto, Arial, system default as the brand voice.

| Role | iOS choice | Fallback | Notes |
|---|---|---|---|
| Display / Brand | **New York** (serif) | Georgia | Product name, large titles on Capture |
| UI / Body | **SF Pro Text** | System | Lists, settings, transcript body |
| Mono / Timecode | **SF Mono** | Menlo | Elapsed recording time |

### Type scale (approx @ default Dynamic Type)

| Style | Size / weight | Use |
|---|---|---|
| `display.l` | New York 40 Regular | Brand on first-run / Capture |
| `title.l` | SF Pro 34 Bold (Large Title) | Memories |
| `title.m` | SF Pro 22 Semibold | Memory titles |
| `body.l` | SF Pro 17 Regular | Transcript |
| `body.m` | SF Pro 15 Regular | Excerpts |
| `meta` | SF Pro 13 Regular | Dates, privacy lines |
| `timecode` | SF Mono 28 Medium | Recording clock |

Respect Dynamic Type; truncate titles to 2 lines in lists.

---

## 4. Layout & spacing

| Token | Value |
|---|---|
| `--space-1` | 4 |
| `--space-2` | 8 |
| `--space-3` | 12 |
| `--space-4` | 16 |
| `--space-5` | 24 |
| `--space-6` | 32 |
| `--space-7` | 48 |
| `--radius-s` | 8 |
| `--radius-m` | 12 |
| `--radius-l` | 20 |
| `--radius-pill` | Avoid for primary chrome |

**Margins:** 20pt horizontal standard (16pt on SE-class).  
**Lists:** Prefer plain inset grouped lists (Notes-like), not heavy card grids.  
**Hero rule:** Capture screen is one composition: brand/wordmark, one line, record control, privacy line.

---

## 5. Elevation & borders

- Default: **no cards**. Separation via spacing + typography hierarchy.
- Sheets: iOS standard material; avoid custom multi-shadow stacks.
- If a container is needed for interaction (e.g. minutes sheet), use `--bg-elevated` + 1px `--line-subtle`, radius-m.
- Shadows only for the record button’s resting state: soft 8pt y-offset, 12% black—never neon glow.

---

## 6. Iconography

- SF Symbols, weight Regular/Semibold matching text
- Prefer: `mic.fill`, `waveform`, `magnifyingglass`, `lock.fill`, `square.and.arrow.up`, `trash`
- Custom product mark: simple ink monogram (abstract notebook fold / sound bar)—single colour
- No emoji in UI chrome

---

## 7. Components

### 7.1 RecordButton

- Size: 72–88pt hit target
- Idle: filled `--accent` or ink with mic glyph in inverse
- Recording: morphs to square-in-circle stop, `--record`
- Motion: matched geometry to session
- Accessibility: “Start recording” / “Stop recording”

### 7.2 MemoryRow

- Title (1–2 lines) + excerpt (1 line) + relative date
- Swipe: Delete / Pin (pin optional MVP)
- No left icon clutter; optional thin date column on iPad later

### 7.3 RecordingMeter

- 24–32pt height capsule of bars or continuous path
- Colour: `--record` at low opacity
- Freeze on Reduce Motion → static bar

### 7.4 StatusPill (rare)

- Only for Recording / Paused / Interrupted
- Not for marketing badges

### 7.5 PrivacyCaption

- `meta` style, `--ink-secondary`
- Standard string near capture & processing

### 7.6 PrimaryButton / SecondaryButton

- Primary: filled `--accent`, label inverse, height 50, radius-m
- Secondary: plain text or bordered `--line-subtle`
- Destructive: `--record` text button

### 7.7 SearchField

- Recessed well, SF magnifying glass, no heavy shadow

### 7.8 CreditsSheet

- Standard sheet detent
- Copy: free time used → earn **1 Recording Credit** → CTA **Watch Ad · +1 Credit**
- Show credit balance + quiet daily reward remaining
- No secondary native stacked above the CTA
- Never shown over active recording UI

### 7.8b SponsoredNativeCard (in-feed)

- Same row rhythm as `MemoryRow` (not a banner strip)
- Quiet “Sponsored” label; no loud sticker/badge chrome
- Inserted every `native_feed_interval` (4–6) conversation cards in Home/History and occasionally Search
- Must not appear in Conversation Detail (Summary / Transcript / Ask AI)

### 7.9 EmptyState

- One illustration, one sentence, one CTA
- No feature grids

### 7.10 Tab Bar

- 3 tabs; centre Capture can use slightly larger symbol
- Blur material standard; no custom neon selected glow

---

## 8. Imagery

- Prefer photographic stills of **real contexts**: café table notebook, walking path, desk by a window—AU-plausible light
- Full-bleed only on first-run / marketing; in-app Capture uses atmospheric gradient + grain, not stock “AI face”
- No floating sticker overlays on heroes

---

## 9. Dark mode & accessibility

- Ship dark mode from day one (system follow)
- Contrast: body text ≥ WCAG AA against surfaces
- Hit targets ≥ 44pt
- VoiceOver order: title → primary action → secondary
- Differentiate record state by shape + text, not colour alone
- Support Bold Text / Increase Contrast

---

## 10. Motion tokens

| Token | Curve | Duration |
|---|---|---|
| `--motion-quick` | `easeOut` | 180ms |
| `--motion-standard` | `spring(0.9, 0.8)` | ~320ms |
| `--motion-emphasis` | matched geometry | 420ms |

Prefer SwiftUI/`UIView` springs consistent with iOS.

---

## 11. Ad surfaces (if enabled)

- Visual style must match app materials—no loud network defaults if customisable
- Frequency capped; never on Capture/Recording/Processing
- Label “Ad” in `meta` style

---

## 12. Do / Don’t

| Do | Don’t |
|---|---|
| One accent colour used sparingly | Purple AI gradients |
| Serif brand moments | All-Inter startup look |
| Plain lists | Card grids everywhere |
| Honest privacy lines | Fake “encrypted vault” badges without substance |
| Quiet confidence | Streaks, XP, rocket emojis |
| Soft limits | Hard paywalls mid-recording |
