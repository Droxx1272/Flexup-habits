import SwiftUI

/// The first thing anyone sees, before an account: a guide asks what you
/// want to change and what usually gets in the way, then shows how FlexUp
/// will help, tailored to those answers, and builds the plan. One question
/// per screen. Answers land in `store.goals`, so onboarding doesn't ask
/// again. Shown once (`AppStore.hasSeenIntro`) and replayable from Stats.
struct IntroView: View {
    @Environment(AppStore.self) private var store

    private enum Step: Int, CaseIterable {
        case hello, focus, obstacle, days, howItWorks, proof, plan
    }

    /// What tends to stop people. Shapes the "here's how I'll help" screen.
    enum Obstacle: String, CaseIterable, Identifiable {
        case snooze, fade, noTracking, alone, time
        var id: String { rawValue }

        var eyebrow: String {
            switch self {
            case .snooze: "MORNINGS"
            case .fade: "MOTIVATION"
            case .noTracking: "TRACKING"
            case .alone: "ACCOUNTABILITY"
            case .time: "TIME"
            }
        }

        var title: String {
            switch self {
            case .snooze: "I hit snooze"
            case .fade: "I start strong, then fade"
            case .noTracking: "I don't track anything"
            case .alone: "No one holds me to it"
            case .time: "I run out of time"
            }
        }

        var color: Color {
            switch self {
            case .snooze: Theme.amber
            case .fade: Theme.danger
            case .noTracking: .indigo
            case .alone: Theme.accent
            case .time: .teal
            }
        }
    }

    @State private var step: Step = .hello
    @State private var focuses: Set<GoalFocus> = []
    @State private var obstacle: Obstacle?
    @State private var daysPerWeek: Int?

    /// The focuses offered first, each with the pillar it belongs to.
    private static let focusOptions: [(focus: GoalFocus, eyebrow: String, color: Color)] = [
        (.wakeEarlier, "WAKE", Theme.amber),
        (.sleepBetter, "SLEEP", .indigo),
        (.runFarther, "RUN", Theme.accent),
        (.buildMuscle, "GYM", Theme.ink),
        (.eatBetter, "DIET", .teal),
        (.loseFat, "BODY", Theme.danger),
    ]

    private var canContinue: Bool {
        switch step {
        case .focus: !focuses.isEmpty
        case .obstacle: obstacle != nil
        case .days: daysPerWeek != nil
        default: true
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            topBar

            ScrollView {
                Group {
                    switch step {
                    case .hello: helloStep
                    case .focus: focusStep
                    case .obstacle: obstacleStep
                    case .days: daysStep
                    case .howItWorks: howItWorksStep
                    case .proof: proofStep
                    case .plan: planStep
                    }
                }
                .id(step)
                .transition(.asymmetric(
                    insertion: .move(edge: .trailing).combined(with: .opacity),
                    removal: .move(edge: .leading).combined(with: .opacity)
                ))
                .padding(.horizontal, 24)
                .padding(.top, 12)
                .padding(.bottom, 24)
            }
            .scrollIndicators(.hidden)
            .animation(.spring(duration: 0.35), value: step)

            Button(step == .plan ? "Let's go" : "Continue") { advance() }
                .buttonStyle(PrimaryButtonStyle())
                .disabled(!canContinue)
                .opacity(canContinue ? 1 : 0.4)
                .padding(.horizontal, 24)
                .padding(.bottom, 14)
        }
        .background(Theme.background)
    }

    // MARK: Top bar

    private var topBar: some View {
        HStack(spacing: 16) {
            Button {
                goBack()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(Theme.ink)
                    .frame(width: 32, height: 32)
            }
            .opacity(step == .hello ? 0 : 1)
            .disabled(step == .hello)
            .accessibilityLabel("Back")

            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule().fill(Theme.ink.opacity(0.08))
                    Capsule()
                        .fill(Theme.accent)
                        .frame(width: proxy.size.width * progress)
                }
            }
            .frame(height: 8)
            .animation(.spring(duration: 0.4), value: step)

