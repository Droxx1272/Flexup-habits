import Foundation
import CoreLocation

// MARK: - Core loop: Plan → Commit → Do → Verify → Celebrate → Repeat

/// The lifecycle of every commitment in FlexUp.
enum CommitmentStatus: String, Codable, CaseIterable {
    case scheduled
    case confirmed
    case completed
    case missed
    case rescheduled

    var label: String {
        switch self {
        case .scheduled: "Scheduled"
        case .confirmed: "Confirmed"
        case .completed: "Completed"
        case .missed: "Missed"
        case .rescheduled: "Rescheduled"
        }
    }
}

/// How a completion gets verified. Honor and timer are fully local in v1;
/// photo, partner and GPS verification light up once the backend exists.
enum VerificationMethod: String, Codable, CaseIterable, Identifiable {
    case honor
    case timer
    case photo
    case partner
    case location

    var id: String { rawValue }

    var label: String {
        switch self {
        case .honor: "Honor"
        case .timer: "Timer"
        case .photo: "Photo"
        case .partner: "Partner"
        case .location: "GPS"
        }
    }

    var icon: String {
        switch self {
        case .honor: "hand.raised"
        case .timer: "timer"
        case .photo: "camera"
        case .partner: "person.2"
        case .location: "location"
        }
    }

    /// Only methods the app can really check. GPS means "record this run"
    /// (`logRun` completes it), so it's offered for runs only. Partner needs
    /// friends, which ship with community; old partner commitments are
    /// completed on honor.
    static func available(for category: ActivityCategory) -> [VerificationMethod] {
        category == .run ? [.honor, .timer, .photo, .location] : [.honor, .timer, .photo]
    }
}

enum ActivityCategory: String, Codable, CaseIterable, Identifiable {
    case run
    case walk
    case gym
    case sport
    case mindfulness
    case reading
    case social

    var id: String { rawValue }

    var label: String {
        switch self {
        case .run: "Running"
        case .walk: "Walking"
        case .gym: "Gym"
        case .sport: "Sports"
        case .mindfulness: "Mindfulness"
        case .reading: "Reading"
        case .social: "Social"
        }
    }

    var icon: String {
        switch self {
        case .run: "figure.run"
        case .walk: "figure.walk"
        case .gym: "dumbbell"
        case .sport: "soccerball"
        case .mindfulness: "leaf"
        case .reading: "book"
        case .social: "person.3"
        }
    }
}

enum Difficulty: String, Codable, CaseIterable, Identifiable {
    case beginner
    case casual
    case competitive

    var id: String { rawValue }

    var label: String {
        switch self {
        case .beginner: "Beginner"
        case .casual: "Casual"
        case .competitive: "Competitive"
        }
    }
}

enum TimeOfDay: String, Codable, CaseIterable, Identifiable {
    case morning
    case midday
    case evening

    var id: String { rawValue }

    var label: String {
        switch self {
        case .morning: "Morning"
        case .midday: "Midday"
        case .evening: "Evening"
        }
    }

    var defaultHour: Int {
        switch self {
        case .morning: 7
        case .midday: 12
        case .evening: 18
        }
    }
}

// MARK: - Habit

struct Habit: Identifiable, Codable, Hashable {
    var id = UUID()
    var title: String
    var category: ActivityCategory
    var scheduleWeekdays: Set<Int>  // Calendar weekday: 1 = Sunday … 7 = Saturday
    var timeOfDay: TimeOfDay
    var verification: VerificationMethod
    var durationMinutes: Int
    var streak: Int = 0
    var bestStreak: Int = 0
}

// MARK: - Commitment

struct Commitment: Identifiable, Codable, Hashable {
    var id = UUID()
    var title: String
    var category: ActivityCategory
    var date: Date
    var status: CommitmentStatus = .scheduled
    var verification: VerificationMethod = .honor
    var durationMinutes: Int = 20
    var habitID: UUID?
    var activityID: UUID?
    var completedAt: Date?
}

// MARK: - Activity (the heart of the app)

