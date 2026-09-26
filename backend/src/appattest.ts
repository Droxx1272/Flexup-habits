/**
 * Apple App Attest verification on WebCrypto — no dependencies, so it runs
 * unchanged in a Cloudflare Worker and in Node for tests.
 *
 * Follows Apple's "Validating apps that connect to your server":
 * https://developer.apple.com/documentation/devicecheck/validating-apps-that-connect-to-your-server
 *
 * - `verifyAttestation` runs once per install: it proves a key was created
 *   in the Secure Enclave of a real Apple device, by a genuine build of this
 *   app (Team ID + bundle ID), and returns that key's public half to store.
 * - `verifyAssertion` runs on every protected request: it proves the request
 *   was signed by that stored key.
 */

// Apple App Attestation Root CA, from
// https://www.apple.com/certificateauthority/Apple_App_Attestation_Root_CA.pem
// SHA-256 fingerprint 1C:B9:82:3B:A2:8B:A6:AD:2D:33:A0:06:94:1D:E2:AE:4F:51:3E:F1:D4:E8:31:B9:F7:E0:FA:7B:62:42:C9:32
const APPLE_ROOT_CA_BASE64 =
  "MIICITCCAaegAwIBAgIQC/O+DvHN0uD7jG5yH2IXmDAKBggqhkjOPQQDAzBSMSYwJAYDVQQDDB1BcHBsZSBBcHAgQXR0ZXN0YXRpb24gUm9vdCBDQTETMBEGA1UECgwKQXBwbGUgSW5jLjETMBEGA1UECAwKQ2FsaWZvcm5pYTAeFw0yMDAzMTgxODMyNTNaFw00NTAzMTUwMDAwMDBaMFIxJjAkBgNVBAMMHUFwcGxlIEFwcCBBdHRlc3RhdGlvbiBSb290IENBMRMwEQYDVQQKDApBcHBsZSBJbmMuMRMwEQYDVQQIDApDYWxpZm9ybmlhMHYwEAYHKoZIzj0CAQYFK4EEACIDYgAERTHhmLW07ATaFQIEVwTtT4dyctdhNbJhFs/Ii2FdCgAHGbpphY3+d8qjuDngIN3WVhQUBHAoMeQ/cLiP1sOUtgjqK9auYen1mMEvRq9Sk3Jm5X8U62H+xTD3FE9TgS41o0IwQDAPBgNVHRMBAf8EBTADAQH/MB0GA1UdDgQWBBSskRBTM72+aEH/pwyp5frq5eWKoTAOBgNVHQ8BAf8EBAMCAQYwCgYIKoZIzj0EAwMDaAAwZQIwQgFGnByvsiVbpTKwSga0kP0e8EeDS4+sQmTvb7vn53O5+FRXgeLhpJ06ysC5PrOyAjEAp5U4xDgEgllF7En3VcE3iexZZtKeYnpqtijVoyFraWVIyd/dganmrduC1bmTBGwD";

const NONCE_EXTENSION_OID = "1.2.840.113635.100.8.2";
const AAGUID_DEVELOPMENT = "appattestdevelop";
const AAGUID_PRODUCTION = "appattest\0\0\0\0\0\0\0";

export type AttestEnvironment = "development" | "production";

export class AppAttestError extends Error {}

// MARK: - Public API

export interface AttestationResult {
  /** DER SubjectPublicKeyInfo of the device key — store this. */
  publicKeySpki: Uint8Array;
  environment: AttestEnvironment;
}

