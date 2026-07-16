import SwiftUI
import UIKit

/// The morning pillar. Set a wake time, get the alarm, check in when you're
/// up — optionally with a photo of the sky. No snoozing. No backup alarms.
struct WakeView: View {
    @Environment(AppStore.self) private var store
    @State private var showSetup = false
    @State private var showProofCamera = false

    private let calendar = Calendar.current

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    ScreenHeader(title: "Wake", tagline: "Win the morning first.")
                    heroCard
                    checkInCard
                    streakCard
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 24)
            }
            .scrollIndicators(.hidden)
            .background(Theme.background)
            .toolbar(.hidden, for: .navigationBar)
            .sheet(isPresented: $showSetup) {
                WakeSetupSheet()
            }
            .fullScreenCover(isPresented: $showProofCamera) {
                CameraPicker { image in
                    if let data = image.flexJPEGData() {
                        store.checkInWake(withPhoto: data)
                    }
                }
                .ignoresSafeArea()
            }
        }
    }

    // MARK: Hero

    private var heroCard: some View {
        FlexCard {
            VStack(alignment: .leading, spacing: 12) {
                Text(store.wake.enabled ? "TOMORROW, YOU WILL WAKE UP AT" : "PICK YOUR WAKE-UP TIME")
                    .font(.flexMono(11))
                    .tracking(2)
                    .foregroundStyle(Theme.inkSubtle)

                Text(store.wake.timeLabel)
                    .font(.flexDisplay(58))
                    .foregroundStyle(Theme.ink)
                    .minimumScaleFactor(0.5)
                    .lineLimit(1)

                HStack(spacing: 14) {
                    flowStep(icon: "alarm", label: "Alarm rings")
                    Image(systemName: "arrow.right")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Theme.inkSubtle)
                    flowStep(icon: "camera", label: "Check in")
                    Image(systemName: "arrow.right")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Theme.inkSubtle)
                    flowStep(icon: "sun.max", label: "Day's yours")
                }
                .frame(maxWidth: .infinity)

                Text("No snoozing. No backup alarms.")
                    .font(.flexCaption())
                    .foregroundStyle(Theme.inkSubtle)
                    .frame(maxWidth: .infinity, alignment: .center)

                Button(store.wake.enabled ? "Edit wake-up" : "Set wake-up") {
                    showSetup = true
                }
                .buttonStyle(store.wake.enabled ? SecondaryButtonStyle() : SecondaryButtonStyle(tint: Theme.background, background: Theme.ink))
            }
        }
    }

    private func flowStep(icon: String, label: String) -> some View {
        VStack(spacing: 6) {
            ZStack {
                Circle()
                    .fill(Theme.ink)
                    .frame(width: 44, height: 44)
                Image(systemName: icon)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(Theme.background)
            }
            Text(label)
                .font(.flexCaption())
                .foregroundStyle(Theme.inkSubtle)
        }
    }

    // MARK: Check-in

    private var checkInCard: some View {
        Group {
            if store.isWakeCheckedInToday {
                FlexCard {
                    HStack(spacing: 14) {
                        ZStack {
                            Circle()
                                .fill(Theme.accentSoft)
                                .frame(width: 48, height: 48)
                            Image(systemName: "checkmark")
                                .font(.system(size: 20, weight: .bold))
                                .foregroundStyle(Theme.accent)
                        }
                        VStack(alignment: .leading, spacing: 3) {
                            Text("Checked in. Morning won.")
                                .font(.flexBodyBold())
                                .foregroundStyle(Theme.ink)
                            Text("SEE YOU TOMORROW AT \(store.wake.timeLabel.uppercased())")
                                .font(.flexMono(9))
                                .tracking(1)
                                .foregroundStyle(Theme.inkSubtle)
                        }
                        Spacer()
                    }
                }
            } else {
                VStack(spacing: 10) {
                    Button {
                        if UIImagePickerController.isSourceTypeAvailable(.camera) {
                            showProofCamera = true
                        } else {
                            store.checkInWake()
                        }
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: "camera")
                            Text("I'm up — photo check-in")
                        }
                    }
                    .buttonStyle(PrimaryButtonStyle())

                    Button("Check in without photo") {
                        store.checkInWake()
                    }
                    .buttonStyle(SecondaryButtonStyle())
                }
            }
        }
    }

    // MARK: Streak

    private var streakCard: some View {
        FlexCard {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Text("YOUR WAKE-UP STREAK")
                        .font(.flexMono(11))
                        .tracking(2)
                        .foregroundStyle(Theme.ink)
                    Spacer()
                    HStack(spacing: 4) {
                        Image(systemName: "flame.fill")
                        Text("\(store.wakeStreak)")
                            .monospacedDigit()
                    }
                    .font(.flexBodyBold())
                    .foregroundStyle(Theme.amber)
                }

                Text("Complete your check-in on scheduled days to build your streak.")
                    .font(.flexCaption())
                    .foregroundStyle(Theme.inkSubtle)

                HStack(spacing: 8) {
                    ForEach(weekDays, id: \.self) { day in
                        dayCircle(day)
                    }
                }
                .frame(maxWidth: .infinity)
            }
        }
    }

    /// The current week, Sunday through Saturday.
    private var weekDays: [Date] {
        guard let start = calendar.dateInterval(of: .weekOfYear, for: .now)?.start else { return [] }
        return (0..<7).compactMap { calendar.date(byAdding: .day, value: $0, to: start) }
    }

    private func dayCircle(_ day: Date) -> some View {
        let weekday = calendar.component(.weekday, from: day)
        let scheduled = store.wake.days.contains(weekday)
        let checked = store.wakeCheckInDays.contains(dayKey(day))
        let isPast = day < calendar.startOfDay(for: .now)
        let letter = day.formatted(.dateTime.weekday(.narrow))

        return ZStack {
            Circle()
                .fill(checked ? Theme.accent : Theme.card)
            if scheduled && !checked {
                Circle()
                    .stroke(isPast ? Theme.danger.opacity(0.5) : Theme.accent.opacity(0.6), lineWidth: 1.5)
            }
            Text(letter)
                .font(.flexMono(12))
                .foregroundStyle(checked ? Theme.background : (scheduled ? Theme.ink : Theme.inkSubtle.opacity(0.5)))
        }
        .frame(width: 40, height: 40)
    }

    private func dayKey(_ date: Date) -> String {
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        return "\(parts.year ?? 0)-\(parts.month ?? 0)-\(parts.day ?? 0)"
    }
}

