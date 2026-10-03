import SwiftUI

struct RootView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.scenePhase) private var scenePhase
    /// The vault door covers everything at launch, and again whenever the
    /// app goes to the background with the lock on.
    @State private var vaultShown = true

    var body: some View {
        Group {
            if !store.hasSeenIntro {
                IntroView()
                    .transition(.opacity)
            } else if !store.isSignedIn {
                AuthView()
            } else if !store.hasOnboarded {
                OnboardingView()
            } else {
                MainTabView()
            }
        }
        .overlay {
            if let celebration = store.celebration {
                CelebrationView(celebration: celebration)
                    .transition(.opacity)
            }
        }
        .overlay {
            if vaultShown {
                VaultView(requiresUnlock: store.vaultLock && store.isSignedIn) {
                    vaultShown = false
                }
                .transition(.identity)
            }
        }
        .onChange(of: scenePhase) { _, phase in
            // Only on background: Face ID itself briefly makes the app inactive.
            if phase == .background && store.vaultLock && store.isSignedIn {
                vaultShown = true
            }
        }
        .animation(.spring(duration: 0.35), value: store.celebration != nil)
        .animation(.easeInOut(duration: 0.35), value: store.hasSeenIntro)
    }
}

/// One tab per pillar, plus Today (commitments, community, progress, stats).
/// Everything else (Discover, Squad, Calendar, coach) stays in the codebase
/// for later — the nav stays simple.
struct MainTabView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.scenePhase) private var scenePhase

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
            TodayView()
                .tabItem { Label("Today", systemImage: "checklist") }
        }
        .tint(Theme.accent)
        // Every time the app comes forward, make sure the wake-up that's
        // switched on is really scheduled.
        .onAppear { store.verifyWakeSchedule() }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { store.verifyWakeSchedule() }
        }
        // Keeps the header's chat / bell counts current while the app is open.
        .task(id: store.community.isSignedIn) {
            while FeatureFlags.community && store.community.isSignedIn && !Task.isCancelled {
                await store.community.refreshBadges()
                try? await Task.sleep(for: .seconds(60))
            }
        }
    }
}

#Preview {
    RootView()
        .environment(AppStore())
}
