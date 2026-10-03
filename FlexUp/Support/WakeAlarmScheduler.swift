import Foundation
import SwiftUI
#if canImport(AlarmKit)
import AlarmKit
#endif

/// Outcome of trying to schedule a real system alarm.
enum WakeAlarmResult {
    /// AlarmKit owns the wake-up; the notification burst must stay off so
    /// the morning doesn't fire twice.
    case scheduled(UUID)
    /// Pre-iOS 26: fall back to notifications.
    case unavailable
    /// iOS 26, but alarms are turned off for FlexUp in Settings. Falls back
    /// to notifications, and the app must say so.
    case denied
    /// AlarmKit refused the schedule. Falls back to notifications; the
    /// reason is shown so it isn't a silent failure.
    case failed(String)
    /// The wake-up is switched off; nothing should fire at all.
    case disabled
}

/// A real alarm, not a notification.
///
/// `UNUserNotificationCenter` can never ring through the mute switch — only
/// AlarmKit (iOS 26+) and the critical-alerts entitlement can. This wraps
/// AlarmKit so the wake-up behaves like the system Clock alarm: it rings at
/// full volume on silent, pierces Focus, and shows a full-screen alert with
/// a Stop button.
enum WakeAlarmScheduler {

    /// FlexUp never snoozes, so there's no secondary button and no metadata
    /// to carry — but AlarmKit still needs a concrete conforming type.
    #if canImport(AlarmKit)
    @available(iOS 26.0, *)
    struct Metadata: AlarmMetadata {
        init() {}
    }
    #endif

    /// Replace the existing FlexUp alarm with one matching the config.
    /// Returns the new alarm's ID so it can be cancelled later.
    static func reschedule(
        hour: Int,
        minute: Int,
        weekdays: Set<Int>,
        enabled: Bool,
        existingID: UUID?,
        tint: Color
    ) async -> WakeAlarmResult {
        #if canImport(AlarmKit)
        guard #available(iOS 26.0, *) else { return .unavailable }

        // Clear the previous alarm first — rescheduling should never stack.
        if let existingID {
            try? AlarmManager.shared.cancel(id: existingID)
        }

        guard enabled, !weekdays.isEmpty else { return .disabled }
        guard await requestAuthorization() else { return .denied }

        let attributes = makeAttributes(title: "Wake up. You said so.", tint: tint)

        let schedule = Alarm.Schedule.relative(
            .init(
                time: .init(hour: hour, minute: minute),
                repeats: .weekly(weekdays.sorted().compactMap(localeWeekday))
            )
        )

        let configuration = AlarmManager.AlarmConfiguration(
            countdownDuration: nil,
            schedule: schedule,
            attributes: attributes,
            stopIntent: nil,
            secondaryIntent: nil
        )

        let id = UUID()
        do {
            _ = try await AlarmManager.shared.schedule(id: id, configuration: configuration)
            return .scheduled(id)
        } catch {
            return .failed(error.localizedDescription)
        }
        #else
        return .unavailable
        #endif
    }

    /// A one-off real alarm a few seconds from now, so "Preview" rings
    /// exactly like the morning will (through silent mode) instead of
    /// playing a notification. Doesn't touch the scheduled wake-up.
    static func ringTest(after seconds: TimeInterval, tint: Color) async -> WakeAlarmResult {
        #if canImport(AlarmKit)
        guard #available(iOS 26.0, *) else { return .unavailable }
        guard await requestAuthorization() else { return .denied }
        let configuration = AlarmManager.AlarmConfiguration(
            countdownDuration: nil,
            schedule: .fixed(Date.now.addingTimeInterval(seconds)),
            attributes: makeAttributes(title: "Test alarm. This is your wake-up.", tint: tint),
            stopIntent: nil,
            secondaryIntent: nil
        )
        let id = UUID()
        do {
            _ = try await AlarmManager.shared.schedule(id: id, configuration: configuration)
            return .scheduled(id)
        } catch {
            return .failed(error.localizedDescription)
        }
        #else
        return .unavailable
        #endif
    }

    /// Whether AlarmKit still holds this alarm. Reinstalls, restores and
    /// permission changes can drop it without telling the app.
    static func isScheduled(id: UUID) -> Bool {
        #if canImport(AlarmKit)
        guard #available(iOS 26.0, *) else { return false }
        let alarms = (try? AlarmManager.shared.alarms) ?? []
        return alarms.contains { $0.id == id }
        #else
        return false
        #endif
    }

    #if canImport(AlarmKit)
    @available(iOS 26.0, *)
    private static func makeAttributes(title: LocalizedStringResource, tint: Color) -> AlarmAttributes<Metadata> {
        let alert = AlarmPresentation.Alert(
            title: title,
            stopButton: AlarmButton(
                text: "I'm up",
                textColor: .white,
                systemImageName: "checkmark"
            )
        )
        return AlarmAttributes(
            presentation: AlarmPresentation(alert: alert),
            metadata: Metadata(),
            tintColor: tint
        )
    }
    #endif

    /// Cancel the scheduled alarm, e.g. when the wake-up is switched off.
    static func cancel(id: UUID?) {
        #if canImport(AlarmKit)
        guard #available(iOS 26.0, *), let id else { return }
        try? AlarmManager.shared.cancel(id: id)
        #endif
    }

    #if canImport(AlarmKit)
    @available(iOS 26.0, *)
    private static func requestAuthorization() async -> Bool {
        if AlarmManager.shared.authorizationState == .authorized { return true }
        do {
            return try await AlarmManager.shared.requestAuthorization() == .authorized
        } catch {
            return false
        }
    }
    #endif

    /// Calendar weekdays (1 = Sunday … 7 = Saturday) → `Locale.Weekday`.
    private static func localeWeekday(_ calendarWeekday: Int) -> Locale.Weekday? {
        switch calendarWeekday {
        case 1: .sunday
        case 2: .monday
        case 3: .tuesday
        case 4: .wednesday
        case 5: .thursday
        case 6: .friday
        case 7: .saturday
        default: nil
        }
    }
}
