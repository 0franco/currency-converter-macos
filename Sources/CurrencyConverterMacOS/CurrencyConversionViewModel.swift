import Combine
import Foundation

public struct CurrencyQuote: Codable, Equatable, Sendable {
    public let sourceCode: String
    public let targetCode: String
    public let rate: Decimal
    public let updatedAt: String?

    public init(sourceCode: String, targetCode: String, rate: Decimal, updatedAt: String? = nil) {
        self.sourceCode = sourceCode.uppercased()
        self.targetCode = targetCode.uppercased()
        self.rate = rate
        self.updatedAt = updatedAt
    }

    public func matches(_ context: CurrencyConversionContext) -> Bool {
        sourceCode == context.sourceCode && targetCode == context.targetCode
    }
}

public enum QuoteLoadResult: Sendable {
    case fresh(CurrencyQuote)
    case stale(CurrencyQuote, warning: String)
}

public enum ExchangeRateProviderError: LocalizedError {
    case invalidURL
    case invalidResponse
    case missingRate(sourceCode: String, targetCode: String)

    public var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Unable to build the exchange rate request."
        case .invalidResponse:
            return "The exchange rate service returned an invalid response."
        case let .missingRate(sourceCode, targetCode):
            return "The exchange rate service did not return a rate for \(sourceCode) to \(targetCode)."
        }
    }
}

public enum LiveExchangeRateProvider {
    private enum API {
        static let apiVersion = "v1"

        static func endpoints(for sourceCode: String) -> [URL] {
            let normalizedSourceCode = sourceCode.lowercased()
            return [
                URL(string: "https://cdn.jsdelivr.net/npm/@fawazahmed0/currency-api@latest/\(apiVersion)/currencies/\(normalizedSourceCode).json"),
                URL(string: "https://latest.currency-api.pages.dev/\(apiVersion)/currencies/\(normalizedSourceCode).json")
            ]
            .compactMap { $0 }
        }
    }

    public static func quote(
        for context: CurrencyConversionContext,
        session: URLSession = .shared,
        retryCount: Int = 2
    ) async throws -> CurrencyQuote {
        if context.sourceCode == context.targetCode {
            return CurrencyQuote(
                sourceCode: context.sourceCode,
                targetCode: context.targetCode,
                rate: Decimal(1)
            )
        }

        let endpoints = API.endpoints(for: context.sourceCode)
        guard !endpoints.isEmpty else {
            throw ExchangeRateProviderError.invalidURL
        }

        var lastError: Error?

        for _ in 0...retryCount {
            for endpoint in endpoints {
                do {
                    let (data, response) = try await session.data(from: endpoint)
                    guard let httpResponse = response as? HTTPURLResponse,
                          200..<300 ~= httpResponse.statusCode else {
                        throw ExchangeRateProviderError.invalidResponse
                    }

                    return try parseQuote(
                        data: data,
                        sourceCode: context.sourceCode,
                        targetCode: context.targetCode
                    )
                } catch {
                    lastError = error
                }
            }
        }

        throw lastError ?? ExchangeRateProviderError.invalidResponse
    }

    private static func parseQuote(
        data: Data,
        sourceCode: String,
        targetCode: String
    ) throws -> CurrencyQuote {
        guard let payload = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw ExchangeRateProviderError.invalidResponse
        }

        let normalizedSourceCode = sourceCode.lowercased()
        let normalizedTargetCode = targetCode.lowercased()

        guard let rates = payload[normalizedSourceCode] as? [String: Any],
              let rawRate = rates[normalizedTargetCode],
              let rate = decimalValue(from: rawRate) else {
            throw ExchangeRateProviderError.missingRate(
                sourceCode: sourceCode,
                targetCode: targetCode
            )
        }

        return CurrencyQuote(
            sourceCode: sourceCode,
            targetCode: targetCode,
            rate: rate,
            updatedAt: payload["date"] as? String
        )
    }

    private static func decimalValue(from rawValue: Any) -> Decimal? {
        if let decimal = rawValue as? Decimal {
            return decimal
        }

        if let number = rawValue as? NSNumber {
            return number.decimalValue
        }

        if let string = rawValue as? String {
            return Decimal(string: string)
        }

        return nil
    }
}

