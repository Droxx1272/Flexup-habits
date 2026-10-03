import SwiftUI

/// Thin tab wrappers giving each pillar its own place in the nav. Each
/// header's tagline is a live status line, not a slogan.

/// "2 of 3 runs this week", or just the count when there's no target.
func weekLine(_ done: Int, of target: Int, noun: String) -> String {
    let plural = (target > 0 ? target : done) == 1 ? noun : noun + "s"
    return target > 0 ? "\(done) of \(target) \(plural) this week" : "\(done) \(plural) this week"
}

struct RunTabView: View {
    @Environment(AppStore.self) private var store

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    ScreenHeader(title: "Run", tagline: weekLine(store.weekProgress.runs, of: store.goals.runsPerWeek, noun: "run"))
                    RunSection()
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 24)
            }
            .scrollIndicators(.hidden)
            .background(Theme.background)
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(for: Run.self) { run in
                RunDetailView(run: run)
            }
        }
    }
}

struct GymTabView: View {
    @Environment(AppStore.self) private var store

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    ScreenHeader(title: "Gym", tagline: weekLine(store.weekProgress.workouts, of: store.goals.gymPerWeek, noun: "session"))
                    LiftSection()
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 24)
            }
            .scrollIndicators(.hidden)
            .background(Theme.background)
            .toolbar(.hidden, for: .navigationBar)
        }
    }
}

struct DietTabView: View {
    @Environment(AppStore.self) private var store

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    ScreenHeader(title: "Diet", tagline: "\(store.caloriesToday) of \(store.nutritionGoals.calories) kcal today")
                    FuelSection()
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 24)
            }
            .scrollIndicators(.hidden)
            .background(Theme.background)
            .toolbar(.hidden, for: .navigationBar)
        }
    }
}
