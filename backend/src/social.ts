import {
  areFriends,
  isBlocked,
  notify,
  publicUser,
  requireUser,
  type CommunityEnv,
  type Handler,
  type Params,
  type UserRow,
} from "./community";
import { ensureSchema, isoNow } from "./db";
import { HttpError, json, readBody, readJson, text } from "./http";
import { filterText, REPORT_REASONS } from "./moderation";

/**
 * The Strava-like layer on top of friends: photos, posts with kudos and
 * comments, 1:1 messages between friends, the notification bell, profiles,
 * blocking and reporting. Still friends-only: nothing here is visible to
 * someone you haven't accepted.
 */

const IMAGE_TYPES = ["image/jpeg", "image/png", "image/webp"];
/** D1 rows top out at 2 MB; the app sends ≤1080 px JPEGs (~150–300 KB). */
const MAX_IMAGE_BYTES = 1_500_000;
const PAGE = 30;

// MARK: - Helpers

async function friendIds(db: D1Database, userId: string): Promise<string[]> {
  const rows = await db.prepare("SELECT friend_id FROM friendships WHERE user_id = ?").bind(userId).all<{ friend_id: string }>();
  return rows.results.map((row) => row.friend_id);
}

async function canSee(db: D1Database, viewer: string, owner: string): Promise<boolean> {
  return viewer === owner || (await areFriends(db, viewer, owner));
}

async function limit(request: Request, env: CommunityEnv): Promise<void> {
  const ip = request.headers.get("cf-connecting-ip") ?? "unknown";
  const { success } = await env.IP_LIMITER.limit({ key: ip });
  if (!success) throw new HttpError(429, "rate_limited", "Slow down a little. Try again in a minute.");
}

function compactUser(row: { id: string; name: string; handle: string; avatar_id: string | null }) {
  return { id: row.id, name: row.name, handle: row.handle, avatar_id: row.avatar_id };
}

// MARK: - Images

async function uploadImage(request: Request, env: CommunityEnv): Promise<Response> {
  const user = await requireUser(request, env);
  await limit(request, env);
  const contentType = (request.headers.get("content-type") ?? "").split(";")[0].trim();
  if (!IMAGE_TYPES.includes(contentType)) throw new HttpError(400, "bad_request", "Photos must be JPEG, PNG or WebP.");
  const bytes = await readBody(request, MAX_IMAGE_BYTES);
  if (bytes.length < 100) throw new HttpError(400, "bad_request", "That photo is empty.");
  const id = crypto.randomUUID();
  await env.DB.prepare("INSERT INTO images (id, user_id, bytes, content_type, created_at) VALUES (?, ?, ?, ?, ?)")
    .bind(id, user.id, bytes, contentType, isoNow())
    .run();
  return json({ id });
}

/**
 * Served by unguessable ID without a session so the app can load and cache
 * them like any image. IDs are only ever handed to friends.
 */
async function getImage(_request: Request, env: CommunityEnv, params: Params): Promise<Response> {
  const row = await env.DB.prepare("SELECT bytes, content_type FROM images WHERE id = ?")
    .bind(params.id)
    .first<{ bytes: ArrayBuffer | number[]; content_type: string }>();
  if (!row) return new Response("Not found", { status: 404 });
  const body = row.bytes instanceof ArrayBuffer ? row.bytes : new Uint8Array(row.bytes);
  return new Response(body, {
    headers: {
      "content-type": row.content_type,
      "cache-control": "public, max-age=31536000, immutable",
    },
  });
}

// MARK: - Posts

interface PostRow {
  id: string;
  user_id: string;
  text: string;
  image_id: string | null;
  created_at: string;
  name: string;
  handle: string;
  avatar_id: string | null;
}

