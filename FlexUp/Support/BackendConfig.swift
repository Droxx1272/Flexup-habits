import Foundation

/// Where the FlexUp server lives. The server (see `backend/`) holds the
/// Anthropic key, so nothing secret ships in the app; `AppAttestClient`
/// proves each request comes from a genuine copy of it.
enum BackendConfig {
    /// Paste your Worker URL here after `npm run deploy` in `backend/`,
    /// e.g. "https://flexup-api.your-subdomain.workers.dev". It isn't a
    /// secret — it's safe to commit.
    static let baseURLString = ""

    static var baseURL: URL? {
        let trimmed = baseURLString.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : URL(string: trimmed)
    }

    static var isConfigured: Bool { baseURL != nil }
}