@MainActor
public final class CurrencyConversionViewModel: ObservableObject {
    public typealias QuoteLoader = @Sendable (CurrencyConversionContext) async throws -> QuoteLoadResult

    @Published public private(set) var selectionState: CurrencySelectionState
    @Published public private(set) var sourceCode: String
    @Published public private(set) var targetCode: String
    @Published public private(set) var sourceAmountText: String
    @Published public private(set) var favoritePairs: Set<FavoriteCurrencyPair>
    @Published public private(set) var currentQuote: CurrencyQuote?
    @Published public private(set) var refreshErrorMessage: String?
    @Published public private(set) var isRefreshing = false
    @Published public private(set) var isStale = false

    private let quoteLoader: QuoteLoader
    private let refreshAction: @Sendable () async -> Void
    private let favoritePairsChanged: @Sendable (Set<FavoriteCurrencyPair>) -> Void
    private let decimalSeparator = "."

    public init(
        selectionState: CurrencySelectionState = CurrencySelectionState(),
        sourceAmountText: String = "1.00",
        favoritePairs: Set<FavoriteCurrencyPair> = [],
        currentQuote: CurrencyQuote? = nil,
        quoteLoader: @escaping QuoteLoader = { try await .fresh(LiveExchangeRateProvider.quote(for: $0)) },
        favoritePairsChanged: @escaping @Sendable (Set<FavoriteCurrencyPair>) -> Void = { _ in },
        refreshAction: @escaping @Sendable () async -> Void = {}
    ) {
        self.selectionState = selectionState
        self.sourceCode = selectionState.sourceCode
        self.targetCode = selectionState.targetCode
        self.sourceAmountText = Self.sanitizedAmountText(sourceAmountText)
        self.favoritePairs = favoritePairs
        self.currentQuote = currentQuote
        self.quoteLoader = quoteLoader
        self.favoritePairsChanged = favoritePairsChanged
        self.refreshAction = refreshAction
    }

    public var sourceCurrency: CurrencyDescriptor? {
        selectionState.sourceCurrency
    }

    public var targetCurrency: CurrencyDescriptor? {
        selectionState.targetCurrency
    }

    public var conversionContext: CurrencyConversionContext? {
        selectionState.conversionContext
    }

    public var supportedCurrencies: [CurrencyDescriptor] {
        selectionState.supportedCurrencies
    }

    public var featuredCurrencies: [CurrencyDescriptor] {
        selectionState.featuredCurrencies
    }

    public var parsedAmount: Decimal? {
        Decimal(string: normalizedAmountTextForParsing(sourceAmountText))
    }

    public var convertedAmount: Decimal? {
        guard let amount = parsedAmount,
              let conversionContext,
              let currentQuote,
              currentQuote.matches(conversionContext) else {
            return nil
        }

        return Self.multiply(amount, by: currentQuote.rate)
    }

    public var convertedAmountText: String {
        guard let convertedAmount else {
            return "--"
        }

        return Self.decimalFormatter.string(from: convertedAmount as NSDecimalNumber)
            ?? (convertedAmount as NSDecimalNumber).stringValue
    }

    public var amountValidationMessage: String? {
        guard !sourceAmountText.isEmpty else {
            return "Enter an amount to convert."
        }

        guard parsedAmount != nil else {
            return "Enter a valid numeric amount."
        }

        return nil
    }

    public var conversionSummaryText: String {
        guard let conversionContext else {
            return "Select a currency pair"
        }

        if let amountValidationMessage {
            return amountValidationMessage
        }

        guard let currentQuote, currentQuote.matches(conversionContext) else {
            if let refreshErrorMessage {
                return refreshErrorMessage
            }

            return "Refreshing latest \(conversionContext.sourceCode) -> \(conversionContext.targetCode) rate..."
        }

        let rateText = Self.rateFormatter.string(from: currentQuote.rate as NSDecimalNumber)
            ?? (currentQuote.rate as NSDecimalNumber).stringValue

        if let updatedAt = currentQuote.updatedAt {
            let summary = "1 \(conversionContext.sourceCode) = \(rateText) \(conversionContext.targetCode) | Updated \(updatedAt)"
            return isStale ? "\(summary) (Stale Data)" : summary
        }

        let summary = "1 \(conversionContext.sourceCode) = \(rateText) \(conversionContext.targetCode)"
        return isStale ? "\(summary) (Stale Data)" : summary
    }

