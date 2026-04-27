import CurrencyConverterMacOS
import SwiftUI

// MARK: - Theme

private enum ConverterTheme {
    static let backgroundTop = Color(red: 0.05, green: 0.12, blue: 0.24)
    static let backgroundBottom = Color(red: 0.01, green: 0.05, blue: 0.12)
    static let panel = Color.white.opacity(0.075)
    static let panelStrong = Color.white.opacity(0.12)
    static let stroke = Color.white.opacity(0.16)
    static let strokeStrong = Color.white.opacity(0.28)
    static let primaryText = Color(red: 0.93, green: 0.96, blue: 1.0)
    static let secondaryText = Color(red: 0.66, green: 0.74, blue: 0.9)
    static let accent = Color(red: 0.18, green: 0.57, blue: 1.0)
    static let success = Color(red: 0.29, green: 0.86, blue: 0.4)
    static let warning = Color(red: 1.0, green: 0.66, blue: 0.25)
    static let danger = Color(red: 1.0, green: 0.3, blue: 0.28)
}

// MARK: - Inline Currency Picker

/// A searchable, scrollable currency list shown inline within the popover.
/// Replaces the main content when a currency button is tapped.
private struct InlineCurrencyPicker: View {
    let title: String
    let currencies: [CurrencyDescriptor]
    let currentCode: String
    let onSelect: (String) -> Void
    let onCancel: () -> Void

    @State private var searchText = ""
    @State private var assetFilter: CurrencyAssetFilter = .all
    @FocusState private var searchFocused: Bool

    private var filtered: [CurrencyDescriptor] {
        let categoryMatches = currencies.filter { assetFilter.includes($0) }
        guard !searchText.isEmpty else { return categoryMatches }

        return categoryMatches.filter {
            $0.code.localizedCaseInsensitiveContains(searchText) ||
                $0.displayName.localizedCaseInsensitiveContains(searchText) ||
                ($0.symbol?.localizedCaseInsensitiveContains(searchText) ?? false)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button {
                    onCancel()
                } label: {
                    Label("Back", systemImage: "chevron.left")
                        .labelStyle(.titleAndIcon)
                }
                .buttonStyle(.plain)
                .foregroundStyle(ConverterTheme.secondaryText)

                Spacer()

                Text(title)
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(ConverterTheme.primaryText)

                Spacer()

                Label("Back", systemImage: "chevron.left")
                    .hidden()
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)

            AssetFilterControl(selection: $assetFilter)
            .padding(.horizontal, 14)
            .padding(.bottom, 10)

            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(ConverterTheme.secondaryText)
                    .font(.caption)

                ZStack(alignment: .leading) {
                    if searchText.isEmpty {
                        Text("Search assets...")
                            .font(.body)
                            .foregroundStyle(ConverterTheme.secondaryText.opacity(0.78))
                    }

                    TextField("", text: $searchText)
                        .textFieldStyle(.plain)
                        .focused($searchFocused)
                        .font(.body)
                        .foregroundStyle(ConverterTheme.primaryText)
                }

                if !searchText.isEmpty {
                    Button {
                        searchText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(ConverterTheme.secondaryText)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
            .background(ConverterTheme.panelStrong)
            .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .stroke(ConverterTheme.stroke, lineWidth: 1)
            )
            .padding(.horizontal, 14)
            .padding(.bottom, 10)

            Divider()
                .overlay(ConverterTheme.stroke)

            if filtered.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .font(.title2)
                        .foregroundStyle(ConverterTheme.secondaryText)
                    Text("No assets found")
                        .font(.subheadline)
                        .foregroundStyle(ConverterTheme.secondaryText)
                }
                .frame(maxWidth: .infinity, minHeight: 220)
            } else {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            ForEach(filtered) { currency in
                                Button {
                                    onSelect(currency.code)
                                } label: {
                                    HStack(spacing: 10) {
                                        CurrencyBadge(currency: currency, size: 30)

                                        VStack(alignment: .leading, spacing: 2) {
                                            HStack(spacing: 7) {
                                                Text(currency.code)
                                                    .font(.body.weight(.semibold))
                                                    .foregroundStyle(ConverterTheme.primaryText)

                                                if currency.assetKind == .crypto {
                                                    Text("Crypto")
                                                        .font(.caption2.weight(.medium))
                                                        .foregroundStyle(ConverterTheme.secondaryText)
                                                        .padding(.horizontal, 6)
                                                        .padding(.vertical, 2)
                                                        .background(ConverterTheme.panelStrong)
                                                        .clipShape(Capsule())
                                                }
                                            }

                                            Text(currency.displayName)
                                                .font(.caption)
                                                .foregroundStyle(ConverterTheme.secondaryText)
                                                .lineLimit(1)
                                        }

                                        Spacer()

                                        if currency.code == currentCode {
                                            Image(systemName: "checkmark.circle.fill")
                                                .font(.body.weight(.semibold))
                                                .foregroundStyle(ConverterTheme.accent)
                                        }
                                    }
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 9)
                                    .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                                .id(currency.code)

                                if currency.code != filtered.last?.code {
                                    Divider()
                                        .overlay(ConverterTheme.stroke.opacity(0.6))
                                        .padding(.leading, 54)
                                }
                            }
                        }
                    }
                    .onAppear {
                        proxy.scrollTo(currentCode, anchor: .center)
                    }
                }
            }
        }
        .frame(width: 360, height: 420)
        .background(converterBackground)
        .onAppear { searchFocused = true }
    }
}

