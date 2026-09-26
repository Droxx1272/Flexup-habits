import SwiftUI
import UIKit
import Charts

/// Nutrition without the noise: step through any day, calories against a
/// budget, macros against goals, water, the week at a glance — and snap the
/// plate for an itemised estimate you can correct.
struct FuelSection: View {
    @Environment(AppStore.self) private var store
    @State private var day: Date = Calendar.current.startOfDay(for: .now)
    @State private var showAddFood = false
    @State private var addMeal: MealType = .breakfast
    @State private var showGoals = false
    @State private var showLogWeight = false
    @State private var selectedEntry: FoodEntry?

    private var calendar: Calendar { .current }
    private var isToday: Bool { calendar.isDateInToday(day) }
    private var goals: NutritionGoals { store.nutritionGoals }
    private var consumed: Int { store.calories(on: day) }
    private var remaining: Int { goals.calories - consumed }
    private var macros: Macros { store.macros(on: day) }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            daySwitcher
            budgetCard

            Button {
                addMeal = isToday ? suggestedMeal : .dinner
                showAddFood = true
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "fork.knife")
                    Text(isToday ? "Log food" : "Log food for this day")
                }
            }
            .buttonStyle(PrimaryButtonStyle())

            macrosCard

            ForEach(MealType.allCases) { meal in
                mealCard(meal)
            }

            waterCard
            weekCard
            weightCard
        }
        .sheet(isPresented: $showLogWeight) {
            LogWeightSheet()
        }
        .sheet(isPresented: $showAddFood) {
            AddFoodSheet(meal: addMeal, day: day)
        }
        .sheet(isPresented: $showGoals) {
            NutritionGoalsSheet()
        }
        .sheet(item: $selectedEntry) { entry in
            FoodEntryDetailSheet(entry: entry)
        }
    }

    // MARK: Day switcher

    /// Forgot yesterday's dinner? Step back and log it where it belongs.
    private var daySwitcher: some View {
        HStack {
            dayButton("chevron.left", enabled: true) { shiftDay(-1) }
            Spacer()
            VStack(spacing: 3) {
                Text(isToday ? "TODAY" : (calendar.isDateInYesterday(day) ? "YESTERDAY" : day.formatted(.dateTime.weekday(.wide)).uppercased()))
                    .font(.flexMono(12))
                    .tracking(2)
                    .foregroundStyle(Theme.ink)
                Text(day.formatted(.dateTime.day().month(.wide).year()).uppercased())
                    .font(.flexMono(9))
                    .tracking(1)
                    .foregroundStyle(Theme.inkSubtle)
            }
            .contentShape(Rectangle())
            .onTapGesture {
                withAnimation(.spring(duration: 0.25)) { day = calendar.startOfDay(for: .now) }
            }
            Spacer()
            dayButton("chevron.right", enabled: !isToday) { shiftDay(1) }
        }
        .padding(6)
        .background(Theme.card)
        .clipShape(Capsule())
    }

    private func dayButton(_ icon: String, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(Theme.ink)
                .frame(width: 38, height: 38)
                .background(Theme.background)
                .clipShape(Circle())
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .opacity(enabled ? 1 : 0.3)
    }

    private func shiftDay(_ offset: Int) {
        guard let next = calendar.date(byAdding: .day, value: offset, to: day),
              next <= calendar.startOfDay(for: .now) else { return }
        withAnimation(.spring(duration: 0.25)) { day = next }
    }

    // MARK: Budget

    private var budgetCard: some View {
        FlexCard {
            HStack(spacing: 18) {
                ZStack {
                    ProgressRing(progress: goals.calories > 0 ? min(1, Double(consumed) / Double(goals.calories)) : 0)
                        .frame(width: 84, height: 84)
                    VStack(spacing: 1) {
                        Text("\(abs(remaining))")
                            .font(.flexStat(22))
                            .foregroundStyle(remaining >= 0 ? Theme.ink : Theme.danger)
                            .minimumScaleFactor(0.6)
                            .lineLimit(1)
                        Text(remaining >= 0 ? "LEFT" : "OVER")
                            .font(.flexMono(8))
                            .tracking(1.5)
                            .foregroundStyle(Theme.inkSubtle)
                    }
                }
                VStack(alignment: .leading, spacing: 5) {
                    Text(isToday ? "TODAY'S FUEL" : "THIS DAY'S FUEL")
                        .font(.flexMono(10))
                        .tracking(2)
                        .foregroundStyle(Theme.inkSubtle)
                    Text("\(consumed) of \(goals.calories) kcal")
                        .font(.flexBodyBold())
                        .foregroundStyle(Theme.ink)
                    if store.foodLogStreak > 1 {
                        Text("\(store.foodLogStreak)-DAY LOGGING STREAK")
                            .font(.flexMono(9))
                            .tracking(1)
                            .foregroundStyle(Theme.accent)
                    }
                    Button {
                        showGoals = true
                    } label: {
                        Text("EDIT GOALS")
                            .font(.flexMono(9))
                            .tracking(1)
                            .foregroundStyle(Theme.accent)
                    }
                    .buttonStyle(.plain)
                }
                Spacer()
            }
        }
    }

    // MARK: Macros

    private var macrosCard: some View {
        let known = store.caloriesWithMacros(on: day)
        let split = macros.calorieSplit
        let splitTotal = split.protein + split.carbs + split.fat

        return FlexCard(padding: 16) {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .center) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("MACROS")
                            .font(.flexMono(11))
                            .tracking(1.5)
                            .foregroundStyle(Theme.ink)
                        if splitTotal > 0 {
                            Text("P \(percent(split.protein, of: splitTotal))% · C \(percent(split.carbs, of: splitTotal))% · F \(percent(split.fat, of: splitTotal))% OF ENERGY")
                                .font(.flexMono(9))
                                .tracking(1)
                                .foregroundStyle(Theme.inkSubtle)
                        } else {
                            Text("LOG FOOD TO SEE YOUR SPLIT")
                                .font(.flexMono(9))
                                .tracking(1)
                                .foregroundStyle(Theme.inkSubtle)
                        }
                    }
                    Spacer()
                    if splitTotal > 0 {
                        Chart {
                            SectorMark(angle: .value("Protein", split.protein), innerRadius: .ratio(0.62), angularInset: 1.5)
                                .foregroundStyle(MacroKind.protein.color)
                            SectorMark(angle: .value("Carbs", split.carbs), innerRadius: .ratio(0.62), angularInset: 1.5)
                                .foregroundStyle(MacroKind.carbs.color)
                            SectorMark(angle: .value("Fat", split.fat), innerRadius: .ratio(0.62), angularInset: 1.5)
                                .foregroundStyle(MacroKind.fat.color)
                        }
                        .frame(width: 52, height: 52)
                    }
                }

                MacroBar(kind: .protein, value: macros.protein, goal: goals.protein)
                MacroBar(kind: .carbs, value: macros.carbs, goal: goals.carbs)
                MacroBar(kind: .fat, value: macros.fat, goal: goals.fat)

                Rectangle()
                    .fill(Theme.inkSubtle.opacity(0.15))
                    .frame(height: 1)

                HStack(spacing: 0) {
                    microStat("FIBRE", "\(Int(macros.fiber.rounded()))/\(goals.fiber)g")
                    microStat("SUGAR", "\(Int(macros.sugar.rounded()))g")
                    microStat("SODIUM", "\(Int(macros.sodiumMg.rounded()))mg")
                }

                if consumed > 0 && known < consumed {
                    Text("Macros cover \(known) of \(consumed) kcal — entries logged with calories only aren't counted here.")
                        .font(.flexCaption())
                        .foregroundStyle(Theme.amber)
                }
            }
        }
    }

    private func percent(_ part: Double, of total: Double) -> Int {
        total > 0 ? Int((part / total * 100).rounded()) : 0
    }

    private func microStat(_ label: String, _ value: String) -> some View {
        VStack(spacing: 3) {
            Text(value)
                .font(.flexBodyBold())
                .monospacedDigit()
                .foregroundStyle(Theme.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(label)
                .font(.flexMono(8))
                .tracking(1.5)
                .foregroundStyle(Theme.inkSubtle)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: Meals

    private func mealCard(_ meal: MealType) -> some View {
        let entries = store.food(on: day, meal: meal)
        let total = entries.reduce(0) { $0 + $1.calories }

        return FlexCard(padding: 14) {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Image(systemName: meal.icon)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Theme.accent)
                    Text(meal.label.uppercased())
                        .font(.flexMono(11))
                        .tracking(1.5)
                        .foregroundStyle(Theme.ink)
                    Spacer()
                    if total > 0 {
                        Text("\(total) KCAL")
                            .font(.flexMono(10))
                            .tracking(1)
                            .foregroundStyle(Theme.inkSubtle)
                    }
                    Button {
                        addMeal = meal
                        showAddFood = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.title3)
                            .foregroundStyle(Theme.accent)
                    }
                    .buttonStyle(.plain)
                }

                if entries.isEmpty {
                    Text("Nothing logged.")
                        .font(.flexCaption())
                        .foregroundStyle(Theme.inkSubtle)
                } else {
                    ForEach(entries) { entry in
                        Button {
                            selectedEntry = entry
                        } label: {
                            FoodEntryRow(entry: entry)
                        }
                        .buttonStyle(.plain)
                        .contextMenu {
                            Button {
                                store.relogFood(entry, on: .now)
                            } label: {
                                Label("Log again today", systemImage: "arrow.clockwise")
                            }
                            Button(role: .destructive) {
                                store.deleteFood(entry)
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    }
                }
            }
        }
    }

    // MARK: Water

    private var waterCard: some View {
        let water = store.water(on: day)
        let glassCount = min(12, max(4, goals.waterMl / 250))
        let filled = min(glassCount, water / 250)

        return FlexCard(padding: 14) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: "drop.fill")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Theme.accent)
                    Text("WATER")
                        .font(.flexMono(11))
                        .tracking(1.5)
                        .foregroundStyle(Theme.ink)
                    Spacer()
                    Text("\(water) / \(goals.waterMl) ML")
                        .font(.flexMono(10))
                        .tracking(1)
                        .foregroundStyle(water >= goals.waterMl ? Theme.accent : Theme.inkSubtle)
                }

                HStack(spacing: 6) {
                    ForEach(0..<glassCount, id: \.self) { index in
                        Image(systemName: index < filled ? "drop.fill" : "drop")
                            .font(.system(size: 17))
                            .foregroundStyle(index < filled ? Theme.accent : Theme.inkSubtle.opacity(0.35))
                            .frame(maxWidth: .infinity)
                    }
                }
                .animation(.spring(duration: 0.3), value: filled)

                HStack(spacing: 8) {
                    waterButton("+250 ML") { store.addWater(250, on: day) }
                    waterButton("+500 ML") { store.addWater(500, on: day) }
                    Spacer()
                    Button {
                        store.addWater(-250, on: day)
                    } label: {
                        Image(systemName: "minus")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(Theme.inkSubtle)
                            .frame(width: 34, height: 34)
                            .background(Theme.background)
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                    .disabled(water == 0)
                    .opacity(water == 0 ? 0.4 : 1)
                }
            }
        }
    }

    private func waterButton(_ label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.flexMono(10))
                .tracking(1)
                .foregroundStyle(Theme.accent)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(Theme.accentSoft)
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    // MARK: Week

    private var weekDays: [DailyPoint] {
        let today = calendar.startOfDay(for: .now)
        return (0..<7).reversed().compactMap { offset in
            guard let date = calendar.date(byAdding: .day, value: -offset, to: today) else { return nil }
            return DailyPoint(date: date, value: Double(store.calories(on: date)))
        }
    }

    private var weekCard: some View {
        let days = weekDays
        let logged = days.filter { $0.value > 0 }
        let average = logged.isEmpty ? 0 : Int(logged.reduce(0) { $0 + $1.value } / Double(logged.count))
        let within = logged.filter { $0.value <= Double(goals.calories) }.count

        return FlexCard(padding: 16) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("LAST 7 DAYS")
                            .font(.flexMono(11))
                            .tracking(1.5)
                            .foregroundStyle(Theme.ink)
                        Text(logged.isEmpty
                             ? "NOTHING LOGGED THIS WEEK"
                             : "\(within) OF \(logged.count) LOGGED DAYS WITHIN BUDGET")
                            .font(.flexMono(9))
                            .tracking(1)
                            .foregroundStyle(Theme.inkSubtle)
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 0) {
                        Text("\(average)")
                            .font(.flexStat(22))
                            .foregroundStyle(Theme.ink)
                        Text("AVG KCAL")
                            .font(.flexMono(8))
                            .tracking(1)
                            .foregroundStyle(Theme.inkSubtle)
                    }
                }

                Chart {
                    ForEach(days) { point in
                        BarMark(
                            x: .value("Day", point.date, unit: .day),
                            y: .value("kcal", point.value)
                        )
                        .foregroundStyle(point.value > Double(goals.calories) ? Theme.amber : Theme.accent)
                        .opacity(calendar.isDate(point.date, inSameDayAs: day) ? 1 : 0.55)
                        .cornerRadius(5)
                    }
                    RuleMark(y: .value("Budget", goals.calories))
                        .foregroundStyle(Theme.inkSubtle)
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
                }
                .chartXAxis {
                    AxisMarks(values: .stride(by: .day)) { _ in
                        AxisValueLabel(format: .dateTime.weekday(.narrow), centered: true)
                    }
                }
                .chartYAxis(.hidden)
                .frame(height: 120)
            }
        }
    }

    // MARK: Body weight

    private var weightCard: some View {
        FlexCard(padding: 14) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: "scalemass")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Theme.accent)
                    Text("BODY WEIGHT")
                        .font(.flexMono(11))
                        .tracking(1.5)
                        .foregroundStyle(Theme.ink)
                    Spacer()
                    Button {
                        showLogWeight = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.title3)
                            .foregroundStyle(Theme.accent)
                    }
                    .buttonStyle(.plain)
                }

                if let latest = store.latestWeight {
                    HStack(alignment: .firstTextBaseline, spacing: 10) {
                        Text(String(format: "%.1f", latest.kilograms))
                            .font(.flexStat(30))
                            .foregroundStyle(Theme.ink)
                        Text("KG")
                            .font(.flexMono(10))
                            .tracking(1.5)
                            .foregroundStyle(Theme.inkSubtle)
                        Spacer()
                        if let change = store.weightChange30Days {
                            HStack(spacing: 4) {
                                Image(systemName: change >= 0 ? "arrow.up.right" : "arrow.down.right")
                                Text(String(format: "%.1f kg / 30d", abs(change)))
                            }
                            .font(.flexCaption())
                            .foregroundStyle(Theme.inkSubtle)
                        }
                    }
                    Text("LOGGED \(latest.date.formatted(.dateTime.weekday(.abbreviated).day().month()).uppercased())")
                        .font(.flexMono(9))
                        .tracking(1)
                        .foregroundStyle(Theme.inkSubtle)
                } else {
                    Text("Weigh in weekly, same time of day. The trend matters, not any single number.")
                        .font(.flexCaption())
                        .foregroundStyle(Theme.inkSubtle)
                }
            }
        }
    }

    private var suggestedMeal: MealType {
        switch Calendar.current.component(.hour, from: .now) {
        case ..<11: .breakfast
        case ..<16: .lunch
        case ..<21: .dinner
        default: .snack
        }
    }
}