            // Balances the back button so the bar sits centred.
            Color.clear.frame(width: 32, height: 32)
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .padding(.bottom, 8)
    }

    private var progress: CGFloat {
        CGFloat(step.rawValue + 1) / CGFloat(Step.allCases.count)
    }

    // MARK: Navigation

    private func advance() {
        if step == .plan {
            finish()
            return
        }
        if let next = Step(rawValue: step.rawValue + 1) { step = next }
    }

    private func goBack() {
        if let previous = Step(rawValue: step.rawValue - 1) { step = previous }
    }

    /// Weekly targets from the days answer, split across running and the
    /// gym when both were picked.
    private var targets: (runs: Int, gym: Int) {
        let days = daysPerWeek ?? 3
        let runs = focuses.contains(.runFarther)
        let gym = focuses.contains(.buildMuscle) || focuses.contains(.loseFat)
        switch (runs, gym) {
        case (true, true): return (max(1, days / 2), max(1, days - days / 2))
        case (true, false): return (days, store.goals.gymPerWeek)
        case (false, true): return (store.goals.runsPerWeek, days)
        default: return (store.goals.runsPerWeek, store.goals.gymPerWeek)
        }
    }

    private func finish() {
        var goals = store.goals
        goals.focuses = GoalFocus.allCases.filter { focuses.contains($0) }
        let plan = targets
        goals.runsPerWeek = plan.runs
        goals.gymPerWeek = plan.gym
        store.updateGoals(goals)
        store.completeIntro()
    }

    // MARK: Steps

    private var helloStep: some View {
        VStack(spacing: 28) {
            GuideOrb(size: 220, pulsing: true)
                .padding(.top, 50)
            GuideBubble(text: "Hi. I'm going to help you do what you said you'd do.")
        }
    }

    private var focusStep: some View {
        VStack(spacing: 22) {
            guideHeader("What do you want to change first? Pick all that apply.")
            VStack(spacing: 12) {
                ForEach(Self.focusOptions, id: \.focus) { option in
                    OptionCard(
                        eyebrow: option.eyebrow,
                        title: option.focus.label,
                        color: option.color,
                        isSelected: focuses.contains(option.focus)
                    ) {
                        if focuses.contains(option.focus) {
                            focuses.remove(option.focus)
                        } else {
                            focuses.insert(option.focus)
                        }
                    }
                }
            }
        }
    }

    private var obstacleStep: some View {
        VStack(spacing: 22) {
            guideHeader("Be honest. What usually gets in the way?")
            VStack(spacing: 12) {
                ForEach(Obstacle.allCases) { option in
                    OptionCard(
                        eyebrow: option.eyebrow,
                        title: option.title,
                        color: option.color,
                        isSelected: obstacle == option
                    ) {
                        obstacle = option
                    }
                }
            }
        }
    }

    private var daysStep: some View {
        VStack(spacing: 22) {
            guideHeader("On a normal week, not your best one, how many days can you show up?")
            VStack(spacing: 12) {
                ForEach([2, 3, 4, 5], id: \.self) { days in
                    OptionCard(
                        eyebrow: days == 5 ? "ALL IN" : (days == 2 ? "EASING IN" : "STEADY"),
                        title: days == 5 ? "5 or more days" : "\(days) days a week",
                        color: Theme.accent,
                        isSelected: daysPerWeek == days
                    ) {
                        daysPerWeek = days
                    }
                }
            }
            Text("You can change this any time. Hitting a smaller number beats missing a bigger one.")
                .font(.flexCaption())
                .foregroundStyle(Theme.inkSubtle)
                .multilineTextAlignment(.center)
        }
    }

    private var howItWorksStep: some View {
        VStack(spacing: 30) {
            guideHeader("Here's how I'll help. Every day runs on the same loop.")
            LoopDiagram()
                .frame(height: 340)
        }
    }

    private var proofStep: some View {
        let story = ProofStory(for: obstacle ?? .alone, focuses: focuses)
        return VStack(spacing: 34) {
            guideHeader(story.line)
            ProofSequence(steps: story.steps)
        }
    }

    private var planStep: some View {
        VStack(spacing: 26) {
            GuideOrb(size: 150, pulsing: true)
                .padding(.top, 10)
            GuideBubble(text: "Let's build your plan…")
            PlanList(items: planItems)
        }
    }

    /// What the next week looks like, in the person's own terms.
    private var planItems: [String] {
        var items: [String] = []
        let plan = targets
        if focuses.contains(.wakeEarlier) { items.append("A real alarm, and a photo check-in to prove you're up") }
        if focuses.contains(.sleepBetter) { items.append("A bedtime reminder and a 10-second sleep log") }
        if focuses.contains(.runFarther) { items.append("\(plan.runs) runs a week, tracked by GPS") }
        if focuses.contains(.buildMuscle) || focuses.contains(.loseFat) {
            items.append("\(plan.gym) gym sessions a week, every set logged")
        }
        if focuses.contains(.eatBetter) || focuses.contains(.loseFat) {
            items.append("Meals logged in seconds, with calories and macros")
        }
        items.append("One scorecard each week, measured against your plan")
        return items
    }

    /// Small orb with the speech bubble under it, as in a conversation.
    private func guideHeader(_ text: String) -> some View {
        VStack(spacing: 10) {
            GuideOrb(size: 64, pulsing: false)
            GuideBubble(text: text)
        }
    }
}

