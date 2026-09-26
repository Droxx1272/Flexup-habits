import SwiftUI
import UIKit
import UserNotifications

// MARK: - My profile (from the header)

struct MyProfileView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        Group {
            if FeatureFlags.community, let me = store.community.me, store.community.isSignedIn {
                MemberProfileView(userID: me.id)
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        HStack(spacing: 14) {
                            ProfileAvatar(name: store.profile?.name ?? store.account?.name ?? "", avatarId: nil, size: 64, ring: true)
                            VStack(alignment: .leading, spacing: 3) {
                                Text(store.profile?.name ?? store.account?.name ?? "You")
                                    .font(.system(size: 26, weight: .black))
                                    .foregroundStyle(Theme.ink)
                                Text("BECOMING \((store.profile?.identityStatement ?? "consistent").uppercased())")
                                    .font(.flexMono(9))
                                    .tracking(1.5)
                                    .foregroundStyle(Theme.accent)
                            }
                        }
                        if let email = store.account?.email {
                            Label(email, systemImage: store.account?.provider == .apple ? "apple.logo" : "envelope")
                                .font(.flexCaption())
                                .foregroundStyle(Theme.inkSubtle)
                        }

                        weekSummary

                        VStack(spacing: 0) {
                            NavigationLink(value: CommunityDestination.notificationSettings) {
                                HStack(spacing: 14) {
                                    Image(systemName: "bell.badge")
                                        .font(.system(size: 15, weight: .semibold))
                                        .foregroundStyle(Theme.accent)
                                        .frame(width: 22)
                                    Text("Notifications & reminders")
                                        .font(.flexBody())
                                        .foregroundStyle(Theme.ink)
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 11, weight: .bold))
                                        .foregroundStyle(Theme.inkSubtle)
                                }
                                .padding(14)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                        }
                        .background(Theme.card)
                        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))

                        if FeatureFlags.community {
                            CommunityGateView()
                        } else {
                            ComingSoonCommunity()
                        }
                    }
                    .padding(20)
                }
                .background(Theme.background)
                .navigationTitle("Profile")
                .navigationBarTitleDisplayMode(.inline)
            }
        }
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Done") { dismiss() }
            }
        }
        .task {
            if FeatureFlags.community && store.community.isSignedIn && store.community.me == nil {
                await store.community.refresh(day: store.todayKey)
            }
        }
    }

    /// Goals from onboarding and how this week is going against them.
    private var weekSummary: some View {
        let week = store.weekProgress
        let focuses = store.goals.focuses
        return FlexCard(padding: 16) {
            VStack(alignment: .leading, spacing: 12) {
                if !focuses.isEmpty {
                    Text("GOALS")
                        .font(.flexMono(10))
                        .tracking(2)
                        .foregroundStyle(Theme.inkSubtle)
                    Text(focuses.map(\.label).joined(separator: " · "))
                        .font(.flexBodyBold())
                        .foregroundStyle(Theme.ink)
                }
                HStack(spacing: 8) {
                    TrackStat(value: "\(week.wakeUps)/\(week.wakeDays)", label: "Wake-ups")
                    TrackStat(value: "\(week.runs)/\(store.goals.runsPerWeek)", label: "Runs")
                    TrackStat(value: "\(week.workouts)/\(store.goals.gymPerWeek)", label: "Sessions")
                }
                Text("THIS WEEK")
                    .font(.flexMono(8))
                    .tracking(1.5)
                    .foregroundStyle(Theme.inkSubtle)
            }
        }
    }
}

// MARK: - Profile

/// Anyone's profile: photo, name, handle, location, who they're becoming,
/// their goal, this month's proof, and their posts. Yours has Edit, a
/// camera badge on the photo, and your settings.
struct MemberProfileView: View {
    @Environment(AppStore.self) private var store
    let userID: String

    @State private var profile: CommunityProfile?
    @State private var posts: [Post] = []
    @State private var errorText: String?
    @State private var showEdit = false
    @State private var showSharing = false
    @State private var showPhotoOptions = false
    @State private var showCamera = false
    @State private var showLibrary = false
    @State private var isUploading = false
    @State private var confirmRemove = false
    @State private var confirmBlock = false
    @State private var reporting = false
    @State private var reported = false

    private var community: CommunityStore { store.community }
    private var isMe: Bool { userID == community.me?.id }

