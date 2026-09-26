import SwiftUI
import Charts

/// Training log in the spirit of Hevy: start empty or from a routine, tick
/// sets off against last session's numbers, rest between them, and see
/// PRs as they happen. The session in progress is saved as it goes.
/// Finishing auto-completes today's gym commitment.
struct LiftSection: View {
    @Environment(AppStore.self) private var store
    @State private var session: ActiveSession?
    @State private var pendingStart: WorkoutDraft?
    @State private var editingRoutine: RoutineEdit?
    @State private var detailWorkout: Workout?

    /// Identifiable wrapper so one full-screen cover handles every way of
    /// starting a session.
    struct ActiveSession: Identifiable {
        let id = UUID()
    }

    struct RoutineEdit: Identifiable {
        let id = UUID()
        let routine: Routine?
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 10) {
                TrackStat(value: "\(store.workoutsThisWeek)/\(store.goals.gymPerWeek)", label: "This week")
                TrackStat(value: "\(store.workouts.count)", label: "Sessions")
                TrackStat(value: volumeText, label: "Total kg")
            }

            if let draft = store.workoutDraft {
                resumeCard(draft)
            } else {
                Button {
                    start(WorkoutDraft(title: "", startedAt: .now, exercises: []))
                } label: {
                    Label("Start empty workout", systemImage: "plus")
                }
                .buttonStyle(PrimaryButtonStyle())
            }

