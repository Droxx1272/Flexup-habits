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
  // Photos (avatars, post pictures). Small JPEGs, served by unguessable ID.
  `CREATE TABLE IF NOT EXISTS images (
     id TEXT PRIMARY KEY,
     user_id TEXT NOT NULL,
     bytes BLOB NOT NULL,
     content_type TEXT NOT NULL,
     created_at TEXT NOT NULL
   )`,
  `CREATE INDEX IF NOT EXISTS images_user ON images(user_id)`,
  `CREATE TABLE IF NOT EXISTS posts (
     id TEXT PRIMARY KEY,
     user_id TEXT NOT NULL,
     text TEXT NOT NULL DEFAULT '',
     image_id TEXT,
     created_at TEXT NOT NULL
   )`,
  `CREATE INDEX IF NOT EXISTS posts_user_time ON posts(user_id, created_at)`,
  `CREATE TABLE IF NOT EXISTS post_kudos (
     post_id TEXT NOT NULL,
     user_id TEXT NOT NULL,
     created_at TEXT NOT NULL,
     PRIMARY KEY (post_id, user_id)
   )`,
  `CREATE TABLE IF NOT EXISTS comments (
     id TEXT PRIMARY KEY,
     post_id TEXT NOT NULL,
     user_id TEXT NOT NULL,
     text TEXT NOT NULL,
     created_at TEXT NOT NULL
   )`,
  `CREATE INDEX IF NOT EXISTS comments_post ON comments(post_id, created_at)`,
  `CREATE TABLE IF NOT EXISTS notifications (
     id TEXT PRIMARY KEY,
     user_id TEXT NOT NULL,
     actor_id TEXT NOT NULL,
     type TEXT NOT NULL,
     post_id TEXT,
     text TEXT NOT NULL DEFAULT '',
     created_at TEXT NOT NULL,
     read_at TEXT
   )`,
  `CREATE INDEX IF NOT EXISTS notifications_user ON notifications(user_id, created_at)`,
  `CREATE TABLE IF NOT EXISTS messages (
     id TEXT PRIMARY KEY,
     from_id TEXT NOT NULL,
     to_id TEXT NOT NULL,
     text TEXT NOT NULL,
     created_at TEXT NOT NULL,
     read_at TEXT
   )`,
  `CREATE INDEX IF NOT EXISTS messages_pair ON messages(from_id, to_id, created_at)`,
  `CREATE INDEX IF NOT EXISTS messages_unread ON messages(to_id, read_at)`,
  `CREATE TABLE IF NOT EXISTS blocks (
     blocker_id TEXT NOT NULL,
     blocked_id TEXT NOT NULL,
     created_at TEXT NOT NULL,
     PRIMARY KEY (blocker_id, blocked_id)
   )`,
  `CREATE TABLE IF NOT EXISTS reports (
     id TEXT PRIMARY KEY,
     reporter_id TEXT NOT NULL,
     target_type TEXT NOT NULL,
     target_id TEXT NOT NULL,
     reason TEXT NOT NULL DEFAULT '',
     created_at TEXT NOT NULL
   )`,
];

/** Columns added after a table first shipped. Applied once each, if missing. */
const ADDED_COLUMNS: { table: string; column: string; definition: string }[] = [
  { table: "users", column: "avatar_id", definition: "TEXT" },
  { table: "users", column: "location", definition: "TEXT NOT NULL DEFAULT ''" },
  { table: "users", column: "bio", definition: "TEXT NOT NULL DEFAULT ''" },
  { table: "users", column: "goal", definition: "TEXT NOT NULL DEFAULT ''" },
  { table: "users", column: "notify_prefs", definition: "TEXT NOT NULL DEFAULT '{}'" },
];

async function addMissingColumns(db: D1Database): Promise<void> {
  const tables = [...new Set(ADDED_COLUMNS.map((c) => c.table))];
  for (const table of tables) {
    const info = await db.prepare(`PRAGMA table_info(${table})`).all<{ name: string }>();
    const existing = new Set(info.results.map((row) => row.name));
    for (const added of ADDED_COLUMNS.filter((c) => c.table === table && !existing.has(c.column))) {
      await db.prepare(`ALTER TABLE ${table} ADD COLUMN ${added.column} ${added.definition}`).run();
    }
  }
}

let ready: Promise<void> | null = null;

export function ensureSchema(db: D1Database): Promise<void> {
  if (!ready) {
    ready = db
      .batch(SCHEMA.map((sql) => db.prepare(sql)))
      .then(() => addMissingColumns(db))
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
