import SwiftUI

/// Training log: start a session (blank or from a saved routine), add
/// exercises, log sets × kg × reps against last time's numbers.
/// Finishing auto-completes today's gym commitment.
struct LiftSection: View {
    @Environment(AppStore.self) private var store
    @State private var workoutStart: WorkoutStart?

    /// Identifiable wrapper so one sheet handles both a blank session and
    /// starting from a routine.
    struct WorkoutStart: Identifiable {
        let id = UUID()
        let routine: Routine?
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 10) {
                TrackStat(value: "\(store.workouts.count)", label: "Sessions")
                TrackStat(value: volumeText, label: "Total KG")
                TrackStat(value: "\(store.workoutsThisWeek)", label: "This week")
            }

            Button {
                workoutStart = WorkoutStart(routine: nil)
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "dumbbell")
                    Text("Start workout")
                }
            }
            .buttonStyle(PrimaryButtonStyle())

            routinesSection
            historySection
        }
        .fullScreenCover(item: $workoutStart) { start in
            ActiveWorkoutView(routine: start.routine)
        }
    }

    private var volumeText: String {
        let volume = store.totalVolumeKg
        return volume >= 10000
            ? String(format: "%.1ft", volume / 1000)
            : "\(Int(volume))"
    }

    // MARK: Routines

    private var routinesSection: some View {
        Group {
            if !store.routines.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    SectionHeader(title: "Routines", subtitle: "Start with your exercises already loaded.")
                    ScrollView(.horizontal) {
                        HStack(spacing: 10) {
                            ForEach(store.routines) { routine in
                                routineCard(routine)
                            }
                        }
                    }
                    .scrollIndicators(.hidden)
                }
            }
        }
    }

    private func routineCard(_ routine: Routine) -> some View {
        Button {
            workoutStart = WorkoutStart(routine: routine)
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                Image(systemName: "list.bullet.rectangle")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Theme.accent)
                Spacer(minLength: 0)
                Text(routine.name)
                    .font(.flexBodyBold())
                    .foregroundStyle(Theme.ink)
                    .lineLimit(1)
                Text("\(routine.exerciseNames.count) EXERCISES")
                    .font(.flexMono(9))
                    .tracking(1)
                    .foregroundStyle(Theme.inkSubtle)
            }
            .frame(width: 150, height: 110, alignment: .leading)
            .padding(14)
            .background(Theme.card)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button(role: .destructive) {
                store.deleteRoutine(routine)
            } label: {
                Label("Delete routine", systemImage: "trash")
            }
        }
    }

    // MARK: History

    private var historySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "History", subtitle: store.workouts.isEmpty ? nil : "Long-press to delete.")
            if store.workouts.isEmpty {
                EmptyStateCard(
                    icon: "dumbbell",
                    title: "No sessions yet",
                    message: "Log the first one. The bar doesn't care where you start."
                )
            } else {
                ForEach(store.workouts) { workout in
                    WorkoutRow(workout: workout)
                        .contextMenu {
                            Button {
                                store.saveRoutine(
                                    name: workout.title,
                                    exerciseNames: workout.exercises.map(\.name)
                                )
                            } label: {
                                Label("Save as routine", systemImage: "square.and.arrow.down")
                            }
                            Button(role: .destructive) {
                                store.deleteWorkout(workout)
                            } label: {
                                Label("Delete session", systemImage: "trash")
                            }
                        }
                }
            }
        }
    }
}

// MARK: - Workout row

struct WorkoutRow: View {
    let workout: Workout

    var body: some View {
        FlexCard(padding: 16) {
            HStack(spacing: 14) {
                IconBadge(systemName: "dumbbell", size: 42)
                VStack(alignment: .leading, spacing: 3) {
                    Text(workout.title)
                        .font(.flexBodyBold())
                        .foregroundStyle(Theme.ink)
                        .lineLimit(1)
                    Text(workout.date.formatted(.dateTime.weekday(.abbreviated).day().month()).uppercased())
                        .font(.flexMono(10))
                        .tracking(1)
                        .foregroundStyle(Theme.inkSubtle)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 3) {
                    Text("\(Int(workout.totalVolumeKg)) kg")
                        .font(.flexStat(18))
                        .foregroundStyle(Theme.ink)
                    Text("\(workout.totalSets) SETS · \(RunFormat.duration(workout.duration))")
                        .font(.flexMono(9))
                        .tracking(1)
                        .foregroundStyle(Theme.inkSubtle)
                }
            }
        }
    }
}

// MARK: - Active workout