// MARK: - Macro pieces

enum MacroKind {
    case protein, carbs, fat

    var label: String {
        switch self {
        case .protein: "Protein"
        case .carbs: "Carbs"
        case .fat: "Fat"
        }
    }

    var color: Color {
        switch self {
        case .protein: Theme.accent
        case .carbs: Theme.amber
        case .fat: Theme.ink.opacity(0.75)
        }
    }
}

/// One macro against its goal: label, grams, and a capsule that fills.
struct MacroBar: View {
    let kind: MacroKind
    let value: Double
    let goal: Int

    private var progress: Double {
        goal > 0 ? min(1, value / Double(goal)) : 0
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(kind.label.uppercased())
                    .font(.flexMono(10))
                    .tracking(1.5)
                    .foregroundStyle(Theme.ink)
                Spacer()
                Text("\(Int(value.rounded())) / \(goal) G")
                    .font(.flexMono(10))
                    .tracking(1)
                    .monospacedDigit()
                    .foregroundStyle(Theme.inkSubtle)
            }
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Theme.background)
                    Capsule()
                        .fill(kind.color)
                        .frame(width: max(progress > 0 ? 8 : 0, proxy.size.width * progress))
                }
            }
            .frame(height: 8)
            .animation(.spring(duration: 0.5), value: progress)
        }
    }
}

