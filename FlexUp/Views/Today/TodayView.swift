import SwiftUI

/// Where the core loop closes. Habits materialize commitments onto each
/// day; this is the screen where you see them, do them, and check them off.
/// Stats lives one segment away.
struct TodayView: View {
    enum Section: String, CaseIterable, Identifiable {
        case today = "Today"
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
                        commitmentsSection
                        planRow
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
