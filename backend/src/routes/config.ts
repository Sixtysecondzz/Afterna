import { Hono } from "hono";
import { config } from "../config.js";
import type { RemoteConfig } from "../types.js";

export const configRoutes = new Hono();

configRoutes.get("/v1/config", (c) => {
  const body: RemoteConfig = {
    base_free_minutes: config.baseFreeMinutes,
    reward_minutes: 5,
    max_daily_rewards: 3,
    banner_enabled: false,
    native_feed_interval: 8,
    banner_refresh_interval: 60,
    ai_daily_limit: config.aiDailyLimit,
    ads_on_summary_enabled: false,
    feature_flags: {
      fixture_mode: config.fixtureMode,
      ask_ai: true,
      cross_conversation_search: true,
    },
  };
  return c.json(body);
});