/// A logged food in a meal card.
struct FoodEntryRow: View {
    @Environment(AppStore.self) private var store
    let entry: FoodEntry

    var body: some View {
        HStack(spacing: 10) {
            if let fileName = entry.photoFileName {
                AsyncPhotoView(url: store.imageURL(fileName: fileName), maxPixel: 100)
                    .frame(width: 38, height: 38)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(entry.name)
                    .font(.flexBody())
                    .foregroundStyle(Theme.ink)
                    .lineLimit(1)
                if let macros = entry.macros {
                    Text(macros.shortLabel)
                        .font(.flexMono(9))
                        .tracking(0.5)
                        .foregroundStyle(Theme.inkSubtle)
                } else if let items = entry.items {
                    Text("\(items.count) ITEMS")
                        .font(.flexMono(9))
                        .tracking(0.5)
                        .foregroundStyle(Theme.inkSubtle)
                }
            }
            Spacer()
            Text("\(entry.calories)")
                .font(.flexBodyBold())
                .monospacedDigit()
                .foregroundStyle(Theme.ink)
            Image(systemName: "chevron.right")
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(Theme.inkSubtle.opacity(0.6))
        }
        .contentShape(Rectangle())
    }
}

// MARK: - Add food sheet

struct AddFoodSheet: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    @State private var meal: MealType
    @State private var name = ""
    @State private var calories: Int?
    @State private var photoData: Data?
    @State private var showCamera = false
    @State private var showLibrary = false
    @State private var estimating = false
    @State private var estimateNote: String?
    @State private var estimateError: String?

    /// Non-empty once a photo has been estimated — switches the sheet from
    /// manual entry into the itemised review where portions get corrected.
    @State private var items: [FoodItem] = []
    @State private var correction = ""
    @State private var showContextEditor = false
    @State private var dictation = VoiceDictation()

    /// Hand-entered macros. Optional — calories alone are still a valid log.
    @State private var protein: Double?
    @State private var carbs: Double?
    @State private var fat: Double?
    @State private var fiber: Double?
    @State private var showMacroFields = false
    /// Full macros (incl. sugar/sodium) from a quick-add or recent pick, so
    /// the fields the form doesn't show still get saved.
    @State private var presetMacros: Macros?
    @State private var presetName: String?

    /// The day being logged — today, or a past day chosen in the Diet tab.
    private let day: Date

    init(meal: MealType, day: Date = .now) {
        _meal = State(initialValue: meal)
        self.day = day
    }

    private var manualMacros: Macros? {
        guard protein != nil || carbs != nil || fat != nil || fiber != nil else { return nil }
        var macros = presetMacros ?? Macros()
        macros.protein = protein ?? 0
        macros.carbs = carbs ?? 0
        macros.fat = fat ?? 0
        macros.fiber = fiber ?? 0
        return macros
    }

    private var plateMacros: Macros? {
        let known = items.compactMap(\.macros)
        return known.isEmpty ? nil : known.reduce(Macros.zero, +)
    }

    private var dayLabel: String? {
        let calendar = Calendar.current
        if calendar.isDateInToday(day) { return nil }
        if calendar.isDateInYesterday(day) { return "YESTERDAY" }
        return day.formatted(.dateTime.weekday(.abbreviated).day().month()).uppercased()
    }

    private var cameraAvailable: Bool {
        UIImagePickerController.isSourceTypeAvailable(.camera)
    }

    private var isReviewing: Bool { !items.isEmpty }

    private var totalCalories: Int {
        items.reduce(0) { $0 + $1.calories }
    }

    private var canSave: Bool {
        if isReviewing {
            return !name.trimmingCharacters(in: .whitespaces).isEmpty && totalCalories > 0
        }
        return !name.trimmingCharacters(in: .whitespaces).isEmpty && (calories ?? 0) > 0
    }

    private let quickFoodColumns = [GridItem(.flexible()), GridItem(.flexible())]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Capsule()
                .fill(Theme.inkSubtle.opacity(0.3))
                .frame(width: 36, height: 5)
                .frame(maxWidth: .infinity)
                .padding(.top, 10)
                .padding(.bottom, 14)

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        Text(isReviewing ? "CHECK THE ESTIMATE" : "LOG FOOD")
                            .font(.flexMono(12))
                            .tracking(2)
                            .foregroundStyle(Theme.ink)
                        Spacer()
                        if let dayLabel {
                            Text("FOR \(dayLabel)")
                                .font(.flexMono(10))
                                .tracking(1.5)
                                .foregroundStyle(Theme.amber)
                        }
                    }

                    mealPicker
                    photoBlock

                    if isReviewing {
                        itemsEditor
                        addOnsRow
                        correctionRow
                    } else {
                        manualEntry
                        macroFields
                        recentRow
                        quickAddGrid
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
            }
            .scrollIndicators(.hidden)
            .scrollDismissesKeyboard(.interactively)

            saveBar
        }
        .background(Theme.background)
        .presentationDetents([.large])
        .fullScreenCover(isPresented: $showCamera) {
            CameraPicker { image in
                photoData = image.flexJPEGData()
            }
            .ignoresSafeArea()
        }
        .sheet(isPresented: $showLibrary) {
            LibraryPicker { image in
                photoData = image.flexJPEGData()
            }
        }
        .sheet(isPresented: $showContextEditor) {
            CuisineContextSheet()
        }
        .onChange(of: name) { _, newValue in
            // Typed something else after a preset: its hidden sugar/sodium
            // no longer describe this food.
            if let presetName, newValue != presetName {
                presetMacros = nil
                self.presetName = nil
            }
        }
    }

    // MARK: Meal picker

    private var mealPicker: some View {
        HStack(spacing: 8) {
            ForEach(MealType.allCases) { item in
                SelectableChip(label: item.label, isSelected: meal == item) {
                    meal = item
                }
            }
        }
    }

    // MARK: Photo

    private var photoBlock: some View {
        Group {
            if let photoData, let image = UIImage(data: photoData) {
                VStack(spacing: 10) {
                    ZStack(alignment: .topTrailing) {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFill()
                            .frame(maxWidth: .infinity)
                            .frame(height: 170)
                            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                        Button {
                            self.photoData = nil
                            items = []
                            estimateNote = nil
                            estimateError = nil
                        } label: {
                            Image(systemName: "xmark")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundStyle(Theme.ink)
                                .padding(9)
                                .background(.thinMaterial)
                                .clipShape(Circle())
                        }
                        .padding(10)
                    }

                    if BackendConfig.isConfigured {
                        Button {
                            runEstimate()
                        } label: {
                            HStack(spacing: 8) {
                                if estimating {
                                    ProgressView().controlSize(.small)
                                } else {
                                    Image(systemName: "sparkles")
                                }
                                Text(estimating
                                     ? "Estimating…"
                                     : (isReviewing ? "Re-estimate with corrections" : "Estimate calories with AI"))
                            }
                        }
                        .buttonStyle(SecondaryButtonStyle(tint: Theme.accent, background: Theme.accentSoft))
                        .disabled(estimating)

                        cuisineRow

                        if !isReviewing, let estimateError {
                            Text(estimateError)
                                .font(.flexCaption())
                                .foregroundStyle(Theme.danger)
                        }
                    } else {
                        // Honest label: the photo still saves with the entry,
                        // but no AI runs until the server is connected.
                        Text("AI estimates aren't switched on in this build yet — the photo is saved with your entry. Add the calories below.")
                            .font(.flexCaption())
                            .foregroundStyle(Theme.inkSubtle)
                    }
                }
            } else {
                Button {
                    if cameraAvailable { showCamera = true } else { showLibrary = true }
                } label: {
                    VStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(Theme.ink)
                                .frame(width: 62, height: 62)
                            Image(systemName: "camera.fill")
                                .font(.system(size: 24, weight: .semibold))
                                .foregroundStyle(Theme.background)
                        }
                        Text("SNAP YOUR MEAL")
                            .font(.flexMono(13))
                            .tracking(2)
                            .foregroundStyle(Theme.ink)
                        Text("AI breaks it into items you can adjust")
                            .font(.flexCaption())
                            .foregroundStyle(Theme.inkSubtle)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 168)
                    .background(Theme.card)
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .stroke(Theme.accent.opacity(0.5), style: StrokeStyle(lineWidth: 1.5, dash: [6, 5]))
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }

    /// Tells the model how you actually cook. The single biggest accuracy
    /// lever for regional and mixed dishes.
    private var cuisineRow: some View {
        Button {
            showContextEditor = true
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "globe.asia.australia")
                    .font(.system(size: 11, weight: .semibold))
                Text(store.cuisineContext.isEmpty
                     ? "SET YOUR CUISINE FOR BETTER ACCURACY"
                     : store.cuisineContext.uppercased())
                    .font(.flexMono(9))
                    .tracking(1)
                    .lineLimit(1)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 9, weight: .bold))
            }
            .foregroundStyle(store.cuisineContext.isEmpty ? Theme.amber : Theme.accent)
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
            .background((store.cuisineContext.isEmpty ? Theme.amber : Theme.accent).opacity(0.1))
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    // MARK: Itemised review

    private var itemsEditor: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                SectionHeader(title: "On your plate", subtitle: "Tap − or + to fix any portion.")
                Spacer()
                VStack(alignment: .trailing, spacing: 0) {
                    Text("\(totalCalories)")
                        .font(.flexStat(26))
                        .foregroundStyle(Theme.accent)
                    Text("KCAL")
                        .font(.flexMono(9))
                        .tracking(1)
                        .foregroundStyle(Theme.inkSubtle)
                }
            }

            ForEach($items) { $item in
                itemRow($item)
            }

            if let plateMacros {
                HStack(spacing: 0) {
                    plateStat("PROTEIN", "\(Int(plateMacros.protein.rounded()))g")
                    plateStat("CARBS", "\(Int(plateMacros.carbs.rounded()))g")
                    plateStat("FAT", "\(Int(plateMacros.fat.rounded()))g")
                    plateStat("FIBRE", "\(Int(plateMacros.fiber.rounded()))g")
                }
                .padding(.vertical, 12)
                .background(Theme.accentSoft)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }

            if let estimateNote {
                Text(estimateNote)
                    .font(.flexCaption())
                    .foregroundStyle(Theme.inkSubtle)
            }
            if let estimateError {
                Text(estimateError)
                    .font(.flexCaption())
                    .foregroundStyle(Theme.danger)
            }
        }
    }

    private func itemRow(_ item: Binding<FoodItem>) -> some View {
        let value = item.wrappedValue
        return VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(value.name)
                        .font(.flexBodyBold())
                        .foregroundStyle(Theme.ink)
                    Text(value.isAddOn ? "ADDED · \(value.portion.uppercased())" : value.portion.uppercased())
                        .font(.flexMono(9))
                        .tracking(1)
                        .foregroundStyle(value.isAddOn ? Theme.amber : Theme.inkSubtle)
                    if let macros = value.macros {
                        Text(macros.shortLabel)
                            .font(.flexMono(9))
                            .tracking(0.5)
                            .foregroundStyle(Theme.inkSubtle)
                    }
                }
                Spacer()
                Text("\(value.calories)")
                    .font(.flexStat(20))
                    .monospacedDigit()
                    .foregroundStyle(Theme.ink)
            }

            HStack(spacing: 10) {
                stepButton("minus") {
                    item.multiplier.wrappedValue = max(0.25, value.multiplier - 0.25)
                }
                Text(value.multiplierLabel)
                    .font(.flexMono(12))
                    .foregroundStyle(Theme.ink)
                    .frame(minWidth: 44)
                stepButton("plus") {
                    item.multiplier.wrappedValue = min(6, value.multiplier + 0.25)
                }
                Spacer()
                Button {
                    items.removeAll { $0.id == value.id }
                } label: {
                    Image(systemName: "trash")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Theme.inkSubtle)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(14)
        .background(Theme.card)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func plateStat(_ label: String, _ value: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.flexBodyBold())
                .monospacedDigit()
                .foregroundStyle(Theme.ink)
            Text(label)
                .font(.flexMono(8))
                .tracking(1)
                .foregroundStyle(Theme.accent)
        }
        .frame(maxWidth: .infinity)
    }

    private func stepButton(_ icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(Theme.ink)
                .frame(width: 32, height: 32)
                .background(Theme.background)
                .clipShape(Circle())
        }
        .buttonStyle(.plain)
    }

    // MARK: Hidden ingredients

    private var addOnsRow: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionHeader(title: "What the photo missed", subtitle: "Cooking fat is invisible and it counts.")
            ScrollView(.horizontal) {
                HStack(spacing: 8) {
                    ForEach(SampleData.hiddenIngredients) { ingredient in
                        Button {
                            items.append(FoodItem(
                                name: ingredient.name,
                                baseCalories: ingredient.calories,
                                portion: ingredient.portion,
                                isAddOn: true,
                                baseMacros: ingredient.macros
                            ))
                        } label: {
                            HStack(spacing: 5) {
                                Image(systemName: "plus")
                                    .font(.system(size: 9, weight: .bold))
                                Text(ingredient.name)
                                    .font(.flexCaption())
                            }
                            .foregroundStyle(Theme.ink)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 9)
                            .background(Theme.card)
                            .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .scrollIndicators(.hidden)
        }
    }

    // MARK: Spoken / typed correction

    private var correctionRow: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionHeader(title: "Tell it what it got wrong", subtitle: "Then re-estimate with your correction.")
            HStack(spacing: 8) {
                TextField("e.g. cooked in ghee, only two rotis", text: $correction, axis: .vertical)
                    .font(.flexBody())
                    .lineLimit(1...3)
                    .padding(12)
                    .background(Theme.card)
                    .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))

                Button {
                    if dictation.isRecording {
                        dictation.stop()
                    } else {
                        dictation.transcript = correction
                        dictation.start()
                    }
                } label: {
                    Image(systemName: dictation.isRecording ? "stop.fill" : "mic.fill")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(dictation.isRecording ? Theme.background : Theme.ink)
                        .frame(width: 46, height: 46)
                        .background(dictation.isRecording ? Theme.danger : Theme.card)
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
            }
            .onChange(of: dictation.transcript) { _, newValue in
                if dictation.isRecording { correction = newValue }
            }

            if dictation.isRecording {
                Text("LISTENING — TAP STOP WHEN DONE")
                    .font(.flexMono(9))
                    .tracking(1)
                    .foregroundStyle(Theme.danger)
            }
            if let voiceError = dictation.errorMessage {
                Text(voiceError)
                    .font(.flexCaption())
                    .foregroundStyle(Theme.inkSubtle)
            }
        }
    }

    // MARK: Manual entry (no photo)

    private var manualEntry: some View {
        HStack(spacing: 10) {
            TextField("What did you eat?", text: $name)
                .font(.flexBodyBold())
                .padding(13)
                .background(Theme.card)
                .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
            TextField("kcal", value: $calories, format: .number)
                .keyboardType(.numberPad)
                .font(.flexBodyBold())
                .multilineTextAlignment(.center)
                .padding(13)
                .frame(width: 90)
                .background(Theme.card)
                .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
        }
    }

    private var quickAddGrid: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionHeader(title: "Quick add")
            LazyVGrid(columns: quickFoodColumns, spacing: 8) {
                ForEach(SampleData.quickFoods) { food in
                    Button {
                        applyPreset(name: food.name, calories: food.calories, macros: food.macros)
                    } label: {
                        HStack {
                            Text(food.name)
                                .font(.flexCaption())
                                .foregroundStyle(Theme.ink)
                                .lineLimit(1)
                            Spacer()
                            Text("\(food.calories) · P\(Int(food.macros.protein.rounded()))")
                                .font(.flexMono(10))
                                .foregroundStyle(Theme.inkSubtle)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 11)
                        .background(name == food.name ? Theme.accentSoft : Theme.card)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: Macros (manual)

    private var macroFields: some View {
        VStack(alignment: .leading, spacing: 10) {
            Button {
                withAnimation(.spring(duration: 0.25)) { showMacroFields.toggle() }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: showMacroFields ? "chevron.down" : "chevron.right")
                        .font(.system(size: 9, weight: .bold))
                    Text(manualMacros == nil ? "ADD MACROS (OPTIONAL)" : "MACROS · \(manualMacros!.shortLabel)")
                        .font(.flexMono(10))
                        .tracking(1)
                }
                .foregroundStyle(Theme.accent)
            }
            .buttonStyle(.plain)

            if showMacroFields {
                HStack(spacing: 8) {
                    gramField("Protein", value: $protein)
                    gramField("Carbs", value: $carbs)
                    gramField("Fat", value: $fat)
                    gramField("Fibre", value: $fiber)
                }
            }
        }
    }

    private func gramField(_ label: String, value: Binding<Double?>) -> some View {
        VStack(spacing: 4) {
            TextField("0", value: value, format: .number)
                .keyboardType(.decimalPad)
                .font(.flexBodyBold())
                .multilineTextAlignment(.center)
                .padding(.vertical, 11)
                .background(Theme.card)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            Text("\(label.uppercased()) G")
                .font(.flexMono(8))
                .tracking(1)
                .foregroundStyle(Theme.inkSubtle)
        }
    }

    // MARK: Recent foods

    /// What you actually eat, one tap away. Beats any generic list.
    @ViewBuilder
    private var recentRow: some View {
        let recent = store.recentFoods
        if !recent.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                SectionHeader(title: "Recent", subtitle: "Tap to fill, then add.")
                ScrollView(.horizontal) {
                    HStack(spacing: 8) {
                        ForEach(recent) { entry in
                            Button {
                                applyPreset(name: entry.name, calories: entry.calories, macros: entry.macros)
                            } label: {
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(entry.name)
                                        .font(.flexCaption())
                                        .foregroundStyle(Theme.ink)
                                        .lineLimit(1)
                                    Text("\(entry.calories) KCAL")
                                        .font(.flexMono(9))
                                        .foregroundStyle(Theme.inkSubtle)
                                }
                                .frame(maxWidth: 150, alignment: .leading)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 9)
                                .background(name == entry.name ? Theme.accentSoft : Theme.card)
                                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .scrollIndicators(.hidden)
            }
        }
    }

    private func applyPreset(name: String, calories: Int, macros: Macros?) {
        self.name = name
        self.calories = calories
        presetName = name
        presetMacros = macros
        protein = macros.map { ($0.protein * 10).rounded() / 10 }
        carbs = macros.map { ($0.carbs * 10).rounded() / 10 }
        fat = macros.map { ($0.fat * 10).rounded() / 10 }
        fiber = macros.map { ($0.fiber * 10).rounded() / 10 }
        if macros != nil { showMacroFields = true }
    }

    // MARK: Save

    private var saveBar: some View {
        VStack(spacing: 6) {
            if isReviewing {
                TextField("Meal name", text: $name)
                    .font(.flexBodyBold())
                    .multilineTextAlignment(.center)
                    .padding(11)
                    .background(Theme.card)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
            Button(isReviewing
                   ? "Log \(totalCalories) kcal to \(meal.label.lowercased())"
                   : "Add to \(meal.label.lowercased())") {
                store.addFood(
                    name: name,
                    calories: isReviewing ? totalCalories : (calories ?? 0),
                    meal: meal,
                    date: store.logDate(for: day, meal: meal),
                    photoData: photoData,
                    items: isReviewing ? items : nil,
                    macros: isReviewing ? nil : manualMacros
                )
                dismiss()
            }
            .buttonStyle(PrimaryButtonStyle())
            .disabled(!canSave)
            .opacity(canSave ? 1 : 0.4)
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 12)
        .background(Theme.background)
    }

    // MARK: Estimation

    private func runEstimate() {
        guard let photoData, let image = UIImage(data: photoData) else { return }

        dictation.stop()
        estimating = true
        estimateError = nil
        estimateNote = nil

        let context = store.cuisineContext
        let note = correction
        // Anything the user added by hand survives a re-estimate — they
        // know about the ghee, the model doesn't.
        let manualAddOns = items.filter(\.isAddOn)

        Task {
            do {
                let estimate = try await CalorieEstimator.estimate(
                    image: image,
                    cuisineContext: context,
                    correction: note
                )
                await MainActor.run {
                    name = estimate.mealName
                    items = estimate.foodItems + manualAddOns
                    estimateNote = "\(estimate.confidence.capitalized) confidence · \(estimate.notes)"
                    estimating = false
                }
            } catch {
                await MainActor.run {
                    estimateError = error.localizedDescription
                    estimating = false
                }
            }
        }
    }
}

// MARK: - Cuisine context

/// Teaches the estimator how this person cooks. Persisted, so it applies to
/// every future photo without being retyped.
struct CuisineContextSheet: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var text = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Capsule()
                .fill(Theme.inkSubtle.opacity(0.3))
                .frame(width: 36, height: 5)
                .frame(maxWidth: .infinity)
                .padding(.top, 10)

            Text("HOW YOU COOK")
                .font(.flexMono(12))
                .tracking(2)
                .foregroundStyle(Theme.ink)

            Text("Western food databases misjudge regional and mixed dishes badly. Describing your kitchen once makes every future estimate better — the more specific, the better.")
                .font(.flexCaption())
                .foregroundStyle(Theme.inkSubtle)

            TextField("e.g. North Indian home cooking, mustard oil, moderate ghee, rice with most meals", text: $text, axis: .vertical)
                .font(.flexBody())
                .lineLimit(3...6)
                .padding(14)
                .background(Theme.card)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

            Text("START FROM A PRESET")
                .font(.flexMono(10))
                .tracking(2)
                .foregroundStyle(Theme.inkSubtle)

            ScrollView {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                    ForEach(SampleData.cuisinePresets, id: \.self) { preset in
                        Button {
                            text = preset
                        } label: {
                            Text(preset)
                                .font(.flexCaption())
                                .foregroundStyle(text == preset ? Theme.background : Theme.ink)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 11)
                                .background(text == preset ? Theme.ink : Theme.card)
                                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .scrollIndicators(.hidden)

            Button("Save context") {
                store.cuisineContext = text.trimmingCharacters(in: .whitespacesAndNewlines)
                store.save()
                dismiss()
            }
            .buttonStyle(PrimaryButtonStyle())
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 12)
        .background(Theme.background)
        .presentationDetents([.large])
        .onAppear { text = store.cuisineContext }
    }
}

