import Foundation
import CoreLocation
import Observation

/// Live run tracking: elapsed time from a 1s timer, distance from
/// CoreLocation deltas (accuracy-filtered so GPS noise doesn't inflate
/// kilometres). Works without location permission too — time still counts.
@Observable
final class RunTracker: NSObject, CLLocationManagerDelegate {

    enum Phase {
        case idle, running, paused
    }

    var phase: Phase = .idle
    var elapsed: TimeInterval = 0
    var distanceMeters: Double = 0
    var locationDenied = false

    @ObservationIgnored private let manager = CLLocationManager()
    @ObservationIgnored private var lastLocation: CLLocation?
    @ObservationIgnored private var timer: Timer?
    // Elapsed time is wall-clock based so it stays correct even though the
    // 1s UI timer pauses while the app is backgrounded.
    @ObservationIgnored private var accumulated: TimeInterval = 0
    @ObservationIgnored private var segmentStart: Date?

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest
        manager.activityType = .fitness
        manager.distanceFilter = 5
    }

    func start() {
        guard phase == .idle else { return }
        elapsed = 0
        distanceMeters = 0
        lastLocation = nil
        accumulated = 0
        segmentStart = .now

        if manager.authorizationStatus == .notDetermined {
            manager.requestWhenInUseAuthorization()
        }
        updateDeniedFlag()
        manager.startUpdatingLocation()
        phase = .running
        startTimer()
    }

    func pause() {
        guard phase == .running else { return }
        manager.stopUpdatingLocation()
        lastLocation = nil
        timer?.invalidate()
        if let start = segmentStart {
            accumulated += Date.now.timeIntervalSince(start)
        }
        segmentStart = nil
        refreshElapsed()
        phase = .paused
    }

    func resume() {
        guard phase == .paused else { return }
        segmentStart = .now
        manager.startUpdatingLocation()
        startTimer()
        phase = .running
    }

    /// Stop tracking and hand back the totals. Resets to idle.
    func finish() -> (distanceMeters: Double, duration: TimeInterval) {
        manager.stopUpdatingLocation()
        timer?.invalidate()
        timer = nil
        if let start = segmentStart {
            accumulated += Date.now.timeIntervalSince(start)
        }
        segmentStart = nil
        refreshElapsed()
        let result = (distanceMeters, elapsed)
        lastLocation = nil
        phase = .idle
        return result
    }

    private func refreshElapsed() {
        let live = segmentStart.map { Date.now.timeIntervalSince($0) } ?? 0
        elapsed = accumulated + live
    }

    var currentPaceSecondsPerKm: Double? {
        let km = distanceMeters / 1000
        return km > 0.05 ? elapsed / km : nil
    }

    private func startTimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            self?.refreshElapsed()
        }
    }

    private func updateDeniedFlag() {
        locationDenied = manager.authorizationStatus == .denied || manager.authorizationStatus == .restricted
    }

    // MARK: CLLocationManagerDelegate

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard phase == .running else { return }
        for location in locations where location.horizontalAccuracy >= 0 && location.horizontalAccuracy <= 35 {
            if let last = lastLocation {
                let delta = location.distance(from: last)
                // Ignore sub-metre jitter and impossible jumps.
                if delta >= 1 && delta <= 100 {
                    distanceMeters += delta
                }
            }
            lastLocation = location
        }
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        updateDeniedFlag()
        if phase == .running {
            manager.startUpdatingLocation()
        }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        // Non-fatal: the run keeps timing even if GPS drops.
    }
}

// MARK: - Formatting

enum RunFormat {
    static func duration(_ t: TimeInterval) -> String {
        let total = Int(t)
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        let seconds = total % 60
        return hours > 0
            ? String(format: "%d:%02d:%02d", hours, minutes, seconds)
            : String(format: "%02d:%02d", minutes, seconds)
    }

    static func pace(_ secondsPerKm: Double?) -> String {
        guard let secondsPerKm, secondsPerKm.isFinite, secondsPerKm < 3600 else { return "—" }
        let total = Int(secondsPerKm)
        return String(format: "%d'%02d\"", total / 60, total % 60)
    }

    static func kilometers(_ km: Double) -> String {
        String(format: "%.2f", km)
    }
}