struct Activity: Identifiable, Codable, Hashable {
    var id = UUID()
    var title: String
    var category: ActivityCategory
    var goal: String
    var locationName: String
    var distanceKm: Double
    var date: Date
    var difficulty: Difficulty
    var host: String
    var attendees: [String]
    var friendsGoing: [String]
    var isJoined: Bool = false
}

struct ChatMessage: Identifiable, Codable, Hashable {
    var id = UUID()
    var author: String
    var text: String
    var date: Date = .now
}

// MARK: - Runs

struct RoutePoint: Codable, Hashable {
    var lat: Double
    var lon: Double

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: lat, longitude: lon)
    }
}

struct Run: Identifiable, Codable, Hashable {
    var id = UUID()
    var date: Date
    var distanceMeters: Double
    var duration: TimeInterval
    // Optional: added after the first release so older saved runs still decode.
    var route: [RoutePoint]?
    var splitsSeconds: [Double]?
    var elevationGainM: Double?

    var kilometers: Double { distanceMeters / 1000 }

    /// Average pace in seconds per km; nil when there's no meaningful distance.
    var paceSecondsPerKm: Double? {
        kilometers > 0.05 ? duration / kilometers : nil
    }

    var coordinates: [CLLocationCoordinate2D] {
        (route ?? []).map(\.coordinate)
    }

    var splits: [Double] { splitsSeconds ?? [] }

    /// Distance beyond the last full-km split, in meters.
    var finalPartialMeters: Double {
        distanceMeters - Double(splits.count) * 1000
    }
}

// MARK: - Wake (mornings)

struct WakeConfig: Codable, Hashable {
    var hour = 6
    var minute = 30
    /// Calendar weekdays (1 = Sunday … 7 = Saturday) the wake-up applies to.
    var days: Set<Int> = [2, 3, 4, 5, 6]
    var enabled = false
    /// The AlarmKit alarm currently scheduled (iOS 26+), so it can be
    /// cancelled on reschedule. Optional — nil means notifications are
    /// carrying the wake-up.
    var alarmID: UUID?
    /// Photo of the spot you must photograph again to check in (sink,
    /// kettle, front door). nil = any photo counts.
    var proofSpotFileName: String?

    var timeToday: Date {
        Calendar.current.date(bySettingHour: hour, minute: minute, second: 0, of: .now) ?? .now
    }

    var timeLabel: String {
        timeToday.formatted(date: .omitted, time: .shortened)
    }
}

/// Why the wake-up fell back to notifications when it could be a real alarm.
enum WakeAlarmIssue: Equatable {
    /// Alarms are turned off for FlexUp in Settings (iOS 26+).
    case alarmsDenied
    /// AlarmKit refused to schedule; the system's reason.
    case failed(String)
}

// MARK: - Sleep (nights)

struct BedtimeConfig: Codable, Hashable {
    var hour = 22
    var minute = 30
    /// Calendar weekdays (1 = Sunday … 7 = Saturday) the reminder applies to.
    var days: Set<Int> = [1, 2, 3, 4, 5, 6, 7]
    var enabled = false

    var timeToday: Date {
        Calendar.current.date(bySettingHour: hour, minute: minute, second: 0, of: .now) ?? .now
    }

    var timeLabel: String {
        timeToday.formatted(date: .omitted, time: .shortened)
    }
}

enum SleepQuality: Int, Codable, CaseIterable, Identifiable {
    case poor = 1
    case fair = 2
    case good = 3
    case great = 4

    var id: Int { rawValue }

    var label: String {
        switch self {
        case .poor: "Poor"
        case .fair: "Fair"
        case .good: "Good"
        case .great: "Great"
        }
    }

    var emoji: String {
        switch self {
        case .poor: "😩"
        case .fair: "😐"
        case .good: "🙂"
        case .great: "😴"
        }
    }
}

enum SleepGoal {
    static let targetHours = 8.0
}

struct SleepSession: Identifiable, Codable, Hashable {
    var id = UUID()
    var bedtime: Date
    var wakeTime: Date
    var quality: SleepQuality

    var duration: TimeInterval { max(0, wakeTime.timeIntervalSince(bedtime)) }
    var hours: Double { duration / 3600 }