// MARK: - Log weight sheet

struct LogWeightSheet: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var kilograms: Double?

    private var canSave: Bool { (kilograms ?? 0) > 0 }

    var body: some View {
        VStack(spacing: 18) {
            Capsule()
                .fill(Theme.inkSubtle.opacity(0.3))
                .frame(width: 36, height: 5)
                .padding(.top, 10)

            Text("LOG YOUR WEIGHT")
                .font(.flexMono(12))
                .tracking(2)
                .foregroundStyle(Theme.ink)

            HStack(alignment: .firstTextBaseline, spacing: 8) {
                TextField("0.0", value: $kilograms, format: .number)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
                    .font(.flexDisplay(46))
                    .foregroundStyle(Theme.ink)
                    .frame(maxWidth: 180)
                Text("KG")
                    .font(.flexMono(13))
                    .tracking(2)
                    .foregroundStyle(Theme.inkSubtle)
            }
            .padding(.vertical, 10)

            Text("Same time of day gives the truest trend — most people weigh in first thing in the morning.")
                .font(.flexCaption())
                .foregroundStyle(Theme.inkSubtle)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)

            if !store.weightEntries.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    SectionHeader(title: "Recent", subtitle: "Long-press to delete.")
                    ForEach(store.weightEntries.sorted { $0.date > $1.date }.prefix(5)) { entry in
                        HStack {
                            Text(String(format: "%.1f kg", entry.kilograms))
                                .font(.flexBodyBold())
                                .foregroundStyle(Theme.ink)
                            Spacer()
                            Text(entry.date.formatted(.dateTime.weekday(.abbreviated).day().month()).uppercased())
                                .font(.flexMono(9))
                                .tracking(1)
                                .foregroundStyle(Theme.inkSubtle)
                        }
                        .padding(12)
                        .background(Theme.card)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .contextMenu {
                            Button(role: .destructive) {
                                store.deleteWeight(entry)
                            } label: {
                                Label("Delete entry", systemImage: "trash")
                            }
                        }
                    }
                }
                .padding(.horizontal, 20)
            }

            Spacer()

            Button("Save weight") {
                store.logWeight(kilograms ?? 0)
                dismiss()
            }
            .buttonStyle(PrimaryButtonStyle())
            .disabled(!canSave)
            .opacity(canSave ? 1 : 0.4)
            .padding(.horizontal, 20)
        }
        .padding(.bottom, 12)
        .background(Theme.background)
        .presentationDetents([.large])
        .onAppear {
            // Pre-fill with the last weight — most weigh-ins move a little.
            if kilograms == nil { kilograms = store.latestWeight?.kilograms }
        }
    }
}

