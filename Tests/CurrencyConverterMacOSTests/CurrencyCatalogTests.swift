import XCTest
@testable import CurrencyConverterMacOS

actor RefreshCounter {
    private(set) var count = 0

    func increment() {
        count += 1
    }
}

actor RefreshGate {
    private var continuation: CheckedContinuation<Void, Never>?

    func wait() async {
        await withCheckedContinuation { continuation in
            self.continuation = continuation
        }
    }

    func release() {
        continuation?.resume()
        continuation = nil
    }
}

final class CurrencyCatalogTests: XCTestCase {
    func testLiveServiceUsesExpectedPreselectedDefaults() {
        let service = CurrencyCatalogService.live

        XCTAssertEqual(service.defaultPreselectedCodes, ["USD", "EUR", "CNY"])
    }

    func testSupportedCurrenciesContainRequiredDefaults() {
        let supportedCodes = Set(CurrencyCatalogService.live.supportedCurrencies().map(\.code))

        XCTAssertTrue(supportedCodes.contains("USD"))
        XCTAssertTrue(supportedCodes.contains("EUR"))
        XCTAssertTrue(supportedCodes.contains("CNY"))
    }

    func testSupportedCurrenciesUseUniqueCodesAndNames() {
        let currencies = CurrencyCatalogService.live.supportedCurrencies()
        let uniqueCodes = Set(currencies.map(\.code))

        XCTAssertFalse(currencies.isEmpty)
        XCTAssertEqual(uniqueCodes.count, currencies.count)
        XCTAssertTrue(currencies.allSatisfy { !$0.displayName.isEmpty })
    }

    func testDefaultsAreOrderedFirstForMenuPresentation() {
        let firstThreeCodes = Array(CurrencyCatalogService.live.supportedCurrencies().prefix(3).map(\.code))

        XCTAssertEqual(firstThreeCodes, CurrencyCatalogService.live.defaultPreselectedCodes)
    }

    func testCatalogCoversBroadFiatCurrencySelection() {
        XCTAssertGreaterThanOrEqual(CurrencyCatalogService.live.supportedCurrencies().count, 100)
    }

    func testCurrencyLookupIsCaseInsensitive() {
        let currency = CurrencyCatalogService.live.currency(for: "usd")

        XCTAssertEqual(currency?.code, "USD")
    }

    func testServiceCanBeConstructedWithCustomCatalogForAppInjection() {
        let injectedCurrencies = [
            CurrencyDescriptor(code: "BRL", displayName: "Brazilian Real", symbol: "R$"),
            CurrencyDescriptor(code: "JPY", displayName: "Japanese Yen", symbol: "¥")
        ]
        let service = CurrencyCatalogService(
            defaultPreselectedCodes: ["JPY"],
            currencies: injectedCurrencies
        )

        XCTAssertEqual(service.defaultPreselectedCodes, ["JPY"])
        XCTAssertEqual(service.supportedCurrencies(), injectedCurrencies)
        XCTAssertEqual(service.currency(for: "brl")?.displayName, "Brazilian Real")
    }

    func testSelectionStateUsesSharedSupportedCurrencyList() {
        let injectedCurrencies = [
            CurrencyDescriptor(code: "USD", displayName: "US Dollar", symbol: "$"),
            CurrencyDescriptor(code: "EUR", displayName: "Euro", symbol: "€"),
            CurrencyDescriptor(code: "CNY", displayName: "Chinese Yuan", symbol: "¥")
        ]
        let service = CurrencyCatalogService(
            defaultPreselectedCodes: ["USD", "EUR", "CNY"],
            currencies: injectedCurrencies
        )

        let selectionState = CurrencySelectionState(catalog: service)

        XCTAssertEqual(selectionState.supportedCurrencies, injectedCurrencies)
        XCTAssertEqual(selectionState.featuredCurrencies.map(\.code), ["USD", "EUR", "CNY"])
    }

    func testSelectionStateUsesFirstTwoDefaultsForInitialPickerSelections() {
        let selectionState = CurrencySelectionState(catalog: CurrencyCatalogService.live)

        XCTAssertEqual(selectionState.sourceCode, "USD")
        XCTAssertEqual(selectionState.targetCode, "EUR")
    }

