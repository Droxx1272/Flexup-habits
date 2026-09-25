import SwiftUI

/// The first thing anyone sees: five swipeable pages that say what FlexUp
/// is for and what each pillar does, before asking for an account. Shown
/// once (`AppStore.hasSeenIntro`) and replayable from Stats.
struct IntroView: View {
    @Environment(AppStore.self) private var store
    @State private var page = 0

    fileprivate enum Art {
        case manifesto, wake, move, fuel, progress
    }

    fileprivate struct Page {
        let eyebrow: String
        let title: String
        let body: String
        let art: Art
    }

    private let pages: [Page] = [
        Page(
            eyebrow: "FLEXUP",
            title: "Become who you said you'd be.",
            body: "Most people know what to do. FlexUp is built for the doing — plan it, commit, do it, prove it, repeat.",
            art: .manifesto
        ),
        Page(
            eyebrow: "01 — WAKE",
            title: "Win the morning.",
            body: "Set your wake time once. On iOS 26 it rings like a real alarm, even on silent. Check in when you're up and log how you slept.",
            art: .wake
        ),
        Page(
            eyebrow: "02 — RUN · GYM",
            title: "Move. Lift. Log it.",
            body: "GPS runs with your route, splits and pace. A training log that remembers your last set, times your rest and catches every PR.",
            art: .move
        ),
        Page(
            eyebrow: "03 — DIET",
            title: "Snap the plate.",
            body: "Photo in, itemised estimate out — calories and macros per item. Fix any portion, add the oil the camera missed, track water and protein.",
            art: .fuel
        ),
        Page(
            eyebrow: "04 — PROGRESS",
            title: "Watch yourself change.",
            body: "Every pillar on one page, over a week, a month or a year. Days you didn't log stay empty — no fake numbers, ever.",
            art: .progress
        ),
    ]

    private var isLast: Bool { page == pages.count - 1 }

    var body: some View {
        VStack(spacing: 0) {
            topBar

            TabView(selection: $page) {
                ForEach(pages.indices, id: \.self) { index in
                    pageView(pages[index])
                        .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .animation(.spring(duration: 0.35), value: page)

            bottomBar
        }
        .background(Theme.background)
    }

    // MARK: Chrome

    private var topBar: some View {
        HStack {
            Text(String(format: "%02d / %02d", page + 1, pages.count))
                .font(.flexMono(11))
                .tracking(2)
                .foregroundStyle(Theme.inkSubtle)
                .contentTransition(.numericText())
            Spacer()
            Button("SKIP") {
                store.completeIntro()
            }
            .font(.flexMono(11))
            .tracking(2)
            .foregroundStyle(Theme.inkSubtle)
            .opacity(isLast ? 0 : 1)
            .disabled(isLast)
        }
        .padding(.horizontal, 24)
        .padding(.top, 14)
        .padding(.bottom, 6)
    }

    private var bottomBar: some View {
        VStack(spacing: 18) {
            HStack(spacing: 6) {
                ForEach(pages.indices, id: \.self) { index in
                    Capsule()
                        .fill(index == page ? Theme.ink : Theme.ink.opacity(0.15))
                        .frame(width: index == page ? 26 : 7, height: 7)
                        .onTapGesture { page = index }
                }
            }
            .animation(.spring(duration: 0.3), value: page)

            Button {
                if isLast {
                    store.completeIntro()
                } else {
                    page += 1
                }
            } label: {
                HStack(spacing: 10) {
                    Text(isLast ? "Get started" : "Next")
                    Image(systemName: "arrow.right")
                }
            }
            .buttonStyle(PrimaryButtonStyle())
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 16)
    }

    // MARK: Page

    private func pageView(_ page: Page) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                IntroArtCard(art: page.art)

                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 8) {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Theme.accent)
                            .frame(width: 22, height: 3)
                        Text(page.eyebrow)
                            .font(.flexMono(11))
                            .tracking(2)
                            .foregroundStyle(Theme.accent)
                    }
                    Text(page.title.uppercased())
                        .font(.flexDisplay(36))
                        .foregroundStyle(Theme.ink)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(page.body)
                        .font(.flexBody())
                        .foregroundStyle(Theme.inkSubtle)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 8)
        }
        .scrollIndicators(.hidden)
    }
}

// MARK: - Art

