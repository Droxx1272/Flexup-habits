import SwiftUI

/// The social dashboard. Two halves of one idea:
/// Feed — what your people are doing, with something to join or cheer.
/// Memories — proof of who you're becoming, worth keeping and sharing.
/// No follower counts, no infinite scroll; every card points at action.
struct SquadView: View {
    @Environment(AppStore.self) private var store

    enum Section: String, CaseIterable, Identifiable {
        case feed = "Feed"
        case memories = "Memories"
        var id: String { rawValue }
    }

    @State private var section: Section = .feed

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    ScreenHeader(title: "Squad", tagline: "People make plans stick.")
                    sectionToggle

                    switch section {
                    case .feed:
                        crewCard
                        ForEach(store.feedEvents) { event in
                            FeedCard(event: event)
                        }
                    case .memories:
                        memoriesSection
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

    // MARK: Section toggle

    private var sectionToggle: some View {
        HStack(spacing: 6) {
            ForEach(Section.allCases) { item in
                Button {
                    withAnimation(.spring(duration: 0.25)) { section = item }
                } label: {
                    Text(item.rawValue.uppercased())
                        .font(.flexMono(12))
                        .tracking(1.5)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 11)
                        .background(section == item ? Theme.ink : .clear)
                        .foregroundStyle(section == item ? Theme.background : Theme.inkSubtle)
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(4)
        .background(Theme.card)
        .clipShape(Capsule())
    }

    // MARK: Crew

    private var crewCard: some View {
        // Your completions plus a fixture crew count; the real number arrives
        // with the backend.
        let friendCompletions = 14
        let total = store.completedThisWeek + friendCompletions
        let goal = 25

        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("YOUR CREW")
                    .font(.flexMono(11))
                    .tracking(2)
                    .foregroundStyle(Theme.accent)
                Spacer()
                AvatarStack(names: [store.profile?.name ?? "You"] + store.friends.map(\.name), size: 26)
            }
            Text("\(total) things done this week, together.")
                .font(.flexHeading())
                .foregroundStyle(Theme.ink)
            ProgressView(value: Double(min(total, goal)), total: Double(goal))
                .tint(Theme.accent)
            Text(total >= goal
                 ? "Weekly goal hit. Celebrate it — then reset it."
                 : "\(goal - total) more to this week's crew goal of \(goal). Yours count double to you.")
                .font(.flexCaption())
                .foregroundStyle(Theme.inkSubtle)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.accentSoft)
        .clipShape(RoundedRectangle(cornerRadius: Theme.cornerRadius, style: .continuous))
    }

    // MARK: Memories

    private var memoriesSection: some View {
        let memories = store.memories
        return Group {
            if memories.isEmpty {
                EmptyStateCard(
                    icon: "sparkles.rectangle.stack",
                    title: "No memories yet",
                    message: "Do things worth remembering. Every completion, run, and achievement lands here."
                )
            } else {
                VStack(alignment: .leading, spacing: 12) {
                    SectionHeader(title: "Your moments", subtitle: "Earned, not posted. Share the ones that matter.")
                    ForEach(memories) { memory in
                        MemoryCard(memory: memory)
                    }
                }
            }
        }
    }
}

// MARK: - Feed card

struct FeedCard: View {
    @Environment(AppStore.self) private var store
    let event: SocialEvent

    private var linkedActivity: Activity? {
        guard let id = event.activityID else { return nil }
        return store.activities.first { $0.id == id }
    }

    var body: some View {
        FlexCard(padding: 16) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top, spacing: 12) {
                    AvatarCircle(name: event.author, size: 38)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(event.message)
                            .font(.flexBodyBold())
                            .foregroundStyle(Theme.ink)
                        if let detail = event.detail {
                            Text(detail)
                                .font(.flexCaption())
                                .foregroundStyle(Theme.inkSubtle)
                        }
                        Text(event.date.formatted(.relative(presentation: .named)).uppercased())
                            .font(.flexMono(9))
                            .tracking(1)
                            .foregroundStyle(Theme.inkSubtle)
                    }
                    Spacer()
                    Image(systemName: event.icon)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Theme.accent)
                }

                HStack(spacing: 10) {
                    if let activity = linkedActivity {
                        NavigationLink(value: activity) {
                            HStack(spacing: 6) {
                                Text(activity.isJoined ? "You're in" : "Join")
                                Image(systemName: "arrow.right")
                            }
                            .font(.flexMono(11))
                            .tracking(1)
                            .foregroundStyle(Theme.background)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 9)
                            .background(Theme.ink)
                            .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                    Spacer()
                    Button {
                        store.toggleCheer(event)
                    } label: {
                        HStack(spacing: 5) {
                            Image(systemName: event.cheeredByMe ? "hands.clap.fill" : "hands.clap")
                            Text("\(event.cheers)")
                                .monospacedDigit()
                        }
                        .font(.flexCaption())
                        .foregroundStyle(event.cheeredByMe ? Theme.accent : Theme.inkSubtle)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background((event.cheeredByMe ? Theme.accent : Theme.inkSubtle).opacity(0.12))
                        .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

// MARK: - Memory card

struct MemoryCard: View {
    let memory: Memory

    var body: some View {
        HStack(spacing: 14) {
            IconBadge(
                systemName: memory.icon,
                tint: memory.isHighlight ? Theme.amber : Theme.accent,
                size: 46
            )
            VStack(alignment: .leading, spacing: 3) {
                Text(memory.title)
                    .font(.flexBodyBold())
                    .foregroundStyle(Theme.ink)
                    .lineLimit(1)
                Text(memory.subtitle)
                    .font(.flexCaption())
                    .foregroundStyle(memory.isHighlight ? Theme.amber : Theme.inkSubtle)
                Text(memory.date.formatted(.dateTime.weekday(.abbreviated).day().month()).uppercased())
                    .font(.flexMono(9))
                    .tracking(1)
                    .foregroundStyle(Theme.inkSubtle)
            }
            Spacer()
            ShareLink(item: memory.shareText) {
                Image(systemName: "square.and.arrow.up")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Theme.inkSubtle)
                    .padding(10)
                    .background(Theme.ink.opacity(0.06))
                    .clipShape(Circle())
            }
        }
        .padding(14)
        .background(Theme.card)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(memory.isHighlight ? Theme.amber.opacity(0.4) : .clear, lineWidth: 1.5)
        )
    }
}

#Preview {
    SquadView()
        .environment(AppStore())
}