export async function verifyAttestation(params: {
  attestation: Uint8Array;
  /** The exact bytes the app hashed as clientData (the server's challenge). */
  clientData: Uint8Array;
  /** Base64 key identifier from `DCAppAttestService.generateKey()`. */
  keyId: string;
  /** "TEAMID.bundle.id" */
  appId: string;
  allowDevelopment: boolean;
  now?: Date;
}): Promise<AttestationResult> {
  const now = params.now ?? new Date();
  const decoded = decodeCbor(params.attestation);
  const attStmt = mapGet(decoded, "attStmt");
  const authData = asBytes(mapGet(decoded, "authData"), "authData");
  if (mapGet(decoded, "fmt") !== "apple-appattest") throw new AppAttestError("not an App Attest attestation");
  const x5c = mapGet(attStmt, "x5c");
  if (!Array.isArray(x5c) || x5c.length !== 2) throw new AppAttestError("expected two certificates");

  // 1. Certificate chain: credCert ← Apple App Attestation CA 1 ← pinned root.
  const credCert = parseCertificate(asBytes(x5c[0], "credCert"));
  const intermediate = parseCertificate(asBytes(x5c[1], "intermediate"));
  const root = parseCertificate(base64Decode(APPLE_ROOT_CA_BASE64));
  for (const cert of [credCert, intermediate, root]) {
    if (now < cert.notBefore || now > cert.notAfter) throw new AppAttestError("certificate outside its validity period");
  }
  if (!(await verifyCertificateSignature(intermediate, root))) {
    throw new AppAttestError("intermediate not signed by Apple's root");
  }
  if (!(await verifyCertificateSignature(credCert, intermediate))) {
    throw new AppAttestError("credential certificate not signed by Apple's intermediate");
  }

  // 2–4. nonce = SHA256(authData ‖ SHA256(clientData)) must equal the
  // octet string inside the credCert's nonce extension.
  const clientDataHash = await sha256(params.clientData);
  const nonce = await sha256(concat(authData, clientDataHash));
  const extension = credCert.extensions.get(NONCE_EXTENSION_OID);
  if (!extension) throw new AppAttestError("nonce extension missing");
  const outer = parseDer(extension, 0);
  const tagged = childrenOf(extension, outer)[0];
  if (!tagged || tagged.tag !== 0xa1) throw new AppAttestError("nonce extension malformed");
  const octet = childrenOf(extension, tagged)[0];
  if (!octet || octet.tag !== 0x04) throw new AppAttestError("nonce extension malformed");
  if (!equalBytes(valueOf(extension, octet), nonce)) throw new AppAttestError("nonce mismatch");

  // 5. keyId = SHA256(public key point).
  const keyIdBytes = base64Decode(params.keyId);
  if (!equalBytes(await sha256(credCert.publicKeyPoint), keyIdBytes)) throw new AppAttestError("keyId mismatch");

  // 6. RP ID hash = SHA256(App ID).
  const auth = parseAuthenticatorData(authData);
  if (!equalBytes(auth.rpIdHash, await sha256(utf8(params.appId)))) throw new AppAttestError("app ID mismatch");

  // 7. A fresh key has signed nothing yet.
  if (auth.counter !== 0) throw new AppAttestError("counter is not zero");

  // 8. Environment.
  if (authData.length < 55) throw new AppAttestError("authData too short");
  const aaguid = String.fromCharCode(...authData.subarray(37, 53));
  let environment: AttestEnvironment;
  if (aaguid === AAGUID_PRODUCTION) environment = "production";
  else if (aaguid === AAGUID_DEVELOPMENT) environment = "development";
  else throw new AppAttestError("unknown App Attest environment");
  if (environment === "development" && !params.allowDevelopment) {
    throw new AppAttestError("development attestations are not accepted");
  }

  // 9. credentialId = keyId.
  const credentialIdLength = (authData[53] << 8) | authData[54];
  const credentialId = authData.subarray(55, 55 + credentialIdLength);
  if (!equalBytes(credentialId, keyIdBytes)) throw new AppAttestError("credentialId mismatch");

  return { publicKeySpki: credCert.spki, environment };
}

