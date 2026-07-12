import SwiftUI

/// The heart of the app: a real plan, real people, a temporary chat, and a
/// completion that counts.
struct ActivityDetailView: View {
    @Environment(AppStore.self) private var store
    let activity: Activity

    @State private var draftMessage = ""

    private var live: Activity { store.liveActivity(activity) }
    private var messages: [ChatMessage] { store.chats[activity.id] ?? [] }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                heroCard
                detailsCard
                attendeesCard
                chatCard
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 24)
        }
        .scrollIndicators(.hidden)
        .background(Theme.background)
        .navigationTitle(live.title)
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .bottom) { bottomActions }
    }

    // MARK: Hero

    private var heroCard: some View {
        FlexCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    IconBadge(systemName: live.category.icon, size: 54)
                    Spacer()
                    TagPill(text: live.difficulty.label, tint: live.difficulty == .competitive ? Theme.amber : Theme.accent)
                }
                Text(live.title)
                    .font(.flexHeading())
                    .foregroundStyle(Theme.ink)
                Text(live.goal)
                    .font(.flexBody())
                    .foregroundStyle(Theme.inkSubtle)
            }
        }
    }

    // MARK: Details

    private var detailsCard: some View {
        FlexCard {
            VStack(alignment: .leading, spacing: 14) {
                detailRow(icon: "clock", text: live.date.formatted(.dateTime.weekday(.wide).day().month().hour().minute()))
                detailRow(icon: "mappin.and.ellipse", text: "\(live.locationName) · \(live.distanceKm.formatted(.number.precision(.fractionLength(1)))) km away")
                detailRow(icon: "person.crop.circle", text: "Hosted by \(live.host)")
                detailRow(icon: "checkmark.shield", text: "Completion verified by the group")
            }
        }
    }

    private func detailRow(icon: String, text: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Theme.accent)
                .frame(width: 24)
            Text(text)
                .font(.flexBody())
                .foregroundStyle(Theme.ink)
        }
    }

    // MARK: Attendees

    private var attendeesCard: some View {
        FlexCard {
            VStack(alignment: .leading, spacing: 10) {
                SectionHeader(title: "Who's going")
                HStack {
                    AvatarStack(names: live.attendees, size: 34, maxShown: 6)
                    Spacer()
                    Text("\(live.attendees.count) going")
                        .font(.flexCaption())
                        .foregroundStyle(Theme.inkSubtle)
                }
                if !live.friendsGoing.isEmpty {
                    Text("Friends: \(live.friendsGoing.joined(separator: ", "))")
                        .font(.flexCaption())
                        .foregroundStyle(Theme.accent)
                }
            }
        }
    }

    // MARK: Temporary group chat

    private var chatCard: some View {
        FlexCard {
            VStack(alignment: .leading, spacing: 12) {
                SectionHeader(title: "Group chat", subtitle: "Temporary — it disappears after the activity.")

                if live.isJoined {
                    if messages.isEmpty {
                        Text("No messages yet. Say hi, or coordinate a meeting spot.")
                            .font(.flexCaption())
                            .foregroundStyle(Theme.inkSubtle)
                    } else {
                        ForEach(messages) { message in
                            HStack(alignment: .top, spacing: 10) {
                                AvatarCircle(name: message.author, size: 26)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(message.author)
                                        .font(.flexCaption())
                                        .foregroundStyle(Theme.inkSubtle)
                                    Text(message.text)
                                        .font(.flexBody())
                                        .foregroundStyle(Theme.ink)
                                }
                            }
                        }
                    }

                    HStack(spacing: 8) {
                        TextField("Message", text: $draftMessage)
                            .font(.flexBody())
                            .padding(10)
                            .background(Theme.background)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        Button {
                            store.sendMessage(draftMessage, in: live)
                            draftMessage = ""
                        } label: {
                            Image(systemName: "arrow.up.circle.fill")
                                .font(.title2)
                                .foregroundStyle(Theme.accent)
                        }
                        .disabled(draftMessage.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                } else {
                    Label("Chat opens when you join", systemImage: "lock")
                        .font(.flexCaption())
                        .foregroundStyle(Theme.inkSubtle)
                }
            }
        }
    }

    // MARK: Actions

    private var bottomActions: some View {
        VStack(spacing: 10) {
            if live.isJoined, let commitment = store.commitment(for: live),
               commitment.status != .completed, live.date <= .now {
                Button("Mark completed") {
                    store.complete(commitment)
                }
                .buttonStyle(PrimaryButtonStyle())
            }

            Button(live.isJoined ? "Leave activity" : "Join activity") {
                store.toggleJoin(live)
            }
            .buttonStyle(live.isJoined
                ? SecondaryButtonStyle(tint: Theme.danger, background: Theme.danger.opacity(0.1))
                : SecondaryButtonStyle(tint: .white, background: Theme.accent))
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 8)
        .background(Theme.background.opacity(0.94))
    }
}
