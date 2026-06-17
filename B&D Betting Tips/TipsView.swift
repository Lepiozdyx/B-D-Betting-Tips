import SwiftUI

struct TipsView: View {
    @AppStorage("readTipIDs") private var readTipIDs = ""
    @AppStorage("favoriteTipIDs") private var favoriteTipIDs = ""
    @State private var searchText = ""
    @State private var selectedCategory: TipCategory?
    @State private var expandedTipID: Int?

    private var readIDs: Set<Int> {
        parseIDs(readTipIDs)
    }

    private var favoriteIDs: Set<Int> {
        parseIDs(favoriteTipIDs)
    }

    private var filteredTips: [BettingTip] {
        AppData.tips.filter { tip in
            let matchesCategory = selectedCategory == nil || tip.category == selectedCategory
            let matchesSearch = searchText.isEmpty
                || tip.title.localizedCaseInsensitiveContains(searchText)
                || tip.detail.localizedCaseInsensitiveContains(searchText)
                || tip.content.localizedCaseInsensitiveContains(searchText)
                || tip.keyTakeaway.localizedCaseInsensitiveContains(searchText)
            return matchesCategory && matchesSearch
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    categoryPicker
                    progressCard

                    if filteredTips.isEmpty {
                        EmptyStateView(
                            icon: "magnifyingglass",
                            title: "No Tips Found",
                            message: "Try another search term or category."
                        )
                    } else {
                        ForEach(filteredTips) { tip in
                            tipCard(tip)
                        }
                    }
                }
                .padding()
            }
            .appScreen()
            .navigationTitle("Professional Betting Tips")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $searchText, prompt: "Search tips")
        }
    }

    private var progressCard: some View {
        AppCard {
            VStack(spacing: 12) {
                HStack {
                    Text("Your Progress")
                        .font(.headline)
                    Spacer()
                    Text("\(readIDs.count) / \(AppData.tips.count)")
                }
                ProgressView(value: Double(readIDs.count), total: Double(AppData.tips.count))
                    .tint(AppTheme.accent)
                HStack {
                    Text("Completion")
                    Spacer()
                    Text("\(Int(Double(readIDs.count) / Double(AppData.tips.count) * 100))%")
                }
                .font(.subheadline)
                .foregroundStyle(AppTheme.secondaryText)
                HStack {
                    Text("Favorite Tips")
                    Spacer()
                    Text("\(favoriteIDs.count)")
                }
                .font(.subheadline)
                .foregroundStyle(AppTheme.secondaryText)
            }
        }
    }

    private var categoryPicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack {
                categoryButton("All", category: nil)
                ForEach(TipCategory.allCases) { category in
                    categoryButton(category.rawValue, category: category)
                }
            }
        }
    }

    private func categoryButton(_ title: String, category: TipCategory?) -> some View {
        Button(title) {
            selectedCategory = category
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(selectedCategory == category ? AppTheme.accent : AppTheme.surface)
        .clipShape(Capsule())
        .foregroundStyle(.white)
    }

    private func tipCard(_ tip: BettingTip) -> some View {
        let isExpanded = expandedTipID == tip.id

        return VStack(alignment: .leading, spacing: 0) {
            Button {
                withAnimation(.easeInOut(duration: 0.22)) {
                    expandedTipID = isExpanded ? nil : tip.id
                    markRead(tip.id)
                }
            } label: {
                ZStack {
                    if !isExpanded {
                        CollapsedTipBackground()
                    }

                    VStack(alignment: .leading, spacing: 7) {
                        HStack(alignment: .center, spacing: 8) {
                            Text("#\(tip.id)")
                                .font(.caption)
                                .foregroundStyle(AppTheme.secondaryText)

                            Text(tip.category.rawValue)
                                .font(.caption)
                                .foregroundStyle(AppTheme.accent)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(AppTheme.accent.opacity(0.18), in: Capsule())

                            Spacer()

                            Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                                .font(.caption.bold())
                                .foregroundStyle(AppTheme.secondaryText)
                        }

                        Text(tip.title)
                            .font(.headline)
                            .foregroundStyle(.white)
                            .multilineTextAlignment(.leading)

                        Text(tip.detail)
                            .font(.subheadline)
                            .foregroundStyle(AppTheme.secondaryText)
                            .multilineTextAlignment(.leading)
                            .lineSpacing(3)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(20)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if isExpanded {
                Divider()
                    .overlay(AppTheme.border)

                VStack(alignment: .leading, spacing: 20) {
                    Text(nonEmpty(tip.content, fallback: "Detailed content has not been added yet."))
                        .font(.body)
                        .foregroundStyle(tip.content.isEmpty ? AppTheme.secondaryText : .white)
                        .lineSpacing(6)
                        .fixedSize(horizontal: false, vertical: true)

                    VStack(alignment: .leading, spacing: 7) {
                        Text("Key Takeaway")
                            .font(.caption)
                            .foregroundStyle(AppTheme.secondaryText)
                        Text(nonEmpty(tip.keyTakeaway, fallback: "Not provided"))
                            .font(.subheadline)
                            .foregroundStyle(tip.keyTakeaway.isEmpty ? AppTheme.secondaryText : .white)
                            .lineSpacing(3)
                    }
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(AppTheme.raised)
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))

                    HStack(alignment: .center, spacing: 12) {
                        Text(relatedText(tip.relatedTipIDs))
                            .font(.caption)
                            .foregroundStyle(AppTheme.secondaryText)

                        Spacer()

                        Button {
                            toggleFavorite(tip.id)
                        } label: {
                            Image(systemName: favoriteIDs.contains(tip.id) ? "bookmark.fill" : "bookmark")
                                .font(.subheadline)
                                .foregroundStyle(
                                    favoriteIDs.contains(tip.id) ? AppTheme.accent : AppTheme.secondaryText
                                )
                                .frame(width: 34, height: 34)
                                .background(AppTheme.raised, in: Circle())
                        }
                        .accessibilityLabel(
                            favoriteIDs.contains(tip.id) ? "Remove from favorites" : "Add to favorites"
                        )
                    }
                }
                .padding(20)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(AppTheme.border)
        }
    }

    private func parseIDs(_ value: String) -> Set<Int> {
        Set(value.split(separator: ",").compactMap { Int($0) })
    }

    private func markRead(_ id: Int) {
        var ids = readIDs
        ids.insert(id)
        readTipIDs = ids.sorted().map(String.init).joined(separator: ",")
    }

    private func toggleFavorite(_ id: Int) {
        var ids = favoriteIDs
        if ids.contains(id) {
            ids.remove(id)
        } else {
            ids.insert(id)
        }
        favoriteTipIDs = ids.sorted().map(String.init).joined(separator: ",")
    }

    private func nonEmpty(_ value: String, fallback: String) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? fallback : trimmed
    }

    private func relatedText(_ ids: [Int]) -> String {
        guard !ids.isEmpty else { return "Related: None" }
        return "Related: " + ids.map { "#\($0)" }.joined(separator: ", ")
    }
}

private struct CollapsedTipBackground: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    AppTheme.surface,
                    AppTheme.surface,
                    Color(red: 0.10, green: 0.10, blue: 0.12)
                ],
                startPoint: .leading,
                endPoint: .trailing
            )

            Canvas { context, size in
                var accentLine = Path()
                accentLine.move(to: CGPoint(x: size.width * 0.78, y: 0))
                accentLine.addLine(to: CGPoint(x: size.width * 0.62, y: size.height))
                context.stroke(accentLine, with: .color(AppTheme.accent.opacity(0.3)), lineWidth: 1)

                var darkBand = Path()
                darkBand.move(to: CGPoint(x: size.width * 0.94, y: 0))
                darkBand.addLine(to: CGPoint(x: size.width * 0.79, y: size.height))
                context.stroke(darkBand, with: .color(.white.opacity(0.05)), lineWidth: 10)

                for row in 0..<4 {
                    for column in 0..<5 {
                        let rect = CGRect(
                            x: size.width - 52 + CGFloat(column * 7),
                            y: size.height - 34 + CGFloat(row * 7),
                            width: 2,
                            height: 2
                        )
                        context.fill(Path(ellipseIn: rect), with: .color(AppTheme.accent.opacity(0.38)))
                    }
                }
            }
        }
    }
}