// MARK: - Guide

/// FlexUp's guide: concentric rings in the accent green, breathing gently.
struct GuideOrb: View {
    var size: CGFloat
    var pulsing: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var breathe = false

    var body: some View {
        ZStack {
            Circle()
                .stroke(Theme.accent.opacity(0.22), lineWidth: max(1, size * 0.008))
                .scaleEffect(breathe ? 1.04 : 0.96)
            Circle()
                .stroke(Theme.accent.opacity(0.55), lineWidth: size * 0.05)
                .padding(size * 0.08)
            Circle()
                .stroke(Theme.accent.opacity(0.85), lineWidth: size * 0.065)
                .padding(size * 0.18)
                .scaleEffect(breathe ? 1.02 : 0.98)
            Circle()
                .fill(Color(light: 0x1F4F3C, dark: 0x8FD3B0))
                .padding(size * 0.3)
        }
        .frame(width: size, height: size)
        .onAppear {
            guard pulsing, !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 1.6).repeatForever(autoreverses: true)) { breathe = true }
        }
        .accessibilityHidden(true)
    }
}

/// The guide's speech bubble. Text types itself out, so it reads like
/// someone talking; Reduce Motion shows it all at once.
struct GuideBubble: View {
    let text: String

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var shown = 0

    var body: some View {
        let characters = Array(text)
        let visible = String(characters.prefix(shown))
        let hidden = String(characters.dropFirst(shown))

        // The hidden part keeps its space, so the bubble never resizes.
        (Text(visible) + Text(hidden).foregroundColor(.clear))
            .font(.system(size: 24, weight: .semibold))
            .foregroundColor(Theme.ink)
            .multilineTextAlignment(.center)
            .padding(.horizontal, 26)
            .padding(.vertical, 24)
            .frame(maxWidth: .infinity)
            .background(Theme.card)
            .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
            .overlay(alignment: .top) {
                BubblePointer()
                    .fill(Theme.card)
                    .frame(width: 26, height: 12)
                    .offset(y: -11)
            }
            .shadow(color: .black.opacity(0.05), radius: 14, y: 6)
            .accessibilityElement()
            .accessibilityLabel(text)
            .task(id: text) {
                guard !reduceMotion else {
                    shown = characters.count
                    return
                }
                shown = 0
                for index in 1...max(1, characters.count) {
                    try? await Task.sleep(nanoseconds: 16_000_000)
                    if Task.isCancelled { return }
                    shown = index
                }
            }
    }
}

/// The little triangle connecting a bubble to the orb above it.
struct BubblePointer: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

// MARK: - Option card

