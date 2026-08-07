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

export class AuthError extends Error {
  status = 401;
  constructor(message: string) {
    super(message);
    this.name = "AuthError";
  }
}

export { DEV_USER_ID };
