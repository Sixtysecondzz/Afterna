# Supabase test project setup

**Project ref:** `njhvksxylqhqkshoedkq`  
**API URL:** `https://njhvksxylqhqkshoedkq.supabase.co`

## Cursor MCP

Configured in [`.cursor/mcp.json`](../.cursor/mcp.json). Reload Cursor / enable the Supabase MCP server, then complete browser auth if prompted.

## Agent skills

Installed under `.agents/skills/` (`supabase`, `supabase-postgres-best-practices`).

## Keys to paste (Dashboard → Settings → API)

Do **not** commit these. Put them in:

1. `backend/.env`
   - `SUPABASE_URL=https://njhvksxylqhqkshoedkq.supabase.co`
   - `SUPABASE_ANON_KEY=…`
   - `SUPABASE_SERVICE_ROLE_KEY=…`
   - `DATABASE_URL=…` (already set locally for the test DB)
2. `ios/Afterna/Info.plist`
   - `SUPABASE_URL` (already set)
   - `SUPABASE_ANON_KEY` (still placeholder until you paste)

## Schema

Migrations live in `supabase/migrations/`. Apply via:

```bash
# Preferred once CLI is linked
npx supabase db push --project-ref njhvksxylqhqkshoedkq

# Or SQL Editor in the Supabase dashboard — paste both migration files in order
```

## Auth providers

Enable **Apple** and **Google** under Authentication → Providers (see `supabase/README.md`).

## Security

This is a **test** database. Rotate the DB password and API keys before any production use. Never commit `.env` or connection strings.
