import SwiftUI
import UIKit
import UserNotifications

/// The morning pillar (wake alarm and check-in) and the night pillar right
/// beside it (bedtime reminder and sleep log), on one screen.
struct WakeView: View {
    enum Section: String, CaseIterable, Identifiable {
        case wake = "Wake"
        case sleep = "Sleep"
        var id: String { rawValue }
    }

    @Environment(AppStore.self) private var store
    @Environment(\.openURL) private var openURL
    @Environment(\.scenePhase) private var scenePhase
    @State private var section: Section = .wake
    /// Notifications switched off in Settings. Without AlarmKit that means
    /// the wake-up can't make a sound at all, so it has to be said.
    @State private var notificationsDenied = false
    @State private var showSetup = false
    @State private var showBedtimeSetup = false
    @State private var showLogSleep = false

    private let calendar = Calendar.current

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    ScreenHeader(title: "Wake", tagline: headerStatus)
                    SegmentPills(items: Section.allCases, selection: $section)

                    switch section {
                    case .wake:
                        if store.wake.enabled && !store.isWakeAlarmReal && notificationsDenied {
                            blockedCard
                        } else if store.wake.enabled, let issue = store.wakeAlarmIssue {
                            alarmIssueCard(issue)
                        }
                        heroCard
                        WakeCheckInCard()
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
            .task { await refreshPermission() }
            .onChange(of: scenePhase) { _, phase in
                // Coming back from Settings should clear the warning at once.
                if phase == .active { Task { await refreshPermission() } }
            }
            .sheet(isPresented: $showBedtimeSetup) {
                BedtimeSetupSheet()
            }
            .sheet(isPresented: $showLogSleep) {
                LogSleepSheet()
            }
        }
    }

    /// Live status under the title: what's set, or how today went.
    private var headerStatus: String {
        if store.isWakeCheckedInToday {
            return store.wakeStreak > 1 ? "Up today · \(store.wakeStreak)-day streak" : "Up today"
        }
        return store.wake.enabled ? "Wake-up at \(store.wake.timeLabel)" : "No wake-up set"
    }

    // MARK: Permission

    private func refreshPermission() async {
        let status = await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
        let wasDenied = notificationsDenied
        notificationsDenied = status == .denied
        // Just switched back on: schedule what couldn't be scheduled before.
        if wasDenied && !notificationsDenied {
            store.updateWakeSchedule()
            store.updateBedtimeSchedule()
        } else if store.wakeAlarmIssue == .alarmsDenied {
            // Alarms may have just been switched on in Settings.
            store.updateWakeSchedule()
        }
    }

    /// iOS 26 could ring a real alarm but can't right now: say why, and
    /// what the wake-up is doing instead.
    private func alarmIssueCard(_ issue: WakeAlarmIssue) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Image(systemName: "alarm.waves.left.and.right")
                    .foregroundStyle(Theme.amber)
                Text(issue == .alarmsDenied ? "Alarms are off for FlexUp" : "The alarm couldn't be set")
                    .font(.flexBodyBold())
                    .foregroundStyle(Theme.ink)
            }
            Text(issueMessage(issue))
                .font(.flexCaption())
                .foregroundStyle(Theme.inkSubtle)
                .fixedSize(horizontal: false, vertical: true)
            if issue == .alarmsDenied {
                Button("Open Settings") {
                    if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
                }
                .buttonStyle(SecondaryButtonStyle(tint: Theme.amber, background: Theme.amberSoft))
            } else {
                Button("Try again") { store.updateWakeSchedule() }
                    .buttonStyle(SecondaryButtonStyle())
            }
        }
        .padding(16)
        .background(Theme.card)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private func issueMessage(_ issue: WakeAlarmIssue) -> String {
        switch issue {
        case .alarmsDenied:
            "Your wake-up is a notification for now, so silent mode will mute it. Turn on Alarms for FlexUp in Settings to make it ring like the Clock app."
        case .failed(let reason):
            "iOS said: \(reason) Your wake-up is a notification for now, so keep your phone off silent."
        }
    }

    private var blockedCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Image(systemName: "bell.slash.fill")
                    .foregroundStyle(Theme.danger)
                Text("Your wake-up can't ring")
                    .font(.flexBodyBold())
                    .foregroundStyle(Theme.ink)
            }
            Text("Notifications for FlexUp are turned off, so nothing will sound at \(store.wake.timeLabel). Turn them on in Settings.")
                .font(.flexCaption())
                .foregroundStyle(Theme.inkSubtle)
                .fixedSize(horizontal: false, vertical: true)
            Button("Open Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
            }
            .buttonStyle(SecondaryButtonStyle(tint: Theme.danger, background: Theme.danger.opacity(0.1)))
        }
        .padding(16)
        .background(Theme.card)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    // MARK: Hero

    private var heroCard: some View {
        FlexCard {
            VStack(alignment: .leading, spacing: 12) {
                Text(store.wake.enabled ? "WAKE-UP · \(daysLabel(store.wake.days))" : "PICK YOUR WAKE-UP TIME")
                    .font(.flexMono(11))
                    .tracking(2)
                    .foregroundStyle(Theme.inkSubtle)

                Text(store.wake.timeLabel)
                    .font(.flexDisplay(58))
                    .foregroundStyle(Theme.ink)
                    .minimumScaleFactor(0.5)
                    .lineLimit(1)

                if store.wake.enabled {
                    alarmModeBadge
                }

                Button(store.wake.enabled ? "Edit wake-up" : "Set wake-up") {
                    showSetup = true
                }
                .buttonStyle(store.wake.enabled ? SecondaryButtonStyle() : SecondaryButtonStyle(tint: Theme.background, background: Theme.ink))
            }
        }
    }

    /// "WEEKDAYS", "EVERY DAY", or the short day names.
    private func daysLabel(_ days: Set<Int>) -> String {
        if days.count == 7 { return "EVERY DAY" }
        if days == [2, 3, 4, 5, 6] { return "WEEKDAYS" }
        if days == [1, 7] { return "WEEKENDS" }
        let symbols = calendar.shortWeekdaySymbols
        return days.sorted().map { symbols[$0 - 1].uppercased() }.joined(separator: " ")
    }

    /// Says plainly which mechanism is live. A real alarm rings through
    /// silent; the fallback is muted by the ring switch, and that's worth
    /// knowing before you trust it to wake you.
    private var alarmModeBadge: some View {
        let isReal = store.isWakeAlarmReal
        return HStack(spacing: 6) {
            Image(systemName: isReal ? "bell.badge.fill" : "bell.slash.fill")
                .font(.system(size: 10, weight: .bold))
            Text(isReal ? "REAL ALARM · RINGS ON SILENT" : "NOTIFICATION ONLY · SILENT MUTES IT")
                .font(.flexMono(9))
                .tracking(1)
        }
        .foregroundStyle(isReal ? Theme.accent : Theme.amber)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background((isReal ? Theme.accent : Theme.amber).opacity(0.12))
        .clipShape(Capsule())
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

            StatStrip([
                (lastNightLabel, "Last night"),
                (averageLabel, "7-day avg"),
                ("\(store.sleepLogStreak)", "Night streak")
            ])
        }
    }

    private var lastNightLabel: String {
        guard let last = store.lastNightSleep else { return "-" }
        return String(format: "%.1fh", last.hours)
    }

    private var averageLabel: String {
        guard let average = store.averageSleepHours() else { return "-" }
        return String(format: "%.1fh", average)
    }

    // MARK: Sleep history

    private var sleepHistoryCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "History")
            if store.sleepSessions.isEmpty {
                EmptyStateCard(
                    icon: "moon.zzz",
                    title: "No nights logged yet",
                    message: "Log tonight's sleep tomorrow morning. Even a rough estimate builds the picture."
                )
            } else {
                ForEach(store.sleepSessions.sorted { $0.wakeTime > $1.wakeTime }) { session in
                    sleepRow(session)
                        .contextMenu {
                            Button(role: .destructive) {
                                store.deleteSleep(session)
                            } label: {
                                Label("Delete night", systemImage: "trash")
                            }
                        }
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

// MARK: - Check-in

/// "I'm up." With a proof spot set, the only way to check in is to walk
/// to that spot and photograph it; the phone compares the two photos on
/// the device. Without one, any live photo (or none) counts.
struct WakeCheckInCard: View {
    @Environment(AppStore.self) private var store
    @State private var showCamera = false
    @State private var isChecking = false
    @State private var misses = 0
    @State private var message: String?

    /// After this many misses the escape hatch appears, so a dark bathroom
    /// can't lock someone out of their own streak.
    private let missesBeforeFallback = 3

    private var cameraAvailable: Bool {
        UIImagePickerController.isSourceTypeAvailable(.camera)
    }

    var body: some View {
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
                if let spot = store.proofSpotURL {
                    FlexCard(padding: 14) {
                        HStack(spacing: 14) {
                            AsyncPhotoView(url: spot, maxPixel: 240)
                                .frame(width: 64, height: 64)
                                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                            VStack(alignment: .leading, spacing: 4) {
                                Text("YOUR PROOF SPOT")
                                    .font(.flexMono(9))
                                    .tracking(1.5)
                                    .foregroundStyle(Theme.inkSubtle)
                                Text("Walk there and photograph it from the same angle.")
                                    .font(.flexCaption())
                                    .foregroundStyle(Theme.ink)
                            }
                            Spacer(minLength: 0)
                        }
                    }
                }

                if let message {
                    Text(message)
                        .font(.flexCaption())
                        .foregroundStyle(Theme.danger)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                }

                Button {
                    message = nil
                    if cameraAvailable {
                        showCamera = true
                    } else {
                        store.checkInWake()
                    }
                } label: {
                    HStack(spacing: 10) {
                        if isChecking {
                            ProgressView().tint(Theme.background)
                            Text("Checking your photo")
                        } else {
                            Image(systemName: "camera")
                            Text(store.proofSpotURL == nil ? "I'm up. Take a photo" : "I'm up. Photograph my spot")
                        }
                    }
                }
                .buttonStyle(PrimaryButtonStyle())
                .disabled(isChecking)

                if store.proofSpotURL == nil {
                    Button("Check in without a photo") {
                        store.checkInWake()
                    }
                    .buttonStyle(SecondaryButtonStyle())
                } else if misses >= missesBeforeFallback {
                    Button("Still no match? Check in anyway") {
                        store.checkInWake()
                    }
                    .buttonStyle(SecondaryButtonStyle())
                }
            }
            .fullScreenCover(isPresented: $showCamera) {
                CameraPicker { image in handle(image) }
                    .ignoresSafeArea()
            }
        }
    }

    private func handle(_ image: UIImage) {
        guard let spot = store.proofSpotURL else {
            checkIn(with: image)
            return
        }
        isChecking = true
        Task { @MainActor in
            let outcome = await PhotoMatcher.compare(image, toReferenceAt: spot)
            isChecking = false
            switch outcome {
            case .match:
                misses = 0
                checkIn(with: image)
            case .noMatch:
                misses += 1
                message = "That doesn't look like your spot. Stand where you took the first photo and try again."
            case .failed:
                misses += 1
                message = "Couldn't read that photo. Turn a light on and try again."
            }
        }
    }

    private func checkIn(with image: UIImage) {
        if let data = image.flexJPEGData() {
            store.checkInWake(withPhoto: data)
        } else {
            store.checkInWake()
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
    /// Whether the last test used a real AlarmKit alarm.
    @State private var previewIsReal = false
    @State private var showSpotCamera = false
    @State private var showSpotLibrary = false

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
            "Rings at full volume even on silent, like the Clock app. The test rings the real alarm, so you can lock your phone and hear it."
        } else {
            "Keep your phone off silent and the volume up. Before iOS 26, only the Clock app can ring through the mute switch."
        }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                Text("WAKE-UP TIME")
                    .font(.flexMono(12))
                    .tracking(2)
                    .foregroundStyle(Theme.ink)
                    .padding(.top, 24)

                DatePicker("Time", selection: $time, displayedComponents: .hourAndMinute)
                    .datePickerStyle(.wheel)
                    .labelsHidden()
                    .frame(maxWidth: .infinity)

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

                proofSpotCard

                VStack(spacing: 8) {
                    Button {
                        previewSent = true
                        Task { @MainActor in
                            previewIsReal = await store.previewWakeAlarm()
                            try? await Task.sleep(nanoseconds: 8_000_000_000)
                            previewSent = false
                        }
                    } label: {
                        Label(previewSent ? (previewIsReal ? "Ringing in 5 seconds. Lock your phone." : "Sounding in 5 seconds") : "Test the alarm now", systemImage: "speaker.wave.3")
                    }
                    .buttonStyle(SecondaryButtonStyle())
                    .disabled(previewSent)

                    Text(alarmCapabilityNote)
                        .font(.flexCaption())
                        .foregroundStyle(Theme.inkSubtle)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 8)
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 20)
        }
        .scrollIndicators(.hidden)
        .safeAreaInset(edge: .bottom) {
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
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(Theme.background)
        }
        .background(Theme.background)
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .fullScreenCover(isPresented: $showSpotCamera) {
            CameraPicker { image in saveSpot(image) }
                .ignoresSafeArea()
        }
        .sheet(isPresented: $showSpotLibrary) {
            LibraryPicker { image in saveSpot(image) }
        }
        .onAppear {
            time = store.wake.timeToday
            days = store.wake.days
            // Default the alarm on for first-time setup; respect the saved
            // choice once the feature has been used.
            enabled = store.wake.enabled || store.wakeCheckInDays.isEmpty
        }
    }

    /// The Alarmy-style proof: a photo of somewhere away from the bed that
    /// you must photograph again before the check-in counts.
    private var proofSpotCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 14) {
                Group {
                    if let spot = store.proofSpotURL {
                        AsyncPhotoView(url: spot, maxPixel: 240)
                    } else {
                        Image(systemName: "camera.viewfinder")
                            .font(.system(size: 24, weight: .semibold))
                            .foregroundStyle(Theme.accent)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .background(Theme.accentSoft)
                    }
                }
                .frame(width: 64, height: 64)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                VStack(alignment: .leading, spacing: 3) {
                    Text("Proof spot")
                        .font(.flexBodyBold())
                        .foregroundStyle(Theme.ink)
                    Text(store.proofSpotURL == nil
                         ? "Photograph a spot away from your bed, like the bathroom sink. To check in, you'll have to walk there and photograph it again."
                         : "To check in, photograph this spot again. The photos are compared on your phone.")
                        .font(.flexCaption())
                        .foregroundStyle(Theme.inkSubtle)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            HStack(spacing: 8) {
                Menu {
                    if UIImagePickerController.isSourceTypeAvailable(.camera) {
                        Button("Take photo", systemImage: "camera") { showSpotCamera = true }
                    }
                    Button("Choose from library", systemImage: "photo.on.rectangle") { showSpotLibrary = true }
                } label: {
                    Text(store.proofSpotURL == nil ? "Set proof spot" : "Change spot")
                        .font(.flexBodyBold())
                        .foregroundStyle(Theme.ink)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Theme.ink.opacity(0.08))
                        .clipShape(Capsule())
                }
                if store.proofSpotURL != nil {
                    Button("Remove") { store.setProofSpot(nil) }
                        .font(.flexBodyBold())
                        .foregroundStyle(Theme.danger)
                        .padding(.horizontal, 18)
                        .padding(.vertical, 12)
                        .background(Theme.danger.opacity(0.08))
                        .clipShape(Capsule())
                        .buttonStyle(.plain)
                }
            }
        }
        .padding(14)
        .background(Theme.card)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func saveSpot(_ image: UIImage) {
        guard let data = image.flexJPEGData(maxEdge: 1200, quality: 0.8) else { return }
        store.setProofSpot(data)
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

    /// The evening the night started on. Bedtime and wake time are picked
    /// as clock times and placed around it, so the sheet never needs two
    /// full date pickers side by side.
    @State private var night = Calendar.current.date(byAdding: .day, value: -1, to: .now) ?? .now
    @State private var bedTime = Date.now
    @State private var wakeTime = Date.now
    @State private var quality: SleepQuality = .good

    private let calendar = Calendar.current

    /// Bedtime lands on the chosen evening, or the next morning when it's
    /// after midnight (a 1:00 AM bedtime belongs to the same night).
    private var bedtimeDate: Date {
        let day = calendar.startOfDay(for: night)
        let hour = calendar.component(.hour, from: bedTime)
        let minute = calendar.component(.minute, from: bedTime)
        let placed = calendar.date(bySettingHour: hour, minute: minute, second: 0, of: day) ?? day
        return hour < 12 ? (calendar.date(byAdding: .day, value: 1, to: placed) ?? placed) : placed
    }

    /// The first wake time after bedtime.
    private var wakeDate: Date {
        let hour = calendar.component(.hour, from: wakeTime)
        let minute = calendar.component(.minute, from: wakeTime)
        let sameDay = calendar.date(bySettingHour: hour, minute: minute, second: 0, of: bedtimeDate) ?? bedtimeDate
        return sameDay > bedtimeDate ? sameDay : (calendar.date(byAdding: .day, value: 1, to: sameDay) ?? sameDay)
    }

    private var duration: TimeInterval {
        max(0, wakeDate.timeIntervalSince(bedtimeDate))
    }

    private var durationLabel: String {
        let totalMinutes = Int(duration / 60)
        return "\(totalMinutes / 60)h \(totalMinutes % 60)m"
    }

    /// Anything past 16 hours is almost certainly a mis-set time.
    private var isPlausible: Bool { duration > 0 && duration <= 16 * 3600 }

    var body: some View {
        VStack(spacing: 20) {
            VStack(spacing: 6) {
                Text("LOG A NIGHT")
                    .font(.flexMono(12))
                    .tracking(2)
                    .foregroundStyle(Theme.inkSubtle)
                Text(durationLabel)
                    .font(.flexDisplay(44))
                    .foregroundStyle(Theme.ink)
                    .contentTransition(.numericText())
                    .animation(.snappy, value: durationLabel)
                if !isPlausible {
                    Text("Check the times. That's longer than a night.")
                        .font(.flexCaption())
                        .foregroundStyle(Theme.danger)
                }
            }
            .padding(.top, 28)

            VStack(spacing: 0) {
                pickerRow("Night of", icon: "calendar") {
                    DatePicker("Night of", selection: $night, in: ...Date.now, displayedComponents: .date)
                }
                Divider().padding(.leading, 50)
                pickerRow("Fell asleep", icon: "moon.fill") {
                    DatePicker("Fell asleep", selection: $bedTime, displayedComponents: .hourAndMinute)
                }
                Divider().padding(.leading, 50)
                pickerRow("Woke up", icon: "sun.max.fill") {
                    DatePicker("Woke up", selection: $wakeTime, displayedComponents: .hourAndMinute)
                }
            }
            .background(Theme.card)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))

            VStack(alignment: .leading, spacing: 10) {
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

            Spacer(minLength: 0)

            Button("Save night") {
                store.logSleep(bedtime: bedtimeDate, wakeTime: wakeDate, quality: quality)
                dismiss()
            }
            .buttonStyle(PrimaryButtonStyle())
            .disabled(!isPlausible)
            .opacity(isPlausible ? 1 : 0.4)
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 12)
        .frame(maxWidth: .infinity)
        .background(Theme.background)
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .onAppear {
            bedTime = store.bedtime.timeToday
            wakeTime = store.wake.timeToday
        }
    }

    private func pickerRow<Picker: View>(_ title: String, icon: String, @ViewBuilder picker: () -> Picker) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Theme.accent)
                .frame(width: 22)
            Text(title)
                .font(.flexBody())
                .foregroundStyle(Theme.ink)
            Spacer(minLength: 8)
            picker()
                .labelsHidden()
                .datePickerStyle(.compact)
                .tint(Theme.accent)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
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
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
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
