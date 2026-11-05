import SwiftUI
import MapKit

extension RunGameKind {
    /// Each game's colour, used for its card, icon and live display.
    var color: Color {
        switch self {
        case .free: Theme.ink
        case .zombies: Theme.danger
        case .ghost: .indigo
        case .territory: Theme.accent
        case .checkpoints: Theme.amber
        }
    }
}

// MARK: - Games on the Run tab

/// Four ways to make a run a game, each with what you've done so far.
struct RunGamesSection: View {
    @Environment(AppStore.self) private var store
    var onPick: (RunGameKind) -> Void
    var onShowTerritory: () -> Void

    private let columns = [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Run games")
            LazyVGrid(columns: columns, spacing: 10) {
                ForEach(RunGameKind.games) { kind in
                    Button {
                        onPick(kind)
                    } label: {
                        GameCard(kind: kind, stat: store.gameStat(kind))
                    }
                    .buttonStyle(.plain)
                }
            }
            Button(action: onShowTerritory) {
                HStack(spacing: 12) {
                    IconBadge(systemName: "map.fill", tint: Theme.accent, size: 38)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Your territory")
                            .font(.flexBodyBold())
                            .foregroundStyle(Theme.ink)
                        Text(store.territory.isEmpty
                             ? "Run with GPS to claim your first blocks"
                             : "\(store.territory.count) blocks · about \(areaLabel) km²")
                            .font(.flexCaption())
                            .foregroundStyle(Theme.inkSubtle)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(Theme.inkSubtle)
                }
                .padding(14)
                .background(Theme.card)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            }
            .buttonStyle(.plain)
        }
    }

    private var areaLabel: String {
        String(format: "%.1f", Double(store.territory.count) * TerritoryGrid.cellSquareKm)
    }
}

struct GameCard: View {
    let kind: RunGameKind
    let stat: String

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Image(systemName: kind.icon)
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 46, height: 46)
                .background(kind.color.gradient)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            Text(kind.title)
                .font(.flexBodyBold())
                .foregroundStyle(Theme.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            Text(kind.tagline)
                .font(.flexCaption())
                .foregroundStyle(Theme.inkSubtle)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
            Text(stat.uppercased())
                .font(.flexMono(8))
                .tracking(1)
                .foregroundStyle(kind.color)
                .lineLimit(2)
        }
        .padding(14)
        .frame(maxWidth: .infinity, minHeight: 190, alignment: .topLeading)
        .background(Theme.card)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(Theme.ink.opacity(0.05), lineWidth: 1)
        )
    }
}

// MARK: - Setup

/// What to know and choose before a game run starts.
struct RunGameSetupSheet: View {
    let kind: RunGameKind
    var onStart: (RunGameSetup) -> Void

    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var setup: RunGameSetup
    @State private var ghostID: UUID?

    init(kind: RunGameKind, onStart: @escaping (RunGameSetup) -> Void) {
        self.kind = kind
        self.onStart = onStart
        _setup = State(initialValue: RunGameSetup(kind: kind))
    }

