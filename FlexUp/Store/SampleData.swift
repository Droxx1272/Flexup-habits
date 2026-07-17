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

    /// Exercise library for the Lift logger.
    struct ExerciseTemplate: Identifiable, Hashable {
        var id: String { name }
        var name: String
        var muscle: String
    }

    static let exerciseCatalog: [ExerciseTemplate] = [
        ExerciseTemplate(name: "Bench Press", muscle: "Chest"),
        ExerciseTemplate(name: "Incline Dumbbell Press", muscle: "Chest"),
        ExerciseTemplate(name: "Cable Fly", muscle: "Chest"),
        ExerciseTemplate(name: "Push-up", muscle: "Chest"),
        ExerciseTemplate(name: "Squat", muscle: "Legs"),
        ExerciseTemplate(name: "Leg Press", muscle: "Legs"),
        ExerciseTemplate(name: "Romanian Deadlift", muscle: "Legs"),
        ExerciseTemplate(name: "Lunge", muscle: "Legs"),
        ExerciseTemplate(name: "Calf Raise", muscle: "Legs"),
        ExerciseTemplate(name: "Hip Thrust", muscle: "Glutes"),
        ExerciseTemplate(name: "Deadlift", muscle: "Back"),
        ExerciseTemplate(name: "Barbell Row", muscle: "Back"),
        ExerciseTemplate(name: "Lat Pulldown", muscle: "Back"),
        ExerciseTemplate(name: "Pull-up", muscle: "Back"),
        ExerciseTemplate(name: "Seated Row", muscle: "Back"),
        ExerciseTemplate(name: "Overhead Press", muscle: "Shoulders"),
        ExerciseTemplate(name: "Lateral Raise", muscle: "Shoulders"),
        ExerciseTemplate(name: "Bicep Curl", muscle: "Arms"),
        ExerciseTemplate(name: "Tricep Pushdown", muscle: "Arms"),
        ExerciseTemplate(name: "Plank", muscle: "Core"),
    ]

    /// One-tap foods for the Fuel logger.
    struct QuickFood: Identifiable, Hashable {
        var id: String { name }
        var name: String
        var calories: Int
    }

    static let quickFoods: [QuickFood] = [
        QuickFood(name: "Oats bowl", calories: 220),
        QuickFood(name: "2 eggs", calories: 156),
        QuickFood(name: "Banana", calories: 105),
        QuickFood(name: "Apple", calories: 95),
        QuickFood(name: "Chicken breast", calories: 165),
        QuickFood(name: "Paneer 100g", calories: 265),
        QuickFood(name: "Rice bowl", calories: 240),
        QuickFood(name: "Dal bowl", calories: 180),
        QuickFood(name: "2 rotis", calories: 200),
        QuickFood(name: "Protein shake", calories: 180),
        QuickFood(name: "Greek yogurt", calories: 120),
        QuickFood(name: "Handful of nuts", calories: 170),
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

    /// Squad feed fixtures, linked to seeded activities so every event with
    /// a "Join" CTA opens a real activity.
    static func socialEvents(activities: [Activity], from now: Date = .now) -> [SocialEvent] {
        func ago(_ hours: Double) -> Date { now.addingTimeInterval(-hours * 3600) }
        func activity(_ title: String) -> UUID? { activities.first { $0.title == title }?.id }

        return [
            SocialEvent(
                author: "Aman", kind: .completed,
                message: "Aman completed his first 10K.",
                detail: "Join his next run.",
                date: ago(3), activityID: activity("Sunrise 5K"), cheers: 4
            ),
            SocialEvent(
                author: "Sarah", kind: .created,
                message: "Sarah created a trail hike.",
                detail: "8 km at Cedar Ridge. Moderate climb, great views.",
                date: ago(7), activityID: activity("Trail hike"), cheers: 2
            ),
            SocialEvent(
                author: "Maya", kind: .achievement,
                message: "Maya unlocked One Week Strong.",
                detail: "Seven days without missing.",
                date: ago(21), cheers: 6
            ),
            SocialEvent(
                author: "Jonas", kind: .created,
                message: "Jonas is hosting 7-a-side football.",
                detail: "Two spots left for Saturday.",
                date: ago(27), activityID: activity("Saturday football"), cheers: 3
            ),
            SocialEvent(
                author: "Priya", kind: .milestone,
                message: "Your crew logged 18 workouts this week.",
                detail: "Best week yet. Keep it rolling.",
                date: ago(32), cheers: 8
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
        Achievement(key: "first_run", title: "First Run", detail: "Track your first run.", category: .firsts, icon: "figure.run"),
        Achievement(key: "five_k", title: "5K", detail: "Run 5 km in a single run.", category: .milestones, icon: "medal.fill"),
        Achievement(key: "first_lift", title: "First Session", detail: "Log your first workout.", category: .firsts, icon: "dumbbell"),
        Achievement(key: "ton_lifted", title: "The Ton", detail: "Lift 1,000 kg of volume in one session.", category: .milestones, icon: "scalemass.fill"),
        Achievement(key: "first_photo", title: "Day One", detail: "Take your first progress photo.", category: .firsts, icon: "camera.fill"),
        Achievement(key: "host", title: "Host", detail: "Organize an activity for others.", category: .leadership, icon: "megaphone.fill"),
        Achievement(key: "first_sleep", title: "First Night", detail: "Log your first night's sleep.", category: .firsts, icon: "moon.stars.fill"),
        Achievement(key: "full_battery", title: "Full Battery", detail: "Log 8+ hours of sleep in one night.", category: .milestones, icon: "battery.100percent"),
        Achievement(key: "sleep_week", title: "Well Rested Week", detail: "Log sleep 7 nights in a row.", category: .consistency, icon: "moon.zzz.fill"),
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
