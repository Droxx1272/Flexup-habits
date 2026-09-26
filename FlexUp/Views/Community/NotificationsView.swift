import SwiftUI

/// The bell: friend requests to answer, then everything your crew did that
/// involves you — kudos, comments, cheers, nudges, new friends.
struct NotificationsView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var loaded = false

    private var community: CommunityStore { store.community }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if !community.isSignedIn {
                    CommunityGateView()
                } else {
                    if !community.incoming.isEmpty {
                        requests
                    }
                    if community.notifications.isEmpty {
                        if loaded {
                            EmptyStateCard(
                                icon: "bell",
                                title: "All quiet",
                                message: "Kudos, comments, cheers and nudges from your crew show up here."
                            )
                        } else {
                            ProgressView().frame(maxWidth: .infinity).padding(.vertical, 40)
                        }
                    } else {
                        VStack(spacing: 8) {
                            ForEach(community.notifications) { notification in
                                NavigationLink(value: destination(for: notification)) {
                                    row(notification)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    NavigationLink(value: CommunityDestination.notificationSettings) {
                        Label("Notification settings", systemImage: "slider.horizontal.3")
                            .font(.flexCaption())
                            .foregroundStyle(Theme.accent)
                    }
                    .padding(.top, 6)
                }
            }
            .padding(20)
        }
        .background(Theme.background)
        .navigationTitle("Notifications")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Done") { dismiss() }
            }
        }
        .refreshable { await community.loadNotifications() }
        .task {
            await community.loadNotifications()
            loaded = true
            // Seen once the list has been on screen for a moment.
            try? await Task.sleep(for: .seconds(1.5))
            await community.markNotificationsRead()
        }
    }

    private var requests: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionHeader(title: "Friend requests")
            ForEach(community.incoming) { user in
                HStack(spacing: 12) {
                    NavigationLink(value: CommunityDestination.profile(user.id)) {
                        HStack(spacing: 12) {
                            ProfileAvatar(user: user, size: 42)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(user.name)
                                    .font(.flexBodyBold())
                                    .foregroundStyle(Theme.ink)
                                Text("@\(user.handle)")
                                    .font(.flexCaption())
                                    .foregroundStyle(Theme.inkSubtle)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                    Spacer()
                    Button {
                        Task { await community.respond(to: user, accept: false, day: store.todayKey) }
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(Theme.inkSubtle)
                            .frame(width: 34, height: 34)
                            .background(Theme.background)
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                    Button {
                        Task { await community.respond(to: user, accept: true, day: store.todayKey) }
                    } label: {
                        Text("Accept")
                            .font(.flexCaption())
                            .foregroundStyle(Theme.background)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 9)
                            .background(Theme.ink)
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
                .padding(12)
                .background(Theme.card)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
        }
    }

    private func row(_ notification: AppNotification) -> some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack(alignment: .bottomTrailing) {
                ProfileAvatar(user: notification.actor, size: 44)
                Image(systemName: notification.icon)
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 20, height: 20)
                    .background(Theme.accent)
                    .clipShape(Circle())
                    .overlay(Circle().stroke(Theme.card, lineWidth: 2))
                    .offset(x: 4, y: 4)
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(notification.sentence)
                    .font(notification.isRead ? .flexBody() : .flexBodyBold())
                    .foregroundStyle(Theme.ink)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                Text(notification.createdAt.formatted(.relative(presentation: .named)).uppercased())
                    .font(.flexMono(9))
                    .tracking(1)
                    .foregroundStyle(Theme.inkSubtle)
            }
            Spacer(minLength: 0)
            if !notification.isRead {
                Circle()
                    .fill(Theme.accent)
                    .frame(width: 8, height: 8)
                    .padding(.top, 6)
            }
        }
        .padding(12)
        .background(notification.isRead ? Theme.card : Theme.accentSoft)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func destination(for notification: AppNotification) -> CommunityDestination {
        if let postID = notification.postId { return .postID(postID) }
        if notification.type == "friend_request" { return .crew }
        return .profile(notification.actor.id)
    }
}
