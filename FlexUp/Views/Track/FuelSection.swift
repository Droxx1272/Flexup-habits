import SwiftUI
import UIKit

/// Calorie tracking, deliberately simple: a daily budget, four meals,
/// quick-add foods — and snap the plate while you're at it.
struct FuelSection: View {
    @Environment(AppStore.self) private var store
    @State private var showAddFood = false
    @State private var addMeal: MealType = .breakfast
    @State private var showBudgetEdit = false

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

    init(meal: MealType) {
        _meal = State(initialValue: meal)
    }

    private var cameraAvailable: Bool {
        UIImagePickerController.isSourceTypeAvailable(.camera)
    }

    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty && (calories ?? 0) > 0
    }

    private let columns = [GridItem(.flexible()), GridItem(.flexible())]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Capsule()
                .fill(Theme.inkSubtle.opacity(0.3))
                .frame(width: 36, height: 5)
                .frame(maxWidth: .infinity)
                .padding(.top, 10)

            Text("LOG FOOD")
                .font(.flexMono(12))
                .tracking(2)
                .foregroundStyle(Theme.ink)

            HStack(spacing: 8) {
                ForEach(MealType.allCases) { item in
                    SelectableChip(label: item.label, isSelected: meal == item) {
                        meal = item
                    }
                }
            }

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

            // Snap the plate — a photo makes the log honest, and AI can
            // estimate the calories from it.
            HStack(spacing: 10) {
                if let photoData, let image = UIImage(data: photoData) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 52, height: 52)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    Button {
                        self.photoData = nil
                        estimateNote = nil
                        estimateError = nil
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(Theme.inkSubtle)
                    }
                    .buttonStyle(.plain)
                    Button {
                        runEstimate()
                    } label: {
                        HStack(spacing: 6) {
                            if estimating {
                                ProgressView()
                                    .controlSize(.small)
                            } else {
                                Image(systemName: "sparkles")
                            }
                            Text(estimating ? "Estimating…" : "Estimate with AI")
                        }
                        .font(.flexCaption())
                        .foregroundStyle(Theme.accent)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(Theme.accentSoft)
                        .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    .disabled(estimating)
                } else {
                    Button {
                        if cameraAvailable { showCamera = true } else { showLibrary = true }
                    } label: {
                        Label("Snap your meal", systemImage: "camera")
                            .font(.flexCaption())
                            .foregroundStyle(Theme.accent)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)
                            .background(Theme.accentSoft)
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
                Spacer()
            }

            if let estimateNote {
                Text(estimateNote.uppercased())
                    .font(.flexMono(9))
                    .tracking(1)
                    .foregroundStyle(Theme.accent)
            }
            if let estimateError {
                Text(estimateError)
                    .font(.flexCaption())
                    .foregroundStyle(Theme.danger)
            }

            SectionHeader(title: "Quick add")
            ScrollView {
                LazyVGrid(columns: columns, spacing: 8) {
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
            .scrollIndicators(.hidden)

            Button("Add to \(meal.label.lowercased())") {
                store.addFood(name: name, calories: calories ?? 0, meal: meal, photoData: photoData)
                dismiss()
            }
            .buttonStyle(PrimaryButtonStyle())
            .disabled(!canSave)
            .opacity(canSave ? 1 : 0.4)
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 12)
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
    }

    private func runEstimate() {
        guard let photoData, let image = UIImage(data: photoData) else { return }
        guard !store.anthropicAPIKey.isEmpty else {
            showKeyEntry = true
            return
        }

        estimating = true
        estimateError = nil
        estimateNote = nil
        let apiKey = store.anthropicAPIKey

        Task {
            do {
                let estimate = try await CalorieEstimator.estimate(image: image, apiKey: apiKey)
                await MainActor.run {
                    name = estimate.foodName
                    calories = estimate.calories
                    estimateNote = "\(estimate.confidence) confidence · \(estimate.notes)"
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

            Text("Paste an Anthropic API key (console.anthropic.com → API Keys). It's stored only on this phone and each estimate costs about a cent.")
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
