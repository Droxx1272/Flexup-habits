import Foundation
import Observation
import UserNotifications

/// Single source of truth for the app. Everything the UI shows flows from
/// here, and every user action lands here — one place to later swap local
/// persistence for a real backend without touching views.
@Observable
final class AppStore {

    // MARK: - State

    var profile: UserProfile?
    var account: Account?
    var habits: [Habit] = []
    var commitments: [Commitment] = []
    var activities: [Activity] = []
    var achievements: [Achievement] = []
    var communities: [Community] = []
    var friends: [Friend] = []
    var runs: [Run] = []
    var workouts: [Workout] = []
    var routines: [Routine] = []
    var weightEntries: [WeightEntry] = []
    var foodEntries: [FoodEntry] = []
    var progressPhotos: [ProgressPhoto] = []
    var nutritionGoals = NutritionGoals()
    /// Millilitres of water per day, keyed by `dayKey`.
    var waterByDay: [String: Int] = [:]
    /// The paged introduction runs once, before sign-in.
    var hasSeenIntro = false
    /// Which pillars friends see in their feed.
    var sharing = SharingSettings()
    /// Outcomes and weekly targets, asked right after sign-up.
    var goals = UserGoals()
    var reminders = ReminderPreferences()

    /// Friends, cheers and nudges — the part of the app that lives on the
    /// FlexUp server. Reached as `store.community` so state still has one home.
    let community = CommunityStore()
    /// How this person actually cooks, in their words. Fed to the photo
    /// estimator so regional dishes aren't scored against Western recipes.
    var cuisineContext: String = ""
    var wake = WakeConfig()
    var wakeCheckInDays: Set<String> = []
    var bedtime = BedtimeConfig()
    var sleepSessions: [SleepSession] = []
    var socialEvents: [SocialEvent] = []
    var moodByDay: [String: String] = [:]
    var chats: [UUID: [ChatMessage]] = [:]

    /// Non-nil while the celebration overlay is showing. Never persisted.
    var celebration: Celebration?

    var hasOnboarded: Bool { profile != nil }
    var isSignedIn: Bool { account != nil }

    /// Kept as its own name because half the app already reads it.
    var calorieBudget: Int {
        get { nutritionGoals.calories }
        set { nutritionGoals.calories = newValue }
    }

    func completeIntro() {
        hasSeenIntro = true
        save()
    }

    /// Lets someone watch the introduction again from Stats.
    func replayIntro() {
        hasSeenIntro = false
    }

    func signIn(_ account: Account) {
        self.account = account
        save()
    }

    /// Signing out gates the app behind login again. Local data stays on
    /// device — signing back in with the same account picks it right up.
    func signOut() {
        account = nil
        save()
        let community = self.community
        Task { @MainActor in
            await community.logOut()
        }
    }

    /// The app's key for "today" — shared with the server so friends'
    /// "done today" means the same day on both sides.
    var todayKey: String { dayKey() }

    func updateSharing(_ settings: SharingSettings) {
        sharing = settings
        save()
    }

    func updateGoals(_ newGoals: UserGoals) {
        goals = newGoals
        save()
    }

    func updateReminders(_ preferences: ReminderPreferences) {
        reminders = preferences
        save()
        updateHabitReminders()
    }

    func setWakeAlarm(_ enabled: Bool) {
        wake.enabled = enabled
        updateWakeSchedule()
        save()
    }

    func setBedtimeReminder(_ enabled: Bool) {
        bedtime.enabled = enabled
        updateBedtimeSchedule()
    }

    /// This calendar week against the weekly targets from onboarding.
    var weekProgress: (runs: Int, workouts: Int, wakeUps: Int, wakeDays: Int) {
        guard let week = calendar.dateInterval(of: .weekOfYear, for: .now) else { return (0, 0, 0, 0) }
        let runsThisWeek = runs.filter { week.contains($0.date) }.count
        let workoutsThisWeek = workouts.filter { week.contains($0.date) }.count
        var wakeUps = 0
        var scheduled = 0
        var day = week.start
        while day < week.end {
            if wake.days.contains(calendar.component(.weekday, from: day)) {
                scheduled += 1
                if wakeCheckInDays.contains(dayKey(day)) { wakeUps += 1 }
            }
            guard let next = calendar.date(byAdding: .day, value: 1, to: day) else { break }
            day = next
        }
        return (runsThisWeek, workoutsThisWeek, wakeUps, scheduled)
    }

    /// Hand a real, just-logged activity to friends, if that pillar is shared.
    private func shareWithFriends(_ kind: ActivityKind, title: String, detail: String = "", streak: Int? = nil) {
        guard FeatureFlags.community, sharing.allows(kind) else { return }
        community.share(PendingActivity(
            kind: kind,
            title: title,
            detail: detail,
            day: dayKey(),
            occurredAt: .now,
            streak: streak
        ))
    }

    private let calendar = Calendar.current

    // MARK: - Init

    init() {
        load()
        if activities.isEmpty { seedWorld() }
        if socialEvents.isEmpty { socialEvents = SampleData.socialEvents(activities: activities) }
        mergeAchievementCatalog()
        refreshDiscoverFeed()
        rolloverMissed()
        generateUpcomingCommitments()
        removeLegacyAPIKey()
        save()
    }

    private func seedWorld() {
        activities = SampleData.activities()
        communities = SampleData.communities
        achievements = SampleData.achievements
        friends = SampleData.friends
    }

    /// New app versions can add achievements; fold any missing catalog
    /// entries into previously-saved state.
    private func mergeAchievementCatalog() {
        for item in SampleData.achievements where !achievements.contains(where: { $0.key == item.key }) {
            achievements.append(item)
        }
    }

    /// Sample activities have fixed dates; once they've all passed, drop the
    /// stale unjoined ones and seed a fresh batch so Discover never looks dead.
    private func refreshDiscoverFeed() {
        guard !activities.contains(where: { $0.date > .now }) else { return }
        activities.removeAll { !$0.isJoined && $0.date < .now }
        activities.append(contentsOf: SampleData.activities())
    }

    // MARK: - Onboarding

    func completeOnboarding(name: String, identity: String, interests: [ActivityCategory], templates: [HabitTemplate]) {
        profile = UserProfile(name: name, identityStatement: identity, interests: interests)
        for template in templates {
            habits.append(Habit(
                title: template.title,
                category: template.category,
                scheduleWeekdays: template.weekdays,
                timeOfDay: template.timeOfDay,
                verification: template.verification,
                durationMinutes: template.durationMinutes
            ))
        }
        generateUpcomingCommitments()
        updateHabitReminders()
        save()
    }

    // MARK: - Habits

    /// Habits are editable for the life of the app — what you commit to in
    /// week one shouldn't be locked in forever.
    func addHabit(
        title: String,
        category: ActivityCategory,
        weekdays: Set<Int>,
        timeOfDay: TimeOfDay,
        verification: VerificationMethod,
        durationMinutes: Int
    ) {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !weekdays.isEmpty else { return }
        habits.append(Habit(
            title: trimmed,
            category: category,
            scheduleWeekdays: weekdays,
            timeOfDay: timeOfDay,
            verification: verification,
            durationMinutes: durationMinutes
        ))
        generateUpcomingCommitments()
        updateHabitReminders()
        save()
    }

    /// Save an edited habit and re-materialize its upcoming commitments so
    /// a changed time or day takes effect immediately. Completed history is
    /// never touched.
    func updateHabit(_ habit: Habit) {
        guard let index = habits.firstIndex(where: { $0.id == habit.id }) else { return }
        habits[index] = habit
        removeUpcomingCommitments(forHabit: habit.id)
        generateUpcomingCommitments()
        updateHabitReminders()
        save()
    }