    /// Your own profile reads live from the store so edits show at once.
    private var user: CommunityUser? {
        if isMe, let me = community.me { return me.asUser }
        return profile?.user
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                if let user {
                    header(user)
                    statsRow
                    actions(user)
                    if isMe { myLinks }
                    postsSection
                } else if let errorText {
                    EmptyStateCard(icon: "person.crop.circle.badge.exclamationmark", title: "Profile unavailable", message: errorText)
                } else {
                    ProgressView().padding(.vertical, 60)
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 30)
        }
        .background(Theme.background)
        .navigationTitle("Profile")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                if isMe {
                    Button("Edit") { showEdit = true }
                        .fontWeight(.semibold)
                } else if profile?.relationship == "friend" {
                    Menu {
                        Button("Remove from crew", systemImage: "person.badge.minus") { confirmRemove = true }
                        Button("Report", systemImage: "flag") { reporting = true }
                        Button("Block", systemImage: "hand.raised", role: .destructive) { confirmBlock = true }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
        }
        .refreshable { await load() }
        .task { await load() }
        .sheet(isPresented: $showEdit) {
            EditProfileSheet()
        }
        .sheet(isPresented: $showSharing) {
            SharingSheet()
        }
        .confirmationDialog("Profile photo", isPresented: $showPhotoOptions) {
            if UIImagePickerController.isSourceTypeAvailable(.camera) {
                Button("Take photo") { showCamera = true }
            }
            Button("Choose from library") { showLibrary = true }
            if community.me?.avatarId != nil {
                Button("Remove photo", role: .destructive) {
                    Task { try? await community.updateProfile(["avatar_id": NSNull()]) }
                }
            }
        }
        .fullScreenCover(isPresented: $showCamera) {
            CameraPicker { image in upload(image) }
                .ignoresSafeArea()
        }
        .sheet(isPresented: $showLibrary) {
            LibraryPicker { image in upload(image) }
        }
        .confirmationDialog("Remove \(user?.name ?? "them") from your crew?", isPresented: $confirmRemove, titleVisibility: .visible) {
            Button("Remove", role: .destructive) {
                if let user { Task { await community.remove(user, day: store.todayKey); await load() } }
            }
        } message: {
            Text("You'll stop seeing each other's activity. They won't be told.")
        }
        .confirmationDialog("Block \(user?.name ?? "them")?", isPresented: $confirmBlock, titleVisibility: .visible) {
            Button("Block", role: .destructive) {
                if let user { Task { await community.block(user, day: store.todayKey); await load() } }
            }
        } message: {
            Text("They can't see your profile, posts or activity, message you, or add you again. They won't be told.")
        }
        .confirmationDialog("Why are you reporting \(user?.name ?? "them")?", isPresented: $reporting, titleVisibility: .visible) {
            ForEach(ReportReason.allCases) { reason in
                Button(reason.label) {
                    Task {
                        try? await community.report(type: "user", id: userID, reason: reason)
                        reported = true
                    }
                }
            }
            Button("Cancel", role: .cancel) {}
        }
        .alert("Thanks for telling us", isPresented: $reported) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("We review every report within 24 hours.")
        }
    }

    // MARK: Header

    private func header(_ user: CommunityUser) -> some View {
        VStack(spacing: 10) {
            ZStack(alignment: .bottomTrailing) {
                ProfileAvatar(user: user, size: 150, ring: true)
                    .overlay {
                        if isUploading {
                            ProgressView()
                                .padding(20)
                                .background(.thinMaterial)
                                .clipShape(Circle())
                        }
                    }
                if isMe {
                    Button {
                        showPhotoOptions = true
                    } label: {
                        Image(systemName: "camera.fill")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(Theme.background)
                            .frame(width: 44, height: 44)
                            .background(Theme.ink)
                            .clipShape(Circle())
                            .overlay(Circle().stroke(Theme.background, lineWidth: 4))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Change profile photo")
                    .offset(x: -4, y: -4)
                }
            }
            .padding(.top, 10)

            Text(user.name)
                .font(.system(size: 30, weight: .black))
                .foregroundStyle(Theme.ink)
                .multilineTextAlignment(.center)
            Text("@\(user.handle)")
                .font(.flexBody())
                .foregroundStyle(Theme.inkSubtle)

            if let location = user.location, !location.isEmpty {
                Label(location, systemImage: "location.fill")
                    .font(.flexBody())
                    .foregroundStyle(Theme.ink)
                    .padding(.top, 4)
            }

            if let identity = user.identity, !identity.isEmpty {
                Text("BECOMING \(identity.uppercased())")
                    .font(.flexMono(10))
                    .tracking(1.5)
                    .foregroundStyle(Theme.accent)
                    .multilineTextAlignment(.center)
                    .padding(.top, 4)
            }

            let goal = isMe ? (community.me?.goal ?? "") : (profile?.goal ?? "")
            if !goal.isEmpty {
                Label(goal, systemImage: "target")
                    .font(.flexCaption())
                    .foregroundStyle(Theme.ink)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .background(Theme.accentSoft)
                    .clipShape(Capsule())
            }

            let bio = isMe ? (community.me?.bio ?? "") : (profile?.bio ?? "")
            if !bio.isEmpty {
                Text(bio)
                    .font(.flexBody())
                    .foregroundStyle(Theme.inkSubtle)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 10)
            }
        }
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    private var statsRow: some View {
        if let profile, profile.relationship == "self" || profile.relationship == "friend" {
            VStack(spacing: 8) {
                HStack(spacing: 8) {
                    TrackStat(value: profile.wakeStreak.map { "\($0)" } ?? "—", label: "Wake streak")
                    TrackStat(value: "\(profile.month["run"] ?? 0)", label: "Runs")
                    TrackStat(value: "\(profile.month["workout"] ?? 0)", label: "Sessions")
                }
                Text("THIS MONTH · SHARED ACTIVITY")
                    .font(.flexMono(8))
                    .tracking(1.5)
                    .foregroundStyle(Theme.inkSubtle)
            }
        }
    }

    // MARK: Actions

    @ViewBuilder
    private func actions(_ user: CommunityUser) -> some View {
        switch profile?.relationship ?? "" {
        case "friend":
            HStack(spacing: 10) {
                NavigationLink(value: CommunityDestination.chat(user)) {
                    Label("Message", systemImage: "bubble.left.fill")
                }
                .buttonStyle(PrimaryButtonStyle())
                if let friend = community.friends.first(where: { $0.id == user.id }) {
                    Menu {
                        ForEach(NudgeKind.allCases) { kind in
                            Button(kind.message) {
                                Task { await community.nudge(friend, kind: kind, day: store.todayKey) }
                            }
                        }
                    } label: {
                        Label(friend.nudgedToday ? "Nudged" : "Nudge", systemImage: "hand.wave")
                            .font(.flexBodyBold())
                            .foregroundStyle(Theme.accent)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(Theme.accentSoft)
                            .clipShape(Capsule())
                    }
                    .disabled(friend.nudgedToday)
                }
            }
        case "incoming":
            VStack(spacing: 10) {
                Text("\(user.name) wants to be accountability partners.")
                    .font(.flexCaption())
                    .foregroundStyle(Theme.inkSubtle)
                Button("Accept") {
                    Task { await community.respond(to: user, accept: true, day: store.todayKey); await load() }
                }
                .buttonStyle(PrimaryButtonStyle())
                Button("Decline") {
                    Task { await community.respond(to: user, accept: false, day: store.todayKey); await load() }
                }
                .buttonStyle(SecondaryButtonStyle())
            }
        case "outgoing":
            Text("REQUEST SENT — WAITING ON \(user.name.uppercased())")
                .font(.flexMono(10))
                .tracking(1)
                .foregroundStyle(Theme.inkSubtle)
        default:
            EmptyView()
        }
    }

    private var myLinks: some View {
        VStack(spacing: 0) {
            linkRow(.crew, icon: "person.2", title: "Your crew", badge: community.badges.requests)
            Divider().padding(.leading, 50)
            Button {
                showSharing = true
            } label: {
                rowLabel(icon: "eye", title: "What your friends see", badge: 0)
            }
            .buttonStyle(.plain)
            Divider().padding(.leading, 50)
            linkRow(.notificationSettings, icon: "bell.badge", title: "Notifications", badge: 0)
            Divider().padding(.leading, 50)
            linkRow(.blocked, icon: "hand.raised", title: "Blocked people", badge: 0)
        }
        .background(Theme.card)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private func linkRow(_ destination: CommunityDestination, icon: String, title: String, badge: Int) -> some View {
        NavigationLink(value: destination) {
            rowLabel(icon: icon, title: title, badge: badge)
        }
        .buttonStyle(.plain)
    }

    private func rowLabel(icon: String, title: String, badge: Int) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Theme.accent)
                .frame(width: 22)
            Text(title)
                .font(.flexBody())
                .foregroundStyle(Theme.ink)
            Spacer()
            if badge > 0 {
                Text("\(badge)")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .frame(minWidth: 20, minHeight: 20)
                    .background(Theme.danger)
                    .clipShape(Capsule())
            }
            Image(systemName: "chevron.right")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(Theme.inkSubtle)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 14)
        .contentShape(Rectangle())
    }

    // MARK: Posts

    @ViewBuilder
    private var postsSection: some View {
        if profile?.relationship == "self" || profile?.relationship == "friend" {
            VStack(alignment: .leading, spacing: 12) {
                SectionHeader(title: "Posts")
                if posts.isEmpty {
                    Text(isMe ? "Nothing posted yet. Share your next win from the Community tab." : "No posts yet.")
                        .font(.flexCaption())
                        .foregroundStyle(Theme.inkSubtle)
                } else {
                    ForEach(posts) { post in
                        PostCard(post: post) {
                            Task {
                                let updated = await community.toggleKudos(post)
                                if let index = posts.firstIndex(where: { $0.id == post.id }) { posts[index] = updated }
                            }
                        }
                    }
                }
            }
        }
    }

    // MARK: Loading

    @MainActor
    private func load() async {
        do {
            profile = try await community.profile(of: userID)
            errorText = nil
            if profile?.relationship == "self" || profile?.relationship == "friend" {
                posts = try await community.posts(of: userID)
            } else {
                posts = []
            }
        } catch {
            errorText = error.localizedDescription
        }
    }

    private func upload(_ image: UIImage) {
        Task { @MainActor in
            isUploading = true
            defer { isUploading = false }
            do {
                try await community.setAvatar(image)
            } catch {
                errorText = error.localizedDescription
            }
        }
    }
}