    private var canStart: Bool {
        kind != .ghost || ghostID != nil
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    VStack(alignment: .leading, spacing: 14) {
                        Image(systemName: kind.icon)
                            .font(.system(size: 30, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(width: 66, height: 66)
                            .background(kind.color.gradient)
                            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                        Text(kind.title.uppercased())
                            .font(.flexDisplay(34))
                            .foregroundStyle(Theme.ink)
                        Text(howItWorks)
                            .font(.flexBody())
                            .foregroundStyle(Theme.inkSubtle)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    options

                    Toggle(isOn: $setup.voiceOn) {
                        Label("Voice prompts", systemImage: "speaker.wave.2.fill")
                            .font(.flexBody())
                            .foregroundStyle(Theme.ink)
                    }
                    .tint(Theme.accent)
                    .padding(14)
                    .background(Theme.card)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

                    Text("Headphones in, phone in a pocket. Prompts duck your music instead of stopping it.")
                        .font(.flexCaption())
                        .foregroundStyle(Theme.inkSubtle)
                }
                .padding(20)
            }
            .background(Theme.background)
            .safeAreaInset(edge: .bottom) {
                Button {
                    var chosen = setup
                    chosen.ghost = store.ghostCandidates.first { $0.id == ghostID }
                    onStart(chosen)
                    dismiss()
                } label: {
                    Label("Start \(kind.title)", systemImage: "play.fill")
                }
                .buttonStyle(PrimaryButtonStyle())
                .disabled(!canStart)
                .opacity(canStart ? 1 : 0.4)
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(Theme.background)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .onAppear {
                if ghostID == nil { ghostID = store.ghostCandidates.first?.id }
            }
        }
        .tint(Theme.ink)
    }

    private var howItWorks: String {
        switch kind {
        case .zombies:
            let next = store.zombieMissionsPlayed % ZombieEscape.missions.count
            return "Mission \(next + 1): \(ZombieEscape.missions[next].title). You'll pick up supplies as you run. Every few minutes a horde turns up 50 m behind you. Hold your pace and they catch you; push about a fifth faster for a minute and you lose them. Their speed comes from your own recent pace, so it's a fair fight at any speed."
        case .ghost:
            return "Pick one of your past runs. Its ghost runs beside you at exactly the pace you ran that day, and you'll hear when you pass it, when it passes you, and how far apart you are."
        case .territory:
            return "The map is cut into blocks about 170 m across. Every block you run through becomes yours, and you'll hear each new one. Every GPS run claims blocks; this mode makes a game of finding new streets."
        case .checkpoints:
            return "Checkpoints are dropped around where you start. Find them all, in any order, and you'll be told the distance and direction to the next. They're placed by distance, not on paths, so skip one that lands somewhere you can't reach."
        case .free:
            return "Just run."
        }
    }

    @ViewBuilder
    private var options: some View {
        switch kind {
        case .ghost:
            VStack(alignment: .leading, spacing: 10) {
                Text("RACE AGAINST")
                    .font(.flexMono(10))
                    .tracking(2)
                    .foregroundStyle(Theme.inkSubtle)
                if store.ghostCandidates.isEmpty {
                    Text("Finish one run of at least 400 m first. Then you'll have a ghost to race.")
                        .font(.flexCaption())
                        .foregroundStyle(Theme.inkSubtle)
                } else {
                    VStack(spacing: 0) {
                        ForEach(store.ghostCandidates) { run in
                            Button {
                                ghostID = run.id
                            } label: {
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("\(RunFormat.kilometers(run.kilometers)) km in \(RunFormat.duration(run.duration))")
                                            .font(.flexBodyBold())
                                            .foregroundStyle(Theme.ink)
                                        Text("\(run.date.formatted(.dateTime.weekday(.abbreviated).day().month())) · \(RunFormat.pace(run.paceSecondsPerKm)) /km".uppercased())
                                            .font(.flexMono(9))
                                            .tracking(1)
                                            .foregroundStyle(Theme.inkSubtle)
                                    }
                                    Spacer()
                                    Image(systemName: ghostID == run.id ? "checkmark.circle.fill" : "circle")
                                        .foregroundStyle(ghostID == run.id ? RunGameKind.ghost.color : Theme.inkSubtle.opacity(0.4))
                                }
                                .padding(14)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            if run.id != store.ghostCandidates.last?.id {
                                Divider().padding(.leading, 14)
                            }
                        }
                    }
                    .background(Theme.card)
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                }
            }
        case .checkpoints:
            VStack(alignment: .leading, spacing: 10) {
                Text("LENGTH")
                    .font(.flexMono(10))
                    .tracking(2)
                    .foregroundStyle(Theme.inkSubtle)
                ForEach(CheckpointHunt.Length.allCases) { length in
                    OptionCard(
                        eyebrow: "\(length.count) CHECKPOINTS",
                        title: length.label,
                        color: RunGameKind.checkpoints.color,
                        isSelected: setup.huntLength == length
                    ) {
                        setup.huntLength = length
                    }
                }
            }
        default:
            EmptyView()
        }
    }
}

// MARK: - Live display

/// The game's part of the run screen, above the time.
struct GameHUD: View {
    let session: RunGameSession

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let zombies = session.zombies {
                ZombieHUD(game: zombies)
            } else if let ghost = session.ghost {
                GhostHUD(race: ghost)
            } else if let territory = session.territory {
                TerritoryHUD(game: territory)
            } else if let hunt = session.hunt {
                HuntHUD(hunt: hunt)
            }
            if let line = session.lastEvent {
                Text(line)
                    .font(.flexCaption())
                    .foregroundStyle(Theme.inkSubtle)
                    .lineLimit(2)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .transition(.opacity)
                    .id(line)
            }
        }
        .padding(14)
        .background(Theme.card)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .padding(.horizontal, 20)
        .animation(.snappy, value: session.lastEvent)
    }
}

