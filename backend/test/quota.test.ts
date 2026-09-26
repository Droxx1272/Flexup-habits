import { test } from "node:test";
import assert from "node:assert/strict";
import { dayKey, quotaDay } from "../src/quota";

const NOW = new Date("2026-09-26T20:00:00Z");

test("dayKey matches the app's unpadded format", () => {
  assert.equal(dayKey(new Date("2026-01-05T00:00:00Z")), "2026-1-5");
});

test("accepts the caller's local day when it exists somewhere right now", () => {
  // 20:00 UTC is already the 27th in India (UTC+5:30).
  assert.equal(quotaDay("2026-9-27", NOW), "2026-9-27");
  assert.equal(quotaDay("2026-9-26", NOW), "2026-9-26");
});

test("rejects days that can't be today anywhere", () => {
  assert.equal(quotaDay("2026-9-29", NOW), "2026-9-26");
  assert.equal(quotaDay("2026-9-20", NOW), "2026-9-26");
  assert.equal(quotaDay(42, NOW), "2026-9-26");
  assert.equal(quotaDay(undefined, NOW), "2026-9-26");
});