/// One answer: a coloured eyebrow over a big plain title.
struct OptionCard: View {
    let eyebrow: String
    let title: String
    let color: Color
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                VStack(alignment: .leading, spacing: 6) {
                    Text(eyebrow)
                        .font(.flexMono(11))
                        .tracking(1.5)
                        .foregroundStyle(color)
                    Text(title)
                        .font(.system(size: 21, weight: .semibold))
                        .foregroundStyle(Theme.ink)
                        .multilineTextAlignment(.leading)
                }
                Spacer()
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 22))
                    .foregroundStyle(isSelected ? Theme.accent : Theme.inkSubtle.opacity(0.35))
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 18)
            .background(Theme.card)
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(isSelected ? Theme.accent : Theme.ink.opacity(0.05), lineWidth: isSelected ? 2 : 1)
            )
            .animation(.snappy(duration: 0.2), value: isSelected)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

// MARK: - How it works

/// The core loop as a ring of five nodes, lighting up one after another.
private struct LoopDiagram: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var lit = 0

    private let nodes: [(title: String, detail: String, icon: String)] = [
        ("Plan", "Pick the days", "calendar"),
        ("Commit", "It goes on today", "hand.raised.fill"),
        ("Do", "Run, lift, wake, eat", "bolt.fill"),
        ("Prove", "Photo, GPS, sets", "checkmark.seal.fill"),
        ("Repeat", "Streaks keep score", "arrow.triangle.2.circlepath"),
    ]

    /// Nodes evenly around a circle, starting at the top.
    private func positions(in size: CGSize) -> [CGPoint] {
        let center = CGPoint(x: size.width / 2, y: size.height / 2)
        let radius = min(size.width, size.height) / 2 - 46
        let step = 2 * Double.pi / Double(nodes.count)
        return nodes.indices.map { index in
            let angle = -Double.pi / 2 + Double(index) * step
            return CGPoint(x: center.x + radius * cos(angle), y: center.y + radius * sin(angle))
        }
    }

    /// Dashed link; the ones already travelled turn green.
    private func link(from start: CGPoint, to end: CGPoint, travelled: Bool) -> some View {
        Path { path in
            path.move(to: start)
            path.addLine(to: end)
        }
        .stroke(
            travelled ? Theme.accent : Theme.inkSubtle.opacity(0.35),
            style: StrokeStyle(lineWidth: 2.5, lineCap: .round, dash: [5, 6])
        )
    }

    private func node(_ index: Int) -> some View {
        let isOn = index <= lit
        let item = nodes[index]
        return VStack(spacing: 6) {
            ZStack {
                Circle()
                    .stroke(Theme.accent.opacity(index == lit ? 0.35 : 0), lineWidth: 6)
                    .frame(width: 58, height: 58)
                Circle()
                    .fill(isOn ? Theme.accent : Theme.card)
                    .frame(width: 46, height: 46)
                    .overlay(Circle().stroke(Theme.inkSubtle.opacity(isOn ? 0 : 0.3), lineWidth: 1))
                Image(systemName: item.icon)
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(isOn ? Color.white : Theme.inkSubtle)
            }
            VStack(spacing: 1) {
                Text(item.title.uppercased())
                    .font(.flexMono(11))
                    .tracking(1.2)
                    .foregroundStyle(Theme.ink)
                Text(item.detail)
                    .font(.flexCaption())
                    .foregroundStyle(Theme.inkSubtle)
                    .lineLimit(1)
                    .fixedSize()
            }
        }
    }

    var body: some View {
        GeometryReader { proxy in
            let points = positions(in: proxy.size)
            ZStack {
                ForEach(nodes.indices, id: \.self) { index in
                    link(from: points[index], to: points[(index + 1) % nodes.count], travelled: index < lit)
                }
                ForEach(nodes.indices, id: \.self) { index in
                    node(index)
                        .position(x: points[index].x, y: points[index].y + 18)
                }
            }
            .animation(.spring(duration: 0.4), value: lit)
        }
        .accessibilityElement()
        .accessibilityLabel("Plan, commit, do, prove, repeat.")
        .task {
            if reduceMotion {
                lit = nodes.count - 1
                return
            }
            // Walks the loop, pauses on a full ring, then starts again.
            while !Task.isCancelled {
                for index in 0..<nodes.count {
                    lit = index
                    try? await Task.sleep(nanoseconds: 700_000_000)
                }
                try? await Task.sleep(nanoseconds: 900_000_000)
            }
        }
    }
}

