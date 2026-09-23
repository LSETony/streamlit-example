import SwiftUI

struct TrainersView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss
    @State private var selectedTrainer: Trainer?
    @State private var search = ""
    @State private var favorites: Set<UUID> = []
    @State private var isShowingFilters = false
    @State private var maxPrice: Double = 500
    @State private var selectedTags: Set<String> = []
    @State private var sortOption = "Top rated"
    private let sortOptions = ["Top rated", "Price: low to high", "Price: high to low", "Name"]

    private var priceBound: Double {
        Double(appState.trainers.compactMap { Int($0.priceCompact) }.max() ?? 100)
    }

    private var allTags: [String] {
        Array(Set(appState.trainers.flatMap(\.tags))).sorted()
    }

    private var filteredTrainers: [Trainer] {
        let filtered = appState.trainers.filter { trainer in
            let matchesSearch = search.isEmpty
                || trainer.name.localizedCaseInsensitiveContains(search)
                || trainer.specialty.localizedCaseInsensitiveContains(search)
                || trainer.tags.contains { $0.localizedCaseInsensitiveContains(search) }
            let matchesPrice = Double(Int(trainer.priceCompact) ?? 0) <= maxPrice
            let matchesTags = selectedTags.isEmpty || !Set(trainer.tags).isDisjoint(with: selectedTags)
            return matchesSearch && matchesPrice && matchesTags
        }
        switch sortOption {
        case "Price: low to high":
            return filtered.sorted { (Int($0.priceCompact) ?? 0) < (Int($1.priceCompact) ?? 0) }
        case "Price: high to low":
            return filtered.sorted { (Int($0.priceCompact) ?? 0) > (Int($1.priceCompact) ?? 0) }
        case "Name":
            return filtered.sorted { $0.name < $1.name }
        default:
            return filtered.sorted { (Double($0.rating) ?? 0) > (Double($1.rating) ?? 0) }
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Personal Trainers")
                    .font(.brand(32))
                    .foregroundStyle(.white)
                SearchToolRow(search: $search, sortOptions: sortOptions, onSortSelect: { sortOption = $0 }) { isShowingFilters = true }

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 14) {
                    ForEach(filteredTrainers) { trainer in
                        TrainerTile(
                            trainer: trainer,
                            isFavorite: Binding(
                                get: { favorites.contains(trainer.id) },
                                set: { on in
                                    if on { favorites.insert(trainer.id) } else { favorites.remove(trainer.id) }
                                }
                            )
                        ) {
                            selectedTrainer = trainer
                        }
                    }
                }
            }
            .screenPadding()
            .padding(.top, 12)
            .padding(.bottom, 24)
        }
        .background(Color.appBackground.ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Done") { dismiss() }.foregroundStyle(Color.appAccent)
            }
        }
        .sheet(item: $selectedTrainer) { trainer in
            NavigationStack { TrainerDetailView(trainer: trainer) }
        }
        .sheet(isPresented: $isShowingFilters) {
            PriceTagFilterSheet(
                title: "Filter trainers",
                maxPrice: $maxPrice,
                priceBound: priceBound,
                sectionLabel: "Specialty",
                allOptions: allTags,
                selectedOptions: $selectedTags
            )
        }
    }
}

