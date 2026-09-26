/** "2026-9-26": the app's `dayKey()` format (no zero padding). */
export function dayKey(date: Date): string {
  return `${date.getUTCFullYear()}-${date.getUTCMonth() + 1}-${date.getUTCDate()}`;
}

/**
 * The caller's local day for the daily AI cap. The app sends it so the cap
 * resets at the person's midnight, but it only counts if it is a date
 * somewhere on Earth right now (UTC-12 to UTC+14). Anything else falls
 * back to the UTC day, so a client can't mint fresh days.
 */
export function quotaDay(claimed: unknown, now = new Date()): string {
  const possible = new Set([
    dayKey(new Date(now.getTime() - 12 * 3600_000)),
    dayKey(now),
    dayKey(new Date(now.getTime() + 14 * 3600_000)),
  ]);
  return typeof claimed === "string" && possible.has(claimed) ? claimed : dayKey(now);
}
