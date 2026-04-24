import CurrencyConverterMacOS
import SwiftUI

struct MenuBarView: View {
    @ObservedObject var viewModel: CurrencyConversionViewModel

    private var refreshKey: String {
        "\(viewModel.sourceCode)->\(viewModel.targetCode)"
    }

    var body: some View {
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
                currencyPicker(
                    title: "From",
                    selection: Binding(
                        get: { viewModel.sourceCode },
                        set: { viewModel.selectSourceCurrency(code: $0) }
                    )
                )

                Button {
                    viewModel.swapCurrencies()
                } label: {
                    Image(systemName: "arrow.left.arrow.right")
                }
                .buttonStyle(.bordered)
                .accessibilityLabel("Swap currencies")

                currencyPicker(
                    title: "To",
                    selection: Binding(
                        get: { viewModel.targetCode },
                        set: { viewModel.selectTargetCurrency(code: $0) }
                    )
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
        .task(id: refreshKey) {
            viewModel.requestRefresh()
        }
    }

    private var sortedFavorites: [FavoriteCurrencyPair] {
        viewModel.favoritePairs.sorted {
            if $0.sourceCode == $1.sourceCode {
                return $0.targetCode < $1.targetCode
            }

            return $0.sourceCode < $1.sourceCode
        }
    }

    private func currencyPicker(title: String, selection: Binding<String>) -> some View {
        Picker(title, selection: selection) {
            ForEach(viewModel.supportedCurrencies) { currency in
                Text(label(for: currency)).tag(currency.code)
            }
        }
        .pickerStyle(.menu)
        .frame(maxWidth: .infinity)
    }

    private func label(for currency: CurrencyDescriptor) -> String {
        if let symbol = currency.symbol, !symbol.isEmpty {
            return "\(currency.code) \(symbol)"
        }

        return currency.code
    }
}
