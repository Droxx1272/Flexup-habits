import SwiftUI

/// Top-right of every tab: messages, the notification bell, and your
/// profile photo — each with a count when something's waiting.
struct HeaderActions: View {
    enum Route: String, Identifiable {
        case messages, notifications, profile
        var id: String { rawValue }
    }

    @Environment(AppStore.self) private var store
    @State private var route: Route?

    private var community: CommunityStore { store.community }

    var body: some View {
        HStack(spacing: 16) {
            if community.isSignedIn {
                iconButton("bubble.left.and.bubble.right", count: community.badges.messages, label: "Messages") {
                    route = .messages
                }
                iconButton("bell", count: community.badges.notifications + community.badges.requests, label: "Notifications") {
                    route = .notifications
                }
            }
            Button {
                route = .profile
            } label: {
                ProfileAvatar(
                    name: community.me?.name ?? store.profile?.name ?? store.account?.name ?? "",
                    avatarId: community.me?.avatarId,
                    size: 38,
                    ring: true
                )
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Your profile")
        }
        .sheet(item: $route) { route in
            NavigationStack {
                Group {
                    switch route {
                    case .messages: MessagesView()
                    case .notifications: NotificationsView()
                    case .profile: MyProfileView()
                    }
                }
                .communityDestinations()
            }
            .tint(Theme.accent)
        }
    }

    private func iconButton(_ icon: String, count: Int, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 21, weight: .regular))
                .foregroundStyle(Theme.ink)
                .frame(width: 30, height: 30)
                .overlay(alignment: .topTrailing) {
                    if count > 0 {
                        Text(count > 99 ? "99+" : "\(count)")
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 5)
                            .frame(minWidth: 19, minHeight: 19)
                            .background(Theme.danger)
                            .clipShape(Capsule())
                            .offset(x: 9, y: -7)
                    }
                }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(count > 0 ? "\(label), \(count) new" : label)
    }
}

// MARK: - Navigation between community screens

enum CommunityDestination: Hashable {
    case profile(String)
    case post(Post)
    case postID(String)
    case chat(CommunityUser)
    case crew
    case notificationSettings
    case blocked
}

extension View {
    /// Registers every community screen, so any NavigationStack that shows
    /// posts, people or notifications can push the right one.
    func communityDestinations() -> some View {
        navigationDestination(for: CommunityDestination.self) { destination in
            switch destination {
            case .profile(let userID): ProfileView(userID: userID)
            case .post(let post): PostDetailView(post: post)
            case .postID(let postID): PostDetailView(postID: postID)
            case .chat(let user): ChatView(user: user)
            case .crew: CrewView()
            case .notificationSettings: NotificationSettingsView()
            case .blocked: BlockedUsersView()
            }
        }
    }
}

/// Shown where a community screen needs an account and there isn't one.
struct CommunityGateView: View {
    @Environment(AppStore.self) private var store
    @State private var showAuth = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            if !store.community.isAvailable {
                EmptyStateCard(
                    icon: "person.2",
                    title: "Community is almost here",
                    message: "Profiles, posts and messages need the FlexUp server. Once it's connected, it all switches on here."
                )
            } else {
                FlexCard {
                    VStack(alignment: .leading, spacing: 14) {
                        IconBadge(systemName: "person.2.fill")
                        Text("DO IT TOGETHER")
                            .font(.flexDisplay(26))
                            .foregroundStyle(Theme.ink)
                        Text("People who tell a friend follow through far more often. Create your FlexUp account to get a profile, post your wins, and message your crew.")
                            .font(.flexCaption())
                            .foregroundStyle(Theme.inkSubtle)
                        Button("Create account or log in") {
                            showAuth = true
                        }
                        .buttonStyle(PrimaryButtonStyle())
                    }
                }
            }
        }
        .sheet(isPresented: $showAuth) {
            CommunityAuthSheet(initialMode: .create)
        }
    }
}