private struct HUDLabel: View {
    let text: String
    var color: Color = Theme.inkSubtle

    var body: some View {
        Text(text.uppercased())
            .font(.flexMono(9))
            .tracking(1.5)
            .foregroundStyle(color)
    }
}

private struct ZombieHUD: View {
    let game: ZombieEscape

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                HUDLabel(text: "Mission \(game.missionIndex % ZombieEscape.missions.count + 1) · \(game.mission.title)", color: RunGameKind.zombies.color)
                Spacer()
                Label("\(game.supplies.count)", systemImage: "backpack.fill")
                    .font(.flexBodyBold())
                    .foregroundStyle(Theme.ink)
                    .accessibilityLabel("\(game.supplies.count) supplies")
            }
            if game.phase == .chase {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(alignment: .firstTextBaseline) {
                        Text("\(max(0, Int(game.gap))) M")
                            .font(.flexStat(30))
                            .monospacedDigit()
                            .foregroundStyle(RunGameKind.zombies.color)
                            .contentTransition(.numericText())
                        Text("BEHIND YOU")
                            .font(.flexMono(10))
                            .tracking(1.5)
                            .foregroundStyle(RunGameKind.zombies.color)
                        Spacer()
                        Text("HOLD \(RunFormat.duration(game.chaseRemaining))")
                            .font(.flexMono(10))
                            .tracking(1)
                            .monospacedDigit()
                            .foregroundStyle(Theme.ink)
                    }
                    GeometryReader { proxy in
                        ZStack(alignment: .leading) {
                            Capsule().fill(RunGameKind.zombies.color.opacity(0.15))
                            Capsule()
                                .fill(RunGameKind.zombies.color)
                                .frame(width: proxy.size.width * CGFloat(min(1, max(0, game.gap / ZombieEscape.escapeGap))))
                        }
                    }
                    .frame(height: 8)
                    .animation(.snappy, value: game.gap)
                }
            } else {
                HStack(spacing: 16) {
                    Label(game.needsGPS ? "Needs GPS" : "Running clear", systemImage: game.needsGPS ? "location.slash" : "checkmark.shield.fill")
                        .font(.flexBodyBold())
                        .foregroundStyle(Theme.ink)
                    Spacer()
                    Text("ESCAPED \(game.escaped) · CAUGHT \(game.caught)")
                        .font(.flexMono(9))
                        .tracking(1)
                        .foregroundStyle(Theme.inkSubtle)
                }
            }
        }
    }
}

private struct GhostHUD: View {
    let race: GhostRace

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                HUDLabel(text: race.finishedAt != nil ? "Finished" : (race.lead >= 0 ? "Ahead of your ghost" : "Behind your ghost"), color: RunGameKind.ghost.color)
                Spacer()
                Text("\(Int(abs(race.lead))) M")
                    .font(.flexStat(26))
                    .monospacedDigit()
                    .foregroundStyle(race.lead >= 0 ? Theme.accent : Theme.danger)
                    .contentTransition(.numericText())
            }
            progressRow("YOU", fraction: race.ghost.distance > 0 ? (race.ghostDistance + race.lead) / race.ghost.distance : 0, color: Theme.ink)
            progressRow("GHOST", fraction: race.ghost.distance > 0 ? race.ghostDistance / race.ghost.distance : 0, color: RunGameKind.ghost.color)
        }
    }

    private func progressRow(_ label: String, fraction: Double, color: Color) -> some View {
        HStack(spacing: 8) {
            Text(label)
                .font(.flexMono(8))
                .tracking(1)
                .foregroundStyle(Theme.inkSubtle)
                .frame(width: 40, alignment: .leading)
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule().fill(Theme.ink.opacity(0.08))
                    Capsule()
                        .fill(color)
                        .frame(width: proxy.size.width * CGFloat(min(1, max(0, fraction))))
                }
            }
            .frame(height: 6)
        }
    }
}

private struct TerritoryHUD: View {
    let game: TerritoryRun

    var body: some View {
        HStack(spacing: 0) {
            stat("\(game.newBlocks)", "New blocks", color: RunGameKind.territory.color)
            Rectangle().fill(Theme.inkSubtle.opacity(0.18)).frame(width: 1, height: 30)
            stat("\(game.total)", "Owned", color: Theme.ink)
        }
    }

