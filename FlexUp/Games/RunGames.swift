import Foundation
import CoreLocation
import Observation

// MARK: - Ghost Race

/// A past run replayed second by second: how far it had gone at any moment.
struct GhostProfile {
    let runID: UUID
    let date: Date
    let distance: Double
    let duration: Double
    /// (seconds, metres), increasing.
    private let samples: [(t: Double, d: Double)]

    init(run: Run) {
        runID = run.id
        date = run.date
        distance = run.distanceMeters
        duration = run.duration

        var points: [(t: Double, d: Double)] = [(0, 0)]
        let route = run.route ?? []
        if route.count > 1, route.allSatisfy({ $0.t != nil }) {
            // Exact replay from timestamped GPS points.
            var total = 0.0
            for (a, b) in zip(route, route.dropFirst()) {
                total += Geo.distance(a.coordinate, b.coordinate)
                points.append((b.t ?? 0, total))
            }
            // GPS distance can differ slightly from the logged total; scale to it.
            if total > 0 {
                let scale = run.distanceMeters / total
                points = points.map { ($0.t, $0.d * scale) }
            }
        } else if !run.splits.isEmpty {
            // Older runs: per-km splits, then the last partial kilometre.
            var t = 0.0
            for (index, split) in run.splits.enumerated() {
                t += split
                points.append((t, Double(index + 1) * 1000))
            }
        }
        if (points.last?.t ?? 0) < run.duration {
            points.append((run.duration, run.distanceMeters))
        }
        samples = points
    }

    /// Where the ghost was `t` seconds in.
    func distance(at t: Double) -> Double {
        guard t > 0 else { return 0 }
        guard let after = samples.firstIndex(where: { $0.t >= t }) else { return distance }
        guard after > 0 else { return samples[after].d }
        let a = samples[after - 1], b = samples[after]
        let span = b.t - a.t
        return span > 0 ? a.d + (b.d - a.d) * (t - a.t) / span : b.d
    }
}

/// Ghost Race: you against one of your own past runs, metre by metre.
@Observable
final class GhostRace {
    let ghost: GhostProfile

    /// Positive: you're ahead of the ghost, in metres.
    private(set) var lead = 0.0
    private(set) var ghostDistance = 0.0
    private(set) var finishedAt: Double?
    private(set) var ghostFinished = false
    private(set) var lastEvent: String?

    @ObservationIgnored private var lastLeader: Bool?
    @ObservationIgnored private var nextUpdateAt = 250.0
    private let announcer: Announcer

    init(ghost: GhostProfile, announcer: Announcer) {
        self.ghost = ghost
        self.announcer = announcer
    }

    func begin() {
        let km = String(format: "%.1f", ghost.distance / 1000)
        announcer.say("Racing your run from \(ghost.date.formatted(.dateTime.weekday(.wide).day().month(.wide))). \(km) kilometres in \(spoken(ghost.duration)). Go.")
    }

    func update(elapsed t: Double, distance d: Double) {
        ghostDistance = ghost.distance(at: t)
        lead = d - ghostDistance

        if finishedAt == nil && d >= ghost.distance && ghost.distance > 0 {
            finishedAt = t
            let margin = ghost.duration - t
            event(margin >= 0
                  ? "Finish line. You beat your ghost by \(spoken(margin))."
                  : "Finish line. Your ghost was \(spoken(-margin)) faster this time.",
                  haptic: margin >= 0 ? .success : .failure)
            return
        }
        guard finishedAt == nil else { return }

        if t >= ghost.duration && !ghostFinished {
            ghostFinished = true
            event("Your ghost just finished. \(Int(ghost.distance - d)) metres to go.", haptic: .alert)
        }

        // Call out a change of leader straight away (with a little slack so
        // GPS wobble doesn't flip it back and forth), otherwise every 250 m.
        let leading = lead > 0
        if let previous = lastLeader, previous != leading, abs(lead) > 8 {
            lastLeader = leading
            event(leading ? "You've passed your ghost." : "Your ghost just passed you.", haptic: .alert)
        } else if lastLeader == nil, abs(lead) > 8 {
            lastLeader = leading
        }
        if d >= nextUpdateAt {
            nextUpdateAt += 250
            event(lead >= 0 ? "\(Int(lead)) metres ahead of your ghost." : "\(Int(-lead)) metres behind your ghost.")
        }
    }

    private func event(_ text: String, haptic: Announcer.Haptic? = nil) {
        lastEvent = text
        announcer.say(text, haptic: haptic)
    }