export async function verifyAssertion(params: {
  assertion: Uint8Array;
  /** The exact bytes the app hashed as clientData. */
  clientData: Uint8Array;
  /** Stored from `verifyAttestation`. */
  publicKeySpki: Uint8Array;
  appId: string;
}): Promise<{ counter: number }> {
  const decoded = decodeCbor(params.assertion);
  const signature = asBytes(mapGet(decoded, "signature"), "signature");
  const authenticatorData = asBytes(mapGet(decoded, "authenticatorData"), "authenticatorData");

  // 1–3. The device signed SHA256(authenticatorData ‖ SHA256(clientData)).
  const clientDataHash = await sha256(params.clientData);
  const nonce = await sha256(concat(authenticatorData, clientDataHash));
  const key = await crypto.subtle.importKey("spki", params.publicKeySpki, { name: "ECDSA", namedCurve: "P-256" }, false, [
    "verify",
  ]);
  const valid = await crypto.subtle.verify(
    { name: "ECDSA", hash: "SHA-256" },
    key,
    derSignatureToRaw(signature, 32),
    nonce,
  );
  if (!valid) throw new AppAttestError("bad signature");

  // 4. Signed by a key belonging to this app.
  const auth = parseAuthenticatorData(authenticatorData);
  if (!equalBytes(auth.rpIdHash, await sha256(utf8(params.appId)))) throw new AppAttestError("app ID mismatch");

  // 5. Counter must advance. Callers that persist it compare against the
  // stored value; we at least reject a key that claims to have signed nothing.
  if (auth.counter < 1) throw new AppAttestError("counter did not advance");
  return { counter: auth.counter };
}

// MARK: - Bytes

export function base64Decode(input: string): Uint8Array {
  const normalized = input.replace(/-/g, "+").replace(/_/g, "/");
  const padded = normalized + "=".repeat((4 - (normalized.length % 4)) % 4);
  const binary = atob(padded);
  const out = new Uint8Array(binary.length);
  for (let i = 0; i < binary.length; i++) out[i] = binary.charCodeAt(i);
  return out;
}

export function base64Encode(bytes: Uint8Array): string {
  let binary = "";
  for (const byte of bytes) binary += String.fromCharCode(byte);
  return btoa(binary);
}

export function utf8(text: string): Uint8Array {
  return new TextEncoder().encode(text);
}

export function concat(...parts: Uint8Array[]): Uint8Array {
  const out = new Uint8Array(parts.reduce((n, p) => n + p.length, 0));
  let offset = 0;
  for (const part of parts) {
    out.set(part, offset);
    offset += part.length;
  }
  return out;
}

export async function sha256(data: Uint8Array): Promise<Uint8Array> {
  return new Uint8Array(await crypto.subtle.digest("SHA-256", data));
}

function equalBytes(a: Uint8Array, b: Uint8Array): boolean {
  if (a.length !== b.length) return false;
  let diff = 0;
  for (let i = 0; i < a.length; i++) diff |= a[i] ^ b[i];
  return diff === 0;
}

function asBytes(value: unknown, what: string): Uint8Array {
  if (!(value instanceof Uint8Array)) throw new AppAttestError(`${what} is not a byte string`);
  return value;
}

function mapGet(value: unknown, key: string): unknown {
  if (!(value instanceof Map)) throw new AppAttestError("expected a CBOR map");
  return value.get(key);
}

function parseAuthenticatorData(data: Uint8Array): { rpIdHash: Uint8Array; counter: number } {
  if (data.length < 37) throw new AppAttestError("authenticator data too short");
  const counter = ((data[33] << 24) >>> 0) + (data[34] << 16) + (data[35] << 8) + data[36];
  return { rpIdHash: data.subarray(0, 32), counter };
}

// MARK: - CBOR (the subset App Attest uses)

