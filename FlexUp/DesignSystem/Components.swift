import SwiftUI

// MARK: - Card

struct FlexCard<Content: View>: View {
    private let padding: CGFloat
    private let content: Content

    init(padding: CGFloat = 18, @ViewBuilder content: () -> Content) {
        self.padding = padding
        self.content = content()
    }

    var body: some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.card)
            .clipShape(RoundedRectangle(cornerRadius: Theme.cornerRadius, style: .continuous))
            .overlay(
                // Hairline keeps cards defined in dark mode where shadows vanish.
                RoundedRectangle(cornerRadius: Theme.cornerRadius, style: .continuous)
                    .stroke(Theme.ink.opacity(0.05), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.05), radius: 14, y: 6)
    }
}

// MARK: - Buttons

/// Solid ink pill — the one primary CTA per screen.
struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.flexBodyBold())
            .foregroundStyle(Theme.background)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 17)
            .background(Theme.ink.opacity(configuration.isPressed ? 0.85 : 1))
            .clipShape(Capsule())
            .shadow(color: Theme.ink.opacity(configuration.isPressed ? 0.12 : 0.25), radius: 10, y: 4)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.spring(duration: 0.2), value: configuration.isPressed)
    }
}

struct SecondaryButtonStyle: ButtonStyle {
    var tint: Color = Theme.ink
    var background: Color = Theme.ink.opacity(0.08)

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.flexBodyBold())
            .foregroundStyle(tint)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(background.opacity(configuration.isPressed ? 0.6 : 1))
            .clipShape(Capsule())
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.spring(duration: 0.2), value: configuration.isPressed)
    }
}

// MARK: - Pills & badges

struct StatusPill: View {
    let status: CommitmentStatus

    var body: some View {
        Text(status.label)
            .font(.system(.caption2, design: .rounded, weight: .semibold))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(status.tint.opacity(0.14))
            .foregroundStyle(status.tint)
            .clipShape(Capsule())
    }
}

struct TagPill: View {
    let text: String
    var tint: Color = Theme.inkSubtle

    var body: some View {
        Text(text)
            .font(.system(.caption2, design: .rounded, weight: .semibold))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(tint.opacity(0.12))
            .foregroundStyle(tint)
            .clipShape(Capsule())
    }
}

struct IconBadge: View {
    let systemName: String
    var tint: Color = Theme.accent
    var size: CGFloat = 44

    var body: some View {
        Image(systemName: systemName)
            .font(.system(size: size * 0.42, weight: .semibold))
            .foregroundStyle(tint)
            .frame(width: size, height: size)
            .background(tint.opacity(0.12))
            .clipShape(RoundedRectangle(cornerRadius: size * 0.32, style: .continuous))
    }
}

// MARK: - Progress ring

struct ProgressRing: View {
    let progress: Double
    var lineWidth: CGFloat = 9

    var body: some View {
        ZStack {
            Circle()
                .stroke(Theme.accentSoft, lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: max(0.001, progress))
                .stroke(Theme.accent, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.spring(duration: 0.6), value: progress)
        }
    }
}

// MARK: - Avatars

struct AvatarCircle: View {
    let name: String
    var size: CGFloat = 30

    private var initials: String {
        let parts = name.split(separator: " ")
        let letters = parts.prefix(2).compactMap { $0.first }
        return String(letters).uppercased()
    }

    private var color: Color {
        let palette: [Color] = [Theme.accent, Theme.amber, .indigo, .teal, .brown]
        // Stable across launches (String.hashValue is seeded per-process).
        let sum = name.unicodeScalars.reduce(0) { $0 + Int($1.value) }
        return palette[sum % palette.count]
    }

    var body: some View {
        Text(initials)
            .font(.system(size: size * 0.38, weight: .bold, design: .rounded))
            .foregroundStyle(.white)
            .frame(width: size, height: size)
            .background(color.gradient)
            .clipShape(Circle())
    }
}

struct AvatarStack: View {
    let names: [String]
    var size: CGFloat = 28
    var maxShown: Int = 4