// MARK: - Nutrition goals

/// Calories plus the targets that make them mean something. Picking a
/// direction sets a sensible macro split; every number stays adjustable.
struct NutritionGoalsSheet: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var goals = NutritionGoals()
    @State private var direction: DietDirection?

    private var macroCalories: Int {
        goals.protein * 4 + goals.carbs * 4 + goals.fat * 9
    }

    private var macrosMatchCalories: Bool {
        guard goals.calories > 0 else { return true }
        return abs(Double(macroCalories - goals.calories)) / Double(goals.calories) <= 0.1
    }

    var body: some View {
        VStack(spacing: 0) {
            Capsule()
                .fill(Theme.inkSubtle.opacity(0.3))
                .frame(width: 36, height: 5)
                .padding(.top, 10)
                .padding(.bottom, 14)

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("DAILY GOALS")
                        .font(.flexMono(12))
                        .tracking(2)
                        .foregroundStyle(Theme.ink)
                    Text("A budget is a direction, not a verdict. Pick numbers you can keep on a normal day.")
                        .font(.flexCaption())
                        .foregroundStyle(Theme.inkSubtle)

                    VStack(alignment: .leading, spacing: 8) {
                        SectionHeader(title: "Direction", subtitle: "Sets a macro split from your calories.")
                        HStack(spacing: 8) {
                            ForEach(DietDirection.allCases) { item in
                                SelectableChip(label: item.rawValue, isSelected: direction == item) {
                                    direction = item
                                    goals = item.goals(calories: goals.calories, keeping: goals)
                                }
                            }
                        }
                    }

                    goalRow("Calories", unit: "kcal", value: $goals.calories, range: 1200...4500, step: 50) {
                        if let direction {
                            goals = direction.goals(calories: goals.calories, keeping: goals)
                        }
                    }
                    goalRow("Protein", unit: "g", value: $goals.protein, range: 30...300, step: 5) { direction = nil }

                    if let weight = store.latestWeight?.kilograms {
                        let target = Int((weight * 1.6).rounded())
                        Button {
                            goals.protein = target
                            direction = nil
                        } label: {
                            Text("MATCH 1.6 G PER KG BODY WEIGHT → \(target) G")
                                .font(.flexMono(9))
                                .tracking(1)
                                .foregroundStyle(Theme.accent)
                        }
                        .buttonStyle(.plain)
                    }

                    goalRow("Carbs", unit: "g", value: $goals.carbs, range: 30...600, step: 5) { direction = nil }
                    goalRow("Fat", unit: "g", value: $goals.fat, range: 20...250, step: 5) { direction = nil }

                    Text("Macros add up to \(macroCalories) kcal\(macrosMatchCalories ? " — in line with your calorie goal." : ", which is off from your \(goals.calories) kcal goal. Adjust one or the other.")")
                        .font(.flexCaption())
                        .foregroundStyle(macrosMatchCalories ? Theme.inkSubtle : Theme.amber)

                    goalRow("Fibre", unit: "g", value: $goals.fiber, range: 10...70, step: 1)
                    goalRow("Water", unit: "ml", value: $goals.waterMl, range: 1000...5000, step: 250)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
            }
            .scrollIndicators(.hidden)

            Button("Save goals") {
                store.updateNutritionGoals(goals)
                dismiss()
            }
            .buttonStyle(PrimaryButtonStyle())
            .padding(.horizontal, 20)
            .padding(.bottom, 12)
        }
        .background(Theme.background)
        .presentationDetents([.large])
        .onAppear { goals = store.nutritionGoals }
    }

    private func goalRow(
        _ title: String,
        unit: String,
        value: Binding<Int>,
        range: ClosedRange<Int>,
        step: Int,
        onEdit: (() -> Void)? = nil
    ) -> some View {
        let binding = Binding<Int>(
            get: { value.wrappedValue },
            set: { newValue in
                value.wrappedValue = newValue
                onEdit?()
            }
        )
        return HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(title.uppercased())
                    .font(.flexMono(10))
                    .tracking(1.5)
                    .foregroundStyle(Theme.inkSubtle)
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text("\(value.wrappedValue)")
                        .font(.flexStat(24))
                        .monospacedDigit()
                        .foregroundStyle(Theme.ink)
                    Text(unit.uppercased())
                        .font(.flexMono(9))
                        .foregroundStyle(Theme.inkSubtle)
                }
            }
            Spacer()
            Stepper(title, value: binding, in: range, step: step)
                .labelsHidden()
        }
        .padding(14)
        .background(Theme.card)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

