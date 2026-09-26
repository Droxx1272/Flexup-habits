import Foundation
import UIKit

/// Posts, kudos, comments, messages, notifications, profiles, photos,
/// blocking and reporting. Screens that need a one-off list (a thread, a
/// post's comments, someone's profile) get it returned rather than stored,
/// so opening one profile never disturbs another.
extension CommunityStore {

    func imageURL(_ id: String?) -> URL? {
        guard let id, let base = BackendConfig.baseURL else { return nil }
        return base.appendingPathComponent("v1/images/\(id)")
    }

    // MARK: - Photos

    /// Uploads a photo (downscaled to `maxEdge`) and returns its ID.
    func uploadImage(_ image: UIImage, maxEdge: CGFloat) async throws -> String {
        guard let data = image.flexJPEGData(maxEdge: maxEdge, quality: 0.72) else {
            throw ServerError(status: 0, type: "bad_image", message: "Couldn't read that photo.")
        }
        let response: ImageResponse = try await requireAPI().upload("v1/images", data: data, contentType: "image/jpeg")
        return response.id
    }

    @MainActor
    func setAvatar(_ image: UIImage) async throws {
        let id = try await uploadImage(image, maxEdge: 480)
        try await updateProfile(["avatar_id": id])
    }

    // MARK: - Header badges

    @MainActor
    func refreshBadges() async {
        guard isSignedIn, let api else { return }
        if let value: Badges = try? await api.get("v1/badges") {
            badges = value
        }
    }

    // MARK: - Posts

    @MainActor
    func loadPosts() async {
        guard isSignedIn, let api else { return }
        do {
            let response: PostsResponse = try await api.get("v1/posts")
            posts = response.posts
            hasMorePosts = response.posts.count >= 30
        } catch {
            handle(error)
        }
    }

    @MainActor
    func loadMorePosts() async {
        guard isSignedIn, let api, let last = posts.last else { return }
        do {
            let response: PostsResponse = try await api.get(
                "v1/posts",
                query: ["before": CommunityAPI.dateFormatter.string(from: last.createdAt)]
            )
            let known = Set(posts.map(\.id))
            posts.append(contentsOf: response.posts.filter { !known.contains($0.id) })
            hasMorePosts = response.posts.count >= 30
        } catch {
            handle(error)
        }
    }

    @MainActor
    func createPost(text: String, image: UIImage?) async throws {
        var body: [String: Any] = ["text": text]
        if let image {
            body["image_id"] = try await uploadImage(image, maxEdge: 1080)
        }
        let response: PostResponse = try await requireAPI().post("v1/posts", body)
        posts.insert(response.post, at: 0)
    }

    @MainActor
    func post(id: String) async throws -> Post {
        let response: PostResponse = try await requireAPI().get("v1/posts/\(id)")
        return response.post
    }

    @MainActor
    func deletePost(_ post: Post) async {
        posts.removeAll { $0.id == post.id }
        do {
            let _: OKResponse = try await requireAPI().post("v1/posts/\(post.id)/delete")
        } catch {
            handle(error)
        }
    }

    /// Toggle kudos. Updates instantly; returns the updated post for screens
    /// that hold their own copy.
    @MainActor
    @discardableResult
    func toggleKudos(_ post: Post) async -> Post {
        var updated = post
        updated.gaveKudos.toggle()
        if updated.gaveKudos, let me {
            updated.kudos.append(me.asUser)
        } else if let me {
            updated.kudos.removeAll { $0.id == me.id }
        }
        if let index = posts.firstIndex(where: { $0.id == post.id }) {
            posts[index] = updated
        }
        do {
            let _: OKResponse = try await requireAPI().post("v1/posts/\(post.id)/kudos", ["on": updated.gaveKudos])
        } catch {
            handle(error)
        }
        return updated
    }

    @MainActor
    func comments(on post: Post) async throws -> [PostComment] {
        let response: CommentsResponse = try await requireAPI().get("v1/posts/\(post.id)/comments")
        if let index = posts.firstIndex(where: { $0.id == post.id }) {
            posts[index].commentCount = response.comments.count
        }
        return response.comments
    }

