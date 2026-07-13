import SwiftUI

/// The weekly timeline. Plan the week here; rest days are part of the plan.
struct WeekCalendarView: View {
    @Environment(AppStore.self) private var store

    @State private var selectedDate = Calendar.current.startOfDay(for: .now)
    @State private var showPlanSheet = false
    @State private var selectedCommitment: Commitment?

    private let calendar = Calendar.current

    /// Today plus the next 13 days.
    private var days: [Date] {
        (0..<14).compactMap {
            calendar.date(byAdding: .day, value: $0, to: calendar.startOfDay(for: .now))
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                HStack(alignment: .top) {
                    ScreenHeader(title: "Calendar", tagline: "Plan the week. Keep the plan.")
                    Button {
                        showPlanSheet = true
                    } label: {
                        Image(systemName: "plus")
                            .font(.system(size: 17, weight: .bold))
                            .foregroundStyle(Theme.background)
                            .padding(12)
                            .background(Theme.ink)
                            .clipShape(Circle())
                    }
                }
                .padding(.horizontal, 20)

                dayStrip
                    .padding(.vertical, 12)

                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        timeline
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 24)
                }
                .scrollIndicators(.hidden)
            }
            .background(Theme.background)
            .toolbar(.hidden, for: .navigationBar)
            .sheet(isPresented: $showPlanSheet) {
                PlanSheet(initialDate: selectedDate)
            }
            .sheet(item: $selectedCommitment) { commitment in
                CommitmentDetailSheet(commitment: commitment)
            }
            .navigationDestination(for: Activity.self) { activity in
                ActivityDetailView(activity: activity)
            }
        }
    }

    // MARK: Day strip

    private var dayStrip: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 8) {
                ForEach(days, id: \.self) { day in
                    dayPill(day)
                }
            }
            .padding(.horizontal, 20)
        }
        .scrollIndicators(.hidden)
    }

    private func dayPill(_ day: Date) -> some View {
        let isSelected = calendar.isDate(day, inSameDayAs: selectedDate)
        let count = store.commitments(on: day).count + store.joinedActivities(on: day).count

        return Button {
            selectedDate = day
        } label: {
            VStack(spacing: 5) {
                Text(day.formatted(.dateTime.weekday(.narrow)))
                    .font(.flexCaption())
                Text(day.formatted(.dateTime.day()))
                    .font(.system(.body, design: .rounded, weight: .bold))
                Circle()
                    .fill(count > 0 ? (isSelected ? .white : Theme.accent) : .clear)
                    .frame(width: 5, height: 5)
            }
            .foregroundStyle(isSelected ? .white : Theme.ink)
            .frame(width: 46, height: 68)
            .background(isSelected ? Theme.accent : Theme.card)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    // MARK: Timeline

    private var timeline: some View {
        let commitments = store.commitments(on: selectedDate)
        let activities = store.joinedActivities(on: selectedDate)

        return Group {
            if commitments.isEmpty && activities.isEmpty {
                EmptyStateCard(
                    icon: "moon.zzz",
                    title: "Nothing planned",
                    message: "Rest is part of the plan — or add one small thing.",
                    actionLabel: "Plan something",
                    action: { showPlanSheet = true }
                )
                .padding(.top, 16)
            } else {
                ForEach(commitments) { commitment in
                    timelineRow(time: commitment.date) {
                        CommitmentRow(commitment: commitment) {
                            selectedCommitment = commitment
                        }
                    }
                }
                if !activities.isEmpty {
                    SectionHeader(title: "Activities", subtitle: "Plans with other people.")
                        .padding(.top, 6)
                    ForEach(activities) { activity in
                        timelineRow(time: activity.date) {
                            NavigationLink(value: activity) {
                                ActivityCard(activity: activity)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
    }

    private func timelineRow<Content: View>(time: Date, @ViewBuilder content: () -> Content) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Text(time, style: .time)
                .font(.flexCaption())
                .foregroundStyle(Theme.inkSubtle)
                .frame(width: 52, alignment: .trailing)
                .padding(.top, 16)
            content()
        }
    }
}

// MARK: - Plan sheet

/// Plan: create a one-off commitment with a verification method.
struct PlanSheet: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    let initialDate: Date

    @State private var title = ""
    @State private var category: ActivityCategory = .walk
    @State private var date: Date
    @State private var verification: VerificationMethod = .honor
    @State private var durationMinutes = 20

    init(initialDate: Date) {
        self.initialDate = initialDate
        let calendar = Calendar.current
        let base = calendar.isDateInToday(initialDate)
            ? Date.now.addingTimeInterval(3600)
            : (calendar.date(bySettingHour: 9, minute: 0, second: 0, of: initialDate) ?? initialDate)
        _date = State(initialValue: base)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("What will you do?")
                            .font(.flexCaption())
                            .foregroundStyle(Theme.inkSubtle)
                        TextField("e.g. 20-minute run", text: $title)
                            .font(.flexBodyBold())
                            .padding(14)
                            .background(Theme.card)
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Category")
                            .font(.flexCaption())
                            .foregroundStyle(Theme.inkSubtle)
                        ScrollView(.horizontal) {
                            HStack(spacing: 8) {
                                ForEach(ActivityCategory.allCases) { item in
                                    SelectableChip(label: item.label, icon: item.icon, isSelected: category == item) {
                                        category = item
                                    }
                                }
                            }
                        }
                        .scrollIndicators(.hidden)
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("When")
                            .font(.flexCaption())
                            .foregroundStyle(Theme.inkSubtle)
                        DatePicker("When", selection: $date, in: Date.now...)
                            .datePickerStyle(.compact)
                            .labelsHidden()
                            .tint(Theme.accent)
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Verification")
                            .font(.flexCaption())
                            .foregroundStyle(Theme.inkSubtle)
                        HStack(spacing: 8) {
                            ForEach(VerificationMethod.allCases) { method in
                                SelectableChip(label: method.label, icon: method.icon, isSelected: verification == method) {
                                    verification = method
                                }
                            }
                        }
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Duration")
                            .font(.flexCaption())
                            .foregroundStyle(Theme.inkSubtle)
                        Stepper("\(durationMinutes) minutes", value: $durationMinutes, in: 5...180, step: 5)
                            .font(.flexBodyBold())
                            .foregroundStyle(Theme.ink)
                    }
                }
                .padding(20)
            }
            .background(Theme.background)
            .navigationTitle("Plan something")
            .navigationBarTitleDisplayMode(.inline)
            .safeAreaInset(edge: .bottom) {
                Button("Commit to it") {
                    store.addCommitment(
                        title: title.trimmingCharacters(in: .whitespaces),
                        category: category,
                        date: date,
                        verification: verification,
                        durationMinutes: durationMinutes
                    )
                    dismiss()
                }
                .buttonStyle(PrimaryButtonStyle())
                .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty)
                .opacity(title.trimmingCharacters(in: .whitespaces).isEmpty ? 0.4 : 1)
                .padding(.horizontal, 20)
                .padding(.bottom, 8)
            }
        }
    }
}

#Preview {
    WeekCalendarView()
        .environment(AppStore())
}