            routinesSection
            recordsSection
            historySection
        }
        .fullScreenCover(item: $session) { _ in
            ActiveWorkoutView()
        }
        .sheet(item: $editingRoutine) { edit in
            RoutineEditorSheet(routine: edit.routine)
        }
        .sheet(item: $detailWorkout) { workout in
            WorkoutDetailSheet(workout: workout) { exercises in
                detailWorkout = nil
                start(WorkoutDraft(title: workout.title, startedAt: .now, exercises: exercises))
            }
        }
        .confirmationDialog(
            "You have a workout in progress",
            isPresented: Binding(get: { pendingStart != nil }, set: { if !$0 { pendingStart = nil } }),
            titleVisibility: .visible
        ) {
            Button("Resume it") {
                pendingStart = nil
                session = ActiveSession()
            }
            Button("Discard it and start this one", role: .destructive) {
                if let pendingStart {
                    store.cancelRestNotification()
                    store.updateWorkoutDraft(pendingStart)
                    session = ActiveSession()
                }
                pendingStart = nil
            }
            Button("Cancel", role: .cancel) { pendingStart = nil }
        }
    }

    /// Opens a session, unless one is already running.
    private func start(_ draft: WorkoutDraft) {
        if store.workoutDraft != nil {
            pendingStart = draft
        } else {
            store.updateWorkoutDraft(draft)
            session = ActiveSession()
        }
    }

    private var volumeText: String {
        let volume = store.totalVolumeKg
        return volume >= 10000
            ? String(format: "%.1ft", volume / 1000)
            : "\(Int(volume))"
    }

    // MARK: Resume

    private func resumeCard(_ draft: WorkoutDraft) -> some View {
        let done = draft.exercises.flatMap(\.sets).filter { $0.isDone == true }.count
        return VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                IconBadge(systemName: "figure.strengthtraining.traditional", size: 42)
                VStack(alignment: .leading, spacing: 3) {
                    Text(draft.title.isEmpty ? "Workout in progress" : draft.title)
                        .font(.flexBodyBold())
                        .foregroundStyle(Theme.ink)
                    TimelineView(.periodic(from: .now, by: 1)) { context in
                        Text("\(RunFormat.duration(context.date.timeIntervalSince(draft.startedAt))) · \(done) SETS DONE")
                            .font(.flexMono(9))
                            .tracking(1)
                            .monospacedDigit()
                            .foregroundStyle(Theme.accent)
                    }
                }
                Spacer()
            }
            Button("Resume workout") {
                session = ActiveSession()
            }
            .buttonStyle(PrimaryButtonStyle())
        }
        .padding(16)
        .background(Theme.card)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    // MARK: Routines

    private var routinesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                SectionHeader(title: "Routines", subtitle: store.routines.isEmpty ? "Save a plan once, start it in one tap." : nil)
                Spacer()
                Button {
                    editingRoutine = RoutineEdit(routine: nil)
                } label: {
                    Label("New", systemImage: "plus")
                        .font(.flexCaption())
                        .foregroundStyle(Theme.accent)
                }
                .buttonStyle(.plain)
            }
            ForEach(store.routines) { routine in
                routineRow(routine)
            }
        }
    }

    private func routineRow(_ routine: Routine) -> some View {
        let exercises = routine.startingExercises
        return VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(routine.name)
                        .font(.flexBodyBold())
                        .foregroundStyle(Theme.ink)
                    Text(exercises.map(\.name).joined(separator: ", "))
                        .font(.flexCaption())
                        .foregroundStyle(Theme.inkSubtle)
                        .lineLimit(2)
                }
                Spacer()
                Menu {
                    Button("Edit routine", systemImage: "pencil") {
                        editingRoutine = RoutineEdit(routine: routine)
                    }
                    Button("Delete routine", systemImage: "trash", role: .destructive) {
                        store.deleteRoutine(routine)
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(Theme.inkSubtle)
                        .frame(width: 32, height: 32)
                }
            }
            Button {
                start(WorkoutDraft(title: routine.name, startedAt: .now, exercises: exercises))
            } label: {
                Text("Start routine")
            }
            .buttonStyle(SecondaryButtonStyle(tint: Theme.accent, background: Theme.accentSoft))
        }
        .padding(16)
        .background(Theme.card)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    // MARK: Records

    private var recordsSection: some View {
        Group {
            let records = Array(store.personalRecords.prefix(5))
            if !records.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    SectionHeader(title: "Personal records", subtitle: nil)
                    VStack(spacing: 0) {
                        ForEach(Array(records.enumerated()), id: \.element.id) { index, record in
                            if index > 0 { Divider().padding(.leading, 16) }
                            HStack {
                                Image(systemName: "trophy.fill")
                                    .font(.system(size: 13))
                                    .foregroundStyle(Theme.amber)
                                Text(record.exercise)
                                    .font(.flexBody())
                                    .foregroundStyle(Theme.ink)
                                    .lineLimit(1)
                                Spacer()
                                Text("\(WeightFormat.kg(record.weightKg)) × \(record.reps)")
                                    .font(.flexBodyBold())
                                    .monospacedDigit()
                                    .foregroundStyle(Theme.ink)
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                        }
                    }
                    .background(Theme.card)
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                }
            }
        }
    }

    // MARK: History

    private var historySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "History", subtitle: store.workouts.isEmpty ? nil : "Tap a session for details.")
            if store.workouts.isEmpty {
                EmptyStateCard(
                    icon: "dumbbell",
                    title: "No sessions yet",
                    message: "Log the first one. The bar doesn't care where you start."
                )
            } else {
                ForEach(store.workouts) { workout in
                    Button {
                        detailWorkout = workout
                    } label: {
                        WorkoutRow(workout: workout)
                    }
                    .buttonStyle(.plain)
                    .contextMenu {
                        Button {
                            store.saveRoutine(name: workout.title, exercises: workout.exercises)
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

enum WeightFormat {
    /// "60", "62.5": no trailing zeros.
    static func kg(_ value: Double) -> String {
        value == value.rounded() ? "\(Int(value))" : String(format: "%.1f", value)
    }
}

// MARK: - Workout row

struct WorkoutRow: View {
    let workout: Workout

    var body: some View {
        FlexCard(padding: 16) {
            VStack(alignment: .leading, spacing: 10) {
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
                Text(workout.exercises.map { "\($0.sets.count) × \($0.name)" }.joined(separator: "  ·  "))
                    .font(.flexCaption())
                    .foregroundStyle(Theme.inkSubtle)
                    .lineLimit(2)
            }
        }
    }
}

// MARK: - Active workout

struct ActiveWorkoutView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    @State private var title = ""
    @State private var exercises: [WorkoutExercise] = []
    @State private var startedAt = Date.now
    @State private var loaded = false

    @State private var showExercisePicker = false
    @State private var replacingExercise: WorkoutExercise.ID?
    @State private var historyFor: ExerciseName?
    @State private var confirmClose = false
    @State private var confirmFinish = false
    @State private var showNothingDone = false
    @State private var showSaveRoutine = false
    @State private var routineName = ""

    @State private var restEndsAt: Date?
    @State private var restTotal: TimeInterval = 90
    @State private var completedSets = 0

    struct ExerciseName: Identifiable {
        let name: String
        var id: String { name }
    }

    private var doneSets: [ExerciseSet] {
        exercises.flatMap(\.sets).filter { $0.isDone == true }
    }

    private var unfinishedSets: Int {
        exercises.flatMap(\.sets).filter { $0.isDone != true && ($0.reps > 0 || ($0.seconds ?? 0) > 0) }.count
    }

    private var liveVolume: Double {
        doneSets.filter(\.counts).reduce(0) { $0 + $1.weightKg * Double($1.reps) }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                header

                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        TextField("Workout name", text: $title)
                            .font(.flexBodyBold())
                            .padding(14)
                            .background(Theme.card)
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

                        if exercises.isEmpty {
                            VStack(spacing: 8) {
                                Image(systemName: "dumbbell")
                                    .font(.system(size: 28, weight: .semibold))
                                    .foregroundStyle(Theme.inkSubtle)
                                Text("Add your first exercise to get started.")
                                    .font(.flexCaption())
                                    .foregroundStyle(Theme.inkSubtle)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 30)
                        }

                        ForEach($exercises) { $exercise in
                            ExerciseCard(
                                exercise: $exercise,
                                onRemove: { exercises.removeAll { $0.id == exercise.id } },
                                onReplace: {
                                    replacingExercise = exercise.id
                                    showExercisePicker = true
                                },
                                onShowHistory: { historyFor = ExerciseName(name: exercise.name) },
                                onSetCompleted: { rest in startRest(rest) }
                            )
                        }

                        Button {
                            replacingExercise = nil
                            showExercisePicker = true
                        } label: {
                            Label("Add exercise", systemImage: "plus")
                        }
                        .buttonStyle(SecondaryButtonStyle(tint: Theme.accent, background: Theme.accentSoft))

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
                            .padding(.top, 4)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 20)
                }
                .scrollIndicators(.hidden)
                .scrollDismissesKeyboard(.interactively)

                if let restEndsAt {
                    restBar(until: restEndsAt)
                        .padding(.horizontal, 20)
                        .padding(.bottom, 12)
                }
            }
            .background(Theme.background)
            .toolbar(.hidden, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .keyboard) {
                    HStack {
                        Spacer()
                        Button("Done") { hideKeyboard() }
                            .fontWeight(.semibold)
                    }
                }
            }
        }
        .interactiveDismissDisabled(true)
        .sensoryFeedback(.success, trigger: completedSets)
        .sheet(isPresented: $showExercisePicker) {
            ExercisePickerSheet { template in
                addOrReplace(template)
            }
        }
        .sheet(item: $historyFor) { item in
            ExerciseHistorySheet(exerciseName: item.name)
        }
        .alert("Save as routine", isPresented: $showSaveRoutine) {
            TextField("Routine name", text: $routineName)
            Button("Save") {
                store.saveRoutine(name: routineName, exercises: exercises)
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Next time you start with these exercises and today's numbers as targets.")
        }
        .alert("Nothing to save yet", isPresented: $showNothingDone) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Tick off at least one set with the check button, then finish.")
        }
        .confirmationDialog("Finish workout?", isPresented: $confirmFinish, titleVisibility: .visible) {
            Button("Finish and save") { finish() }
            Button("Keep logging", role: .cancel) {}
        } message: {
            Text(unfinishedSets == 1
                 ? "1 set isn't ticked off and won't be saved."
                 : "\(unfinishedSets) sets aren't ticked off and won't be saved.")
        }
        .confirmationDialog("Leave this workout?", isPresented: $confirmClose, titleVisibility: .visible) {
            Button("Keep it for later") { dismiss() }
            Button("Discard workout", role: .destructive) {
                store.cancelRestNotification()
                store.updateWorkoutDraft(nil)
                dismiss()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("A kept workout waits on the Gym tab until you finish it.")
        }
        .onAppear(perform: load)
        .onChange(of: exercises) { _, _ in persist() }
        .onChange(of: title) { _, _ in persist() }
    }

    // MARK: Header

    private var header: some View {
        VStack(spacing: 14) {
            HStack {
                Button {
                    hideKeyboard()
                    confirmClose = true
                } label: {
                    Image(systemName: "chevron.down")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(Theme.ink)
                        .frame(width: 40, height: 40)
                        .background(Theme.card)
                        .clipShape(Circle())
                }
                .accessibilityLabel("Close workout")
                Spacer()
                Text("LOG WORKOUT")
                    .font(.flexMono(11))
                    .tracking(2.5)
                    .foregroundStyle(Theme.ink)
                Spacer()
                Button("Finish") {
                    hideKeyboard()
                    if doneSets.isEmpty {
                        showNothingDone = true
                    } else if unfinishedSets > 0 {
                        confirmFinish = true
                    } else {
                        finish()
                    }
                }
                .font(.flexBodyBold())
                .foregroundStyle(Theme.background)
                .padding(.horizontal, 16)
                .frame(height: 40)
                .background(Theme.ink)
                .clipShape(Capsule())
            }

            HStack(spacing: 0) {
                TimelineView(.periodic(from: .now, by: 1)) { context in
                    headerStat(RunFormat.duration(context.date.timeIntervalSince(startedAt)), "DURATION")
                }
                headerStat("\(WeightFormat.kg(liveVolume)) kg", "VOLUME")
                headerStat("\(doneSets.count)", "SETS")
            }
            .padding(.vertical, 10)
            .background(Theme.card)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .padding(.bottom, 12)
    }

    private func headerStat(_ value: String, _ label: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.flexBodyBold())
                .monospacedDigit()
                .foregroundStyle(Theme.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(label)
                .font(.flexMono(8))
                .tracking(1)
                .foregroundStyle(Theme.inkSubtle)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: Rest timer

    private func startRest(_ seconds: Int) {
        completedSets += 1
        guard seconds > 0 else { return }
        restTotal = TimeInterval(seconds)
        restEndsAt = Date.now.addingTimeInterval(restTotal)
        store.scheduleRestNotification(after: restTotal)
    }

    private func adjustRest(by delta: TimeInterval) {
        guard let end = restEndsAt else { return }
        let newEnd = max(Date.now.addingTimeInterval(1), end.addingTimeInterval(delta))
        restEndsAt = newEnd
        restTotal = max(restTotal + delta, 1)
        store.scheduleRestNotification(after: newEnd.timeIntervalSinceNow)
    }

    private func stopRest() {
        restEndsAt = nil
        store.cancelRestNotification()
    }

    private func restBar(until end: Date) -> some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            let remaining = max(0, end.timeIntervalSince(context.date))
            VStack(spacing: 10) {
                HStack {
                    Image(systemName: remaining > 0 ? "timer" : "checkmark.circle.fill")
                    Text(remaining > 0 ? "Rest \(RunFormat.duration(remaining))" : "Rest done. Next set.")
                        .monospacedDigit()
                    Spacer()
                    if remaining > 0 {
                        restButton("-15") { adjustRest(by: -15) }
                        restButton("+15") { adjustRest(by: 15) }
                    }
                    restButton(remaining > 0 ? "Skip" : "OK") { stopRest() }
                }
                .font(.flexBodyBold())
                .foregroundStyle(remaining > 0 ? Theme.ink : Theme.accent)

                GeometryReader { proxy in
                    Capsule()
                        .fill(Theme.ink.opacity(0.08))
                        .overlay(alignment: .leading) {
                            Capsule()
                                .fill(Theme.accent)
                                .frame(width: proxy.size.width * CGFloat(restTotal > 0 ? remaining / restTotal : 0))
                        }
                }
                .frame(height: 4)
            }
            .padding(14)
            .background(remaining > 0 ? Theme.card : Theme.accentSoft)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
    }

    private func restButton(_ label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.flexMono(11))
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Theme.background)
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    // MARK: Session state

    private func load() {
        guard !loaded else { return }
        loaded = true
        if let draft = store.workoutDraft {
            title = draft.title
            exercises = draft.exercises
            startedAt = draft.startedAt
        } else {
            startedAt = .now
            persist()
        }
    }

    private func persist() {
        guard loaded else { return }
        store.updateWorkoutDraft(WorkoutDraft(title: title, startedAt: startedAt, exercises: exercises))
    }

    private func addOrReplace(_ template: SampleData.ExerciseTemplate) {
        if let id = replacingExercise, let index = exercises.firstIndex(where: { $0.id == id }) {
            exercises[index].name = template.name
            exercises[index].kind = template.kind
        } else {
            // Start from last session's sets so the targets are ready.
            let previous = store.lastSets(for: template.name)?.sets ?? []
            let sets = previous.isEmpty
                ? [ExerciseSet()]
                : previous.map { ExerciseSet(weightKg: $0.weightKg, reps: $0.reps, kind: $0.kind, seconds: $0.seconds) }
            exercises.append(WorkoutExercise(name: template.name, sets: sets, kind: template.kind))
        }
        replacingExercise = nil
    }

    private func finish() {
        stopRest()
        store.logWorkout(
            title: title,
            duration: Date.now.timeIntervalSince(startedAt),
            exercises: exercises
        )
        dismiss()
    }

    private func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}