    var durationLabel: String {
        let totalMinutes = Int(duration / 60)
        return "\(totalMinutes / 60)h \(totalMinutes % 60)m"
    }
}

// MARK: - Fuel (calorie tracking)

enum MealType: String, Codable, CaseIterable, Identifiable {
    case breakfast
    case lunch
    case dinner
    case snack

    var id: String { rawValue }

    var label: String {
        switch self {
        case .breakfast: "Breakfast"
        case .lunch: "Lunch"
        case .dinner: "Dinner"
        case .snack: "Snacks"
        }
    }

    var icon: String {
        switch self {
        case .breakfast: "sunrise"
        case .lunch: "sun.max"
        case .dinner: "moon"
        case .snack: "takeoutbag.and.cup.and.straw"
        }
    }
}

/// One component of a meal. The estimator proposes a name, a portion it
/// believes it sees, and the calories for that portion; the user scales it
/// with `multiplier` rather than retyping numbers.
enum FoodSource: String, Codable, Hashable {
    case ai
    case usda
}

struct FoodItem: Identifiable, Codable, Hashable {
    var id = UUID()
    var name: String
    /// Calories for the portion described in `portion`, before adjustment.
    var baseCalories: Int
    var portion: String
    var multiplier: Double = 1
    /// True for things the user added by hand — cooking fats and other
    /// ingredients a photo can't show.
    var isAddOn: Bool = false
    /// Nutrients for the portion in `portion`, before adjustment. Optional
    /// so items saved before macro tracking still decode.
    var baseMacros: Macros?
    /// Weight of the base portion in grams, when known (USDA picks, and AI
    /// estimates since they started reporting it).
    var grams: Double?
    /// Where the numbers came from. nil for items saved before this existed.
    var source: FoodSource?

    var calories: Int { Int((Double(baseCalories) * multiplier).rounded()) }
    var macros: Macros? { baseMacros?.scaled(by: multiplier) }

    var multiplierLabel: String {
        multiplier == multiplier.rounded()
            ? "\(Int(multiplier))×"
            : String(format: "%.2f×", multiplier)
                .replacingOccurrences(of: "0×", with: "×")
    }
}

struct FoodEntry: Identifiable, Codable, Hashable {
    var id = UUID()
    var name: String
    var calories: Int
    var meal: MealType
    var date: Date = .now
    /// Optional meal photo, stored in the app's photo directory.
    var photoFileName: String?
    /// Per-component breakdown when the entry came from a photo estimate.
    /// Optional so entries saved before itemisation still decode.
    var items: [FoodItem]?
    /// Protein/carbs/fat and friends. Nil when only calories are known —
    /// older entries and hand-typed numbers — so totals can say honestly
    /// how much of the day they cover.
    var macros: Macros?
}

/// Grams, except sodium. Everything the Diet tab shows beyond calories.
struct Macros: Codable, Hashable {
    var protein: Double = 0
    var carbs: Double = 0
    var fat: Double = 0
    var fiber: Double = 0
    var sugar: Double = 0
    var sodiumMg: Double = 0

    static let zero = Macros()

    static func + (lhs: Macros, rhs: Macros) -> Macros {
        Macros(
            protein: lhs.protein + rhs.protein,
            carbs: lhs.carbs + rhs.carbs,
            fat: lhs.fat + rhs.fat,
            fiber: lhs.fiber + rhs.fiber,
            sugar: lhs.sugar + rhs.sugar,
            sodiumMg: lhs.sodiumMg + rhs.sodiumMg
        )
    }

    func scaled(by factor: Double) -> Macros {
        Macros(
            protein: protein * factor,
            carbs: carbs * factor,
            fat: fat * factor,
            fiber: fiber * factor,
            sugar: sugar * factor,
            sodiumMg: sodiumMg * factor
        )
    }

    /// Energy from the three macronutrients (4 / 4 / 9 kcal per gram).
    var calorieSplit: (protein: Double, carbs: Double, fat: Double) {
        (protein * 4, carbs * 4, fat * 9)
    }

    var isEmpty: Bool { protein + carbs + fat + fiber + sugar + sodiumMg == 0 }

