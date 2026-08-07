# UNIT_ECONOMICS.md
## Afterna — Monetisation & Unit Economics

**Goal:** Prefer a **free, ad-supported** app. Test whether ads can cover transcription + AI costs. Recommend subscriptions **only if** ads + soft limits cannot reach sustainability.

**Currency:** USD unless noted  
**Launch geo mix assumption:** AU-heavy Tier-1 English (AU/UK/CA/US)  
**Last updated:** 2026-08-07

---

## 1. Cost model (COGS)

### 1.1 Transcription (STT)

Public 2025–2026 API ranges (batch English):

| Tier | Indicative $/min | Notes |
|---|---|---|
| Budget | $0.0025–$0.003 | e.g. AssemblyAI Universal-2 / OpenAI gpt-4o-mini-transcribe class |
| Mid | $0.004–$0.008 | Deepgram Nova-class / higher STT tiers |
| Planning default | **$0.004 / min** | Includes headroom for diarisation & retries |

### 1.2 AI summarisation / memory extract

| Approach | Indicative cost |
|---|---|
| Short summary per session (small model) | ~$0.001–$0.01 per session |
| Planning default | **$0.005 / session** + **$0.0005 / transcript-minute** for longer context |

**Blended variable COGS (planning):**

\[
\text{COGS/min} \approx 0.004 + 0.0005 = \mathbf{\$0.0045/\ min}
\]
plus **$0.005 / session** fixed AI.

For a 12-minute session ≈ \(12 \times 0.0045 + 0.005 = \$0.059\).

### 1.3 Other variable costs (smaller)

| Item | Planning |
|---|---|
| Storage (text only) | ~$0.001–$0.01 / MAU / month |
| Bandwidth / signed uploads | bundled into COGS margin |
| Crash/analytics | ignore in MVP COGS |
| Support | opex, not COGS |

**Audio retention:** deleting audio after STT keeps storage near-zero—critical for unit economics *and* privacy.

---

## 2. Revenue model inputs (ads)

### 2.1 Indicative eCPM ranges (Tier-1 / AU-relevant)

Synthesised from public 2025–2026 publisher benchmarks (wide variance by mediation, seasonality, ATT):

| Format | Indicative eCPM (AU / Tier-1 iOS) | Notes |
|---|---|---|
| Banner / native | **$0.20–$1.50** | High volume, low UX fit |
| Interstitial | **$6–$14** | Retention risk if frequent |
| Rewarded video | **$10–$25** (sometimes higher) | Best UX fit for “earn minutes” |
| AU rewarded (blended cites) | ~**$13–$20** | Mistplay-style country tables ~$13.8 blended RV |
| AU interstitial (blended cites) | ~**$7–$10** | Lower than US iOS peaks |

**Planning eCPMs (conservative AU-leaning iOS):**

| Format | Base | Upside |
|---|---|---|
| Rewarded | **$14** | $20 |
| Interstitial | **$8** | $12 |
| Native | **$0.80** | $1.50 |

**ATT reality:** Without tracking, eCPMs often fall **20–40%**. Model Base as post-ATT-blended.

### 2.2 Ad UX inventory (privacy-compatible)

Allowed:
- Rewarded video for extra minutes (user-initiated)
- Sparse native in Memories list (1 per ~8–12 rows)
- Optional interstitial on **app open** max 1 / session after day 3 (never before first value)

Forbidden for economics *and* brand:
- Ads during recording/processing
- Forced interstitial every memory open

---

## 3. Usage distributions (realistic)

Conversation memory apps are **power-law**: most users try once; a minority record weekly.

### 3.1 Monthly recorded minutes per MAU

| Segment | % of MAU | Minutes / month | Sessions / month | Avg session |
|---|---|---|---|---|
| Dormant | 55% | 0 | 0 | — |
| Light | 25% | 8 | 2 | 4 min |
| Core | 15% | 45 | 4 | ~11 min |
| Power | 5% | 180 | 10 | 18 min |

**Blended minutes / MAU / month:**