    func testSelectionStateIgnoresUnsupportedPickerSelections() {
        let injectedCurrencies = [
            CurrencyDescriptor(code: "USD", displayName: "US Dollar", symbol: "$"),
            CurrencyDescriptor(code: "EUR", displayName: "Euro", symbol: "€")
        ]
        let service = CurrencyCatalogService(
            defaultPreselectedCodes: ["USD", "EUR"],
            currencies: injectedCurrencies
        )
        var selectionState = CurrencySelectionState(catalog: service)

        selectionState.selectSourceCurrency(code: "AUD")
        selectionState.selectTargetCurrency(code: "cad")

        XCTAssertEqual(selectionState.sourceCode, "USD")
        XCTAssertEqual(selectionState.targetCode, "EUR")
    }

    func testSelectionStateAllowsValidPickerUpdatesCaseInsensitively() {
        let injectedCurrencies = [
            CurrencyDescriptor(code: "USD", displayName: "US Dollar", symbol: "$"),
            CurrencyDescriptor(code: "EUR", displayName: "Euro", symbol: "€"),
            CurrencyDescriptor(code: "JPY", displayName: "Japanese Yen", symbol: "¥")
        ]
        let service = CurrencyCatalogService(
            defaultPreselectedCodes: ["USD", "EUR"],
            currencies: injectedCurrencies
        )
        var selectionState = CurrencySelectionState(catalog: service)

        selectionState.selectSourceCurrency(code: "jpy")
        selectionState.selectTargetCurrency(code: "usd")

        XCTAssertEqual(selectionState.sourceCurrency?.code, "JPY")
        XCTAssertEqual(selectionState.targetCurrency?.code, "USD")
    }

    func testSelectionStateAllowsSourceSelectionFromAnySupportedCurrency() {
        let supportedCurrencies = CurrencyCatalogService.live.supportedCurrencies()
        let service = CurrencyCatalogService(
            defaultPreselectedCodes: ["USD", "EUR", "CNY"],
            currencies: supportedCurrencies
        )
        var selectionState = CurrencySelectionState(catalog: service)

        guard let audCurrency = supportedCurrencies.first(where: { $0.code == "AUD" }) else {
            return XCTFail("Expected AUD to be present in the supported currency list.")
        }

        selectionState.selectSourceCurrency(code: audCurrency.code)

        XCTAssertEqual(selectionState.sourceCode, "AUD")
        XCTAssertEqual(selectionState.sourceCurrency, audCurrency)
    }

    func testSelectionStateCanSwapSourceAndTargetCurrencies() {
        var selectionState = CurrencySelectionState(catalog: CurrencyCatalogService.live)

        selectionState.swapSelections()

        XCTAssertEqual(selectionState.sourceCode, "EUR")
        XCTAssertEqual(selectionState.targetCode, "USD")
    }

    func testSelectionStateUpdatesConversionContextWhenTargetSelectionChanges() {
        let injectedCurrencies = [
            CurrencyDescriptor(code: "USD", displayName: "US Dollar", symbol: "$"),
            CurrencyDescriptor(code: "EUR", displayName: "Euro", symbol: "€"),
            CurrencyDescriptor(code: "JPY", displayName: "Japanese Yen", symbol: "¥")
        ]
        let service = CurrencyCatalogService(
            defaultPreselectedCodes: ["USD", "EUR"],
            currencies: injectedCurrencies
        )
        var selectionState = CurrencySelectionState(catalog: service)

        selectionState.selectTargetCurrency(code: "jpy")

        XCTAssertEqual(selectionState.conversionContext?.sourceCode, "USD")
        XCTAssertEqual(selectionState.conversionContext?.targetCode, "JPY")
        XCTAssertEqual(selectionState.sourceCode, "USD")
    }

    func testFavoriteCurrencyPairNormalizesCodesToUppercase() {
        let pair = FavoriteCurrencyPair(sourceCode: "usd", targetCode: "eur")

        XCTAssertEqual(pair.sourceCode, "USD")
        XCTAssertEqual(pair.targetCode, "EUR")
        XCTAssertEqual(pair.id, "USD->EUR")
    }

    @MainActor
    func testConversionViewModelSanitizesAmountInput() {
        let viewModel = CurrencyConversionViewModel(sourceAmountText: "1.00")

        viewModel.updateSourceAmount("ab.12.3c")

        XCTAssertEqual(viewModel.sourceAmountText, "0.123")
        XCTAssertEqual(viewModel.parsedAmount, Decimal(string: "0.123"))
        XCTAssertNil(viewModel.amountValidationMessage)
    }