/// Shared price + tag/ingredient filter sheet used by Trainers, Store and
/// Food recipes — "max price" slider plus a checklist of the domain's
/// content options (specialty tags, ingredients).
struct PriceTagFilterSheet: View {
    @Environment(\.dismiss) private var dismiss
    let title: String
    @Binding var maxPrice: Double
    let priceBound: Double
    let sectionLabel: String
    let allOptions: [String]
    @Binding var selectedOptions: Set<String>

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 10) {
                    EyebrowLabel(text: "Max price")
                    Text("$\(Int(maxPrice))")
                        .font(.digitalTimer(28))
                        .foregroundStyle(.white)
                    Slider(value: $maxPrice, in: 0...max(priceBound, 1))
                        .tint(Color.appAccent)
                }

                if !allOptions.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        EyebrowLabel(text: sectionLabel)
                        ScrollView {
                            VStack(spacing: 8) {
                                ForEach(allOptions, id: \.self) { option in
                                    optionRow(option)
                                }
                            }
                        }
                    }
                }

                Spacer(minLength: 0)
            }
            .screenPadding()
            .padding(.top, 12)
            .padding(.bottom, 24)
            .background(Color.appBackground.ignoresSafeArea())
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Reset") {
                        maxPrice = priceBound
                        selectedOptions.removeAll()
                    }
                    .foregroundStyle(Color.appTextSecondary)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }.foregroundStyle(Color.appAccent)
                }
            }
        }
    }

    private func optionRow(_ option: String) -> some View {
        let isOn = selectedOptions.contains(option)
        return Button {
            if isOn { selectedOptions.remove(option) } else { selectedOptions.insert(option) }
        } label: {
            HStack {
                Text(option)
                    .font(.system(size: 14))
                    .foregroundStyle(.white)
                Spacer()
                if isOn {
                    Image(systemName: "checkmark")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(Color.appAccent)
                }
            }
            .padding(14)
            .background(Color.appSurface)
            .clipShape(RoundedRectangle(cornerRadius: AppMetrics.smallCorner, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

/// Shared search field + sort/filter icon row used by Trainers, Supplements
/// and Food recipes in the latest Figma pass. The sort icon opens a menu of
/// `sortOptions` when the caller supplies any; with none (the default) it's
/// a plain non-interactive icon, same as before.
struct SearchToolRow: View {
    @Binding var search: String
    var sortOptions: [String] = []
    var onSortSelect: (String) -> Void = { _ in }
    var onFilterTap: () -> Void = {}

    var body: some View {
        GlassEffectContainer(spacing: 10) {
            HStack(spacing: 10) {
                HStack(spacing: 8) {
                    Image("IconSearch").customIcon(size: 14).foregroundStyle(Color.appTextSecondary)
                    TextField("", text: $search, prompt: Text("search").foregroundStyle(Color.appTextSecondary))
                        .font(.brand(16))
                        .foregroundStyle(.white)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 13)
                .glassEffect(.regular, in: Capsule())

                if sortOptions.isEmpty {
                    toolIcon("IconSort")
                } else {
                    Menu {
                        ForEach(sortOptions, id: \.self) { option in
                            Button(option) { onSortSelect(option) }
                        }
                    } label: {
                        toolIcon("IconSort")
                    }
                }
                Button(action: onFilterTap) {
                    Image("IconFilter").customIcon(size: 16)
                        .foregroundStyle(.white)
                        .frame(width: 42, height: 42)
                }
                .buttonStyle(.plain)
                .glassCircleButton()
            }
        }
    }

    private func toolIcon(_ name: String) -> some View {
        Image(name).customIcon(size: 16)
            .foregroundStyle(.white)
            .frame(width: 42, height: 42)
            .glassCircleButton()
    }
}

private struct TrainerTile: View {
    let trainer: Trainer
    @Binding var isFavorite: Bool
    var onOpen: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button(action: onOpen) {
                ZStack(alignment: .topTrailing) {
                    Image(trainer.imageName)
                        .resizable()
                        .scaledToFill()
                    FavoriteButton(isFavorite: $isFavorite).padding(8)
                }
                .aspectRatio(186.0 / 250.0, contentMode: .fit)
                .clipShape(RoundedRectangle(cornerRadius: AppMetrics.smallCorner, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: AppMetrics.smallCorner, style: .continuous).stroke(Color.appDivider, lineWidth: 1))
            }
            .buttonStyle(.plain)
            Text(trainer.name)
                .font(.brand(16))
                .foregroundStyle(.white)
            Text("Personal trainer")
                .font(.brand(12))
                .foregroundStyle(Color.appTextSecondary)
        }
    }
}

struct TrainerDetailView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss
    let trainer: Trainer
    @State private var selectedSlot: String = ""
    @State private var didBook = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                HStack(spacing: 16) {
                    Image(trainer.imageName)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 76, height: 76)
                        .clipShape(Circle())
                    VStack(alignment: .leading, spacing: 5) {
                        Text(trainer.name)
                            .font(.brand(24))
                            .foregroundStyle(.white)
                        Text(trainer.specialty)
                            .font(.system(size: 13))
                            .foregroundStyle(Color.appTextSecondary)
                        HStack(spacing: 10) {
                            Text(trainer.rating).font(.digitalTimer(16)).foregroundStyle(Color.appAccent)
                            Text("\(trainer.reviews) reviews · \(trainer.yearsExperience)")
                                .font(.system(size: 12))
                                .foregroundStyle(Color.appTextSecondary)
                        }
                    }
                }

                HStack(spacing: 8) {
                    ForEach(trainer.tags, id: \.self) { tag in
                        Text(tag)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(Color.appAccent)
                            .padding(.horizontal, 13)
                            .padding(.vertical, 7)
                            .background(Color.appAccentDim)
                            .clipShape(Capsule())
                    }
                }

                Text(trainer.bio)
                    .font(.system(size: 14))
                    .foregroundStyle(Color.appTextSecondary)
                    .lineSpacing(4)

                HStack(spacing: 10) {
                    statBlock(value: "\(trainer.clients)", label: "Clients")
                    statBlock(value: "\(trainer.sessions)", label: "Sessions")
                    statBlock(value: trainer.priceCompact, label: "Per hour")
                }

                VStack(alignment: .leading, spacing: 10) {
                    EyebrowLabel(text: "Next free slots · Tue 15")
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: 8) {
                        ForEach(appState.trainerSlots, id: \.self) { slot in
                            let on = selectedSlot == slot
                            Text(slot)
                                .font(.digitalTimer(15))
                                .foregroundStyle(on ? .white : Color.appTextPrimary)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 11)
                                .background(on ? Color.appAccent : Color.appSurface)
                                .overlay(RoundedRectangle(cornerRadius: AppMetrics.smallCorner, style: .continuous).stroke(on ? .clear : Color.appDivider, lineWidth: 1))
                                .clipShape(RoundedRectangle(cornerRadius: AppMetrics.smallCorner, style: .continuous))
                                .onTapGesture { selectedSlot = slot }
                        }
                    }
                }

                PrimaryButton(title: didBook ? "✓ Session requested" : "Book \(trainer.name.split(separator: " ").first.map(String.init) ?? trainer.name) · \(selectedSlot.isEmpty ? appState.trainerSlots.first ?? "" : selectedSlot)", isEnabled: !didBook) {
                    didBook = true
                }
            }
            .screenPadding()
            .padding(.top, 12)
            .padding(.bottom, 24)
        }
        .background(Color.appBackground.ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Done") { dismiss() }.foregroundStyle(Color.appAccent)
            }
        }
        .onAppear { selectedSlot = appState.trainerSlots.first ?? "" }
    }

    private func statBlock(value: String, label: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(value).font(.digitalTimer(20)).foregroundStyle(.white)
            Text(label.uppercased()).font(.system(size: 10, weight: .semibold)).tracking(0.4).foregroundStyle(Color.appTextSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(Color.appSurface)
        .clipShape(RoundedRectangle(cornerRadius: AppMetrics.smallCorner, style: .continuous))
    }
}

#Preview {
    NavigationStack { TrainersView() }
        .environmentObject(AppState())
}
