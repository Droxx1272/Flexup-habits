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

    var timeToday: Date {
        Calendar.current.date(bySettingHour: hour, minute: minute, second: 0, of: .now) ?? .now
    }

    var timeLabel: String {
        timeToday.formatted(date: .omitted, time: .shortened)
    }
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

struct FoodEntry: Identifiable, Codable, Hashable {
    var id = UUID()
    var name: String
    var calories: Int
    var meal: MealType
    var date: Date = .now
    /// Optional meal photo, stored in the app's photo directory.
    var photoFileName: String?
}

// MARK: - Lift (training log)

struct ExerciseSet: Identifiable, Codable, Hashable {
    var id = UUID()
    var weightKg: Double = 0
    var reps: Int = 0
}

struct WorkoutExercise: Identifiable, Codable, Hashable {
    var id = UUID()
    var name: String
    var sets: [ExerciseSet] = [ExerciseSet()]
}

struct Workout: Identifiable, Codable, Hashable {
    var id = UUID()
    var title: String
    var date: Date
    var duration: TimeInterval
    var exercises: [WorkoutExercise]

    var totalVolumeKg: Double {
        exercises.flatMap(\.sets).reduce(0) { $0 + $1.weightKg * Double($1.reps) }
    }

    var totalSets: Int {
        exercises.reduce(0) { $0 + $1.sets.count }
    }
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
        "\(title) — \(subtitle) · \(date.formatted(date: .abbreviated, time: .omitted)) · FlexUp"
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

struct DayStat: Identifiable {
    var id = UUID()
    var label: String
    var completed: Int
    var planned: Int
}
