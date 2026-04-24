import CurrencyConverterMacOS
import Foundation

@MainActor
final class AppComposition: ObservableObject {
    let viewModel: CurrencyConversionViewModel

    init(
        favoriteStore: FavoriteCurrencyPairStore = FavoriteCurrencyPairStore(),
        quoteCacheStore: QuoteCacheStore = QuoteCacheStore()
    ) {
        let initialFavorites = Set(favoriteStore.loadFavoritePairs())

        viewModel = CurrencyConversionViewModel(
            favoritePairs: initialFavorites,
            quoteLoader: { context in
                do {
                    let quote = try await LiveExchangeRateProvider.quote(for: context)
                    try? quoteCacheStore.saveQuote(quote)
                    return .fresh(quote)
                } catch {
                    let pair = FavoriteCurrencyPair(
                        sourceCode: context.sourceCode,
                        targetCode: context.targetCode
                    )

                    if let cachedQuote = quoteCacheStore.loadQuote(for: pair) {
                        return .stale(
                            cachedQuote,
                            warning: "Using cached exchange rate because the latest quote could not be loaded."
                        )
                    }

                    throw error
                }
            },
            favoritePairsChanged: { favoritePairs in
                let sortedPairs = favoritePairs.sorted {
                    if $0.sourceCode == $1.sourceCode {
                        return $0.targetCode < $1.targetCode
                    }

                    return $0.sourceCode < $1.sourceCode
                }

                try? favoriteStore.saveFavoritePairs(sortedPairs)
            }
        )
    }
}
