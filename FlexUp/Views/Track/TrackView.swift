import SwiftUI

/// The tracking hub: everything you *do* gets measured here, and everything
/// measured feeds the same loop — runs (GPS), lifts (training log), fuel
/// (calories), and progress photos.
struct TrackView: View {
    enum TrackSection: String, CaseIterable, Identifiable {
        case run = "Run"
        case lift = "Lift"
        case fuel = "Fuel"
        case photos = "Photos"
        var id: String { rawValue }
    }

    @State private var section: TrackSection = .run

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    ScreenHeader(title: "Track", tagline: "Run. Lift. Fuel. Proof.")
                    SegmentPills(items: TrackSection.allCases, selection: $section)

                    switch section {
                    case .run: RunSection()
                    case .lift: LiftSection()
                    case .fuel: FuelSection()
                    case .photos: PhotoSection()
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 24)
            }
            .scrollIndicators(.hidden)
            .background(Theme.background)
            .toolbar(.hidden, for: .navigationBar)
        }
    }
}

#Preview {
    TrackView()
        .environment(AppStore())
}