private enum CurrencyAssetFilter: String, CaseIterable, Identifiable {
    case all
    case fiat
    case crypto

    var id: String { rawValue }

    var title: String {
        switch self {
        case .all:
            return "All"
        case .fiat:
            return "Fiat"
        case .crypto:
            return "Crypto"
        }
    }

    func includes(_ currency: CurrencyDescriptor) -> Bool {
        switch self {
        case .all:
            return true
        case .fiat:
            return currency.assetKind == .fiat
        case .crypto:
            return currency.assetKind == .crypto
        }
    }
}

private struct AssetFilterControl: View {
    @Binding var selection: CurrencyAssetFilter

    var body: some View {
        HStack(spacing: 3) {
            ForEach(CurrencyAssetFilter.allCases) { filter in
                Button {
                    selection = filter
                } label: {
                    Text(filter.title)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(selection == filter ? Color.white : ConverterTheme.secondaryText)
                        .frame(maxWidth: .infinity)
                        .frame(height: 32)
                        .background(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(selection == filter ? ConverterTheme.accent : Color.clear)
                        )
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(3)
        .background(Color.black.opacity(0.18))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(ConverterTheme.stroke.opacity(0.75), lineWidth: 1)
        )
    }
}

// MARK: - Currency Controls

private struct CurrencyPickerButton: View {
    let currency: CurrencyDescriptor?
    let code: String
    let onTap: () -> Void

    var body: some View {
        Button {
            onTap()
        } label: {
            HStack(spacing: 9) {
                CurrencyBadge(currency: currency, fallbackCode: code, size: 34)

                Text(code)
                    .font(.system(size: 18, weight: .semibold, design: .rounded))
                    .foregroundStyle(ConverterTheme.primaryText)
                    .lineLimit(1)

                Image(systemName: "chevron.down")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(ConverterTheme.secondaryText)
            }
            .padding(.horizontal, 11)
            .frame(height: 52)
            .background(ConverterTheme.panelStrong)
            .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .stroke(ConverterTheme.stroke, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

private struct CurrencyBadge: View {
    let currency: CurrencyDescriptor?
    let fallbackCode: String
    let size: CGFloat

    init(currency: CurrencyDescriptor?, fallbackCode: String? = nil, size: CGFloat) {
        self.currency = currency
        self.fallbackCode = fallbackCode ?? currency?.code ?? ""
        self.size = size
    }

    var body: some View {
        Text(badgeText)
            .font(.system(size: badgeFontSize, weight: .semibold, design: .rounded))
            .foregroundStyle(.white)
            .frame(width: size, height: size)
            .background(badgeGradient)
            .clipShape(Circle())
            .overlay(
                Circle()
                    .stroke(Color.white.opacity(0.2), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.18), radius: 6, y: 2)
    }

    private var badgeText: String {
        let code = currency?.code ?? fallbackCode
        if let flag = Self.flags[code] {
            return flag
        }

        if let symbol = currency?.symbol, !symbol.isEmpty, symbol.count <= 3 {
            return symbol
        }

        return String(code.prefix(2))
    }

    private var badgeFontSize: CGFloat {
        badgeText.count == 1 ? size * 0.54 : size * 0.42
    }

    private var badgeGradient: LinearGradient {
        let code = currency?.code ?? fallbackCode
        if currency?.assetKind == .crypto {
            return LinearGradient(
                colors: [Color(red: 1.0, green: 0.64, blue: 0.12), Color(red: 0.93, green: 0.36, blue: 0.08)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }

        let palette = Self.palette(for: code)
        return LinearGradient(colors: palette, startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    private static let flags: [String: String] = [
        "USD": "🇺🇸",
        "EUR": "🇪🇺",
        "GBP": "🇬🇧",
        "JPY": "🇯🇵",
        "CNY": "🇨🇳",
        "CAD": "🇨🇦",
        "AUD": "🇦🇺",
        "CHF": "🇨🇭",
        "NZD": "🇳🇿",
        "HKD": "🇭🇰",
        "SGD": "🇸🇬",
        "KRW": "🇰🇷",
        "INR": "🇮🇳",
        "MXN": "🇲🇽",
        "BRL": "🇧🇷",
        "SEK": "🇸🇪",
        "NOK": "🇳🇴",
        "DKK": "🇩🇰"
    ]

    private static func palette(for code: String) -> [Color] {
        switch abs(code.hashValue) % 5 {
        case 0:
            return [Color(red: 0.19, green: 0.54, blue: 0.96), Color(red: 0.16, green: 0.26, blue: 0.72)]
        case 1:
            return [Color(red: 0.18, green: 0.74, blue: 0.58), Color(red: 0.06, green: 0.4, blue: 0.55)]
        case 2:
            return [Color(red: 0.84, green: 0.26, blue: 0.36), Color(red: 0.44, green: 0.19, blue: 0.7)]
        case 3:
            return [Color(red: 0.91, green: 0.56, blue: 0.18), Color(red: 0.55, green: 0.29, blue: 0.1)]
        default:
            return [Color(red: 0.55, green: 0.45, blue: 0.96), Color(red: 0.16, green: 0.22, blue: 0.64)]
        }
    }
}

// MARK: - Picker Mode

/// Tracks which currency picker (if any) is currently open inline.
private enum PickerMode: Equatable {
    case none
    case source
    case target
}

// MARK: - Menu Bar View

struct MenuBarView: View {
    @ObservedObject var viewModel: CurrencyConversionViewModel
    @State private var pickerMode: PickerMode = .none

    private var refreshKey: String {
        "\(viewModel.sourceCode)->\(viewModel.targetCode)"
    }

    private var sortedCurrencies: [CurrencyDescriptor] {
        viewModel.supportedCurrencies.sorted {
            if $0.assetKind != $1.assetKind {
                return $0.assetKind == .fiat
            }

            return $0.code < $1.code
        }
    }

    var body: some View {
        Group {
            switch pickerMode {
            case .none:
                mainContent
            case .source:
                InlineCurrencyPicker(
                    title: "From Currency",
                    currencies: sortedCurrencies,
                    currentCode: viewModel.sourceCode,
                    onSelect: { code in
                        viewModel.selectSourceCurrency(code: code)
                        pickerMode = .none
                    },
                    onCancel: { pickerMode = .none }
                )
            case .target:
                InlineCurrencyPicker(
                    title: "To Currency",
                    currencies: sortedCurrencies,
                    currentCode: viewModel.targetCode,
                    onSelect: { code in
                        viewModel.selectTargetCurrency(code: code)
                        pickerMode = .none
                    },
                    onCancel: { pickerMode = .none }
                )
            }
        }
        .task(id: refreshKey) {
            viewModel.requestRefresh()
        }
    }

    // MARK: - Main Content

    private var mainContent: some View {
        VStack(alignment: .leading, spacing: 10) {
            header

            ZStack {
                VStack(spacing: 10) {
                    amountPanel
                    resultPanel
                }

                Button {
                    viewModel.swapCurrencies()
                } label: {
                    Image(systemName: "arrow.up.arrow.down")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(ConverterTheme.primaryText)
                        .frame(width: 54, height: 54)
                        .background(
                            Circle()
                                .fill(Color(red: 0.08, green: 0.16, blue: 0.31))
                        )
                        .overlay(
                            Circle()
                                .stroke(ConverterTheme.strokeStrong, lineWidth: 1)
                        )
                        .shadow(color: Color.black.opacity(0.35), radius: 12, y: 4)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Swap currencies")
                .offset(x: 118)
            }

            favoritesSection

            bottomBar
        }
        .padding(14)
        .frame(width: 360, height: 420, alignment: .top)
        .background(converterBackground)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(ConverterTheme.strokeStrong, lineWidth: 1)
        )
    }

    private var header: some View {
        HStack(spacing: 8) {
            Text(updateStatusText)
                .font(.caption.weight(.medium))
                .foregroundStyle(ConverterTheme.secondaryText)
                .lineLimit(1)

            Spacer(minLength: 8)

            Text("Rates via currency-api")
                .font(.caption.weight(.medium))
                .foregroundStyle(ConverterTheme.secondaryText)
                .lineLimit(1)

            Circle()
                .fill(statusColor)
                .frame(width: 8, height: 8)
                .shadow(color: statusColor.opacity(0.45), radius: 4)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
    }

    private var amountPanel: some View {
        conversionPanel {
            VStack(alignment: .leading, spacing: 7) {
                Text("You send")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(ConverterTheme.secondaryText)

                HStack(spacing: 10) {
                    TextField(
                        "0",
                        text: Binding(
                            get: { viewModel.sourceAmountText },
                            set: { viewModel.updateSourceAmount($0) }
                        )
                    )
                    .textFieldStyle(.plain)
                    .font(.system(size: 32, weight: .semibold, design: .rounded))
                    .foregroundStyle(ConverterTheme.primaryText)
                    .lineLimit(1)
                    .padding(.horizontal, 8)
                    .frame(height: 54)
                    .background(Color.black.opacity(0.16))
                    .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 7, style: .continuous)
                            .stroke(ConverterTheme.accent.opacity(0.9), lineWidth: 1)
                    )

                    CurrencyPickerButton(
                        currency: viewModel.sourceCurrency,
                        code: viewModel.sourceCode,
                        onTap: { pickerMode = .source }
                    )
                }
            }
        }
    }

    private var resultPanel: some View {
        conversionPanel {
            VStack(alignment: .leading, spacing: 8) {
                Text("You get approx.")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(ConverterTheme.secondaryText)

                HStack(alignment: .center, spacing: 10) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(viewModel.convertedAmountText)
                            .font(.system(size: 30, weight: .semibold, design: .rounded))
                            .foregroundStyle(ConverterTheme.primaryText)
                            .lineLimit(1)
                            .minimumScaleFactor(0.72)

                        Text(rateSummaryText)
                            .font(.subheadline)
                            .foregroundStyle(summaryColor)
                            .lineLimit(2)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Spacer(minLength: 6)

                    CurrencyPickerButton(
                        currency: viewModel.targetCurrency,
                        code: viewModel.targetCode,
                        onTap: { pickerMode = .target }
                    )
                }
            }
        }
    }

    private func conversionPanel<Content: View>(
        @ViewBuilder content: () -> Content
    ) -> some View {
        content()
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(ConverterTheme.panel)
            .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 11, style: .continuous)
                    .stroke(ConverterTheme.stroke, lineWidth: 1)
            )
    }

    @ViewBuilder
    private var favoritesSection: some View {
        if !viewModel.favoritePairs.isEmpty {
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Text("Favorites")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(ConverterTheme.secondaryText)
                        .textCase(.uppercase)

                    Spacer()

                    Text("\(viewModel.favoritePairs.count)")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(ConverterTheme.secondaryText)
                }
                .padding(.horizontal, 8)
                .padding(.bottom, 7)

                ScrollView {
                    VStack(spacing: 0) {
                        ForEach(sortedFavorites) { pair in
                            FavoritePairRow(
                                pair: pair,
                                sourceCurrency: currency(for: pair.sourceCode),
                                targetCurrency: currency(for: pair.targetCode),
                                isActive: pair.sourceCode == viewModel.sourceCode && pair.targetCode == viewModel.targetCode,
                                onSelect: {
                                    viewModel.selectSourceCurrency(code: pair.sourceCode)
                                    viewModel.selectTargetCurrency(code: pair.targetCode)
                                },
                                onRemove: {
                                    viewModel.removeFavoritePair(pair)
                                }
                            )

                            if pair != sortedFavorites.last {
                                Divider()
                                    .overlay(ConverterTheme.stroke.opacity(0.65))
                                    .padding(.leading, 46)
                            }
                        }
                    }
                }
                .scrollIndicators(.hidden)
                .frame(maxHeight: 158)
                .background(ConverterTheme.panel)
                .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 11, style: .continuous)
                        .stroke(ConverterTheme.stroke, lineWidth: 1)
                )
            }
            .padding(.top, 2)
        }
    }

    private var bottomBar: some View {
        HStack(spacing: 8) {
            Button {
                viewModel.requestRefresh()
            } label: {
                ActionButtonLabel(
                    title: viewModel.isRefreshing ? "Refreshing" : "Refresh Rates",
                    systemImage: "arrow.clockwise",
                    isWorking: viewModel.isRefreshing
                )
            }
            .buttonStyle(.plain)
            .disabled(viewModel.isRefreshing)

            Spacer()

            Button {
                viewModel.toggleCurrentFavoritePair()
            } label: {
                ActionButtonLabel(
                    title: viewModel.isCurrentPairFavorite ? "Favorited" : "Favorite",
                    systemImage: viewModel.isCurrentPairFavorite ? "star.fill" : "star",
                    tint: viewModel.isCurrentPairFavorite ? Color.yellow : ConverterTheme.secondaryText
                )
            }
            .buttonStyle(.plain)

            Button(role: .destructive) {
                NSApplication.shared.terminate(nil)
            } label: {
                Image(systemName: "power")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(ConverterTheme.secondaryText)
                    .frame(width: 32, height: 32)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Quit")
        }
        .padding(.top, 4)
        .padding(.bottom, 2)
        .padding(.horizontal, 4)
    }

    // MARK: - Helpers

    private var sortedFavorites: [FavoriteCurrencyPair] {
        viewModel.favoritePairs.sorted {
            if $0.sourceCode == $1.sourceCode {
                return $0.targetCode < $1.targetCode
            }

            return $0.sourceCode < $1.sourceCode
        }
    }

    private var updateStatusText: String {
        if viewModel.isRefreshing {
            return "Refreshing..."
        }

        if viewModel.isStale {
            return "Cached rate"
        }

        if let updatedAt = viewModel.currentQuote?.updatedAt {
            return "Updated \(updatedAt)"
        }

        if viewModel.refreshErrorMessage != nil {
            return "Rate unavailable"
        }

        return "Ready"
    }

    private var rateSummaryText: String {
        if viewModel.refreshErrorMessage != nil || viewModel.currentQuote == nil {
            return viewModel.conversionSummaryText
        }

        if let separatorIndex = viewModel.conversionSummaryText.firstIndex(of: "|") {
            return String(viewModel.conversionSummaryText[..<separatorIndex])
                .trimmingCharacters(in: .whitespacesAndNewlines)
        }

        return viewModel.conversionSummaryText
    }

    private var statusColor: Color {
        if viewModel.isRefreshing {
            return ConverterTheme.accent
        }

        if viewModel.isStale {
            return ConverterTheme.warning
        }

        if viewModel.refreshErrorMessage != nil {
            return ConverterTheme.danger
        }

        return ConverterTheme.success
    }

    private var summaryColor: Color {
        if viewModel.isStale {
            return ConverterTheme.warning
        }

        if viewModel.refreshErrorMessage != nil {
            return ConverterTheme.danger
        }

        return ConverterTheme.secondaryText
    }

    private func currency(for code: String) -> CurrencyDescriptor? {
        viewModel.supportedCurrencies.first { $0.code == code }
    }
}

// MARK: - Supporting Views

private struct FavoritePairRow: View {
    let pair: FavoriteCurrencyPair
    let sourceCurrency: CurrencyDescriptor?
    let targetCurrency: CurrencyDescriptor?
    let isActive: Bool
    let onSelect: () -> Void
    let onRemove: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Button {
                onSelect()
            } label: {
                HStack(spacing: 9) {
                    Image(systemName: "star.fill")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Color.yellow)
                        .frame(width: 22)

                    CurrencyBadge(currency: sourceCurrency, fallbackCode: pair.sourceCode, size: 25)

                    Text("\(pair.sourceCode) / \(pair.targetCode)")
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                        .foregroundStyle(ConverterTheme.primaryText)

                    Spacer()

                    Text(isActive ? "Current" : "Select")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(isActive ? ConverterTheme.success : ConverterTheme.secondaryText)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Button(role: .destructive) {
                onRemove()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(ConverterTheme.secondaryText.opacity(0.75))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Remove \(pair.sourceCode) to \(pair.targetCode) favorite")
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 9)
        .background(isActive ? ConverterTheme.panelStrong : Color.clear)
    }
}

private struct ActionButtonLabel: View {
    let title: String
    let systemImage: String
    var tint: Color = ConverterTheme.secondaryText
    var isWorking = false

    var body: some View {
        HStack(spacing: 7) {
            if isWorking {
                ProgressView()
                    .controlSize(.small)
                    .tint(tint)
            } else {
                Image(systemName: systemImage)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(tint)
            }

            Text(title)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(ConverterTheme.secondaryText)
        }
        .padding(.horizontal, 7)
        .frame(height: 32)
        .contentShape(Rectangle())
    }
}

private var converterBackground: some View {
    LinearGradient(
        colors: [
            ConverterTheme.backgroundTop,
            Color(red: 0.02, green: 0.09, blue: 0.18),
            ConverterTheme.backgroundBottom
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
}