\[
0.55(0)+0.25(8)+0.15(45)+0.05(180) = 2 + 6.75 + 9 = \mathbf{17.75\ min}
\]

**Blended sessions / MAU / month:** \(0.25\times2 + 0.15\times4 + 0.05\times10 = 0.5+0.6+0.5 = \mathbf{1.6}\)

Use **18 min** and **1.6 sessions** as planning defaults.

### 3.2 Implied COGS / MAU / month

\[
18 \times 0.0045 + 1.6 \times 0.005 = 0.081 + 0.008 = \mathbf{\sim\$0.09\ COGS/MAU}
\]

Stress (heavy product-market fit): 40 min/MAU → ~**$0.20** COGS/MAU.  
Viral student weeks can spike; need soft caps.

---

## 4. Can unlimited free + ads work?

### 4.1 Ad engagement assumptions

| Metric | Conservative | Base | Optimistic |
|---|---|---|---|
| Rewarded plays / MAU / month | 0.3 | 0.8 | 1.5 |
| Interstitials / MAU / month | 0.5 | 1.5 | 3.0 |
| Native impressions / MAU / month | 8 | 20 | 40 |
| Rewarded eCPM | $12 | $14 | $20 |
| Interstitial eCPM | $6 | $8 | $12 |
| Native eCPM | $0.50 | $0.80 | $1.20 |

**ARPMAU (ad revenue per MAU):**

\[
\text{ARPMAU} = \frac{\text{impressions}}{1000} \times \text{eCPM}
\]

**Base ARPMAU:**

| Format | Calc | $ |
|---|---|---|
| Rewarded | 0.8/1000 × 14 | 0.0112 |
| Interstitial | 1.5/1000 × 8 | 0.0120 |
| Native | 20/1000 × 0.80 | 0.0160 |
| **Total** | | **≈ $0.039** |

**Conservative ARPMAU ≈ $0.015**  
**Optimistic ARPMAU ≈ $0.090**

### 4.2 Verdict on unlimited free

| Scenario | ARPMAU | COGS/MAU | Contribution |
|---|---|---|---|
| Conservative | $0.015 | $0.09 | **−$0.075** |
| Base | $0.039 | $0.09 | **−$0.051** |
| Optimistic ads + light usage (12 min) | $0.09 | $0.06 | **+$0.03** |
| Optimistic ads + base usage | $0.09 | $0.09 | **~$0** |

**Conclusion:** Pure **unlimited free transcription for all MAU is not reliably fundable on ads alone** at realistic conversation-memory usage, especially once power users appear.  
Ads *can* fund a generous free tier if minutes are capped and rewarded top-ups convert.

Subscriptions are **not** required—**soft free minutes + Recording Credits + persistent native + remote caps** is the primary design.

---

## 5. Recommended monetisation design (no subscription MVP)

**CEO wording (canonical):**  
**Free + 60 min/week + in-feed native ads + rewarded recording credits + configurable usage caps**  
(Native = sponsored cards in the library/search feed every N rows—not a glued banner. Value screens stay ad-free.)

### 5.1 Free allotment

| Grant | Amount | Config key | Rationale |
|---|---|---|---|
| Weekly free pool | **60 min / week** | `base_free_minutes` | Covers typical light/core users |
| Recording Credit | **1 credit = 5 min** (default) | `reward_minutes` | User thinks in credits, not dollars |
| Max rewarded ads / day | **6** | `max_daily_rewards` | Caps STT dump via ad farming (≤30 min/day @ default) |

Expected mean consumption ~18 min/month ≪ 60/week → **most users never hit the cap**.  
Caps exist to stop the 5% power cohort from destroying margins.

### 5.2 Recording Credits (preferred UX)

When free time is exhausted (and no credit balance):

> You've used your free recording time.  
> Watch an ad to earn 1 Recording Credit  
> **Watch Ad · +1 Credit**

Internally:

