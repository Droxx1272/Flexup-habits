import SwiftUI
import UIKit

/// Onboarding, one question per screen: progress bar and back arrow up top,
/// a single big question, one pill button at the bottom. Ends with the wake
/// pillar configured so day one starts tomorrow morning.
struct OnboardingView: View {
    @Environment(AppStore.self) private var store

    private enum Step: Int, CaseIterable {
        case welcome, name, identity, goals, interests, habits, targets, wake, notifications, profile
    }

    @State private var step: Step = .welcome
    @State private var name = ""
    @State private var identity = ""
    @State private var interests: Set<ActivityCategory> = []
    @State private var selectedTemplates: Set<HabitTemplate> = []
    @State private var wakeTime = Calendar.current.date(bySettingHour: 6, minute: 30, second: 0, of: .now) ?? .now
    @State private var wakeDays: Set<Int> = [2, 3, 4, 5, 6]
    @State private var wakeAlarm = true

    // Goals & preferences
    @State private var goalFocuses: Set<GoalFocus> = []
    @State private var runsPerWeek = 2
    @State private var gymPerWeek = 3
    @State private var dietDirection: DietDirection = .maintain
    @State private var currentWeight: Double?
    @State private var targetWeight: Double?
    @State private var habitReminders = true
    @State private var bedtimeReminder = true
    @State private var crewPrefs = NotifyPrefs()
    @State private var avatarImage: UIImage?
    @State private var location = ""
    @State private var showCamera = false
    @State private var showLibrary = false

    /// Identity archetypes — the person you're building toward, not a hobby
    /// tag. Picking one shapes the app's voice; "In My Words" opens a field.
    private struct IdentityOption: Identifiable, Hashable {
        var id: String { title }
        let icon: String
        let title: String
        let statement: String
        let detail: String
        var isCustom: Bool = false
    }

    private static let identityOptions: [IdentityOption] = [
        IdentityOption(icon: "sunrise.fill", title: "The Early Riser", statement: "an early riser", detail: "Up before the noise. Mornings owned."),
        IdentityOption(icon: "figure.run", title: "The Runner", statement: "a runner", detail: "Kilometres over excuses."),
        IdentityOption(icon: "dumbbell", title: "The Athlete", statement: "an athlete", detail: "Stronger every single week."),
        IdentityOption(icon: "target", title: "The Disciplined", statement: "someone who keeps every small promise", detail: "Small promises, always kept."),
        IdentityOption(icon: "arrow.uturn.up", title: "The Comeback", statement: "back on track", detail: "Falling off isn't failing. Staying off is."),
        IdentityOption(icon: "pencil.line", title: "In My Words", statement: "", detail: "Say it your way.", isCustom: true),
    ]

