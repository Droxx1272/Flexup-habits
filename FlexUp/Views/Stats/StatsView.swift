import SwiftUI
import Charts

/// The proof: streaks across all four pillars, the weekly chart, habits,
/// body weight, progress photos, and achievements. Presented as the Stats
/// segment of `TodayView`, so it owns no navigation of its own.
struct StatsSection: View {
    @Environment(AppStore.self) private var store
    @State private var confirmSignOut = false
    @State private var confirmDelete = false
    @State private var deleteError: String?
    @State private var showHabits = false

    private let achievementColumns = [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())]

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            identityRow
            pillarTiles
            consistencyCard
            habitsCard
            weightCard
            photosSection
            achievementsSection
            accountSection
        }
        .sheet(isPresented: $showHabits) {
            HabitsSheet()
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

    // MARK: Habits

    private var habitsCard: some View {
        Button {
            showHabits = true
        } label: {
            FlexCard {
                HStack(spacing: 14) {
                    IconBadge(systemName: "repeat", size: 44)
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Habits")
                            .font(.flexBodyBold())
                            .foregroundStyle(Theme.ink)
                        Text(store.habits.isEmpty
                             ? "Add the habits that schedule your days"
                             : "\(store.habits.count) scheduled · tap to add or edit")
                            .font(.flexCaption())
                            .foregroundStyle(Theme.inkSubtle)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(Theme.inkSubtle)
                }
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: Body weight

    private var weightCard: some View {
        Group {
            if store.weightEntries.count >= 2 {
                FlexCard {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            SectionHeader(title: "Body weight", subtitle: "The trend, not any single day.")
                            Spacer()
                            if let latest = store.latestWeight {
                                Text(String(format: "%.1f kg", latest.kilograms))
                                    .font(.flexStat(22))
                                    .foregroundStyle(Theme.accent)
                            }
                        }
                        Chart(store.weightEntries.sorted { $0.date < $1.date }) { entry in
                            LineMark(
                                x: .value("Date", entry.date),
                                y: .value("Kilograms", entry.kilograms)
                            )
                            .foregroundStyle(Theme.accent)
                            .interpolationMethod(.catmullRom)

                            PointMark(
                                x: .value("Date", entry.date),
                                y: .value("Kilograms", entry.kilograms)
                            )
                            .foregroundStyle(Theme.accent)
                        }
                        .chartYScale(domain: .automatic(includesZero: false))
                        .frame(height: 130)
                    }
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
                Button {
                    store.replayIntro()
                } label: {
                    Text("REPLAY THE INTRODUCTION")
                        .font(.flexMono(9))
                        .tracking(1)
                        .foregroundStyle(Theme.accent)
                }
                .buttonStyle(.plain)

                if store.community.isSignedIn {
                    Button {
                        confirmDelete = true
                    } label: {
                        Text("DELETE ACCOUNT")
                            .font(.flexMono(9))
                            .tracking(1)
                            .foregroundStyle(Theme.danger)
                    }
                    .buttonStyle(.plain)
                }
                if let deleteError {
                    Text(deleteError)
                        .font(.flexCaption())
                        .foregroundStyle(Theme.danger)
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
        .confirmationDialog("Delete your FlexUp account?", isPresented: $confirmDelete, titleVisibility: .visible) {
            Button("Delete account", role: .destructive) {
                Task { @MainActor in
                    do {
                        try await store.community.deleteAccount()
                        deleteError = nil
                        store.signOut()
                    } catch {
                        deleteError = error.localizedDescription
                    }
                }
            }
            Button("Keep my account", role: .cancel) {}
        } message: {
            Text("This permanently removes your account, friends, and everything you've shared. Logs stored only on this phone stay here.")
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
    ScrollView {
        StatsSection()
            .padding(20)
    }
    .background(Theme.background)
    .environment(AppStore())
}