struct ActiveWorkoutView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    /// When set, the session starts with these exercises already loaded.
    let routine: Routine?

    @State private var title = ""
    @State private var exercises: [WorkoutExercise] = []
    @State private var startedAt = Date.now
    @State private var showExercisePicker = false
    @State private var confirmDiscard = false
    @State private var restEndsAt: Date?
    @State private var showSaveRoutine = false
    @State private var routineName = ""

    private static let restSeconds: TimeInterval = 90

    private var hasLoggedSets: Bool {
        exercises.contains { $0.sets.contains { $0.reps > 0 } }
    }

    var body: some View {
        VStack(spacing: 0) {
            header

            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    TextField("Name this session (e.g. Push day)", text: $title)
                        .font(.flexBodyBold())
                        .padding(14)
                        .background(Theme.card)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

                    ForEach($exercises) { $exercise in
                        ExerciseCard(exercise: $exercise) {
                            exercises.removeAll { $0.id == exercise.id }
                        } onSetAdded: {
                            restEndsAt = Date.now.addingTimeInterval(Self.restSeconds)
                        }
                    }

                    Button {
                        showExercisePicker = true
                    } label: {
                        Label("Add exercise", systemImage: "plus")
                    }
                    .buttonStyle(SecondaryButtonStyle())

                    if !exercises.isEmpty {
                        Button {
                            routineName = title.trimmingCharacters(in: .whitespaces)
                            showSaveRoutine = true
                        } label: {
                            Label("Save as routine", systemImage: "square.and.arrow.down")
                                .font(.flexCaption())
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(Theme.accent)
                        .frame(maxWidth: .infinity)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
            }
            .scrollIndicators(.hidden)
            .scrollDismissesKeyboard(.interactively)

            VStack(spacing: 10) {
                if let restEndsAt {
                    restPill(until: restEndsAt)
                }

                Button("Finish workout") {
                    store.logWorkout(
                        title: title,
                        duration: Date.now.timeIntervalSince(startedAt),
                        exercises: exercises
                    )
                    dismiss()
                }
                .buttonStyle(PrimaryButtonStyle())
                .disabled(!hasLoggedSets)
                .opacity(hasLoggedSets ? 1 : 0.4)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 12)
        }
        .background(Theme.background)
        .interactiveDismissDisabled(true)
        .sheet(isPresented: $showExercisePicker) {
            ExercisePickerSheet { name in
                exercises.append(WorkoutExercise(name: name))
            }
        }
        .alert("Save as routine", isPresented: $showSaveRoutine) {
            TextField("Routine name", text: $routineName)
            Button("Save") {
                store.saveRoutine(name: routineName, exerciseNames: exercises.map(\.name))
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Next time you can start with these exercises already loaded.")
        }
        .confirmationDialog("Discard this workout?", isPresented: $confirmDiscard, titleVisibility: .visible) {
            Button("Discard workout", role: .destructive) { dismiss() }
            Button("Keep going", role: .cancel) {}
        }
        .onAppear(perform: loadRoutine)
    }

    private func loadRoutine() {
        guard let routine, exercises.isEmpty else { return }
        title = routine.name
        exercises = routine.exerciseNames.map { WorkoutExercise(name: $0) }
    }

    // MARK: Rest timer

    private func restPill(until end: Date) -> some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            let remaining = max(0, end.timeIntervalSince(context.date))
            Button {
                restEndsAt = nil
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: remaining > 0 ? "timer" : "checkmark.circle.fill")
                    Text(remaining > 0
                         ? "Rest · \(RunFormat.duration(remaining))"
                         : "Rest done — next set")
                        .monospacedDigit()
                    Spacer()
                    Text("SKIP")
                        .font(.flexMono(9))
                        .tracking(1)
                }
                .font(.flexBodyBold())
                .foregroundStyle(remaining > 0 ? Theme.ink : Theme.accent)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(remaining > 0 ? Theme.card : Theme.accentSoft)
                .clipShape(Capsule())
            }
            .buttonStyle(.plain)
        }
    }

    private var header: some View {
        VStack(spacing: 6) {
            HStack {
                Button {
                    if hasLoggedSets { confirmDiscard = true } else { dismiss() }
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(Theme.inkSubtle)
                        .padding(12)
                        .background(Theme.card)
                        .clipShape(Circle())
                }
                Spacer()
                TimelineView(.periodic(from: .now, by: 1)) { context in
                    Text(RunFormat.duration(context.date.timeIntervalSince(startedAt)))
                        .font(.flexStat(22))
                        .monospacedDigit()
                        .foregroundStyle(Theme.ink)
                }
            }
            Text("WORKOUT IN PROGRESS")
                .font(.flexMono(11))
                .tracking(3)
                .foregroundStyle(Theme.accent)
        }
        .padding(.horizontal, 20)
        .padding(.top, 16)
        .padding(.bottom, 12)
    }
}

// MARK: - Exercise card

struct ExerciseCard: View {
    @Environment(AppStore.self) private var store
    @Binding var exercise: WorkoutExercise
    var onDelete: () -> Void
    var onSetAdded: () -> Void