async function hydratePosts(db: D1Database, viewer: string, rows: PostRow[]) {
  const ids = JSON.stringify(rows.map((row) => row.id));
  const [kudos, counts] = await Promise.all([
    db
      .prepare(
        `SELECT k.post_id, u.id, u.name, u.handle, u.avatar_id FROM post_kudos k JOIN users u ON u.id = k.user_id
         WHERE k.post_id IN (SELECT value FROM json_each(?)) ORDER BY k.created_at`,
      )
      .bind(ids)
      .all<{ post_id: string; id: string; name: string; handle: string; avatar_id: string | null }>(),
    db
      .prepare(`SELECT post_id, COUNT(*) AS n FROM comments WHERE post_id IN (SELECT value FROM json_each(?)) GROUP BY post_id`)
      .bind(ids)
      .all<{ post_id: string; n: number }>(),
  ]);
  const kudosByPost = new Map<string, ReturnType<typeof compactUser>[]>();
  for (const row of kudos.results) kudosByPost.set(row.post_id, [...(kudosByPost.get(row.post_id) ?? []), compactUser(row)]);
  const commentCounts = new Map(counts.results.map((row) => [row.post_id, row.n]));

  return rows.map((row) => {
    const givers = kudosByPost.get(row.id) ?? [];
    return {
      id: row.id,
      user: compactUser({ id: row.user_id, name: row.name, handle: row.handle, avatar_id: row.avatar_id }),
      text: row.text,
      image_id: row.image_id,
      created_at: row.created_at,
      is_mine: row.user_id === viewer,
      kudos: givers,
      gave_kudos: givers.some((giver) => giver.id === viewer),
      comment_count: commentCounts.get(row.id) ?? 0,
    };
  });
}

const POST_SELECT = `SELECT p.id, p.user_id, p.text, p.image_id, p.created_at, u.name, u.handle, u.avatar_id
  FROM posts p JOIN users u ON u.id = p.user_id`;

async function listPosts(request: Request, env: CommunityEnv): Promise<Response> {
  const user = await requireUser(request, env);
  const before = text(new URL(request.url).searchParams.get("before"), 30) || "9999";
  const rows = await env.DB.prepare(
    `${POST_SELECT}
     WHERE (p.user_id = ?1 OR p.user_id IN (SELECT friend_id FROM friendships WHERE user_id = ?1)) AND p.created_at < ?2
     ORDER BY p.created_at DESC LIMIT ${PAGE}`,
  )
    .bind(user.id, before)
    .all<PostRow>();
  return json({ posts: await hydratePosts(env.DB, user.id, rows.results) });
}

async function getPost(request: Request, env: CommunityEnv, params: Params): Promise<Response> {
  const user = await requireUser(request, env);
  await loadVisiblePost(env, user.id, params.id);
  const row = await env.DB.prepare(`${POST_SELECT} WHERE p.id = ?`).bind(params.id).first<PostRow>();
  return json({ post: (await hydratePosts(env.DB, user.id, row ? [row] : []))[0] });
}

async function userPosts(request: Request, env: CommunityEnv, params: Params): Promise<Response> {
  const user = await requireUser(request, env);
  if (!(await canSee(env.DB, user.id, params.id))) throw new HttpError(404, "not_found", "Posts are shared with friends only.");
  const rows = await env.DB.prepare(`${POST_SELECT} WHERE p.user_id = ? ORDER BY p.created_at DESC LIMIT ${PAGE}`)
    .bind(params.id)
    .all<PostRow>();
  return json({ posts: await hydratePosts(env.DB, user.id, rows.results) });
}

async function createPost(request: Request, env: CommunityEnv): Promise<Response> {
  const user = await requireUser(request, env);
  await limit(request, env);
  const body = await readJson(request);
  const postText = filterText(text(body.text, 1000));
  let imageId: string | null = null;
  if (typeof body.image_id === "string" && body.image_id) {
    const owned = await env.DB.prepare("SELECT 1 FROM images WHERE id = ? AND user_id = ?").bind(body.image_id, user.id).first();
    if (!owned) throw new HttpError(400, "bad_request", "That photo didn't upload. Try again.");
    imageId = body.image_id;
  }
  if (!postText && !imageId) throw new HttpError(400, "bad_request", "Write something or add a photo.");

  const id = crypto.randomUUID();
  await env.DB.prepare("INSERT INTO posts (id, user_id, text, image_id, created_at) VALUES (?, ?, ?, ?, ?)")
    .bind(id, user.id, postText, imageId, isoNow())
    .run();
  const row = await env.DB.prepare(`${POST_SELECT} WHERE p.id = ?`).bind(id).first<PostRow>();
  return json({ post: (await hydratePosts(env.DB, user.id, row ? [row] : []))[0] });
}

async function loadVisiblePost(env: CommunityEnv, viewer: string, postId: string): Promise<{ id: string; user_id: string; text: string }> {
  const post = await env.DB.prepare("SELECT id, user_id, text FROM posts WHERE id = ?")
    .bind(postId)
    .first<{ id: string; user_id: string; text: string }>();
  if (!post || !(await canSee(env.DB, viewer, post.user_id))) throw new HttpError(404, "not_found", "That post is gone.");
  return post;
}

