import Foundation

public struct CurrencyDescriptor: Codable, Hashable, Identifiable, Sendable {
    public let code: String
    public let displayName: String
    public let symbol: String?

    public var id: String { code }

    public init(code: String, displayName: String, symbol: String?) {
        self.code = code
        self.displayName = displayName
        self.symbol = symbol
    }
}

public protocol CurrencyCatalogProviding: Sendable {
    var defaultPreselectedCodes: [String] { get }

    func supportedCurrencies() -> [CurrencyDescriptor]
    func currency(for code: String) -> CurrencyDescriptor?
}

public struct CurrencyCatalogService: CurrencyCatalogProviding, Sendable {
    public static let live = CurrencyCatalogService()

    public let defaultPreselectedCodes: [String]

    private let currencies: [CurrencyDescriptor]
    private let currenciesByCode: [String: CurrencyDescriptor]

    public init(
        defaultPreselectedCodes: [String] = ["USD", "EUR", "CNY"],
        currencies: [CurrencyDescriptor]? = nil
    ) {
        self.defaultPreselectedCodes = defaultPreselectedCodes.map { $0.uppercased() }

        let resolvedCurrencies = currencies ?? Self.buildSupportedCurrencies(
            defaultPreselectedCodes: self.defaultPreselectedCodes
        )

        self.currencies = resolvedCurrencies
        self.currenciesByCode = Dictionary(
            uniqueKeysWithValues: resolvedCurrencies.map { ($0.code.uppercased(), $0) }
        )
    }

    public func supportedCurrencies() -> [CurrencyDescriptor] {
        currencies
    }

    public func currency(for code: String) -> CurrencyDescriptor? {
        currenciesByCode[code.uppercased()]
    }

    private static func buildSupportedCurrencies(
        defaultPreselectedCodes: [String]
    ) -> [CurrencyDescriptor] {
        let locale = Locale(identifier: "en_US_POSIX")

        let currencies = Locale.commonISOCurrencyCodes
            .map { $0.uppercased() }
            .compactMap { code -> CurrencyDescriptor? in
                guard let displayName = locale.localizedString(forCurrencyCode: code)?
                    .trimmingCharacters(in: .whitespacesAndNewlines),
                      !displayName.isEmpty else {
                    return nil
                }

                return CurrencyDescriptor(
                    code: code,
                    displayName: displayName,
                    symbol: symbol(for: code, locale: locale)
                )
            }

        return currencies.sorted {
            sortCurrencies(
                lhs: $0,
                rhs: $1,
                defaultPreselectedCodes: defaultPreselectedCodes
            )
        }
    }

    private static func sortCurrencies(
        lhs: CurrencyDescriptor,
        rhs: CurrencyDescriptor,
        defaultPreselectedCodes: [String]
    ) -> Bool {
        let lhsDefaultIndex = defaultPreselectedCodes.firstIndex(of: lhs.code)
        let rhsDefaultIndex = defaultPreselectedCodes.firstIndex(of: rhs.code)

        switch (lhsDefaultIndex, rhsDefaultIndex) {
        case let (lhsIndex?, rhsIndex?):
            return lhsIndex < rhsIndex
        case (_?, nil):
            return true
        case (nil, _?):
            return false
        case (nil, nil):
            let nameComparison = lhs.displayName.localizedCaseInsensitiveCompare(rhs.displayName)
            if nameComparison != .orderedSame {
                return nameComparison == .orderedAscending
            }

            return lhs.code < rhs.code
        }
    }

    private static func symbol(for code: String, locale: Locale) -> String? {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = locale
        formatter.currencyCode = code

        guard let rawSymbol = formatter.currencySymbol?
            .trimmingCharacters(in: .whitespacesAndNewlines),
              !rawSymbol.isEmpty,
              rawSymbol.caseInsensitiveCompare(code) != .orderedSame else {
            return nil
        }

        return rawSymbol
    }
}

public enum CurrencyCatalog {
    public static let live: any CurrencyCatalogProviding = CurrencyCatalogService.live

    public static var defaultPreselectedCodes: [String] {
        live.defaultPreselectedCodes
    }

    public static var supportedCurrencies: [CurrencyDescriptor] {
        live.supportedCurrencies()
    }

    public static func currency(for code: String) -> CurrencyDescriptor? {
        live.currency(for: code)
    }
}
