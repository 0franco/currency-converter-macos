import Foundation

public struct CurrencyConversionContext: Equatable, Sendable {
    public let sourceCurrency: CurrencyDescriptor
    public let targetCurrency: CurrencyDescriptor

    public var sourceCode: String { sourceCurrency.code }
    public var targetCode: String { targetCurrency.code }

    public init(sourceCurrency: CurrencyDescriptor, targetCurrency: CurrencyDescriptor) {
        self.sourceCurrency = sourceCurrency
        self.targetCurrency = targetCurrency
    }
}

public struct CurrencySelectionState: Sendable {
    public let supportedCurrencies: [CurrencyDescriptor]
    public let featuredCurrencies: [CurrencyDescriptor]

    public private(set) var sourceCode: String
    public private(set) var targetCode: String

    private let currenciesByCode: [String: CurrencyDescriptor]

    public init(catalog: any CurrencyCatalogProviding = CurrencyCatalog.live) {
        let supportedCurrencies = catalog.supportedCurrencies()
        let currenciesByCode = Dictionary(
            uniqueKeysWithValues: supportedCurrencies.map { ($0.code.uppercased(), $0) }
        )
        let featuredCurrencies = catalog.defaultPreselectedCodes.compactMap {
            currenciesByCode[$0.uppercased()]
        }

        self.supportedCurrencies = supportedCurrencies
        self.featuredCurrencies = featuredCurrencies
        self.currenciesByCode = currenciesByCode

        let defaultSelections = Self.resolveDefaultSelections(
            supportedCurrencies: supportedCurrencies,
            defaultPreselectedCodes: catalog.defaultPreselectedCodes
        )
        self.sourceCode = defaultSelections.sourceCode
        self.targetCode = defaultSelections.targetCode
    }

    public var sourceCurrency: CurrencyDescriptor? {
        currenciesByCode[sourceCode]
    }

    public var targetCurrency: CurrencyDescriptor? {
        currenciesByCode[targetCode]
    }

    public var conversionContext: CurrencyConversionContext? {
        guard let sourceCurrency, let targetCurrency else {
            return nil
        }

        return CurrencyConversionContext(
            sourceCurrency: sourceCurrency,
            targetCurrency: targetCurrency
        )
    }

    public mutating func selectSourceCurrency(code: String) {
        guard let normalizedCode = normalizedCode(for: code) else {
            return
        }

        sourceCode = normalizedCode
    }

    public mutating func selectTargetCurrency(code: String) {
        guard let normalizedCode = normalizedCode(for: code) else {
            return
        }

        targetCode = normalizedCode
    }

    public mutating func swapSelections() {
        let previousSourceCode = sourceCode
        sourceCode = targetCode
        targetCode = previousSourceCode
    }

    private func normalizedCode(for code: String) -> String? {
        let normalizedCode = code.uppercased()
        guard currenciesByCode[normalizedCode] != nil else {
            return nil
        }

        return normalizedCode
    }

    private static func resolveDefaultSelections(
        supportedCurrencies: [CurrencyDescriptor],
        defaultPreselectedCodes: [String]
    ) -> (sourceCode: String, targetCode: String) {
        let supportedCodes = Set(supportedCurrencies.map(\.code))
        let defaults = defaultPreselectedCodes
            .map { $0.uppercased() }
            .filter { supportedCodes.contains($0) }

        if defaults.count >= 2 {
            return (defaults[0], defaults[1])
        }

        if let onlyDefault = defaults.first,
           let firstAlternative = supportedCurrencies.map(\.code).first(where: { $0 != onlyDefault }) {
            return (onlyDefault, firstAlternative)
        }

        let fallbackCodes = supportedCurrencies.map(\.code)

        switch fallbackCodes.count {
        case let count where count >= 2:
            return (fallbackCodes[0], fallbackCodes[1])
        case 1:
            return (fallbackCodes[0], fallbackCodes[0])
        default:
            return ("USD", "EUR")
        }
    }
}