async function deletePost(request: Request, env: CommunityEnv, params: Params): Promise<Response> {
  const user = await requireUser(request, env);
  const post = await env.DB.prepare("SELECT id, image_id FROM posts WHERE id = ? AND user_id = ?")
    .bind(params.id, user.id)
    .first<{ id: string; image_id: string | null }>();
  if (!post) throw new HttpError(404, "not_found", "That post is gone.");
  const statements = [
    env.DB.prepare("DELETE FROM post_kudos WHERE post_id = ?").bind(post.id),
    env.DB.prepare("DELETE FROM comments WHERE post_id = ?").bind(post.id),
    env.DB.prepare("DELETE FROM notifications WHERE post_id = ?").bind(post.id),
    env.DB.prepare("DELETE FROM posts WHERE id = ?").bind(post.id),
  ];
  if (post.image_id) statements.push(env.DB.prepare("DELETE FROM images WHERE id = ?").bind(post.image_id));
  await env.DB.batch(statements);
  return json({ ok: true });
}

async function kudos(request: Request, env: CommunityEnv, params: Params): Promise<Response> {
  const user = await requireUser(request, env);
  const post = await loadVisiblePost(env, user.id, params.id);
  const on = (await readJson(request)).on !== false;
  if (on) {
    const result = await env.DB.prepare("INSERT OR IGNORE INTO post_kudos (post_id, user_id, created_at) VALUES (?, ?, ?)")
      .bind(post.id, user.id, isoNow())
      .run();
    if (result.meta.changes > 0) {
      await notify(env.DB, post.user_id, user.id, "kudos", { postId: post.id, text: post.text.slice(0, 80) });
    }
  } else {
    await env.DB.prepare("DELETE FROM post_kudos WHERE post_id = ? AND user_id = ?").bind(post.id, user.id).run();
  }
  return json({ ok: true });
}

async function listComments(request: Request, env: CommunityEnv, params: Params): Promise<Response> {
  const user = await requireUser(request, env);
  const post = await loadVisiblePost(env, user.id, params.id);
  const rows = await env.DB.prepare(
    `SELECT c.id, c.text, c.created_at, u.id AS user_id, u.name, u.handle, u.avatar_id
     FROM comments c JOIN users u ON u.id = c.user_id WHERE c.post_id = ? ORDER BY c.created_at LIMIT 200`,
  )
    .bind(post.id)
    .all<{ id: string; text: string; created_at: string; user_id: string; name: string; handle: string; avatar_id: string | null }>();
  return json({
    comments: rows.results.map((row) => ({
      id: row.id,
      text: row.text,
      created_at: row.created_at,
      user: compactUser({ id: row.user_id, name: row.name, handle: row.handle, avatar_id: row.avatar_id }),
      can_delete: row.user_id === user.id || post.user_id === user.id,
    })),
  });
}

async function addComment(request: Request, env: CommunityEnv, params: Params): Promise<Response> {
  const user = await requireUser(request, env);
  await limit(request, env);
  const post = await loadVisiblePost(env, user.id, params.id);
  const commentText = filterText(text((await readJson(request)).text, 500));
  if (!commentText) throw new HttpError(400, "bad_request", "Write something first.");
  const id = crypto.randomUUID();
  await env.DB.prepare("INSERT INTO comments (id, post_id, user_id, text, created_at) VALUES (?, ?, ?, ?, ?)")
    .bind(id, post.id, user.id, commentText, isoNow())
    .run();
  await notify(env.DB, post.user_id, user.id, "comment", { postId: post.id, text: commentText.slice(0, 80) });
  return json({ ok: true, id });
}

async function deleteComment(request: Request, env: CommunityEnv, params: Params): Promise<Response> {
  const user = await requireUser(request, env);
  const comment = await env.DB.prepare(
    "SELECT c.id, c.user_id, p.user_id AS post_owner FROM comments c JOIN posts p ON p.id = c.post_id WHERE c.id = ?",
  )
    .bind(params.id)
    .first<{ id: string; user_id: string; post_owner: string }>();
  if (!comment || (comment.user_id !== user.id && comment.post_owner !== user.id)) {
    throw new HttpError(404, "not_found", "That comment is gone.");
  }
  await env.DB.prepare("DELETE FROM comments WHERE id = ?").bind(comment.id).run();
  return json({ ok: true });
}

// MARK: - Notifications