// MARK: - Exercise card

struct ExerciseCard: View {
    @Environment(AppStore.self) private var store
    @Binding var exercise: WorkoutExercise
    var onRemove: () -> Void
    var onReplace: () -> Void
    var onShowHistory: () -> Void
    /// Called with the rest (seconds) to run after a set is ticked.
    var onSetCompleted: (Int) -> Void

    static let restOptions = [0, 30, 60, 90, 120, 150, 180, 240, 300]
    static let defaultRest = 90

    private var rest: Int { exercise.restSeconds ?? Self.defaultRest }

    /// Last session's sets: the "previous" column, and the numbers to beat.
    private var previous: [ExerciseSet] {
        store.lastSets(for: exercise.name)?.sets ?? []
    }

    /// Best before today, so a new PR shows the moment it's ticked.
    private var bestBefore: Double {
        store.bestOneRepMax(for: exercise.name) ?? 0
    }

    private var template: SampleData.ExerciseTemplate? {
        SampleData.exercise(named: exercise.name)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                Button(action: onShowHistory) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(exercise.name)
                            .font(.flexBodyBold())
                            .foregroundStyle(Theme.accent)
                            .multilineTextAlignment(.leading)
                        if let template {
                            Text("\(template.muscle) · \(template.equipment)".uppercased())
                                .font(.flexMono(8))
                                .tracking(1)
                                .foregroundStyle(Theme.inkSubtle)
                        }
                    }
                }
                .buttonStyle(.plain)
                Spacer()
                Menu {
                    Button(exercise.notes == nil ? "Add note" : "Remove note", systemImage: "note.text") {
                        exercise.notes = exercise.notes == nil ? "" : nil
                    }
                    Picker("Rest timer", selection: Binding(
                        get: { rest },
                        set: { exercise.restSeconds = $0 }
                    )) {
                        ForEach(Self.restOptions, id: \.self) { seconds in
                            Text(seconds == 0 ? "Off" : RunFormat.duration(TimeInterval(seconds))).tag(seconds)
                        }
                    }
                    Button("Exercise history", systemImage: "clock.arrow.circlepath", action: onShowHistory)
                    Button("Replace exercise", systemImage: "arrow.triangle.2.circlepath", action: onReplace)
                    Button("Remove exercise", systemImage: "trash", role: .destructive, action: onRemove)
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(Theme.inkSubtle)
                        .frame(width: 36, height: 30)
                }
            }

            if exercise.notes != nil {
                TextField("Notes: seat height, grip, how it felt", text: Binding(
                    get: { exercise.notes ?? "" },
                    set: { exercise.notes = $0 }
                ), axis: .vertical)
                .font(.flexCaption())
                .lineLimit(1...4)
                .padding(10)
                .background(Theme.background)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            }

            HStack(spacing: 4) {
                Image(systemName: "timer")
                Text(rest == 0 ? "REST OFF" : "REST \(RunFormat.duration(TimeInterval(rest)))")
            }
            .font(.flexMono(9))
            .tracking(1)
            .foregroundStyle(Theme.inkSubtle)

            columnHeader

            ForEach($exercise.sets) { $set in
                let index = exercise.sets.firstIndex { $0.id == set.id } ?? 0
                SetRow(
                    index: index,
                    number: workingSetNumber(at: index),
                    entry: $set,
                    previous: previous.indices.contains(index) ? previous[index] : nil,
                    kind: exercise.exerciseKind,
                    bestBefore: bestBefore,
                    canDelete: exercise.sets.count > 1,
                    onDelete: { exercise.sets.removeAll { $0.id == set.id } },
                    onCompleted: { onSetCompleted(rest) }
                )
            }

            Button {
                let last = exercise.sets.last
                exercise.sets.append(ExerciseSet(
                    weightKg: last?.weightKg ?? 0,
                    reps: last?.reps ?? 0,
                    kind: last?.setKind == .warmup ? nil : last?.kind,
                    seconds: last?.seconds
                ))
            } label: {
                Label("Add set", systemImage: "plus")
                    .font(.flexCaption())
                    .foregroundStyle(Theme.ink)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 9)
                    .background(Theme.background)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            }
            .buttonStyle(.plain)
        }
        .padding(14)
        .background(Theme.card)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private var columnHeader: some View {
        HStack(spacing: 6) {
            Text("SET").frame(width: 30)
            Text("PREVIOUS").frame(maxWidth: .infinity)
            switch exercise.exerciseKind {
            case .weightReps:
                Text("KG").frame(width: 58)
                Text("REPS").frame(width: 50)
            case .bodyweight:
                Text("+KG").frame(width: 58)
                Text("REPS").frame(width: 50)
            case .duration:
                Text("SEC").frame(width: 114)
            }
            Image(systemName: "checkmark").frame(width: 34)
        }
        .font(.flexMono(8))
        .tracking(0.5)
        .foregroundStyle(Theme.inkSubtle)
    }

    /// Working sets are numbered 1, 2, 3; warm-ups, failure and drop sets
    /// show a letter instead and don't take a number.
    private func workingSetNumber(at index: Int) -> Int {
        exercise.sets.prefix(index + 1).filter { $0.setKind == .normal }.count
    }
}