export function decodeCbor(data: Uint8Array): unknown {
  let offset = 0;

  const readLength = (info: number): number => {
    if (info < 24) return info;
    const size = info === 24 ? 1 : info === 25 ? 2 : info === 26 ? 4 : info === 27 ? 8 : 0;
    if (size === 0) throw new AppAttestError("unsupported CBOR length");
    if (offset + size > data.length) throw new AppAttestError("truncated CBOR");
    let value = 0;
    for (let i = 0; i < size; i++) value = value * 256 + data[offset + i];
    offset += size;
    return value;
  };

  const read = (depth: number): unknown => {
    if (depth > 16) throw new AppAttestError("CBOR nested too deeply");
    if (offset >= data.length) throw new AppAttestError("truncated CBOR");
    const initial = data[offset++];
    const major = initial >> 5;
    const info = initial & 0x1f;
    switch (major) {
      case 0:
        return readLength(info);
      case 1:
        return -1 - readLength(info);
      case 2: {
        const length = readLength(info);
        if (offset + length > data.length) throw new AppAttestError("truncated CBOR");
        const bytes = data.slice(offset, offset + length);
        offset += length;
        return bytes;
      }
      case 3: {
        const length = readLength(info);
        if (offset + length > data.length) throw new AppAttestError("truncated CBOR");
        const text = new TextDecoder().decode(data.subarray(offset, offset + length));
        offset += length;
        return text;
      }
      case 4: {
        const length = readLength(info);
        const items: unknown[] = [];
        for (let i = 0; i < length; i++) items.push(read(depth + 1));
        return items;
      }
      case 5: {
        const length = readLength(info);
        const map = new Map<unknown, unknown>();
        for (let i = 0; i < length; i++) {
          const key = read(depth + 1);
          map.set(key, read(depth + 1));
        }
        return map;
      }
      case 7:
        if (info === 20) return false;
        if (info === 21) return true;
        if (info === 22) return null;
        throw new AppAttestError("unsupported CBOR simple value");
      default:
        throw new AppAttestError("unsupported CBOR type");
    }
  };

  const value = read(0);
  if (offset !== data.length) throw new AppAttestError("trailing CBOR data");
  return value;
}

// MARK: - DER / X.509 (just what App Attest needs)

interface DerNode {
  tag: number;
  /** Offset of the tag byte. */
  start: number;
  /** Offset of the first content byte. */
  contentStart: number;
  /** Offset just past the node. */
  end: number;
}

function parseDer(data: Uint8Array, offset: number): DerNode {
  if (offset + 2 > data.length) throw new AppAttestError("truncated DER");
  const tag = data[offset];
  let length = data[offset + 1];
  let contentStart = offset + 2;
  if (length & 0x80) {
    const count = length & 0x7f;
    if (count === 0 || count > 4) throw new AppAttestError("unsupported DER length");
    length = 0;
    for (let i = 0; i < count; i++) length = length * 256 + data[offset + 2 + i];
    contentStart += count;
  }
  const end = contentStart + length;
  if (end > data.length) throw new AppAttestError("truncated DER");
  return { tag, start: offset, contentStart, end };
}

function childrenOf(data: Uint8Array, node: DerNode): DerNode[] {
  const children: DerNode[] = [];
  let offset = node.contentStart;
  while (offset < node.end) {
    const child = parseDer(data, offset);
    children.push(child);
    offset = child.end;
  }
  return children;
}

function valueOf(data: Uint8Array, node: DerNode): Uint8Array {
  return data.subarray(node.contentStart, node.end);
}

function rawOf(data: Uint8Array, node: DerNode): Uint8Array {
  return data.subarray(node.start, node.end);
}

function decodeOid(bytes: Uint8Array): string {
  const parts: number[] = [];
  let value = 0;
  for (let i = 0; i < bytes.length; i++) {
    value = value * 128 + (bytes[i] & 0x7f);
    if (!(bytes[i] & 0x80)) {
      if (parts.length === 0) {
        const first = value < 80 ? Math.floor(value / 40) : 2;
        parts.push(first, value - first * 40);
      } else {
        parts.push(value);
      }
      value = 0;
    }
  }
  return parts.join(".");
}

function decodeTime(data: Uint8Array, node: DerNode): Date {
  const text = new TextDecoder().decode(valueOf(data, node));
  const match =
    node.tag === 0x17
      ? /^(\d{2})(\d{2})(\d{2})(\d{2})(\d{2})(\d{2})Z$/.exec(text)
      : /^(\d{4})(\d{2})(\d{2})(\d{2})(\d{2})(\d{2})Z$/.exec(text);
  if (!match) throw new AppAttestError("unsupported certificate time");
  let year = Number(match[1]);
  if (node.tag === 0x17) year += year < 50 ? 2000 : 1900;
  return new Date(
    Date.UTC(year, Number(match[2]) - 1, Number(match[3]), Number(match[4]), Number(match[5]), Number(match[6])),
  );
}

interface Certificate {
  tbs: Uint8Array;
  signatureAlgorithm: string;
  signature: Uint8Array;
  notBefore: Date;
  notAfter: Date;
  spki: Uint8Array;
  curve: string;
  publicKeyPoint: Uint8Array;
  extensions: Map<string, Uint8Array>;
}