async function listNotifications(request: Request, env: CommunityEnv): Promise<Response> {
  const user = await requireUser(request, env);
  const rows = await env.DB.prepare(
    `SELECT n.id, n.type, n.post_id, n.text, n.created_at, n.read_at, u.id AS actor_id, u.name, u.handle, u.avatar_id
     FROM notifications n JOIN users u ON u.id = n.actor_id
     WHERE n.user_id = ? ORDER BY n.created_at DESC LIMIT 60`,
  )
    .bind(user.id)
    .all<{
      id: string;
      type: string;
      post_id: string | null;
      text: string;
      created_at: string;
      read_at: string | null;
      actor_id: string;
      name: string;
      handle: string;
      avatar_id: string | null;
    }>();
  return json({
    notifications: rows.results.map((row) => ({
      id: row.id,
      type: row.type,
      post_id: row.post_id,
      text: row.text,
      created_at: row.created_at,
      is_read: row.read_at !== null,
      actor: compactUser({ id: row.actor_id, name: row.name, handle: row.handle, avatar_id: row.avatar_id }),
    })),
  });
}

async function readNotifications(request: Request, env: CommunityEnv): Promise<Response> {
  const user = await requireUser(request, env);
  await env.DB.prepare("UPDATE notifications SET read_at = ? WHERE user_id = ? AND read_at IS NULL").bind(isoNow(), user.id).run();
  return json({ ok: true });
}

/** The three numbers the header shows: bell, chat, friend requests. */
async function badges(request: Request, env: CommunityEnv): Promise<Response> {
  const user = await requireUser(request, env);
  const [notificationsRow, messagesRow, requestsRow] = await Promise.all([
    env.DB.prepare("SELECT COUNT(*) AS n FROM notifications WHERE user_id = ? AND read_at IS NULL").bind(user.id).first<{ n: number }>(),
    env.DB.prepare(
      `SELECT COUNT(*) AS n FROM messages WHERE to_id = ?1 AND read_at IS NULL
       AND from_id IN (SELECT friend_id FROM friendships WHERE user_id = ?1)`,
    )
      .bind(user.id)
      .first<{ n: number }>(),
    env.DB.prepare("SELECT COUNT(*) AS n FROM friend_requests WHERE to_id = ?").bind(user.id).first<{ n: number }>(),
  ]);
  return json({
    notifications: notificationsRow?.n ?? 0,
    messages: messagesRow?.n ?? 0,
    requests: requestsRow?.n ?? 0,
  });
}

// MARK: - Messages

async function listThreads(request: Request, env: CommunityEnv): Promise<Response> {
  const user = await requireUser(request, env);
  const rows = await env.DB.prepare(
    `SELECT u.id, u.name, u.handle, u.avatar_id,
       (SELECT text FROM messages m WHERE (m.from_id = ?1 AND m.to_id = u.id) OR (m.from_id = u.id AND m.to_id = ?1)
        ORDER BY m.created_at DESC LIMIT 1) AS last_text,
       (SELECT created_at FROM messages m WHERE (m.from_id = ?1 AND m.to_id = u.id) OR (m.from_id = u.id AND m.to_id = ?1)
        ORDER BY m.created_at DESC LIMIT 1) AS last_at,
       (SELECT from_id FROM messages m WHERE (m.from_id = ?1 AND m.to_id = u.id) OR (m.from_id = u.id AND m.to_id = ?1)
        ORDER BY m.created_at DESC LIMIT 1) AS last_from,
       (SELECT COUNT(*) FROM messages m WHERE m.from_id = u.id AND m.to_id = ?1 AND m.read_at IS NULL) AS unread
     FROM friendships f JOIN users u ON u.id = f.friend_id
     WHERE f.user_id = ?1
     ORDER BY last_at IS NULL, last_at DESC, u.name COLLATE NOCASE`,
  )
    .bind(user.id)
    .all<{
      id: string;
      name: string;
      handle: string;
      avatar_id: string | null;
      last_text: string | null;
      last_at: string | null;
      last_from: string | null;
      unread: number;
    }>();
  return json({
    threads: rows.results.map((row) => ({
      user: compactUser(row),
      last_text: row.last_text,
      last_at: row.last_at,
      last_from_me: row.last_from === user.id,
      unread: row.unread,
    })),
  });
}

async function requireFriend(env: CommunityEnv, user: UserRow, otherId: string): Promise<void> {
  if (!(await areFriends(env.DB, user.id, otherId)) || (await isBlocked(env.DB, user.id, otherId))) {
    throw new HttpError(404, "not_found", "You can only message friends.");
  }
}