// MARK: - Set row

struct SetRow: View {
    let index: Int
    let number: Int
    @Binding var entry: ExerciseSet
    let previous: ExerciseSet?
    let kind: ExerciseKind
    let bestBefore: Double
    let canDelete: Bool
    var onDelete: () -> Void
    var onCompleted: () -> Void

    private var isDone: Bool { entry.isDone == true }

    private var isRecord: Bool {
        isDone && entry.counts && bestBefore > 0 && entry.estimatedOneRepMax > bestBefore
    }

    private var previousLabel: String {
        guard let previous else { return "-" }
        switch kind {
        case .weightReps:
            return previous.reps > 0 ? "\(WeightFormat.kg(previous.weightKg)) × \(previous.reps)" : "-"
        case .bodyweight:
            guard previous.reps > 0 else { return "-" }
            return previous.weightKg > 0 ? "+\(WeightFormat.kg(previous.weightKg)) × \(previous.reps)" : "\(previous.reps) reps"
        case .duration:
            return (previous.seconds ?? 0) > 0 ? "\(previous.seconds ?? 0)s" : "-"
        }
    }

    var body: some View {
        HStack(spacing: 6) {
            Menu {
                ForEach(SetKind.allCases, id: \.self) { option in
                    Button {
                        entry.kind = option
                    } label: {
                        if entry.setKind == option {
                            Label(option.label, systemImage: "checkmark")
                        } else {
                            Text(option.label)
                        }
                    }
                }
                if canDelete {
                    Divider()
                    Button("Delete set", systemImage: "trash", role: .destructive, action: onDelete)
                }
            } label: {
                Text(entry.setKind.badge ?? "\(number)")
                    .font(.flexMono(12))
                    .foregroundStyle(badgeColor)
                    .frame(width: 30, height: 32)
                    .background(Theme.background.opacity(isDone ? 0 : 1))
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            }
            .accessibilityLabel("Set \(index + 1), \(entry.setKind.label)")

            Button(action: copyPrevious) {
                HStack(spacing: 4) {
                    if isRecord {
                        Image(systemName: "trophy.fill")
                            .foregroundStyle(Theme.amber)
                    }
                    Text(previousLabel)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
                .font(.flexMono(11))
                .foregroundStyle(Theme.inkSubtle)
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.plain)
            .disabled(previous == nil || isDone)

            switch kind {
            case .weightReps, .bodyweight:
                numberField(
                    prompt: previous.map { WeightFormat.kg($0.weightKg) } ?? "0",
                    value: Binding(
                        get: { entry.weightKg > 0 ? entry.weightKg : nil },
                        set: { entry.weightKg = max(0, $0 ?? 0) }
                    ),
                    width: 58,
                    decimal: true
                )
                numberField(
                    prompt: previous.map { "\($0.reps)" } ?? "0",
                    value: Binding(
                        get: { entry.reps > 0 ? Double(entry.reps) : nil },
                        set: { entry.reps = max(0, Int($0 ?? 0)) }
                    ),
                    width: 50,
                    decimal: false
                )
            case .duration:
                numberField(
                    prompt: previous.flatMap(\.seconds).map { "\($0)" } ?? "0",
                    value: Binding(
                        get: { (entry.seconds ?? 0) > 0 ? Double(entry.seconds ?? 0) : nil },
                        set: { entry.seconds = max(0, Int($0 ?? 0)) }
                    ),
                    width: 114,
                    decimal: false
                )
            }

            Button(action: toggleDone) {
                Image(systemName: "checkmark")
                    .font(.system(size: 13, weight: .heavy))
                    .foregroundStyle(isDone ? Theme.background : Theme.inkSubtle)
                    .frame(width: 34, height: 32)
                    .background(isDone ? Theme.accent : Theme.background)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            }
            .buttonStyle(.plain)
            .accessibilityLabel(isDone ? "Mark set not done" : "Mark set done")
        }
        .padding(.vertical, 3)
        .padding(.horizontal, 4)
        .background(isDone ? Theme.accentSoft : .clear)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .animation(.snappy(duration: 0.2), value: isDone)
    }

    private var badgeColor: Color {
        switch entry.setKind {
        case .warmup: Theme.amber
        case .failure, .drop: Theme.danger
        case .normal: Theme.ink
        }
    }

    private func numberField(prompt: String, value: Binding<Double?>, width: CGFloat, decimal: Bool) -> some View {
        TextField(prompt, value: value, format: .number)
            .keyboardType(decimal ? .decimalPad : .numberPad)
            .multilineTextAlignment(.center)
            .font(.flexBodyBold())
            .monospacedDigit()
            .frame(width: width, height: 32)
            .background(isDone ? Color.clear : Theme.background)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .disabled(isDone)
    }

    private func copyPrevious() {
        guard let previous else { return }
        entry.weightKg = previous.weightKg
        entry.reps = previous.reps
        entry.seconds = previous.seconds
    }

    /// Ticking an empty set uses last session's numbers (the grey
    /// placeholders), the way Hevy does. A set with nothing at all to log
    /// stays unticked.
    private func toggleDone() {
        if isDone {
            entry.isDone = false
            return
        }
        if let previous {
            if kind == .duration {
                if (entry.seconds ?? 0) == 0 { entry.seconds = previous.seconds }
            } else {
                if entry.reps == 0 { entry.reps = previous.reps }
                if entry.weightKg == 0 && kind == .weightReps { entry.weightKg = previous.weightKg }
            }
        }
        let hasWork = kind == .duration ? (entry.seconds ?? 0) > 0 : entry.reps > 0
        guard hasWork else { return }
        entry.isDone = true
        onCompleted()
    }
}

// MARK: - Exercise picker

struct ExercisePickerSheet: View {
    var onPick: (SampleData.ExerciseTemplate) -> Void
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var search = ""
    @State private var muscle: String?

