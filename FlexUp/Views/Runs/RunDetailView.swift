import SwiftUI
import MapKit

/// A finished run, Strava-style: the route on a map, headline stats,
/// and per-km splits with pace bars.
struct RunDetailView: View {
    let run: Run
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var confirmDelete = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                header
                routeMap
                statsGrid
                splitsSection
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 24)
        }
        .scrollIndicators(.hidden)
        .background(Theme.background)
        .navigationTitle(run.date.formatted(.dateTime.weekday(.wide).day().month()))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(role: .destructive) {
                    confirmDelete = true
                } label: {
                    Image(systemName: "trash")
                }
                .accessibilityLabel("Delete run")
            }
        }
        .confirmationDialog("Delete this run?", isPresented: $confirmDelete, titleVisibility: .visible) {
            Button("Delete run", role: .destructive) {
                store.deleteRun(run)
                dismiss()
            }
            Button("Cancel", role: .cancel) {}
        }
    }

    // MARK: Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(run.date.formatted(.dateTime.hour().minute()).uppercased() + " RUN")
                .font(.flexMono(11))
                .tracking(2)
                .foregroundStyle(Theme.inkSubtle)
            Text("\(RunFormat.kilometers(run.kilometers)) KM")
                .font(.flexDisplay(44))
                .foregroundStyle(Theme.ink)
        }
        .padding(.top, 8)
    }

    // MARK: Map

    private var routeMap: some View {
        Group {
            if run.coordinates.count > 1 {
                Map(initialPosition: .automatic, interactionModes: [.zoom, .pan]) {
                    MapPolyline(coordinates: run.coordinates)
                        .stroke(Theme.accent, style: StrokeStyle(lineWidth: 5, lineCap: .round, lineJoin: .round))
                    if let start = run.coordinates.first {
                        Annotation("Start", coordinate: start) {
                            markerDot(Theme.accent)
                        }
                    }
                    if let end = run.coordinates.last {
                        Annotation("Finish", coordinate: end) {
                            markerDot(Theme.ink)
                        }
                    }
                }
                .mapStyle(.standard(elevation: .flat))
                .frame(height: 260)
                .clipShape(RoundedRectangle(cornerRadius: Theme.cornerRadius, style: .continuous))
            } else {
                FlexCard {
                    Label("No route recorded for this run.", systemImage: "location.slash")
                        .font(.flexCaption())
                        .foregroundStyle(Theme.inkSubtle)
                }
            }
        }
    }

    private func markerDot(_ color: Color) -> some View {
        Circle()
            .fill(color)
            .frame(width: 14, height: 14)
            .overlay(Circle().stroke(.white, lineWidth: 3))
    }

    // MARK: Stats

    private var statsGrid: some View {
        VStack(spacing: 10) {
            StatStrip([
                (RunFormat.duration(run.duration), "Time"),
                (RunFormat.pace(run.paceSecondsPerKm), "Avg pace")
            ])
            StatStrip([
                ("\(Int(run.elevationGainM ?? 0))", "Elev gain M"),
                ("\(Int((run.kilometers * 62).rounded()))", "Est kcal")
            ])
        }
    }

    // MARK: Splits

    private var splitsSection: some View {
        Group {
            if !run.splits.isEmpty {
                FlexCard {
                    VStack(alignment: .leading, spacing: 12) {
                        SectionHeader(title: "Splits", subtitle: "Longer bar, faster kilometre.")
                        VStack(spacing: 8) {
                            ForEach(Array(run.splits.enumerated()), id: \.offset) { index, seconds in
                                splitRow(label: "\(index + 1)", seconds: seconds, fraction: fraction(for: seconds))
                            }
                            if run.finalPartialMeters > 50, run.splits.count >= 1 {
                                partialRow
                            }
                        }
                    }
                }
            }
        }
    }

    /// Bar length relative to the fastest split (fastest = full width).
    private func fraction(for seconds: Double) -> Double {
        guard let fastest = run.splits.min(), seconds > 0 else { return 0 }
        return max(0.15, fastest / seconds)
    }

    private func splitRow(label: String, seconds: Double, fraction: Double) -> some View {
        HStack(spacing: 10) {
            Text(label)
                .font(.flexMono(11))
                .foregroundStyle(Theme.inkSubtle)
                .frame(width: 22, alignment: .leading)
            GeometryReader { proxy in
                Capsule()
                    .fill(Theme.accent)
                    .frame(width: max(8, proxy.size.width * fraction), height: 10)
                    .frame(maxHeight: .infinity, alignment: .center)
            }
            .frame(height: 16)
            Text(RunFormat.pace(seconds))
                .font(.flexMono(11))
                .monospacedDigit()
                .foregroundStyle(Theme.ink)
                .frame(width: 52, alignment: .trailing)
        }
    }

    private var partialRow: some View {
        let meters = run.finalPartialMeters
        let fullSplitTime = run.splits.reduce(0, +)
        let partialSeconds = max(0, run.duration - fullSplitTime)
        let projectedPace = meters > 0 ? partialSeconds / (meters / 1000) : 0

        return HStack(spacing: 10) {
            Text(String(format: "%.1f", meters / 1000).replacingOccurrences(of: "0.", with: "."))
                .font(.flexMono(11))
                .foregroundStyle(Theme.inkSubtle)
                .frame(width: 22, alignment: .leading)
            GeometryReader { proxy in
                Capsule()
                    .fill(Theme.accentSoft)
                    .frame(width: max(8, proxy.size.width * fraction(for: projectedPace)), height: 10)
                    .frame(maxHeight: .infinity, alignment: .center)
            }
            .frame(height: 16)
            Text(RunFormat.pace(projectedPace))
                .font(.flexMono(11))
                .monospacedDigit()
                .foregroundStyle(Theme.inkSubtle)
                .frame(width: 52, alignment: .trailing)
        }
    }
}
