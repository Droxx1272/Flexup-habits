import Foundation
import CryptoKit
import DeviceCheck

/// Proves to the FlexUp server that a request comes from a genuine copy of
/// this app on a real Apple device (Apple's App Attest), so the AI budget
/// can't be spent by anything that merely knows the server's URL.
///
/// - Once per install: the Secure Enclave makes a key, Apple attests it, and
///   the server stores its public half (`/v1/attest/register`).
/// - Every protected request: the key signs a fresh server challenge plus
///   the exact request body, sent as `X-FlexUp-*` headers.
///
/// The iOS Simulator can't use App Attest. Debug builds there can send a
/// development token instead: add `FLEXUP_DEV_TOKEN` (matching the server's
/// `DEV_BYPASS_TOKEN`) under Product → Scheme → Edit Scheme → Run →
/// Environment Variables. Scheme variables never reach shipped builds.
actor AppAttestClient {
    static let shared = AppAttestClient()

    enum Failure: LocalizedError {
        case unsupported
        case appleUnavailable
        case couldNotVerify

        var errorDescription: String? {
            switch self {
            case .unsupported:
                "AI estimates need a real iPhone — this device can't prove the app is genuine."
            case .appleUnavailable:
                "Apple's verification service didn't respond — try again in a moment."
            case .couldNotVerify:
                "This copy of FlexUp couldn't be verified."
            }
        }
    }

    private let service = DCAppAttestService.shared
    private let keyIDDefaultsKey = "flexupAppAttestKeyID"
    private var registration: Task<String, Error>?

    /// Headers proving `body` was sent by this install. Registers the
    /// install first if it hasn't been yet.
    func headers(for body: Data, baseURL: URL) async throws -> [String: String] {
        #if DEBUG
        if !service.isSupported,
           let token = ProcessInfo.processInfo.environment["FLEXUP_DEV_TOKEN"], !token.isEmpty {
            return ["X-FlexUp-Dev-Token": token]
        }
        #endif
        guard service.isSupported else { throw Failure.unsupported }

        do {
            return try await signedHeaders(for: body, baseURL: baseURL)
        } catch let error as DCError where error.code == .invalidKey {
            // The key is gone (restore to a new device, reinstall, OS reset).
            // Start over with a fresh one, once.
            forgetKey()
            return try await signedHeaders(for: body, baseURL: baseURL)
        }
    }

    /// Drop the registered key so the next request registers a new one —
    /// used when the server says it doesn't recognise this install.
    func forgetKey() {
        UserDefaults.standard.removeObject(forKey: keyIDDefaultsKey)
    }

    // MARK: - Private

    private func signedHeaders(for body: Data, baseURL: URL) async throws -> [String: String] {
        let keyID = try await registeredKeyID(baseURL: baseURL)
        let challenge = try await fetchChallenge(baseURL: baseURL)
        var clientData = Data(challenge.utf8)
        clientData.append(body)
        let assertion = try await mapAppleErrors {
            try await self.service.generateAssertion(keyID, clientDataHash: Data(SHA256.hash(data: clientData)))
        }
        return [
            "X-FlexUp-Key-Id": keyID,
            "X-FlexUp-Challenge": challenge,
            "X-FlexUp-Assertion": assertion.base64EncodedString(),
        ]
    }

    private func registeredKeyID(baseURL: URL) async throws -> String {
        if let existing = UserDefaults.standard.string(forKey: keyIDDefaultsKey) { return existing }
        if let registration { return try await registration.value }

        let task = Task { try await self.register(baseURL: baseURL) }
        registration = task
        defer { registration = nil }
        let keyID = try await task.value
        // Stored only after the server accepted it; a failed attempt just
        // means a fresh key next time (Apple attests each key only once).
        UserDefaults.standard.set(keyID, forKey: keyIDDefaultsKey)
        return keyID
    }

    private func register(baseURL: URL) async throws -> String {
        let keyID = try await mapAppleErrors { try await self.service.generateKey() }
        let challenge = try await fetchChallenge(baseURL: baseURL)
        let attestation = try await mapAppleErrors {
            try await self.service.attestKey(keyID, clientDataHash: Data(SHA256.hash(data: Data(challenge.utf8))))
        }

        let body = try JSONSerialization.data(withJSONObject: [
            "key_id": keyID,
            "attestation": attestation.base64EncodedString(),
            "challenge": challenge,
        ])
        var request = URLRequest(url: baseURL.appendingPathComponent("v1/attest/register"))
        request.httpMethod = "POST"
        request.timeoutInterval = 30
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = body
        let (data, response) = try await URLSession.shared.data(for: request)
        try ServerError.check(data: data, response: response)
        return keyID
    }

    private func fetchChallenge(baseURL: URL) async throws -> String {
        var request = URLRequest(url: baseURL.appendingPathComponent("v1/attest/challenge"))
        request.httpMethod = "POST"
        request.timeoutInterval = 20
        let (data, response) = try await URLSession.shared.data(for: request)
        try ServerError.check(data: data, response: response)
        struct Challenge: Decodable { let challenge: String }
        guard let challenge = try? JSONDecoder().decode(Challenge.self, from: data).challenge else {
            throw Failure.couldNotVerify
        }
        return challenge
    }

    /// Apple's DeviceCheck errors, in words a person can act on. `invalidKey`
    /// passes through so `headers(for:)` can start over with a new key.
    private func mapAppleErrors<T>(_ operation: () async throws -> T) async throws -> T {
        do {
            return try await operation()
        } catch let error as DCError {
            switch error.code {
            case .invalidKey: throw error
            case .serverUnavailable: throw Failure.appleUnavailable
            case .featureUnsupported: throw Failure.unsupported
            default: throw Failure.couldNotVerify
            }
        }
    }
}

/// An error response from the FlexUp server:
/// `{ "error": { "type": ..., "message": ... } }`.
struct ServerError: LocalizedError {
    let status: Int
    let type: String
    let message: String

    var errorDescription: String? { message }

    /// Throws unless `response` is a 200.
    static func check(data: Data, response: URLResponse) throws {
        guard let http = response as? HTTPURLResponse else {
            throw ServerError(status: 0, type: "no_response", message: "No response from the FlexUp server.")
        }
        guard http.statusCode != 200 else { return }
        struct Envelope: Decodable {
            struct Detail: Decodable {
                let type: String
                let message: String
            }

            let error: Detail
        }
        let detail = try? JSONDecoder().decode(Envelope.self, from: data).error
        throw ServerError(
            status: http.statusCode,
            type: detail?.type ?? "http_\(http.statusCode)",
            message: detail?.message ?? "The FlexUp server had a problem (\(http.statusCode))."
        )
    }
}
