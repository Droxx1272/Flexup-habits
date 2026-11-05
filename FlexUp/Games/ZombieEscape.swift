import Foundation
import CoreLocation
import Observation

/// Zombie Escape: a story mission told by voice. Running collects supplies;
/// hordes turn up at random and you have to speed up to stay ahead of them.
/// The horde's speed is set from *your* recent pace, so a walker and a
/// sprinter get the same fight.
@Observable
final class ZombieEscape {

    struct Mission {
        let title: String
        let intro: String
    }

    /// Original story, one mission per run, looping after the last.
    static let missions: [Mission] = [
        Mission(title: "The Bridge", intro: "This is base. The east bridge is the last way into the safe zone, and the supply truck never made it across. Everything you pick up out there, we keep. Stay quick. Go."),
        Mission(title: "Pharmacy Run", intro: "The pharmacy on the high street still has stock. Get what you can and keep moving. They're slow in the cold, but not that slow."),
        Mission(title: "Radio Silence", intro: "Our radio mast went dark last night. We need batteries and parts, and we need them before sunset."),
        Mission(title: "The Ring Road", intro: "Scouts saw a horde moving along the ring road. Keep your pace honest and you'll stay ahead of it."),
        Mission(title: "Seed Bank", intro: "The old garden centre has seeds for the spring planting. This one is about the future. Bring back what you can."),
        Mission(title: "Night Shift", intro: "It's dark, it's quiet, and that's the problem. Listen for them. When I say run, you run."),
        Mission(title: "Bad Water", intro: "The filters failed. Find water and anything that cleans it. Thirst gets everyone eventually."),
        Mission(title: "Homecoming", intro: "One more run and the convoy can leave. Make it count. We wait for you, always."),
    ]

    private static let supplyNames = [
        "water", "a medical kit", "batteries", "a radio", "tinned food", "a map", "a torch",
        "seeds", "a water filter", "rope", "antibiotics", "a solar charger", "bandages", "a compass",
    ]

    enum Phase: Equatable {
        case calm
        case chase
    }

    /// The horde starts this far behind you.
    static let startGap = 50.0
    /// Hold them off this long, or get this far ahead, to escape.
    static let chaseSeconds = 60.0
    static let escapeGap = 100.0

    let missionIndex: Int
    var mission: Mission { Self.missions[missionIndex % Self.missions.count] }

    private(set) var phase: Phase = .calm
    private(set) var supplies: [String] = []
    private(set) var escaped = 0
    private(set) var caught = 0
    /// Metres between you and the horde during a chase.
    private(set) var gap = startGap
    /// Seconds left to hold them off.
    private(set) var chaseRemaining = 0.0
    private(set) var lastEvent: String?
    private(set) var needsGPS = false

    @ObservationIgnored private var samples: [(t: Double, d: Double)] = []
    @ObservationIgnored private var nextChaseAt: Double = 0
    @ObservationIgnored private var nextSupplyAt: Double = 250
    @ObservationIgnored private var chaseStart: (t: Double, d: Double) = (0, 0)
    @ObservationIgnored private var hordeSpeed = 2.5
    @ObservationIgnored private var warned50 = false
    @ObservationIgnored private var warned20 = false
    @ObservationIgnored private var warnedPulling = false
    private let announcer: Announcer

    init(missionIndex: Int, announcer: Announcer) {
        self.missionIndex = missionIndex
        self.announcer = announcer
    }

    func begin() {
        nextChaseAt = Double.random(in: 150...210)
        announcer.say("Mission \(missionIndex % Self.missions.count + 1). \(mission.title). \(mission.intro)")
    }

    func update(elapsed t: Double, distance d: Double, locationDenied: Bool) {
        samples.append((t, d))
        samples.removeAll { t - $0.t > 120 }

        if locationDenied {
            if !needsGPS {
                needsGPS = true
                event("Zombie Escape needs location to track your speed. Hordes are off for this run.")
            }
            return
        }

        switch phase {
        case .calm:
            if d >= nextSupplyAt {
                let item = Self.supplyNames.randomElement() ?? "water"
                supplies.append(item)
                nextSupplyAt = d + Double.random(in: 250...400)
                event("Picked up \(item).", haptic: .tap)
            }
            if t >= nextChaseAt { startChase(t: t, d: d) }

        case .chase:
            let since = t - chaseStart.t
            gap = Self.startGap + (d - chaseStart.d) - hordeSpeed * since
            chaseRemaining = max(0, Self.chaseSeconds - since)

            if gap <= 0 {
                caught += 1
                let lost = supplies.isEmpty ? nil : supplies.remove(at: Int.random(in: 0..<supplies.count))
                event(lost.map { "They caught you. You dropped \($0). Keep going." } ?? "They caught you. Keep going, you can lose them.", haptic: .failure)
                endChase(t: t)
            } else if since >= Self.chaseSeconds || gap >= Self.escapeGap {
                escaped += 1
                event("You lost them. Ease off and get your breath back.", haptic: .success)
                endChase(t: t)
            } else if gap < 10 && !warned20 {
                warned20 = true
                event("They're right behind you!", haptic: .alert)
            } else if gap < 25 && !warned50 {
                warned50 = true
                event("Twenty-five metres. Faster!", haptic: .alert)
            } else if gap > 80 && !warnedPulling {
                warnedPulling = true
                event("You're pulling away. Keep it up.")
            }
        }
    }

    /// Your speed over the last two minutes (metres per second), with a
    /// floor so a slow start still gets a fair horde.
    private var baselineSpeed: Double {
        guard let first = samples.first, let last = samples.last, last.t - first.t >= 20 else { return 2.0 }
        return max(1.4, (last.d - first.d) / (last.t - first.t))
    }

    private func startChase(t: Double, d: Double) {
        phase = .chase
        chaseStart = (t, d)
        // Holding your normal pace gets you caught near the end of the
        // minute; a push of about 20 to 25 percent gets you clear.
        let base = baselineSpeed
        hordeSpeed = base + max(0.9, base * 0.3)
        gap = Self.startGap
        chaseRemaining = Self.chaseSeconds
        warned50 = false
        warned20 = false
        warnedPulling = false
        event("Zombies! Fifty metres behind you. Speed up!", haptic: .alert)
    }

    private func endChase(t: Double) {
        phase = .calm
        gap = Self.startGap
        chaseRemaining = 0
        nextChaseAt = t + Double.random(in: 150...270)
    }

    private func event(_ text: String, haptic: Announcer.Haptic? = nil) {
        lastEvent = text
        announcer.say(text, haptic: haptic)
    }

    func result() -> RunGameResult {
        let chases = escaped + caught
        let headline = chases == 0
            ? "\(mission.title) · \(supplies.count) supplies"
            : "\(mission.title) · escaped \(escaped) of \(chases) · \(supplies.count) supplies"
        announcer.say("You made it back with \(supplies.count) supplies. Base out.")
        return RunGameResult(
            kind: .zombies,
            headline: headline,
            won: chases > 0 && caught == 0,
            mission: missionIndex,
            supplies: supplies.count,
            chasesEscaped: escaped,
            chasesCaught: caught
        )
    }
}
