import Foundation

private struct UncheckedSendableUserDefaults: @unchecked Sendable {
    let value: UserDefaults
}

public protocol QuoteCacheReading: Sendable {
    func loadQuote(for pair: FavoriteCurrencyPair) -> CurrencyQuote?
}

public protocol QuoteCacheWriting: Sendable {
    func saveQuote(_ quote: CurrencyQuote) throws
}

public typealias QuoteCacheStoring = QuoteCacheReading & QuoteCacheWriting

public enum QuoteCacheStoreError: Error, Equatable, Sendable {
    case encodingFailed
}

public struct QuoteCacheStore: QuoteCacheStoring, Sendable {
    public static let defaultStorageKey = "quote-cache"

    private let defaults: UncheckedSendableUserDefaults
    private let storageKey: String
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    public init(
        defaults: UserDefaults = .standard,
        storageKey: String = defaultStorageKey
    ) {
        self.defaults = UncheckedSendableUserDefaults(value: defaults)
        self.storageKey = storageKey

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        self.encoder = encoder
        self.decoder = JSONDecoder()
    }

    public func loadQuote(for pair: FavoriteCurrencyPair) -> CurrencyQuote? {
        guard let storedData = defaults.value.data(forKey: storageKey) else {
            return nil
        }

        guard
            let payload = try? decoder.decode(
                QuoteCacheStoragePayload.self,
                from: storedData
            )
        else {
            return nil
        }

        return payload.quotes[pair.id]
    }

    public func saveQuote(_ quote: CurrencyQuote) throws {
        var payload: QuoteCacheStoragePayload
        if let storedData = defaults.value.data(forKey: storageKey),
           let existingPayload = try? decoder.decode(QuoteCacheStoragePayload.self, from: storedData) {
            payload = existingPayload
        } else {
            payload = QuoteCacheStoragePayload(quotes: [:])
        }

        let pair = FavoriteCurrencyPair(sourceCode: quote.sourceCode, targetCode: quote.targetCode)
        var quotes = payload.quotes
        quotes[pair.id] = quote
        let newPayload = QuoteCacheStoragePayload(version: payload.version, quotes: quotes)

        guard let encodedData = try? encoder.encode(newPayload) else {
            throw QuoteCacheStoreError.encodingFailed
        }

        defaults.value.set(encodedData, forKey: storageKey)
    }
}

struct QuoteCacheStoragePayload: Codable, Equatable, Sendable {
    static let currentVersion = 1

    let version: Int
    let quotes: [String: CurrencyQuote]

    init(version: Int = currentVersion, quotes: [String: CurrencyQuote]) {
        self.version = version
        self.quotes = quotes
    }
}