    @MainActor
    func testConversionViewModelAcceptsUserEnteredNumericAmount() {
        let viewModel = CurrencyConversionViewModel(sourceAmountText: "1.00")

        viewModel.updateSourceAmount("9876.54")

        XCTAssertEqual(viewModel.sourceAmountText, "9876.54")
        XCTAssertEqual(viewModel.parsedAmount, Decimal(string: "9876.54"))
        XCTAssertNil(viewModel.amountValidationMessage)
    }

    @MainActor
    func testConversionViewModelNormalizesCommaSeparatedNumericAmount() {
        let viewModel = CurrencyConversionViewModel(sourceAmountText: "1.00")

        viewModel.updateSourceAmount("12,34")

        XCTAssertEqual(viewModel.sourceAmountText, "12.34")
        XCTAssertEqual(viewModel.parsedAmount, Decimal(string: "12.34"))
        XCTAssertNil(viewModel.amountValidationMessage)
    }

    @MainActor
    func testConversionViewModelFlagsEmptyAmount() {
        let viewModel = CurrencyConversionViewModel(sourceAmountText: "1.00")

        viewModel.updateSourceAmount("")

        XCTAssertEqual(viewModel.amountValidationMessage, "Enter an amount to convert.")
    }

    @MainActor
    func testConversionViewModelUpdatesSelectionsAndSwapsPair() {
        let injectedCurrencies = [
            CurrencyDescriptor(code: "USD", displayName: "US Dollar", symbol: "$"),
            CurrencyDescriptor(code: "EUR", displayName: "Euro", symbol: "€"),
            CurrencyDescriptor(code: "CNY", displayName: "Chinese Yuan", symbol: "¥")
        ]
        let selectionState = CurrencySelectionState(
            catalog: CurrencyCatalogService(
                defaultPreselectedCodes: ["USD", "EUR", "CNY"],
                currencies: injectedCurrencies
            )
        )
        let viewModel = CurrencyConversionViewModel(selectionState: selectionState)

        viewModel.selectTargetCurrency(code: "cny")
        viewModel.swapCurrencies()

        XCTAssertEqual(viewModel.sourceCode, "CNY")
        XCTAssertEqual(viewModel.targetCode, "USD")
    }

    @MainActor
    func testConversionViewModelExposesTargetPickerCurrenciesFromSharedCatalog() {
        let injectedCurrencies = [
            CurrencyDescriptor(code: "USD", displayName: "US Dollar", symbol: "$"),
            CurrencyDescriptor(code: "EUR", displayName: "Euro", symbol: "€"),
            CurrencyDescriptor(code: "JPY", displayName: "Japanese Yen", symbol: "¥")
        ]
        let viewModel = CurrencyConversionViewModel(
            selectionState: CurrencySelectionState(
                catalog: CurrencyCatalogService(
                    defaultPreselectedCodes: ["USD", "EUR"],
                    currencies: injectedCurrencies
                )
            )
        )

        XCTAssertEqual(viewModel.supportedCurrencies, injectedCurrencies)
        XCTAssertEqual(viewModel.targetCurrency?.code, "EUR")
    }

    @MainActor
    func testConversionViewModelAllowsTargetSelectionFromSharedCatalog() {
        let injectedCurrencies = [
            CurrencyDescriptor(code: "USD", displayName: "US Dollar", symbol: "$"),
            CurrencyDescriptor(code: "EUR", displayName: "Euro", symbol: "€"),
            CurrencyDescriptor(code: "JPY", displayName: "Japanese Yen", symbol: "¥")
        ]
        let viewModel = CurrencyConversionViewModel(
            selectionState: CurrencySelectionState(
                catalog: CurrencyCatalogService(
                    defaultPreselectedCodes: ["USD", "EUR"],
                    currencies: injectedCurrencies
                )
            )
        )

        viewModel.selectTargetCurrency(code: "jpy")

        XCTAssertEqual(viewModel.targetCode, "JPY")
        XCTAssertEqual(viewModel.targetCurrency?.displayName, "Japanese Yen")
    }

