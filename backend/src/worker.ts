import { config } from "./config.js";
import { processAvailableJobs } from "./jobs/processJobs.js";

const INTERVAL_MS = Number(process.env.WORKER_INTERVAL_MS ?? 2000);

console.log(`Afterna worker starting (fixture=${config.fixtureMode}, interval=${INTERVAL_MS}ms)`);

async function loop() {
  try {
    const n = await processAvailableJobs(5);
    if (n > 0) console.log(`[worker] processed ${n} job(s)`);
  } catch (err) {
    console.error("[worker] tick failed", err);
  } finally {
    setTimeout(loop, INTERVAL_MS);
  }
}

void loop();
