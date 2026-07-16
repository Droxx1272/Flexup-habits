import SwiftUI

/// Onboarding, one question per screen: progress bar and back arrow up top,
/// a single big question, one pill button at the bottom. Ends with the wake
/// pillar configured so day one starts tomorrow morning.
struct OnboardingView: View {
    @Environment(AppStore.self) private var store

    private enum Step: Int, CaseIterable {
        case welcome, name, identity, interests, habits, wake
    }

    @State private var step: Step = .welcome
    @State private var name = ""
    @State private var identity = ""
    @State private var interests: Set<ActivityCategory> = []
    @State private var selectedTemplates: Set<HabitTemplate> = []
    @State private var wakeTime = Calendar.current.date(bySettingHour: 6, minute: 30, second: 0, of: .now) ?? .now
    @State private var wakeDays: Set<Int> = [2, 3, 4, 5, 6]
    @State private var wakeAlarm = true

    private let identitySuggestions = ["a runner", "an early riser", "stronger", "consistent", "a morning person"]
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
        case .interests: !interests.isEmpty
        case .habits: !selectedTemplates.isEmpty
        case .wake: !wakeDays.isEmpty
        }
    }

    private var buttonLabel: String {
        switch step {
        case .welcome: "Get started"
        case .wake: "Start tomorrow morning"
        default: "Continue"
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
                    case .interests: interestsStep
                    case .habits: habitsStep
                    case .wake: wakeStep
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

    private var progressFraction: CGFloat {
        CGFloat(step.rawValue) / CGFloat(Step.allCases.count - 1)
    }

    // MARK: Navigation

    private func advance() {
        if step == .wake {
            finish()
        } else if let next = Step(rawValue: step.rawValue + 1) {
            step = next
        }
    }

    private func goBack() {
        if let previous = Step(rawValue: step.rawValue - 1) {
            step = previous
        }
    }

    private func finish() {
        store.completeOnboarding(
            name: name.trimmingCharacters(in: .whitespaces),
            identity: identity.trimmingCharacters(in: .whitespaces).isEmpty
                ? "someone who follows through"
                : identity.trimmingCharacters(in: .whitespaces),
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
        VStack(alignment: .leading, spacing: 24) {
            Spacer(minLength: 30)
            Image(systemName: "arrow.up.right.circle.fill")
                .font(.system(size: 54))
                .foregroundStyle(Theme.accent)
            Text("FLEXUP")
                .font(.flexDisplay(52))
                .foregroundStyle(Theme.ink)
            Text("THE OPERATING SYSTEM FOR BECOMING THE PERSON YOU WANT TO BE.")
                .font(.flexMono(13))
                .tracking(2)
                .foregroundStyle(Theme.inkSubtle)
                .lineSpacing(6)

            HStack(spacing: 12) {
                pillarBadge("sunrise.fill", "Wake")
                pillarBadge("figure.run", "Run")
                pillarBadge("dumbbell", "Gym")
                pillarBadge("fork.knife", "Diet")
            }
            .frame(maxWidth: .infinity)
            .padding(.top, 8)

            Text("Four pillars. One streak at a time. No feeds, no noise — the app exists to get you off your phone.")
                .font(.flexBody())
                .foregroundStyle(Theme.inkSubtle)
        }
    }

    private func pillarBadge(_ icon: String, _ label: String) -> some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .fill(Theme.ink)
                    .frame(width: 52, height: 52)
                Image(systemName: icon)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(Theme.background)
            }
            Text(label.uppercased())
                .font(.flexMono(9))
                .tracking(1)
                .foregroundStyle(Theme.inkSubtle)
        }
        .frame(maxWidth: .infinity)
    }

    private var nameStep: some View {
        VStack(alignment: .leading, spacing: 24) {
            stepHeader("What should we call you?", "First name is fine. It's how the app talks to you.")
            TextField("Your name", text: $name)
                .font(.flexDisplay(26))
                .foregroundStyle(Theme.ink)
                .padding(18)
                .background(Theme.card)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
    }

    private var identityStep: some View {
        VStack(alignment: .leading, spacing: 24) {
            stepHeader("Who are you becoming?", "FlexUp is built around identity, not streaks for their own sake. Skip it if you're not sure yet.")

            HStack(spacing: 0) {
                Text("I'm becoming ")
                    .font(.flexBodyBold())
                    .foregroundStyle(Theme.inkSubtle)
                TextField("a runner", text: $identity)
                    .font(.flexBodyBold())
                    .foregroundStyle(Theme.ink)
            }
            .padding(18)
            .background(Theme.card)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))

            ScrollView(.horizontal) {
                HStack(spacing: 8) {
                    ForEach(identitySuggestions, id: \.self) { suggestion in
                        SelectableChip(label: suggestion, isSelected: identity == suggestion) {
                            identity = suggestion
                        }
                    }
                }
            }
            .scrollIndicators(.hidden)
        }
    }

    private var interestsStep: some View {
        VStack(alignment: .leading, spacing: 24) {
            stepHeader("Pick your focus", "Choose what you care about — it shapes your starter habits.")
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
}

#Preview {
    OnboardingView()
        .environment(AppStore())
}