    /// "P 30 · C 45 · F 12" — the compact line under a food row.
    var shortLabel: String {
        "P \(Int(protein.rounded())) · C \(Int(carbs.rounded())) · F \(Int(fat.rounded()))"
    }
}

/// Daily targets. Calories used to live alone as `calorieBudget`; the store
/// still exposes that name so nothing downstream had to change.
struct NutritionGoals: Codable, Hashable {
    var calories: Int = 2200
    var protein: Int = 130
    var carbs: Int = 240
    var fat: Int = 70
    var fiber: Int = 30
    var waterMl: Int = 2500
}

/// A starting point for macro targets. Protein stays high in every
/// direction — it's what keeps muscle while cutting and builds it while
/// gaining.
enum DietDirection: String, CaseIterable, Identifiable {
    case lose = "Lose"
    case maintain = "Maintain"
    case build = "Build"

    var id: String { rawValue }

    /// Share of calories from protein / carbs / fat.
    var split: (protein: Double, carbs: Double, fat: Double) {
        switch self {
        case .lose: (0.35, 0.35, 0.30)
        case .maintain: (0.25, 0.45, 0.30)
        case .build: (0.25, 0.50, 0.25)
        }
    }

    func goals(calories: Int, keeping current: NutritionGoals) -> NutritionGoals {
        var goals = current
        goals.calories = calories
        goals.protein = Int((Double(calories) * split.protein / 4).rounded())
        goals.carbs = Int((Double(calories) * split.carbs / 4).rounded())
        goals.fat = Int((Double(calories) * split.fat / 9).rounded())
        return goals
    }
}

// MARK: - Lift (training log)

/// How a set counts. Warm-ups are logged but left out of volume and PRs.
enum SetKind: String, Codable, CaseIterable, Hashable {
    case warmup, normal, failure, drop

    var label: String {
        switch self {
        case .warmup: "Warm-up"
        case .normal: "Normal"
        case .failure: "Failure"
        case .drop: "Drop set"
        }
    }

    /// What the set column shows instead of a number.
    var badge: String? {
        switch self {
        case .warmup: "W"
        case .normal: nil
        case .failure: "F"
        case .drop: "D"
        }
    }
}

/// What gets recorded for an exercise.
enum ExerciseKind: String, Codable, Hashable {
    /// Weight and reps (bench press).
    case weightReps
    /// Reps, with optional added weight (pull-up, dip).
    case bodyweight
    /// A hold, in seconds (plank).
    case duration
}

struct ExerciseSet: Identifiable, Codable, Hashable {
    var id = UUID()
    var weightKg: Double = 0
    var reps: Int = 0
    /// nil for sets saved before set types existed; read as `.normal`.
    var kind: SetKind?
    /// Ticked off during the session. nil for older saves, which only kept
    /// finished sets anyway.
    var isDone: Bool?
    /// For timed exercises.
    var seconds: Int?

    var setKind: SetKind { kind ?? .normal }
    var counts: Bool { setKind != .warmup }

    /// Epley estimate, the usual way apps compare sets of different reps.
    var estimatedOneRepMax: Double {
        guard weightKg > 0, reps > 0 else { return 0 }
        return reps == 1 ? weightKg : weightKg * (1 + Double(reps) / 30)
    }
}

struct WorkoutExercise: Identifiable, Codable, Hashable {
    var id = UUID()
    var name: String
    var sets: [ExerciseSet] = [ExerciseSet()]
    var notes: String?
    /// Rest after each set, in seconds. nil = the default 90. 0 = off.
    var restSeconds: Int?
    var kind: ExerciseKind?

    var exerciseKind: ExerciseKind { kind ?? .weightReps }
}

/// A saved session template. Newer routines keep each exercise's sets
/// (as targets); older ones only have the names.
struct Routine: Identifiable, Codable, Hashable {
    var id = UUID()
    var name: String
    var exerciseNames: [String]
    var exercises: [WorkoutExercise]?

