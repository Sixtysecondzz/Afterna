# Supabase — Afterna

## Apply migrations

```bash
# With Supabase CLI linked to a project
supabase db push

# Or local
supabase start
supabase db reset
```

Also run newer files in `migrations/` via the SQL Editor if CLI is unavailable (e.g. `20260808000001_memory_org.sql` for pins, quotes, global todos).

## Auth providers

### Sign in with Apple

1. Apple Developer → Identifiers → App ID `app.afterna.ios` → enable **Sign In with Apple**.
2. Xcode capability is already in `Afterna.entitlements`.
3. Supabase Dashboard → Authentication → Providers → **Apple**:
   - For native iOS, add Bundle ID `app.afterna.ios` under Client IDs (see [Supabase Apple docs](https://supabase.com/docs/guides/auth/social-login/auth-apple?platform=swift)).
4. Put project URL + anon key into `ios/Afterna/Info.plist` (`SUPABASE_URL`, `SUPABASE_ANON_KEY`).

### Google (Gmail)

1. [Google Cloud Console](https://console.cloud.google.com/) → OAuth consent screen + **Web** OAuth client (used by Supabase).
2. Supabase → Authentication → Providers → **Google**: enable, paste Web client ID + secret.
3. Supabase → Authentication → URL Configuration → Redirect URLs, add:
   - `app.afterna.ios://auth-callback`
4. iOS uses **ASWebAuthenticationSession** (no GoogleSignIn SPM). Scheme `app.afterna.ios` is in `Info.plist`.

Until keys exist, the app shows **Continue as Demo** (`Authorization: Bearer dev-user` for the local API).

## Storage

Bucket `audio-inbox` is private, path convention `{user_id}/{recording_id}.m4a`, intended TTL 24–72h.

## Edge Functions

Primary API: `backend/` (Hono on Node). Keep AssemblyAI / OpenAI keys in the Node worker environment, not in the iOS app.