    func deleteHabit(_ habit: Habit) {
        habits.removeAll { $0.id == habit.id }
        removeUpcomingCommitments(forHabit: habit.id)
        updateHabitReminders()
        save()
    }

    /// Drop not-yet-done commitments for a habit, keeping completed and
    /// missed ones so the record stays honest.
    private func removeUpcomingCommitments(forHabit habitID: UUID) {
        commitments.removeAll { commitment in
            commitment.habitID == habitID
                && commitment.status != .completed
                && commitment.status != .missed
        }
    }

    /// A habit nobody is reminded of is just a note. Each one gets a nudge
    /// at its scheduled time.
    ///
    /// iOS allows 64 pending notifications per app and the wake fallback
    /// plus bedtime already claim ~49, so habit reminders are capped at 14.
    private static let habitReminderCap = 14

    func updateHabitReminders() {
        let center = UNUserNotificationCenter.current()
        let habitsSnapshot = habits
        let remindersOn = reminders.habitReminders

        center.getPendingNotificationRequests { requests in
            let stale = requests.map(\.identifier).filter { $0.hasPrefix("habit-") }
            center.removePendingNotificationRequests(withIdentifiers: stale)
            guard remindersOn, !habitsSnapshot.isEmpty else { return }

            center.requestAuthorization(options: [.alert, .sound]) { granted, _ in
                guard granted else { return }
                var scheduled = 0

                for habit in habitsSnapshot {
                    for weekday in habit.scheduleWeekdays.sorted() {
                        guard scheduled < Self.habitReminderCap else { return }

                        var components = DateComponents()
                        components.weekday = weekday
                        components.hour = habit.timeOfDay.defaultHour
                        components.minute = 0

                        let content = UNMutableNotificationContent()
                        content.title = habit.title
                        content.body = "\(habit.durationMinutes) minutes. You planned this one."
                        content.sound = .default

                        center.add(UNNotificationRequest(
                            identifier: "habit-\(habit.id.uuidString)-\(weekday)",
                            content: content,
                            trigger: UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
                        ))
                        scheduled += 1
                    }
                }
            }
        }
    }

    // MARK: - Today

    var todayCommitments: [Commitment] {
        commitments
            .filter { calendar.isDateInToday($0.date) }
            .sorted { $0.date < $1.date }
    }

    var todayProgress: Double {
        let today = todayCommitments
        guard !today.isEmpty else { return 0 }
        let done = today.filter { $0.status == .completed }.count
        return Double(done) / Double(today.count)
    }

    func commitments(on date: Date) -> [Commitment] {
        commitments
            .filter { calendar.isDate($0.date, inSameDayAs: date) }
            .sorted { $0.date < $1.date }
    }

    func joinedActivities(on date: Date) -> [Activity] {
        activities.filter { $0.isJoined && calendar.isDate($0.date, inSameDayAs: date) }
    }

    // MARK: - Mood

    private func dayKey(_ date: Date = .now) -> String {
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        return "\(parts.year ?? 0)-\(parts.month ?? 0)-\(parts.day ?? 0)"
    }

    /// Inverse of `dayKey` — noon on that day, so time zones can't tip it.
    private func date(fromDayKey key: String) -> Date? {
        let parts = key.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3 else { return nil }
        return calendar.date(from: DateComponents(year: parts[0], month: parts[1], day: parts[2], hour: 12))
    }

    var todayMood: String? {
        get { moodByDay[dayKey()] }
        set { moodByDay[dayKey()] = newValue; save() }
    }

    // MARK: - Commitment actions

    func liveCommitment(_ commitment: Commitment) -> Commitment {
        commitments.first { $0.id == commitment.id } ?? commitment
    }

    /// `sharesActivity` is false when a logged run or workout completes the
    /// commitment — that run or workout is shared on its own instead.
    func complete(_ commitment: Commitment, sharesActivity: Bool = true) {
        guard let index = commitments.firstIndex(where: { $0.id == commitment.id }),
              commitments[index].status != .completed else { return }

        commitments[index].status = .completed
        commitments[index].completedAt = .now

        var streak: Int?
        if let habitID = commitments[index].habitID,
           let habitIndex = habits.firstIndex(where: { $0.id == habitID }) {
            habits[habitIndex].streak += 1
            habits[habitIndex].bestStreak = max(habits[habitIndex].bestStreak, habits[habitIndex].streak)
            streak = habits[habitIndex].streak
        }

        if sharesActivity {
            shareWithFriends(
                .habit,
                title: "Done: \(commitments[index].title)",
                detail: (streak ?? 0) > 1 ? "\(streak ?? 0) in a row" : ""
            )
        }

        let unlocked = checkUnlocks()
        celebration = Celebration(
            title: SampleData.completionTitles.randomElement() ?? "Done.",
            message: SampleData.completionMessages.randomElement() ?? "Keep going.",
            streak: streak,
            achievement: unlocked.first
        )
        save()
    }

    func confirm(_ commitment: Commitment) {
        update(commitment) { $0.status = .confirmed }
    }

    func markMissed(_ commitment: Commitment) {
        update(commitment) { $0.status = .missed }
        if let habitID = commitment.habitID,
           let habitIndex = habits.firstIndex(where: { $0.id == habitID }) {
            habits[habitIndex].streak = 0
        }
        save()
    }

    func reschedule(_ commitment: Commitment, to date: Date) {
        update(commitment) {
            $0.date = date
            $0.status = .rescheduled
        }
    }

    private func update(_ commitment: Commitment, _ transform: (inout Commitment) -> Void) {
        guard let index = commitments.firstIndex(where: { $0.id == commitment.id }) else { return }
        transform(&commitments[index])
        save()
    }

    func addCommitment(title: String, category: ActivityCategory, date: Date, verification: VerificationMethod, durationMinutes: Int) {
        commitments.append(Commitment(
            title: title,
            category: category,
            date: date,
            verification: verification,
            durationMinutes: durationMinutes
        ))
        save()
    }

    /// Quick Start: do one small thing right now.
    func quickStart(_ category: ActivityCategory) {
        commitments.append(Commitment(
            title: "\(category.label) — right now",
            category: category,
            date: .now,
            status: .confirmed,
            verification: .timer,
            durationMinutes: 15
        ))
        save()
    }

    // MARK: - Activities

    func liveActivity(_ activity: Activity) -> Activity {
        activities.first { $0.id == activity.id } ?? activity
    }

    func toggleJoin(_ activity: Activity) {
        guard let index = activities.firstIndex(where: { $0.id == activity.id }) else { return }
        let name = profile?.name ?? "You"

        if activities[index].isJoined {
            activities[index].isJoined = false
            activities[index].attendees.removeAll { $0 == name }
            commitments.removeAll { $0.activityID == activity.id && $0.status != .completed }
        } else {
            activities[index].isJoined = true
            activities[index].attendees.append(name)
            commitments.append(Commitment(
                title: activity.title,
                category: activity.category,
                date: activity.date,
                status: .confirmed,
                verification: .partner,
                durationMinutes: 60,
                activityID: activity.id
            ))
            if let unlocked = unlock("show_up") {
                celebration = Celebration(
                    title: "You're in.",
                    message: "\(activity.title) is on your calendar. Showing up is the hard part.",
                    streak: nil,
                    achievement: unlocked
                )
            }
        }
        save()
    }

    func commitment(for activity: Activity) -> Commitment? {
        commitments.first { $0.activityID == activity.id }
    }

