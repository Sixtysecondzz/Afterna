# Afterna agent notes

- Monorepo root: this directory (`ios/`, `backend/`, `supabase/`, `contracts/`, `web/`, `docs/`).
- Always fetch https://www.assemblyai.com/docs/llms.txt before writing AssemblyAI code. The API changes — do not rely on memorized parameter names.
- Never put `ASSEMBLYAI_API_KEY` or `OPENAI_API_KEY` in iOS or git. Server env only.
- Pre-recorded STT: `speech_models: ["universal-3-5-pro", "universal-2"]`, `speaker_labels: true`. Authorization header is the raw key (no `Bearer`) for AssemblyAI STT.
- Do not use deprecated AssemblyAI `auto_chapters` / `summarization` — Afterna extract uses OpenAI jobs.