    @MainActor
    func testConversionViewModelKeepsTargetSelectionIndependentFromSourceSelection() {
        let injectedCurrencies = [
            CurrencyDescriptor(code: "USD", displayName: "US Dollar", symbol: "$"),
            CurrencyDescriptor(code: "EUR", displayName: "Euro", symbol: "€"),
            CurrencyDescriptor(code: "JPY", displayName: "Japanese Yen", symbol: "¥")
        ]
        let viewModel = CurrencyConversionViewModel(
            selectionState: CurrencySelectionState(
                catalog: CurrencyCatalogService(
                    defaultPreselectedCodes: ["USD", "EUR"],
                    currencies: injectedCurrencies
                )
            )
        )

        viewModel.selectTargetCurrency(code: "jpy")
        viewModel.selectSourceCurrency(code: "eur")

        XCTAssertEqual(viewModel.sourceCode, "EUR")
        XCTAssertEqual(viewModel.targetCode, "JPY")
        XCTAssertEqual(viewModel.selectionState.sourceCode, "EUR")
        XCTAssertEqual(viewModel.selectionState.targetCode, "JPY")
    }

    @MainActor
    func testConversionViewModelUpdatesConversionContextWhenTargetSelectionChanges() {
        let injectedCurrencies = [
            CurrencyDescriptor(code: "USD", displayName: "US Dollar", symbol: "$"),
            CurrencyDescriptor(code: "EUR", displayName: "Euro", symbol: "€"),
            CurrencyDescriptor(code: "JPY", displayName: "Japanese Yen", symbol: "¥")
        ]
        let viewModel = CurrencyConversionViewModel(
            selectionState: CurrencySelectionState(
                catalog: CurrencyCatalogService(
                    defaultPreselectedCodes: ["USD", "EUR"],
                    currencies: injectedCurrencies
                )
            )
        )

        viewModel.selectTargetCurrency(code: "jpy")

        XCTAssertEqual(viewModel.conversionContext?.sourceCode, "USD")
        XCTAssertEqual(viewModel.conversionContext?.targetCode, "JPY")
        XCTAssertEqual(viewModel.sourceCode, "USD")
    }

    @MainActor
    func testConversionViewModelKeepsSourceSelectionIndependentFromTargetSelection() {
        let injectedCurrencies = [
            CurrencyDescriptor(code: "USD", displayName: "US Dollar", symbol: "$"),
            CurrencyDescriptor(code: "EUR", displayName: "Euro", symbol: "€"),
            CurrencyDescriptor(code: "JPY", displayName: "Japanese Yen", symbol: "¥")
        ]
        let viewModel = CurrencyConversionViewModel(
            selectionState: CurrencySelectionState(
                catalog: CurrencyCatalogService(
                    defaultPreselectedCodes: ["USD", "EUR"],
                    currencies: injectedCurrencies
                )
            )
        )

        viewModel.selectSourceCurrency(code: "jpy")
        viewModel.selectTargetCurrency(code: "usd")

        XCTAssertEqual(viewModel.sourceCode, "JPY")
        XCTAssertEqual(viewModel.targetCode, "USD")
        XCTAssertEqual(viewModel.selectionState.sourceCode, "JPY")
        XCTAssertEqual(viewModel.selectionState.targetCode, "USD")
    }

    @MainActor
    func testConversionViewModelExposesSourceShortcutsFromDefaultFeaturedCurrencies() {
        let featuredCodes = CurrencyConversionViewModel().featuredCurrencies.map(\.code)

        XCTAssertEqual(featuredCodes, ["USD", "EUR", "CNY"])
    }

    @MainActor
    func testConversionViewModelMarksCurrentSelectionAsFavorite() {
        let viewModel = CurrencyConversionViewModel()

        viewModel.toggleCurrentFavoritePair()

        XCTAssertTrue(viewModel.isCurrentPairFavorite)
        XCTAssertEqual(
            viewModel.favoritePairs,
            [FavoriteCurrencyPair(sourceCode: "USD", targetCode: "EUR")]
        )
    }

    @MainActor
    func testConversionViewModelRemovesExistingFavoriteWhenToggledAgain() {
        let viewModel = CurrencyConversionViewModel(
            favoritePairs: [FavoriteCurrencyPair(sourceCode: "USD", targetCode: "EUR")]
        )

        viewModel.toggleCurrentFavoritePair()

        XCTAssertFalse(viewModel.isCurrentPairFavorite)
        XCTAssertTrue(viewModel.favoritePairs.isEmpty)
    }

