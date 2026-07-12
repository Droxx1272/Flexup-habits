import SwiftUI
import Charts

/// Identity over popularity: no follower counts, no vanity metrics.
/// Who you're becoming, how consistent you are, what you've earned.
struct ProfileView: View {
    @Environment(AppStore.self) private var store

    private let columns = [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    identityHeader
                    statTiles
                    consistencyCard
                    achievementsSection
                    communitiesSection
                    interestsSection
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 24)
            }
            .scrollIndicators(.hidden)
            .background(Theme.background)
            .navigationTitle("Profile")
        }
    }

    // MARK: Identity

    private var identityHeader: some View {
        FlexCard {
            HStack(spacing: 16) {
                AvatarCircle(name: store.profile?.name ?? "You", size: 64)
                VStack(alignment: .leading, spacing: 4) {
                    Text(store.profile?.name ?? "You")
                        .font(.flexHeading())
                        .foregroundStyle(Theme.ink)
                    Text("Becoming \(store.profile?.identityStatement ?? "consistent")")
                        .font(.flexBody())
                        .foregroundStyle(Theme.accent)
                    if let joined = store.profile?.joinedAt {
                        Text("Member since \(joined.formatted(.dateTime.month(.wide).year()))")
                            .font(.flexCaption())
                            .foregroundStyle(Theme.inkSubtle)
                    }
                }
                Spacer()
            }
        }
    }

    // MARK: Stats

    private var statTiles: some View {
        HStack(spacing: 10) {
            statTile(value: "\(store.currentStreak)", label: "Streak", icon: "flame.fill", tint: Theme.amber)
            statTile(value: "\(store.bestStreak)", label: "Best", icon: "trophy.fill", tint: Theme.accent)
            statTile(value: "\(store.totalCompleted)", label: "Done", icon: "checkmark.circle.fill", tint: Theme.accent)
            statTile(value: "\(store.consistencyPercent)%", label: "This week", icon: "chart.bar.fill", tint: Theme.accent)
        }
    }

    private func statTile(value: String, label: String, icon: String, tint: Color) -> some View {
        VStack(spacing: 5) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(tint)
            Text(value)
                .font(.system(.title3, design: .rounded, weight: .bold))
                .foregroundStyle(Theme.ink)
                .minimumScaleFactor(0.7)
            Text(label)
                .font(.system(.caption2, design: .rounded, weight: .medium))
                .foregroundStyle(Theme.inkSubtle)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(Theme.card)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    // MARK: Consistency

    private var consistencyCard: some View {
        FlexCard {
            VStack(alignment: .leading, spacing: 12) {
                SectionHeader(title: "Consistency", subtitle: "Completions over the last 7 days.")
                Chart(store.weeklyStats()) { stat in
                    BarMark(
                        x: .value("Day", stat.label),
                        y: .value("Planned", stat.planned)
                    )
                    .foregroundStyle(Theme.accentSoft)
                    .cornerRadius(5)

                    BarMark(
                        x: .value("Day", stat.label),
                        y: .value("Done", stat.completed)
                    )
                    .foregroundStyle(Theme.accent)
                    .cornerRadius(5)
                }
                .chartYAxis(.hidden)
                .frame(height: 130)
            }
        }
    }

    // MARK: Achievements

    private var achievementsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Achievements", subtitle: "\(store.earnedAchievements.count) of \(store.achievements.count) earned.")
            LazyVGrid(columns: columns, spacing: 10) {
                ForEach(store.achievements) { achievement in
                    achievementTile(achievement)
                }
            }
        }
    }

    private func achievementTile(_ achievement: Achievement) -> some View {
        let hiddenAndLocked = achievement.isHidden && !achievement.isEarned
        return VStack(spacing: 7) {
            ZStack {
                Circle()
                    .fill(achievement.isEarned ? Theme.accentSoft : Theme.inkSubtle.opacity(0.1))
                    .frame(width: 46, height: 46)
                Image(systemName: hiddenAndLocked ? "questionmark" : achievement.icon)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(achievement.isEarned ? Theme.accent : Theme.inkSubtle.opacity(0.6))
            }
            Text(hiddenAndLocked ? "Hidden" : achievement.title)
                .font(.system(.caption2, design: .rounded, weight: .semibold))
                .foregroundStyle(achievement.isEarned ? Theme.ink : Theme.inkSubtle)
                .multilineTextAlignment(.center)
                .lineLimit(2)
            Text(achievement.category.label)
                .font(.system(size: 9, weight: .medium, design: .rounded))
                .foregroundStyle(Theme.inkSubtle)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .padding(.horizontal, 6)
        .background(Theme.card)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .opacity(achievement.isEarned ? 1 : 0.75)
    }

    // MARK: Communities

    private var communitiesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Communities", subtitle: "They organize events, not conversations.")
            ForEach(store.communities) { community in
                FlexCard(padding: 14) {
                    HStack(spacing: 12) {
                        IconBadge(systemName: community.icon, size: 40)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(community.name)
                                .font(.flexBodyBold())
                                .foregroundStyle(Theme.ink)
                            Text(community.nextEvent ?? "\(community.members) members")
                                .font(.flexCaption())
                                .foregroundStyle(Theme.inkSubtle)
                        }
                        Spacer()
                        Button(community.isJoined ? "Joined" : "Join") {
                            store.toggleCommunity(community)
                        }
                        .font(.flexCaption())
                        .foregroundStyle(community.isJoined ? Theme.accent : .white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 7)
                        .background(community.isJoined ? Theme.accentSoft : Theme.accent)
                        .clipShape(Capsule())
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    // MARK: Interests

    private var interestsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Interests")
            ScrollView(.horizontal) {
                HStack(spacing: 8) {
                    ForEach(store.profile?.interests ?? []) { interest in
                        TagPill(text: interest.label, tint: Theme.accent)
                    }
                }
            }
            .scrollIndicators(.hidden)
        }
    }
}

#Preview {
    ProfileView()
        .environment(AppStore())
}
