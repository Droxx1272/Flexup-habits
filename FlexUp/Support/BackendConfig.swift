import Foundation

/// Where the FlexUp server lives. The server (see `backend/`) holds the
/// Anthropic key, so nothing secret ships in the app.
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

    /// Random per-install ID. Carries no personal data; the server uses it
    /// only to rate-limit, so one device can't burn through the AI budget.
    static var installID: String {
        let key = "flexupInstallID"
        if let existing = UserDefaults.standard.string(forKey: key) { return existing }
        let fresh = UUID().uuidString
        UserDefaults.standard.set(fresh, forKey: key)
        return fresh
    }
}