const CURVES: Record<string, { name: "P-256" | "P-384"; size: number }> = {
  "1.2.840.10045.3.1.7": { name: "P-256", size: 32 },
  "1.3.132.0.34": { name: "P-384", size: 48 },
};

const SIGNATURE_HASHES: Record<string, "SHA-256" | "SHA-384"> = {
  "1.2.840.10045.4.3.2": "SHA-256",
  "1.2.840.10045.4.3.3": "SHA-384",
};

function parseCertificate(der: Uint8Array): Certificate {
  const cert = parseDer(der, 0);
  const [tbsNode, algNode, sigNode] = childrenOf(der, cert);
  if (!tbsNode || !algNode || !sigNode || sigNode.tag !== 0x03) throw new AppAttestError("malformed certificate");

  const tbsChildren = childrenOf(der, tbsNode);
  let index = tbsChildren[0]?.tag === 0xa0 ? 1 : 0; // optional [0] version
  index += 1; // serialNumber
  index += 1; // signature algorithm
  index += 1; // issuer
  const validity = tbsChildren[index++];
  index += 1; // subject
  const spkiNode = tbsChildren[index++];
  if (!validity || !spkiNode) throw new AppAttestError("malformed certificate");

  const [notBeforeNode, notAfterNode] = childrenOf(der, validity);
  const [spkiAlg, spkiKey] = childrenOf(der, spkiNode);
  const [, curveNode] = childrenOf(der, spkiAlg);
  if (!curveNode || !spkiKey) throw new AppAttestError("unsupported public key");

  const extensions = new Map<string, Uint8Array>();
  const extensionsWrapper = tbsChildren.find((node) => node.tag === 0xa3);
  if (extensionsWrapper) {
    const [sequence] = childrenOf(der, extensionsWrapper);
    for (const extension of childrenOf(der, sequence)) {
      const parts = childrenOf(der, extension);
      const oid = decodeOid(valueOf(der, parts[0]));
      const value = parts[parts.length - 1];
      extensions.set(oid, valueOf(der, value));
    }
  }

  return {
    tbs: rawOf(der, tbsNode),
    signatureAlgorithm: decodeOid(valueOf(der, childrenOf(der, algNode)[0])),
    signature: valueOf(der, sigNode).subarray(1), // drop the unused-bits byte
    notBefore: decodeTime(der, notBeforeNode),
    notAfter: decodeTime(der, notAfterNode),
    spki: rawOf(der, spkiNode),
    curve: decodeOid(valueOf(der, curveNode)),
    publicKeyPoint: valueOf(der, spkiKey).subarray(1),
    extensions,
  };
}

async function verifyCertificateSignature(cert: Certificate, issuer: Certificate): Promise<boolean> {
  const hash = SIGNATURE_HASHES[cert.signatureAlgorithm];
  const curve = CURVES[issuer.curve];
  if (!hash || !curve) throw new AppAttestError("unsupported certificate algorithm");
  const key = await crypto.subtle.importKey("spki", issuer.spki, { name: "ECDSA", namedCurve: curve.name }, false, [
    "verify",
  ]);
  return crypto.subtle.verify({ name: "ECDSA", hash }, key, derSignatureToRaw(cert.signature, curve.size), cert.tbs);
}

/** DER `SEQUENCE { r INTEGER, s INTEGER }` → the fixed-width r‖s WebCrypto wants. */
function derSignatureToRaw(der: Uint8Array, size: number): Uint8Array {
  const sequence = parseDer(der, 0);
  const [r, s] = childrenOf(der, sequence);
  if (!r || !s || r.tag !== 0x02 || s.tag !== 0x02) throw new AppAttestError("malformed signature");
  const out = new Uint8Array(size * 2);
  const place = (node: DerNode, at: number) => {
    let bytes = valueOf(der, node);
    while (bytes.length > size && bytes[0] === 0) bytes = bytes.subarray(1);
    if (bytes.length > size) throw new AppAttestError("malformed signature");
    out.set(bytes, at + size - bytes.length);
  };
  place(r, 0);
  place(s, size);
  return out;
}
