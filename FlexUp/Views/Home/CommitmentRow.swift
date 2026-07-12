import SwiftUI

struct CommitmentRow: View {
    let commitment: Commitment
    var onOpen: () -> Void

    var body: some View {
        Button(action: onOpen) {
            HStack(spacing: 12) {
                IconBadge(
                    systemName: commitment.category.icon,
                    tint: commitment.status == .completed ? Theme.inkSubtle : Theme.accent,
                    size: 42
                )
                VStack(alignment: .leading, spacing: 4) {
                    Text(commitment.title)
                        .font(.flexBodyBold())
                        .foregroundStyle(Theme.ink)
                        .strikethrough(commitment.status == .completed, color: Theme.inkSubtle)
                        .lineLimit(1)
                    HStack(spacing: 8) {
                        Text(commitment.date, style: .time)
                            .font(.flexCaption())
                            .foregroundStyle(Theme.inkSubtle)
                        StatusPill(status: commitment.status)
                    }
                }
                Spacer()
                Image(systemName: commitment.status == .completed ? "checkmark.circle.fill" : "chevron.right")
                    .font(commitment.status == .completed ? .title2 : .footnote.weight(.semibold))
                    .foregroundStyle(commitment.status == .completed ? Theme.accent : Theme.inkSubtle)
            }
            .padding(14)
            .background(Theme.card)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .shadow(color: .black.opacity(0.04), radius: 8, y: 3)
            .opacity(commitment.status == .completed ? 0.75 : 1)
        }
        .buttonStyle(.plain)
    }
}
