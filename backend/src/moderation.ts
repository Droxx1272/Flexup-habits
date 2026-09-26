/**
 * The App Store requires apps with user-generated content to filter
 * objectionable material, let people report it and block users, and act on
 * reports. This is the filter: whole-word matches are masked before storage.
 * It's a floor, not a moderator — extend BLOCKED as reports come in, and
 * review `reports` in D1 (see README).
 */

const BLOCKED = [
  "fuck",
  "fucker",
  "fucking",
  "motherfucker",
  "shit",
  "bullshit",
  "bitch",
  "cunt",
  "asshole",
  "bastard",
  "dick",
  "dickhead",
  "pussy",
  "whore",
  "slut",
  "faggot",
  "fag",
  "nigger",
  "nigga",
  "retard",
  "kys",
];

const PATTERN = new RegExp(`\\b(${BLOCKED.join("|")})s?\\b`, "gi");

export function filterText(text: string): string {
  return text.replace(PATTERN, (match) => match[0] + "*".repeat(Math.max(1, match.length - 1)));
}

export const REPORT_REASONS = ["spam", "harassment", "hate", "nudity", "violence", "other"] as const;