| Concept | Behaviour |
|---|---|
| Credit balance | Integer; stackable up to daily reward earn cap |
| Redemption | Starting a recording consumes minutes from free pool first, then from credit-backed minutes |
| Display | Show **credits** + remaining free minutes; never show “$ economics” |
| Remote change | Changing `reward_minutes` from 5→3 updates value of future (and optionally unredeemed) credits without UI redesign |

### 5.3 Soft limits

1. Warning at 80% of weekly free minutes (and when credit balance is 0).
2. At 100% free + 0 credits: allow finishing an **active** recording; block **new** recordings until user earns a credit or week resets.
3. Offer rewarded sheet: **+1 Recording Credit** (not “+15 minutes” in copy).
4. Enforce `max_daily_rewards` (default 6) server-side + client-side.

### 5.4 Ad placement map (trust-critical / premium)

| Surface | Ads? | Format / rule |
|---|---|---|
| Home / History | ✅ | **In-feed native card** after every **4–6** conversation rows (config: `native_feed_interval`) |
| Search results | ✅ | Occasional in-feed native (same interval policy or sparser) |
| Recording | ❌ | Absolutely none |
| Live Activity | ❌ | None |
| Processing | ❌ | None (upload/transcribe/summarise) |
| Conversation Summary | ❌ | Preferably none initially (`ads_on_summary_enabled=false`) |
| Transcript | ❌ | None |
| Ask AI | ❌ | None |
| Out of recording minutes | ✅ | Rewarded → +1 Recording Credit |
| Settings | ❌ | None |

**Design rule:** Native must look like part of the feed (sponsored card), never a permanently glued bottom/top banner. Monetise **browsing/library + resource limits**, not value consumption.

Interstitials: deferred; if ever used, max 1/day after day 3 and never on record/process/detail.

### 5.5 Remote configuration (day one — mandatory)

| Key | Default | Purpose |
|---|---|---|
| `base_free_minutes` | 60 | Weekly free pool |
| `reward_minutes` | 5 | Minutes per Recording Credit |
| `max_daily_rewards` | 6 | Max rewarded ads / day |
| `banner_enabled` | true | In-feed native kill switch (misnamed historically; means native ads on) |
| `native_feed_interval` | 5 | Conversation cards between sponsored inserts (range 4–6) |
| `banner_refresh_interval` | list-policy | Refresh/reuse cadence for feed cards |
| `ads_on_summary_enabled` | false | Keep Summary ad-free at launch |
| `ai_daily_limit` | e.g. 20 | Ask AI daily cap |

If 5-minute credits lose money, set `reward_minutes` to 3 server-side—no App Store update.

### 5.6 When (and only when) to consider subscription

Introduce an **optional** “Supporter / Unlimited” IAP **only if** after 8–12 weeks:

- Rewarded fill rate < 70%, or
- Power-user COGS > 25% of gross revenue, or
- Users request ad-free *and* ads already maxed without covering COGS

Price test then: **$4.99/month** AU—not before. Not the default pitch.

---

## 6. Scale scenarios (1K / 10K / 100K / 1M MAU)

Assumptions per scenario unless noted: **18 min/MAU**, **$0.0045/min + $0.005/session**, Base ads ARPMAU **$0.039**, weekly soft cap in place (COGS restrained to ~same blend).

### 6.1 Monthly P&L sketch (variable only)

| MAU | Minutes | STT+AI COGS | Ad revenue (Base) | Variable margin |
|---|---|---|---|---|
| 1,000 | 18k | ~$90 | ~$39 | **−$51** |
| 10,000 | 180k | ~$900 | ~$390 | **−$510** |
| 100,000 | 1.8M | ~$9,000 | ~$3,900 | **−$5,100** |
| 1,000,000 | 18M | ~$90,000 | ~$39,000 | **−$51,000** |

**Interpretation:** Base ads without behaviour change lose money at every scale.

### 6.2 With soft caps + credits + persistent native (Target model)

