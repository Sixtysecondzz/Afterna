# Transcription Provider Research — Afterna

**Product context:** iPhone conversation memory app (multi-speaker, real rooms, AU/US/UK English first).  
**MVP mode preference:** **batch post-recording** (upload completed audio → async transcript). Prefer streaming only when live captions clearly justify cost and complexity.  
**Research window:** verified against public pricing/docs as of **August 2026**. Rates change; re-check source URLs before locking contracts.

---

## Executive recommendation

| Role | Provider / model | Why |
|---|---|---|
| **Primary (MVP)** | **AssemblyAI** — `universal-3-pro` (Universal-3.5 Pro) async + speaker diarization | Best batch price/quality for multi-speaker conversations; cheap diarization; word timestamps & punctuation; mature async job API; EU endpoint at same price |
| **Fallback** | **OpenAI** — `gpt-4o-transcribe-diarize` (speaker memory) / `gpt-transcribe` (plain text) | Different vendor failure domain; simple REST; strong general accuracy; known-speaker references; high operational reliability |
| **Strong alternate (eval)** | **Deepgram Nova-3** pre-recorded | Excellent noisy / far-field / accented speech marketing + benchmarks; keep if your AU café/office eval set beats AssemblyAI |
| **Long-term cost** | Tiered routing + on-device draft + (at scale) self-hosted Whisper | See [Cost optimisation](#long-term-cost-optimisation) |

**Do not use as primary for long-form conversation memory:** legacy **Apple `SFSpeechRecognizer`** (session/rate limits). Treat **Apple `SpeechAnalyzer` (iOS 26+)** as on-device privacy/offline assist, not cloud diarized memory.

---

## Decision criteria (weighted for this app)

1. **Multi-speaker + diarisation** — who said what is a product feature, not an add-on curiosity  
2. **Noisy rooms / far-field phone mic** — cafés, kitchens, cars  
3. **AU / US / UK accent robustness** — English variety first; other languages later  
4. **Punctuation + timestamps** — readable memory + seek/playback  
5. **Batch reliability** — fewer moving parts than live WebSocket on cellular  
6. **Cost per audio hour** at early volumes (tens–hundreds of hours/month)  
7. **API reliability / ops simplicity** — retries, webhooks, clear failure modes  
8. **Overlapping speech honesty** — all vendors degrade; prefer overlap-aware systems, never promise perfect separation

---

## Provider scorecard (MVP lens)

Ratings are qualitative (●●●●● best) for *this* product, not universal WER leaderboards.

| Provider | Accuracy (clear EN) | Noisy / far-field | AU/US/UK | Multi-spk / overlap | Punctuation | Timestamps | Diarisation | Languages | Batch | Streaming | Reliability | ~Cost/hr (batch + diar*) |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| **AssemblyAI U3.5 Pro** | ●●●●● | ●●●● | ●●●● | ●●●● | ●●●●● | ●●●●● | ●●●●● | ●●●● (U3.5) / ●●●●● (U2) | ●●●●● | ●●●● | ●●●●● | **~$0.23** |
| **Deepgram Nova-3** | ●●●●● | ●●●●● | ●●●●● | ●●●● | ●●●●● | ●●●●● | ●●●● | ●●●● | ●●●●● | ●●●●● | ●●●●● | **~$0.46–0.55**† |
| **OpenAI gpt-transcribe** | ●●●●● | ●●●● | ●●●● | ●● | ●●●● | Limited‡ | — | ●●●●● | ●●●● | Live separate | ●●●●● | **~$0.27** |
| **OpenAI gpt-4o-transcribe-diarize** | ●●●● | ●●●● | ●●●● | ●●●● | ●●●● | Segment | ●●●●● | ●●●● | ●●●● | File stream | ●●●●● | **~$0.36** |
| **OpenAI whisper-1** | ●●●● | ●●● | ●●●● | ●● | ●●● | ●●●●● word | — | ●●●●● | ●●●● | No | ●●●● | **~$0.36** |
| **Google STT V2 Chirp** | ●●●● | ●●●● | ●●●● | ●●● | ●●●● | ●●●● | ●●● | ●●●●● | ●●●●● | ●●●●● | ●●●●● | **~$0.96** (std) / **~$0.18** (dynamic batch, ≤24h) |
| **Apple SFSpeechRecognizer** | ●●● | ●●● | ●●●● (locale) | ●● | ●●● | Weak | — | ●●●● | Short only | Partial | ●●● (device) | **$0** (quota/limits) |
| **Apple SpeechAnalyzer (iOS 26+)** | ●●●●● (on-device) | ●●●● | ●●●● | ●● | ●●●● | ●●● | — | Growing | ●●●●● long-form | ●●●● | ●●●●● on-device | **$0** |
| **Self-hosted Whisper (+ diar)** | ●●●● | ●●● | ●●●● | ●●● (w/ pyannote) | Post | Post | DIY | ●●●●● | ●●●●● | Hard | You own it | **~$0.02–0.05** infra§ |
| **Gladia** (notable other) | ●●●● | ●●●● | ●●●● | ●●●●● async | ●●●●● | ●●●●● | ●●●●● async | ●●●●● | ●●●●● | ●●●● (no live diar) | ●●●● | **~$0.61** starter |

\* Approximate PAYG USD for **1 hour mono audio**, diarisation included where required for conversation memory.  
† Deepgram Nova-3 Monolingual pre-recorded **$0.0077/min ≈ $0.46/hr**; multilingual **$0.0092/min ≈ $0.55/hr**. Streaming currently has promotional lower rates — confirm live. Diarisation add-on listed **+$0.002/min** on streaming; verify whether pre-recorded includes diarisation in your account.  
‡ OpenAI: word-level `timestamp_granularities` documented for **`whisper-1`**; diarize model returns **segment** speaker/start/end via `diarized_json`.  
§ Infra only at high utilisation; excludes DevOps labour (see cost section).

---

## Detailed provider notes

### 1. AssemblyAI (recommended primary)

**Best fit:** Async post-recording of conversations with speaker labels.

| Dimension | Assessment |
|---|---|
| Accuracy | Universal-3.5 Pro is the current flagship; strong conversational English |
| Latency | Batch: typically seconds–low minutes depending on length/queue (not live) |
| Accents | Solid EN varieties; still run AU-specific eval clips |
| Noisy rooms | Good; not marketed as strongly as Nova-3 for extreme far-field |
| Overlap | Better than classic clustering-only stacks; still imperfect |
| Punctuation / formatting | First-class |
| Timestamps | Word-level supported |
| Diarisation | Async **+$0.02/hr** standard; experimental **+$0.065/hr** for hard audio |
| Languages | U3.5 Pro: focused multilingual / code-switch story; Universal-2: broader 99+ coverage at **$0.15/hr** |
| Streaming vs batch | Both; MVP should use **pre-recorded**. Streaming billed on **WebSocket open time** (idle counts) |
| Reliability | Mature job + webhook pattern; failed transcripts not charged (per their billing docs) |
| Cost | **$0.21/hr** + **$0.02** diar = **~$0.23/hr** |

**Sources:**  
- https://www.assemblyai.com/pricing  
- https://www.assemblyai.com/docs/billing-and-pricing  
- https://www.assemblyai.com/blog/speech-to-text-api-pricing  

**MVP config sketch:** `speech_models: ["universal-3-pro"]`, speaker diarization on, word timestamps on, language hints for `en_au` / `en_us` / `en_gb` when known, optional keyterms for contact names.

**Risks:** Streaming cost surprises if someone leaves sockets open; model defaults can differ free vs paid — always set model explicitly.

---

### 2. OpenAI transcription APIs (recommended fallback)

**Current models (2026):**

| Model | Role | Official estimate |
|---|---|---|
| `gpt-transcribe` | **Recommended** default for recorded speech | **$0.0045/min ≈ $0.27/hr** |
| `gpt-4o-transcribe` | Prior GPT-4o STT generation | **~$0.006/min ≈ $0.36/hr** |
| `gpt-4o-mini-transcribe` | Cheaper / lower quality | **~$0.003/min ≈ $0.18/hr** |
| `gpt-4o-transcribe-diarize` | Speaker labels (`diarized_json`) | Commonly **~$0.006/min ≈ $0.36/hr** (verify against current pricing page; not always listed as a separate row) |
| `whisper-1` | Legacy; word timestamps / SRT/VTT | **$0.006/min ≈ $0.36/hr** |
| `gpt-live-transcribe` / realtime whisper | Live streaming | **$0.017/min ≈ $1.02/hr** |

**Sources:**  
- https://developers.openai.com/api/docs/pricing  
- https://openai.com/api/pricing/  
- https://developers.openai.com/api/docs/guides/speech-to-text  
- https://developers.openai.com/api/docs/models/gpt-4o-transcribe  

| Dimension | Assessment |
|---|---|
| Accuracy | Excellent general STT; gpt-transcribe is the current recommended file model |
| Latency | Fast file turnaround; not a true live caption product at batch prices |
| Accents / noise | Strong vs classic Whisper; still validate on phone-mic AU audio |
| Diarisation | Dedicated `gpt-4o-transcribe-diarize`; optional known-speaker reference clips (up to 4) — valuable for “remember who this is” |
| Timestamps | Diarize → segment times; **word timestamps → whisper-1** |
| Limits | **25 MB** upload; longer audio needs chunking (`chunking_strategy` required for diarize >30s) |
| Streaming | Live models are **~3–4×** batch cost — avoid for MVP |
| Reliability | Extremely common dependency; clear rate tiers |

**Use as fallback when:** AssemblyAI outage / elevated error rate / quality regression on a clip family.  
**Do not expect:** One model that simultaneously gives best WER + word timestamps + diarisation + cheapest price.

---

### 3. Deepgram (Nova-3) — strong alternate / streaming leader

| Dimension | Assessment |
|---|---|
| Accuracy | Nova-3 claims large WER gains vs prior gens; strong on accents, noise, crosstalk (vendor benchmarks) |
| Latency | Excellent streaming story (Flux / Nova); batch also fast |
| Diarisation | Supported; streaming add-on **+$0.0020/min** on published pricing |
| Formatting | Smart formatting included |
| Languages | Nova-3 multilingual + code-switch story; ~45+ languages depending on model |
| Cost (official page) | Nova-3 Mono PAYG: stream **$0.0048/min**, pre-recorded **$0.0077/min**; Multi: **$0.0058 / $0.0092**. Note: **streaming currently cheaper than batch** (promo called out) |
| Credits | **$200** free credit (Pay As You Go) |

**Sources:**  
- https://deepgram.com/pricing  
- https://deepgram.com/learn/introducing-nova-3-speech-to-text-api  
- https://deepgram.com/learn/model-comparison-when-to-use-nova-2-vs-nova-3-for-devs  

**When to promote to primary:** If blinded evals on *your* iPhone room recordings (especially AU + overlap) beat AssemblyAI by a clear margin, or you later ship live captions.

---

### 4. Google Cloud Speech-to-Text V2 (Chirp / Chirp 3)

| Dimension | Assessment |
|---|---|
| Accuracy | Chirp / Chirp 3 competitive multilingual ASR; diarisation + denoiser called out in release notes |
| Cost | Standard recognition **$0.016/min ≈ $0.96/hr** (0–500k min/mo); Dynamic Batch **$0.003/min ≈ $0.18/hr** with lower urgency (results within ~24h) |
| Free tier | **60 min/month** (V1 table; confirm V2 account defaults) |
| Fit | Strong if already on GCP; **expensive for interactive memory sync** at standard rates |

**Sources:**  
- https://cloud.google.com/speech-to-text/pricing  
- https://docs.cloud.google.com/speech-to-text/docs/release-notes  

**Role:** Optional **archival / reprocess** path via Dynamic Batch, not MVP primary.

---

### 5. Apple Speech frameworks (honest limits)

#### Legacy: `SFSpeechRecognizer`

- Designed for **short-form** dictation / queries, not hour-long conversation memory.  
- Practical constraints widely documented: **~1 minute per recognition request**, **~1,000 requests/device/hour**.  
- Default path often uses **Apple servers** (privacy + network); `requiresOnDeviceRecognition` needs downloaded locale models and is not universally available.  
- **No production-grade speaker diarisation.**  
- Punctuation improved (`addsPunctuation`) but output quality ≠ modern cloud STT for meetings.  
- **Verdict:** Fine for voice search / short notes; **unsuitable as primary long-form cloud/offline memory engine.**

#### Modern: `SpeechAnalyzer` + `SpeechTranscriber` (iOS 26+, WWDC 2025)

- On-device, **long-form** capable (Notes / Voice Memos class workloads).  
- Better distant-mic / conversation acoustic modelling than legacy API.  
- **No server fallback** — if the device can’t run it, you’re stuck.  
- Asset download / locale management required (`AssetInventory`).  
- **Still no first-party speaker diarisation** for “Speaker A/B” memory graphs.  
- **Verdict:** Excellent **privacy draft**, offline UX, or low-cost pre-transcript; **not a full substitute** for cloud diarised conversation memory until Apple ships speaker separation (or you add a local diarisation stack).

**Sources:**  
- https://developer.apple.com/videos/play/wwdc2025/277/  
- Apple Speech / SFSpeechRecognizer documentation  
- Industry write-ups summarizing iOS 26 SpeechAnalyzer vs SFSpeechRecognizer (cross-check against Apple docs before shipping)

---

### 6. Self-hosted Whisper (faster-whisper / WhisperKit)

| Dimension | Assessment |
|---|---|
| Accuracy | `large-v3` / turbo variants competitive on clean audio; noisy multi-speaker needs extra models |
| Diarisation | **Not built-in** — typically **pyannote** / Sortformer / similar (extra GPU + ops) |
| On-device iOS | **WhisperKit** is a viable local path for draft transcripts (battery/thermal tradeoffs) |
| Cost | GPU infra often cited ~**$0.02–0.05/audio-hr** at high utilisation; **DevOps labour** often dominates until thousands of hours/month |
| Reliability | You own queues, GPUs, scaling, model updates, abuse |

**Role:** Long-term optimisation / privacy-sensitive enterprise tier — **not MVP**.

---

### 7. Other strong vendors (brief)

| Vendor | Why consider | Why not MVP primary |
|---|---|---|
| **Gladia** | Async diarisation strength; 100+ languages; bundled features | Starter async **~$0.61/hr** (higher than AssemblyAI); live diarisation not available |
| **AWS Transcribe** | Enterprise AWS shops | Overlap/diarisation generally weaker vs leaders; pricing/complexity |
| **Rev AI / Speechmatics** | Specialty accuracy niches | Usually not cheapest; evaluate only if evals win |
| **Soniox** | Emerging real-time + diarisation claims | Smaller ecosystem; validate SLA |

**Gladia source:** https://www.gladia.io/pricing  

---

## Streaming vs batch (MVP recommendation)

| Mode | Pros | Cons | MVP? |
|---|---|---|---|
| **Batch post-recording** | Reliable on flaky LTE/Wi‑Fi; simpler billing; better diarisation (full audio context); easier retries | User waits for “memory ready” | **Yes — default** |
| **Streaming live captions** | Instant feedback; engagement | WebSocket ops; higher cost; idle billing traps; worse/harder diarisation; battery + background audio complexity on iOS | **Phase 2+** only if product requires live UI |

**Rule:** Record locally → compress (AAC/m4a or Opus) → upload → primary provider async job → normalize → store. Optionally show Apple on-device partial text while upload runs.

---

## Cost scenarios (illustrative)

Assumptions: mono audio, conversation memory needs diarisation where available.

| Monthly audio | AssemblyAI U3.5 Pro + diar (~$0.23/hr) | OpenAI diarize (~$0.36/hr) | Deepgram Nova-3 mono prerecorded (~$0.46/hr) | Google Chirp std (~$0.96/hr) |
|---|---|---|---|---|
| 50 hr | ~$12 | ~$18 | ~$23 | ~$48 |
| 200 hr | ~$46 | ~$72 | ~$92 | ~$192 |
| 1,000 hr | ~$230 | ~$360 | ~$460 | ~$960 |
| 5,000 hr | ~$1,150 | ~$1,800 | ~$2,300 | ~$4,800 |

At **5,000+ hr/mo**, revisit Growth commits (Deepgram/Gladia), Google Dynamic Batch for cold storage reprocess, and self-hosted Whisper+diar pipelines.

---

## Long-term cost optimisation

1. **Stay batch-first** — avoid $0.45–$1+/hr streaming until live UI is required.  
2. **Tier models by job class**  
   - Multi-speaker conversation → AssemblyAI U3.5 Pro + diar (or OpenAI diarize)  
   - Single-speaker voice notes → `gpt-4o-mini-transcribe` or AssemblyAI Universal-2  
   - Archival re-transcribe → Google Dynamic Batch / cheaper model  
3. **On-device draft (iOS 26+ SpeechAnalyzer / WhisperKit)** — reduce “retry because user is impatient” cloud calls; never treat as final diarised truth.  
4. **Aggressive VAD / silence trim** before upload — don’t pay for 20 minutes of empty room.  
5. **Provider commits** only after volume is stable (Deepgram Growth, Gladia Growth, GCP committed use).  
6. **Self-host** when volume + privacy justify GPU + SRE (rough industry break-even often **hundreds–thousands of hours/month** once labour is counted — measure your own).  
7. **Cache & idempotency** — never double-bill the same recording UUID.  
8. **Eval-gated routing** — periodically score AU noisy clips; auto-failover if primary WER/DER drifts.

---

## Suggested evaluation protocol (before locking primary)

Record **≥30 clips** on iPhone in real conditions:

- AU / US / UK speakers  
- Quiet room, café noise, TV in background, car  
- 2-speaker and 3+ speaker, with intentional overlap  
- 5–45 minute lengths  

Score: WER (or human edit distance), DER / speaker confusion, punctuation readability, time-to-transcript p50/p95, $/hr, failure rate.

Promote Deepgram (or OpenAI) to primary **only if** they win this eval, not vendor blogs.

---

## Recommendation summary

1. **Primary:** AssemblyAI Universal-3.5 Pro **async** + standard diarisation.  
2. **Fallback:** OpenAI `gpt-4o-transcribe-diarize` (conversations) / `gpt-transcribe` (single speaker).  
3. **Keep warm:** Deepgram Nova-3 for noisy-room bake-off and future streaming.  
4. **Apple:** SpeechAnalyzer for on-device assist; SFSpeechRecognizer only for short dictation legacy support.  
5. **MVP transport:** batch post-recording behind a swappable provider protocol (see `TRANSCRIPTION_ARCHITECTURE.md`).
