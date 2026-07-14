import SwiftUI

/// Training log: start a session, add exercises, log sets × kg × reps.
/// Finishing auto-completes today's gym commitment.
struct LiftSection: View {
    @Environment(AppStore.self) private var store
    @State private var showActiveWorkout = false

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 10) {
                TrackStat(value: "\(store.workouts.count)", label: "Sessions")
                TrackStat(value: volumeText, label: "Total KG")
                TrackStat(value: "\(store.workoutsThisWeek)", label: "This week")
            }

            Button {
                showActiveWorkout = true
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "dumbbell")
                    Text("Start workout")
                }
            }
            .buttonStyle(PrimaryButtonStyle())

            VStack(alignment: .leading, spacing: 12) {
                SectionHeader(title: "History", subtitle: store.workouts.isEmpty ? nil : "Most recent first.")
                if store.workouts.isEmpty {
                    EmptyStateCard(
                        icon: "dumbbell",
                        title: "No sessions yet",
                        message: "Log the first one. The bar doesn't care where you start."
                    )
                } else {
                    ForEach(store.workouts) { workout in
                        WorkoutRow(workout: workout)
                    }
                }
            }
        }
        .fullScreenCover(isPresented: $showActiveWorkout) {
            ActiveWorkoutView()
        }
    }

    private var volumeText: String {
        let volume = store.totalVolumeKg
        return volume >= 10000
            ? String(format: "%.1ft", volume / 1000)
            : "\(Int(volume))"
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

    @State private var title = ""
    @State private var exercises: [WorkoutExercise] = []
    @State private var startedAt = Date.now
    @State private var showExercisePicker = false
    @State private var confirmDiscard = false

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
                        }
                    }

                    Button {
                        showExercisePicker = true
                    } label: {
                        Label("Add exercise", systemImage: "plus")
                    }
                    .buttonStyle(SecondaryButtonStyle())
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
            }
            .scrollIndicators(.hidden)
            .scrollDismissesKeyboard(.interactively)

            Button("Finish workout") {
                store.logWorkout(title: title, duration: Date.now.timeIntervalSince(startedAt), exercises: exercises)
                dismiss()
            }
            .buttonStyle(PrimaryButtonStyle())
            .disabled(!hasLoggedSets)
            .opacity(hasLoggedSets ? 1 : 0.4)
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
        .confirmationDialog("Discard this workout?", isPresented: $confirmDiscard, titleVisibility: .visible) {
            Button("Discard workout", role: .destructive) { dismiss() }
            Button("Keep going", role: .cancel) {}
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
                let last = exercise.sets.last
                exercise.sets.append(ExerciseSet(weightKg: last?.weightKg ?? 0, reps: last?.reps ?? 0))
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