Levers:
- Cap + `max_daily_rewards=6` bounds power-user STT dump (≤30 rewarded min/day @ 5 min/credit)
- Cap reduces power-user minutes ~28% overall → COGS/MAU **$0.065**
- Rewarded ~2.0 plays/MAU @ $16 eCPM → $0.032 (credits UX should lift conversion vs opaque “+minutes”)
- In-feed native ~20–30 impr/MAU @ $0.80–$1.20 → ~$0.020–0.036 (library browsing inventory; not glued banner)
- Optional interstitial kept off initially  
→ **ARPMAU ≈ $0.055–0.075**, COGS ≈ $0.065 → **near break-even**; tune `native_feed_interval` + `reward_minutes` via remote config

| MAU | COGS | Revenue (mid) | Variable margin |
|---|---|---|---|
| 1K | $65 | $70 | **+$5** |
| 10K | $650 | $700 | **+$50** |
| 100K | $6.5k | $7.0k | **+$0.5k** |
| 1M | $65k | $70k | **+$5k** |

Still thin—must add opex discipline—but **substantially more plausible** than rewarded-only because native is always-on inventory and credits + daily reward caps control COGS without a subscription.

### 6.3 Stress: uncapped viral power users

If 5% of 100K MAU each burn 400 min/month uncapped:

- Extra minutes ≈ 0.05 × 100k × 400 = 2M min  
- Extra COGS ≈ $9k → blows the Target model  
→ **Soft caps are mandatory**, not optional polish.

### 6.4 Optimistic “ads cover unlimited light users”

If product stays diary-like (≤12 min/MAU) **and** ARPMAU hits $0.09:

- COGS ≈ $0.06 → healthy  
- Unlimited free for light users possible; still soft-cap power tier (fair use 120 min/week).

---

## 7. Scenario narratives

### Scenario A — Launch AU (months 0–3)

- MAU 1–5K, eCPM learning, low fill  
- Expect negative variable margin  
- Fund with runway; instrument cost per session  
- Ship 60 min/week + Recording Credits + native + remote config early

### Scenario B — Product-market fit (10–100K)

- Improve mediation; rewarded as primary  
- Negotiate STT volume pricing toward $0.0025–$0.003/min  
- If COGS/min drops 30% and ARPMAU → $0.07, unlimited *light* use becomes plausible

### Scenario C — Scale (100K–1M)

- Multi-geo dilutes eCPM if expanding beyond Tier-1  
- Keep AU/US/UK as monetisation core  
- Consider on-device / self-hosted STT for power users later  
- Subscription only as optional ad-remove + fair-use lift

### Scenario D — Ads fail (fill <50% or brand harm)

1. Tighten free pool to 30 min/week  
2. Raise rewarded reward friction carefully  
3. Last resort: $3.99–$4.99 optional unlock  
**Do not** lead with subscription paywall.

---

## 8. Unit economics KPIs to instrument

| KPI | Target |
|---|---|
| COGS / active recorder | < $0.15 / month |
| ARPMAU | > COGS/MAU within  decile of Tier-1 |
| Rewarded play rate among capped users | > 35% |
| Cap hit rate | 5–12% of WAU |
| D1/D7 retention after first rewarded | No worse than −2pp vs control |
| Cost per transcribed minute (blended) | Track weekly |
| Audio storage $ | ≈ 0 (purge working) |

---

## 9. Decision matrix

| Question | Answer |
|---|---|
| Prefer free + ads? | **Yes** |
| Can unlimited free work day one? | **No (not safely)** |
| Best design? | **60 min/week + Recording Credits + persistent native + remote caps** |
| Subscriptions MVP? | **No** |
| Subscriptions later? | Only if Target model fails after optimisation |
| Ads on recording / detail value screens? | **Never** (Summary prefer none; Transcript/Ask AI none) |
| Native format? | **In-feed sponsored card every 4–6 rows** (not glued banner) |

---

## 10. Source anchors

- Mobile eCPM benchmarks (Mistplay, AdReact, Adapty/industry posts, 2025–2026) — treat as ranges, not guarantees  
- STT pricing public pages / comparisons (OpenAI / Deepgram / AssemblyAI class, 2026)