    var body: some View {
        HStack(spacing: -size * 0.3) {
            ForEach(Array(names.prefix(maxShown).enumerated()), id: \.offset) { _, name in
                AvatarCircle(name: name, size: size)
                    .overlay(Circle().stroke(Theme.card, lineWidth: 2))
            }
            if names.count > maxShown {
                Text("+\(names.count - maxShown)")
                    .font(.system(size: size * 0.36, weight: .bold, design: .rounded))
                    .foregroundStyle(Theme.inkSubtle)
                    .frame(width: size, height: size)
                    .background(Theme.accentSoft)
                    .clipShape(Circle())
                    .overlay(Circle().stroke(Theme.card, lineWidth: 2))
            }
        }
    }
}

// MARK: - Screen header

/// Huge uppercase title with a monospaced tagline underneath —
/// "PROFILE / YOUR GAME. YOUR JOURNEY."
struct ScreenHeader: View {
    let title: String
    let tagline: String
    /// Messages, notifications and your profile photo, top right.
    var showsActions = true

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .center, spacing: 8) {
                Text(title.uppercased())
                    .font(.flexDisplay(40))
                    .foregroundStyle(Theme.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                Spacer(minLength: 8)
                if showsActions {
                    HeaderActions()
                }
            }
            HStack(spacing: 8) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(Theme.accent)
                    .frame(width: 22, height: 3)
                Text(tagline.uppercased())
                    .font(.flexMono(12))
                    .tracking(2)
                    .foregroundStyle(Theme.inkSubtle)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 8)
    }
}

// MARK: - Section header

struct SectionHeader: View {
    let title: String
    var subtitle: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title.uppercased())
                .font(.flexMono(13))
                .tracking(2)
                .foregroundStyle(Theme.ink)
            if let subtitle {
                Text(subtitle)
                    .font(.flexCaption())
                    .foregroundStyle(Theme.inkSubtle)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Empty state

struct EmptyStateCard: View {
    let icon: String
    let title: String
    let message: String
    var actionLabel: String?
    var action: (() -> Void)?

    var body: some View {
        FlexCard {
            VStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 30, weight: .medium))
                    .foregroundStyle(Theme.inkSubtle)
                Text(title)
                    .font(.flexBodyBold())
                    .foregroundStyle(Theme.ink)
                Text(message)
                    .font(.flexCaption())
                    .foregroundStyle(Theme.inkSubtle)
                    .multilineTextAlignment(.center)
                if let actionLabel, let action {
                    Button(actionLabel, action: action)
                        .buttonStyle(SecondaryButtonStyle())
                        .padding(.top, 4)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
        }
    }
}

// MARK: - Segment pills

/// Capsule segmented control in the FlexUp voice — mono uppercase labels,
/// ink-filled selection.
struct SegmentPills<T: Identifiable & Hashable & RawRepresentable>: View where T.RawValue == String {
    let items: [T]
    @Binding var selection: T

    var body: some View {
        HStack(spacing: 6) {
            ForEach(items) { item in
                Button {
                    withAnimation(.spring(duration: 0.25)) { selection = item }
                } label: {
                    Text(item.rawValue.uppercased())
                        .font(.flexMono(11))
                        .tracking(1.5)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 11)
                        .background(selection == item ? Theme.ink : .clear)
                        .foregroundStyle(selection == item ? Theme.background : Theme.inkSubtle)
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(4)
        .background(Theme.card)
        .clipShape(Capsule())
    }
}

// MARK: - Selectable chip

struct SelectableChip: View {
    let label: String
    var icon: String?
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 5) {
                if let icon {
                    Image(systemName: icon)
                        .font(.system(size: 12, weight: .semibold))
                }
                Text(label)
                    .font(.flexCaption())
            }
            .padding(.horizontal, 13)
            .padding(.vertical, 8)
            .background(isSelected ? Theme.accent : Theme.card)
            .foregroundStyle(isSelected ? .white : Theme.ink)
            .clipShape(Capsule())
            .overlay(Capsule().stroke(isSelected ? .clear : Theme.inkSubtle.opacity(0.25), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }
}
