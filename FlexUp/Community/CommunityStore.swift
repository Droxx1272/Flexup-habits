import Foundation
import Observation

/// Friends, their progress, cheers and nudges — everything that needs the
/// FlexUp server. Owned by `AppStore` (as `store.community`) so there's still
/// one place the app's state comes from; views call these methods and never
/// mutate the arrays themselves.
///
/// Anything that changes observed state runs on the main actor.
@Observable
final class CommunityStore {
    private(set) var me: CommunityMe?
    // Settable app-wide only so the social extension (another file) can
    // update them; views still go through methods.
    var friends: [FriendStatus] = []
    private(set) var incoming: [CommunityUser] = []
    private(set) var outgoing: [CommunityUser] = []
    var feed: [FeedEvent] = []
    private(set) var nudges: [Nudge] = []
    /// Posts from you and your friends, newest first.
    var posts: [Post] = []
    var hasMorePosts = false
    var notifications: [AppNotification] = []
    var threads: [MessageThread] = []
    /// Counts for the header's chat, bell and friend-request badges.
    var badges = Badges()
    private(set) var isRefreshing = false
    private(set) var hasLoaded = false
    /// Last thing that went wrong, in plain words. Views show and clear it.
    var errorMessage: String?
    private(set) var isSignedIn: Bool

    @ObservationIgnored private var token: String?
    @ObservationIgnored private var pending: [PendingActivity]
    @ObservationIgnored private var isFlushing = false
    private static let pendingKey = "flexupPendingActivities"

    var isAvailable: Bool { BackendConfig.isConfigured && FeatureFlags.cloudAccounts }

    init() {
        let savedToken = Keychain.read()
        token = savedToken
        isSignedIn = savedToken != nil
        pending = Self.loadPending()
    }

    private static func loadPending() -> [PendingActivity] {
        guard let data = UserDefaults.standard.data(forKey: pendingKey),
              let saved = try? JSONDecoder().decode([PendingActivity].self, from: data) else { return [] }
        return saved
    }

    var api: CommunityAPI? {
        BackendConfig.baseURL.map { CommunityAPI(baseURL: $0, token: token) }
    }

    func requireAPI() throws -> CommunityAPI {
        guard let api else {
            throw ServerError(status: 0, type: "not_configured", message: "Friends need the FlexUp server, which isn't connected yet.")
        }
        return api
    }

    // MARK: - Account

    @MainActor
    func signUp(name: String, email: String, password: String) async throws -> CommunityMe {
        let response: AuthResponse = try await requireAPI().post("v1/auth/signup", [
            "name": name, "email": email, "password": password,
        ])
        return startSession(response)
    }

    @MainActor
    func logIn(email: String, password: String) async throws -> CommunityMe {
        let response: AuthResponse = try await requireAPI().post("v1/auth/login", [
            "email": email, "password": password,
        ])
        return startSession(response)
    }

    /// `identityToken` from `ASAuthorizationAppleIDCredential`; Apple only
    /// shares the name the first time, so pass it along when present.
    @MainActor
    func signInWithApple(identityToken: String, name: String) async throws -> CommunityMe {
        let response: AuthResponse = try await requireAPI().post("v1/auth/apple", [
            "identity_token": identityToken, "name": name,
        ])
        return startSession(response)
    }

    @MainActor
    private func startSession(_ response: AuthResponse) -> CommunityMe {
        token = response.token
        Keychain.save(response.token)
        me = response.user
        isSignedIn = true
        return response.user
    }

    @MainActor
    func logOut() async {
        if let api, token != nil {
            let _: OKResponse? = try? await api.post("v1/auth/logout")
        }
        clearSession()
    }

    /// Permanently deletes the account and everything shared with friends.
    @MainActor
    func deleteAccount() async throws {
        let _: OKResponse = try await requireAPI().post("v1/me/delete")
        clearSession()
    }

    @MainActor
    private func clearSession() {
        token = nil
        Keychain.delete()
        isSignedIn = false
        me = nil
        friends = []
        incoming = []
        outgoing = []
        feed = []
        nudges = []
        posts = []
        hasMorePosts = false
        notifications = []
        threads = []
        badges = Badges()
        hasLoaded = false
        pending = []
        savePending()
    }

    @MainActor
    func updateProfile(name: String, handle: String, identity: String) async throws {
        try await updateProfile(["name": name, "handle": handle, "identity": identity])
    }

    /// Any of: name, handle, identity, location, bio, goal, avatar_id, notify_prefs.
    @MainActor
    func updateProfile(_ fields: [String: Any]) async throws {
        let response: MeResponse = try await requireAPI().post("v1/me", fields)
        me = response.user
    }

    // MARK: - Loading

    /// Everything the Friends screen shows. `day` is the app's day key, so
    /// "today" means the same thing on both sides.
    @MainActor
    func refresh(day: String) async {
        guard isSignedIn, let api, !isRefreshing else { return }
        isRefreshing = true
        defer { isRefreshing = false }
        await flushPending()
        do {
            async let meResponse: MeResponse = api.get("v1/me")
            async let friendsResponse: FriendsResponse = api.get("v1/friends", query: ["day": day])
            async let feedResponse: FeedResponse = api.get("v1/feed")
            async let nudgesResponse: NudgesResponse = api.get("v1/nudges")
            async let postsResponse: PostsResponse = api.get("v1/posts")
            async let badgesResponse: Badges = api.get("v1/badges")
            let (meValue, friendsValue, feedValue, nudgesValue) = try await (meResponse, friendsResponse, feedResponse, nudgesResponse)
            let (postsValue, badgesValue) = try await (postsResponse, badgesResponse)
            me = meValue.user
            posts = postsValue.posts
            hasMorePosts = postsValue.posts.count >= 30
            badges = badgesValue
            friends = friendsValue.friends
            incoming = friendsValue.incoming
            outgoing = friendsValue.outgoing
            feed = feedValue.events
            nudges = nudgesValue.nudges
            hasLoaded = true
        } catch {
            handle(error)
        }
    }

