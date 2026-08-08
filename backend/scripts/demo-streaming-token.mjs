/**
 * Minimal local demo: mint a streaming token (or fixture token) via the Afterna API.
 *
 *   FIXTURE_MODE=true npm run dev   # terminal 1
 *   node scripts/demo-streaming-token.mjs
 */
const base = process.env.AFTERNA_API_BASE ?? "http://localhost:8787";

const res = await fetch(`${base}/v1/streaming/token`, {
  method: "POST",
  headers: {
    Authorization: "Bearer dev-user",
    "Content-Type": "application/json",
  },
  body: JSON.stringify({ expires_in_seconds: 60 }),
});

const json = await res.json();
if (!res.ok) {
  console.error("Failed", res.status, json);
  process.exit(1);
}

console.log("Streaming token response:");
console.log(JSON.stringify(json, null, 2));
console.log(
  json.fixture
    ? "\nFixture mode — iOS will simulate live captions without AssemblyAI."
    : "\nConnect iOS/WebSocket with params + token query string (one-time use).",
);
