import SwiftUI

/// Stands in for the Community segment while `FeatureFlags.community` is off.
struct ComingSoonCommunity: View {
    private let features: [(icon: String, title: String, detail: String)] = [
        ("person.2.fill", "Your crew", "Add friends with a code and see who's shown up today."),
        ("photo.on.rectangle", "Posts & kudos", "Share a win or a photo; cheer each other on."),
        ("bubble.left.and.bubble.right.fill", "Messages", "Plan the 6 a.m. run together."),
        ("hand.wave.fill", "Nudges", "A friendly push when someone's gone quiet."),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            FlexCard {
                VStack(alignment: .leading, spacing: 12) {
                    Text("COMING SOON")
                        .font(.flexMono(10))
                        .tracking(2)
                        .foregroundStyle(Theme.accent)
                    Text("DO IT TOGETHER")
                        .font(.flexDisplay(30))
                        .foregroundStyle(Theme.ink)
                    Text("People who tell a friend follow through far more often. Community lands in an upcoming update — your account is already set for it.")
                        .font(.flexCaption())
                        .foregroundStyle(Theme.inkSubtle)
                }
            }

            VStack(spacing: 10) {
                ForEach(features, id: \.title) { feature in
                    HStack(spacing: 14) {
                        IconBadge(systemName: feature.icon, size: 42)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(feature.title)
                                .font(.flexBodyBold())
                                .foregroundStyle(Theme.ink)
                            Text(feature.detail)
                                .font(.flexCaption())
                                .foregroundStyle(Theme.inkSubtle)
                        }
                        Spacer()
                    }
                    .padding(14)
                    .background(Theme.card)
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                }
            }
        }
    }
}
