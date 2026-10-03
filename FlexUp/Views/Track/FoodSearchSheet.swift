import SwiftUI

/// What the food search was opened for: a fresh item, or a better match
/// for an item already on the plate (an AI guess, say).
struct FoodSearchRequest: Identifiable {
    let id = UUID()
    var query = ""
    /// Weight to start the portion picker at, e.g. the AI's gram estimate.
    var grams: Double?
    var replacing: FoodItem.ID?
}

/// Search the bundled USDA list, pick a portion, get exact numbers.
struct FoodSearchSheet: View {
    @Environment(\.dismiss) private var dismiss
    let request: FoodSearchRequest
    let onPick: (FoodItem) -> Void

    @State private var query = ""
    @State private var results: [USDAFood] = []
    @State private var hasSearched = false
    @FocusState private var fieldFocused: Bool

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                searchField
                    .padding(.horizontal, 20)
                    .padding(.bottom, 12)

                ScrollView {
                    LazyVStack(spacing: 8) {
                        if query.trimmingCharacters(in: .whitespaces).isEmpty {
                            hint("Search by name, like \"dal\", \"chapati\", \"grilled chicken breast\" or \"banana\".")
                        } else if hasSearched && results.isEmpty {
                            hint("Nothing matched. Try a simpler word, or log it by hand.")
                        }
                        ForEach(results) { food in
                            NavigationLink(value: food) {
                                resultRow(food)
                            }
                            .buttonStyle(.plain)
                        }
                        Text("Nutrition data from USDA FoodData Central.")
                            .font(.flexCaption())
                            .foregroundStyle(Theme.inkSubtle)
                            .padding(.top, 12)
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 20)
                }
                .scrollDismissesKeyboard(.interactively)
            }
            .background(Theme.background)
            .navigationTitle("Search foods")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .navigationDestination(for: USDAFood.self) { food in
                FoodPortionPicker(food: food, startingGrams: request.grams) { item in
                    onPick(item)
                    dismiss()
                }
            }
            .task(id: query) {
                let text = query
                // Debounce: typing fast shouldn't search every keystroke.
                try? await Task.sleep(nanoseconds: 180_000_000)
                guard !Task.isCancelled else { return }
                let found = await FoodDatabase.shared.search(text)
                guard !Task.isCancelled else { return }
                results = found
                hasSearched = !text.trimmingCharacters(in: .whitespaces).isEmpty
            }
        }
        .tint(Theme.ink)
        .onAppear {
            query = request.query
            fieldFocused = request.query.isEmpty
        }
    }

    private var searchField: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(Theme.inkSubtle)
            TextField("Search foods", text: $query)
                .font(.flexBody())
                .focused($fieldFocused)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .submitLabel(.search)
            if !query.isEmpty {
                Button {
                    query = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(Theme.inkSubtle)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Clear search")
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(Theme.card)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func hint(_ text: String) -> some View {
        Text(text)
            .font(.flexCaption())
            .foregroundStyle(Theme.inkSubtle)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 8)
    }

    private func resultRow(_ food: USDAFood) -> some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(food.name)
                    .font(.flexBodyBold())
                    .foregroundStyle(Theme.ink)
                    .multilineTextAlignment(.leading)
                    .lineLimit(2)
                if !food.category.isEmpty {
                    Text(food.category.uppercased())
                        .font(.flexMono(8))
                        .tracking(1)
                        .foregroundStyle(Theme.inkSubtle)
                        .lineLimit(1)
                }
            }
            Spacer(minLength: 8)
            VStack(alignment: .trailing, spacing: 1) {
                Text("\(Int(food.kcal.rounded()))")
                    .font(.flexBodyBold())
                    .monospacedDigit()
                    .foregroundStyle(Theme.ink)
                Text("KCAL/100G")
                    .font(.flexMono(8))
                    .foregroundStyle(Theme.inkSubtle)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.card)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .contentShape(Rectangle())
    }
}

/// Choose how much: one of USDA's household measures times a quantity, or
/// an exact weight in grams.
struct FoodPortionPicker: View {
    let food: USDAFood
    let startingGrams: Double?
    let onAdd: (FoodItem) -> Void

    /// nil = weigh it in grams.
    @State private var portionIndex: Int?
    @State private var quantity: Double = 1
    @State private var customGrams: Double?