    private func spoken(_ seconds: Double) -> String {
        let total = Int(seconds.rounded())
        let minutes = total / 60, secs = total % 60
        if minutes == 0 { return "\(secs) seconds" }
        return secs == 0 ? "\(minutes) minutes" : "\(minutes) minutes \(secs) seconds"
    }

    func result() -> RunGameResult {
        if let finishedAt {
            let margin = ghost.duration - finishedAt
            let time = RunFormat.duration(abs(margin))
            return RunGameResult(
                kind: .ghost,
                headline: margin >= 0 ? "Beat your ghost by \(time)" : "Ghost won by \(time)",
                won: margin >= 0,
                ghostMarginSeconds: margin
            )
        }
        return RunGameResult(
            kind: .ghost,
            headline: "Stopped \(Int(abs(lead))) m \(lead >= 0 ? "ahead of" : "behind") your ghost",
            won: false
        )
    }
}

// MARK: - Territory

/// Territory: every block you run through becomes yours. The live game just
/// shows it happening; every GPS run claims blocks either way.
@Observable
final class TerritoryRun {
    let owned: Set<String>
    private(set) var claimed = Set<String>()
    private(set) var lastEvent: String?
    @ObservationIgnored private var lastCell: String?
    private let announcer: Announcer

    init(owned: Set<String>, announcer: Announcer) {
        self.owned = owned
        self.announcer = announcer
    }

    var newBlocks: Int { claimed.subtracting(owned).count }
    var total: Int { owned.union(claimed).count }

    func begin() {
        announcer.say("Territory. You own \(owned.count) blocks. Every new street is a new block. Go explore.")
    }

    func update(location: CLLocation) {
        let cell = TerritoryGrid.cell(for: location.coordinate)
        guard cell != lastCell else { return }
        lastCell = cell
        let isNew = !owned.contains(cell) && !claimed.contains(cell)
        claimed.insert(cell)
        guard isNew else { return }
        let count = newBlocks
        if count % 10 == 0 {
            event("\(count) new blocks this run. You own \(total).", haptic: .success)
        } else {
            event("New block. \(count) this run.", haptic: .tap)
        }
    }

    private func event(_ text: String, haptic: Announcer.Haptic? = nil) {
        lastEvent = text
        announcer.say(text, haptic: haptic)
    }

    func result() -> RunGameResult {
        RunGameResult(
            kind: .territory,
            headline: "\(newBlocks) new blocks · \(total) owned",
            won: newBlocks > 0,
            newBlocks: newBlocks
        )
    }
}

// MARK: - Checkpoint Hunt

/// Checkpoint Hunt: points dropped at random around where you start. Find
/// them all, in any order. They're placed by distance, not on paths, so a
/// checkpoint in a river can be skipped.
@Observable
final class CheckpointHunt {
    enum Length: String, CaseIterable, Identifiable {
        case short, medium, long
        var id: String { rawValue }
        var label: String {
            switch self {
            case .short: "Short · about 2 km"
            case .medium: "Medium · about 4 km"
            case .long: "Long · about 6 km"
            }
        }
        var count: Int { [3, 4, 5][index] }
        var maxRadius: Double { [450, 800, 1200][index] }
        private var index: Int { Self.allCases.firstIndex(of: self) ?? 0 }
    }

    struct Checkpoint: Identifiable {
        let id: Int
        let coordinate: CLLocationCoordinate2D
        var found = false
        var skipped = false
        var done: Bool { found || skipped }
    }

    /// Close enough to count as reached.
    static let reachRadius = 35.0

    let length: Length
    private(set) var checkpoints: [Checkpoint] = []
    private(set) var here: CLLocationCoordinate2D?
    private(set) var lastEvent: String?
    private let announcer: Announcer

    init(length: Length, announcer: Announcer) {
        self.length = length
        self.announcer = announcer
    }

    var found: Int { checkpoints.filter(\.found).count }
    var isComplete: Bool { !checkpoints.isEmpty && checkpoints.allSatisfy(\.done) }

    /// The closest checkpoint still to find, with distance and bearing.
    var nearest: (checkpoint: Checkpoint, meters: Double, bearing: Double)? {
        guard let here else { return nil }
        return checkpoints
            .filter { !$0.done }
            .map { ($0, Geo.distance(here, $0.coordinate), Geo.bearing(here, $0.coordinate)) }
            .min { $0.1 < $1.1 }
    }

    func begin() {
        announcer.say("Checkpoint hunt. \(length.count) checkpoints are waiting around you. Getting your position.")
    }

