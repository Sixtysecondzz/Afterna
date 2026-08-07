# Edge Functions (optional)

Primary API: `backend/` (Hono on Node).

Optional future Edge Functions:

- `config` — cacheable remote config
- `quota-gate` — pre-enqueue minutes check close to PostgREST

Keep AssemblyAI / OpenAI keys in the Node worker environment, not in the iOS app.