    /// What you did last time — the number to beat.
    private var lastTime: (sets: [ExerciseSet], date: Date)? {
        store.lastSets(for: exercise.name)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(exercise.name)
                        .font(.flexBodyBold())
                        .foregroundStyle(Theme.ink)
                    if let best = store.bestWeight(for: exercise.name), best > 0 {
                        Text("BEST \(Int(best)) KG")
                            .font(.flexMono(9))
                            .tracking(1)
                            .foregroundStyle(Theme.accent)
                    }
                }
                Spacer()
                Button(action: onDelete) {
                    Image(systemName: "trash")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Theme.inkSubtle)
                }
                .buttonStyle(.plain)
            }

            if let lastTime {
                Text("LAST · \(lastTime.sets.map { "\(Int($0.weightKg))×\($0.reps)" }.joined(separator: "  "))")
                    .font(.flexMono(9))
                    .tracking(1)
                    .foregroundStyle(Theme.inkSubtle)
                    .lineLimit(1)
            }

            HStack {
                Text("SET").frame(width: 36, alignment: .leading)
                Text("KG").frame(maxWidth: .infinity, alignment: .center)
                Text("REPS").frame(maxWidth: .infinity, alignment: .center)
                Spacer().frame(width: 28)
            }
            .font(.flexMono(9))
            .tracking(1)
            .foregroundStyle(Theme.inkSubtle)

            ForEach($exercise.sets) { $set in
                HStack {
                    Text("\(setNumber(of: set))")
                        .font(.flexMono(12))
                        .foregroundStyle(Theme.inkSubtle)
                        .frame(width: 36, alignment: .leading)
                    TextField("0", value: $set.weightKg, format: .number)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.center)
                        .font(.flexBodyBold())
                        .padding(.vertical, 8)
                        .background(Theme.background)
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    TextField("0", value: $set.reps, format: .number)
                        .keyboardType(.numberPad)
                        .multilineTextAlignment(.center)
                        .font(.flexBodyBold())
                        .padding(.vertical, 8)
                        .background(Theme.background)
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    Button {
                        if exercise.sets.count > 1 {
                            exercise.sets.removeAll { $0.id == set.id }
                        }
                    } label: {
                        Image(systemName: "minus.circle")
                            .foregroundStyle(exercise.sets.count > 1 ? Theme.inkSubtle : Theme.inkSubtle.opacity(0.3))
                    }
                    .buttonStyle(.plain)
                    .frame(width: 28)
                }
            }

            Button {
                // Prefill from the last set logged, or from last session's
                // matching set — you rarely change weight between sets.
                let previous = exercise.sets.last
                let reference = lastTime?.sets.dropFirst(exercise.sets.count).first
                exercise.sets.append(ExerciseSet(
                    weightKg: previous?.weightKg ?? reference?.weightKg ?? 0,
                    reps: previous?.reps ?? reference?.reps ?? 0
                ))
                onSetAdded()
            } label: {
                Label("Add set", systemImage: "plus")
                    .font(.flexCaption())
                    .foregroundStyle(Theme.accent)
            }
            .buttonStyle(.plain)
        }
        .padding(14)
        .background(Theme.card)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private func setNumber(of set: ExerciseSet) -> Int {
        (exercise.sets.firstIndex { $0.id == set.id } ?? 0) + 1
    }
}

// MARK: - Exercise picker

struct ExercisePickerSheet: View {
    var onPick: (String) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var search = ""

    private var filtered: [SampleData.ExerciseTemplate] {
        let query = search.trimmingCharacters(in: .whitespaces)
        guard !query.isEmpty else { return SampleData.exerciseCatalog }
        return SampleData.exerciseCatalog.filter {
            $0.name.localizedCaseInsensitiveContains(query)
        }
    }

    var body: some View {
        VStack(spacing: 14) {
            Capsule()
                .fill(Theme.inkSubtle.opacity(0.3))
                .frame(width: 36, height: 5)
                .padding(.top, 10)

            TextField("Search exercises", text: $search)
                .font(.flexBody())
                .padding(12)
                .background(Theme.card)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .padding(.horizontal, 20)

            ScrollView {
                VStack(spacing: 8) {
                    ForEach(filtered) { template in
                        Button {
                            onPick(template.name)
                            dismiss()
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(template.name)
                                        .font(.flexBodyBold())
                                        .foregroundStyle(Theme.ink)
                                    Text(template.muscle.uppercased())
                                        .font(.flexMono(9))
                                        .tracking(1)
                                        .foregroundStyle(Theme.inkSubtle)
                                }
                                Spacer()
                                Image(systemName: "plus.circle.fill")
                                    .foregroundStyle(Theme.accent)
                            }
                            .padding(12)
                            .background(Theme.card)
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        }
                        .buttonStyle(.plain)
                    }

                    // Not in the catalog? Add whatever was typed.
                    if !search.trimmingCharacters(in: .whitespaces).isEmpty {
                        Button {
                            onPick(search.trimmingCharacters(in: .whitespaces))
                            dismiss()
                        } label: {
                            Label("Add \"\(search.trimmingCharacters(in: .whitespaces))\"", systemImage: "plus")
                                .font(.flexBodyBold())
                                .foregroundStyle(Theme.accent)
                                .padding(.vertical, 12)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
            }
            .scrollIndicators(.hidden)
        }
        .background(Theme.background)
        .presentationDetents([.large])
    }
}