// MARK: - Edit profile

struct EditProfileSheet: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var handle = ""
    @State private var location = ""
    @State private var goal = ""
    @State private var identity = ""
    @State private var bio = ""
    @State private var isSaving = false
    @State private var errorText: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    field("NAME") { TextField("Name", text: $name).textContentType(.name) }
                    field("HANDLE") {
                        HStack(spacing: 2) {
                            Text("@").foregroundStyle(Theme.inkSubtle)
                            TextField("handle", text: $handle)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                        }
                    }
                    field("LOCATION") {
                        TextField("City", text: $location).textContentType(.addressCity)
                    }
                    field("CURRENT GOAL") {
                        TextField("e.g. Run a sub-50 10K", text: $goal)
                    }
                    field("BECOMING") {
                        TextField("an early riser", text: $identity)
                    }
                    field("BIO") {
                        TextField("A line about you", text: $bio, axis: .vertical)
                            .lineLimit(2...4)
                    }

                    if let errorText {
                        Text(errorText)
                            .font(.flexCaption())
                            .foregroundStyle(Theme.danger)
                    }
                }
                .padding(20)
            }
            .background(Theme.background)
            .navigationTitle("Edit profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        Task { await save() }
                    } label: {
                        if isSaving { ProgressView() } else { Text("Save").fontWeight(.semibold) }
                    }
                    .disabled(isSaving || name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .onAppear {
                guard let me = store.community.me else { return }
                name = me.name
                handle = me.handle
                location = me.location
                goal = me.goal
                identity = me.identity
                bio = me.bio
            }
        }
    }

    private func field<Content: View>(_ label: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.flexMono(9))
                .tracking(1.5)
                .foregroundStyle(Theme.inkSubtle)
            content()
                .font(.flexBodyBold())
                .padding(14)
                .background(Theme.card)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
    }

    @MainActor
    private func save() async {
        isSaving = true
        errorText = nil
        defer { isSaving = false }
        let trim = { (value: String) in value.trimmingCharacters(in: .whitespacesAndNewlines) }
        do {
            try await store.community.updateProfile([
                "name": trim(name),
                "handle": trim(handle),
                "location": trim(location),
                "goal": trim(goal),
                "identity": trim(identity),
                "bio": trim(bio),
            ])
            dismiss()
        } catch {
            errorText = error.localizedDescription
        }
    }
}

