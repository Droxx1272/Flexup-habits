import SwiftUI

/// The Community segment of Today — Strava-style, but only your crew:
/// who's shown up today, a composer, and one feed mixing posts (photos,
/// words, kudos, comments) with logged activity (wake-ups, runs, sessions).
/// A plain content view; `TodayView` owns the navigation.
struct CommunitySection: View {
    @Environment(AppStore.self) private var store
    @State private var showComposer = false
    @State private var isLoadingMore = false

    private var community: CommunityStore { store.community }

    private enum FeedItem: Identifiable {
        case post(Post)
        case activity(FeedEvent)

        var id: String {
            switch self {
            case .post(let post): "post-\(post.id)"
            case .activity(let event): "activity-\(event.id)"
            }
        }

        var date: Date {
            switch self {
            case .post(let post): post.createdAt
            case .activity(let event): event.occurredAt
            }
        }
    }

    private var items: [FeedItem] {
        (community.posts.map(FeedItem.post) + community.feed.map(FeedItem.activity))
            .sorted { $0.date > $1.date }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            if !community.isAvailable || !community.isSignedIn {
                CommunityGateView()
            } else {
                if let errorMessage = community.errorMessage {
                    CommunityErrorBanner(message: errorMessage)
                }
                NudgesCard()
                crewStrip
                requestsBanner
                composer
                feed
            }
        }
        .sheet(isPresented: $showComposer) {
            PostComposerSheet()
        }
        .task(id: community.isSignedIn) {
            if community.isSignedIn { await community.refresh(day: store.todayKey) }
        }
    }

    // MARK: Crew strip

    private var crewStrip: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader(title: "Your crew", subtitle: "A ring means they've shown up today. Long-press to nudge.")
            ScrollView(.horizontal) {
                HStack(alignment: .top, spacing: 14) {
                    NavigationLink(value: CommunityDestination.crew) {
                        VStack(spacing: 6) {
                            Image(systemName: "plus")
                                .font(.system(size: 20, weight: .semibold))
                                .foregroundStyle(Theme.accent)
                                .frame(width: 62, height: 62)
                                .background(Theme.accentSoft)
                                .clipShape(Circle())
                                .overlay(Circle().strokeBorder(Theme.accent.opacity(0.5), style: StrokeStyle(lineWidth: 1.5, dash: [4, 4])))
                            Text("INVITE")
                                .font(.flexMono(9))
                                .tracking(1)
                                .foregroundStyle(Theme.accent)
                        }
                    }
                    .buttonStyle(.plain)

                    ForEach(community.friends) { friend in
                        NavigationLink(value: CommunityDestination.profile(friend.user.id)) {
                            VStack(spacing: 6) {
                                ProfileAvatar(user: friend.user, size: 62, ring: !friend.todayKinds.isEmpty)
                                    .opacity(friend.todayKinds.isEmpty ? 0.75 : 1)
                                Text(firstName(friend.user.name).uppercased())
                                    .font(.flexMono(9))
                                    .tracking(1)
                                    .foregroundStyle(Theme.ink)
                                    .lineLimit(1)
                                    .frame(maxWidth: 70)
                            }
                        }
                        .buttonStyle(.plain)
                        .contextMenu {
                            if friend.nudgedToday {
                                Text("Already nudged today")
                            } else {
                                ForEach(NudgeKind.allCases) { kind in
                                    Button(kind.message) {
                                        Task { await community.nudge(friend, kind: kind, day: store.todayKey) }
                                    }
                                }
                            }
                        }
                    }
                }
                .padding(.vertical, 2)
            }
            .scrollIndicators(.hidden)
        }
    }

    private func firstName(_ name: String) -> String {
        name.split(separator: " ").first.map(String.init) ?? name
    }

    @ViewBuilder
    private var requestsBanner: some View {
        if !community.incoming.isEmpty {
            NavigationLink(value: CommunityDestination.crew) {
                HStack(spacing: 12) {
                    AvatarStack(names: community.incoming.map(\.name), size: 28, maxShown: 3)
                    Text(community.incoming.count == 1
                         ? "\(community.incoming[0].name) wants to join your crew"
                         : "\(community.incoming.count) people want to join your crew")
                        .font(.flexBodyBold())
                        .foregroundStyle(Theme.ink)
                        .lineLimit(1)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(Theme.inkSubtle)
                }
                .padding(14)
                .background(Theme.accentSoft)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: Composer

    private var composer: some View {
        Button {
            showComposer = true
        } label: {
            HStack(spacing: 12) {
                ProfileAvatar(name: community.me?.name ?? "", avatarId: community.me?.avatarId, size: 40)
                Text("Share a win, a photo, a thought…")
                    .font(.flexBody())
                    .foregroundStyle(Theme.inkSubtle)
                Spacer()
                Image(systemName: "photo")
                    .font(.system(size: 17))
                    .foregroundStyle(Theme.accent)
            }
            .padding(14)
            .background(Theme.card)
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    // MARK: Feed

    private var feed: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Feed", subtitle: "Your crew's posts and real, logged activity.")
            if items.isEmpty {
                Text(community.hasLoaded
                     ? "Quiet in here. Post your next win, or invite someone to keep you honest."
                     : "Loading…")
                    .font(.flexCaption())
                    .foregroundStyle(Theme.inkSubtle)
            } else {
                ForEach(items) { item in
                    switch item {
                    case .post(let post):
                        PostCard(post: post) {
                            Task { await community.toggleKudos(post) }
                        }
                    case .activity(let event):
                        FeedEventRow(event: event) { emoji in
                            Task { await community.cheer(event, with: emoji) }
                        }
                    }
                }
                if community.hasMorePosts {
                    Button {
                        Task {
                            isLoadingMore = true
                            await community.loadMorePosts()
                            isLoadingMore = false
                        }
                    } label: {
                        if isLoadingMore { ProgressView() } else { Text("Load older posts") }
                    }
                    .buttonStyle(SecondaryButtonStyle())
                    .disabled(isLoadingMore)
                }
            }
        }
    }
}