// MARK: - Food entry detail

/// Everything known about one logged food: the photo, the per-item
/// breakdown, every nutrient — and one tap to eat it again.
struct FoodEntryDetailSheet: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    let entry: FoodEntry

    private let columns = [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)]

    var body: some View {
        VStack(spacing: 0) {
            Capsule()
                .fill(Theme.inkSubtle.opacity(0.3))
                .frame(width: 36, height: 5)
                .padding(.top, 10)
                .padding(.bottom, 14)

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    if let fileName = entry.photoFileName {
                        AsyncPhotoView(url: store.imageURL(fileName: fileName), maxPixel: 900)
                            .frame(maxWidth: .infinity)
                            .frame(height: 200)
                            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        Text("\(entry.meal.label.uppercased()) · \(entry.date.formatted(.dateTime.weekday(.abbreviated).day().month().hour().minute()).uppercased())")
                            .font(.flexMono(10))
                            .tracking(1.5)
                            .foregroundStyle(Theme.accent)
                        Text(entry.name.uppercased())
                            .font(.flexDisplay(28))
                            .foregroundStyle(Theme.ink)
                        HStack(alignment: .firstTextBaseline, spacing: 6) {
                            Text("\(entry.calories)")
                                .font(.flexStat(40))
                                .foregroundStyle(Theme.ink)
                            Text("KCAL")
                                .font(.flexMono(11))
                                .tracking(1.5)
                                .foregroundStyle(Theme.inkSubtle)
                        }
                    }

                    if let macros = entry.macros {
                        LazyVGrid(columns: columns, spacing: 8) {
                            nutrient("Protein", grams: macros.protein)
                            nutrient("Carbs", grams: macros.carbs)
                            nutrient("Fat", grams: macros.fat)
                            nutrient("Fibre", grams: macros.fiber)
                            nutrient("Sugar", grams: macros.sugar)
                            nutrientTile("Sodium", value: "\(Int(macros.sodiumMg.rounded()))", unit: "MG")
                        }
                    } else {
                        Text("Calories only — this entry was logged without macros.")
                            .font(.flexCaption())
                            .foregroundStyle(Theme.inkSubtle)
                    }

                    if let items = entry.items, !items.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            SectionHeader(title: "Breakdown", subtitle: "What was on the plate, as logged.")
                            ForEach(items) { item in
                                HStack(alignment: .top) {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(item.name)
                                            .font(.flexBodyBold())
                                            .foregroundStyle(Theme.ink)
                                        Text("\(item.portion.uppercased()) · \(item.multiplierLabel)")
                                            .font(.flexMono(9))
                                            .tracking(1)
                                            .foregroundStyle(item.isAddOn ? Theme.amber : Theme.inkSubtle)
                                        if let macros = item.macros {
                                            Text(macros.shortLabel)
                                                .font(.flexMono(9))
                                                .foregroundStyle(Theme.inkSubtle)
                                        }
                                    }
                                    Spacer()
                                    Text("\(item.calories)")
                                        .font(.flexBodyBold())
                                        .monospacedDigit()
                                        .foregroundStyle(Theme.ink)
                                }
                                .padding(12)
                                .background(Theme.card)
                                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                            }
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
            }
            .scrollIndicators(.hidden)

            VStack(spacing: 10) {
                Button {
                    store.relogFood(entry, on: .now)
                    dismiss()
                } label: {
                    Label("Log again today", systemImage: "arrow.clockwise")
                }
                .buttonStyle(PrimaryButtonStyle())

                Button(role: .destructive) {
                    store.deleteFood(entry)
                    dismiss()
                } label: {
                    Label("Delete entry", systemImage: "trash")
                }
                .buttonStyle(SecondaryButtonStyle(tint: Theme.danger))
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 12)
        }
        .background(Theme.background)
        .presentationDetents([.large])
    }

    private func nutrient(_ label: String, grams: Double) -> some View {
        nutrientTile(label, value: grams < 10 ? String(format: "%.1f", grams) : "\(Int(grams.rounded()))", unit: "G")
    }

    private func nutrientTile(_ label: String, value: String, unit: String) -> some View {
        VStack(spacing: 4) {
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(value)
                    .font(.flexStat(20))
                    .foregroundStyle(Theme.ink)
                Text(unit)
                    .font(.flexMono(8))
                    .foregroundStyle(Theme.inkSubtle)
            }
            Text(label.uppercased())
                .font(.flexMono(8))
                .tracking(1.5)
                .foregroundStyle(Theme.inkSubtle)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(Theme.card)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}