    private var grams: Double {
        if let portionIndex, food.portions.indices.contains(portionIndex) {
            return food.portions[portionIndex].grams * quantity
        }
        return customGrams ?? 0
    }

    private var portionLabel: String {
        let weight = "\(Int(grams.rounded())) g"
        guard let portionIndex, food.portions.indices.contains(portionIndex) else { return weight }
        let count = quantity == quantity.rounded() ? "\(Int(quantity))" : String(format: "%.1f", quantity)
        return "\(count) × \(food.portions[portionIndex].label) (\(weight))"
    }

    var body: some View {
        let macros = food.macros(grams: grams)
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text(food.name)
                    .font(.system(size: 24, weight: .black))
                    .foregroundStyle(Theme.ink)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text("\(food.calories(grams: grams))")
                        .font(.flexStat(48))
                        .foregroundStyle(Theme.accent)
                        .contentTransition(.numericText())
                        .animation(.snappy, value: grams)
                    Text("KCAL")
                        .font(.flexMono(11))
                        .tracking(1.5)
                        .foregroundStyle(Theme.inkSubtle)
                }

                StatStrip([
                    ("\(Int(macros.protein.rounded()))g", "Protein"),
                    ("\(Int(macros.carbs.rounded()))g", "Carbs"),
                    ("\(Int(macros.fat.rounded()))g", "Fat")
                ])

                VStack(alignment: .leading, spacing: 10) {
                    Text("PORTION")
                        .font(.flexMono(10))
                        .tracking(2)
                        .foregroundStyle(Theme.inkSubtle)
                    ScrollView(.horizontal) {
                        HStack(spacing: 8) {
                            ForEach(Array(food.portions.enumerated()), id: \.offset) { index, portion in
                                SelectableChip(label: portion.label, isSelected: portionIndex == index) {
                                    portionIndex = index
                                }
                            }
                            SelectableChip(label: "Grams", isSelected: portionIndex == nil) {
                                if customGrams == nil { customGrams = grams > 0 ? grams.rounded() : 100 }
                                portionIndex = nil
                            }
                        }
                    }
                    .scrollIndicators(.hidden)
                }

                if portionIndex != nil {
                    HStack {
                        Text("How many")
                            .font(.flexBody())
                            .foregroundStyle(Theme.ink)
                        Spacer()
                        stepButton("minus") { quantity = max(0.5, quantity - 0.5) }
                        Text(quantity == quantity.rounded() ? "\(Int(quantity))" : String(format: "%.1f", quantity))
                            .font(.flexBodyBold())
                            .monospacedDigit()
                            .frame(minWidth: 44)
                        stepButton("plus") { quantity = min(20, quantity + 0.5) }
                    }
                    .padding(14)
                    .background(Theme.card)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                } else {
                    HStack {
                        Text("Weight")
                            .font(.flexBody())
                            .foregroundStyle(Theme.ink)
                        Spacer()
                        TextField("100", value: $customGrams, format: .number)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .font(.flexBodyBold())
                            .frame(width: 90)
                        Text("g")
                            .font(.flexBody())
                            .foregroundStyle(Theme.inkSubtle)
                    }
                    .padding(14)
                    .background(Theme.card)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }

                Text("Per 100 g: \(Int(food.kcal.rounded())) kcal · \(format(food.protein))g protein · \(format(food.carbs))g carbs · \(format(food.fat))g fat. Source: USDA FoodData Central.")
                    .font(.flexCaption())
                    .foregroundStyle(Theme.inkSubtle)
            }
            .padding(20)
        }
        .scrollDismissesKeyboard(.interactively)
        .safeAreaInset(edge: .bottom) {
            Button("Add to plate") {
                onAdd(food.item(grams: grams, portionLabel: portionLabel))
            }
            .buttonStyle(PrimaryButtonStyle())
            .disabled(grams <= 0)
            .opacity(grams > 0 ? 1 : 0.4)
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(Theme.background)
        }
        .background(Theme.background)
        .navigationTitle("Portion")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            if let startingGrams, startingGrams > 0 {
                customGrams = startingGrams.rounded()
                portionIndex = nil
            } else if !food.portions.isEmpty {
                portionIndex = 0
            } else {
                customGrams = 100
            }
        }
    }

    private func format(_ value: Double) -> String {
        value >= 10 ? "\(Int(value.rounded()))" : String(format: "%.1f", value)
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
}