    /// Fresh, unticked exercises to start a session with.
    var startingExercises: [WorkoutExercise] {
        if let exercises, !exercises.isEmpty {
            return exercises.map { exercise in
                var copy = exercise
                copy.id = UUID()
                copy.sets = exercise.sets.map { ExerciseSet(weightKg: $0.weightKg, reps: $0.reps, kind: $0.kind, seconds: $0.seconds) }
                if copy.sets.isEmpty { copy.sets = [ExerciseSet()] }
                return copy
            }
        }
        return exerciseNames.map { WorkoutExercise(name: $0) }
    }
}

/// The session in progress, saved as it changes so a crash or a closed app
/// doesn't lose it.
struct WorkoutDraft: Codable, Hashable {
    var title: String
    var startedAt: Date
    var exercises: [WorkoutExercise]
}

struct Workout: Identifiable, Codable, Hashable {
    var id = UUID()
    var title: String
    var date: Date
    var duration: TimeInterval
    var exercises: [WorkoutExercise]

    /// Warm-ups don't count, as in every serious lifting log.
    var totalVolumeKg: Double {
        exercises.flatMap(\.sets).filter(\.counts).reduce(0) { $0 + $1.weightKg * Double($1.reps) }
    }

    var totalSets: Int {
        exercises.reduce(0) { $0 + $1.sets.filter(\.counts).count }
    }
}

// MARK: - Body weight

struct WeightEntry: Identifiable, Codable, Hashable {
    var id = UUID()
    var date: Date
    var kilograms: Double
}

// MARK: - Progress photos

enum PhotoPose: String, Codable, CaseIterable, Identifiable {
    case front
    case side
    case back
    case flex
    /// Photo taken to verify a commitment (BeReal-style proof, not a pose).
    case proof

    var id: String { rawValue }

    var label: String {
        switch self {
        case .front: "Front"
        case .side: "Side"
        case .back: "Back"
        case .flex: "Flex"
        case .proof: "Check-in"
        }
    }

    var icon: String {
        switch self {
        case .front: "figure.stand"
        case .side: "figure.walk"
        case .back: "figure.arms.open"
        case .flex: "figure.strengthtraining.traditional"
        case .proof: "checkmark.seal"
        }
    }

    /// Poses offered in the capture flow (proof is system-generated).
    static var captureCases: [PhotoPose] { [.front, .side, .back, .flex] }
}

struct ProgressPhoto: Identifiable, Codable, Hashable {
    var id = UUID()
    var date: Date
    var pose: PhotoPose
    var fileName: String
}

// MARK: - Social

struct Friend: Identifiable, Codable, Hashable {
    var id = UUID()
    var name: String
}

/// A feed entry on the Squad dashboard. Every event points at action —
/// something to join, cheer, or celebrate. Never idle content.
struct SocialEvent: Identifiable, Codable, Hashable {
    enum Kind: String, Codable {
        case completed
        case created
        case achievement
        case milestone
    }

    var id = UUID()
    var author: String
    var kind: Kind
    var message: String
    var detail: String?
    var date: Date
    var activityID: UUID?
    var cheers: Int = 0
    var cheeredByMe: Bool = false

    var icon: String {
        switch kind {
        case .completed: "checkmark.circle.fill"
        case .created: "calendar.badge.plus"
        case .achievement: "rosette"
        case .milestone: "flame.fill"
        }
    }
}

/// A moment worth keeping: a completed commitment, a run, an achievement.
/// Derived from history, never stored — memories are earned, not written.
struct Memory: Identifiable {
    var id: String
    var title: String
    var subtitle: String
    var icon: String
    var date: Date
    var isHighlight: Bool = false

    var shareText: String {
        "\(title): \(subtitle) · \(date.formatted(date: .abbreviated, time: .omitted)) · FlexUp"
    }
}

struct Community: Identifiable, Codable, Hashable {
    var id = UUID()
    var name: String
    var icon: String
    var members: Int
    var isJoined: Bool = false
    var nextEvent: String?
}

// MARK: - Achievements

enum AchievementCategory: String, Codable, CaseIterable {
    case firsts
    case consistency
    case community
    case exploration
    case milestones
    case leadership