    func sendMessage(_ text: String, in activity: Activity) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        chats[activity.id, default: []].append(ChatMessage(author: profile?.name ?? "You", text: trimmed))
        save()
    }

    var upcomingFriendActivities: [Activity] {
        activities
            .filter { !$0.friendsGoing.isEmpty && $0.date > .now }
            .sorted { $0.date < $1.date }
    }

    // MARK: - Runs

    /// Log a tracked run. Counts toward today's run commitment if one exists,
    /// so a real run never has to be marked done twice.
    func logRun(
        distanceMeters: Double,
        duration: TimeInterval,
        route: [RoutePoint] = [],
        splitsSeconds: [Double] = [],
        elevationGainM: Double = 0
    ) {
        let run = Run(
            date: .now,
            distanceMeters: distanceMeters,
            duration: duration,
            route: route,
            splitsSeconds: splitsSeconds,
            elevationGainM: elevationGainM
        )
        runs.insert(run, at: 0)

        var unlocked: [Achievement] = []
        if let a = unlock("first_run") { unlocked.append(a) }
        if run.kilometers >= 5, let a = unlock("five_k") { unlocked.append(a) }

        if run.kilometers >= 0.1 {
            shareWithFriends(
                .run,
                title: "Ran \(RunFormat.kilometers(run.kilometers)) km",
                detail: "\(RunFormat.duration(run.duration)) · \(RunFormat.pace(run.paceSecondsPerKm)) /km"
            )
        }

        if let commitment = todayCommitments.first(where: { $0.category == .run && $0.status != .completed && $0.status != .missed }) {
            complete(commitment, sharesActivity: false)
            if celebration?.achievement == nil {
                celebration?.achievement = unlocked.first
            }
        } else {
            unlocked.append(contentsOf: checkUnlocks())
            let distanceLine = run.kilometers >= 0.1
                ? String(format: "%.2f km on your legs, not on your list.", run.kilometers)
                : "Time on your feet counts."
            celebration = Celebration(
                title: "Run logged.",
                message: distanceLine,
                streak: nil,
                achievement: unlocked.first
            )
        }
        save()
    }

    func deleteRun(_ run: Run) {
        runs.removeAll { $0.id == run.id }
        save()
    }

    var totalRunKilometers: Double {
        runs.reduce(0) { $0 + $1.kilometers }
    }

    /// Best (lowest) average pace across runs, in seconds per km.
    var bestPaceSecondsPerKm: Double? {
        runs.compactMap(\.paceSecondsPerKm).min()
    }

    // MARK: - Lift

    /// Log a finished workout. Sets with zero reps are dropped; counts
    /// toward today's gym commitment if one exists.
    func logWorkout(title: String, duration: TimeInterval, exercises: [WorkoutExercise]) {
        let cleaned = exercises
            .map { exercise in
                var copy = exercise
                copy.sets = exercise.sets.filter { $0.reps > 0 }
                return copy
            }
            .filter { !$0.sets.isEmpty }
        guard !cleaned.isEmpty else { return }

        let workout = Workout(
            title: title.trimmingCharacters(in: .whitespaces).isEmpty ? "Workout" : title,
            date: .now,
            duration: duration,
            exercises: cleaned
        )
        workouts.insert(workout, at: 0)

        var unlocked: [Achievement] = []
        if let a = unlock("first_lift") { unlocked.append(a) }
        if workout.totalVolumeKg >= 1000, let a = unlock("ton_lifted") { unlocked.append(a) }

        shareWithFriends(
            .workout,
            title: "Trained: \(workout.title)",
            detail: "\(workout.exercises.count) exercises · \(Int(workout.totalVolumeKg)) kg moved"
        )

        if let commitment = todayCommitments.first(where: { $0.category == .gym && $0.status != .completed && $0.status != .missed }) {
            complete(commitment, sharesActivity: false)
            if celebration?.achievement == nil {
                celebration?.achievement = unlocked.first
            }
        } else {
            unlocked.append(contentsOf: checkUnlocks())
            celebration = Celebration(
                title: "Session logged.",
                message: "\(Int(workout.totalVolumeKg)) kg moved across \(workout.totalSets) sets. Strength is built, not found.",
                streak: nil,
                achievement: unlocked.first
            )
        }
        save()
    }

    func deleteWorkout(_ workout: Workout) {
        workouts.removeAll { $0.id == workout.id }
        save()
    }

    /// The sets logged for this exercise last time it was trained — the
    /// number to beat, shown while logging.
    func lastSets(for exerciseName: String) -> (sets: [ExerciseSet], date: Date)? {
        for workout in workouts.sorted(by: { $0.date > $1.date }) {
            if let exercise = workout.exercises.first(where: { $0.name == exerciseName }),
               !exercise.sets.isEmpty {
                return (exercise.sets, workout.date)
            }
        }
        return nil
    }

    // MARK: - Routines

    func saveRoutine(name: String, exerciseNames: [String]) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !exerciseNames.isEmpty else { return }
        // Re-saving under an existing name replaces it rather than duplicating.
        if let index = routines.firstIndex(where: { $0.name.caseInsensitiveCompare(trimmed) == .orderedSame }) {
            routines[index].exerciseNames = exerciseNames
        } else {
            routines.append(Routine(name: trimmed, exerciseNames: exerciseNames))
        }
        save()
    }

    func deleteRoutine(_ routine: Routine) {
        routines.removeAll { $0.id == routine.id }
        save()
    }

    // MARK: - Body weight

    func logWeight(_ kilograms: Double) {
        guard kilograms > 0 else { return }
        weightEntries.append(WeightEntry(date: .now, kilograms: kilograms))
        save()
    }

    func deleteWeight(_ entry: WeightEntry) {
        weightEntries.removeAll { $0.id == entry.id }
        save()
    }

    var latestWeight: WeightEntry? {
        weightEntries.max { $0.date < $1.date }
    }

    /// Change since the oldest entry in the last 30 days — the trend, not
    /// a single day's noise.
    var weightChange30Days: Double? {
        guard let latest = latestWeight,
              let cutoff = calendar.date(byAdding: .day, value: -30, to: .now) else { return nil }
        let window = weightEntries.filter { $0.date >= cutoff }.sorted { $0.date < $1.date }
        guard let first = window.first, first.id != latest.id else { return nil }
        return latest.kilograms - first.kilograms
    }

    var totalVolumeKg: Double {
        workouts.reduce(0) { $0 + $1.totalVolumeKg }
    }

    var workoutsThisWeek: Int {
        guard let weekAgo = calendar.date(byAdding: .day, value: -7, to: .now) else { return 0 }
        return workouts.filter { $0.date >= weekAgo }.count
    }

    /// Heaviest set ever logged for an exercise — shown while logging.
    func bestWeight(for exerciseName: String) -> Double? {
        workouts
            .flatMap(\.exercises)
            .filter { $0.name == exerciseName }
            .flatMap(\.sets)
            .filter { $0.reps > 0 }
            .map(\.weightKg)
            .max()
    }

    // MARK: - Fuel

    func addFood(
        name: String,
        calories: Int,
        meal: MealType,
        date: Date = .now,
        photoData: Data? = nil,
        items: [FoodItem]? = nil,
        macros: Macros? = nil
    ) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, calories > 0 else { return }
        let fileName = photoData.flatMap { saveImage($0) }
        let storedItems = (items?.isEmpty ?? true) ? nil : items
        // An itemised plate's macros are the sum of its items.
        let itemMacros = storedItems?.compactMap(\.macros).reduce(Macros.zero, +)
        let resolvedMacros = macros ?? itemMacros.flatMap { $0.isEmpty ? nil : $0 }
        foodEntries.insert(
            FoodEntry(
                name: trimmed,
                calories: calories,
                meal: meal,
                date: date,
                photoFileName: fileName,
                items: storedItems,
                macros: resolvedMacros
            ),
            at: 0
        )
        foodEntries.sort { $0.date > $1.date }
        save()
    }

    /// Log the same food again — the fastest entry there is. The photo stays
    /// with the original so deleting one never breaks the other.
    func relogFood(_ entry: FoodEntry, meal: MealType? = nil, on day: Date = .now) {
        let targetMeal = meal ?? entry.meal
        foodEntries.insert(
            FoodEntry(
                name: entry.name,
                calories: entry.calories,
                meal: targetMeal,
                date: logDate(for: day, meal: targetMeal),
                items: entry.items,
                macros: entry.macros
            ),
            at: 0
        )
        foodEntries.sort { $0.date > $1.date }
        save()
    }

    func deleteFood(_ entry: FoodEntry) {
        if let fileName = entry.photoFileName,
           !foodEntries.contains(where: { $0.id != entry.id && $0.photoFileName == fileName }) {
            try? FileManager.default.removeItem(at: imageURL(fileName: fileName))
        }
        foodEntries.removeAll { $0.id == entry.id }
        save()
    }

    /// When a food logged for `day` should be timestamped: now for today,
    /// otherwise a plausible hour for the meal so back-filled days sort right.
    func logDate(for day: Date, meal: MealType) -> Date {
        if calendar.isDateInToday(day) { return .now }
        let hour: Int
        switch meal {
        case .breakfast: hour = 8
        case .lunch: hour = 13
        case .snack: hour = 16
        case .dinner: hour = 19
        }
        return calendar.date(bySettingHour: hour, minute: 0, second: 0, of: day) ?? day
    }

    func food(on day: Date) -> [FoodEntry] {
        foodEntries.filter { calendar.isDate($0.date, inSameDayAs: day) }
    }

    func food(on day: Date, meal: MealType) -> [FoodEntry] {
        food(on: day).filter { $0.meal == meal }.sorted { $0.date < $1.date }
    }

    func todayFood(for meal: MealType) -> [FoodEntry] {
        food(on: .now, meal: meal)
    }

    func calories(on day: Date) -> Int {
        food(on: day).reduce(0) { $0 + $1.calories }
    }

    var caloriesToday: Int { calories(on: .now) }

    func macros(on day: Date) -> Macros {
        food(on: day).compactMap(\.macros).reduce(Macros.zero, +)
    }

    /// Calories on `day` whose macros are known. Lets the UI say "macros
    /// cover 1,240 of 1,800 kcal" instead of quietly under-reporting.
    func caloriesWithMacros(on day: Date) -> Int {
        food(on: day).filter { $0.macros != nil }.reduce(0) { $0 + $1.calories }
    }

    /// Distinct foods, most recent first — one tap to log them again.
    var recentFoods: [FoodEntry] {
        var seen = Set<String>()
        var result: [FoodEntry] = []
        for entry in foodEntries.sorted(by: { $0.date > $1.date }) {
            let key = entry.name.lowercased()
            guard !seen.contains(key) else { continue }
            seen.insert(key)
            result.append(entry)
            if result.count == 10 { break }
        }
        return result
    }

    /// Consecutive days with at least one food logged, counting back from
    /// today (or yesterday, if today is still empty).
    var foodLogStreak: Int {
        consecutiveDays(in: Set(foodEntries.map { dayKey($0.date) }))
    }

    func updateNutritionGoals(_ goals: NutritionGoals) {
        nutritionGoals = goals
        save()
    }

    // MARK: - Water

    func water(on day: Date) -> Int { waterByDay[dayKey(day)] ?? 0 }

    var waterToday: Int { water(on: .now) }

    func addWater(_ milliliters: Int, on day: Date = .now) {
        let key = dayKey(day)
        let updated = max(0, (waterByDay[key] ?? 0) + milliliters)
        waterByDay[key] = updated == 0 ? nil : updated
        save()
    }

    // MARK: - Wake

    var isWakeCheckedInToday: Bool {
        wakeCheckInDays.contains(dayKey())
    }

    /// True when a real AlarmKit alarm is scheduled (rings through the mute
    /// switch); false means the notification fallback is carrying the
    /// morning. Surfaced in the UI so which path is live is verifiable
    /// rather than guesswork — building with an SDK older than iOS 26
    /// compiles AlarmKit out entirely.
    var isWakeAlarmReal: Bool {
        wake.enabled && wake.alarmID != nil
    }

    /// Consecutive scheduled wake days checked in, counting back from today
    /// (an unchecked today doesn't break the streak yet).
    var wakeStreak: Int {
        var streak = 0
        var offset = isWakeCheckedInToday ? 0 : 1
        while offset < 366 {
            guard let day = calendar.date(byAdding: .day, value: -offset, to: .now) else { break }
            let weekday = calendar.component(.weekday, from: day)
            if wake.days.contains(weekday) {
                if wakeCheckInDays.contains(dayKey(day)) {
                    streak += 1
                } else {
                    break
                }
            }
            offset += 1
        }
        return streak
    }

    /// Morning check-in — once per day. An optional photo (sky, grass, made
    /// bed) files as a check-in shot.
    func checkInWake(withPhoto data: Data? = nil) {
        guard !isWakeCheckedInToday else { return }
        if let data {
            addProgressPhoto(imageData: data, pose: .proof)
        }
        wakeCheckInDays.insert(dayKey())

        var unlocked: [Achievement] = []
        if calendar.component(.hour, from: .now) < 8, let a = unlock("early_bird") { unlocked.append(a) }

        let streak = wakeStreak
        shareWithFriends(
            .wake,
            title: "Up at \(Date.now.formatted(date: .omitted, time: .shortened))",
            detail: streak > 1 ? "\(streak)-day wake streak" : "",
            streak: streak
        )
        celebration = Celebration(
            title: "Morning won.",
            message: streak > 1
                ? "That's \(streak) wake-ups in a row. The day is yours before it starts."
                : "Up is up. Everything else gets easier from here.",
            streak: streak > 1 ? streak : nil,
            achievement: unlocked.first
        )
        save()
        silenceWakeNudges()
    }

    /// A single notification pings once and stops — useless as an alarm. The
    /// wake-up instead schedules a burst of nudges that keep buzzing until
    /// you check in. iOS caps an app at 64 pending notifications, so this
    /// stays modest: 6 nudges × 7 days = 42, leaving room for bedtime.
    private static let wakeNudgeCount = 6
    private static let wakeNudgeSpacingSeconds = 40

    private static let wakeNudgeCopy: [(title: String, body: String)] = [
        ("Wake up. You said so.", "Check in before the day decides for you."),
        ("Still in bed.", "You picked this time. Feet on the floor."),
        ("This is the moment.", "The one where it gets decided either way."),
        ("Your streak is on the line.", "Open FlexUp and check in."),
        ("Last call.", "Get up now and the whole day is still yours."),
        ("Morning's slipping.", "Check in — even late counts more than not at all."),
    ]

    /// Identifiers for every wake notification, including the legacy
    /// single-notification IDs so older schedules get cleaned up.
    private var wakeNotificationIdentifiers: [String] {
        var identifiers: [String] = []
        for weekday in 1...7 {
            identifiers.append("wake-\(weekday)")
            for nudge in 0..<Self.wakeNudgeCount {
                identifiers.append("wake-\(weekday)-\(nudge)")
            }
        }
        return identifiers
    }

    /// Weekday/time components pushed forward by `offset` seconds, rolling
    /// into the next weekday when the offset crosses midnight.
    private static func alarmComponents(weekday: Int, hour: Int, minute: Int, offsetSeconds offset: Int) -> DateComponents {
        let total = hour * 3600 + minute * 60 + offset
        let dayRollover = total / 86_400
        let within = total % 86_400

        var components = DateComponents()
        components.weekday = (weekday - 1 + dayRollover) % 7 + 1
        components.hour = within / 3600
        components.minute = (within % 3600) / 60
        components.second = within % 60
        return components
    }

    /// Re-sync the wake-up with the current config.
    ///
    /// AlarmKit (iOS 26+) gives a real alarm that rings through the mute
    /// switch, so when it takes the job the notification burst stays off —
    /// otherwise the morning would fire twice. Older systems fall back to
    /// stacked notifications.
    func updateWakeSchedule() {
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: wakeNotificationIdentifiers)
        save()

        let config = wake
        Task { @MainActor in
            let result = await WakeAlarmScheduler.reschedule(
                hour: config.hour,
                minute: config.minute,
                weekdays: config.days,
                enabled: config.enabled,
                existingID: config.alarmID,
                tint: Theme.accent
            )
            switch result {
            case .scheduled(let id):
                self.wake.alarmID = id
                self.save()
            case .disabled:
                self.wake.alarmID = nil
                self.save()
            case .unavailable:
                self.wake.alarmID = nil
                self.save()
                self.scheduleWakeNotifications()
            }
        }
    }

    /// The pre-AlarmKit fallback: a burst of Time Sensitive notifications.
    private func scheduleWakeNotifications() {
        guard wake.enabled else { return }
        let center = UNUserNotificationCenter.current()

        center.requestAuthorization(options: [.alert, .sound, .badge]) { [weak self] granted, _ in
            guard granted, let self else { return }
            let config = self.wake
            for weekday in config.days {
                for nudge in 0..<Self.wakeNudgeCount {
                    let copy = Self.wakeNudgeCopy[min(nudge, Self.wakeNudgeCopy.count - 1)]
                    let components = Self.alarmComponents(
                        weekday: weekday,
                        hour: config.hour,
                        minute: config.minute,
                        offsetSeconds: nudge * Self.wakeNudgeSpacingSeconds
                    )

                    let content = UNMutableNotificationContent()
                    content.title = copy.title
                    content.body = copy.body
                    content.sound = .default
                    // Time Sensitive breaks through Focus modes (but never the
                    // ring/silent switch — only AlarmKit or critical alerts can).
                    content.interruptionLevel = .timeSensitive

                    let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
                    center.add(UNNotificationRequest(
                        identifier: "wake-\(weekday)-\(nudge)",
                        content: content,
                        trigger: trigger
                    ))
                }
            }
        }
    }

    /// Stop the rest of this morning's nudges. Removing and re-adding the
    /// repeating requests clears today's remaining buzzes while leaving next
    /// week's alarm intact.
    private func silenceWakeNudges() {
        let center = UNUserNotificationCenter.current()
        center.removeDeliveredNotifications(withIdentifiers: wakeNotificationIdentifiers)
        updateWakeSchedule()
    }

    /// Fire one alarm-style notification shortly, so the wake-up can be
    /// heard and verified without waiting for the morning.
    func previewWakeAlarm() {
        let center = UNUserNotificationCenter.current()
        center.requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
            guard granted else { return }
            let content = UNMutableNotificationContent()
            content.title = "Wake up. You said so."
            content.body = "This is what your morning will sound like."
            content.sound = .default
            content.interruptionLevel = .timeSensitive

            center.add(UNNotificationRequest(
                identifier: "wake-preview",
                content: content,
                trigger: UNTimeIntervalNotificationTrigger(timeInterval: 5, repeats: false)
            ))
        }
    }

    // MARK: - Sleep

    var lastNightSleep: SleepSession? {
        sleepSessions.max { $0.wakeTime < $1.wakeTime }
    }

    /// Average hours across the most recent `nights` logged sessions.
    func averageSleepHours(nights: Int = 7) -> Double? {
        let recent = sleepSessions
            .sorted { $0.wakeTime > $1.wakeTime }
            .prefix(nights)
        guard !recent.isEmpty else { return nil }
        return recent.reduce(0) { $0 + $1.hours } / Double(recent.count)
    }

    /// Consecutive days with a logged night, keyed by wake date.
    var sleepLogStreak: Int {
        consecutiveDays(in: Set(sleepSessions.map { dayKey($0.wakeTime) }))
    }

    /// Length of the run of consecutive day keys ending today — or
    /// yesterday, so an evening that hasn't been logged yet doesn't reset it.
    private func consecutiveDays(in days: Set<String>) -> Int {
        guard !days.isEmpty else { return 0 }
        var streak = 0
        var offset = days.contains(dayKey()) ? 0 : 1
        while offset < 366 {
            guard let day = calendar.date(byAdding: .day, value: -offset, to: .now) else { break }
            if days.contains(dayKey(day)) {
                streak += 1
                offset += 1
            } else {
                break
            }
        }
        return streak
    }

    /// Log a night's sleep. Awards achievements and celebrates the streak.
    func logSleep(bedtime: Date, wakeTime: Date, quality: SleepQuality) {
        let session = SleepSession(bedtime: bedtime, wakeTime: wakeTime, quality: quality)
        sleepSessions.append(session)

        var unlocked: [Achievement] = []
        if let a = unlock("first_sleep") { unlocked.append(a) }
        if session.hours >= 8, let a = unlock("full_battery") { unlocked.append(a) }
        if sleepLogStreak >= 7, let a = unlock("sleep_week") { unlocked.append(a) }

        let hours = Int(session.hours)
        let minutes = Int((session.hours - Double(hours)) * 60)
        shareWithFriends(.sleep, title: "Slept \(hours)h \(minutes)m", detail: "\(quality.label) quality")
        celebration = Celebration(
            title: "Night logged.",
            message: "\(hours)h \(minutes)m of sleep, \(quality.label.lowercased()) quality. Rest is training too.",
            streak: sleepLogStreak > 1 ? sleepLogStreak : nil,
            achievement: unlocked.first
        )
        save()
    }

    func deleteSleep(_ session: SleepSession) {
        sleepSessions.removeAll { $0.id == session.id }
        save()
    }

    /// Re-sync the repeating bedtime reminder with the current config.
    func updateBedtimeSchedule() {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: (1...7).map { "bedtime-\($0)" })
        save()
        guard bedtime.enabled else { return }

        center.requestAuthorization(options: [.alert, .sound]) { [weak self] granted, _ in
            guard granted, let self else { return }
            let config = self.bedtime
            for weekday in config.days {
                var components = DateComponents()
                components.weekday = weekday
                components.hour = config.hour
                components.minute = config.minute

                let content = UNMutableNotificationContent()
                content.title = "Wind down."
                content.body = "Bedtime, so tomorrow's wake-up doesn't hurt."
                content.sound = .default

                let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
                center.add(UNNotificationRequest(identifier: "bedtime-\(weekday)", content: content, trigger: trigger))
            }
        }
    }

    // MARK: - Progress photos

    private var photosDirectory: URL {
        let directory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("FlexUp/Photos", isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }

    func imageURL(for photo: ProgressPhoto) -> URL {
        photosDirectory.appendingPathComponent(photo.fileName)
    }

    func imageURL(fileName: String) -> URL {
        photosDirectory.appendingPathComponent(fileName)
    }

    /// Write image data into the app's photo directory; returns the file name.
    func saveImage(_ data: Data) -> String? {
        let fileName = "\(UUID().uuidString).jpg"
        do {
            try data.write(to: photosDirectory.appendingPathComponent(fileName), options: .atomic)
            return fileName
        } catch {
            return nil
        }
    }

    @discardableResult
    func addProgressPhoto(imageData: Data, pose: PhotoPose) -> ProgressPhoto? {
        guard let fileName = saveImage(imageData) else { return nil }
        let photo = ProgressPhoto(date: .now, pose: pose, fileName: fileName)
        progressPhotos.insert(photo, at: 0)

        let unlocked = unlock("first_photo")
        // Proof photos are part of completing a commitment — that flow owns
        // the celebration. Pose photos celebrate here.
        if pose != .proof {
            celebration = Celebration(
                title: "Day \(photoDayNumber(for: photo)).",
                message: "Same pose, same spot, every week. Future you will thank you for this.",
                streak: nil,
                achievement: unlocked
            )
        }
        save()
        return photo
    }

    func deleteProgressPhoto(_ photo: ProgressPhoto) {
        try? FileManager.default.removeItem(at: imageURL(for: photo))
        progressPhotos.removeAll { $0.id == photo.id }
        save()
    }

    func photos(for pose: PhotoPose) -> [ProgressPhoto] {
        progressPhotos
            .filter { $0.pose == pose }
            .sorted { $0.date < $1.date }
    }

    private func photoDayNumber(for photo: ProgressPhoto) -> Int {
        guard let first = progressPhotos.map(\.date).min() else { return 1 }
        let days = calendar.dateComponents([.day], from: calendar.startOfDay(for: first), to: calendar.startOfDay(for: photo.date)).day ?? 0
        return days + 1
    }

    // MARK: - Squad

    var feedEvents: [SocialEvent] {
        socialEvents.sorted { $0.date > $1.date }
    }

    func toggleCheer(_ event: SocialEvent) {
        guard let index = socialEvents.firstIndex(where: { $0.id == event.id }) else { return }
        socialEvents[index].cheeredByMe.toggle()
        socialEvents[index].cheers += socialEvents[index].cheeredByMe ? 1 : -1
        save()
    }

    /// Your completions in the last 7 days — feeds the crew progress card.
    var completedThisWeek: Int {
        guard let weekAgo = calendar.date(byAdding: .day, value: -7, to: .now) else { return 0 }
        return commitments.filter {
            $0.status == .completed && ($0.completedAt ?? $0.date) >= weekAgo
        }.count
    }

    // MARK: - Memories

    /// Everything worth remembering, newest first: completed commitments,
    /// tracked runs, and earned achievements. Derived, never written.
    var memories: [Memory] {
        var items: [Memory] = []

        for commitment in commitments where commitment.status == .completed {
            guard let done = commitment.completedAt else { continue }
            items.append(Memory(
                id: "commitment-\(commitment.id)",
                title: commitment.title,
                subtitle: "Followed through",
                icon: commitment.category.icon,
                date: done
            ))
        }

        for run in runs {
            items.append(Memory(
                id: "run-\(run.id)",
                title: "\(RunFormat.kilometers(run.kilometers)) km run",
                subtitle: "\(RunFormat.duration(run.duration)) · \(RunFormat.pace(run.paceSecondsPerKm)) /km",
                icon: "figure.run",
                date: run.date
            ))
        }

        for workout in workouts {
            items.append(Memory(
                id: "workout-\(workout.id)",
                title: workout.title,
                subtitle: "\(Int(workout.totalVolumeKg)) kg · \(workout.totalSets) sets",
                icon: "dumbbell",
                date: workout.date
            ))
        }

        for session in sleepSessions {
            items.append(Memory(
                id: "sleep-\(session.id)",
                title: "\(session.durationLabel) sleep",
                subtitle: "\(session.quality.emoji) \(session.quality.label) quality",
                icon: "moon.stars",
                date: session.wakeTime
            ))
        }

        for photo in progressPhotos where photo.pose != .proof {
            items.append(Memory(
                id: "photo-\(photo.id)",
                title: "Progress photo",
                subtitle: "\(photo.pose.label) pose",
                icon: "camera",
                date: photo.date
            ))
        }

        for achievement in achievements where achievement.isEarned {
            items.append(Memory(
                id: "achievement-\(achievement.id)",
                title: achievement.title,
                subtitle: "Achievement unlocked",
                icon: achievement.icon,
                date: achievement.earnedAt ?? .now,
                isHighlight: true
            ))
        }

        return items.sorted { $0.date > $1.date }
    }

    // MARK: - Communities

    func toggleCommunity(_ community: Community) {
        guard let index = communities.firstIndex(where: { $0.id == community.id }) else { return }
        communities[index].isJoined.toggle()
        if communities[index].isJoined, let unlocked = unlock("belong") {
            celebration = Celebration(
                title: "Welcome to \(community.name).",
                message: "Communities organize action, not conversation.",
                streak: nil,
                achievement: unlocked
            )
        }
        save()
    }

    // MARK: - Scheduling engine

    /// Materialize commitments from habits for the next 7 days.
    func generateUpcomingCommitments() {
        for habit in habits {
            for offset in 0..<7 {
                guard let day = calendar.date(byAdding: .day, value: offset, to: calendar.startOfDay(for: .now)) else { continue }
                let weekday = calendar.component(.weekday, from: day)
                guard habit.scheduleWeekdays.contains(weekday) else { continue }

                let exists = commitments.contains {
                    $0.habitID == habit.id && calendar.isDate($0.date, inSameDayAs: day)
                }
                guard !exists else { continue }

                let date = calendar.date(bySettingHour: habit.timeOfDay.defaultHour, minute: 0, second: 0, of: day) ?? day
                commitments.append(Commitment(
                    title: habit.title,
                    category: habit.category,
                    date: date,
                    verification: habit.verification,
                    durationMinutes: habit.durationMinutes,
                    habitID: habit.id
                ))
            }
        }
    }

    /// Anything scheduled before today that never happened becomes missed.
    private func rolloverMissed() {
        let startOfToday = calendar.startOfDay(for: .now)
        for index in commitments.indices {
            if commitments[index].date < startOfToday,
               commitments[index].status == .scheduled || commitments[index].status == .confirmed || commitments[index].status == .rescheduled {
                commitments[index].status = .missed
                if let habitID = commitments[index].habitID,
                   let habitIndex = habits.firstIndex(where: { $0.id == habitID }) {
                    habits[habitIndex].streak = 0
                }
            }
        }
    }

    // MARK: - Achievements

    @discardableResult
    private func unlock(_ key: String) -> Achievement? {
        guard let index = achievements.firstIndex(where: { $0.key == key && $0.earnedAt == nil }) else { return nil }
        achievements[index].earnedAt = .now
        return achievements[index]
    }

    private func checkUnlocks() -> [Achievement] {
        var unlocked: [Achievement] = []
        let completed = commitments.filter { $0.status == .completed }

        if completed.count >= 1, let a = unlock("first_step") { unlocked.append(a) }
        if completed.count >= 10, let a = unlock("ten_done") { unlocked.append(a) }
        if habits.contains(where: { $0.streak >= 7 }), let a = unlock("week_strong") { unlocked.append(a) }
        if Set(completed.map(\.category)).count >= 3, let a = unlock("explorer") { unlocked.append(a) }
        if completed.contains(where: {
            guard let done = $0.completedAt else { return false }
            return calendar.component(.hour, from: done) < 8
        }), let a = unlock("early_bird") { unlocked.append(a) }

        return unlocked
    }

    var earnedAchievements: [Achievement] { achievements.filter(\.isEarned) }

    // MARK: - Coach (rule-based v1; swap for a model-backed coach later)

    var coachInsight: CoachInsight {
        let name = profile?.name ?? "there"

        if let days = inactiveDays, days >= 3 {
            return CoachInsight(
                message: "It's been \(days) days since your last completion. No guilt — just restart small. A 15-minute walk resets everything.",
                actionLabel: "Start a walk",
                action: .quickStart(.walk)
            )
        }

        if let weekdayName = habitualMissWeekdayName {
            return CoachInsight(
                message: "I've noticed \(weekdayName)s are the day you tend to skip. Want to plan something lighter for it?",
                actionLabel: nil,
                action: nil
            )
        }

        if let activity = upcomingFriendActivities.first(where: { !$0.isJoined }) {
            let who = activity.friendsGoing.first ?? activity.host
            return CoachInsight(
                message: "\(who) is going to \(activity.title) \(activity.date.formatted(.dateTime.weekday(.wide))). People keep plans they make together.",
                actionLabel: "Take a look",
                action: .openActivity(activity.id)
            )
        }

        if !todayCommitments.isEmpty && todayProgress >= 1 {
            return CoachInsight(
                message: "Everything you planned today is done, \(name). Go live your life — that's the whole point.",
                actionLabel: nil,
                action: nil
            )
        }

        return CoachInsight(
            message: "One small thing now beats a perfect plan later. Pick the easiest item on your list and start it.",
            actionLabel: nil,
            action: nil
        )
    }

    private var inactiveDays: Int? {
        guard let last = commitments.compactMap(\.completedAt).max() else { return nil }
        return calendar.dateComponents([.day], from: calendar.startOfDay(for: last), to: calendar.startOfDay(for: .now)).day
    }

    private var habitualMissWeekdayName: String? {
        let missed = commitments.filter { $0.status == .missed }
        var counts: [Int: Int] = [:]
        for commitment in missed {
            counts[calendar.component(.weekday, from: commitment.date), default: 0] += 1
        }
        guard let (weekday, count) = counts.max(by: { $0.value < $1.value }), count >= 2 else { return nil }
        return calendar.weekdaySymbols[weekday - 1]
    }

    // MARK: - Stats

    /// Completions per day over the last 7 days, oldest first.
    func weeklyStats() -> [DayStat] {
        (0..<7).reversed().compactMap { offset in
            guard let day = calendar.date(byAdding: .day, value: -offset, to: calendar.startOfDay(for: .now)) else { return nil }
            let dayCommitments = commitments.filter { calendar.isDate($0.date, inSameDayAs: day) }
            return DayStat(
                label: day.formatted(.dateTime.weekday(.abbreviated)),
                completed: dayCommitments.filter { $0.status == .completed }.count,
                planned: dayCommitments.count
            )
        }
    }

    var currentStreak: Int { habits.map(\.streak).max() ?? 0 }
    var bestStreak: Int { habits.map(\.bestStreak).max() ?? 0 }
    var totalCompleted: Int { commitments.filter { $0.status == .completed }.count }

    var consistencyPercent: Int {
        let stats = weeklyStats()
        let planned = stats.reduce(0) { $0 + $1.planned }
        guard planned > 0 else { return 0 }
        let completed = stats.reduce(0) { $0 + $1.completed }
        return Int((Double(completed) / Double(planned) * 100).rounded())
    }

    // MARK: - Progress

    enum Aggregation { case sum, average }

    func rangeStart(_ range: ProgressRange) -> Date {
        let today = calendar.startOfDay(for: .now)
        return calendar.date(byAdding: .day, value: -(range.days - 1), to: today) ?? today
    }

    private func isInRange(_ date: Date, _ range: ProgressRange) -> Bool {
        let startOfToday = calendar.startOfDay(for: .now)
        let endOfToday = calendar.date(byAdding: .day, value: 1, to: startOfToday) ?? .now
        return date >= rangeStart(range) && date < endOfToday
    }

    /// Collapse raw samples into chart points: first per day, then per
    /// range bucket (day or week). Days with no samples produce no point,
    /// so an unlogged day never reads as a zero.
    private func series(
        _ samples: [(date: Date, value: Double)],
        in range: ProgressRange,
        perDay: Aggregation,
        perBucket: Aggregation
    ) -> [DailyPoint] {
        func combine(_ values: [Double], _ mode: Aggregation) -> Double {
            let total = values.reduce(0, +)
            return mode == .sum ? total : total / Double(max(1, values.count))
        }

        let byDay = Dictionary(grouping: samples.filter { isInRange($0.date, range) }) {
            calendar.startOfDay(for: $0.date)
        }
        let dailyValues = byDay.mapValues { samples in combine(samples.map { $0.value }, perDay) }

        let byBucket = Dictionary(grouping: dailyValues) { entry in
            calendar.dateInterval(of: range.bucket, for: entry.key)?.start ?? entry.key
        }
        return byBucket
            .map { bucket in DailyPoint(date: bucket.key, value: combine(bucket.value.map { $0.value }, perBucket)) }
            .sorted { $0.date < $1.date }
    }

    // Consistency

    /// Commitments in the range that have an outcome: done, missed, or
    /// from a day that's already over. Rescheduled ones moved elsewhere and
    /// today's still-open ones haven't had their chance yet.
    private func resolvedCommitments(in range: ProgressRange) -> [Commitment] {
        let startOfToday = calendar.startOfDay(for: .now)
        return commitments.filter { commitment in
            guard isInRange(commitment.date, range), commitment.status != .rescheduled else { return false }
            return commitment.status == .completed || commitment.status == .missed || commitment.date < startOfToday
        }
    }

    /// Completion rate (0–100) per bucket, over commitments whose day has
    /// already happened or that were already resolved.
    func completionSeries(_ range: ProgressRange) -> [DailyPoint] {
        let resolved = resolvedCommitments(in: range)
        let byDay = Dictionary(grouping: resolved) { calendar.startOfDay(for: $0.date) }
        let samples: [(date: Date, value: Double)] = byDay.map { entry in
            let done = entry.value.filter { $0.status == .completed }.count
            return (date: entry.key, value: Double(done) / Double(entry.value.count) * 100)
        }
        return series(samples, in: range, perDay: .average, perBucket: .average)
    }

    func completionRate(_ range: ProgressRange) -> Int? {
        let resolved = resolvedCommitments(in: range)
        guard !resolved.isEmpty else { return nil }
        let done = resolved.filter { $0.status == .completed }.count
        return Int((Double(done) / Double(resolved.count) * 100).rounded())
    }

    func completedCount(_ range: ProgressRange) -> Int {
        commitments.filter { isInRange($0.date, range) && $0.status == .completed }.count
    }

    // Wake

    /// Every day in the range, oldest first, with whether you checked in.
    func wakeDays(_ range: ProgressRange) -> [(date: Date, checkedIn: Bool)] {
        let today = calendar.startOfDay(for: .now)
        return (0..<range.days).reversed().compactMap { offset in
            guard let day = calendar.date(byAdding: .day, value: -offset, to: today) else { return nil }
            return (date: day, checkedIn: wakeCheckInDays.contains(dayKey(day)))
        }
    }

    func wakeCheckIns(_ range: ProgressRange) -> Int {
        wakeDays(range).filter { $0.checkedIn }.count
    }

    // Sleep

    func sleepSessions(in range: ProgressRange) -> [SleepSession] {
        sleepSessions.filter { isInRange($0.wakeTime, range) }
    }

    func sleepSeries(_ range: ProgressRange) -> [DailyPoint] {
        series(sleepSessions.map { (date: $0.wakeTime, value: $0.hours) }, in: range, perDay: .sum, perBucket: .average)
    }

    // Run

    func runs(in range: ProgressRange) -> [Run] {
        runs.filter { isInRange($0.date, range) }
    }

    func runDistanceSeries(_ range: ProgressRange) -> [DailyPoint] {
        series(runs.map { (date: $0.date, value: $0.kilometers) }, in: range, perDay: .sum, perBucket: .sum)
    }

    // Gym

    func workouts(in range: ProgressRange) -> [Workout] {
        workouts.filter { isInRange($0.date, range) }
    }

    func volumeSeries(_ range: ProgressRange) -> [DailyPoint] {
        series(workouts.map { (date: $0.date, value: $0.totalVolumeKg) }, in: range, perDay: .sum, perBucket: .sum)
    }

    /// Heaviest set ever logged per exercise, newest PRs first.
    var personalRecords: [PersonalRecord] {
        var best: [String: PersonalRecord] = [:]
        for workout in workouts {
            for exercise in workout.exercises {
                for set in exercise.sets where set.weightKg > 0 && set.reps > 0 {
                    let isBetter: Bool
                    if let current = best[exercise.name] {
                        isBetter = set.weightKg > current.weightKg
                            || (set.weightKg == current.weightKg && set.reps > current.reps)
                    } else {
                        isBetter = true
                    }
                    if isBetter {
                        best[exercise.name] = PersonalRecord(
                            exercise: exercise.name,
                            weightKg: set.weightKg,
                            reps: set.reps,
                            date: workout.date
                        )
                    }
                }
            }
        }
        return best.values.sorted { $0.date > $1.date }
    }

    // Diet

    func calorieSeries(_ range: ProgressRange) -> [DailyPoint] {
        series(foodEntries.map { (date: $0.date, value: Double($0.calories)) }, in: range, perDay: .sum, perBucket: .average)
    }

    func proteinSeries(_ range: ProgressRange) -> [DailyPoint] {
        series(
            foodEntries.compactMap { entry in entry.macros.map { (date: entry.date, value: $0.protein) } },
            in: range, perDay: .sum, perBucket: .average
        )
    }

    /// Days in the range with any food logged.
    func foodDays(_ range: ProgressRange) -> [Date] {
        Set(foodEntries.filter { isInRange($0.date, range) }.map { calendar.startOfDay(for: $0.date) })
            .sorted()
    }

    /// Average daily macros across logged days in the range.
    func averageMacros(_ range: ProgressRange) -> Macros? {
        let days = foodDays(range)
        guard !days.isEmpty else { return nil }
        let total = days.map { macros(on: $0) }.reduce(Macros.zero, +)
        return total.isEmpty ? nil : total.scaled(by: 1 / Double(days.count))
    }

    func waterSeries(_ range: ProgressRange) -> [DailyPoint] {
        let samples: [(date: Date, value: Double)] = waterByDay.compactMap { key, ml in
            date(fromDayKey: key).map { (date: $0, value: Double(ml)) }
        }
        return series(samples, in: range, perDay: .sum, perBucket: .average)
    }

    // Body

    func weightSeries(_ range: ProgressRange) -> [DailyPoint] {
        series(weightEntries.map { (date: $0.date, value: $0.kilograms) }, in: range, perDay: .average, perBucket: .average)
    }

    // MARK: - Persistence (local JSON; replace with backend sync later)

    private struct Snapshot: Codable {
        var profile: UserProfile?
        var account: Account?
        var habits: [Habit]
        var commitments: [Commitment]
        var activities: [Activity]
        var achievements: [Achievement]
        var communities: [Community]
        var friends: [Friend]
        // Optional: added after v1, so older saved snapshots still decode.
        var runs: [Run]?
        var workouts: [Workout]?
        var routines: [Routine]?
        var weightEntries: [WeightEntry]?
        var foodEntries: [FoodEntry]?
        var progressPhotos: [ProgressPhoto]?
        var calorieBudget: Int?
        var cuisineContext: String?
        var wake: WakeConfig?
        var wakeCheckInDays: Set<String>?
        var bedtime: BedtimeConfig?
        var sleepSessions: [SleepSession]?
        var socialEvents: [SocialEvent]?
        var nutritionGoals: NutritionGoals?
        var waterByDay: [String: Int]?
        var hasSeenIntro: Bool?
        var sharing: SharingSettings?
        var goals: UserGoals?
        var reminders: ReminderPreferences?
        var moodByDay: [String: String]
        var chats: [UUID: [ChatMessage]]
    }

    private var storeURL: URL {
        let directory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("FlexUp", isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory.appendingPathComponent("state.json")
    }

    @ObservationIgnored private var pendingSave: Task<Void, Never>?

    /// Debounced, off-main-thread persistence. Encoding the whole snapshot
    /// synchronously on every mutation caused visible stutters — now rapid
    /// mutations coalesce into one background disk write.
    func save() {
        let snapshot = Snapshot(
            profile: profile,
            account: account,
            habits: habits,
            commitments: commitments,
            activities: activities,
            achievements: achievements,
            communities: communities,
            friends: friends,
            runs: runs,
            workouts: workouts,
            routines: routines,
            weightEntries: weightEntries,
            foodEntries: foodEntries,
            progressPhotos: progressPhotos,
            calorieBudget: calorieBudget,
            cuisineContext: cuisineContext,
            wake: wake,
            wakeCheckInDays: wakeCheckInDays,
            bedtime: bedtime,
            sleepSessions: sleepSessions,
            socialEvents: socialEvents,
            nutritionGoals: nutritionGoals,
            waterByDay: waterByDay,
            hasSeenIntro: hasSeenIntro,
            sharing: sharing,
            goals: goals,
            reminders: reminders,
            moodByDay: moodByDay,
            chats: chats
        )
        let url = storeURL

        pendingSave?.cancel()
        pendingSave = Task.detached(priority: .utility) {
            try? await Task.sleep(nanoseconds: 250_000_000)
            guard !Task.isCancelled else { return }
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            if let data = try? encoder.encode(snapshot) {
                try? data.write(to: url, options: .atomic)
            }
        }
    }

    private func load() {
        guard let data = try? Data(contentsOf: storeURL) else { return }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        guard let snapshot = try? decoder.decode(Snapshot.self, from: data) else { return }
        profile = snapshot.profile
        account = snapshot.account
        habits = snapshot.habits
        commitments = snapshot.commitments
        activities = snapshot.activities
        achievements = snapshot.achievements
        communities = snapshot.communities
        friends = snapshot.friends
        runs = snapshot.runs ?? []
        workouts = snapshot.workouts ?? []
        routines = snapshot.routines ?? []
        weightEntries = snapshot.weightEntries ?? []
        foodEntries = snapshot.foodEntries ?? []
        progressPhotos = snapshot.progressPhotos ?? []
        nutritionGoals = snapshot.nutritionGoals ?? NutritionGoals(calories: snapshot.calorieBudget ?? 2200)
        waterByDay = snapshot.waterByDay ?? [:]
        // Anyone who already signed in before the intro existed has seen enough.
        hasSeenIntro = snapshot.hasSeenIntro ?? (snapshot.account != nil)
        sharing = snapshot.sharing ?? SharingSettings()
        goals = snapshot.goals ?? UserGoals()
        reminders = snapshot.reminders ?? ReminderPreferences()
        cuisineContext = snapshot.cuisineContext ?? ""
        wake = snapshot.wake ?? WakeConfig()
        wakeCheckInDays = snapshot.wakeCheckInDays ?? []
        bedtime = snapshot.bedtime ?? BedtimeConfig()
        sleepSessions = snapshot.sleepSessions ?? []
        socialEvents = snapshot.socialEvents ?? []
        moodByDay = snapshot.moodByDay
        chats = snapshot.chats
    }

    func dismissCelebration() {
        celebration = nil
    }

    // MARK: - AI

    /// Earlier prototypes stored an Anthropic key on the device. Estimates
    /// now go through the FlexUp server (`BackendConfig`), so wipe any key
    /// an old build left behind.
    private func removeLegacyAPIKey() {
        UserDefaults.standard.removeObject(forKey: "anthropicAPIKey")
    }
}
