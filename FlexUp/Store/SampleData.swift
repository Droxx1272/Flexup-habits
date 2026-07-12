import Foundation

/// Habit templates offered during onboarding, grouped by interest.
struct HabitTemplate: Identifiable, Hashable {
    var id: String { title }
    var title: String
    var category: ActivityCategory
    var weekdays: Set<Int>
    var timeOfDay: TimeOfDay
    var verification: VerificationMethod
    var durationMinutes: Int
}

enum SampleData {

    static let habitTemplates: [HabitTemplate] = [
        HabitTemplate(title: "Morning run", category: .run, weekdays: [2, 4, 6], timeOfDay: .morning, verification: .timer, durationMinutes: 25),
        HabitTemplate(title: "Evening walk", category: .walk, weekdays: [1, 2, 3, 4, 5, 6, 7], timeOfDay: .evening, verification: .timer, durationMinutes: 20),
        HabitTemplate(title: "Gym session", category: .gym, weekdays: [2, 4, 6], timeOfDay: .evening, verification: .timer, durationMinutes: 45),
        HabitTemplate(title: "Stretch & mobility", category: .gym, weekdays: [1, 3, 5, 7], timeOfDay: .morning, verification: .timer, durationMinutes: 10),
        HabitTemplate(title: "Read 20 pages", category: .reading, weekdays: [1, 2, 3, 4, 5, 6, 7], timeOfDay: .evening, verification: .honor, durationMinutes: 25),
        HabitTemplate(title: "10 minutes of calm", category: .mindfulness, weekdays: [1, 2, 3, 4, 5, 6, 7], timeOfDay: .morning, verification: .timer, durationMinutes: 10),
        HabitTemplate(title: "Wake up by 7", category: .mindfulness, weekdays: [2, 3, 4, 5, 6], timeOfDay: .morning, verification: .honor, durationMinutes: 5),
        HabitTemplate(title: "Play a sport", category: .sport, weekdays: [7], timeOfDay: .midday, verification: .partner, durationMinutes: 60),
        HabitTemplate(title: "Call a friend", category: .social, weekdays: [1], timeOfDay: .evening, verification: .honor, durationMinutes: 15),
    ]

    static let friends: [Friend] = [
        Friend(name: "Aman"),
        Friend(name: "Sarah"),
        Friend(name: "Maya"),
        Friend(name: "Jonas"),
        Friend(name: "Priya"),
    ]