    public var currentFavoritePair: FavoriteCurrencyPair? {
        guard let conversionContext else {
            return nil
        }

        return FavoriteCurrencyPair(
            sourceCode: conversionContext.sourceCode,
            targetCode: conversionContext.targetCode
        )
    }

    public var isCurrentPairFavorite: Bool {
        guard let currentFavoritePair else {
            return false
        }

        return favoritePairs.contains(currentFavoritePair)
    }

    public func updateSourceAmount(_ newValue: String) {
        sourceAmountText = Self.sanitizedAmountText(newValue)
    }

    public func selectSourceCurrency(code: String) {
        var updatedSelectionState = selectionState
        updatedSelectionState.selectSourceCurrency(code: code)
        applySelectionState(updatedSelectionState)
    }

    public func selectTargetCurrency(code: String) {
        var updatedSelectionState = selectionState
        updatedSelectionState.selectTargetCurrency(code: code)
        applySelectionState(updatedSelectionState)
    }

    public func swapCurrencies() {
        var updatedSelectionState = selectionState
        updatedSelectionState.swapSelections()
        applySelectionState(updatedSelectionState)
    }

    public func toggleCurrentFavoritePair() {
        guard let currentFavoritePair else {
            return
        }

        if favoritePairs.contains(currentFavoritePair) {
            favoritePairs.remove(currentFavoritePair)
        } else {
            favoritePairs.insert(currentFavoritePair)
        }

        favoritePairsChanged(favoritePairs)
    }

    public func removeFavoritePair(_ pair: FavoriteCurrencyPair) {
        favoritePairs.remove(pair)
        favoritePairsChanged(favoritePairs)
    }

    public func requestRefresh() {
        guard !isRefreshing else {
            return
        }

        isRefreshing = true
        refreshErrorMessage = nil

        Task { [quoteLoader, refreshAction] in
            defer {
                Task { @MainActor in
                    self.isRefreshing = false
                }
            }

            if let conversionContext = await MainActor.run(body: { self.conversionContext }) {
                do {
                    let result = try await quoteLoader(conversionContext)
                    await MainActor.run {
                        switch result {
                        case .fresh(let quote):
                            self.currentQuote = quote
                            self.isStale = false
                        case .stale(let quote, let warning):
                            self.currentQuote = quote
                            self.isStale = true
                            self.refreshErrorMessage = warning
                        }
                    }
                } catch {
                    await MainActor.run {
                        self.refreshErrorMessage = error.localizedDescription
                        self.isStale = false
                    }
                }
            }

            await refreshAction()

            await MainActor.run {
                self.isRefreshing = false
            }
        }
    }

    private func normalizedAmountTextForParsing(_ text: String) -> String {
        if text.hasSuffix(decimalSeparator) {
            return String(text.dropLast())
        }

        return text
    }

    private func applySelectionState(_ updatedSelectionState: CurrencySelectionState) {
        selectionState = updatedSelectionState
        sourceCode = updatedSelectionState.sourceCode
        targetCode = updatedSelectionState.targetCode
        refreshErrorMessage = nil
    }

    private static let decimalFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 4
        formatter.usesGroupingSeparator = true
        return formatter
    }()

    private static let rateFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 6
        formatter.usesGroupingSeparator = false
        return formatter
    }()

    private static func multiply(_ lhs: Decimal, by rhs: Decimal) -> Decimal {
        var lhs = lhs
        var rhs = rhs
        var result = Decimal()
        NSDecimalMultiply(&result, &lhs, &rhs, .bankers)
        return result
    }

    private static func sanitizedAmountText(_ rawValue: String) -> String {
        let normalized = rawValue.replacingOccurrences(of: ",", with: ".")
        var result = ""
        var hasDecimalSeparator = false

        for character in normalized {
            if character.isWholeNumber {
                result.append(character)
                continue
            }

            if character == ".", !hasDecimalSeparator {
                if result.isEmpty {
                    result = "0"
                }

                result.append(character)
                hasDecimalSeparator = true
            }
        }

        return result
    }
}
