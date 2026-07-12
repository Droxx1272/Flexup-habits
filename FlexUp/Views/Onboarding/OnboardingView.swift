import SwiftUI

/// Three steps, one promise: tell us who you're becoming, and we'll help
/// you follow through. Ends with real habits on a real calendar.
struct OnboardingView: View {
    @Environment(AppStore.self) private var store

    @State private var step = 0
    @State private var name = ""
    @State private var identity = ""
    @State private var interests: Set<ActivityCategory> = []
    @State private var selectedTemplates: Set<HabitTemplate> = []

    private let identitySuggestions = [
        "a runner", "an early riser", "consistent", "a reader", "stronger every week",
    ]

    private var suggestedTemplates: [HabitTemplate] {
        let matching = SampleData.habitTemplates.filter { interests.contains($0.category) }
        return matching.isEmpty ? SampleData.habitTemplates : matching
    }

    private var canContinue: Bool {
        switch step {
        case 0: true
        case 1: !name.trimmingCharacters(in: .whitespaces).isEmpty
        case 2: !interests.isEmpty && !selectedTemplates.isEmpty
        default: false
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    switch step {
                    case 0: welcome
                    case 1: identityStep
                    default: habitsStep
                    }
                }
                .padding(24)
            }
            .scrollIndicators(.hidden)

            Button(step == 2 ? "Start showing up" : "Continue") {
                if step < 2 {
                    withAnimation(.spring(duration: 0.35)) { step += 1 }
                } else {
                    store.completeOnboarding(
                        name: name.trimmingCharacters(in: .whitespaces),
                        identity: identity.isEmpty ? "someone who follows through" : identity,
                        interests: Array(interests),
                        templates: Array(selectedTemplates)
                    )
                }
            }
            .buttonStyle(PrimaryButtonStyle())
            .disabled(!canContinue)
            .opacity(canContinue ? 1 : 0.4)
            .padding(.horizontal, 24)
            .padding(.bottom, 16)
        }
        .background(Theme.background)
    }

    // MARK: Step 0 — Welcome

    private var welcome: some View {
        VStack(alignment: .leading, spacing: 20) {
            Spacer(minLength: 40)
            Image(systemName: "arrow.up.right.circle.fill")
                .font(.system(size: 52))
                .foregroundStyle(Theme.accent)
            Text("FlexUp")
                .font(.flexTitle())
                .foregroundStyle(Theme.ink)
            Text("The operating system for becoming the person you want to be.")
                .font(.flexHeading())
                .foregroundStyle(Theme.ink)
            VStack(alignment: .leading, spacing: 12) {
                principle("You don't need more motivation. You need a better system.")
                principle("Relationships motivate more than notifications.")
                principle("Consistency beats intensity.")
                principle("The app exists to get you off your phone.")
            }
            .padding(.top, 8)
        }
    }

    private func principle(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "checkmark")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(Theme.accent)
                .padding(.top, 3)
            Text(text)
                .font(.flexBody())
                .foregroundStyle(Theme.inkSubtle)
        }
    }

    // MARK: Step 1 — Identity

    private var identityStep: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Who are you becoming?")
                .font(.flexTitle())
                .foregroundStyle(Theme.ink)
            Text("FlexUp is built around identity, not streaks for their own sake. Progress matters more than perfection.")
                .font(.flexBody())
                .foregroundStyle(Theme.inkSubtle)

            VStack(alignment: .leading, spacing: 8) {
                Text("Your name")
                    .font(.flexCaption())
                    .foregroundStyle(Theme.inkSubtle)
                TextField("Name", text: $name)
                    .font(.flexBodyBold())
                    .padding(14)
                    .background(Theme.card)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("I'm becoming…")
                    .font(.flexCaption())
                    .foregroundStyle(Theme.inkSubtle)
                TextField("a runner", text: $identity)
                    .font(.flexBodyBold())
                    .padding(14)
                    .background(Theme.card)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

                FlowChips(items: identitySuggestions, selected: identity) { suggestion in
                    identity = suggestion
                }
            }
        }
    }

    // MARK: Step 2 — Interests & starter habits

    private var habitsStep: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Pick your first commitments")
                .font(.flexTitle())
                .foregroundStyle(Theme.ink)
            Text("Choose what you care about, then two or three small habits. Small and repeated wins.")
                .font(.flexBody())
                .foregroundStyle(Theme.inkSubtle)

            SectionHeader(title: "Interests")
            FlowLayoutChips {
                ForEach(ActivityCategory.allCases) { category in
                    SelectableChip(
                        label: category.label,
                        icon: category.icon,
                        isSelected: interests.contains(category)
                    ) {
                        if interests.contains(category) {
                            interests.remove(category)
                        } else {
                            interests.insert(category)
                        }
                    }
                }
            }

            SectionHeader(title: "Starter habits", subtitle: "Tap to add — start with 2 or 3.")
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
                IconBadge(systemName: template.category.icon, size: 38)
                VStack(alignment: .leading, spacing: 2) {
                    Text(template.title)
                        .font(.flexBodyBold())
                        .foregroundStyle(Theme.ink)
                    Text("\(template.weekdays.count)× a week · \(template.timeOfDay.label) · \(template.durationMinutes) min")
                        .font(.flexCaption())
                        .foregroundStyle(Theme.inkSubtle)
                }
                Spacer()
                Image(systemName: isSelected ? "checkmark.circle.fill" : "plus.circle")
                    .font(.title3)
                    .foregroundStyle(isSelected ? Theme.accent : Theme.inkSubtle)
            }
            .padding(12)
            .background(Theme.card)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(isSelected ? Theme.accent : .clear, lineWidth: 1.5)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Small chip helpers

/// Single-row wrapping chips for short suggestion lists.
private struct FlowChips: View {
    let items: [String]
    let selected: String
    let onTap: (String) -> Void

    var body: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 8) {
                ForEach(items, id: \.self) { item in
                    SelectableChip(label: item, isSelected: selected == item) {
                        onTap(item)
                    }
                }
            }
        }
        .scrollIndicators(.hidden)
    }
}

/// Simple wrap substitute: horizontal scroll keeps layout dependable.
private struct FlowLayoutChips<Content: View>: View {
    private let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 8) { content }
        }
        .scrollIndicators(.hidden)
    }
}

#Preview {
    OnboardingView()
        .environment(AppStore())
}