async function getMessages(request: Request, env: CommunityEnv, params: Params): Promise<Response> {
  const user = await requireUser(request, env);
  await requireFriend(env, user, params.id);
  // Inclusive: timestamps are per-second, so two messages can share one.
  // The app drops the ones it already has by ID.
  const after = text(new URL(request.url).searchParams.get("after"), 30);
  const rows = after
    ? await env.DB.prepare(
        `SELECT id, from_id, text, created_at FROM messages
         WHERE ((from_id = ?1 AND to_id = ?2) OR (from_id = ?2 AND to_id = ?1)) AND created_at >= ?3
         ORDER BY created_at LIMIT 200`,
      )
        .bind(user.id, params.id, after)
        .all<{ id: string; from_id: string; text: string; created_at: string }>()
    : await env.DB.prepare(
        `SELECT * FROM (SELECT id, from_id, text, created_at FROM messages
         WHERE (from_id = ?1 AND to_id = ?2) OR (from_id = ?2 AND to_id = ?1)
         ORDER BY created_at DESC LIMIT 100) ORDER BY created_at`,
      )
        .bind(user.id, params.id)
        .all<{ id: string; from_id: string; text: string; created_at: string }>();
  await env.DB.prepare("UPDATE messages SET read_at = ? WHERE from_id = ? AND to_id = ? AND read_at IS NULL")
    .bind(isoNow(), params.id, user.id)
    .run();
  return json({
    messages: rows.results.map((row) => ({
      id: row.id,
      text: row.text,
      created_at: row.created_at,
      from_me: row.from_id === user.id,
    })),
  });
}

async function sendMessage(request: Request, env: CommunityEnv, params: Params): Promise<Response> {
  const user = await requireUser(request, env);
  await limit(request, env);
  await requireFriend(env, user, params.id);
  const messageText = filterText(text((await readJson(request)).text, 1000));
  if (!messageText) throw new HttpError(400, "bad_request", "Write something first.");
  const message = { id: crypto.randomUUID(), text: messageText, created_at: isoNow(), from_me: true };
  await env.DB.prepare("INSERT INTO messages (id, from_id, to_id, text, created_at) VALUES (?, ?, ?, ?, ?)")
    .bind(message.id, user.id, params.id, message.text, message.created_at)
    .run();
  return json({ message });
}

// MARK: - Profiles, blocking, reporting

async function getProfile(request: Request, env: CommunityEnv, params: Params): Promise<Response> {
  const viewer = await requireUser(request, env);
  if (await isBlocked(env.DB, viewer.id, params.id)) throw new HttpError(404, "not_found", "That profile isn't available.");
  const user = await env.DB.prepare("SELECT * FROM users WHERE id = ?").bind(params.id).first<UserRow>();
  if (!user) throw new HttpError(404, "not_found", "That profile isn't available.");

  let relationship = "none";
  if (user.id === viewer.id) relationship = "self";
  else if (await areFriends(env.DB, viewer.id, user.id)) relationship = "friend";
  else if (await env.DB.prepare("SELECT 1 FROM friend_requests WHERE from_id = ? AND to_id = ?").bind(user.id, viewer.id).first())
    relationship = "incoming";
  else if (await env.DB.prepare("SELECT 1 FROM friend_requests WHERE from_id = ? AND to_id = ?").bind(viewer.id, user.id).first())
    relationship = "outgoing";
  if (relationship === "none") throw new HttpError(404, "not_found", "Profiles are shared with friends only.");

  const monthStart = isoNow(new Date(Date.UTC(new Date().getUTCFullYear(), new Date().getUTCMonth(), 1)));
  const counts = await env.DB.prepare(
    `SELECT kind, COUNT(*) AS n FROM events WHERE user_id = ? AND occurred_at >= ? GROUP BY kind`,
  )
    .bind(user.id, monthStart)
    .all<{ kind: string; n: number }>();
  const streak = await env.DB.prepare(
    "SELECT streak FROM events WHERE user_id = ? AND kind = 'wake' ORDER BY occurred_at DESC LIMIT 1",
  )
    .bind(user.id)
    .first<{ streak: number | null }>();
  const showDetails = relationship === "self" || relationship === "friend";

  return json({
    profile: {
      user: publicUser(user),
      bio: showDetails ? user.bio : "",
      goal: showDetails ? user.goal : "",
      joined_at: user.created_at,
      relationship,
      month: showDetails ? Object.fromEntries(counts.results.map((row) => [row.kind, row.n])) : {},
      wake_streak: showDetails ? (streak?.streak ?? null) : null,
    },
  });
}