    @State private var selectedIdentity: IdentityOption?
    @State private var heroAppeared = false
    private let dayLetters = ["S", "M", "T", "W", "T", "F", "S"]
    private let interestColumns = [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)]

    private var suggestedTemplates: [HabitTemplate] {
        let matching = SampleData.habitTemplates.filter { interests.contains($0.category) }
        return Array((matching.isEmpty ? SampleData.habitTemplates : matching).prefix(6))
    }

    private var canContinue: Bool {
        switch step {
        case .welcome: true
        case .name: !name.trimmingCharacters(in: .whitespaces).isEmpty
        case .identity: true
        case .goals: !goalFocuses.isEmpty
        case .interests: !interests.isEmpty
        case .habits: !selectedTemplates.isEmpty
        case .targets: true
        case .wake: !wakeDays.isEmpty
        case .notifications: true
        case .profile: true
        }
    }

    private var buttonLabel: String {
        if step == activeSteps.last { return "Start tomorrow morning" }
        switch step {
        case .welcome: return "Get started"
        case .profile: return avatarImage == nil && location.isEmpty ? "Skip for now" : "Continue"
        default: return "Continue"
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            topBar

            ScrollView {
                Group {
                    switch step {
                    case .welcome: welcomeStep
                    case .name: nameStep
                    case .identity: identityStep
                    case .goals: goalsStep
                    case .interests: interestsStep
                    case .habits: habitsStep
                    case .targets: targetsStep
                    case .wake: wakeStep
                    case .notifications: notificationsStep
                    case .profile: profileStep
                    }
                }
                .id(step)
                .transition(.asymmetric(
                    insertion: .move(edge: .trailing).combined(with: .opacity),
                    removal: .move(edge: .leading).combined(with: .opacity)
                ))
                .padding(.horizontal, 24)
                .padding(.top, 20)
                .padding(.bottom, 24)
            }
            .scrollIndicators(.hidden)
            .scrollDismissesKeyboard(.interactively)
            .animation(.spring(duration: 0.32), value: step)

            Button(buttonLabel) { advance() }
                .buttonStyle(PrimaryButtonStyle())
                .disabled(!canContinue)
                .opacity(canContinue ? 1 : 0.4)
                .padding(.horizontal, 24)
                .padding(.bottom, 14)
        }
        .background(Theme.background)
        .onAppear {
            if name.isEmpty {
                name = store.account?.name ?? ""
            }
        }
        .fullScreenCover(isPresented: $showCamera) {
            CameraPicker { image in avatarImage = image }
                .ignoresSafeArea()
        }
        .sheet(isPresented: $showLibrary) {
            LibraryPicker { image in avatarImage = image }
        }
    }

    // MARK: Top bar (back arrow + progress)

    private var topBar: some View {
        HStack(spacing: 14) {
            Button {
                goBack()
            } label: {
                Image(systemName: "arrow.left")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(Theme.ink)
            }
            .opacity(step == .welcome ? 0 : 1)
            .disabled(step == .welcome)

            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Theme.ink.opacity(0.1))
                    Capsule()
                        .fill(Theme.ink)
                        .frame(width: proxy.size.width * progressFraction)
                }
            }
            .frame(height: 5)
            .animation(.spring(duration: 0.35), value: step)
        }
        .padding(.horizontal, 24)
        .padding(.top, 14)
    }

    /// Every step, in order. (Kept as a list so a step can be made
    /// conditional again without touching navigation.)
    private var activeSteps: [Step] {
        Step.allCases
    }

    private var progressFraction: CGFloat {
        let index = activeSteps.firstIndex(of: step) ?? 0
        return CGFloat(index) / CGFloat(max(1, activeSteps.count - 1))
    }

    // MARK: Navigation

    private func advance() {
        guard let index = activeSteps.firstIndex(of: step) else { return }
        if index == activeSteps.count - 1 {
            finish()
        } else {
            step = activeSteps[index + 1]
        }
    }

    private func goBack() {
        guard let index = activeSteps.firstIndex(of: step), index > 0 else { return }
        step = activeSteps[index - 1]
    }

    private func finish() {
        let trimmedCustom = identity.trimmingCharacters(in: .whitespaces)
        let resolvedIdentity: String
        if let choice = selectedIdentity, !choice.isCustom {
            resolvedIdentity = choice.statement
        } else if !trimmedCustom.isEmpty {
            resolvedIdentity = trimmedCustom
        } else {
            resolvedIdentity = "someone who follows through"
        }

        store.completeOnboarding(
            name: name.trimmingCharacters(in: .whitespaces),
            identity: resolvedIdentity,
            interests: Array(interests),
            templates: Array(selectedTemplates)
        )
        var config = store.wake
        let calendar = Calendar.current
        config.hour = calendar.component(.hour, from: wakeTime)
        config.minute = calendar.component(.minute, from: wakeTime)
        config.days = wakeDays
        config.enabled = wakeAlarm
        store.wake = config
        store.updateWakeSchedule()

        // Goals and targets drive the Today "This week" card and nutrition.
        var goals = store.goals
        goals.focuses = GoalFocus.allCases.filter { goalFocuses.contains($0) }
        goals.runsPerWeek = runsPerWeek
        goals.gymPerWeek = gymPerWeek
        goals.currentWeightKg = currentWeight
        goals.targetWeightKg = targetWeight
        store.updateGoals(goals)
        store.updateNutritionGoals(dietDirection.goals(calories: store.nutritionGoals.calories, keeping: store.nutritionGoals))
        if let currentWeight, currentWeight > 0 {
            store.logWeight(currentWeight)
        }

        store.updateReminders(ReminderPreferences(habitReminders: habitReminders))
        if bedtimeReminder != store.bedtime.enabled {
            store.setBedtimeReminder(bedtimeReminder)
        }

        if let photo = avatarImage, let data = photo.flexJPEGData(maxEdge: 800, quality: 0.8) {
            store.setProfilePhoto(data)
        }

        // Profile bits friends see.
        guard FeatureFlags.community, store.community.isSignedIn else { return }
        let community = store.community
        let headline = goals.focuses.prefix(2).map(\.label).joined(separator: " · ")
        let prefs = crewPrefs
        let photo = avatarImage
        let city = location.trimmingCharacters(in: .whitespaces)
        Task { @MainActor in
            try? await community.updateNotifyPrefs(prefs)
            var fields: [String: Any] = ["identity": resolvedIdentity]
            if !headline.isEmpty { fields["goal"] = headline }
            if !city.isEmpty { fields["location"] = city }
            try? await community.updateProfile(fields)
            if let photo { try? await community.setAvatar(photo) }
        }
    }

    // MARK: Step header helper

    private func stepHeader(_ title: String, _ subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title.uppercased())
                .font(.flexDisplay(34))
                .foregroundStyle(Theme.ink)
                .fixedSize(horizontal: false, vertical: true)
            Text(subtitle)
                .font(.flexBody())
                .foregroundStyle(Theme.inkSubtle)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: Steps

    private var welcomeStep: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 8) {
                    Image(systemName: "arrow.up.right.circle.fill")
                        .font(.system(size: 22))
                        .foregroundStyle(Theme.accent)
                    Text("FLEXUP")
                        .font(.flexMono(13))
                        .tracking(3)
                        .foregroundStyle(Theme.background.opacity(0.85))
                    Spacer()
                }
                Spacer(minLength: 28)
                heroLine("WAKE.", index: 0, accent: false)
                heroLine("RUN.", index: 1, accent: false)
                heroLine("LIFT.", index: 2, accent: false)
                heroLine("FUEL.", index: 3, accent: true)
                Spacer(minLength: 28)
                Text("THE OPERATING SYSTEM FOR BECOMING THE PERSON YOU WANT TO BE.")
                    .font(.flexMono(11))
                    .tracking(2)
                    .lineSpacing(5)
                    .foregroundStyle(Theme.background.opacity(0.65))
                    .opacity(heroAppeared ? 1 : 0)
                    .animation(.easeOut(duration: 0.5).delay(0.55), value: heroAppeared)
            }
            .padding(26)
            .frame(maxWidth: .infinity, minHeight: 400, alignment: .leading)
            .background(Theme.ink)
            .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))

            Text("No feeds. No noise. Four pillars, one streak at a time — built to get you off your phone.")
                .font(.flexBody())
                .foregroundStyle(Theme.inkSubtle)
        }
        .onAppear { heroAppeared = true }
    }

    private func heroLine(_ text: String, index: Int, accent: Bool) -> some View {
        Text(text)
            .font(.flexDisplay(48))
            .foregroundStyle(accent ? Theme.accent : Theme.background)
            .opacity(heroAppeared ? 1 : 0)
            .offset(y: heroAppeared ? 0 : 16)
            .animation(.spring(duration: 0.45).delay(Double(index) * 0.09 + 0.1), value: heroAppeared)
    }

    private var nameStep: some View {
        VStack(alignment: .leading, spacing: 28) {
            stepHeader("What should we call you?", "First name is fine. It's how the app talks to you.")
            VStack(alignment: .leading, spacing: 10) {
                Text("FIRST NAME")
                    .font(.flexMono(10))
                    .tracking(2)
                    .foregroundStyle(Theme.inkSubtle)
                TextField("Your name", text: $name)
                    .font(.flexDisplay(36))
                    .foregroundStyle(Theme.ink)
                    .padding(.bottom, 12)
                    .overlay(alignment: .bottom) {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(name.trimmingCharacters(in: .whitespaces).isEmpty ? Theme.ink.opacity(0.15) : Theme.accent)
                            .frame(height: 3)
                    }
                    .animation(.easeOut(duration: 0.2), value: name.isEmpty)
            }
        }
    }

    private var identityStep: some View {
        VStack(alignment: .leading, spacing: 24) {
            stepHeader("Who are you becoming?", "Not a goal — an identity. Pick the person you're building toward.")
            LazyVGrid(columns: interestColumns, spacing: 10) {
                ForEach(Self.identityOptions) { option in
                    identityCard(option)
                }
            }
            if selectedIdentity?.isCustom == true {
                HStack(spacing: 0) {
                    Text("I'm becoming ")
                        .font(.flexBodyBold())
                        .foregroundStyle(Theme.inkSubtle)
                    TextField("unstoppable", text: $identity)
                        .font(.flexBodyBold())
                        .foregroundStyle(Theme.ink)
                }
                .padding(18)
                .background(Theme.card)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .animation(.spring(duration: 0.25), value: selectedIdentity)
    }

    private func identityCard(_ option: IdentityOption) -> some View {
        let isSelected = selectedIdentity == option
        return Button {
            selectedIdentity = isSelected ? nil : option
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                ZStack {
                    Circle()
                        .fill(isSelected ? Theme.accent : Theme.accentSoft)
                        .frame(width: 40, height: 40)
                    Image(systemName: option.icon)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(isSelected ? Theme.background : Theme.accent)
                }
                Spacer(minLength: 0)
                Text(option.title.uppercased())
                    .font(.flexMono(12))
                    .tracking(1)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                Text(option.detail)
                    .font(.flexCaption())
                    .foregroundStyle(isSelected ? Theme.background.opacity(0.7) : Theme.inkSubtle)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .foregroundStyle(isSelected ? Theme.background : Theme.ink)
            .frame(maxWidth: .infinity, alignment: .leading)
            .frame(height: 128)
            .padding(16)
            .background(isSelected ? Theme.ink : Theme.card)
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .scaleEffect(isSelected ? 1.02 : 1)
        }
        .buttonStyle(.plain)
    }

    private var interestsStep: some View {
        VStack(alignment: .leading, spacing: 24) {
            stepHeader("What will you actually do?", "Choose the activities you'll show up for — they shape your starter habits.")
            LazyVGrid(columns: interestColumns, spacing: 10) {
                ForEach(ActivityCategory.allCases) { category in
                    interestCard(category)
                }
            }
        }
    }

    private func interestCard(_ category: ActivityCategory) -> some View {
        let isSelected = interests.contains(category)
        return Button {
            if isSelected {
                interests.remove(category)
            } else {
                interests.insert(category)
            }
        } label: {
            VStack(spacing: 10) {
                Image(systemName: category.icon)
                    .font(.system(size: 24, weight: .semibold))
                Text(category.label.uppercased())
                    .font(.flexMono(11))
                    .tracking(1)
            }
            .foregroundStyle(isSelected ? Theme.background : Theme.ink)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 22)
            .background(isSelected ? Theme.ink : Theme.card)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private var habitsStep: some View {
        VStack(alignment: .leading, spacing: 24) {
            stepHeader("Start small", "Pick two or three. Small and repeated beats big and abandoned.")
            VStack(spacing: 10) {
                ForEach(suggestedTemplates) { template in
                    templateRow(template)
                }
            }
        }
    }

    private func templateRow(_ template: HabitTemplate) -> some View {
        let isSelected = selectedTemplates.contains(template)
        return Button {
            if isSelected {
                selectedTemplates.remove(template)
            } else {
                selectedTemplates.insert(template)
            }
        } label: {
            HStack(spacing: 12) {
                IconBadge(systemName: template.category.icon, size: 40)
                VStack(alignment: .leading, spacing: 3) {
                    Text(template.title)
                        .font(.flexBodyBold())
                        .foregroundStyle(Theme.ink)
                    Text("\(template.weekdays.count)×/WEEK · \(template.timeOfDay.label.uppercased()) · \(template.durationMinutes) MIN")
                        .font(.flexMono(9))
                        .tracking(1)
                        .foregroundStyle(Theme.inkSubtle)
                }
                Spacer()
                Image(systemName: isSelected ? "checkmark.circle.fill" : "plus.circle")
                    .font(.title3)
                    .foregroundStyle(isSelected ? Theme.accent : Theme.inkSubtle)
            }
            .padding(14)
            .background(Theme.card)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(isSelected ? Theme.accent : .clear, lineWidth: 1.5)
            )
        }
        .buttonStyle(.plain)
    }

    private var wakeStep: some View {
        VStack(alignment: .leading, spacing: 24) {
            stepHeader("When will you wake up?", "Win the morning first. No snoozing, no backup alarms.")

            DatePicker("Wake time", selection: $wakeTime, displayedComponents: .hourAndMinute)
                .datePickerStyle(.wheel)
                .labelsHidden()
                .frame(maxWidth: .infinity)

            VStack(alignment: .leading, spacing: 10) {
                Text("REPEAT ON")
                    .font(.flexMono(10))
                    .tracking(2)
                    .foregroundStyle(Theme.inkSubtle)
                HStack(spacing: 8) {
                    ForEach(1...7, id: \.self) { weekday in
                        Button {
                            if wakeDays.contains(weekday) {
                                wakeDays.remove(weekday)
                            } else {
                                wakeDays.insert(weekday)
                            }
                        } label: {
                            Text(dayLetters[weekday - 1])
                                .font(.flexMono(13))
                                .foregroundStyle(wakeDays.contains(weekday) ? Theme.background : Theme.inkSubtle)
                                .frame(maxWidth: .infinity)
                                .frame(height: 42)
                                .background(wakeDays.contains(weekday) ? Theme.ink : Theme.card)
                                .clipShape(Circle())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            Toggle(isOn: $wakeAlarm) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Alarm notification")
                        .font(.flexBodyBold())
                        .foregroundStyle(Theme.ink)
                    Text("Fires at your wake time on these days.")
                        .font(.flexCaption())
                        .foregroundStyle(Theme.inkSubtle)
                }
            }
            .tint(Theme.accent)
            .padding(14)
            .background(Theme.card)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
    }

    // MARK: Goals

    private var goalsStep: some View {
        VStack(alignment: .leading, spacing: 24) {
            stepHeader("What do you want out of this?", "Pick every outcome that matters. We'll measure your weeks against them.")
            LazyVGrid(columns: interestColumns, spacing: 10) {
                ForEach(GoalFocus.allCases) { focus in
                    let isSelected = goalFocuses.contains(focus)
                    Button {
                        if isSelected {
                            goalFocuses.remove(focus)
                        } else {
                            goalFocuses.insert(focus)
                            if focus == .loseFat { dietDirection = .lose }
                            if focus == .buildMuscle, !goalFocuses.contains(.loseFat) { dietDirection = .build }
                        }
                    } label: {
                        VStack(spacing: 10) {
                            Image(systemName: focus.icon)
                                .font(.system(size: 24, weight: .semibold))
                            Text(focus.label.uppercased())
                                .font(.flexMono(11))
                                .tracking(1)
                                .multilineTextAlignment(.center)
                        }
                        .foregroundStyle(isSelected ? Theme.background : Theme.ink)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 22)
                        .background(isSelected ? Theme.ink : Theme.card)
                        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: Weekly targets

    private var targetsStep: some View {
        VStack(alignment: .leading, spacing: 20) {
            stepHeader("Set your week", "Targets you'd hit on a normal week — not your best one. You can change them any time.")

            targetRow("RUNS PER WEEK", value: $runsPerWeek, range: 0...7, icon: "figure.run")
            targetRow("GYM SESSIONS PER WEEK", value: $gymPerWeek, range: 0...7, icon: "dumbbell.fill")

            VStack(alignment: .leading, spacing: 10) {
                Text("EATING FOR")
                    .font(.flexMono(10))
                    .tracking(2)
                    .foregroundStyle(Theme.inkSubtle)
                HStack(spacing: 8) {
                    ForEach(DietDirection.allCases) { direction in
                        SelectableChip(label: direction.rawValue, isSelected: dietDirection == direction) {
                            dietDirection = direction
                        }
                    }
                }
                Text("Sets your macro split in Diet. Calories start at \(store.nutritionGoals.calories) kcal — adjust them there.")
                    .font(.flexCaption())
                    .foregroundStyle(Theme.inkSubtle)
            }

            HStack(spacing: 10) {
                weightField("WEIGHT NOW", value: $currentWeight)
                weightField("TARGET", value: $targetWeight)
            }
            Text("Optional. Weight stays on your phone — it's never shared.")
                .font(.flexCaption())
                .foregroundStyle(Theme.inkSubtle)
        }
    }

    private func targetRow(_ label: String, value: Binding<Int>, range: ClosedRange<Int>, icon: String) -> some View {
        HStack {
            IconBadge(systemName: icon, size: 40)
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.flexMono(9))
                    .tracking(1.5)
                    .foregroundStyle(Theme.inkSubtle)
                Text("\(value.wrappedValue)")
                    .font(.flexStat(28))
                    .foregroundStyle(Theme.ink)
            }
            Spacer()
            Stepper(label, value: value, in: range)
                .labelsHidden()
        }
        .padding(14)
        .background(Theme.card)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private func weightField(_ label: String, value: Binding<Double?>) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.flexMono(9))
                .tracking(1.5)
                .foregroundStyle(Theme.inkSubtle)
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                TextField("—", value: value, format: .number)
                    .keyboardType(.decimalPad)
                    .font(.flexStat(24))
                    .foregroundStyle(Theme.ink)
                Text("KG")
                    .font(.flexMono(10))
                    .foregroundStyle(Theme.inkSubtle)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.card)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    // MARK: Notifications

    private var notificationsStep: some View {
        VStack(alignment: .leading, spacing: 20) {
            stepHeader("How should we reach you?", "Just enough to keep you honest. Nothing to pull you back for the sake of it.")

            VStack(spacing: 0) {
                preferenceToggle("Habit reminders", detail: "A heads-up when a habit is due.", icon: "checklist", isOn: $habitReminders)
                Divider().padding(.leading, 52)
                preferenceToggle("Bedtime reminder", detail: "Wind down in time for your wake-up.", icon: "moon.zzz", isOn: $bedtimeReminder)
            }
            .background(Theme.card)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))

            if FeatureFlags.community && store.community.isSignedIn {
                VStack(alignment: .leading, spacing: 8) {
                    Text("FROM YOUR CREW")
                        .font(.flexMono(10))
                        .tracking(2)
                        .foregroundStyle(Theme.inkSubtle)
                    VStack(spacing: 0) {
                        preferenceToggle("Nudges", detail: "When a friend nudges you to show up.", icon: "hand.wave", isOn: $crewPrefs.nudges)
                        Divider().padding(.leading, 52)
                        preferenceToggle("Cheers & kudos", detail: "When friends cheer what you did.", icon: "hand.thumbsup", isOn: $crewPrefs.cheers)
                        Divider().padding(.leading, 52)
                        preferenceToggle("Comments", detail: "Replies on your posts.", icon: "text.bubble", isOn: $crewPrefs.comments)
                        Divider().padding(.leading, 52)
                        preferenceToggle("Friend requests", detail: "Someone wants you in their crew.", icon: "person.badge.plus", isOn: $crewPrefs.friends)
                    }
                    .background(Theme.card)
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                }
            }

            Text("Your wake alarm is already set from the last screen. Change any of this later from your profile → Notifications.")
                .font(.flexCaption())
                .foregroundStyle(Theme.inkSubtle)
        }
    }

    private func preferenceToggle(_ title: String, detail: String, icon: String, isOn: Binding<Bool>) -> some View {
        Toggle(isOn: isOn) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Theme.accent)
                    .frame(width: 24)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.flexBodyBold())
                        .foregroundStyle(Theme.ink)
                    Text(detail)
                        .font(.flexCaption())
                        .foregroundStyle(Theme.inkSubtle)
                }
            }
        }
        .tint(Theme.accent)
        .padding(14)
    }

    // MARK: Profile (with a FlexUp account)

    private var profileStep: some View {
        VStack(alignment: .leading, spacing: 24) {
            stepHeader("Put a face to it", FeatureFlags.community
                       ? "Your crew sees your photo and city. Both optional."
                       : "Add a photo for your profile. Optional — it stays on your phone.")

            HStack {
                Spacer()
                ZStack(alignment: .bottomTrailing) {
                    Group {
                        if let avatarImage {
                            Image(uiImage: avatarImage)
                                .resizable()
                                .scaledToFill()
                                .frame(width: 150, height: 150)
                                .clipShape(Circle())
                        } else {
                            AvatarCircle(name: name.isEmpty ? "?" : name, size: 150)
                        }
                    }
                    .padding(5)
                    .overlay(Circle().strokeBorder(ProfileAvatar.ringGradient, lineWidth: 4))

                    Menu {
                        if UIImagePickerController.isSourceTypeAvailable(.camera) {
                            Button("Take photo", systemImage: "camera") { showCamera = true }
                        }
                        Button("Choose from library", systemImage: "photo.on.rectangle") { showLibrary = true }
                    } label: {
                        Image(systemName: "camera.fill")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(Theme.background)
                            .frame(width: 44, height: 44)
                            .background(Theme.ink)
                            .clipShape(Circle())
                            .overlay(Circle().stroke(Theme.background, lineWidth: 4))
                    }
                    .offset(x: -4, y: -4)
                }
                Spacer()
            }

            if FeatureFlags.community {
                VStack(alignment: .leading, spacing: 6) {
                    Text("CITY")
                        .font(.flexMono(10))
                        .tracking(2)
                        .foregroundStyle(Theme.inkSubtle)
                    HStack(spacing: 8) {
                        Image(systemName: "location.fill")
                            .foregroundStyle(Theme.accent)
                        TextField("e.g. Noida", text: $location)
                            .font(.flexBodyBold())
                            .textContentType(.addressCity)
                    }
                    .padding(14)
                    .background(Theme.card)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
            }
        }
    }
}

#Preview {
    OnboardingView()
        .environment(AppStore())
}
