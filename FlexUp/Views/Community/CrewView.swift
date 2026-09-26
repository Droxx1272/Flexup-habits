import SwiftUI

/// "Your crew": your friend code and invite, requests, everyone you're
/// accountable with and whether they've shown up today, nudges, and what
/// you share. Friends-only by design — no strangers, no follower counts.
/// Pushed from your profile or the bell.
struct CrewView: View {
    @Environment(AppStore.self) private var store

    var body: some View {
        ScrollView {
            CrewContent()
                .padding(.horizontal, 20)
                .padding(.bottom, 30)
        }
        .background(Theme.background)
        .navigationTitle("Your crew")
        .navigationBarTitleDisplayMode(.inline)
        .refreshable { await store.community.refresh(day: store.todayKey) }
    }
}

struct CrewContent: View {
    @Environment(AppStore.self) private var store
    @State private var showAddFriend = false
    @State private var showSharing = false
    @State private var showProfile = false
    @State private var friendToRemove: FriendStatus?

    private var community: CommunityStore { store.community }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            if !community.isAvailable || !community.isSignedIn {
                CommunityGateView()
            } else {
                if let errorMessage = community.errorMessage {
                    CommunityErrorBanner(message: errorMessage)
                }
                NudgesCard()
                inviteCard
                requestsCard
                crewCard
                sharingRow
            }
        }
        .sheet(isPresented: $showAddFriend) {
            AddFriendSheet()
        }
        .sheet(isPresented: $showSharing) {
            SharingSheet()
        }
        .sheet(isPresented: $showProfile) {
            EditProfileSheet()
        }
        .confirmationDialog(
            "Remove \(friendToRemove?.user.name ?? "friend")?",
            isPresented: Binding(get: { friendToRemove != nil }, set: { if !$0 { friendToRemove = nil } }),
            titleVisibility: .visible
        ) {
            Button("Remove friend", role: .destructive) {
                if let friend = friendToRemove {
                    Task { await community.remove(friend.user, day: store.todayKey) }
                }
                friendToRemove = nil
            }
            Button("Cancel", role: .cancel) { friendToRemove = nil }
        } message: {
            Text("You'll stop seeing each other's activity. They won't be told.")
        }
        .task(id: community.isSignedIn) {
            if community.isSignedIn { await community.refresh(day: store.todayKey) }
        }
    }

    // MARK: Invite

    private var inviteMessage: String {
        guard let me = community.me else { return "Join me on FlexUp." }
        return "Keep me accountable on FlexUp 💪 Add me with my friend code \(me.friendCode) (or @\(me.handle))."
    }

    private var inviteCard: some View {
        FlexCard {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("YOUR FRIEND CODE")
                            .font(.flexMono(10))
                            .tracking(2)
                            .foregroundStyle(Theme.inkSubtle)
                        Text(community.me?.friendCode ?? "······")
                            .font(.flexStat(34))
                            .tracking(4)
                            .foregroundStyle(Theme.ink)
                            .textSelection(.enabled)
                    }
                    Spacer()
                    Button {
                        showProfile = true
                    } label: {
                        VStack(alignment: .trailing, spacing: 2) {
                            Text("@\(community.me?.handle ?? "")")
                                .font(.flexBodyBold())
                                .foregroundStyle(Theme.ink)
                            Text("EDIT PROFILE")
                                .font(.flexMono(9))
                                .tracking(1)
                                .foregroundStyle(Theme.accent)
                        }
                    }
                    .buttonStyle(.plain)
                }

                ShareLink(item: inviteMessage) {
                    Label("Invite a friend", systemImage: "square.and.arrow.up")
                }
                .buttonStyle(PrimaryButtonStyle())

                Button {
                    showAddFriend = true
                } label: {
                    Label("Add by code or @handle", systemImage: "person.badge.plus")
                }
                .buttonStyle(SecondaryButtonStyle())
            }
        }
    }

    // MARK: Requests

    @ViewBuilder
    private var requestsCard: some View {
        if !community.incoming.isEmpty || !community.outgoing.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                SectionHeader(title: "Requests")
                ForEach(community.incoming) { user in
                    HStack(spacing: 12) {
                        ProfileAvatar(user: user, size: 38)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(user.name)
                                .font(.flexBodyBold())
                                .foregroundStyle(Theme.ink)
                            Text("@\(user.handle) WANTS TO BE ACCOUNTABLE WITH YOU")
                                .font(.flexMono(8))
                                .tracking(1)
                                .foregroundStyle(Theme.inkSubtle)
                                .lineLimit(1)
                        }
                        Spacer()
                        Button {
                            Task { await community.respond(to: user, accept: false, day: store.todayKey) }
                        } label: {
                            Image(systemName: "xmark")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundStyle(Theme.inkSubtle)
                                .frame(width: 34, height: 34)
                                .background(Theme.background)
                                .clipShape(Circle())
                        }
                        .buttonStyle(.plain)
                        Button {
                            Task { await community.respond(to: user, accept: true, day: store.todayKey) }
                        } label: {
                            Text("Accept")
                                .font(.flexCaption())
                                .foregroundStyle(Theme.background)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 9)
                                .background(Theme.ink)
                                .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(12)
                    .background(Theme.card)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
                ForEach(community.outgoing) { user in
                    HStack(spacing: 12) {
                        ProfileAvatar(user: user, size: 30)
                        Text("Waiting on \(user.name)")
                            .font(.flexCaption())
                            .foregroundStyle(Theme.inkSubtle)
                        Spacer()
                        Button("Cancel") {
                            Task { await community.remove(user, day: store.todayKey) }
                        }
                        .font(.flexCaption())
                        .foregroundStyle(Theme.inkSubtle)
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                }
            }
        }
    }

    // MARK: Crew

    private var crewCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader(
                title: "Your crew today",
                subtitle: community.friends.isEmpty ? nil : "Nudge anyone who's quiet. Long-press to remove."
            )
            if community.friends.isEmpty {
                if community.hasLoaded {
                    EmptyStateCard(
                        icon: "person.2",
                        title: "Just you, for now",
                        message: "Two or three friends is plenty. Send your code to the people you'd hate to let down."
                    )
                } else {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 20)
                }
            } else {
                ForEach(community.friends) { friend in
                    NavigationLink(value: CommunityDestination.profile(friend.user.id)) {
                        friendRow(friend)
                    }
                    .buttonStyle(.plain)
                        .contextMenu {
                            Button(role: .destructive) {
                                friendToRemove = friend
                            } label: {
                                Label("Remove friend", systemImage: "person.badge.minus")
                            }
                        }
                }
            }
        }
    }

    private func friendRow(_ friend: FriendStatus) -> some View {
        let kinds = friend.todayKinds
        return HStack(spacing: 12) {
            ProfileAvatar(user: friend.user, size: 44, ring: !friend.todayKinds.isEmpty)
            VStack(alignment: .leading, spacing: 4) {
                Text(friend.user.name)
                    .font(.flexBodyBold())
                    .foregroundStyle(Theme.ink)
                if kinds.isEmpty {
                    Text(quietLine(friend))
                        .font(.flexMono(9))
                        .tracking(1)
                        .foregroundStyle(Theme.inkSubtle)
                } else {
                    HStack(spacing: 6) {
                        ForEach(kinds) { kind in
                            Image(systemName: kind.icon)
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(Theme.accent)
                        }
                        Text("SHOWED UP TODAY")
                            .font(.flexMono(9))
                            .tracking(1)
                            .foregroundStyle(Theme.accent)
                    }
                }
                if let streak = friend.wakeStreak, streak > 1 {
                    Text("\(streak)-DAY WAKE STREAK")
                        .font(.flexMono(8))
                        .tracking(1)
                        .foregroundStyle(Theme.inkSubtle)
                }
            }
            Spacer()
            nudgeButton(friend)
        }
        .padding(14)
        .background(Theme.card)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private func quietLine(_ friend: FriendStatus) -> String {
        guard let last = friend.lastActiveAt else { return "NOTHING SHARED YET" }
        return "QUIET TODAY · LAST SEEN \(last.formatted(.relative(presentation: .named)).uppercased())"
    }

    @ViewBuilder
    private func nudgeButton(_ friend: FriendStatus) -> some View {
        if friend.nudgedToday {
            Label("Nudged", systemImage: "checkmark")
                .font(.flexCaption())
                .foregroundStyle(Theme.inkSubtle)
        } else {
            Menu {
                ForEach(NudgeKind.allCases) { kind in
                    Button(kind.message) {
                        Task { await community.nudge(friend, kind: kind, day: store.todayKey) }
                    }
                }
            } label: {
                Text("Nudge")
                    .font(.flexCaption())
                    .foregroundStyle(Theme.accent)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 9)
                    .background(Theme.accentSoft)
                    .clipShape(Capsule())
            }
        }
    }

    // MARK: Sharing

    private var sharingRow: some View {
        Button {
            showSharing = true
        } label: {
            HStack {
                Image(systemName: "eye")
                    .foregroundStyle(Theme.accent)
                Text("What your friends see")
                    .font(.flexBody())
                    .foregroundStyle(Theme.ink)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(Theme.inkSubtle)
            }
            .padding(14)
            .background(Theme.card)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Feed row

struct FeedEventRow: View {
    let event: FeedEvent
    var onCheer: (String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 12) {
                ZStack(alignment: .bottomTrailing) {
                    ProfileAvatar(user: event.user, size: 38)
                    if let kind = event.activityKind {
                        Image(systemName: kind.icon)
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(width: 18, height: 18)
                            .background(Theme.accent)
                            .clipShape(Circle())
                            .offset(x: 4, y: 4)
                    }
                }
                VStack(alignment: .leading, spacing: 3) {
                    Text("\((event.isMine ? "You" : event.user.name).uppercased()) · \(event.occurredAt.formatted(.relative(presentation: .named)).uppercased())")
                        .font(.flexMono(9))
                        .tracking(1)
                        .foregroundStyle(Theme.inkSubtle)
                    Text(event.title)
                        .font(.flexBodyBold())
                        .foregroundStyle(Theme.ink)
                    if !event.detail.isEmpty {
                        Text(event.detail)
                            .font(.flexCaption())
                            .foregroundStyle(Theme.inkSubtle)
                    }
                }
                Spacer(minLength: 0)
            }

            if !event.cheers.isEmpty {
                Text(event.cheers.map { "\($0.emoji) \($0.name)" }.joined(separator: "  "))
                    .font(.flexCaption())
                    .foregroundStyle(Theme.inkSubtle)
            }

            if !event.isMine {
                HStack(spacing: 8) {
                    ForEach(CommunityCheer.all, id: \.self) { emoji in
                        Button {
                            onCheer(emoji)
                        } label: {
                            Text(emoji)
                                .font(.system(size: 17))
                                .frame(width: 42, height: 34)
                                .background(event.myCheer == emoji ? Theme.accentSoft : Theme.background)
                                .clipShape(Capsule())
                                .overlay(
                                    Capsule().stroke(event.myCheer == emoji ? Theme.accent : .clear, lineWidth: 1.5)
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .padding(14)
        .background(Theme.card)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

// MARK: - Add friend

struct AddFriendSheet: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var query = ""
    @State private var isWorking = false
    @State private var result: String?
    @State private var errorText: String?

    private var canSend: Bool { query.trimmingCharacters(in: .whitespaces).count >= 3 && !isWorking }

    var body: some View {
        VStack(spacing: 16) {
            Capsule()
                .fill(Theme.inkSubtle.opacity(0.3))
                .frame(width: 36, height: 5)
                .padding(.top, 10)

            Text("ADD A FRIEND")
                .font(.flexMono(12))
                .tracking(2)
                .foregroundStyle(Theme.ink)

            Text("Enter their 6-character friend code or @handle. They'll get a request to accept.")
                .font(.flexCaption())
                .foregroundStyle(Theme.inkSubtle)
                .multilineTextAlignment(.center)

            TextField("7KQ3XM or @handle", text: $query)
                .font(.flexStat(24))
                .multilineTextAlignment(.center)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .padding(16)
                .background(Theme.card)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .onSubmit { Task { await send() } }

            if let result {
                Text(result)
                    .font(.flexCaption())
                    .foregroundStyle(Theme.accent)
                    .multilineTextAlignment(.center)
            }
            if let errorText {
                Text(errorText)
                    .font(.flexCaption())
                    .foregroundStyle(Theme.danger)
                    .multilineTextAlignment(.center)
            }

            Spacer()

            Button(result == nil ? "Send request" : "Done") {
                if result == nil {
                    Task { await send() }
                } else {
                    dismiss()
                }
            }
            .buttonStyle(PrimaryButtonStyle())
            .disabled(result == nil && !canSend)
            .opacity(result == nil && !canSend ? 0.4 : 1)
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 12)
        .background(Theme.background)
        .presentationDetents([.medium])
    }

    @MainActor
    private func send() async {
        guard canSend else { return }
        isWorking = true
        errorText = nil
        defer { isWorking = false }
        do {
            result = try await store.community.addFriend(query.trimmingCharacters(in: .whitespaces), day: store.todayKey)
        } catch {
            errorText = error.localizedDescription
        }
    }
}

// MARK: - Sharing settings

struct SharingSheet: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var settings = SharingSettings()

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Capsule()
                .fill(Theme.inkSubtle.opacity(0.3))
                .frame(width: 36, height: 5)
                .frame(maxWidth: .infinity)
                .padding(.top, 10)

            Text("WHAT YOUR FRIENDS SEE")
                .font(.flexMono(12))
                .tracking(2)
                .foregroundStyle(Theme.ink)
            Text("Only accepted friends ever see anything, and only from the moment you log it. Food, weight and photos are never shared.")
                .font(.flexCaption())
                .foregroundStyle(Theme.inkSubtle)

            VStack(spacing: 0) {
                toggle(.wake, isOn: $settings.wake)
                toggle(.run, isOn: $settings.run)
                toggle(.workout, isOn: $settings.workout)
                toggle(.habit, isOn: $settings.habit)
                toggle(.sleep, isOn: $settings.sleep)
            }
            .background(Theme.card)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))

            Spacer()

            Button("Save") {
                store.updateSharing(settings)
                dismiss()
            }
            .buttonStyle(PrimaryButtonStyle())
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 12)
        .background(Theme.background)
        .presentationDetents([.large])
        .onAppear { settings = store.sharing }
    }

    private func toggle(_ kind: ActivityKind, isOn: Binding<Bool>) -> some View {
        Toggle(isOn: isOn) {
            Label(kind.label, systemImage: kind.icon)
                .font(.flexBody())
                .foregroundStyle(Theme.ink)
        }
        .tint(Theme.accent)
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}

// MARK: - Shared pieces

struct CommunityErrorBanner: View {
    @Environment(AppStore.self) private var store
    let message: String

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "exclamationmark.circle")
                .foregroundStyle(Theme.amber)
            Text(message)
                .font(.flexCaption())
                .foregroundStyle(Theme.ink)
            Spacer()
            Button {
                store.community.errorMessage = nil
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(Theme.inkSubtle)
            }
            .buttonStyle(.plain)
        }
        .padding(12)
        .background(Theme.amberSoft)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

/// Nudges your crew sent you, until you tap "Got it".
struct NudgesCard: View {
    @Environment(AppStore.self) private var store

    var body: some View {
        let nudges = store.community.nudges
        if !nudges.isEmpty {
            FlexCard(padding: 16) {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text("YOUR CREW IS CALLING")
                            .font(.flexMono(11))
                            .tracking(2)
                            .foregroundStyle(Theme.accent)
                        Spacer()
                        Button("Got it") {
                            Task { await store.community.dismissNudges() }
                        }
                        .font(.flexCaption())
                        .foregroundStyle(Theme.accent)
                        .buttonStyle(.plain)
                    }
                    ForEach(nudges) { nudge in
                        HStack(spacing: 10) {
                            ProfileAvatar(user: nudge.from, size: 32)
                            VStack(alignment: .leading, spacing: 1) {
                                Text(nudge.message)
                                    .font(.flexBodyBold())
                                    .foregroundStyle(Theme.ink)
                                Text("\(nudge.from.name.uppercased()) · \(nudge.createdAt.formatted(.relative(presentation: .named)).uppercased())")
                                    .font(.flexMono(9))
                                    .tracking(1)
                                    .foregroundStyle(Theme.inkSubtle)
                            }
                        }
                    }
                }
            }
        }
    }
}
