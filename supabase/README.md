# Supabase — Afterna

## Apply migrations

```bash
# With Supabase CLI linked to a project
supabase db push

# Or local
supabase start
supabase db reset
```

## Auth providers

### Sign in with Apple

1. Apple Developer → Identifiers → App ID `app.afterna.ios` → enable **Sign In with Apple**.
2. Xcode capability is already in `Afterna.entitlements`.
3. Supabase Dashboard → Authentication → Providers → **Apple**:
   - For native iOS, add Bundle ID `app.afterna.ios` under Client IDs (see [Supabase Apple docs](https://supabase.com/docs/guides/auth/social-login/auth-apple?platform=swift)).
4. Put project URL + anon key into `ios/Afterna/Info.plist` (`SUPABASE_URL`, `SUPABASE_ANON_KEY`).

### Google (Gmail)

1. [Google Cloud Console](https://console.cloud.google.com/) → create OAuth consent screen.
2. Create **iOS** OAuth client ID (bundle `app.afterna.ios`) and a **Web** client ID.
3. Supabase → Authentication → Providers → **Google**:
   - Paste Web + iOS client IDs (comma-separated) under Client IDs.
   - Enable **Skip nonce check** for native Google Sign-In.
4. In `ios/Afterna/Info.plist`:
   - `GIDClientID` = iOS client ID (`….apps.googleusercontent.com`)
   - `CFBundleURLSchemes` = reversed client ID (`com.googleusercontent.apps.…`)

Until keys exist, the app shows **Continue as Demo** (`Authorization: Bearer dev-user` for the local API).

## Storage

Bucket `audio-inbox` is private, path convention `{user_id}/{recording_id}.m4a`, intended TTL 24–72h.

## Edge Functions

Primary API: `backend/` (Hono on Node). Keep AssemblyAI / OpenAI keys in the Node worker environment, not in the iOS app.
