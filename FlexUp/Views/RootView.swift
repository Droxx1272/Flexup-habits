import SwiftUI

struct RootView: View {
    @Environment(AppStore.self) private var store

    var body: some View {
        Group {
            if store.hasOnboarded {
                MainTabView()
            } else {
                OnboardingView()
            }
        }
        .overlay {
            if let celebration = store.celebration {
                CelebrationView(celebration: celebration)
                    .transition(.opacity)
            }
        }
        .animation(.spring(duration: 0.35), value: store.celebration != nil)
    }
}

/// One tab per pillar, plus Stats. Everything else (Discover, Squad,
/// Calendar, coach) stays in the codebase for later — the nav stays simple.
struct MainTabView: View {
    var body: some View {
        TabView {
            WakeView()
                .tabItem { Label("Wake", systemImage: "sunrise.fill") }
            RunTabView()
                .tabItem { Label("Run", systemImage: "figure.run") }
            GymTabView()
                .tabItem { Label("Gym", systemImage: "dumbbell.fill") }
            DietTabView()
                .tabItem { Label("Diet", systemImage: "fork.knife") }
            StatsView()
                .tabItem { Label("Stats", systemImage: "chart.bar.fill") }
        }
        .tint(Theme.accent)
    }
}

#Preview {
    RootView()
        .environment(AppStore())
}
