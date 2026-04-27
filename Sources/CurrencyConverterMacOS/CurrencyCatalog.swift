import Foundation

public enum CurrencyAssetKind: String, Codable, Sendable {
    case fiat
    case crypto
}

public struct CurrencyDescriptor: Codable, Hashable, Identifiable, Sendable {
    public let code: String
    public let displayName: String
    public let symbol: String?
    public let assetKind: CurrencyAssetKind

    public var id: String { code }

    public init(
        code: String,
        displayName: String,
        symbol: String?,
        assetKind: CurrencyAssetKind = .fiat
    ) {
        self.code = code
        self.displayName = displayName
        self.symbol = symbol
        self.assetKind = assetKind
    }

    private enum CodingKeys: String, CodingKey {
        case code
        case displayName
        case symbol
        case assetKind
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        code = try container.decode(String.self, forKey: .code)
        displayName = try container.decode(String.self, forKey: .displayName)
        symbol = try container.decodeIfPresent(String.self, forKey: .symbol)
        assetKind = try container.decodeIfPresent(CurrencyAssetKind.self, forKey: .assetKind) ?? .fiat
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

        let fiatCurrencies = Locale.commonISOCurrencyCodes
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
                    symbol: symbol(for: code, locale: locale),
                    assetKind: .fiat
                )
            }

        let cryptoCurrencies = curatedCryptoCurrencies()
        let currencies = fiatCurrencies + cryptoCurrencies

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

    private static func curatedCryptoCurrencies() -> [CurrencyDescriptor] {
        [
            CurrencyDescriptor(code: "BTC", displayName: "Bitcoin", symbol: "₿", assetKind: .crypto),
            CurrencyDescriptor(code: "ETH", displayName: "Ethereum", symbol: "ETH", assetKind: .crypto),
            CurrencyDescriptor(code: "USDT", displayName: "Tether", symbol: "USDT", assetKind: .crypto),
            CurrencyDescriptor(code: "USDC", displayName: "USDC", symbol: "USDC", assetKind: .crypto),
            CurrencyDescriptor(code: "BNB", displayName: "Binance Coin", symbol: "BNB", assetKind: .crypto),
            CurrencyDescriptor(code: "SOL", displayName: "Solana", symbol: "SOL", assetKind: .crypto),
            CurrencyDescriptor(code: "XRP", displayName: "Ripple", symbol: "XRP", assetKind: .crypto),
            CurrencyDescriptor(code: "ADA", displayName: "Cardano", symbol: "ADA", assetKind: .crypto),
            CurrencyDescriptor(code: "DOGE", displayName: "Dogecoin", symbol: "DOGE", assetKind: .crypto),
            CurrencyDescriptor(code: "LTC", displayName: "Litecoin", symbol: "LTC", assetKind: .crypto)
        ]
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