    @MainActor
    func addComment(_ text: String, on post: Post) async throws -> [PostComment] {
        let _: OKResponse = try await requireAPI().post("v1/posts/\(post.id)/comments", ["text": text])
        return try await comments(on: post)
    }

    @MainActor
    func deleteComment(_ comment: PostComment, on post: Post) async throws -> [PostComment] {
        let _: OKResponse = try await requireAPI().post("v1/comments/\(comment.id)/delete")
        return try await comments(on: post)
    }

    // MARK: - Notifications

    @MainActor
    func loadNotifications() async {
        guard isSignedIn, let api else { return }
        do {
            let response: NotificationsResponse = try await api.get("v1/notifications")
            notifications = response.notifications
        } catch {
            handle(error)
        }
    }

    @MainActor
    func markNotificationsRead() async {
        guard badges.notifications > 0 || notifications.contains(where: { !$0.isRead }) else { return }
        badges.notifications = 0
        let _: OKResponse? = try? await requireAPI().post("v1/notifications/read")
    }

    // MARK: - Messages

    @MainActor
    func loadThreads() async {
        guard isSignedIn, let api else { return }
        do {
            let response: ThreadsResponse = try await api.get("v1/messages")
            threads = response.threads
            badges.messages = response.threads.reduce(0) { $0 + $1.unread }
        } catch {
            handle(error)
        }
    }

    /// The conversation with `user`. Pass `after` to fetch only what's new;
    /// the server includes the boundary message, so callers de-duplicate by ID.
    @MainActor
    func messages(with user: CommunityUser, after: Date? = nil) async throws -> [DirectMessage] {
        var query: [String: String] = [:]
        if let after { query["after"] = CommunityAPI.dateFormatter.string(from: after) }
        let response: MessagesResponse = try await requireAPI().get("v1/messages/\(user.id)", query: query)
        if let index = threads.firstIndex(where: { $0.id == user.id }), threads[index].unread > 0 {
            badges.messages = max(0, badges.messages - threads[index].unread)
            threads[index].unread = 0
        }
        return response.messages
    }

    @MainActor
    func send(_ text: String, to user: CommunityUser) async throws -> DirectMessage {
        let response: MessageResponse = try await requireAPI().post("v1/messages/\(user.id)", ["text": text])
        return response.message
    }

    // MARK: - Profiles

    @MainActor
    func profile(of userID: String) async throws -> CommunityProfile {
        let response: ProfileResponse = try await requireAPI().get("v1/users/\(userID)")
        return response.profile
    }

    @MainActor
    func posts(of userID: String) async throws -> [Post] {
        let response: PostsResponse = try await requireAPI().get("v1/users/\(userID)/posts")
        return response.posts
    }

    // MARK: - Safety

    @MainActor
    func block(_ user: CommunityUser, day: String) async {
        friends.removeAll { $0.user.id == user.id }
        posts.removeAll { $0.user.id == user.id }
        feed.removeAll { $0.user.id == user.id }
        threads.removeAll { $0.user.id == user.id }
        do {
            let _: OKResponse = try await requireAPI().post("v1/users/\(user.id)/block")
        } catch {
            handle(error)
        }
        await refresh(day: day)
    }

    @MainActor
    func unblock(_ user: CommunityUser) async throws {
        let _: OKResponse = try await requireAPI().post("v1/users/\(user.id)/unblock")
    }

    @MainActor
    func blockedUsers() async throws -> [CommunityUser] {
        let response: UsersResponse = try await requireAPI().get("v1/blocked")
        return response.users
    }

    /// `type` is "post", "comment", "message" or "user".
    @MainActor
    func report(type: String, id: String, reason: ReportReason) async throws {
        let _: OKResponse = try await requireAPI().post("v1/reports", ["type": type, "id": id, "reason": reason.rawValue])
    }

    @MainActor
    func updateNotifyPrefs(_ prefs: NotifyPrefs) async throws {
        try await updateProfile(["notify_prefs": [
            "friends": prefs.friends,
            "nudges": prefs.nudges,
            "cheers": prefs.cheers,
            "comments": prefs.comments,
            "messages": prefs.messages,
        ]])
    }
}