    private func stat(_ value: String, _ label: String, color: Color) -> some View {
        VStack(spacing: 3) {
            Text(value)
                .font(.flexStat(26))
                .monospacedDigit()
                .foregroundStyle(color)
                .contentTransition(.numericText())
            HUDLabel(text: label)
        }
        .frame(maxWidth: .infinity)
    }
}

private struct HuntHUD: View {
    let hunt: CheckpointHunt

    var body: some View {
        HStack(spacing: 14) {
            if let next = hunt.nearest {
                Image(systemName: "location.north.fill")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(RunGameKind.checkpoints.color)
                    .rotationEffect(.degrees(next.bearing))
                    .frame(width: 46, height: 46)
                    .background(RunGameKind.checkpoints.color.opacity(0.12))
                    .clipShape(Circle())
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 2) {
                    HUDLabel(text: "Checkpoint \(hunt.found + 1) of \(hunt.checkpoints.count)", color: RunGameKind.checkpoints.color)
                    Text("\(Int(next.meters)) m \(Geo.compassShort(next.bearing))")
                        .font(.flexStat(24))
                        .monospacedDigit()
                        .foregroundStyle(Theme.ink)
                }
                Spacer()
                Button("Skip") { hunt.skipNearest() }
                    .font(.flexMono(10))
                    .foregroundStyle(Theme.inkSubtle)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Theme.background)
                    .clipShape(Capsule())
                    .buttonStyle(.plain)
            } else if hunt.isComplete {
                Label("All \(hunt.checkpoints.count) found. Head home.", systemImage: "flag.checkered")
                    .font(.flexBodyBold())
                    .foregroundStyle(Theme.accent)
            } else {
                Label("Finding your position", systemImage: "location.magnifyingglass")
                    .font(.flexBodyBold())
                    .foregroundStyle(Theme.inkSubtle)
            }
        }
    }
}

// MARK: - Map layers

/// Territory blocks and checkpoints drawn on the live run map.
struct GameMapLayers {
    /// Blocks to draw: owned blocks near you plus this run's claims.
    static func territoryCells(_ game: TerritoryRun, near here: CLLocationCoordinate2D?) -> (owned: [String], claimed: [String]) {
        let claimed = Array(game.claimed.subtracting(game.owned))
        guard let here else { return ([], claimed) }
        let owned = game.owned.filter { id in
            guard let center = TerritoryGrid.center(of: id) else { return false }
            return Geo.distance(center, here) < 1500
        }
        return (Array(owned.prefix(400)), claimed)
    }
}

// MARK: - Results

/// How a game run went, on the run's detail page.
struct GameResultCard: View {
    let result: RunGameResult

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: result.kind.icon)
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 48, height: 48)
                .background(result.kind.color.gradient)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            VStack(alignment: .leading, spacing: 3) {
                HUDLabel(text: result.kind.title, color: result.kind.color)
                Text(result.headline)
                    .font(.flexBodyBold())
                    .foregroundStyle(Theme.ink)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
            if result.won {
                Image(systemName: "trophy.fill")
                    .foregroundStyle(Theme.amber)
                    .accessibilityLabel("Won")
            }
        }
        .padding(14)
        .background(Theme.card)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

// MARK: - Territory map

/// Every block you've claimed, on one map.
struct TerritoryMapView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        let cells = Array(store.territory.prefix(3000))
        NavigationStack {
            VStack(spacing: 0) {
                StatStrip([
                    ("\(store.territory.count)", "Blocks"),
                    (String(format: "%.1f", Double(store.territory.count) * TerritoryGrid.cellSquareKm), "km² owned"),
                    ("\(store.runs.filter { !$0.coordinates.isEmpty }.count)", "GPS runs")
                ])
                .padding(.horizontal, 20)
                .padding(.vertical, 12)

                if cells.isEmpty {
                    Spacer()
                    EmptyStateCard(
                        icon: "square.grid.3x3",
                        title: "No territory yet",
                        message: "Record a run with location on and every block you pass through becomes yours."
                    )
                    .padding(20)
                    Spacer()
                } else {
                    Map(initialPosition: .automatic) {
                        ForEach(cells, id: \.self) { id in
                            MapPolygon(coordinates: TerritoryGrid.polygon(for: id))
                                .foregroundStyle(Theme.accent.opacity(0.35))
                                .stroke(Theme.accent, lineWidth: 1)
                        }
                    }
                    .mapStyle(.standard(elevation: .flat, emphasis: .muted))
                }
            }
            .background(Theme.background)
            .navigationTitle("Territory")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .tint(Theme.ink)
    }
}