    var label: String {
        switch self {
        case .firsts: "Firsts"
        case .consistency: "Consistency"
        case .community: "Community"
        case .exploration: "Exploration"
        case .milestones: "Milestones"
        case .leadership: "Leadership"
        }
    }
}

struct Achievement: Identifiable, Codable, Hashable {
    var id = UUID()
    var key: String
    var title: String
    var detail: String
    var category: AchievementCategory
    var icon: String
    var isHidden: Bool = false
    var earnedAt: Date?

    var isEarned: Bool { earnedAt != nil }
}

// MARK: - Account (login)

enum AuthProvider: String, Codable {
    case apple
    case email
}

struct Account: Codable, Hashable {
    var userID: String
    var name: String
    var email: String?
    var provider: AuthProvider
    var createdAt: Date = .now
}

// MARK: - Profile

struct UserProfile: Codable {
    var name: String
    var identityStatement: String
    var interests: [ActivityCategory]
    var joinedAt: Date = .now
    /// Profile photo in the app's photo directory. Optional so older saves decode.
    var photoFileName: String?
}

// MARK: - Coach

enum CoachAction: Hashable {
    case quickStart(ActivityCategory)
    case openActivity(UUID)
}

struct CoachInsight {
    var message: String
    var actionLabel: String?
    var action: CoachAction?
}

// MARK: - Celebration

struct Celebration {
    var title: String
    var message: String
    var streak: Int?
    var achievement: Achievement?
}

// MARK: - Stats

// MARK: - Progress

/// The window the Progress page looks back over. Short ranges chart by
/// day; long ones by week so the bars stay readable.
enum ProgressRange: String, CaseIterable, Identifiable {
    case week = "7D"
    case month = "30D"
    case quarter = "90D"
    case year = "1Y"

    var id: String { rawValue }

    var days: Int {
        switch self {
        case .week: 7
        case .month: 30
        case .quarter: 90
        case .year: 365
        }
    }

    var bucket: Calendar.Component { days <= 30 ? .day : .weekOfYear }

    var label: String {
        switch self {
        case .week: "last 7 days"
        case .month: "last 30 days"
        case .quarter: "last 90 days"
        case .year: "last year"
        }
    }
}

/// One bar or point on a progress chart.
struct DailyPoint: Identifiable, Hashable {
    var date: Date
    var value: Double
    var id: Date { date }
}

struct PersonalRecord: Identifiable, Hashable {
    var exercise: String
    var weightKg: Double
    var reps: Int
    var date: Date
    var id: String { exercise }
}

// MARK: - Goals & preferences (asked right after sign-up)

/// What someone wants out of FlexUp, in outcomes rather than activities.
enum GoalFocus: String, Codable, CaseIterable, Identifiable {
    case loseFat, buildMuscle, runFarther, sleepBetter, wakeEarlier, eatBetter, beConsistent

    var id: String { rawValue }

    var label: String {
        switch self {
        case .loseFat: "Lose fat"
        case .buildMuscle: "Build muscle"
        case .runFarther: "Run farther"
        case .sleepBetter: "Sleep better"
        case .wakeEarlier: "Wake up earlier"
        case .eatBetter: "Eat better"
        case .beConsistent: "Be consistent"
        }
    }

    var icon: String {
        switch self {
        case .loseFat: "flame"
        case .buildMuscle: "dumbbell"
        case .runFarther: "figure.run"
        case .sleepBetter: "moon.zzz"
        case .wakeEarlier: "sunrise"
        case .eatBetter: "leaf"
        case .beConsistent: "checkmark.seal"
        }
    }
}

/// Weekly targets. The Today screen measures the week against these.
struct UserGoals: Codable, Hashable {
    var focuses: [GoalFocus] = []
    var runsPerWeek = 2
    var gymPerWeek = 3
    var currentWeightKg: Double?
    var targetWeightKg: Double?
}

/// Local reminder switches. Wake alarm and bedtime keep their own configs.
struct ReminderPreferences: Codable, Hashable {
    var habitReminders = true
}

struct DayStat: Identifiable {
    var id = UUID()
    var label: String
    var completed: Int
    var planned: Int
}
