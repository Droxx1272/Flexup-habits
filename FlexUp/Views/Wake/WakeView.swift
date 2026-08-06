import SwiftUI
import UIKit

/// The morning pillar: wake alarm + check-in, and the night pillar right
/// beside it: bedtime reminder + sleep log. Win the morning, protect the
/// night — one screen, one toggle.
struct WakeView: View {
    enum Section: String, CaseIterable, Identifiable {
        case wake = "Wake"
        case sleep = "Sleep"
        var id: String { rawValue }
    }

    @Environment(AppStore.self) private var store
    @State private var section: Section = .wake
    @State private var showSetup = false
    @State private var showProofCamera = false
    @State private var showBedtimeSetup = false
    @State private var showLogSleep = false

    private let calendar = Calendar.current

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    ScreenHeader(title: "Wake", tagline: "Win the morning first.")
                    SegmentPills(items: Section.allCases, selection: $section)

                    switch section {
                    case .wake:
                        heroCard
                        checkInCard
                        streakCard
                    case .sleep:
                        bedtimeCard
                        logSleepCard
                        sleepHistoryCard
                    }
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
            .sheet(isPresented: $showBedtimeSetup) {
                BedtimeSetupSheet()
            }
            .sheet(isPresented: $showLogSleep) {
                LogSleepSheet()
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

    // MARK: Bedtime

    private var bedtimeCard: some View {
        FlexCard {
            VStack(alignment: .leading, spacing: 12) {
                Text(store.bedtime.enabled ? "TONIGHT, WIND DOWN AT" : "PICK YOUR BEDTIME")
                    .font(.flexMono(11))
                    .tracking(2)
                    .foregroundStyle(Theme.inkSubtle)

                Text(store.bedtime.timeLabel)
                    .font(.flexDisplay(58))
                    .foregroundStyle(Theme.ink)
                    .minimumScaleFactor(0.5)
                    .lineLimit(1)

                Text("A consistent bedtime is what makes the wake-up easy.")
                    .font(.flexCaption())
                    .foregroundStyle(Theme.inkSubtle)

                Button(store.bedtime.enabled ? "Edit bedtime" : "Set bedtime") {
                    showBedtimeSetup = true
                }
                .buttonStyle(store.bedtime.enabled ? SecondaryButtonStyle() : SecondaryButtonStyle(tint: Theme.background, background: Theme.ink))
            }
        }
    }

    // MARK: Log sleep

    private var logSleepCard: some View {
        VStack(spacing: 10) {
            Button {
                showLogSleep = true
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "moon.stars")
                    Text("Log last night's sleep")
                }
            }
            .buttonStyle(PrimaryButtonStyle())

            HStack(spacing: 10) {
                TrackStat(value: lastNightLabel, label: "Last night")
                TrackStat(value: averageLabel, label: "7-day avg")
                TrackStat(value: "\(store.sleepLogStreak)", label: "Night streak")
            }
        }
    }

    private var lastNightLabel: String {
        guard let last = store.lastNightSleep else { return "—" }
        return String(format: "%.1fh", last.hours)
    }

    private var averageLabel: String {
        guard let average = store.averageSleepHours() else { return "—" }
        return String(format: "%.1fh", average)
    }

    // MARK: Sleep history

    private var sleepHistoryCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "History", subtitle: store.sleepSessions.isEmpty ? nil : "Most recent first.")
            if store.sleepSessions.isEmpty {
                EmptyStateCard(
                    icon: "moon.zzz",
                    title: "No nights logged yet",
                    message: "Log tonight's sleep tomorrow morning — even a rough estimate builds the picture."
                )
            } else {
                ForEach(store.sleepSessions.sorted { $0.wakeTime > $1.wakeTime }) { session in
                    sleepRow(session)
                }
            }
        }
    }

    private func sleepRow(_ session: SleepSession) -> some View {
        FlexCard(padding: 14) {
            HStack(spacing: 14) {
                IconBadge(systemName: "moon.stars.fill", tint: Theme.amber, size: 42)
                VStack(alignment: .leading, spacing: 3) {
                    Text(session.durationLabel)
                        .font(.flexStat(18))
                        .foregroundStyle(Theme.ink)
                    Text(session.wakeTime.formatted(.dateTime.weekday(.abbreviated).day().month()).uppercased())
                        .font(.flexMono(9))
                        .tracking(1)
                        .foregroundStyle(Theme.inkSubtle)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 3) {
                    Text(session.quality.emoji)
                        .font(.system(size: 20))
                    Text(session.quality.label.uppercased())
                        .font(.flexMono(9))
                        .tracking(1)
                        .foregroundStyle(Theme.inkSubtle)
                }
            }
        }
    }
}

// MARK: - Setup sheet

struct WakeSetupSheet: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    @State private var time = Date.now
    @State private var days: Set<Int> = [2, 3, 4, 5, 6]
    @State private var enabled = true
    @State private var previewSent = false

    private let calendar = Calendar.current
    private let dayLetters = ["S", "M", "T", "W", "T", "F", "S"]

    /// iOS 26 gets a real AlarmKit alarm; older systems get the stacked
    /// notification burst. Say which, honestly.
    private var alarmBehaviourNote: String {
        if #available(iOS 26.0, *) {
            "Rings like a real alarm until you stop it."
        } else {
            "Buzzes every 40 seconds until you check in."
        }
    }

    private var alarmCapabilityNote: String {
        if #available(iOS 26.0, *) {
            "Your wake-up rings at full volume even on silent, like the Clock app. The preview above plays the notification sound instead."
        } else {
            "Your phone must be off silent to hear it — before iOS 26, only the Clock app can ring through the mute switch."
        }
    }

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
                    Text("Wake-up alarm")
                        .font(.flexBodyBold())
                        .foregroundStyle(Theme.ink)
                    Text(alarmBehaviourNote)
                        .font(.flexCaption())
                        .foregroundStyle(Theme.inkSubtle)
                }
            }
            .tint(Theme.accent)
            .padding(14)
            .background(Theme.card)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

            VStack(spacing: 8) {
                Button {
                    store.previewWakeAlarm()
                    previewSent = true
                    Task {
                        try? await Task.sleep(nanoseconds: 6_000_000_000)
                        previewSent = false
                    }
                } label: {
                    Label(previewSent ? "Listen — 5 seconds…" : "Preview the alarm", systemImage: "speaker.wave.3")
                }
                .buttonStyle(SecondaryButtonStyle())
                .disabled(previewSent)

                Text(alarmCapabilityNote)
                    .font(.flexCaption())
                    .foregroundStyle(Theme.inkSubtle)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 8)
            }

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

