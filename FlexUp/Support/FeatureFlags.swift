import Foundation

/// Switches for features that are built but not shipping yet.
enum FeatureFlags {
    /// Community: the feed, posts, kudos, comments, messages, the bell,
    /// friends, nudges, and sharing activity. Off for the first App Store
    /// release, which shows "Coming soon" instead. Accounts (sign up / log
    /// in / delete) work either way. Flip to `true` once the moderation
    /// workflow in `backend/README.md` is being run.
    static let community = false
}