async function block(request: Request, env: CommunityEnv, params: Params): Promise<Response> {
  const user = await requireUser(request, env);
  const other = params.id;
  if (other === user.id) throw new HttpError(400, "bad_request", "You can't block yourself.");
  await env.DB.batch([
    env.DB.prepare("INSERT OR IGNORE INTO blocks (blocker_id, blocked_id, created_at) VALUES (?, ?, ?)").bind(user.id, other, isoNow()),
    env.DB.prepare("DELETE FROM friendships WHERE (user_id = ? AND friend_id = ?) OR (user_id = ? AND friend_id = ?)").bind(
      user.id,
      other,
      other,
      user.id,
    ),
    env.DB.prepare("DELETE FROM friend_requests WHERE (from_id = ? AND to_id = ?) OR (from_id = ? AND to_id = ?)").bind(
      user.id,
      other,
      other,
      user.id,
    ),
    env.DB.prepare("DELETE FROM notifications WHERE (user_id = ? AND actor_id = ?) OR (user_id = ? AND actor_id = ?)").bind(
      user.id,
      other,
      other,
      user.id,
    ),
  ]);
  return json({ ok: true });
}

async function unblock(request: Request, env: CommunityEnv, params: Params): Promise<Response> {
  const user = await requireUser(request, env);
  await env.DB.prepare("DELETE FROM blocks WHERE blocker_id = ? AND blocked_id = ?").bind(user.id, params.id).run();
  return json({ ok: true });
}

async function listBlocked(request: Request, env: CommunityEnv): Promise<Response> {
  const user = await requireUser(request, env);
  const rows = await env.DB.prepare(
    "SELECT u.id, u.name, u.handle, u.avatar_id FROM blocks b JOIN users u ON u.id = b.blocked_id WHERE b.blocker_id = ?",
  )
    .bind(user.id)
    .all<{ id: string; name: string; handle: string; avatar_id: string | null }>();
  return json({ users: rows.results.map(compactUser) });
}

async function report(request: Request, env: CommunityEnv): Promise<Response> {
  const user = await requireUser(request, env);
  await limit(request, env);
  const body = await readJson(request);
  const targetType = text(body.type, 20);
  const targetId = text(body.id, 64);
  const reason = text(body.reason, 20);
  if (!["post", "comment", "message", "user"].includes(targetType) || !targetId) {
    throw new HttpError(400, "bad_request", "Couldn't read the report.");
  }
  if (!(REPORT_REASONS as readonly string[]).includes(reason)) throw new HttpError(400, "bad_request", "Pick a reason.");
  await env.DB.prepare("INSERT INTO reports (id, reporter_id, target_type, target_id, reason, created_at) VALUES (?, ?, ?, ?, ?, ?)")
    .bind(crypto.randomUUID(), user.id, targetType, targetId, reason, isoNow())
    .run();
  return json({ ok: true });
}

// MARK: - Routes

export function socialRoutes(): Record<string, Handler> {
  const withSchema =
    (handler: Handler): Handler =>
    async (request, env, params) => {
      await ensureSchema(env.DB);
      return handler(request, env, params);
    };
  return {
    "POST /v1/images": withSchema(uploadImage),
    "GET /v1/images/:id": withSchema(getImage),
    "GET /v1/posts": withSchema(listPosts),
    "POST /v1/posts": withSchema(createPost),
    "GET /v1/posts/:id": withSchema(getPost),
    "POST /v1/posts/:id/delete": withSchema(deletePost),
    "POST /v1/posts/:id/kudos": withSchema(kudos),
    "GET /v1/posts/:id/comments": withSchema(listComments),
    "POST /v1/posts/:id/comments": withSchema(addComment),
    "POST /v1/comments/:id/delete": withSchema(deleteComment),
    "GET /v1/notifications": withSchema(listNotifications),
    "POST /v1/notifications/read": withSchema(readNotifications),
    "GET /v1/badges": withSchema(badges),
    "GET /v1/messages": withSchema(listThreads),
    "GET /v1/messages/:id": withSchema(getMessages),
    "POST /v1/messages/:id": withSchema(sendMessage),
    "GET /v1/users/:id": withSchema(getProfile),
    "GET /v1/users/:id/posts": withSchema(userPosts),
    "POST /v1/users/:id/block": withSchema(block),
    "POST /v1/users/:id/unblock": withSchema(unblock),
    "GET /v1/blocked": withSchema(listBlocked),
    "POST /v1/reports": withSchema(report),
  };
}
