import SwiftUI
import MapKit

/// The running pillar: lifetime stats, one big Start button, and history.
/// Runs record a GPS route, per-km splits, and elevation — tap one to see
/// the map. Finishing auto-completes today's run commitment.
struct RunSection: View {
    @Environment(AppStore.self) private var store
    @State private var tracker = RunTracker()
    @State private var showActiveRun = false
    @State private var session: RunGameSession?
    @State private var setupKind: RunGameKind?
    /// Chosen on the setup sheet; the run starts once the sheet is gone.
    @State private var pendingSetup: RunGameSetup?
    @State private var showTerritory = false

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            statRow
            startButton
            RunGamesSection(
                onPick: { setupKind = $0 },
                onShowTerritory: { showTerritory = true }
            )
            historySection
        }
        .fullScreenCover(isPresented: $showActiveRun) {
            ActiveRunView(tracker: tracker, session: session)
        }
        .sheet(item: $setupKind, onDismiss: {
            if let setup = pendingSetup {
                pendingSetup = nil
                start(setup)
            }
        }) { kind in
            RunGameSetupSheet(kind: kind) { setup in pendingSetup = setup }
        }
        .sheet(isPresented: $showTerritory) {
            TerritoryMapView()
        }
    }

    /// A plain run (nil) or a game.
    private func start(_ setup: RunGameSetup?) {
        session = setup.map {
            RunGameSession(setup: $0, missionIndex: store.zombieMissionsPlayed, ownedBlocks: store.territory)
        }
        tracker.start()
        session?.attach(to: tracker)
        showActiveRun = true
    }

    // MARK: Stats

    private var statRow: some View {
        StatStrip([
            (RunFormat.kilometers(store.totalRunKilometers), "Total KM"),
            ("\(store.runs.count)", "Runs"),
            (RunFormat.pace(store.bestPaceSecondsPerKm), "Best pace")
        ])
    }

    // MARK: Start

    private var startButton: some View {
        Button {
            start(nil)
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "figure.run")
                Text("Start run")
            }
        }
        .buttonStyle(PrimaryButtonStyle())
    }

    // MARK: History

    private var historySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "History")
            if store.runs.isEmpty {
                EmptyStateCard(
                    icon: "figure.run",
                    title: "No runs yet",
                    message: "Your first run is one button away. Slow counts. Short counts."
                )
            } else {
                ForEach(store.runs) { run in
                    NavigationLink(value: run) {
                        RunRow(run: run)
                    }
                    .buttonStyle(.plain)
                    .contextMenu {
                        Button(role: .destructive) {
                            store.deleteRun(run)
                        } label: {
                            Label("Delete run", systemImage: "trash")
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Shared stat tile for pillar screens

struct TrackStat: View {
    let value: String
    let label: String

    var body: some View {
        VStack(spacing: 6) {
            Text(value)
                .font(.flexStat(26))
                .foregroundStyle(Theme.ink)
                .minimumScaleFactor(0.6)
                .lineLimit(1)
            Text(label.uppercased())
                .font(.flexMono(10))
                .tracking(1.5)
                .foregroundStyle(Theme.inkSubtle)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 18)
        .background(Theme.card)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

// MARK: - Run row

struct RunRow: View {
    let run: Run

    var body: some View {
        FlexCard(padding: 16) {
            HStack(alignment: .center, spacing: 14) {
                IconBadge(systemName: run.coordinates.count > 1 ? "map" : "figure.run", size: 42)
                VStack(alignment: .leading, spacing: 3) {
                    Text("\(RunFormat.kilometers(run.kilometers)) km")
                        .font(.flexStat(20))
                        .foregroundStyle(Theme.ink)
                    Text(run.date.formatted(.dateTime.weekday(.abbreviated).day().month().hour().minute()).uppercased())
                        .font(.flexMono(10))
                        .tracking(1)
                        .foregroundStyle(Theme.inkSubtle)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 3) {
                    Text(RunFormat.duration(run.duration))
                        .font(.flexBodyBold())
                        .monospacedDigit()
                        .foregroundStyle(Theme.ink)
                    Text("\(RunFormat.pace(run.paceSecondsPerKm)) /KM")
                        .font(.flexMono(10))
                        .tracking(1)
                        .foregroundStyle(Theme.inkSubtle)
                }
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Theme.inkSubtle)
            }
        }
    }
}

// MARK: - Active run (Strava-style: live map on top, numbers below)

struct ActiveRunView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    let tracker: RunTracker
    /// The game being played, if any.
    var session: RunGameSession?

    @State private var confirmDiscard = false
    @State private var voiceOn = Announcer.shared.voiceOn
    @State private var camera: MapCameraPosition = .userLocation(fallback: .automatic)

    var body: some View {
        VStack(spacing: 0) {
            liveMap
            statsPanel
        }
        .background(Theme.background)
        .overlay {
            // The edges glow red while a horde is chasing you.
            if session?.zombies?.phase == .chase {
                ChaseGlow()
                    .allowsHitTesting(false)
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.4), value: session?.zombies?.phase == .chase)
        .interactiveDismissDisabled(true)
        .confirmationDialog("Discard this run?", isPresented: $confirmDiscard, titleVisibility: .visible) {
            Button("Discard run", role: .destructive) {
                _ = tracker.finish()
                Announcer.shared.stop()
                dismiss()
            }
            Button("Keep running", role: .cancel) {}
        }
    }

    // MARK: Map

    private var liveMap: some View {
        Map(position: $camera) {
            if let territory = session?.territory {
                let cells = GameMapLayers.territoryCells(territory, near: tracker.routeCoordinates.last)
                ForEach(cells.owned, id: \.self) { id in
                    MapPolygon(coordinates: TerritoryGrid.polygon(for: id))
                        .foregroundStyle(Theme.accent.opacity(0.18))
                }
                ForEach(cells.claimed, id: \.self) { id in
                    MapPolygon(coordinates: TerritoryGrid.polygon(for: id))
                        .foregroundStyle(Theme.accent.opacity(0.45))
                        .stroke(Theme.accent, lineWidth: 1)
                }
            }
            if let hunt = session?.hunt {
                ForEach(hunt.checkpoints) { checkpoint in
                    Annotation("Checkpoint \(checkpoint.id)", coordinate: checkpoint.coordinate) {
                        checkpointPin(checkpoint)
                    }
                }
            }
            UserAnnotation()
            if tracker.routeCoordinates.count > 1 {
                MapPolyline(coordinates: tracker.routeCoordinates)
                    .stroke(Theme.accent, style: StrokeStyle(lineWidth: 5, lineCap: .round, lineJoin: .round))
            }
        }
        .mapStyle(.standard(elevation: .flat))
        .overlay(alignment: .top) {
            HStack {
                Button {
                    confirmDiscard = true
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(Theme.ink)
                        .padding(12)
                        .background(.thinMaterial)
                        .clipShape(Circle())
                }
                Spacer()
                if session != nil {
                    Button {
                        voiceOn.toggle()
                        Announcer.shared.voiceOn = voiceOn
                        if !voiceOn { Announcer.shared.stop() }
                    } label: {
                        Image(systemName: voiceOn ? "speaker.wave.2.fill" : "speaker.slash.fill")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(Theme.ink)
                            .padding(12)
                            .background(.thinMaterial)
                            .clipShape(Circle())
                    }
                    .accessibilityLabel(voiceOn ? "Mute voice prompts" : "Turn on voice prompts")
                }
                Text(tracker.phase == .paused ? "PAUSED" : (session.map { $0.kind.title.uppercased() } ?? "RECORDING"))
                    .font(.flexMono(11))
                    .tracking(3)
                    .foregroundStyle(tracker.phase == .paused ? Theme.amber : Theme.accent)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 9)
                    .background(.thinMaterial)
                    .clipShape(Capsule())
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
        }
    }

    // MARK: Stats

    private var statsPanel: some View {
        VStack(spacing: 18) {
            Capsule()
                .fill(Theme.inkSubtle.opacity(0.3))
                .frame(width: 36, height: 5)
                .padding(.top, 12)

            if let session {
                GameHUD(session: session)
            }

            VStack(spacing: 4) {
                Text(RunFormat.duration(tracker.elapsed))
                    .font(.flexDisplay(session == nil ? 56 : 44))
                    .monospacedDigit()
                    .foregroundStyle(Theme.ink)
                    .minimumScaleFactor(0.5)
                    .lineLimit(1)
                Text("TIME")
                    .font(.flexMono(10))
                    .tracking(3)
                    .foregroundStyle(Theme.inkSubtle)
            }

            HStack {
                liveStat(RunFormat.kilometers(tracker.distanceMeters / 1000), "KM")
                liveStat(RunFormat.pace(tracker.currentPaceSecondsPerKm), "PACE /KM")
                liveStat("\(Int(tracker.elevationGain))", "ELEV M")
            }

            if tracker.locationDenied {
                Text("Location is off, so only time counts. Enable it in Settings → Privacy to record route and distance.")
                    .font(.flexCaption())
                    .foregroundStyle(Theme.inkSubtle)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
            }

            HStack(spacing: 10) {
                Button(tracker.phase == .paused ? "Resume" : "Pause") {
                    tracker.phase == .paused ? tracker.resume() : tracker.pause()
                }
                .buttonStyle(SecondaryButtonStyle())

                Button("Finish") {
                    let game = session?.result()
                    let result = tracker.finish()
                    store.logRun(
                        distanceMeters: result.distanceMeters,
                        duration: result.duration,
                        route: result.route,
                        splitsSeconds: result.splitsSeconds,
                        elevationGainM: result.elevationGainM,
                        game: game
                    )
                    dismiss()
                }
                .buttonStyle(PrimaryButtonStyle())
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 14)
        }
        .frame(maxWidth: .infinity)
        .background(Theme.background)
    }

    private func checkpointPin(_ checkpoint: CheckpointHunt.Checkpoint) -> some View {
        ZStack {
            Circle()
                .fill(checkpoint.found ? Theme.accent : (checkpoint.skipped ? Theme.inkSubtle : RunGameKind.checkpoints.color))
                .frame(width: 30, height: 30)
                .overlay(Circle().stroke(.white, lineWidth: 2))
            if checkpoint.found {
                Image(systemName: "checkmark")
                    .font(.system(size: 12, weight: .heavy))
                    .foregroundStyle(.white)
            } else {
                Text("\(checkpoint.id)")
                    .font(.system(size: 13, weight: .heavy))
                    .foregroundStyle(.white)
            }
        }
    }

    private func liveStat(_ value: String, _ label: String) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.flexStat(28))
                .monospacedDigit()
                .foregroundStyle(Theme.ink)
                .minimumScaleFactor(0.6)
                .lineLimit(1)
            Text(label)
                .font(.flexMono(9))
                .tracking(2)
                .foregroundStyle(Theme.inkSubtle)
        }
        .frame(maxWidth: .infinity)
    }
}

/// Pulsing red edges while a zombie horde is chasing.
private struct ChaseGlow: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var pulse = false

    var body: some View {
        RoundedRectangle(cornerRadius: 44, style: .continuous)
            .strokeBorder(Theme.danger.opacity(pulse ? 0.85 : 0.35), lineWidth: 10)
            .blur(radius: 8)
            .ignoresSafeArea()
            .onAppear {
                guard !reduceMotion else { return }
                withAnimation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true)) { pulse = true }
            }
    }
}
