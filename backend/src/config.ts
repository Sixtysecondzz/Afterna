import "dotenv/config";

function bool(v: string | undefined, fallback: boolean): boolean {
  if (v === undefined || v === "") return fallback;
  return ["1", "true", "yes", "on"].includes(v.toLowerCase());
}

function num(v: string | undefined, fallback: number): number {
  const n = Number(v);
  return Number.isFinite(n) ? n : fallback;
}

export const config = {
  port: num(process.env.PORT, 8787),
  appBaseUrl: process.env.APP_BASE_URL ?? "http://localhost:8787",
  fixtureMode: bool(process.env.FIXTURE_MODE, true),
  supabaseUrl: process.env.SUPABASE_URL ?? "",
  supabaseAnonKey: process.env.SUPABASE_ANON_KEY ?? "",
  supabaseServiceRoleKey: process.env.SUPABASE_SERVICE_ROLE_KEY ?? "",
  assemblyAiApiKey: process.env.ASSEMBLYAI_API_KEY ?? "",
  assemblyAiBaseUrl: process.env.ASSEMBLYAI_BASE_URL ?? "https://api.assemblyai.com",
  openAiApiKey: process.env.OPENAI_API_KEY ?? "",
  webhookAuthHeaderName: process.env.WEBHOOK_AUTH_HEADER_NAME ?? "X-Afterna-Webhook-Secret",
  webhookAuthSecret: process.env.WEBHOOK_AUTH_SECRET ?? "change-me",
  baseFreeMinutes: num(process.env.BASE_FREE_MINUTES, 60),
  aiDailyLimit: num(process.env.AI_DAILY_LIMIT, 30),
  extractModel: process.env.EXTRACT_MODEL ?? "gpt-4.1-mini",
  embedModel: process.env.EMBED_MODEL ?? "text-embedding-3-small",
  askModel: process.env.ASK_MODEL ?? "gpt-4.1-mini",
  promptVersion: process.env.PROMPT_VERSION ?? "extract-v1",
} as const;

export type AppConfig = typeof config;
