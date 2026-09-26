import SwiftUI

/// Where the core loop closes. Habits materialize commitments onto each
/// day; this is the screen where you see them, do them, and check them off.
/// Community (your crew's feed), Progress and Stats live one segment away.
struct TodayView: View {
    enum Section: String, CaseIterable, Identifiable {
        case today = "Today"
        case community = "Community"
        case progress = "Progress"
        case stats = "Stats"
        var id: String { rawValue }
    }

    @Environment(AppStore.self) private var store
    @State private var section: Section = .today
    @State private var selectedCommitment: Commitment?
    @State private var showPlan = false

    private var greeting: String {
        switch Calendar.current.component(.hour, from: .now) {
        case ..<12: "Good morning"
        case ..<17: "Good afternoon"
        default: "Good evening"
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    ScreenHeader(
                        title: "Today",
                        tagline: Date.now.formatted(.dateTime.weekday(.wide).day().month(.wide))
                    )
                    SegmentPills(items: Section.allCases, selection: $section)

                    switch section {
                    case .today:
                        progressCard
                        weekCard
                        crewBanner
                        commitmentsSection
                        planRow
                    case .community:
                        if FeatureFlags.community {
                            CommunitySection()
                        } else {
                            ComingSoonCommunity()
                        }
                    case .progress:
                        ProgressSection()
                    case .stats:
                        StatsSection()
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 24)
            }
            .scrollIndicators(.hidden)
            .background(Theme.background)
            .toolbar(.hidden, for: .navigationBar)
            .refreshable {
                if FeatureFlags.community { await store.community.refresh(day: store.todayKey) }
            }
            .communityDestinations()
            .task {
                if FeatureFlags.community { await store.community.refresh(day: store.todayKey) }
            }
            .sheet(item: $selectedCommitment) { commitment in
                CommitmentDetailSheet(commitment: commitment)
            }
            .sheet(isPresented: $showPlan) {
                PlanSheet(initialDate: .now)
            }
        }
    }

    // MARK: Progress

    private var progressCard: some View {
        let today = store.todayCommitments
        let done = today.filter { $0.status == .completed }.count

        return FlexCard {
            HStack(spacing: 16) {
                ZStack {
                    ProgressRing(progress: store.todayProgress)
                        .frame(width: 64, height: 64)
                    Text("\(done)/\(today.count)")
                        .font(.system(.subheadline, weight: .bold))
                        .monospacedDigit()
                        .foregroundStyle(Theme.ink)
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text("\(greeting.uppercased()), \((store.profile?.name ?? "you").uppercased())")
                        .font(.flexMono(10))
                        .tracking(2)
                        .foregroundStyle(Theme.inkSubtle)
                    Text(message(done: done, total: today.count))
                        .font(.flexBodyBold())
                        .foregroundStyle(Theme.ink)
                }
                Spacer()
            }
        }
    }

    private func message(done: Int, total: Int) -> String {
        if total == 0 { return "Nothing scheduled. One small thing still counts." }
        if done == total { return "All done. Go live your life." }
        if done == 0 { return "\(total) waiting. Start with the easiest." }
        return "\(done) of \(total) done — keep the thread going."
    }

    // MARK: This week vs goals

    /// The weekly targets from onboarding, measured by what was actually logged.
    private var weekCard: some View {
        let week = store.weekProgress
        return FlexCard(padding: 16) {
            VStack(alignment: .leading, spacing: 12) {
                Text("THIS WEEK")
                    .font(.flexMono(10))
                    .tracking(2)
                    .foregroundStyle(Theme.inkSubtle)
                HStack(spacing: 10) {
                    weekStat("Wake-ups", done: week.wakeUps, target: week.wakeDays, icon: "sunrise.fill")
                    weekStat("Runs", done: week.runs, target: store.goals.runsPerWeek, icon: "figure.run")
                    weekStat("Sessions", done: week.workouts, target: store.goals.gymPerWeek, icon: "dumbbell.fill")
                }
            }
        }
    }

    private func weekStat(_ label: String, done: Int, target: Int, icon: String) -> some View {
        let met = target > 0 && done >= target
        return VStack(spacing: 6) {
            Image(systemName: met ? "checkmark.circle.fill" : icon)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(met ? Theme.accent : Theme.inkSubtle)
            Text(target > 0 ? "\(done)/\(target)" : "\(done)")
                .font(.flexStat(22))
                .foregroundStyle(Theme.ink)
            Text(label.uppercased())
                .font(.flexMono(8))
                .tracking(1.2)
                .foregroundStyle(Theme.inkSubtle)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(met ? Theme.accentSoft : Theme.background)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    // MARK: Crew

    /// Nudges from friends surface where the day's work is, not buried a tab away.
    @ViewBuilder
    private var crewBanner: some View {
        let nudges = FeatureFlags.community ? store.community.nudges : []
        if let first = nudges.first {
            Button {
                withAnimation(.spring(duration: 0.25)) { section = .community }
            } label: {
                HStack(spacing: 12) {
                    AvatarCircle(name: first.from.name, size: 34)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(nudges.count == 1
                             ? "\(first.from.name): \(first.message)"
                             : "\(nudges.count) nudges from your crew")
                            .font(.flexBodyBold())
                            .foregroundStyle(Theme.ink)
                            .lineLimit(1)
                        Text("TAP TO SEE YOUR CREW")
                            .font(.flexMono(9))
                            .tracking(1)
                            .foregroundStyle(Theme.accent)
                    }
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

    // MARK: Commitments

    private var commitmentsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Your commitments", subtitle: "Tap one to start it or check it off.")
            if store.todayCommitments.isEmpty {
                EmptyStateCard(
                    icon: "sun.max",
                    title: "A clean slate",
                    message: "Nothing scheduled today. Add a habit in Stats, or plan a one-off below."
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

    // MARK: Plan / Quick Start

    private var planRow: some View {
        VStack(spacing: 10) {
            Button {
                showPlan = true
            } label: {
                Label("Plan something", systemImage: "calendar.badge.plus")
            }
            .buttonStyle(SecondaryButtonStyle())

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
                .shadow(color: Theme.ink.opacity(0.25), radius: 10, y: 4)
            }
        }
    }
}

#Preview {
    TodayView()
        .environment(AppStore())
}
