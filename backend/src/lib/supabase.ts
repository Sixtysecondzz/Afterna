import { createClient, type SupabaseClient } from "@supabase/supabase-js";
import { config } from "../config.js";

const DEV_USER_ID = "00000000-0000-4000-8000-000000000001";

let admin: SupabaseClient | null = null;

export function hasSupabase(): boolean {
  return Boolean(config.supabaseUrl && config.supabaseServiceRoleKey);
}

export function getAdminClient(): SupabaseClient {
  if (!hasSupabase()) {
    throw new Error("Supabase is not configured. Set SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY.");
  }
  if (!admin) {
    admin = createClient(config.supabaseUrl, config.supabaseServiceRoleKey, {
      auth: { persistSession: false, autoRefreshToken: false },
    });
  }
  return admin;
}

/** In-memory store used when Supabase is not configured (local fixture mode). */
export const memory = {
  users: new Map<string, { id: string; display_name: string | null }>(),
  recordings: new Map<string, Record<string, unknown>>(),
  conversations: new Map<string, Record<string, unknown>>(),
  jobs: new Map<string, Record<string, unknown>>(),
  segments: new Map<string, Record<string, unknown>[]>(),
  speakers: new Map<string, Record<string, unknown>[]>(),
  summaries: new Map<string, Record<string, unknown>>(),
  actionItems: new Map<string, Record<string, unknown>[]>(),
  entities: new Map<string, Record<string, unknown>[]>(),
  embeddings: new Map<string, Record<string, unknown>[]>(),
  queries: [] as Record<string, unknown>[],
  audioBlobs: new Map<string, Buffer>(),
  /** token → shared note row (fixture / memory mode). */
  sharedNotes: new Map<string, Record<string, unknown>>(),
};

memory.users.set(DEV_USER_ID, { id: DEV_USER_ID, display_name: "Dev User" });

export function resolveUserId(authHeader: string | undefined): string {
  if (!authHeader?.startsWith("Bearer ")) {
    throw new AuthError("Missing Bearer token");
  }
  const token = authHeader.slice("Bearer ".length).trim();
  if (!token) throw new AuthError("Empty token");
  if (token === "dev-user" || config.fixtureMode) {
    if (token === "dev-user" || token.startsWith("dev-")) return DEV_USER_ID;
  }
  // JWT subject parsing without verification is only for fixture/dev; production uses Supabase Auth.
  try {
    const payload = JSON.parse(Buffer.from(token.split(".")[1] ?? "", "base64url").toString("utf8")) as {
      sub?: string;
    };
    if (payload.sub) return payload.sub;
  } catch {
    /* fallthrough */
  }
  if (config.fixtureMode) return DEV_USER_ID;
  throw new AuthError("Invalid token");
}

/**
 * Ensure auth.users + public.users exist for this id (guest "dev-user" maps to DEV_USER_ID).
 * public.users FK requires auth.users first; signup trigger creates the public row.
 */
export async function ensureAppUser(userId: string, displayName = "Guest"): Promise<void> {
  if (!hasSupabase()) {
    memory.users.set(userId, { id: userId, display_name: displayName });
    return;
  }
  const sb = getAdminClient();
  const { data: existing } = await sb.from("users").select("id").eq("id", userId).maybeSingle();
  if (existing) return;

  const { data: authLookup, error: getErr } = await sb.auth.admin.getUserById(userId);
  if (getErr || !authLookup?.user) {
    const { error: createErr } = await sb.auth.admin.createUser({
      id: userId,
      email: userId === DEV_USER_ID ? "guest-dev@afterna.local" : `${userId}@users.afterna.local`,
      email_confirm: true,
      user_metadata: { full_name: displayName },
    });
    if (createErr && !/already|exists|registered/i.test(createErr.message)) {
      throw createErr;
    }
  }

  const { error: upsertErr } = await sb.from("users").upsert(
    { id: userId, display_name: displayName },
    { onConflict: "id" },
  );
  if (upsertErr) throw upsertErr;
}

export class AuthError extends Error {
  status = 401;
  constructor(message: string) {
    super(message);
    this.name = "AuthError";
  }
}

export { DEV_USER_ID };