// MARK: - Bedtime setup sheet

struct BedtimeSetupSheet: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    @State private var time = Date.now
    @State private var days: Set<Int> = [1, 2, 3, 4, 5, 6, 7]
    @State private var enabled = true

    private let calendar = Calendar.current
    private let dayLetters = ["S", "M", "T", "W", "T", "F", "S"]

    var body: some View {
        VStack(spacing: 18) {
            Capsule()
                .fill(Theme.inkSubtle.opacity(0.3))
                .frame(width: 36, height: 5)
                .padding(.top, 10)

            Text("BEDTIME")
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
                    Text("Wind-down reminder")
                        .font(.flexBodyBold())
                        .foregroundStyle(Theme.ink)
                    Text("Fires at your bedtime on scheduled days.")
                        .font(.flexCaption())
                        .foregroundStyle(Theme.inkSubtle)
                }
            }
            .tint(Theme.accent)
            .padding(14)
            .background(Theme.card)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

            Spacer()

            Button("Save bedtime") {
                var config = store.bedtime
                config.hour = calendar.component(.hour, from: time)
                config.minute = calendar.component(.minute, from: time)
                config.days = days
                config.enabled = enabled
                store.bedtime = config
                store.updateBedtimeSchedule()
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
            time = store.bedtime.timeToday
            days = store.bedtime.days
            enabled = store.bedtime.enabled || store.sleepSessions.isEmpty
        }
    }
}

// MARK: - Log sleep sheet

struct LogSleepSheet: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    @State private var bedtimeDate = Date.now
    @State private var wakeDate = Date.now
    @State private var quality: SleepQuality = .good

    private var duration: TimeInterval {
        max(0, wakeDate.timeIntervalSince(bedtimeDate))
    }

    private var durationLabel: String {
        let totalMinutes = Int(duration / 60)
        return "\(totalMinutes / 60)h \(totalMinutes % 60)m"
    }

    var body: some View {
        VStack(spacing: 18) {
            Capsule()
                .fill(Theme.inkSubtle.opacity(0.3))
                .frame(width: 36, height: 5)
                .padding(.top, 10)

            Text("LOG LAST NIGHT")
                .font(.flexMono(12))
                .tracking(2)
                .foregroundStyle(Theme.ink)

            Text(durationLabel)
                .font(.flexDisplay(40))
                .foregroundStyle(Theme.ink)

            HStack(spacing: 10) {
                VStack(spacing: 6) {
                    Text("BEDTIME")
                        .font(.flexMono(9))
                        .tracking(1)
                        .foregroundStyle(Theme.inkSubtle)
                    DatePicker("Bedtime", selection: $bedtimeDate, displayedComponents: [.date, .hourAndMinute])
                        .labelsHidden()
                        .datePickerStyle(.compact)
                }
                .frame(maxWidth: .infinity)

                VStack(spacing: 6) {
                    Text("WAKE TIME")
                        .font(.flexMono(9))
                        .tracking(1)
                        .foregroundStyle(Theme.inkSubtle)
                    DatePicker("Wake time", selection: $wakeDate, displayedComponents: [.date, .hourAndMinute])
                        .labelsHidden()
                        .datePickerStyle(.compact)
                }
                .frame(maxWidth: .infinity)
            }
            .padding(14)
            .background(Theme.card)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

            VStack(alignment: .leading, spacing: 8) {
                Text("HOW DID YOU SLEEP?")
                    .font(.flexMono(10))
                    .tracking(2)
                    .foregroundStyle(Theme.inkSubtle)
                HStack(spacing: 8) {
                    ForEach(SleepQuality.allCases) { option in
                        qualityChip(option)
                    }
                }
            }

            Spacer()

            Button("Save") {
                store.logSleep(bedtime: bedtimeDate, wakeTime: wakeDate, quality: quality)
                dismiss()
            }
            .buttonStyle(PrimaryButtonStyle())
            .disabled(duration <= 0)
            .opacity(duration > 0 ? 1 : 0.4)
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 12)
        .background(Theme.background)
        .presentationDetents([.large])
        .onAppear {
            let calendar = Calendar.current
            let defaultWake = store.wake.timeToday
            wakeDate = defaultWake
            bedtimeDate = calendar.date(byAdding: .day, value: -1, to: store.bedtime.timeToday) ?? defaultWake.addingTimeInterval(-8 * 3600)
        }
    }

    private func qualityChip(_ option: SleepQuality) -> some View {
        let isSelected = quality == option
        return Button {
            quality = option
        } label: {
            VStack(spacing: 6) {
                Text(option.emoji)
                    .font(.system(size: 22))
                Text(option.label.uppercased())
                    .font(.flexMono(9))
                    .tracking(1)
            }
            .foregroundStyle(isSelected ? Theme.background : Theme.ink)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(isSelected ? Theme.ink : Theme.card)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    WakeView()
        .environment(AppStore())
}
