import SwiftUI
import UIKit

/// Calorie tracking, deliberately simple: a daily budget, four meals,
/// quick-add foods — and snap the plate while you're at it.
struct FuelSection: View {
    @Environment(AppStore.self) private var store
    @State private var showAddFood = false
    @State private var addMeal: MealType = .breakfast
    @State private var showBudgetEdit = false
    @State private var showLogWeight = false

    private var consumed: Int { store.caloriesToday }
    private var budget: Int { store.calorieBudget }
    private var remaining: Int { budget - consumed }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            budgetCard

            Button {
                addMeal = suggestedMeal
                showAddFood = true
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "fork.knife")
                    Text("Log food")
                }
            }
            .buttonStyle(PrimaryButtonStyle())

            ForEach(MealType.allCases) { meal in
                mealCard(meal)
            }

            weightCard
        }
        .sheet(isPresented: $showLogWeight) {
            LogWeightSheet()
        }
        .sheet(isPresented: $showAddFood) {
            AddFoodSheet(meal: addMeal)
        }
        .sheet(isPresented: $showBudgetEdit) {
            BudgetSheet()
        }
    }

    // MARK: Budget

    private var budgetCard: some View {
        FlexCard {
            HStack(spacing: 18) {
                ZStack {
                    ProgressRing(progress: budget > 0 ? min(1, Double(consumed) / Double(budget)) : 0)
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
                    Text("TODAY'S FUEL")
                        .font(.flexMono(10))
                        .tracking(2)
                        .foregroundStyle(Theme.inkSubtle)
                    Text("\(consumed) of \(budget) kcal")
                        .font(.flexBodyBold())
                        .foregroundStyle(Theme.ink)
                    Button {
                        showBudgetEdit = true
                    } label: {
                        Text("EDIT BUDGET")
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

    // MARK: Meals

    private func mealCard(_ meal: MealType) -> some View {
        let entries = store.todayFood(for: meal)
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
                        HStack {
                            if let fileName = entry.photoFileName {
                                AsyncPhotoView(url: store.imageURL(fileName: fileName), maxPixel: 100)
                                    .frame(width: 34, height: 34)
                                    .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
                            }
                            Text(entry.name)
                                .font(.flexBody())
                                .foregroundStyle(Theme.ink)
                            Spacer()
                            Text("\(entry.calories)")
                                .font(.flexBodyBold())
                                .monospacedDigit()
                                .foregroundStyle(Theme.ink)
                            Button {
                                store.deleteFood(entry)
                            } label: {
                                Image(systemName: "minus.circle")
                                    .foregroundStyle(Theme.inkSubtle)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
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
    @State private var showKeyEntry = false

    /// Non-empty once a photo has been estimated — switches the sheet from
    /// manual entry into the itemised review where portions get corrected.
    @State private var items: [FoodItem] = []
    @State private var correction = ""
    @State private var showContextEditor = false
    @State private var dictation = VoiceDictation()

    init(meal: MealType) {
        _meal = State(initialValue: meal)
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
                    Text(isReviewing ? "CHECK THE ESTIMATE" : "LOG FOOD")
                        .font(.flexMono(12))
                        .tracking(2)
                        .foregroundStyle(Theme.ink)

                    mealPicker
                    photoBlock

                    if isReviewing {
                        itemsEditor
                        addOnsRow
                        correctionRow
                    } else {
                        manualEntry
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
        .sheet(isPresented: $showKeyEntry) {
            APIKeySheet {
                runEstimate()
            }
        }
        .sheet(isPresented: $showContextEditor) {
            CuisineContextSheet()
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
                                isAddOn: true
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
                        name = food.name
                        calories = food.calories
                    } label: {
                        HStack {
                            Text(food.name)
                                .font(.flexCaption())
                                .foregroundStyle(Theme.ink)
                                .lineLimit(1)
                            Spacer()
                            Text("\(food.calories)")
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
                    photoData: photoData,
                    items: isReviewing ? items : nil
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
        guard !store.anthropicAPIKey.isEmpty else {
            showKeyEntry = true
            return
        }

        dictation.stop()
        estimating = true
        estimateError = nil
        estimateNote = nil

        let apiKey = store.anthropicAPIKey
        let context = store.cuisineContext
        let note = correction
        // Anything the user added by hand survives a re-estimate — they
        // know about the ghee, the model doesn't.
        let manualAddOns = items.filter(\.isAddOn)

        Task {
            do {
                let estimate = try await CalorieEstimator.estimate(
                    image: image,
                    apiKey: apiKey,
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

// MARK: - API key entry

/// One-time setup for the AI estimator. The key stays on this device —
/// a backend proxy replaces this before any public release.
struct APIKeySheet: View {
    var onSaved: () -> Void
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var key = ""

    var body: some View {
        VStack(spacing: 16) {
            Capsule()
                .fill(Theme.inkSubtle.opacity(0.3))
                .frame(width: 36, height: 5)
                .padding(.top, 10)

            Image(systemName: "sparkles")
                .font(.system(size: 30))
                .foregroundStyle(Theme.accent)
                .padding(.top, 8)

            Text("SET UP AI ESTIMATES")
                .font(.flexMono(12))
                .tracking(2)
                .foregroundStyle(Theme.ink)

            Text("Paste an Anthropic API key (console.anthropic.com → API Keys). It's stored only on this phone and each estimate costs a fraction of a cent.")
                .font(.flexCaption())
                .foregroundStyle(Theme.inkSubtle)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)

            SecureField("sk-ant-…", text: $key)
                .font(.flexBodyBold())
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .padding(14)
                .background(Theme.card)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .padding(.horizontal, 20)

            Button("Save & estimate") {
                store.anthropicAPIKey = key.trimmingCharacters(in: .whitespacesAndNewlines)
                dismiss()
                onSaved()
            }
            .buttonStyle(PrimaryButtonStyle())
            .disabled(key.trimmingCharacters(in: .whitespaces).isEmpty)
            .opacity(key.trimmingCharacters(in: .whitespaces).isEmpty ? 0.4 : 1)
            .padding(.horizontal, 20)

            Spacer()
        }
        .background(Theme.background)
        .presentationDetents([.medium])
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

// MARK: - Budget sheet

struct BudgetSheet: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var budget = 2200

    var body: some View {
        VStack(spacing: 20) {
            Text("DAILY BUDGET")
                .font(.flexMono(12))
                .tracking(2)
                .foregroundStyle(Theme.ink)
                .padding(.top, 24)

            Text("\(budget)")
                .font(.flexDisplay(56))
                .monospacedDigit()
                .foregroundStyle(Theme.ink)
            Text("KCAL / DAY")
                .font(.flexMono(11))
                .tracking(2)
                .foregroundStyle(Theme.inkSubtle)

            Stepper("Adjust", value: $budget, in: 1200...4500, step: 50)
                .labelsHidden()

            Text("A budget is a direction, not a verdict. Pick one you can keep on a normal day.")
                .font(.flexCaption())
                .foregroundStyle(Theme.inkSubtle)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 30)

            Button("Save") {
                store.calorieBudget = budget
                store.save()
                dismiss()
            }
            .buttonStyle(PrimaryButtonStyle())
            .padding(.horizontal, 20)
        }
        .padding(.bottom, 16)
        .frame(maxWidth: .infinity)
        .background(Theme.background)
        .presentationDetents([.medium])
        .onAppear { budget = store.calorieBudget }
    }
}