// MARK: - Notification settings

/// What reaches you: your crew (in the bell) and FlexUp's own reminders.
struct NotificationSettingsView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.openURL) private var openURL

    @State private var prefs = NotifyPrefs()
    @State private var permission: UNAuthorizationStatus = .notDetermined
    @State private var errorText: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                if FeatureFlags.community && store.community.isSignedIn {
                    group("From your crew", note: "Shown in the bell. Lock-screen alerts for these arrive with push notifications in a later update.") {
                        toggle("Friend requests", icon: "person.badge.plus", isOn: $prefs.friends)
                        toggle("Nudges", icon: "hand.wave", isOn: $prefs.nudges)
                        toggle("Cheers & kudos", icon: "hand.thumbsup", isOn: $prefs.cheers)
                        toggle("Comments", icon: "text.bubble", isOn: $prefs.comments)
                    }
                    .onChange(of: prefs) { _, newValue in
                        guard newValue != store.community.me?.notifyPrefs else { return }
                        Task {
                            do {
                                try await store.community.updateNotifyPrefs(newValue)
                                errorText = nil
                            } catch {
                                errorText = error.localizedDescription
                            }
                        }
                    }
                }

                group("Reminders", note: "These ring on this phone even when you're offline.") {
                    toggle("Wake alarm", icon: "alarm", isOn: Binding(
                        get: { store.wake.enabled },
                        set: { store.setWakeAlarm($0) }
                    ))
                    toggle("Bedtime reminder", icon: "moon.zzz", isOn: Binding(
                        get: { store.bedtime.enabled },
                        set: { store.setBedtimeReminder($0) }
                    ))
                    toggle("Habit reminders", icon: "checklist", isOn: Binding(
                        get: { store.reminders.habitReminders },
                        set: { value in
                            var updated = store.reminders
                            updated.habitReminders = value
                            store.updateReminders(updated)
                        }
                    ))
                }

                if permission == .denied {
                    FlexCard(padding: 14) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Notifications are off for FlexUp in iOS Settings, so reminders can't ring.")
                                .font(.flexCaption())
                                .foregroundStyle(Theme.ink)
                            Button("Open Settings") {
                                if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
                            }
                            .font(.flexCaption())
                            .foregroundStyle(Theme.accent)
                        }
                    }
                }

                if let errorText {
                    Text(errorText)
                        .font(.flexCaption())
                        .foregroundStyle(Theme.danger)
                }
            }
            .padding(20)
        }
        .background(Theme.background)
        .navigationTitle("Notifications")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            if let me = store.community.me { prefs = me.notifyPrefs }
            permission = await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
        }
    }

    private func group<Content: View>(_ title: String, note: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionHeader(title: title, subtitle: note)
            VStack(spacing: 0) {
                content()
            }
            .background(Theme.card)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
    }

    private func toggle(_ title: String, icon: String, isOn: Binding<Bool>) -> some View {
        Toggle(isOn: isOn) {
            Label(title, systemImage: icon)
                .font(.flexBody())
                .foregroundStyle(Theme.ink)
        }
        .tint(Theme.accent)
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}

