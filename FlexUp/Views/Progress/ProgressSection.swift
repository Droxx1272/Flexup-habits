import SwiftUI
import Charts

/// Every pillar over time, on one page: follow-through, wake-ups, sleep,
/// runs, lifting, food and body weight. Presented as the Progress segment
/// of `TodayView`, so it owns no navigation of its own. Days with nothing
/// logged are gaps, never zeros — the page only shows what really happened.
struct ProgressSection: View {
    @Environment(AppStore.self) private var store
    @State private var range: ProgressRange = .month

    private var calendar: Calendar { .current }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            SegmentPills(items: ProgressRange.allCases, selection: $range)
            overview
            consistencyCard
            wakeCard
            sleepCard
            runCard
            gymCard
            dietCard
            bodyCard
        }
    }

    // MARK: Chart plumbing

    /// Full range on the x axis, so a quiet stretch reads as a gap.
    private var xDomain: ClosedRange<Date> {
        let start = calendar.dateInterval(of: range.bucket, for: store.rangeStart(range))?.start ?? store.rangeStart(range)
        let end = calendar.dateInterval(of: range.bucket, for: .now)?.end ?? .now
        return start...end
    }

    private var axisFormat: Date.FormatStyle {
        switch range {
        case .week: Date.FormatStyle.dateTime.weekday(.narrow)
        case .month, .quarter: Date.FormatStyle.dateTime.day().month(.abbreviated)
        case .year: Date.FormatStyle.dateTime.month(.abbreviated)
        }
    }

    private var bucketWord: String { range.bucket == .day ? "day" : "week" }

    private func barChart(_ points: [DailyPoint], color: Color, target: Double? = nil) -> some View {
        Chart {
            ForEach(points) { point in
                BarMark(
                    x: .value("Date", point.date, unit: range.bucket),
                    y: .value("Value", point.value)
                )
                .foregroundStyle(color)
                .cornerRadius(4)
            }
            if let target {
                RuleMark(y: .value("Target", target))
                    .foregroundStyle(Theme.inkSubtle)
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
            }
        }
        .chartXScale(domain: xDomain)
        .chartXAxis { xAxis }
        .chartYAxis { yAxis }
        .frame(height: 140)
    }

    private func lineChart(_ points: [DailyPoint], color: Color, target: Double? = nil, includesZero: Bool = true) -> some View {
        Chart {
            ForEach(points) { point in
                LineMark(
                    x: .value("Date", point.date, unit: range.bucket),
                    y: .value("Value", point.value)
                )
                .foregroundStyle(color)
                .interpolationMethod(.catmullRom)
                PointMark(
                    x: .value("Date", point.date, unit: range.bucket),
                    y: .value("Value", point.value)
                )
                .foregroundStyle(color)
                .symbolSize(points.count > 30 ? 12 : 30)
            }
            if let target {
                RuleMark(y: .value("Target", target))
                    .foregroundStyle(Theme.inkSubtle)
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
            }
        }
        .chartXScale(domain: xDomain)
        .chartYScale(domain: .automatic(includesZero: includesZero))
        .chartXAxis { xAxis }
        .chartYAxis { yAxis }
        .frame(height: 140)
    }

    private var xAxis: some AxisContent {
        AxisMarks(values: .automatic(desiredCount: range == .week ? 7 : 4)) { _ in
            AxisValueLabel(format: axisFormat)
        }
    }

    private var yAxis: some AxisContent {
        AxisMarks(position: .leading, values: .automatic(desiredCount: 3)) { _ in
            AxisGridLine()
            AxisValueLabel()
        }
    }

    private func empty(_ message: String) -> some View {
        Text(message)
            .font(.flexCaption())
            .foregroundStyle(Theme.inkSubtle)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 8)
    }

    // MARK: Overview

    private var overview: some View {
        let sleep = store.sleepSessions(in: range)
        let avgSleep = sleep.isEmpty ? nil : sleep.reduce(0) { $0 + $1.hours } / Double(sleep.count)
        let km = store.runs(in: range).reduce(0) { $0 + $1.kilometers }
        let foodDays = store.foodDays(range)
        let avgCalories = foodDays.isEmpty ? nil : foodDays.reduce(0) { $0 + store.calories(on: $1) } / foodDays.count

        return VStack(alignment: .leading, spacing: 10) {
            SectionHeader(title: "At a glance", subtitle: "Your \(range.label), across every pillar.")
            HStack(spacing: 10) {
                TrackStat(value: "\(store.completedCount(range))", label: "Done")
                TrackStat(value: "\(store.wakeCheckIns(range))", label: "Wake-ups")
                TrackStat(value: avgSleep.map { String(format: "%.1fh", $0) } ?? "—", label: "Avg sleep")
            }
            HStack(spacing: 10) {
                TrackStat(value: String(format: "%.1f", km), label: "KM run")
                TrackStat(value: "\(store.workouts(in: range).count)", label: "Sessions")
                TrackStat(value: avgCalories.map { "\($0)" } ?? "—", label: "Avg kcal")
            }
        }
    }

    // MARK: Consistency

    private var consistencyCard: some View {
        let points = store.completionSeries(range)
        return ProgressCard(
            icon: "checkmark.circle",
            title: "Follow-through",
            subtitle: "Commitments completed, per \(bucketWord).",
            headline: store.completionRate(range).map { "\($0)%" } ?? "—",
            headlineLabel: "COMPLETED"
        ) {
            if points.isEmpty {
                empty("No finished commitments in the \(range.label) yet.")
            } else {
                barChart(points, color: Theme.accent, target: 100)
            }
            HStack(spacing: 0) {
                miniStat("\(store.currentStreak)", "Current streak")
                miniStat("\(store.bestStreak)", "Best streak")
                miniStat("\(store.completedCount(range))", "Completed")
            }
        }
    }

    // MARK: Wake

    private var wakeCard: some View {
        let days = store.wakeDays(range)
        let checkIns = days.filter { $0.checkedIn }.count
        let rate = days.isEmpty ? 0 : Int((Double(checkIns) / Double(days.count) * 100).rounded())
        let cell: CGFloat = switch range {
        case .week: 34
        case .month: 22
        case .quarter: 14
        case .year: 7
        }

        return ProgressCard(
            icon: "sunrise.fill",
            title: "Wake",
            subtitle: "Every square is a morning. Filled means you checked in.",
            headline: "\(rate)%",
            headlineLabel: "OF MORNINGS"
        ) {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: cell, maximum: cell), spacing: 3)], alignment: .leading, spacing: 3) {
                ForEach(days, id: \.date) { day in
                    RoundedRectangle(cornerRadius: max(2, cell * 0.25), style: .continuous)
                        .fill(day.checkedIn ? Theme.accent : Theme.accentSoft)
                        .frame(width: cell, height: cell)
                }
            }
            HStack(spacing: 0) {
                miniStat("\(checkIns)", "Check-ins")
                miniStat("\(store.wakeStreak)", "Streak")
                miniStat(String(format: "%02d:%02d", store.wake.hour, store.wake.minute), "Alarm")
            }
        }
    }

    // MARK: Sleep

    private var sleepCard: some View {
        let sessions = store.sleepSessions(in: range)
        let avg = sessions.isEmpty ? nil : sessions.reduce(0) { $0 + $1.hours } / Double(sessions.count)
        let avgQuality = sessions.isEmpty
            ? nil
            : SleepQuality(rawValue: Int((Double(sessions.reduce(0) { $0 + $1.quality.rawValue }) / Double(sessions.count)).rounded()))
        let onTarget = sessions.filter { $0.hours >= SleepGoal.targetHours - 0.25 }.count

        return ProgressCard(
            icon: "moon.zzz.fill",
            title: "Sleep",
            subtitle: "Hours per night\(range.bucket == .day ? "" : ", weekly average"). Dashed line is \(Int(SleepGoal.targetHours))h.",
            headline: avg.map { String(format: "%.1fh", $0) } ?? "—",
            headlineLabel: "AVERAGE"
        ) {
            let points = store.sleepSeries(range)
            if points.isEmpty {
                empty("No nights logged in the \(range.label). Log one from the Wake tab.")
            } else {
                lineChart(points, color: Theme.accent, target: SleepGoal.targetHours)
            }
            HStack(spacing: 0) {
                miniStat("\(sessions.count)", "Nights")
                miniStat("\(onTarget)", "On target")
                miniStat(avgQuality?.label ?? "—", "Quality")
            }
        }
    }

    // MARK: Run

    private var runCard: some View {
        let runs = store.runs(in: range)
        let total = runs.reduce(0) { $0 + $1.kilometers }
        let longest = runs.map(\.kilometers).max()
        let bestPace = runs.filter { $0.kilometers >= 1 }.compactMap(\.paceSecondsPerKm).min()

        return ProgressCard(
            icon: "figure.run",
            title: "Run",
            subtitle: "Kilometres per \(bucketWord).",
            headline: String(format: "%.1f", total),
            headlineLabel: "KM"
        ) {
            let points = store.runDistanceSeries(range)
            if points.isEmpty {
                empty("No runs in the \(range.label).")
            } else {
                barChart(points, color: Theme.accent)
            }
            HStack(spacing: 0) {
                miniStat("\(runs.count)", "Runs")
                miniStat(longest.map { String(format: "%.1f km", $0) } ?? "—", "Longest")
                miniStat(RunFormat.pace(bestPace), "Best pace")
            }
        }
    }

    // MARK: Gym

    private var gymCard: some View {
        let sessions = store.workouts(in: range)
        let volume = sessions.reduce(0) { $0 + $1.totalVolumeKg }
        let sets = sessions.reduce(0) { $0 + $1.totalSets }
        let records = Array(store.personalRecords.prefix(5))
        let rangeStart = store.rangeStart(range)

        return ProgressCard(
            icon: "dumbbell.fill",
            title: "Gym",
            subtitle: "Volume (kg × reps) per \(bucketWord).",
            headline: volume >= 10_000 ? String(format: "%.1ft", volume / 1000) : "\(Int(volume))",
            headlineLabel: volume >= 10_000 ? "LIFTED" : "KG LIFTED"
        ) {
            let points = store.volumeSeries(range)
            if points.isEmpty {
                empty("No sessions in the \(range.label).")
            } else {
                barChart(points, color: Theme.ink.opacity(0.8))
            }
            HStack(spacing: 0) {
                miniStat("\(sessions.count)", "Sessions")
                miniStat("\(sets)", "Sets")
                miniStat(sessions.isEmpty ? "—" : "\(Int(volume / Double(sessions.count)))", "KG / session")
            }

            if !records.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("PERSONAL RECORDS")
                        .font(.flexMono(10))
                        .tracking(1.5)
                        .foregroundStyle(Theme.inkSubtle)
                    ForEach(records) { record in
                        HStack {
                            Text(record.exercise)
                                .font(.flexBody())
                                .foregroundStyle(Theme.ink)
                                .lineLimit(1)
                            if record.date >= rangeStart {
                                Text("NEW")
                                    .font(.flexMono(8))
                                    .tracking(1)
                                    .foregroundStyle(Theme.accent)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Theme.accentSoft)
                                    .clipShape(Capsule())
                            }
                            Spacer()
                            Text("\(record.weightKg.formatted(.number.precision(.fractionLength(0...1)))) kg × \(record.reps)")
                                .font(.flexBodyBold())
                                .monospacedDigit()
                                .foregroundStyle(Theme.ink)
                        }
                    }
                }
            }
        }
    }

    // MARK: Diet

    private var dietCard: some View {
        let loggedDays = store.foodDays(range)
        let dailyTotals = loggedDays.map { store.calories(on: $0) }
        let average = dailyTotals.isEmpty ? nil : dailyTotals.reduce(0, +) / dailyTotals.count
        let within = dailyTotals.filter { $0 <= store.calorieBudget }.count
        let macros = store.averageMacros(range)
        let water = store.waterSeries(range)
        let avgWater = water.isEmpty ? nil : Int(water.reduce(0) { $0 + $1.value } / Double(water.count))

        return ProgressCard(
            icon: "fork.knife",
            title: "Diet",
            subtitle: "Average calories per logged day\(range.bucket == .day ? "" : ", by week"). Dashed line is your budget.",
            headline: average.map { "\($0)" } ?? "—",
            headlineLabel: "AVG KCAL"
        ) {
            let points = store.calorieSeries(range)
            if points.isEmpty {
                empty("Nothing logged in the \(range.label).")
            } else {
                barChart(points, color: Theme.amber, target: Double(store.calorieBudget))
            }
            HStack(spacing: 0) {
                miniStat("\(loggedDays.count)/\(range.days)", "Days logged")
                miniStat("\(within)", "In budget")
                miniStat(avgWater.map { String(format: "%.1fL", Double($0) / 1000) } ?? "—", "Avg water")
            }
            if let macros {
                VStack(spacing: 10) {
                    MacroBar(kind: .protein, value: macros.protein, goal: store.nutritionGoals.protein)
                    MacroBar(kind: .carbs, value: macros.carbs, goal: store.nutritionGoals.carbs)
                    MacroBar(kind: .fat, value: macros.fat, goal: store.nutritionGoals.fat)
                }
                Text("Daily averages on logged days, against your goals.")
                    .font(.flexCaption())
                    .foregroundStyle(Theme.inkSubtle)
            }
        }
    }

    // MARK: Body

    private var bodyCard: some View {
        let points = store.weightSeries(range)
        let entries = store.weightEntries
            .filter { $0.date >= store.rangeStart(range) }
            .sorted { $0.date < $1.date }
        let change: Double? = entries.count >= 2 ? entries.last!.kilograms - entries.first!.kilograms : nil
        let photos = store.progressPhotos.filter { $0.date >= store.rangeStart(range) && $0.pose != .proof }.count

        return ProgressCard(
            icon: "scalemass",
            title: "Body",
            subtitle: "Body weight\(range.bucket == .day ? "" : ", weekly average").",
            headline: store.latestWeight.map { String(format: "%.1f", $0.kilograms) } ?? "—",
            headlineLabel: "KG NOW"
        ) {
            if points.isEmpty {
                empty("No weigh-ins in the \(range.label). Log one from the Diet tab.")
            } else {
                lineChart(points, color: Theme.ink, includesZero: false)
            }
            HStack(spacing: 0) {
                miniStat(change.map { String(format: "%+.1f kg", $0) } ?? "—", "Change")
                miniStat("\(entries.count)", "Weigh-ins")
                miniStat("\(photos)", "Photos")
            }
        }
    }

    // MARK: Pieces

    private func miniStat(_ value: String, _ label: String) -> some View {
        VStack(spacing: 3) {
            Text(value)
                .font(.flexBodyBold())
                .monospacedDigit()
                .foregroundStyle(Theme.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(label.uppercased())
                .font(.flexMono(8))
                .tracking(1.2)
                .foregroundStyle(Theme.inkSubtle)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity)
    }
}

/// Shared shell for each pillar on the Progress page: icon, title, the one
/// number that matters, then whatever charts and stats the pillar needs.
private struct ProgressCard<Content: View>: View {
    let icon: String
    let title: String
    let subtitle: String
    let headline: String
    let headlineLabel: String
    @ViewBuilder var content: Content

    var body: some View {
        FlexCard(padding: 16) {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top, spacing: 12) {
                    IconBadge(systemName: icon, size: 38)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(title.uppercased())
                            .font(.flexMono(12))
                            .tracking(2)
                            .foregroundStyle(Theme.ink)
                        Text(subtitle)
                            .font(.flexCaption())
                            .foregroundStyle(Theme.inkSubtle)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer(minLength: 8)
                    VStack(alignment: .trailing, spacing: 0) {
                        Text(headline)
                            .font(.flexStat(24))
                            .foregroundStyle(Theme.ink)
                            .lineLimit(1)
                            .minimumScaleFactor(0.6)
                        Text(headlineLabel)
                            .font(.flexMono(8))
                            .tracking(1)
                            .foregroundStyle(Theme.inkSubtle)
                    }
                }
                content
            }
        }
    }
}
