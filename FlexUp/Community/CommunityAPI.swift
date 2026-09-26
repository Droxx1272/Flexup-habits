import Foundation

/// Thin client for the community endpoints. Errors arrive as `ServerError`
/// with a message written for the person holding the phone.
struct CommunityAPI {
    let baseURL: URL
    var token: String?

    private static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()

    static let dateFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()

    func get<T: Decodable>(_ path: String, query: [String: String] = [:]) async throws -> T {
        var components = URLComponents(url: baseURL.appendingPathComponent(path), resolvingAgainstBaseURL: false)
        if !query.isEmpty {
            components?.queryItems = query.map { URLQueryItem(name: $0.key, value: $0.value) }
        }
        guard let url = components?.url else {
            throw ServerError(status: 0, type: "bad_url", message: "The FlexUp server address looks wrong.")
        }
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        return try await send(request)
    }

    func post<T: Decodable>(_ path: String, _ body: [String: Any] = [:]) async throws -> T {
        var request = URLRequest(url: baseURL.appendingPathComponent(path))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        return try await send(request)
    }

    /// Raw upload (photos). Returns the server's JSON reply.
    func upload<T: Decodable>(_ path: String, data: Data, contentType: String) async throws -> T {
        var request = URLRequest(url: baseURL.appendingPathComponent(path))
        request.httpMethod = "POST"
        request.setValue(contentType, forHTTPHeaderField: "Content-Type")
        request.httpBody = data
        return try await send(request, timeout: 60)
    }

    private func send<T: Decodable>(_ request: URLRequest, timeout: TimeInterval = 20) async throws -> T {
        var request = request
        request.timeoutInterval = timeout
        if let token {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        let (data, response) = try await URLSession.shared.data(for: request)
        try ServerError.check(data: data, response: response)
        do {
            return try Self.decoder.decode(T.self, from: data)
        } catch {
            throw ServerError(status: 200, type: "malformed", message: "Got an unexpected response. Try again.")
        }
    }
}

// MARK: - Responses

struct AuthResponse: Decodable {
    let token: String
    let user: CommunityMe
}

struct MeResponse: Decodable {
    let user: CommunityMe
}

struct FriendsResponse: Decodable {
    let friends: [FriendStatus]
    let incoming: [CommunityUser]
    let outgoing: [CommunityUser]
}

struct AddFriendResponse: Decodable {
    let status: String
    let user: CommunityUser
}

struct FeedResponse: Decodable {
    let events: [FeedEvent]
}

struct NudgesResponse: Decodable {
    let nudges: [Nudge]
}

struct OKResponse: Decodable {
    let ok: Bool
}

struct PostsResponse: Decodable {
    let posts: [Post]
}

struct PostResponse: Decodable {
    let post: Post
}

struct CommentsResponse: Decodable {
    let comments: [PostComment]
}

struct NotificationsResponse: Decodable {
    let notifications: [AppNotification]
}

struct ThreadsResponse: Decodable {
    let threads: [MessageThread]
}

struct MessagesResponse: Decodable {
    let messages: [DirectMessage]
}

struct MessageResponse: Decodable {
    let message: DirectMessage
}

struct ProfileResponse: Decodable {
    let profile: CommunityProfile
}

struct UsersResponse: Decodable {
    let users: [CommunityUser]
}

struct ImageResponse: Decodable {
    let id: String
}