// MARK: - Setup sheet

struct WakeSetupSheet: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    @State private var time = Date.now
    @State private var days: Set<Int> = [2, 3, 4, 5, 6]
    @State private var enabled = true

    private let calendar = Calendar.current
    private let dayLetters = ["S", "M", "T", "W", "T", "F", "S"]

    var body: some View {
        VStack(spacing: 18) {
            Capsule()
                .fill(Theme.inkSubtle.opacity(0.3))
                .frame(width: 36, height: 5)
                .padding(.top, 10)

            Text("WAKE-UP TIME")
                .font(.flexMono(12))
                .tracking(2)
                .foregroundStyle(Theme.ink)

            DatePicker("Time", selection: $time, displayedComponents: .hourAndMinute)
                .datePickerStyle(.wheel)
                .labelsHidden()

            VStack(spacing: 8) {
                Text("REPEAT ON")
                    .font(.flexMono(10))
                    .tracking(2)
                    .foregroundStyle(Theme.inkSubtle)
                HStack(spacing: 8) {
                    ForEach(1...7, id: \.self) { weekday in
                        Button {
                            if days.contains(weekday) { days.remove(weekday) } else { days.insert(weekday) }
                        } label: {
                            Text(dayLetters[weekday - 1])
                                .font(.flexMono(13))
                                .foregroundStyle(days.contains(weekday) ? Theme.background : Theme.inkSubtle)
                                .frame(width: 38, height: 38)
                                .background(days.contains(weekday) ? Theme.ink : Theme.card)
                                .clipShape(Circle())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            Toggle(isOn: $enabled) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Alarm notification")
                        .font(.flexBodyBold())
                        .foregroundStyle(Theme.ink)
                    Text("Fires at your wake time on scheduled days.")
                        .font(.flexCaption())
                        .foregroundStyle(Theme.inkSubtle)
                }
            }
            .tint(Theme.accent)
            .padding(14)
            .background(Theme.card)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

            Spacer()

            Button("Save wake-up") {
                var config = store.wake
                config.hour = calendar.component(.hour, from: time)
                config.minute = calendar.component(.minute, from: time)
                config.days = days
                config.enabled = enabled
                store.wake = config
                store.updateWakeSchedule()
                dismiss()
            }
            .buttonStyle(PrimaryButtonStyle())
            .disabled(days.isEmpty)
            .opacity(days.isEmpty ? 0.4 : 1)
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 12)
        .background(Theme.background)
        .presentationDetents([.large])
        .onAppear {
            time = store.wake.timeToday
            days = store.wake.days
            // Default the alarm on for first-time setup; respect the saved
            // choice once the feature has been used.
            enabled = store.wake.enabled || store.wakeCheckInDays.isEmpty
        }
    }
}

#Preview {
    WakeView()
        .environment(AppStore())
}