// MARK: - Blocked people

struct BlockedUsersView: View {
    @Environment(AppStore.self) private var store
    @State private var users: [CommunityUser] = []
    @State private var loaded = false
    @State private var errorText: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                Text("Blocked people can't see your profile, posts or activity, message you, or add you. They aren't told.")
                    .font(.flexCaption())
                    .foregroundStyle(Theme.inkSubtle)
                if loaded && users.isEmpty {
                    Text("No one is blocked.")
                        .font(.flexBody())
                        .foregroundStyle(Theme.inkSubtle)
                        .padding(.top, 10)
                }
                ForEach(users) { user in
                    HStack(spacing: 12) {
                        ProfileAvatar(user: user, size: 40)
                        Text(user.name)
                            .font(.flexBodyBold())
                            .foregroundStyle(Theme.ink)
                        Spacer()
                        Button("Unblock") {
                            Task {
                                do {
                                    try await store.community.unblock(user)
                                    users.removeAll { $0.id == user.id }
                                } catch {
                                    errorText = error.localizedDescription
                                }
                            }
                        }
                        .font(.flexCaption())
                        .foregroundStyle(Theme.accent)
                    }
                    .padding(12)
                    .background(Theme.card)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
                if let errorText {
                    Text(errorText)
                        .font(.flexCaption())
                        .foregroundStyle(Theme.danger)
                }
            }
            .padding(20)
        }
        .background(Theme.background)
        .navigationTitle("Blocked people")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            do {
                users = try await store.community.blockedUsers()
            } catch {
                errorText = error.localizedDescription
            }
            loaded = true
        }
    }
}
