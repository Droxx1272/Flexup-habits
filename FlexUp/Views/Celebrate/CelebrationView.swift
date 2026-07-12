import SwiftUI

/// Full-screen moment shown after any real completion. Celebrate, then get
/// the user back to their life — one button, no loops.
struct CelebrationView: View {
    @Environment(AppStore.self) private var store
    let celebration: Celebration

    @State private var appeared = false

    var body: some View {
        ZStack {
            Color.black.opacity(0.45)
                .ignoresSafeArea()
                .onTapGesture { store.dismissCelebration() }

            VStack(spacing: 18) {
                ZStack {
                    Circle()
                        .fill(Theme.accentSoft)
                        .frame(width: 96, height: 96)
                    Image(systemName: "checkmark")
                        .font(.system(size: 40, weight: .bold))
                        .foregroundStyle(Theme.accent)
                }
                .scaleEffect(appeared ? 1 : 0.3)

                Text(celebration.title)
                    .font(.flexHeading())
                    .foregroundStyle(Theme.ink)
                    .multilineTextAlignment(.center)

                Text(celebration.message)
                    .font(.flexBody())
                    .foregroundStyle(Theme.inkSubtle)
                    .multilineTextAlignment(.center)

                if let streak = celebration.streak, streak > 1 {
                    HStack(spacing: 6) {
                        Image(systemName: "flame.fill")
                        Text("\(streak)-day streak")
                    }
                    .font(.flexBodyBold())
                    .foregroundStyle(Theme.amber)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(Theme.amberSoft)
                    .clipShape(Capsule())
                }

                if let achievement = celebration.achievement {
                    HStack(spacing: 12) {
                        IconBadge(systemName: achievement.icon, tint: Theme.amber, size: 40)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Achievement unlocked")
                                .font(.flexCaption())
                                .foregroundStyle(Theme.inkSubtle)
                            Text(achievement.title)
                                .font(.flexBodyBold())
                                .foregroundStyle(Theme.ink)
                        }
                        Spacer()
                    }
                    .padding(12)
                    .background(Theme.accentSoft.opacity(0.6))
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                }

                Button("Keep going") { store.dismissCelebration() }
                    .buttonStyle(PrimaryButtonStyle())
                    .padding(.top, 4)
            }
            .padding(26)
            .background(Theme.card)
            .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
            .padding(30)
            .scaleEffect(appeared ? 1 : 0.9)
            .opacity(appeared ? 1 : 0)
        }
        .onAppear {
            withAnimation(.spring(duration: 0.45, bounce: 0.35)) {
                appeared = true
            }
        }
    }
}