    /// Exercises you've done, most recent first. Easiest to find again.
    private var recent: [SampleData.ExerciseTemplate] {
        var seen = Set<String>()
        var result: [SampleData.ExerciseTemplate] = []
        for workout in store.workouts {
            for exercise in workout.exercises where !seen.contains(exercise.name) {
                seen.insert(exercise.name)
                result.append(SampleData.exercise(named: exercise.name)
                    ?? SampleData.ExerciseTemplate(name: exercise.name, muscle: "Custom", equipment: "Other", kind: exercise.exerciseKind))
            }
        }
        return Array(result.prefix(6))
    }

    private var filtered: [SampleData.ExerciseTemplate] {
        let query = search.trimmingCharacters(in: .whitespaces)
        return SampleData.exerciseCatalog.filter { template in
            (muscle == nil || template.muscle == muscle)
                && (query.isEmpty
                    || template.name.localizedCaseInsensitiveContains(query)
                    || template.equipment.localizedCaseInsensitiveContains(query)
                    || template.muscle.localizedCaseInsensitiveContains(query))
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 12) {
                HStack(spacing: 10) {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(Theme.inkSubtle)
                    TextField("Search exercises", text: $search)
                        .font(.flexBody())
                        .autocorrectionDisabled()
                }
                .padding(12)
                .background(Theme.card)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .padding(.horizontal, 20)

                ScrollView(.horizontal) {
                    HStack(spacing: 8) {
                        SelectableChip(label: "All", isSelected: muscle == nil) { muscle = nil }
                        ForEach(SampleData.muscleGroups, id: \.self) { group in
                            SelectableChip(label: group, isSelected: muscle == group) { muscle = group }
                        }
                    }
                    .padding(.horizontal, 20)
                }
                .scrollIndicators(.hidden)

                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 8) {
                        if search.isEmpty && muscle == nil && !recent.isEmpty {
                            sectionLabel("RECENT")
                            ForEach(recent) { template in row(template) }
                            sectionLabel("ALL EXERCISES")
                        }
                        ForEach(filtered) { template in row(template) }

                        // Not in the list? Add whatever was typed.
                        let typed = search.trimmingCharacters(in: .whitespaces)
                        if !typed.isEmpty && !filtered.contains(where: { $0.name.caseInsensitiveCompare(typed) == .orderedSame }) {
                            Button {
                                pick(SampleData.ExerciseTemplate(name: typed, muscle: "Custom", equipment: "Other", kind: .weightReps))
                            } label: {
                                Label("Add \"\(typed)\" as a new exercise", systemImage: "plus")
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
                .scrollDismissesKeyboard(.interactively)
            }
            .padding(.top, 8)
            .background(Theme.background)
            .navigationTitle("Add exercise")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
        .tint(Theme.ink)
        .presentationDetents([.large])
    }

    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(.flexMono(9))
            .tracking(1.5)
            .foregroundStyle(Theme.inkSubtle)
            .padding(.top, 6)
    }

    private func pick(_ template: SampleData.ExerciseTemplate) {
        onPick(template)
        dismiss()
    }

    private func row(_ template: SampleData.ExerciseTemplate) -> some View {
        Button {
            pick(template)
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(template.name)
                        .font(.flexBodyBold())
                        .foregroundStyle(Theme.ink)
                    Text("\(template.muscle) · \(template.equipment)".uppercased())
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
}

// MARK: - Exercise history

struct ExerciseHistorySheet: View {
    let exerciseName: String
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        let sessions = store.history(for: exerciseName)
        let heaviest = sessions.flatMap(\.sets).filter(\.counts).max { $0.weightKg < $1.weightKg }
        let bestOneRep = store.bestOneRepMax(for: exerciseName) ?? 0
        let points = sessions.prefix(20).reversed().compactMap { session -> (date: Date, value: Double)? in
            let best = session.sets.filter(\.counts).map(\.estimatedOneRepMax).max() ?? 0
            return best > 0 ? (session.date, best) : nil
        }

        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    HStack(spacing: 8) {
                        TrackStat(value: heaviest.map { "\(WeightFormat.kg($0.weightKg))×\($0.reps)" } ?? "-", label: "Heaviest")
                        TrackStat(value: bestOneRep > 0 ? WeightFormat.kg(bestOneRep.rounded()) : "-", label: "Est. 1RM kg")
                        TrackStat(value: "\(sessions.count)", label: "Sessions")
                    }

                    if points.count >= 2 {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("ESTIMATED 1RM")
                                .font(.flexMono(9))
                                .tracking(1.5)
                                .foregroundStyle(Theme.inkSubtle)
                            Chart(points, id: \.date) { point in
                                LineMark(x: .value("Date", point.date), y: .value("kg", point.value))
                                    .foregroundStyle(Theme.accent)
                                PointMark(x: .value("Date", point.date), y: .value("kg", point.value))
                                    .foregroundStyle(Theme.accent)
                            }
                            .chartYScale(domain: .automatic(includesZero: false))
                            .frame(height: 160)
                        }
                        .padding(14)
                        .background(Theme.card)
                        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    }

                    if sessions.isEmpty {
                        EmptyStateCard(icon: "clock", title: "No history yet", message: "Finish a workout with this exercise and it shows up here.")
                    }

                    ForEach(Array(sessions.enumerated()), id: \.offset) { _, session in
                        VStack(alignment: .leading, spacing: 8) {
                            Text(session.date.formatted(.dateTime.weekday(.abbreviated).day().month().year()).uppercased())
                                .font(.flexMono(9))
                                .tracking(1)
                                .foregroundStyle(Theme.inkSubtle)
                            ForEach(Array(session.sets.enumerated()), id: \.offset) { index, set in
                                HStack {
                                    Text(set.setKind.badge ?? "\(index + 1)")
                                        .font(.flexMono(11))
                                        .foregroundStyle(Theme.inkSubtle)
                                        .frame(width: 24, alignment: .leading)
                                    Text(setText(set))
                                        .font(.flexBody())
                                        .monospacedDigit()
                                        .foregroundStyle(Theme.ink)
                                    Spacer()
                                }
                            }
                        }
                        .padding(14)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Theme.card)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }
                }
                .padding(20)
            }
            .background(Theme.background)
            .navigationTitle(exerciseName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .tint(Theme.ink)
    }

