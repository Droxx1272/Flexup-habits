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
    var foodEntries: [FoodEntry] = []
    var progressPhotos: [ProgressPhoto] = []
    var calorieBudget: Int = 2200
    var wake = WakeConfig()
    var wakeCheckInDays: Set<String> = []
    var socialEvents: [SocialEvent] = []
    var moodByDay: [String: String] = [:]
    var chats: [UUID: [ChatMessage]] = [:]

    /// Non-nil while the celebration overlay is showing. Never persisted.
    var celebration: Celebration?

    var hasOnboarded: Bool { profile != nil }
    var isSignedIn: Bool { account != nil }

    func signIn(_ account: Account) {
        self.account = account
        save()
    }

    /// Signing out gates the app behind login again. Local data stays on
    /// device — signing back in with the same account picks it right up.
    func signOut() {
        account = nil
        save()
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
        save()
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

    var todayMood: String? {
        get { moodByDay[dayKey()] }
        set { moodByDay[dayKey()] = newValue; save() }
    }

    // MARK: - Commitment actions

    func liveCommitment(_ commitment: Commitment) -> Commitment {
        commitments.first { $0.id == commitment.id } ?? commitment
    }

    func complete(_ commitment: Commitment) {
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

        if let commitment = todayCommitments.first(where: { $0.category == .run && $0.status != .completed && $0.status != .missed }) {
            complete(commitment)
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

        if let commitment = todayCommitments.first(where: { $0.category == .gym && $0.status != .completed && $0.status != .missed }) {
            complete(commitment)
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

    func addFood(name: String, calories: Int, meal: MealType, photoData: Data? = nil) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, calories > 0 else { return }
        let fileName = photoData.flatMap { saveImage($0) }
        foodEntries.insert(FoodEntry(name: trimmed, calories: calories, meal: meal, photoFileName: fileName), at: 0)
        save()
    }

    func deleteFood(_ entry: FoodEntry) {
        if let fileName = entry.photoFileName {
            try? FileManager.default.removeItem(at: imageURL(fileName: fileName))
        }
        foodEntries.removeAll { $0.id == entry.id }
        save()
    }

    func todayFood(for meal: MealType) -> [FoodEntry] {
        foodEntries.filter { $0.meal == meal && calendar.isDateInToday($0.date) }
    }

    var caloriesToday: Int {
        foodEntries
            .filter { calendar.isDateInToday($0.date) }
            .reduce(0) { $0 + $1.calories }
    }

    // MARK: - Wake

    var isWakeCheckedInToday: Bool {
        wakeCheckInDays.contains(dayKey())
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
        celebration = Celebration(
            title: "Morning won.",
            message: streak > 1
                ? "That's \(streak) wake-ups in a row. The day is yours before it starts."
                : "Up is up. Everything else gets easier from here.",
            streak: streak > 1 ? streak : nil,
            achievement: unlocked.first
        )
        save()
    }

    /// Re-sync the repeating wake-up notifications with the current config.
    func updateWakeSchedule() {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: (1...7).map { "wake-\($0)" })
        save()
        guard wake.enabled else { return }

        center.requestAuthorization(options: [.alert, .sound]) { [weak self] granted, _ in
            guard granted, let self else { return }
            let config = self.wake
            for weekday in config.days {
                var components = DateComponents()
                components.weekday = weekday
                components.hour = config.hour
                components.minute = config.minute

                let content = UNMutableNotificationContent()
                content.title = "Wake up. You said so."
                content.body = "Check in before the day decides for you."
                content.sound = .default

                let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
                center.add(UNNotificationRequest(identifier: "wake-\(weekday)", content: content, trigger: trigger))
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
        var foodEntries: [FoodEntry]?
        var progressPhotos: [ProgressPhoto]?
        var calorieBudget: Int?
        var wake: WakeConfig?
        var wakeCheckInDays: Set<String>?
        var socialEvents: [SocialEvent]?
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
            foodEntries: foodEntries,
            progressPhotos: progressPhotos,
            calorieBudget: calorieBudget,
            wake: wake,
            wakeCheckInDays: wakeCheckInDays,
            socialEvents: socialEvents,
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
        foodEntries = snapshot.foodEntries ?? []
        progressPhotos = snapshot.progressPhotos ?? []
        calorieBudget = snapshot.calorieBudget ?? 2200
        wake = snapshot.wake ?? WakeConfig()
        wakeCheckInDays = snapshot.wakeCheckInDays ?? []
        socialEvents = snapshot.socialEvents ?? []
        moodByDay = snapshot.moodByDay
        chats = snapshot.chats
    }

    func dismissCelebration() {
        celebration = nil
    }

    // MARK: - AI

    /// Anthropic API key for the calorie estimator. Prototype-only storage:
    /// lives in UserDefaults on this device. Before any public release this
    /// moves to a backend proxy so no key ships in the app.
    var anthropicAPIKey: String {
        get { UserDefaults.standard.string(forKey: "anthropicAPIKey") ?? "" }
        set { UserDefaults.standard.set(newValue, forKey: "anthropicAPIKey") }
    }
}