    @MainActor
    func handle(_ error: Error) {
        if let serverError = error as? ServerError, serverError.type == "signed_out" {
            clearSession()
            errorMessage = "You were signed out of FlexUp friends. Sign in again."
        } else if let urlError = error as? URLError, urlError.code == .notConnectedToInternet {
            errorMessage = "You're offline. Friends will update when you're back."
        } else {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Friends

    /// Returns a line to show: "Request sent to Ana" / "You and Ana are friends".
    @MainActor
    func addFriend(_ query: String, day: String) async throws -> String {
        let response: AddFriendResponse = try await requireAPI().post("v1/friends/add", ["query": query])
        await refresh(day: day)
        return response.status == "friends"
            ? "You and \(response.user.name) are now friends."
            : "Request sent to \(response.user.name). You'll connect when they accept."
    }

    @MainActor
    func respond(to user: CommunityUser, accept: Bool, day: String) async {
        do {
            let _: OKResponse = try await requireAPI().post("v1/friends/respond", ["user_id": user.id, "accept": accept])
            await refresh(day: day)
        } catch {
            handle(error)
        }
    }

    /// Unfriend, or cancel a sent request. Also works as a block: neither
    /// side sees the other's activity afterwards.
    @MainActor
    func remove(_ user: CommunityUser, day: String) async {
        friends.removeAll { $0.user.id == user.id }
        outgoing.removeAll { $0.id == user.id }
        feed.removeAll { $0.user.id == user.id }
        do {
            let _: OKResponse = try await requireAPI().post("v1/friends/remove", ["user_id": user.id])
        } catch {
            handle(error)
        }
        await refresh(day: day)
    }

    // MARK: - Cheers & nudges

    /// Toggle a cheer. Updates instantly, then syncs.
    @MainActor
    func cheer(_ event: FeedEvent, with emoji: String) async {
        guard let index = feed.firstIndex(where: { $0.id == event.id }) else { return }
        let newValue: String? = feed[index].myCheer == emoji ? nil : emoji
        feed[index].cheers.removeAll { $0.name == "You" }
        if let newValue { feed[index].cheers.append(FeedCheer(name: "You", emoji: newValue)) }
        feed[index].myCheer = newValue
        do {
            let _: OKResponse = try await requireAPI().post("v1/events/cheer", [
                "event_id": event.id, "emoji": newValue.map { $0 as Any } ?? NSNull(),
            ])
        } catch {
            handle(error)
        }
    }

    @MainActor
    func nudge(_ friend: FriendStatus, kind: NudgeKind, day: String) async {
        if let index = friends.firstIndex(where: { $0.id == friend.id }) {
            friends[index].nudgedToday = true
        }
        do {
            let _: OKResponse = try await requireAPI().post("v1/nudges", [
                "to": friend.user.id, "kind": kind.rawValue, "day": day,
            ])
        } catch let error as ServerError where error.type == "already_nudged" {
            // Already sent from another device — the button state is right.
        } catch {
            if let index = friends.firstIndex(where: { $0.id == friend.id }) {
                friends[index].nudgedToday = false
            }
            handle(error)
        }
    }

    @MainActor
    func dismissNudges() async {
        let ids = nudges.map(\.id)
        nudges = []
        guard !ids.isEmpty else { return }
        let _: OKResponse? = try? await requireAPI().post("v1/nudges/seen", ["ids": ids])
    }

    // MARK: - Sharing

    /// Queue an activity for friends to see. Safe to call from anywhere and
    /// offline; it's delivered on the next successful sync.
    func share(_ activity: PendingActivity) {
        guard isAvailable, isSignedIn else { return }
        pending.append(activity)
        savePending()
        Task { @MainActor in
            await self.flushPending()
        }
    }

    @MainActor
    private func flushPending() async {
        guard !isFlushing, isSignedIn, let api else { return }
        isFlushing = true
        defer { isFlushing = false }

        while let next = pending.first {
            var body: [String: Any] = [
                "client_id": next.clientID,
                "kind": next.kind.rawValue,
                "title": next.title,
                "detail": next.detail,
                "day": next.day,
                "occurred_at": CommunityAPI.dateFormatter.string(from: next.occurredAt),
            ]
            if let streak = next.streak { body["streak"] = streak }
            do {
                let _: OKResponse = try await api.post("v1/events", body)
            } catch let error as ServerError where error.status == 400 {
                // The server will never accept this one; don't retry forever.
            } catch {
                return // offline or signed out. Try again next time
            }
            pending.removeFirst()
            savePending()
        }
    }

    private func savePending() {
        if let data = try? JSONEncoder().encode(pending) {
            UserDefaults.standard.set(data, forKey: Self.pendingKey)
        }
    }
}