    private func setText(_ set: ExerciseSet) -> String {
        if let seconds = set.seconds, seconds > 0, set.reps == 0 { return "\(seconds)s" }
        return set.weightKg > 0 ? "\(WeightFormat.kg(set.weightKg)) kg × \(set.reps)" : "\(set.reps) reps"
    }
}

// MARK: - Workout detail

struct WorkoutDetailSheet: View {
    let workout: Workout
    /// Start a new session with this one's exercises and numbers.
    var onRepeat: ([WorkoutExercise]) -> Void
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var savedRoutine = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text(workout.date.formatted(.dateTime.weekday(.wide).day().month().year().hour().minute()).uppercased())
                        .font(.flexMono(10))
                        .tracking(1)
                        .foregroundStyle(Theme.inkSubtle)

                    HStack(spacing: 8) {
                        TrackStat(value: RunFormat.duration(workout.duration), label: "Duration")
                        TrackStat(value: "\(Int(workout.totalVolumeKg))", label: "Volume kg")
                        TrackStat(value: "\(workout.totalSets)", label: "Sets")
                    }

                    ForEach(workout.exercises) { exercise in
                        VStack(alignment: .leading, spacing: 8) {
                            Text(exercise.name)
                                .font(.flexBodyBold())
                                .foregroundStyle(Theme.ink)
                            if let notes = exercise.notes, !notes.isEmpty {
                                Text(notes)
                                    .font(.flexCaption())
                                    .foregroundStyle(Theme.inkSubtle)
                            }
                            ForEach(Array(exercise.sets.enumerated()), id: \.offset) { index, set in
                                HStack {
                                    Text(set.setKind.badge ?? "\(index + 1)")
                                        .font(.flexMono(11))
                                        .foregroundStyle(Theme.inkSubtle)
                                        .frame(width: 24, alignment: .leading)
                                    Text(setText(set, kind: exercise.exerciseKind))
                                        .font(.flexBody())
                                        .monospacedDigit()
                                        .foregroundStyle(Theme.ink)
                                    Spacer()
                                }
                            }
                        }
                        .padding(14)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Theme.card)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }

                    Button(savedRoutine ? "Saved as a routine" : "Save as routine") {
                        store.saveRoutine(name: workout.title, exercises: workout.exercises)
                        savedRoutine = true
                    }
                    .buttonStyle(SecondaryButtonStyle())
                    .disabled(savedRoutine)
                }
                .padding(20)
            }
            .background(Theme.background)
            .safeAreaInset(edge: .bottom) {
                Button("Do this workout again") {
                    onRepeat(Routine(name: workout.title, exerciseNames: [], exercises: workout.exercises).startingExercises)
                }
                .buttonStyle(PrimaryButtonStyle())
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(Theme.background)
            }
            .navigationTitle(workout.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .tint(Theme.ink)
    }

    private func setText(_ set: ExerciseSet, kind: ExerciseKind) -> String {
        switch kind {
        case .duration: return "\(set.seconds ?? 0)s"
        case .bodyweight: return set.weightKg > 0 ? "+\(WeightFormat.kg(set.weightKg)) kg × \(set.reps)" : "\(set.reps) reps"
        case .weightReps: return "\(WeightFormat.kg(set.weightKg)) kg × \(set.reps)"
        }
    }
}

