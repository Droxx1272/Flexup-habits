import { test } from "node:test";
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { AppAttestError, base64Decode, utf8, verifyAssertion, verifyAttestation } from "../src/appattest";

const load = (name: string) => JSON.parse(readFileSync(new URL(`./fixtures/${name}`, import.meta.url), "utf8"));
const development = load("attestation-development.json");
const production = load("attestation-production.json");
const assertionFixture = load("assertion.json");

const APP_ID = "V8H6LQ9448.io.uebelacker.AppAttestExample";
// Inside both fixture credential certificates' validity windows.
const WHEN = new Date("2024-06-01T00:00:00Z");

const attest = (fixture: { attestation: string; challenge: string; keyId: string }, overrides: Record<string, unknown> = {}) =>
  verifyAttestation({
    attestation: base64Decode(fixture.attestation),
    clientData: base64Decode(fixture.challenge),
    keyId: fixture.keyId,
    appId: APP_ID,
    allowDevelopment: true,
    now: WHEN,
    ...overrides,
  });

const rejects = async (promise: Promise<unknown>, message: RegExp) => {
  await assert.rejects(promise, (error: unknown) => error instanceof AppAttestError && message.test(error.message));
};

test("accepts a real development attestation", async () => {
  const result = await attest(development);
  assert.equal(result.environment, "development");
  assert.equal(result.publicKeySpki[0], 0x30);
});

test("accepts a real production attestation", async () => {
  const result = await attest(production);
  assert.equal(result.environment, "production");
});

test("refuses development attestations when not allowed", async () => {
  await rejects(attest(development, { allowDevelopment: false }), /development/);
  await attest(production, { allowDevelopment: false });
});

test("refuses a different app", async () => {
  await rejects(attest(production, { appId: "ABCDE12345.com.flexup.FlexUp" }), /app ID/);
});

test("refuses a different challenge", async () => {
  await rejects(attest(production, { clientData: utf8("some other challenge") }), /nonce/);
});

test("refuses a keyId that isn't the attested key", async () => {
  await rejects(attest(production, { keyId: development.keyId }), /keyId/);
});

test("refuses expired certificates", async () => {
  await rejects(attest(production, { now: new Date("2026-01-01T00:00:00Z") }), /validity/);
});

test("refuses a tampered attestation", async () => {
  const bytes = base64Decode(production.attestation);
  bytes[bytes.length - 40] ^= 0xff; // inside authData
  await assert.rejects(attest(production, { attestation: bytes }));
});

test("the attested key verifies assertions it signs", async () => {
  const result = await verifyAssertion({
    assertion: base64Decode(assertionFixture.assertion),
    clientData: utf8(assertionFixture.payload),
    publicKeySpki: base64Decode(assertionFixture.publicKeySpki),
    appId: APP_ID,
  });
  assert.equal(result.counter, 1);
});

test("an assertion doesn't verify for a different body", async () => {
  await rejects(
    verifyAssertion({
      assertion: base64Decode(assertionFixture.assertion),
      clientData: utf8(assertionFixture.payload + " "),
      publicKeySpki: base64Decode(assertionFixture.publicKeySpki),
      appId: APP_ID,
    }),
    /signature/,
  );
});

test("an assertion doesn't verify with another key", async () => {
  const other = await attest(production);
  await rejects(
    verifyAssertion({
      assertion: base64Decode(assertionFixture.assertion),
      clientData: utf8(assertionFixture.payload),
      publicKeySpki: other.publicKeySpki,
      appId: APP_ID,
    }),
    /signature/,
  );
});

test("an assertion doesn't verify for another app", async () => {
  await rejects(
    verifyAssertion({
      assertion: base64Decode(assertionFixture.assertion),
      clientData: utf8(assertionFixture.payload),
      publicKeySpki: base64Decode(assertionFixture.publicKeySpki),
      appId: "ABCDE12345.com.flexup.FlexUp",
    }),
    /app ID/,
  );
});
