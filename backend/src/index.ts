import { serve } from "@hono/node-server";
import { Hono } from "hono";
import { cors } from "hono/cors";
import { config } from "./config.js";
import { configRoutes } from "./routes/config.js";
import { uploadRoutes } from "./routes/uploads.js";
import { jobRoutes } from "./routes/jobs.js";
import { askRoutes } from "./routes/ask.js";
import { webhookRoutes } from "./routes/webhooks.js";
import { processAvailableJobs } from "./jobs/processJobs.js";

const app = new Hono();

app.use("*", cors());

app.get("/", (c) =>
  c.json({
    service: "afterna-backend",
    fixture_mode: config.fixtureMode,
    docs: {
      health: "/health",
      config: "/v1/config",
      contracts: "../contracts/openapi.yaml",
    },
    hint: "This is the API, not the marketing site. Try GET /health or run the web app from /web.",
  }),
);

app.get("/health", (c) =>
  c.json({
    ok: true,
    service: "afterna-backend",
    fixture_mode: config.fixtureMode,
  }),
);

app.route("/", configRoutes);
app.route("/", uploadRoutes);
app.route("/", jobRoutes);
app.route("/", askRoutes);
app.route("/", webhookRoutes);

/** Dev convenience: process queued jobs inline once. */
app.post("/v1/worker/tick", async (c) => {
  const n = await processAvailableJobs(10);
  return c.json({ processed: n });
});

/** Embedded worker — keeps Fly to a single process group (dashboard deploys are flaky with app+worker). */
const WORKER_INTERVAL_MS = Number(process.env.WORKER_INTERVAL_MS ?? 2000);
async function workerLoop() {
  try {
    const n = await processAvailableJobs(5);
    if (n > 0) console.log(`[worker] processed ${n} job(s)`);
  } catch (err) {
    console.error("[worker] tick failed", err);
  } finally {
    setTimeout(workerLoop, WORKER_INTERVAL_MS);
  }
}

serve({ fetch: app.fetch, port: config.port, hostname: "0.0.0.0" }, (info) => {
  console.log(`Afterna API listening on http://0.0.0.0:${info.port} (fixture=${config.fixtureMode})`);
  void workerLoop();
});

export default app;