    func update(location: CLLocation) {
        here = location.coordinate
        if checkpoints.isEmpty {
            place(around: location.coordinate)
            if let next = nearest {
                event("First checkpoint is \(Int(next.meters)) metres \(Geo.compassWord(next.bearing)).")
            }
            return
        }
        for index in checkpoints.indices where !checkpoints[index].done {
            if Geo.distance(location.coordinate, checkpoints[index].coordinate) <= Self.reachRadius {
                checkpoints[index].found = true
                announceProgress(found: true)
            }
        }
    }

    /// For a checkpoint that landed somewhere you can't get to.
    func skipNearest() {
        guard let target = nearest?.checkpoint,
              let index = checkpoints.firstIndex(where: { $0.id == target.id }) else { return }
        checkpoints[index].skipped = true
        announceProgress(found: false)
    }

    private func place(around origin: CLLocationCoordinate2D) {
        let count = length.count
        let start = Double.random(in: 0..<360)
        checkpoints = (0..<count).map { index in
            // Spread around the compass so the route makes a loop.
            let bearing = start + Double(index) * 360 / Double(count) + Double.random(in: -20...20)
            let meters = Double.random(in: 200...length.maxRadius)
            return Checkpoint(id: index + 1, coordinate: Geo.offset(origin, meters: meters, bearing: bearing))
        }
    }

    private func announceProgress(found: Bool) {
        let prefix = found ? "Checkpoint \(self.found) of \(checkpoints.count)." : "Skipped."
        if isComplete {
            event("\(prefix) That's all of them. Head home.", haptic: .success)
        } else if let next = nearest {
            event("\(prefix) Next one is \(Int(next.meters)) metres \(Geo.compassWord(next.bearing)).", haptic: found ? .success : nil)
        }
    }

    private func event(_ text: String, haptic: Announcer.Haptic? = nil) {
        lastEvent = text
        announcer.say(text, haptic: haptic)
    }

    func result() -> RunGameResult {
        let total = max(checkpoints.count, length.count)
        return RunGameResult(
            kind: .checkpoints,
            headline: "\(found) of \(total) checkpoints found",
            won: found == total,
            checkpointsFound: found,
            checkpointsTotal: total
        )
    }
}

// MARK: - Session

/// Everything a game run needs, chosen on the setup sheet.
struct RunGameSetup {
    var kind: RunGameKind
    var ghost: Run?
    var huntLength: CheckpointHunt.Length = .medium
    var voiceOn = true
}

/// Runs the chosen game alongside the GPS tracker. The tracker calls
/// `update` every second and on every GPS fix.
@Observable
final class RunGameSession {
    let kind: RunGameKind
    let zombies: ZombieEscape?
    let ghost: GhostRace?
    let territory: TerritoryRun?
    let hunt: CheckpointHunt?

    init(setup: RunGameSetup, missionIndex: Int, ownedBlocks: Set<String>) {
        let announcer = Announcer.shared
        announcer.voiceOn = setup.voiceOn
        kind = setup.kind
        zombies = setup.kind == .zombies ? ZombieEscape(missionIndex: missionIndex, announcer: announcer) : nil
        ghost = setup.kind == .ghost ? setup.ghost.map { GhostRace(ghost: GhostProfile(run: $0), announcer: announcer) } : nil
        territory = setup.kind == .territory ? TerritoryRun(owned: ownedBlocks, announcer: announcer) : nil
        hunt = setup.kind == .checkpoints ? CheckpointHunt(length: setup.huntLength, announcer: announcer) : nil
    }

    /// Hook the game to the tracker and say the opening line.
    func attach(to tracker: RunTracker) {
        zombies?.begin()
        ghost?.begin()
        territory?.begin()
        hunt?.begin()
        tracker.onUpdate = { [weak self] tracker, location in
            self?.update(tracker: tracker, location: location)
        }
    }

    private func update(tracker: RunTracker, location: CLLocation?) {
        if let location {
            territory?.update(location: location)
            hunt?.update(location: location)
        } else {
            zombies?.update(elapsed: tracker.elapsed, distance: tracker.distanceMeters, locationDenied: tracker.locationDenied)
            ghost?.update(elapsed: tracker.elapsed, distance: tracker.distanceMeters)
        }
    }

    /// The most recent thing the game said, for the screen.
    var lastEvent: String? {
        zombies?.lastEvent ?? ghost?.lastEvent ?? territory?.lastEvent ?? hunt?.lastEvent
    }

    func result() -> RunGameResult? {
        zombies?.result() ?? ghost?.result() ?? territory?.result() ?? hunt?.result()
    }
}