/// The ink card at the top of each page — a small, honest illustration of
/// what that pillar looks like in the app. Animates in each time it shows.
private struct IntroArtCard: View {
    let art: IntroView.Art
    @State private var appeared = false

    var body: some View {
        Group {
            switch art {
            case .manifesto: manifesto
            case .wake: wake
            case .move: move
            case .fuel: fuel
            case .progress: progress
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity, minHeight: 300, alignment: .topLeading)
        .background(Theme.ink)
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .onAppear {
            appeared = false
            withAnimation(.spring(duration: 0.5).delay(0.05)) { appeared = true }
        }
        .onDisappear { appeared = false }
    }

    /// Staggered rise-in for the nth element.
    private func rise(_ index: Int) -> some ViewModifier {
        RiseIn(visible: appeared, delay: Double(index) * 0.07)
    }

    // Manifesto

    private var manifesto: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(["PLAN.", "COMMIT.", "DO.", "VERIFY."].enumerated()), id: \.offset) { index, word in
                Text(word)
                    .font(.flexDisplay(46))
                    .foregroundStyle(index == 3 ? Theme.accent : Theme.background)
                    .modifier(rise(index))
            }
            Spacer(minLength: 18)
            HStack(spacing: 8) {
                Image(systemName: "arrow.triangle.2.circlepath")
                Text("CELEBRATE · REPEAT")
            }
            .font(.flexMono(11))
            .tracking(2)
            .foregroundStyle(Theme.background.opacity(0.6))
            .modifier(rise(4))
        }
    }

    // Wake

    private var wake: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("ALARM")
                .font(.flexMono(11))
                .tracking(2)
                .foregroundStyle(Theme.background.opacity(0.55))
            Text("06:30")
                .font(.flexDisplay(84))
                .foregroundStyle(Theme.background)
                .modifier(rise(0))
            HStack(spacing: 6) {
                ForEach(Array(["M", "T", "W", "T", "F", "S", "S"].enumerated()), id: \.offset) { index, letter in
                    Text(letter)
                        .font(.flexMono(11))
                        .foregroundStyle(index < 5 ? Theme.ink : Theme.background.opacity(0.5))
                        .frame(width: 30, height: 30)
                        .background(index < 5 ? Theme.accent : Theme.background.opacity(0.1))
                        .clipShape(Circle())
                        .modifier(rise(index + 1))
                }
            }
            Spacer(minLength: 6)
            HStack(spacing: 8) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(Theme.accent)
                Text("UP AT 06:34 · 7H 12M SLEEP")
                    .font(.flexMono(10))
                    .tracking(1.5)
                    .foregroundStyle(Theme.background.opacity(0.8))
            }
            .modifier(rise(8))
        }
    }

    // Run + Gym

    private var move: some View {
        VStack(alignment: .leading, spacing: 16) {
            RouteSketch()
                .trim(from: 0, to: appeared ? 1 : 0)
                .stroke(Theme.accent, style: StrokeStyle(lineWidth: 4, lineCap: .round, lineJoin: .round))
                .frame(height: 110)
                .animation(.easeInOut(duration: 1.1), value: appeared)

            HStack(spacing: 0) {
                artStat("5.24", "KM")
                artStat("27:18", "TIME")
                artStat("5'12\"", "PACE")
            }
            .modifier(rise(1))

            HStack {
                Text("BENCH PRESS")
                    .font(.flexMono(11))
                    .tracking(1.5)
                    .foregroundStyle(Theme.background.opacity(0.8))
                Spacer()
                Text("80 KG × 5")
                    .font(.flexBodyBold())
                    .foregroundStyle(Theme.background)
                Text("PR")
                    .font(.flexMono(9))
                    .tracking(1)
                    .foregroundStyle(Theme.ink)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(Theme.accent)
                    .clipShape(Capsule())
            }
            .padding(12)
            .background(Theme.background.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .modifier(rise(2))
        }
    }

    private func artStat(_ value: String, _ label: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value)
                .font(.flexStat(26))
                .foregroundStyle(Theme.background)
            Text(label)
                .font(.flexMono(9))
                .tracking(1.5)
                .foregroundStyle(Theme.background.opacity(0.55))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // Diet

    private var fuel: some View {
        VStack(alignment: .leading, spacing: 10) {
            plateRow("Dal", "1 bowl", "180", addOn: false).modifier(rise(0))
            plateRow("Rice", "1 cup", "240", addOn: false).modifier(rise(1))
            plateRow("Roti", "2 pieces", "200", addOn: false).modifier(rise(2))
            plateRow("+ Ghee", "1 tbsp", "112", addOn: true).modifier(rise(3))
            Spacer(minLength: 4)
            HStack(alignment: .firstTextBaseline) {
                Text("732")
                    .font(.flexDisplay(44))
                    .foregroundStyle(Theme.background)
                Text("KCAL")
                    .font(.flexMono(11))
                    .tracking(2)
                    .foregroundStyle(Theme.background.opacity(0.55))
                Spacer()
                Text("P 26 · C 118 · F 21")
                    .font(.flexMono(10))
                    .tracking(1)
                    .foregroundStyle(Theme.accent)
            }
            .modifier(rise(4))
        }
    }

    private func plateRow(_ name: String, _ portion: String, _ kcal: String, addOn: Bool) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 1) {
                Text(name)
                    .font(.flexBodyBold())
                    .foregroundStyle(addOn ? Theme.amber : Theme.background)
                Text(portion.uppercased())
                    .font(.flexMono(9))
                    .tracking(1)
                    .foregroundStyle(Theme.background.opacity(0.5))
            }
            Spacer()
            Text(kcal)
                .font(.flexStat(18))
                .foregroundStyle(Theme.background)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Theme.background.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    // Progress

    private var progress: some View {
        let heights: [CGFloat] = [0.35, 0.5, 0.42, 0.62, 0.58, 0.78, 0.7, 0.9]
        return VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                Text("86%")
                    .font(.flexDisplay(60))
                    .foregroundStyle(Theme.background)
                Text("FOLLOW-THROUGH")
                    .font(.flexMono(10))
                    .tracking(1.5)
                    .foregroundStyle(Theme.background.opacity(0.55))
            }
            .modifier(rise(0))
            HStack(alignment: .bottom, spacing: 8) {
                ForEach(heights.indices, id: \.self) { index in
                    RoundedRectangle(cornerRadius: 5, style: .continuous)
                        .fill(index == heights.count - 1 ? Theme.accent : Theme.background.opacity(0.22))
                        .frame(height: appeared ? 130 * heights[index] : 6)
                        .frame(maxWidth: .infinity)
                        .animation(.spring(duration: 0.6).delay(Double(index) * 0.05), value: appeared)
                }
            }
            .frame(height: 130, alignment: .bottom)
            Text("WAKE · SLEEP · RUN · GYM · DIET · BODY")
                .font(.flexMono(9))
                .tracking(1.5)
                .foregroundStyle(Theme.background.opacity(0.55))
                .modifier(rise(2))
        }
    }
}

