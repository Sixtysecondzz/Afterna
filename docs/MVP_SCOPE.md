# MVP Scope — Afterna V1

## In scope

1. Authentication (Sign in with Apple + session)
2. Start / pause / stop audio recording
3. Reliable background + lock-screen recording (Live Activity)
4. Chunked local storage + upload/process pipeline
5. Batch transcription with timestamps
6. Speaker separation (provider diarisation) + rename speakers
7. AI summary, key points, action items, decisions
8. Entity extraction (people, companies, projects, dates/deadlines)
9. Conversation history library
10. Full-text + basic semantic search
11. Ask AI about one conversation (with citations)
12. Basic cross-conversation Ask AI (with citations)
13. Export / share (Markdown/text, system share sheet)
14. Delete conversation + account deletion
15. Settings + privacy controls (retention, keep-audio opt-in, consent notice)
16. Weekly free minutes + **Recording Credits** (rewarded) + **in-feed native** on Home/History (and occasional Search) every 4–6 rows
17. Remote config for usage/ads (`base_free_minutes`, `reward_minutes`, `max_daily_rewards`, `banner_enabled`, `native_feed_interval`, `banner_refresh_interval`, `ads_on_summary_enabled`, `ai_daily_limit`)
18. Hard rule: **no ads** on Recording, Live Activity, Processing, Transcript, Ask AI, Settings; Summary preferably none

## Explicitly out of V1

- Meeting bots / calendar auto-join
- Zoom / Teams / desktop capture
- Enterprise team admin / SSO
- CRM integrations
- Live streaming captions
- Knowledge graph product
- Complex billing / subscription paywall
- Social / feed features
- Always-on ambient recording
- Phone.app call recording claims
- Ads on the recording screen

## Quality bar for “done”

Compiles; tests for critical paths; loading/empty/error UX; accessibility basics; docs updated; no fake stubs presented as finished.
