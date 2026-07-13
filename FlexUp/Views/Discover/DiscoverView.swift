import SwiftUI

/// Location-aware discovery. v1 filters local fixtures by category,
/// difficulty and friends; the same UI later fronts a real geo backend.
struct DiscoverView: View {
    @Environment(AppStore.self) private var store

    @State private var category: ActivityCategory?
    @State private var difficulty: Difficulty?
    @State private var friendsOnly = false

    private var filtered: [Activity] {
        store.activities
            .filter { $0.date > .now }
            .filter { category == nil || $0.category == category }
            .filter { difficulty == nil || $0.difficulty == difficulty }
            .filter { !friendsOnly || !$0.friendsGoing.isEmpty }
            .sorted { $0.distanceKm < $1.distanceKm }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    ScreenHeader(title: "Discover", tagline: "Find your next move nearby.")
                    categoryChips
                    refinementChips

                    if filtered.isEmpty {
                        EmptyStateCard(
                            icon: "binoculars",
                            title: "Nothing here yet",
                            message: "Loosen the filters, or be the one who starts something."
                        )
                        .padding(.top, 20)
                    } else {
                        ForEach(filtered) { activity in
                            NavigationLink(value: activity) {
                                ActivityCard(activity: activity)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 24)
            }
            .scrollIndicators(.hidden)
            .background(Theme.background)
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(for: Activity.self) { activity in
                ActivityDetailView(activity: activity)
            }
        }
    }

    private var categoryChips: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 8) {
                SelectableChip(label: "All", isSelected: category == nil) {
                    category = nil
                }
                ForEach(ActivityCategory.allCases) { item in
                    SelectableChip(label: item.label, icon: item.icon, isSelected: category == item) {
                        category = category == item ? nil : item
                    }
                }
            }
        }
        .scrollIndicators(.hidden)
    }

    private var refinementChips: some View {
        HStack(spacing: 8) {
            ForEach(Difficulty.allCases) { level in
                SelectableChip(label: level.label, isSelected: difficulty == level) {
                    difficulty = difficulty == level ? nil : level
                }
            }
            SelectableChip(label: "Friends", icon: "person.2.fill", isSelected: friendsOnly) {
                friendsOnly.toggle()
            }
        }
    }
}

// MARK: - Activity card

struct ActivityCard: View {
    let activity: Activity

    var body: some View {
        FlexCard(padding: 16) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top, spacing: 12) {
                    IconBadge(systemName: activity.category.icon, size: 44)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(activity.title)
                            .font(.flexBodyBold())
                            .foregroundStyle(Theme.ink)
                        Text(activity.date.formatted(.dateTime.weekday(.wide).hour().minute()))
                            .font(.flexCaption())
                            .foregroundStyle(Theme.inkSubtle)
                        Text("\(activity.locationName) · \(activity.distanceKm.formatted(.number.precision(.fractionLength(1)))) km away")
                            .font(.flexCaption())
                            .foregroundStyle(Theme.inkSubtle)
                    }
                    Spacer()
                    TagPill(text: activity.difficulty.label, tint: activity.difficulty == .competitive ? Theme.amber : Theme.accent)
                }
                HStack {
                    AvatarStack(names: activity.attendees)
                    Text("\(activity.attendees.count) going")
                        .font(.flexCaption())
                        .foregroundStyle(Theme.inkSubtle)
                    Spacer()
                    if activity.isJoined {
                        Label("You're in", systemImage: "checkmark.circle.fill")
                            .font(.flexCaption())
                            .foregroundStyle(Theme.accent)
                    } else {
                        Text("View")
                            .font(.flexCaption())
                            .foregroundStyle(Theme.accent)
                    }
                }
            }
        }
    }
}

#Preview {
    DiscoverView()
        .environment(AppStore())
}
