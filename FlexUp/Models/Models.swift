import Foundation

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

struct Run: Identifiable, Codable, Hashable {
    var id = UUID()
    var date: Date
    var distanceMeters: Double
    var duration: TimeInterval

    var kilometers: Double { distanceMeters / 1000 }

    /// Average pace in seconds per km; nil when there's no meaningful distance.
    var paceSecondsPerKm: Double? {
        kilometers > 0.05 ? duration / kilometers : nil
    }
}

// MARK: - Social

struct Friend: Identifiable, Codable, Hashable {
    var id = UUID()
    var name: String
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
