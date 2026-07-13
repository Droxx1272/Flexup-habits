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

struct MainTabView: View {
    var body: some View {
        TabView {
            HomeView()
                .tabItem { Label("Home", systemImage: "house.fill") }
            DiscoverView()
                .tabItem { Label("Discover", systemImage: "map.fill") }
            RunsView()
                .tabItem { Label("Runs", systemImage: "figure.run") }
            SquadView()
                .tabItem { Label("Squad", systemImage: "person.3.fill") }
            ProfileView()
                .tabItem { Label("Profile", systemImage: "person.fill") }
        }
        .tint(Theme.accent)
    }
}

#Preview {
    RootView()
        .environment(AppStore())
}
