import SwiftUI

/// Manage the habits that generate daily commitments. What you picked in
/// onboarding shouldn't be permanent — life changes, so the plan should too.
struct HabitsSheet: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    @State private var editing: Habit?
    @State private var creating = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    if store.habits.isEmpty {
                        EmptyStateCard(
                            icon: "repeat",
                            title: "No habits yet",
                            message: "Habits schedule themselves onto your days. Add one to get started."
                        )
                    } else {
                        ForEach(store.habits) { habit in
                            habitRow(habit)
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 20)
            }
            .scrollIndicators(.hidden)
            .background(Theme.background)
            .navigationTitle("Habits")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(Theme.ink)
                }
            }
            .safeAreaInset(edge: .bottom) {
                Button {
                    creating = true
                } label: {
                    Label("New habit", systemImage: "plus")
                }
                .buttonStyle(PrimaryButtonStyle())
                .padding(.horizontal, 20)
                .padding(.bottom, 8)
            }
            .sheet(item: $editing) { habit in
                HabitEditorSheet(habit: habit)
            }
            .sheet(isPresented: $creating) {
                HabitEditorSheet(habit: nil)
            }
        }
    }

    private func habitRow(_ habit: Habit) -> some View {
        Button {
            editing = habit
        } label: {
            FlexCard(padding: 14) {
                HStack(spacing: 12) {
                    IconBadge(systemName: habit.category.icon, size: 42)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(habit.title)
                            .font(.flexBodyBold())
                            .foregroundStyle(Theme.ink)
                        Text("\(habit.scheduleWeekdays.count)×/WEEK · \(habit.timeOfDay.label.uppercased()) · \(habit.durationMinutes) MIN")
                            .font(.flexMono(9))
                            .tracking(1)
                            .foregroundStyle(Theme.inkSubtle)
                    }
                    Spacer()
                    if habit.streak > 0 {
                        HStack(spacing: 3) {
                            Image(systemName: "flame.fill")
                            Text("\(habit.streak)")
                                .monospacedDigit()
                        }
                        .font(.flexCaption())
                        .foregroundStyle(Theme.amber)
                    }
                    Image(systemName: "chevron.right")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(Theme.inkSubtle)
                }
            }
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button(role: .destructive) {
                store.deleteHabit(habit)
            } label: {
                Label("Delete habit", systemImage: "trash")
            }
        }
    }
}

// MARK: - Editor

/// Create or edit one habit. `habit == nil` means create.
struct HabitEditorSheet: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    let habit: Habit?

    @State private var title = ""
    @State private var category: ActivityCategory = .gym
    @State private var weekdays: Set<Int> = [2, 4, 6]
    @State private var timeOfDay: TimeOfDay = .morning
    @State private var verification: VerificationMethod = .honor
    @State private var durationMinutes = 20
    @State private var confirmDelete = false

    private let dayLetters = ["S", "M", "T", "W", "T", "F", "S"]

    private var canSave: Bool {
        !title.trimmingCharacters(in: .whitespaces).isEmpty && !weekdays.isEmpty
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    field("What will you do?") {
                        TextField("e.g. Morning run", text: $title)
                            .font(.flexBodyBold())
                            .padding(14)
                            .background(Theme.card)
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }

                    field("Category") {
                        ScrollView(.horizontal) {
                            HStack(spacing: 8) {
                                ForEach(ActivityCategory.allCases) { item in
                                    SelectableChip(label: item.label, icon: item.icon, isSelected: category == item) {
                                        category = item
                                        if !VerificationMethod.available(for: item).contains(verification) {
                                            verification = .honor
                                        }
                                    }
                                }
                            }
                        }
                        .scrollIndicators(.hidden)
                    }

                    field("Repeat on") {
                        HStack(spacing: 8) {
                            ForEach(1...7, id: \.self) { weekday in
                                Button {
                                    if weekdays.contains(weekday) {
                                        weekdays.remove(weekday)
                                    } else {
                                        weekdays.insert(weekday)
                                    }
                                } label: {
                                    Text(dayLetters[weekday - 1])
                                        .font(.flexMono(13))
                                        .foregroundStyle(weekdays.contains(weekday) ? Theme.background : Theme.inkSubtle)
                                        .frame(maxWidth: .infinity)
                                        .frame(height: 42)
                                        .background(weekdays.contains(weekday) ? Theme.ink : Theme.card)
                                        .clipShape(Circle())
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }

                    field("Time of day") {
                        HStack(spacing: 8) {
                            ForEach(TimeOfDay.allCases) { slot in
                                SelectableChip(label: slot.label, isSelected: timeOfDay == slot) {
                                    timeOfDay = slot
                                }
                            }
                        }
                    }

                    field("Verification") {
                        ScrollView(.horizontal) {
                            HStack(spacing: 8) {
                                ForEach(VerificationMethod.available(for: category)) { method in
                                    SelectableChip(label: method.label, icon: method.icon, isSelected: verification == method) {
                                        verification = method
                                    }
                                }
                            }
                        }
                        .scrollIndicators(.hidden)
                    }

                    field("Duration") {
                        Stepper("\(durationMinutes) minutes", value: $durationMinutes, in: 5...180, step: 5)
                            .font(.flexBodyBold())
                            .foregroundStyle(Theme.ink)
                    }

                    if habit != nil {
                        Button("Delete habit", role: .destructive) {
                            confirmDelete = true
                        }
                        .buttonStyle(SecondaryButtonStyle(tint: Theme.danger, background: Theme.danger.opacity(0.1)))
                    }
                }
                .padding(20)
            }
            .scrollIndicators(.hidden)
            .background(Theme.background)
            .navigationTitle(habit == nil ? "New habit" : "Edit habit")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(Theme.inkSubtle)
                }
            }
            .safeAreaInset(edge: .bottom) {
                Button("Save habit") { save() }
                    .buttonStyle(PrimaryButtonStyle())
                    .disabled(!canSave)
                    .opacity(canSave ? 1 : 0.4)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 8)
            }
            .confirmationDialog("Delete this habit?", isPresented: $confirmDelete, titleVisibility: .visible) {
                Button("Delete", role: .destructive) {
                    if let habit { store.deleteHabit(habit) }
                    dismiss()
                }
                Button("Keep it", role: .cancel) {}
            } message: {
                Text("Upcoming days are removed. Everything you already completed stays in your history.")
            }
            .onAppear(perform: load)
        }
    }

    private func field<Content: View>(_ label: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label.uppercased())
                .font(.flexMono(10))
                .tracking(2)
                .foregroundStyle(Theme.inkSubtle)
            content()
        }
    }

    private func load() {
        guard let habit else { return }
        title = habit.title
        category = habit.category
        weekdays = habit.scheduleWeekdays
        timeOfDay = habit.timeOfDay
        // Partner (and GPS outside runs) can't be checked; edit as honor.
        verification = VerificationMethod.available(for: habit.category).contains(habit.verification)
            ? habit.verification
            : .honor
        durationMinutes = habit.durationMinutes
    }

    private func save() {
        if var existing = habit {
            existing.title = title.trimmingCharacters(in: .whitespaces)
            existing.category = category
            existing.scheduleWeekdays = weekdays
            existing.timeOfDay = timeOfDay
            existing.verification = verification
            existing.durationMinutes = durationMinutes
            store.updateHabit(existing)
        } else {
            store.addHabit(
                title: title,
                category: category,
                weekdays: weekdays,
                timeOfDay: timeOfDay,
                verification: verification,
                durationMinutes: durationMinutes
            )
        }
        dismiss()
    }
}

#Preview {
    HabitsSheet()
        .environment(AppStore())
}
