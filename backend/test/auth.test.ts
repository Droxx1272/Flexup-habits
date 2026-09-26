import { test } from "node:test";
import assert from "node:assert/strict";
import { AuthError, checkPassword, hashPassword, verifyAppleIdentityToken } from "../src/auth";

const BUNDLE = "com.flexup.FlexUp";

const b64url = (bytes: Uint8Array | string) =>
  Buffer.from(typeof bytes === "string" ? Buffer.from(bytes) : bytes)
    .toString("base64")
    .replace(/\+/g, "-")
    .replace(/\//g, "_")
    .replace(/=+$/, "");

// A stand-in for Apple's signing key, published through an injected JWKS.
const keys = await crypto.subtle.generateKey(
  { name: "RSASSA-PKCS1-v1_5", modulusLength: 2048, publicExponent: new Uint8Array([1, 0, 1]), hash: "SHA-256" },
  true,
  ["sign", "verify"],
);
const publicJwk = { ...(await crypto.subtle.exportKey("jwk", keys.publicKey)), kid: "TESTKID" };
const jwks = async () => [publicJwk as JsonWebKey & { kid: string }];

async function token(payload: Record<string, unknown>, kid = "TESTKID", signer = keys.privateKey) {
  const head = b64url(JSON.stringify({ alg: "RS256", kid }));
  const body = b64url(JSON.stringify(payload));
  const sig = new Uint8Array(await crypto.subtle.sign("RSASSA-PKCS1-v1_5", signer, Buffer.from(`${head}.${body}`)));
  return `${head}.${body}.${b64url(sig)}`;
}

const valid = () => ({
  iss: "https://appleid.apple.com",
  aud: BUNDLE,
  sub: "001234.abcdef",
  email: "someone@privaterelay.appleid.com",
  exp: Math.floor(Date.now() / 1000) + 600,
});

const rejects = (promise: Promise<unknown>, message: RegExp) =>
  assert.rejects(promise, (e: unknown) => e instanceof AuthError && message.test(e.message));

test("accepts a valid Apple identity token", async () => {
  const identity = await verifyAppleIdentityToken(await token(valid()), BUNDLE, jwks);
  assert.equal(identity.sub, "001234.abcdef");
  assert.equal(identity.email, "someone@privaterelay.appleid.com");
});

test("rejects a token for another app", async () => {
  await rejects(verifyAppleIdentityToken(await token({ ...valid(), aud: "com.other.app" }), BUNDLE, jwks), /different app/);
});

test("rejects a token from another issuer", async () => {
  await rejects(verifyAppleIdentityToken(await token({ ...valid(), iss: "https://evil.example" }), BUNDLE, jwks), /issuer/);
});

test("rejects an expired token", async () => {
  await rejects(verifyAppleIdentityToken(await token({ ...valid(), exp: 1_600_000_000 }), BUNDLE, jwks), /expired/);
});

test("rejects a token signed by someone else", async () => {
  const impostor = await crypto.subtle.generateKey(
    { name: "RSASSA-PKCS1-v1_5", modulusLength: 2048, publicExponent: new Uint8Array([1, 0, 1]), hash: "SHA-256" },
    true,
    ["sign", "verify"],
  );
  await rejects(verifyAppleIdentityToken(await token(valid(), "TESTKID", impostor.privateKey), BUNDLE, jwks), /signature/);
});

test("rejects a token whose payload was edited", async () => {
  const [head, , sig] = (await token(valid())).split(".");
  const forged = `${head}.${b64url(JSON.stringify({ ...valid(), sub: "someone-else" }))}.${sig}`;
  await rejects(verifyAppleIdentityToken(forged, BUNDLE, jwks), /signature/);
});

test("rejects an unknown signing key", async () => {
  await rejects(verifyAppleIdentityToken(await token(valid(), "OTHERKID"), BUNDLE, jwks), /unknown key/);
});

test("passwords hash and verify, and wrong ones fail", async () => {
  const stored = await hashPassword("correct horse battery");
  assert.match(stored, /^pbkdf2\$100000\$[0-9a-f]{32}\$[0-9a-f]{64}$/);
  assert.equal(await checkPassword("correct horse battery", stored), true);
  assert.equal(await checkPassword("correct horse batterY", stored), false);
  assert.notEqual(await hashPassword("correct horse battery"), stored); // salted
});
