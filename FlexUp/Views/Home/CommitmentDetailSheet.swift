import SwiftUI

/// Do → Verify. Timer verification runs a real countdown; honor completes
/// directly; backend-dependent methods (photo, partner, GPS) fall back to
/// honor in v1 and say so honestly.
struct CommitmentDetailSheet: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    let commitment: Commitment

    @State private var showTimer = false
    @State private var showReschedule = false
    @State private var newDate = Date()

    private var live: Commitment { store.liveCommitment(commitment) }

    var body: some View {
        VStack(spacing: 16) {
            Capsule()
                .fill(Theme.inkSubtle.opacity(0.3))
                .frame(width: 36, height: 5)
                .padding(.top, 10)

            IconBadge(systemName: live.category.icon, size: 64)
                .padding(.top, 6)

            Text(live.title)
                .font(.flexHeading())
                .foregroundStyle(Theme.ink)
                .multilineTextAlignment(.center)

            HStack(spacing: 8) {
                TagPill(text: live.date.formatted(.dateTime.weekday(.abbreviated).hour().minute()))
                TagPill(text: "\(live.durationMinutes) min")
                TagPill(text: live.verification.label, tint: Theme.accent)
                StatusPill(status: live.status)
            }

            if needsFallbackNote {
                Text("\(live.verification.label) verification arrives with the FlexUp backend — completing on honor for now.")
                    .font(.flexCaption())
                    .foregroundStyle(Theme.inkSubtle)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 20)
            }

            Spacer()

            if live.status != .completed && live.status != .missed {
                if live.verification == .timer {
                    Button {
                        showTimer = true
                    } label: {
                        Label("Start \(live.durationMinutes)-minute timer", systemImage: "timer")
                    }
                    .buttonStyle(PrimaryButtonStyle())
                } else {
                    Button("Mark completed") {
                        store.complete(live)
                        dismiss()
                    }
                    .buttonStyle(PrimaryButtonStyle())
                }

                HStack(spacing: 10) {
                    Button("Reschedule") {
                        newDate = live.date
                        showReschedule = true
                    }
                    .buttonStyle(SecondaryButtonStyle())

                    Button("Skip") {
                        store.markMissed(live)
                        dismiss()
                    }
                    .buttonStyle(SecondaryButtonStyle(tint: Theme.danger, background: Theme.danger.opacity(0.1)))
                }
            } else if live.status == .completed {
                Label("Completed \(live.completedAt?.formatted(date: .omitted, time: .shortened) ?? "")", systemImage: "checkmark.circle.fill")
                    .font(.flexBodyBold())
                    .foregroundStyle(Theme.accent)
            }
        }
        .padding(20)
        .presentationDetents([.medium])
        .presentationBackground(Theme.background)
        .sheet(isPresented: $showTimer) {
            TimerSheet(minutes: live.durationMinutes, title: live.title) {
                store.complete(live)
                dismiss()
            }
        }
        .sheet(isPresented: $showReschedule) {
            RescheduleSheet(date: $newDate) {
                store.reschedule(live, to: newDate)
                dismiss()
            }
        }
    }

    private var needsFallbackNote: Bool {
        live.status != .completed &&
        (live.verification == .photo || live.verification == .partner || live.verification == .location)
    }
}

// MARK: - Timer verification

struct TimerSheet: View {
    let minutes: Int
    let title: String
    var onFinish: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var remaining: Int
    @State private var running = true

    private let ticker = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    init(minutes: Int, title: String, onFinish: @escaping () -> Void) {
        self.minutes = minutes
        self.title = title
        self.onFinish = onFinish
        _remaining = State(initialValue: max(60, minutes * 60))
    }

    private var total: Int { max(60, minutes * 60) }

    private var timeText: String {
        String(format: "%02d:%02d", remaining / 60, remaining % 60)
    }

    var body: some View {
        VStack(spacing: 24) {
            Text(title)
                .font(.flexSection())
                .foregroundStyle(Theme.ink)
                .padding(.top, 28)

            ZStack {
                ProgressRing(progress: 1 - Double(remaining) / Double(total), lineWidth: 12)
                    .frame(width: 210, height: 210)
                VStack(spacing: 4) {
                    Text(timeText)
                        .font(.system(size: 44, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(Theme.ink)
                    Text(running ? "In progress" : "Paused")
                        .font(.flexCaption())
                        .foregroundStyle(Theme.inkSubtle)
                }
            }

            Text("Phone down. Go do the thing — we'll keep count.")
                .font(.flexBody())
                .foregroundStyle(Theme.inkSubtle)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 30)

            Spacer()

            Button(running ? "Pause" : "Resume") {
                running.toggle()
            }
            .buttonStyle(SecondaryButtonStyle())

            Button("Finish now") {
                onFinish()
                dismiss()
            }
            .buttonStyle(PrimaryButtonStyle())
        }
        .padding(20)
        .background(Theme.background)
        .interactiveDismissDisabled(true)
        .overlay(alignment: .topTrailing) {
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.title2)
                    .foregroundStyle(Theme.inkSubtle)
            }
            .padding(16)
        }
        .onReceive(ticker) { _ in
            guard running, remaining > 0 else { return }
            remaining -= 1
            if remaining == 0 {
                onFinish()
                dismiss()
            }
        }
    }
}

// MARK: - Reschedule

struct RescheduleSheet: View {
    @Binding var date: Date
    var onConfirm: () -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 20) {
            Text("Move it, don't lose it")
                .font(.flexSection())
                .foregroundStyle(Theme.ink)
                .padding(.top, 24)
            Text("Rescheduling on purpose beats missing by accident.")
                .font(.flexCaption())
                .foregroundStyle(Theme.inkSubtle)

            DatePicker("New time", selection: $date, in: Date.now...)
                .datePickerStyle(.graphical)
                .tint(Theme.accent)

            Button("Reschedule") {
                onConfirm()
                dismiss()
            }
            .buttonStyle(PrimaryButtonStyle())
        }
        .padding(20)
        .background(Theme.background)
        .presentationDetents([.large])
    }
}