private struct RiseIn: ViewModifier {
    let visible: Bool
    let delay: Double

    func body(content: Content) -> some View {
        content
            .opacity(visible ? 1 : 0)
            .offset(y: visible ? 0 : 14)
            .animation(.spring(duration: 0.45).delay(delay), value: visible)
    }
}

/// A hand-drawn-looking run route for the Run page's illustration.
private struct RouteSketch: Shape {
    func path(in rect: CGRect) -> Path {
        let points: [CGPoint] = [
            CGPoint(x: 0.02, y: 0.85), CGPoint(x: 0.14, y: 0.62), CGPoint(x: 0.22, y: 0.7),
            CGPoint(x: 0.34, y: 0.38), CGPoint(x: 0.47, y: 0.45), CGPoint(x: 0.55, y: 0.18),
            CGPoint(x: 0.68, y: 0.3), CGPoint(x: 0.78, y: 0.12), CGPoint(x: 0.9, y: 0.4),
            CGPoint(x: 0.98, y: 0.22),
        ].map { CGPoint(x: rect.minX + $0.x * rect.width, y: rect.minY + $0.y * rect.height) }

        var path = Path()
        path.move(to: points[0])
        for index in 1..<points.count {
            let previous = points[index - 1]
            let current = points[index]
            let mid = CGPoint(x: (previous.x + current.x) / 2, y: (previous.y + current.y) / 2)
            path.addQuadCurve(to: mid, control: previous)
            if index == points.count - 1 {
                path.addQuadCurve(to: current, control: mid)
            }
        }
        return path
    }
}

#Preview {
    IntroView()
        .environment(AppStore())
}
