import CurrencyConverterMacOS
import SwiftUI

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
    @FocusState private var searchFocused: Bool

    private var filtered: [CurrencyDescriptor] {
        guard !searchText.isEmpty else { return currencies }
        return currencies.filter {
            $0.code.localizedCaseInsensitiveContains(searchText) ||
            $0.displayName.localizedCaseInsensitiveContains(searchText) ||
            ($0.symbol?.localizedCaseInsensitiveContains(searchText) ?? false)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header with back button
            HStack {
                Button {
                    onCancel()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                        Text("Back")
                    }
                }
                .buttonStyle(.plain)

                Spacer()

                Text(title)
                    .font(.headline)

                Spacer()

                // Invisible spacer to balance the back button
                Text("Back")
                    .hidden()
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)

            // Search field
            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                    .font(.caption)
                TextField("Search currency…", text: $searchText)
                    .textFieldStyle(.plain)
                    .focused($searchFocused)
                    .font(.body)
                if !searchText.isEmpty {
                    Button {
                        searchText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color(nsColor: .controlBackgroundColor))
            .cornerRadius(6)
            .padding(.horizontal, 14)
            .padding(.bottom, 8)

            Divider()

            // Results
            if filtered.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .font(.title2)
                        .foregroundColor(.secondary)
                    Text("No currencies found")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, minHeight: 200)
            } else {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            ForEach(filtered) { currency in
                                Button {
                                    onSelect(currency.code)
                                } label: {
                                    HStack(spacing: 10) {
                                        Text(currency.code)
                                            .font(.body.weight(.semibold))
                                            .frame(width: 44, alignment: .leading)
                                        VStack(alignment: .leading, spacing: 1) {
                                            Text(currency.displayName)
                                                .font(.body)
                                                .lineLimit(1)
                                            if let symbol = currency.symbol, !symbol.isEmpty {
                                                Text(symbol)
                                                    .font(.caption)
                                                    .foregroundColor(.secondary)
                                            }
                                        }
                                        Spacer()
                                        if currency.code == currentCode {
                                            Image(systemName: "checkmark")
                                                .font(.body.weight(.semibold))
                                                .foregroundColor(.accentColor)
                                        }
                                    }
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 8)
                                    .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                                .id(currency.code)

                                if currency.code != filtered.last?.code {
                                    Divider()
                                        .padding(.leading, 68)
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
        .onAppear { searchFocused = true }
    }
}

// MARK: - Currency Picker Button

/// A button that displays the current currency selection.
/// Tapping it triggers the `onTap` callback to switch to the inline picker.
private struct CurrencyPickerButton: View {
    let title: String
    let code: String
    let symbol: String?
    let onTap: () -> Void

    var body: some View {
        Button {
            onTap()
        } label: {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption)
                    .foregroundColor(.secondary)
                HStack(spacing: 4) {
                    Text(code)
                        .font(.body.weight(.medium))
                    if let sym = symbol, !sym.isEmpty {
                        Text(sym)
                            .font(.body)
                            .foregroundColor(.secondary)
                    }
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(Color(nsColor: .controlBackgroundColor))
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color(nsColor: .separatorColor), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
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
        viewModel.supportedCurrencies.sorted { $0.code < $1.code }
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
        VStack(alignment: .leading, spacing: 12) {
            Text("Currency Converter")
                .font(.headline)

            TextField(
                "Amount",
                text: Binding(
                    get: { viewModel.sourceAmountText },
                    set: { viewModel.updateSourceAmount($0) }
                )
            )
            .textFieldStyle(.roundedBorder)

            HStack(spacing: 8) {
                CurrencyPickerButton(
                    title: "From",
                    code: viewModel.sourceCode,
                    symbol: currencySymbol(for: viewModel.sourceCode),
                    onTap: { pickerMode = .source }
                )

                Button {
                    viewModel.swapCurrencies()
                } label: {
                    Image(systemName: "arrow.left.arrow.right")
                }
                .buttonStyle(.bordered)
                .accessibilityLabel("Swap currencies")

                CurrencyPickerButton(
                    title: "To",
                    code: viewModel.targetCode,
                    symbol: currencySymbol(for: viewModel.targetCode),
                    onTap: { pickerMode = .target }
                )
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(viewModel.convertedAmountText)
                    .font(.system(size: 24, weight: .semibold, design: .rounded))

                Text(viewModel.conversionSummaryText)
                    .font(.footnote)
                    .foregroundStyle(viewModel.isStale ? .orange : .secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            HStack(spacing: 8) {
                Button {
                    viewModel.requestRefresh()
                } label: {
                    if viewModel.isRefreshing {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        Label("Refresh", systemImage: "arrow.clockwise")
                    }
                }
                .buttonStyle(.bordered)

                Button {
                    viewModel.toggleCurrentFavoritePair()
                } label: {
                    Label(
                        viewModel.isCurrentPairFavorite ? "Unfavorite" : "Favorite",
                        systemImage: viewModel.isCurrentPairFavorite ? "star.fill" : "star"
                    )
                }
                .buttonStyle(.bordered)
            }

            if !viewModel.favoritePairs.isEmpty {
                Divider()

                Text("Favorites")
                    .font(.subheadline.weight(.medium))

                ForEach(sortedFavorites) { pair in
                    HStack(spacing: 8) {
                        Button {
                            viewModel.selectSourceCurrency(code: pair.sourceCode)
                            viewModel.selectTargetCurrency(code: pair.targetCode)
                        } label: {
                            Text("\(pair.sourceCode) -> \(pair.targetCode)")
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .buttonStyle(.plain)

                        Button(role: .destructive) {
                            viewModel.removeFavoritePair(pair)
                        } label: {
                            Image(systemName: "trash")
                        }
                        .buttonStyle(.borderless)
                    }
                }
            }

            Divider()

            Button(role: .destructive) {
                NSApplication.shared.terminate(nil)
            } label: {
                Label("Quit", systemImage: "power")
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.plain)
        }
        .padding(14)
        .frame(width: 360)
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

    private func currencySymbol(for code: String) -> String? {
        viewModel.supportedCurrencies.first { $0.code == code }?.symbol
    }
}