    /// Nearby activities. In v1 these are local fixtures; later they come
    /// from the location-aware Discover backend.
    static func activities(from now: Date = .now) -> [Activity] {
        let calendar = Calendar.current
        func at(daysFromNow days: Int, hour: Int) -> Date {
            let day = calendar.date(byAdding: .day, value: days, to: calendar.startOfDay(for: now)) ?? now
            return calendar.date(bySettingHour: hour, minute: 0, second: 0, of: day) ?? day
        }

        return [
            Activity(
                title: "Sunrise 5K",
                category: .run,
                goal: "Easy pace, everyone finishes together.",
                locationName: "Riverside Park",
                distanceKm: 1.2,
                date: at(daysFromNow: 1, hour: 6),
                difficulty: .beginner,
                host: "Aman",
                attendees: ["Aman", "Maya", "Leo"],
                friendsGoing: ["Aman", "Maya"]
            ),
            Activity(
                title: "Saturday football",
                category: .sport,
                goal: "Friendly 7-a-side. All levels welcome.",
                locationName: "Northside Pitch",
                distanceKm: 2.8,
                date: at(daysFromNow: 3, hour: 10),
                difficulty: .casual,
                host: "Jonas",
                attendees: ["Jonas", "Aman", "Sam", "Ravi", "Chris"],
                friendsGoing: ["Jonas", "Aman"]
            ),
            Activity(
                title: "Coffee walk",
                category: .walk,
                goal: "5K loop, then coffee. Bring a topic.",
                locationName: "Old Town Square",
                distanceKm: 0.8,
                date: at(daysFromNow: 2, hour: 9),
                difficulty: .beginner,
                host: "Sarah",
                attendees: ["Sarah", "Priya"],
                friendsGoing: ["Sarah", "Priya"]
            ),
            Activity(
                title: "Beginner gym hour",
                category: .gym,
                goal: "Learn the basics with people at your level.",
                locationName: "Pulse Fitness",
                distanceKm: 1.9,
                date: at(daysFromNow: 2, hour: 18),
                difficulty: .beginner,
                host: "Maya",
                attendees: ["Maya", "Elena"],
                friendsGoing: ["Maya"]
            ),
            Activity(
                title: "Trail hike",
                category: .walk,
                goal: "8 km forest trail, moderate climb.",
                locationName: "Cedar Ridge Trailhead",
                distanceKm: 6.4,
                date: at(daysFromNow: 5, hour: 8),
                difficulty: .casual,
                host: "Sarah",
                attendees: ["Sarah", "Jonas", "Kim"],
                friendsGoing: ["Sarah", "Jonas"]
            ),
            Activity(
                title: "Silent reading club",
                category: .reading,
                goal: "One hour. Your book, shared quiet.",
                locationName: "Fable Café",
                distanceKm: 1.1,
                date: at(daysFromNow: 4, hour: 19),
                difficulty: .beginner,
                host: "Priya",
                attendees: ["Priya", "Noor"],
                friendsGoing: ["Priya"]
            ),
            Activity(
                title: "Tempo run",
                category: .run,
                goal: "6 km at threshold pace.",
                locationName: "City Stadium Track",
                distanceKm: 3.5,
                date: at(daysFromNow: 4, hour: 7),
                difficulty: .competitive,
                host: "Leo",
                attendees: ["Leo", "Aman"],
                friendsGoing: ["Aman"]
            ),
        ]
    }

    static let communities: [Community] = [
        Community(name: "Riverside Run Club", icon: "figure.run", members: 128, nextEvent: "Sunrise 5K · tomorrow"),
        Community(name: "Northside Football", icon: "soccerball", members: 54, nextEvent: "7-a-side · Saturday"),
        Community(name: "Fable Book Circle", icon: "book", members: 42, nextEvent: "Silent reading · Thursday"),
        Community(name: "Pulse Beginners", icon: "dumbbell", members: 76, nextEvent: "Gym hour · Wednesday"),
    ]

    /// The achievement catalog. Everything starts locked; the store unlocks
    /// entries as real behavior happens. Hidden achievements show as "?" until earned.
    static let achievements: [Achievement] = [
        Achievement(key: "first_step", title: "First Step", detail: "Complete your first commitment.", category: .firsts, icon: "shoeprints.fill"),
        Achievement(key: "show_up", title: "Show Up", detail: "Join your first activity.", category: .firsts, icon: "figure.wave"),
        Achievement(key: "belong", title: "Belong", detail: "Join your first community.", category: .community, icon: "person.3.fill"),
        Achievement(key: "week_strong", title: "One Week Strong", detail: "Hold a 7-day streak on any habit.", category: .consistency, icon: "flame.fill"),
        Achievement(key: "ten_done", title: "Ten Done", detail: "Complete 10 commitments.", category: .milestones, icon: "10.circle.fill"),
        Achievement(key: "explorer", title: "Explorer", detail: "Complete commitments in 3 different categories.", category: .exploration, icon: "map.fill"),
        Achievement(key: "early_bird", title: "Early Bird", detail: "Complete something before 8 AM.", category: .consistency, icon: "sunrise.fill", isHidden: true),
        Achievement(key: "host", title: "Host", detail: "Organize an activity for others.", category: .leadership, icon: "megaphone.fill"),
    ]

    static let completionTitles: [String] = [
        "Done. That's who you are.",
        "Followed through.",
        "Said it. Did it.",
        "One more brick laid.",
        "That counts.",
    ]

    static let completionMessages: [String] = [
        "Consistency beats intensity.",
        "Progress over perfection.",
        "You're becoming the person you said you'd be.",
        "Small things, repeated. That's the whole secret.",
        "The plan only works because you do.",
    ]
}
