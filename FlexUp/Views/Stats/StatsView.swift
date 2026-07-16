import SwiftUI
import Charts

/// The everything-view: today's progress, streaks across all four pillars,
/// the weekly chart, progress photos, and achievements. One scroll, whole
/// picture.
struct StatsView: View {
    @Environment(AppStore.self) private var store
    @State private var confirmSignOut = false

    private let achievementColumns = [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    ScreenHeader(title: "Stats", tagline: "The proof, all in one place.")
                    identityRow
                    todayCard
                    pillarTiles
                    consistencyCard
                    photosSection
                    achievementsSection
                    accountSection
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 24)
            }
            .scrollIndicators(.hidden)
            .background(Theme.background)
            .toolbar(.hidden, for: .navigationBar)
        }
    }

    // MARK: Identity

    private var identityRow: some View {
        HStack(spacing: 12) {
            AvatarCircle(name: store.profile?.name ?? "You", size: 46)
            VStack(alignment: .leading, spacing: 2) {
                Text((store.profile?.name ?? "You").uppercased())
                    .font(.flexDisplay(20))
                    .foregroundStyle(Theme.ink)
                Text("BECOMING \((store.profile?.identityStatement ?? "consistent").uppercased())")
                    .font(.flexMono(9))
                    .tracking(1.5)
                    .foregroundStyle(Theme.accent)
            }
            Spacer()
        }
    }

    // MARK: Today

    private var todayCard: some View {
        let today = store.todayCommitments
        let done = today.filter { $0.status == .completed }.count

        return FlexCard {
            HStack(spacing: 16) {
                ZStack {
                    ProgressRing(progress: store.todayProgress)
                        .frame(width: 62, height: 62)
                    Text("\(done)/\(today.count)")
                        .font(.system(.subheadline, weight: .bold))
                        .monospacedDigit()
                        .foregroundStyle(Theme.ink)
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text("TODAY")
                        .font(.flexMono(10))
                        .tracking(2)
                        .foregroundStyle(Theme.inkSubtle)
                    Text(todayMessage(done: done, total: today.count))
                        .font(.flexBodyBold())
                        .foregroundStyle(Theme.ink)
                }
                Spacer()
            }
        }
    }

    private func todayMessage(done: Int, total: Int) -> String {
        if total == 0 { return "Nothing scheduled. The pillars still count." }
        if done == total { return "Everything done. Go live your life." }
        return "\(done) of \(total) done — keep the thread going."
    }

    // MARK: Pillars

    private var pillarTiles: some View {
        VStack(spacing: 10) {
            HStack(spacing: 10) {
                TrackStat(value: "\(store.wakeStreak)", label: "Wake streak")
                TrackStat(value: RunFormat.kilometers(store.totalRunKilometers), label: "KM run")
            }
            HStack(spacing: 10) {
                TrackStat(value: "\(Int(store.totalVolumeKg))", label: "KG lifted")
                TrackStat(value: "\(store.caloriesToday)/\(store.calorieBudget)", label: "KCAL today")
            }
        }
    }

    // MARK: Consistency

    private var consistencyCard: some View {
        FlexCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    SectionHeader(title: "This week", subtitle: "Planned vs completed, last 7 days.")
                    Spacer()
                    Text("\(store.consistencyPercent)%")
                        .font(.flexStat(24))
                        .foregroundStyle(Theme.accent)
                }
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
                .frame(height: 120)
            }
        }
    }

    // MARK: Photos

    private var photosSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Progress photos", subtitle: "Same pose, same spot. The honest graph.")
            PhotoSection()
        }
    }

    // MARK: Achievements

    private var achievementsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Achievements", subtitle: "\(store.earnedAchievements.count) of \(store.achievements.count) earned.")
            LazyVGrid(columns: achievementColumns, spacing: 10) {
                ForEach(store.achievements) { achievement in
                    achievementTile(achievement)
                }
            }
        }
    }

    // MARK: Account

    private var accountSection: some View {
        FlexCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("ACCOUNT")
                    .font(.flexMono(11))
                    .tracking(2)
                    .foregroundStyle(Theme.inkSubtle)
                HStack(spacing: 12) {
                    Image(systemName: store.account?.provider == .apple ? "apple.logo" : "envelope")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Theme.ink)
                        .frame(width: 36, height: 36)
                        .background(Theme.background)
                        .clipShape(Circle())
                    VStack(alignment: .leading, spacing: 2) {
                        Text(store.account?.name.isEmpty == false ? store.account!.name : (store.profile?.name ?? "You"))
                            .font(.flexBodyBold())
                            .foregroundStyle(Theme.ink)
                        if let email = store.account?.email {
                            Text(email)
                                .font(.flexCaption())
                                .foregroundStyle(Theme.inkSubtle)
                        }
                    }
                    Spacer()
                    Button("Sign out") {
                        confirmSignOut = true
                    }
                    .font(.flexCaption())
                    .foregroundStyle(Theme.danger)
                    .buttonStyle(.plain)
                }
            }
        }
        .confirmationDialog("Sign out of FlexUp?", isPresented: $confirmSignOut, titleVisibility: .visible) {
            Button("Sign out", role: .destructive) {
                store.signOut()
            }
            Button("Stay signed in", role: .cancel) {}
        } message: {
            Text("Your data stays on this device and is here when you sign back in.")
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
                .font(.system(.caption2, weight: .semibold))
                .foregroundStyle(achievement.isEarned ? Theme.ink : Theme.inkSubtle)
                .multilineTextAlignment(.center)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .padding(.horizontal, 6)
        .background(Theme.card)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .opacity(achievement.isEarned ? 1 : 0.75)
    }
}

#Preview {
    StatsView()
        .environment(AppStore())
}
