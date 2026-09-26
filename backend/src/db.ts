/**
 * Community database (Cloudflare D1 / SQLite). The schema is created on
 * first use, once per Worker instance, so setup needs no migration step.
 * Additive changes only: new tables or `ALTER TABLE … ADD COLUMN` guarded
 * by a check. Never drop or rename in place.
 */

const SCHEMA = [
  `CREATE TABLE IF NOT EXISTS users (
     id TEXT PRIMARY KEY,
     email TEXT UNIQUE,
     password_hash TEXT,
     apple_sub TEXT UNIQUE,
     name TEXT NOT NULL,
     handle TEXT NOT NULL UNIQUE,
     identity TEXT NOT NULL DEFAULT '',
     friend_code TEXT NOT NULL UNIQUE,
     created_at TEXT NOT NULL
   )`,
  `CREATE TABLE IF NOT EXISTS sessions (
     token_hash TEXT PRIMARY KEY,
     user_id TEXT NOT NULL,
     created_at TEXT NOT NULL
   )`,
  `CREATE INDEX IF NOT EXISTS sessions_user ON sessions(user_id)`,
  `CREATE TABLE IF NOT EXISTS friend_requests (
     from_id TEXT NOT NULL,
     to_id TEXT NOT NULL,
     created_at TEXT NOT NULL,
     PRIMARY KEY (from_id, to_id)
   )`,
  `CREATE INDEX IF NOT EXISTS friend_requests_to ON friend_requests(to_id)`,
  // Stored in both directions so "my friends" is one indexed lookup.
  `CREATE TABLE IF NOT EXISTS friendships (
     user_id TEXT NOT NULL,
     friend_id TEXT NOT NULL,
     created_at TEXT NOT NULL,
     PRIMARY KEY (user_id, friend_id)
   )`,
  `CREATE TABLE IF NOT EXISTS events (
     id TEXT PRIMARY KEY,
     user_id TEXT NOT NULL,
     client_id TEXT NOT NULL,
     kind TEXT NOT NULL,
     title TEXT NOT NULL,
     detail TEXT NOT NULL DEFAULT '',
     day TEXT NOT NULL,
     streak INTEGER,
     occurred_at TEXT NOT NULL,
     created_at TEXT NOT NULL,
     UNIQUE (user_id, client_id)
   )`,
  `CREATE INDEX IF NOT EXISTS events_user_time ON events(user_id, occurred_at)`,
  `CREATE TABLE IF NOT EXISTS cheers (
     event_id TEXT NOT NULL,
     user_id TEXT NOT NULL,
     emoji TEXT NOT NULL,
     created_at TEXT NOT NULL,
     PRIMARY KEY (event_id, user_id)
   )`,
  `CREATE TABLE IF NOT EXISTS nudges (
     id TEXT PRIMARY KEY,
     from_id TEXT NOT NULL,
     to_id TEXT NOT NULL,
     kind TEXT NOT NULL,
     day TEXT NOT NULL,
     created_at TEXT NOT NULL,
     seen_at TEXT,
     UNIQUE (from_id, to_id, day)
   )`,
  `CREATE INDEX IF NOT EXISTS nudges_to ON nudges(to_id, seen_at)`,
];

let ready: Promise<void> | null = null;

export function ensureSchema(db: D1Database): Promise<void> {
  if (!ready) {
    ready = db
      .batch(SCHEMA.map((sql) => db.prepare(sql)))
      .then(() => undefined)
      .catch((error) => {
        ready = null;
        throw error;
      });
  }
  return ready;
}

/** ISO 8601 without milliseconds — what the app's `.iso8601` decoder expects. */
export function isoNow(date = new Date()): string {
  return date.toISOString().replace(/\.\d{3}Z$/, "Z");
}