// MARK: - Routine editor

struct RoutineEditorSheet: View {
    let routine: Routine?
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var exercises: [WorkoutExercise] = []
    @State private var showPicker = false

    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty && !exercises.isEmpty
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    TextField("Routine name, like Push day", text: $name)
                        .font(.flexBodyBold())
                        .padding(14)
                        .background(Theme.card)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

                    ForEach($exercises) { $exercise in
                        HStack(spacing: 12) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(exercise.name)
                                    .font(.flexBodyBold())
                                    .foregroundStyle(Theme.ink)
                                Text("\(exercise.sets.count) SETS")
                                    .font(.flexMono(9))
                                    .tracking(1)
                                    .foregroundStyle(Theme.inkSubtle)
                            }
                            Spacer()
                            stepButton("minus") {
                                if exercise.sets.count > 1 { exercise.sets.removeLast() }
                            }
                            stepButton("plus") {
                                let last = exercise.sets.last
                                exercise.sets.append(ExerciseSet(weightKg: last?.weightKg ?? 0, reps: last?.reps ?? 0, seconds: last?.seconds))
                            }
                            Button {
                                exercises.removeAll { $0.id == exercise.id }
                            } label: {
                                Image(systemName: "trash")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(Theme.inkSubtle)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Remove \(exercise.name)")
                        }
                        .padding(14)
                        .background(Theme.card)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }

                    Button {
                        showPicker = true
                    } label: {
                        Label("Add exercise", systemImage: "plus")
                    }
                    .buttonStyle(SecondaryButtonStyle(tint: Theme.accent, background: Theme.accentSoft))
                }
                .padding(20)
            }
            .background(Theme.background)
            .navigationTitle(routine == nil ? "New routine" : "Edit routine")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        save()
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .disabled(!canSave)
                }
            }
            .sheet(isPresented: $showPicker) {
                ExercisePickerSheet { template in
                    let previous = store.lastSets(for: template.name)?.sets ?? []
                    let sets = previous.isEmpty
                        ? [ExerciseSet(), ExerciseSet(), ExerciseSet()]
                        : previous.map { ExerciseSet(weightKg: $0.weightKg, reps: $0.reps, kind: $0.kind, seconds: $0.seconds) }
                    exercises.append(WorkoutExercise(name: template.name, sets: sets, kind: template.kind))
                }
            }
            .onAppear {
                guard let routine, exercises.isEmpty else { return }
                name = routine.name
                exercises = routine.startingExercises
            }
        }
        .tint(Theme.ink)
    }

    private func save() {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        if var routine {
            routine.name = trimmed
            routine.exerciseNames = exercises.map(\.name)
            routine.exercises = exercises
            store.updateRoutine(routine)
        } else {
            store.saveRoutine(name: trimmed, exercises: exercises)
        }
    }

    private func stepButton(_ icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(Theme.ink)
                .frame(width: 32, height: 32)
                .background(Theme.background)
                .clipShape(Circle())
        }
        .buttonStyle(.plain)
    }
}
