import SwiftUI

/// The running section of Track: lifetime stats, one big Start button, and
/// history. Finishing a run auto-completes today's run commitment.
struct RunSection: View {
    @Environment(AppStore.self) private var store
    @State private var tracker = RunTracker()
    @State private var showActiveRun = false

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            statRow
            startButton
            historySection
        }
        .fullScreenCover(isPresented: $showActiveRun) {
            ActiveRunView(tracker: tracker)
        }
    }

    // MARK: Stats

    private var statRow: some View {
        HStack(spacing: 10) {
            TrackStat(value: RunFormat.kilometers(store.totalRunKilometers), label: "Total KM")
            TrackStat(value: "\(store.runs.count)", label: "Runs")
            TrackStat(value: RunFormat.pace(store.bestPaceSecondsPerKm), label: "Best pace")
        }
    }

    // MARK: Start

    private var startButton: some View {
        Button {
            tracker.start()
            showActiveRun = true
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
            SectionHeader(title: "History", subtitle: store.runs.isEmpty ? nil : "Most recent first.")
            if store.runs.isEmpty {
                EmptyStateCard(
                    icon: "figure.run",
                    title: "No runs yet",
                    message: "Your first run is one button away. Slow counts. Short counts."
                )
            } else {
                ForEach(store.runs) { run in
                    RunRow(run: run)
                }
            }
        }
    }
}

// MARK: - Shared stat tile for Track sections

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
                IconBadge(systemName: "figure.run", size: 42)
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
            }
        }
    }
}

// MARK: - Active run

/// Full-screen tracking view. Giant numbers, nothing else — like a watch face.
struct ActiveRunView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    let tracker: RunTracker

    @State private var confirmDiscard = false

    var body: some View {
        VStack(spacing: 0) {
            Text(tracker.phase == .paused ? "PAUSED" : "RUN IN PROGRESS")
                .font(.flexMono(12))
                .tracking(3)
                .foregroundStyle(tracker.phase == .paused ? Theme.amber : Theme.accent)
                .padding(.top, 28)

            Spacer()

            VStack(spacing: 6) {
                Text(RunFormat.duration(tracker.elapsed))
                    .font(.flexDisplay(78))
                    .monospacedDigit()
                    .foregroundStyle(Theme.ink)
                    .minimumScaleFactor(0.5)
                    .lineLimit(1)
                Text("TIME")
                    .font(.flexMono(11))
                    .tracking(3)
                    .foregroundStyle(Theme.inkSubtle)
            }

            HStack(spacing: 44) {
                VStack(spacing: 6) {
                    Text(RunFormat.kilometers(tracker.distanceMeters / 1000))
                        .font(.flexStat(38))
                        .monospacedDigit()
                        .foregroundStyle(Theme.ink)
                    Text("KM")
                        .font(.flexMono(11))
                        .tracking(3)
                        .foregroundStyle(Theme.inkSubtle)
                }
                VStack(spacing: 6) {
                    Text(RunFormat.pace(tracker.currentPaceSecondsPerKm))
                        .font(.flexStat(38))
                        .monospacedDigit()
                        .foregroundStyle(Theme.ink)
                    Text("PACE /KM")
                        .font(.flexMono(11))
                        .tracking(3)
                        .foregroundStyle(Theme.inkSubtle)
                }
            }
            .padding(.top, 40)

            if tracker.locationDenied {
                Text("Location is off, so distance can't be measured — time still counts. Enable it in Settings → Privacy.")
                    .font(.flexCaption())
                    .foregroundStyle(Theme.inkSubtle)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 36)
                    .padding(.top, 24)
            }

            Spacer()

            VStack(spacing: 10) {
                Button(tracker.phase == .paused ? "Resume" : "Pause") {
                    tracker.phase == .paused ? tracker.resume() : tracker.pause()
                }
                .buttonStyle(SecondaryButtonStyle())

                Button("Finish run") {
                    let result = tracker.finish()
                    store.logRun(distanceMeters: result.distanceMeters, duration: result.duration)
                    dismiss()
                }
                .buttonStyle(PrimaryButtonStyle())
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 16)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.background)
        .interactiveDismissDisabled(true)
        .overlay(alignment: .topLeading) {
            Button {
                confirmDiscard = true
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(Theme.inkSubtle)
                    .padding(12)
                    .background(Theme.card)
                    .clipShape(Circle())
            }
            .padding(16)
        }
        .confirmationDialog("Discard this run?", isPresented: $confirmDiscard, titleVisibility: .visible) {
            Button("Discard run", role: .destructive) {
                _ = tracker.finish()
                dismiss()
            }
            Button("Keep running", role: .cancel) {}
        }
    }
}
