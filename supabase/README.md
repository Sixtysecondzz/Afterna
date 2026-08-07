# Supabase — Afterna

## Apply migrations

```bash
# With Supabase CLI linked to a project
supabase db push

# Or local
supabase start
supabase db reset
```

## Sign in with Apple (stub)

1. Create an App ID + Services ID in Apple Developer for `app.afterna.ios`.
2. In Supabase Dashboard → Authentication → Providers → Apple, paste Service ID, Team ID, Key ID, and `.p8` secret.
3. Redirect URL: `https://YOUR_PROJECT.supabase.co/auth/v1/callback`.

Until Apple credentials exist, the Node API accepts `Authorization: Bearer dev-user` in fixture mode.

## Storage

Bucket `audio-inbox` is private, path convention `{user_id}/{recording_id}.m4a`, intended TTL 24–72h (configure lifecycle in dashboard or cron purge job).

## Note on Edge Functions

Upload complete + transcription workers live in `backend/` (Node + AssemblyAI SDK) so long ASR jobs are not bound by Edge CPU limits. Optional thin Edge proxies can be added later under `supabase/functions/`.