    @MainActor
    func testConversionViewModelFavoriteStateTracksCurrentlySelectedPair() {
        let viewModel = CurrencyConversionViewModel(
            favoritePairs: [FavoriteCurrencyPair(sourceCode: "USD", targetCode: "EUR")]
        )

        XCTAssertTrue(viewModel.isCurrentPairFavorite)

        viewModel.selectTargetCurrency(code: "cny")

        XCTAssertFalse(viewModel.isCurrentPairFavorite)
        XCTAssertEqual(
            viewModel.currentFavoritePair,
            FavoriteCurrencyPair(sourceCode: "USD", targetCode: "CNY")
        )
    }

    @MainActor
    func testConversionViewModelCalculatesConvertedAmountFromMatchingQuote() {
        let viewModel = CurrencyConversionViewModel(
            sourceAmountText: "12.50",
            currentQuote: CurrencyQuote(
                sourceCode: "USD",
                targetCode: "EUR",
                rate: Decimal(string: "0.92")!,
                updatedAt: "2026-04-24"
            )
        )

        XCTAssertEqual(viewModel.convertedAmount, Decimal(string: "11.50"))
        XCTAssertEqual(viewModel.convertedAmountText, "11.50")
        XCTAssertEqual(
            viewModel.conversionSummaryText,
            "1 USD = 0.92 EUR | Updated 2026-04-24"
        )
    }

    @MainActor
    func testConversionViewModelHidesStaleQuoteWhenSelectedPairChanges() {
        let viewModel = CurrencyConversionViewModel(
            currentQuote: CurrencyQuote(
                sourceCode: "USD",
                targetCode: "EUR",
                rate: Decimal(string: "0.92")!
            )
        )

        viewModel.selectTargetCurrency(code: "cny")

        XCTAssertNil(viewModel.convertedAmount)
        XCTAssertEqual(viewModel.convertedAmountText, "--")
        XCTAssertEqual(
            viewModel.conversionSummaryText,
            "Refreshing latest USD -> CNY rate..."
        )
    }

    @MainActor
    func testConversionViewModelRefreshLoadsQuoteForCurrentPair() async {
        let started = expectation(description: "refresh completed")

        let viewModel = CurrencyConversionViewModel(
            sourceAmountText: "10",
            quoteLoader: { context in
                XCTAssertEqual(context.sourceCode, "USD")
                XCTAssertEqual(context.targetCode, "EUR")
                started.fulfill()
                return CurrencyQuote(
                    sourceCode: context.sourceCode,
                    targetCode: context.targetCode,
                    rate: Decimal(string: "0.80")!,
                    updatedAt: "2026-04-24"
                )
            }
        )

        viewModel.requestRefresh()
        await fulfillment(of: [started], timeout: 1.0)

        let deadline = Date().addingTimeInterval(1.0)
        while viewModel.isRefreshing, Date() < deadline {
            await Task.yield()
        }

        XCTAssertEqual(viewModel.convertedAmountText, "8.00")
        XCTAssertNil(viewModel.refreshErrorMessage)
    }

    @MainActor
    func testConversionViewModelRunsRefreshActionOnceWhileRefreshing() async {
        let started = expectation(description: "refresh started")
        let counter = RefreshCounter()
        let gate = RefreshGate()

        let viewModel = CurrencyConversionViewModel(
            quoteLoader: { _ in
                CurrencyQuote(sourceCode: "USD", targetCode: "EUR", rate: Decimal(1))
            },
            refreshAction: {
            await counter.increment()
            started.fulfill()
            await gate.wait()
        })

        viewModel.requestRefresh()
        await fulfillment(of: [started], timeout: 1.0)
        XCTAssertTrue(viewModel.isRefreshing)

        viewModel.requestRefresh()
        XCTAssertEqual(await counter.count, 1)

        await gate.release()

        let deadline = Date().addingTimeInterval(1.0)
        while viewModel.isRefreshing, Date() < deadline {
            await Task.yield()
        }

        XCTAssertFalse(viewModel.isRefreshing)
        XCTAssertEqual(await counter.count, 1)
    }
}