// MARK: - Proof

/// The answer to "what gets in the way": one line from the guide and a
/// three-step picture of how FlexUp handles it.
private struct ProofStory {
    let line: String
    let steps: [(icon: String, title: String)]

    init(for obstacle: IntroView.Obstacle, focuses: Set<GoalFocus>) {
        switch obstacle {
        case .snooze:
            line = "No snooze button. To turn your morning off, you walk to a spot you chose and photograph it."
            steps = [("alarm.fill", "Alarm rings"), ("camera.viewfinder", "Photo your spot"), ("checkmark.seal.fill", "Morning won")]
        case .fade:
            line = "Day 8 is where most people stop. I keep your streak and your week in front of you, so you can see the thread."
            steps = [("flame.fill", "Streak grows"), ("calendar", "Week scorecard"), ("arrow.uturn.up", "Miss one, restart small")]
        case .noTracking:
            line = "Logging takes seconds. Runs track themselves, sets remember last time, meals come from a photo."
            steps = [("figure.run", "GPS run"), ("dumbbell.fill", "Last set shown"), ("camera.fill", "Snap the plate")]
        case .alone:
            line = "I'll hold you to it. Every check-in needs proof, so a done day is really done."
            steps = [("hand.raised.fill", "You commit"), ("checkmark.seal.fill", "You prove it"), ("chart.bar.fill", "It counts")]
        case .time:
            line = "Plan it once and I'll put it on the right days, then remind you when it's time."
            steps = [("calendar.badge.plus", "Plan the week"), ("bell.fill", "Reminder on time"), ("bolt.fill", "Start in one tap")]
        }
    }
}

private struct ProofSequence: View {
    let steps: [(icon: String, title: String)]

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var shown = 0

    var body: some View {
        HStack(alignment: .top, spacing: 6) {
            ForEach(steps.indices, id: \.self) { index in
                if index > 0 {
                    Image(systemName: "arrow.right")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(Theme.inkSubtle)
                        .padding(.top, 30)
                        .opacity(index < shown ? 1 : 0)
                }
                VStack(spacing: 10) {
                    Image(systemName: steps[index].icon)
                        .font(.system(size: 26, weight: .semibold))
                        .foregroundStyle(index == steps.count - 1 ? Color.white : Theme.accent)
                        .frame(width: 76, height: 76)
                        .background(index == steps.count - 1 ? Theme.accent : Theme.accentSoft)
                        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                    Text(steps[index].title)
                        .font(.flexCaption())
                        .foregroundStyle(Theme.ink)
                        .multilineTextAlignment(.center)
                        .frame(width: 90)
                }
                .opacity(index < shown ? 1 : 0)
                .scaleEffect(index < shown ? 1 : 0.8)
            }
        }
        .frame(maxWidth: .infinity)
        .animation(.spring(duration: 0.45), value: shown)
        .accessibilityElement()
        .accessibilityLabel(steps.map(\.title).joined(separator: ", then "))
        .task {
            if reduceMotion {
                shown = steps.count
                return
            }
            for index in 1...steps.count {
                try? await Task.sleep(nanoseconds: 450_000_000)
                shown = index
            }
        }
    }
}

// MARK: - Plan

/// The plan, ticking in line by line as it's "built".
private struct PlanList: View {
    let items: [String]

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var shown = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(items.indices, id: \.self) { index in
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(Theme.accent)
                    Text(items[index])
                        .font(.flexBody())
                        .foregroundStyle(Theme.ink)
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 0)
                }
                .opacity(index < shown ? 1 : 0)
                .offset(y: index < shown ? 0 : 8)
            }
        }
        .padding(18)
        .background(Theme.card)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .animation(.spring(duration: 0.4), value: shown)
        .task {
            if reduceMotion {
                shown = items.count
                return
            }
            try? await Task.sleep(nanoseconds: 900_000_000)
            for index in 1...max(1, items.count) {
                shown = index
                try? await Task.sleep(nanoseconds: 380_000_000)
            }
        }
    }
}

#Preview {
    IntroView()
        .environment(AppStore())
}
