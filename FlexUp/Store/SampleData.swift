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

    /// One-tap foods for the Diet logger, with typical macros per portion.
    struct QuickFood: Identifiable, Hashable {
        var id: String { name }
        var name: String
        var calories: Int
        var macros: Macros
    }

    static let quickFoods: [QuickFood] = [
        QuickFood(name: "Oats bowl", calories: 220, macros: Macros(protein: 8, carbs: 38, fat: 4, fiber: 5, sugar: 1, sodiumMg: 5)),
        QuickFood(name: "2 eggs", calories: 156, macros: Macros(protein: 12.6, carbs: 1.1, fat: 10.6, sugar: 1.1, sodiumMg: 140)),
        QuickFood(name: "Banana", calories: 105, macros: Macros(protein: 1.3, carbs: 27, fat: 0.4, fiber: 3.1, sugar: 14, sodiumMg: 1)),
        QuickFood(name: "Apple", calories: 95, macros: Macros(protein: 0.5, carbs: 25, fat: 0.3, fiber: 4.4, sugar: 19, sodiumMg: 2)),
        QuickFood(name: "Chicken breast", calories: 165, macros: Macros(protein: 31, fat: 3.6, sodiumMg: 74)),
        QuickFood(name: "Paneer 100g", calories: 265, macros: Macros(protein: 18, carbs: 1.2, fat: 21, sugar: 1.2, sodiumMg: 18)),
        QuickFood(name: "Rice bowl", calories: 240, macros: Macros(protein: 4.4, carbs: 53, fat: 0.4, fiber: 0.6, sodiumMg: 2)),
        QuickFood(name: "Dal bowl", calories: 180, macros: Macros(protein: 10, carbs: 28, fat: 3, fiber: 8, sugar: 2, sodiumMg: 350)),
        QuickFood(name: "2 rotis", calories: 200, macros: Macros(protein: 6, carbs: 36, fat: 4, fiber: 6, sugar: 0.5, sodiumMg: 250)),
        QuickFood(name: "Protein shake", calories: 180, macros: Macros(protein: 25, carbs: 8, fat: 3, fiber: 1, sugar: 3, sodiumMg: 150)),
        QuickFood(name: "Greek yogurt", calories: 120, macros: Macros(protein: 17, carbs: 6, fat: 3, sugar: 6, sodiumMg: 60)),
        QuickFood(name: "Handful of nuts", calories: 170, macros: Macros(protein: 6, carbs: 6, fat: 15, fiber: 3, sugar: 1, sodiumMg: 1)),
        QuickFood(name: "Glass of milk", calories: 150, macros: Macros(protein: 8, carbs: 12, fat: 8, sugar: 12, sodiumMg: 105)),
        QuickFood(name: "Salmon fillet", calories: 280, macros: Macros(protein: 30, fat: 17, sodiumMg: 90)),
        QuickFood(name: "Tofu 150g", calories: 215, macros: Macros(protein: 23, carbs: 4, fat: 13, fiber: 3, sodiumMg: 20)),
        QuickFood(name: "Avocado toast", calories: 290, macros: Macros(protein: 7, carbs: 30, fat: 17, fiber: 8, sugar: 3, sodiumMg: 330)),
    ]

    /// Calories a photo can't see. Cooking fat is the single biggest source
    /// of error in photo estimation — a curry looks identical whether it was
    /// finished with a spoon of ghee or nothing at all.
    struct HiddenIngredient: Identifiable, Hashable {
        var id: String { name }
        var name: String
        var calories: Int
        var portion: String
        var macros: Macros
    }

    static let hiddenIngredients: [HiddenIngredient] = [
        HiddenIngredient(name: "Cooking oil", calories: 120, portion: "1 tbsp", macros: Macros(fat: 14)),
        HiddenIngredient(name: "Ghee", calories: 112, portion: "1 tbsp", macros: Macros(fat: 12.7)),
        HiddenIngredient(name: "Butter", calories: 102, portion: "1 tbsp", macros: Macros(protein: 0.1, fat: 11.5, sodiumMg: 90)),
        HiddenIngredient(name: "Olive oil", calories: 119, portion: "1 tbsp", macros: Macros(fat: 13.5)),
        HiddenIngredient(name: "Cream", calories: 52, portion: "1 tbsp", macros: Macros(protein: 0.4, carbs: 0.4, fat: 5.5, sugar: 0.4, sodiumMg: 6)),
        HiddenIngredient(name: "Coconut milk", calories: 111, portion: "1/4 cup", macros: Macros(protein: 1.1, carbs: 1.6, fat: 12, sodiumMg: 7)),
        HiddenIngredient(name: "Sugar", calories: 16, portion: "1 tsp", macros: Macros(carbs: 4.2, sugar: 4.2)),
        HiddenIngredient(name: "Mayonnaise", calories: 94, portion: "1 tbsp", macros: Macros(carbs: 0.1, fat: 10.3, sodiumMg: 88)),
        HiddenIngredient(name: "Cheese", calories: 113, portion: "1 slice", macros: Macros(protein: 7, carbs: 0.4, fat: 9.3, sodiumMg: 180)),
        HiddenIngredient(name: "Nuts / seeds", calories: 170, portion: "small handful", macros: Macros(protein: 6, carbs: 6, fat: 15, fiber: 3, sugar: 1)),
        HiddenIngredient(name: "Deep fried", calories: 130, portion: "absorbed oil", macros: Macros(fat: 14.5)),
        HiddenIngredient(name: "Dressing / sauce", calories: 75, portion: "1 tbsp", macros: Macros(carbs: 2, fat: 7, sugar: 1.5, sodiumMg: 150)),
    ]

    /// Starting points for the cooking context. Western food databases
    /// systematically misjudge these cuisines, so telling the model which
    /// one you cook in is the highest-leverage correction available.
    static let cuisinePresets: [String] = [
        "North Indian home cooking",
        "South Indian home cooking",
        "Pakistani / Punjabi",
        "Bangladeshi / Bengali",
        "Chinese home cooking",
        "Japanese",
        "Korean",
        "Thai",
        "Vietnamese",
        "Filipino",
        "Middle Eastern / Levantine",
        "Turkish",
        "Persian",
        "West African",
        "Ethiopian",
        "North African / Maghrebi",
        "Mexican",
        "Brazilian",
        "Caribbean",
        "Mediterranean",
        "American / Western",
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
