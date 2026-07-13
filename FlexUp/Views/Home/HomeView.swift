import SwiftUI

/// The command center. Everything here answers one question:
/// "What should I do next?"
struct HomeView: View {
    @Environment(AppStore.self) private var store
    @State private var selectedCommitment: Commitment?
    @State private var path = NavigationPath()

    private let moods = ["😌", "🙂", "😐", "😮‍💨", "😓"]

    var body: some View {
        NavigationStack(path: $path) {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    header
                    progressCard
                    coachCard
                    todaySection
                    friendsSection
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
            }
            .scrollIndicators(.hidden)
            .background(Theme.background)
            .toolbar(.hidden, for: .navigationBar)
            .safeAreaInset(edge: .bottom) { quickStartButton }
            .sheet(item: $selectedCommitment) { commitment in
                CommitmentDetailSheet(commitment: commitment)
            }
            .navigationDestination(for: Activity.self) { activity in
                ActivityDetailView(activity: activity)
            }
        }
    }

    // MARK: Header

    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: .now)
        switch hour {
        case ..<12: return "Good morning"
        case ..<17: return "Good afternoon"
        default: return "Good evening"
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(Date.now.formatted(.dateTime.weekday(.wide).day().month(.wide)).uppercased())
                        .font(.flexMono(12))
                        .tracking(2)
                        .foregroundStyle(Theme.inkSubtle)
                    Text("HEY \((store.profile?.name ?? "there").uppercased())")
                        .font(.flexDisplay(36))
                        .foregroundStyle(Theme.ink)
                        .minimumScaleFactor(0.6)
                        .lineLimit(1)
                    Text("\(greeting). What's next?".uppercased())
                        .font(.flexMono(11))
                        .tracking(2)
                        .foregroundStyle(Theme.inkSubtle)
                }
                Spacer()
            }
            HStack(spacing: 10) {
                Text("Mood")
                    .font(.flexCaption())
                    .foregroundStyle(Theme.inkSubtle)
                ForEach(moods, id: \.self) { mood in
                    Button {
                        store.todayMood = mood
                    } label: {
                        Text(mood)
                            .font(.system(size: 20))
                            .opacity(store.todayMood == nil || store.todayMood == mood ? 1 : 0.35)
                            .scaleEffect(store.todayMood == mood ? 1.25 : 1)
                    }
                    .buttonStyle(.plain)
                }
            }
            .animation(.spring(duration: 0.25), value: store.todayMood)
        }
        .padding(.top, 8)
    }

    // MARK: Progress

    private var progressCard: some View {
        let today = store.todayCommitments
        let done = today.filter { $0.status == .completed }.count

        return FlexCard {
            HStack(spacing: 16) {
                ZStack {
                    ProgressRing(progress: store.todayProgress)
                        .frame(width: 62, height: 62)
                    Text("\(done)/\(today.count)")
                        .font(.system(.subheadline, design: .rounded, weight: .bold))
                        .foregroundStyle(Theme.ink)
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text("TODAY")
                        .font(.flexMono(10))
                        .tracking(2)
                        .foregroundStyle(Theme.inkSubtle)
                    Text(progressMessage(done: done, total: today.count))
                        .font(.flexBodyBold())
                        .foregroundStyle(Theme.ink)
                }
                Spacer()
            }
        }
    }

    private func progressMessage(done: Int, total: Int) -> String {
        if total == 0 { return "Nothing planned yet. Keep it light or add one thing." }
        if done == total { return "All done. Go live your life." }
        if done == 0 { return "\(total) commitment\(total == 1 ? "" : "s") waiting. Start with the easiest." }
        return "\(done) of \(total) done — keep the thread going."
    }

    // MARK: Coach

    private var coachCard: some View {
        let insight = store.coachInsight

        return VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "sparkles")
                    .font(.system(size: 14, weight: .semibold))
                Text("COACH")
                    .font(.flexMono(11))
                    .tracking(2)
            }
            .foregroundStyle(Theme.accent)

            Text(insight.message)
                .font(.flexBody())
                .foregroundStyle(Theme.ink)

            if let label = insight.actionLabel, let action = insight.action {
                Button(label) { perform(action) }
                    .buttonStyle(SecondaryButtonStyle(tint: Theme.accent, background: Theme.card))
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.accentSoft)
        .clipShape(RoundedRectangle(cornerRadius: Theme.cornerRadius, style: .continuous))
    }

    private func perform(_ action: CoachAction) {
        switch action {
        case .quickStart(let category):
            store.quickStart(category)
        case .openActivity(let id):
            if let activity = store.activities.first(where: { $0.id == id }) {
                path.append(activity)
            }
        }
    }

    // MARK: Today

    private var todaySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Today", subtitle: "Habits, activities, and one-off plans.")
            if store.todayCommitments.isEmpty {
                EmptyStateCard(
                    icon: "sun.max",
                    title: "A clean slate",
                    message: "Nothing scheduled today. One small thing still counts.",
                    actionLabel: "Quick start a walk",
                    action: { store.quickStart(.walk) }
                )
            } else {
                ForEach(store.todayCommitments) { commitment in
                    CommitmentRow(commitment: commitment) {
                        selectedCommitment = commitment
                    }
                }
            }
        }
    }

    // MARK: Friends

    private var friendsSection: some View {
        let upcoming = store.upcomingFriendActivities
        return Group {
            if !upcoming.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    SectionHeader(title: "Friends are on it", subtitle: "Plans are easier to keep together.")
                    ScrollView(.horizontal) {
                        HStack(spacing: 12) {
                            ForEach(upcoming) { activity in
                                NavigationLink(value: activity) {
                                    FriendActivityCard(activity: activity)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    .scrollIndicators(.hidden)
                }
            }
        }
    }

    // MARK: Quick Start

    private var quickStartButton: some View {
        Menu {
            ForEach(ActivityCategory.allCases) { category in
                Button {
                    store.quickStart(category)
                } label: {
                    Label(category.label, systemImage: category.icon)
                }
            }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "bolt.fill")
                Text("Quick Start")
            }
            .font(.flexBodyBold())
            .foregroundStyle(Theme.background)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 17)
            .background(Theme.ink)
            .clipShape(Capsule())
            .shadow(color: Theme.ink.opacity(0.3), radius: 12, y: 5)
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 6)
    }
}

// MARK: - Friend activity mini card

struct FriendActivityCard: View {
    let activity: Activity

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                IconBadge(systemName: activity.category.icon, size: 34)
                Spacer()
                AvatarStack(names: activity.friendsGoing, size: 24)
            }
            Text(activity.title)
                .font(.flexBodyBold())
                .foregroundStyle(Theme.ink)
                .lineLimit(1)
            Text(activity.date.formatted(.dateTime.weekday(.abbreviated).hour().minute()))
                .font(.flexCaption())
                .foregroundStyle(Theme.inkSubtle)
            Text(activity.isJoined ? "You're going" : "Join them")
                .font(.flexCaption())
                .foregroundStyle(Theme.accent)
        }
        .padding(14)
        .frame(width: 190, alignment: .leading)
        .background(Theme.card)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .shadow(color: .black.opacity(0.05), radius: 10, y: 4)
    }
}

#Preview {
    HomeView()
        .environment(AppStore())
}
