import Foundation

private struct UncheckedSendableUserDefaults: @unchecked Sendable {
    let value: UserDefaults
}

public protocol FavoriteCurrencyPairReading: Sendable {
    func loadFavoritePairs() -> [FavoriteCurrencyPair]
}

public protocol FavoriteCurrencyPairWriting: Sendable {
    func saveFavoritePairs(_ pairs: [FavoriteCurrencyPair]) throws
}

public typealias FavoriteCurrencyPairStoring = FavoriteCurrencyPairReading & FavoriteCurrencyPairWriting

public enum FavoriteCurrencyPairStoreError: Error, Equatable, Sendable {
    case encodingFailed
}

public struct FavoriteCurrencyPairStore: FavoriteCurrencyPairStoring, Sendable {
    public static let defaultStorageKey = "favorite-currency-pairs"

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

    public func loadFavoritePairs() -> [FavoriteCurrencyPair] {
        guard let storedData = defaults.value.data(forKey: storageKey) else {
            return []
        }

        guard
            let payload = try? decoder.decode(
                FavoriteCurrencyPairStoragePayload.self,
                from: storedData
            )
        else {
            return []
        }

        return payload.pairs
    }

    public func saveFavoritePairs(_ pairs: [FavoriteCurrencyPair]) throws {
        let payload = FavoriteCurrencyPairStoragePayload(pairs: pairs)

        guard let encodedData = try? encoder.encode(payload) else {
            throw FavoriteCurrencyPairStoreError.encodingFailed
        }

        defaults.value.set(encodedData, forKey: storageKey)
    }
}

struct FavoriteCurrencyPairStoragePayload: Codable, Equatable, Sendable {
    static let currentVersion = 1

    let version: Int
    let pairs: [FavoriteCurrencyPair]

    init(version: Int = currentVersion, pairs: [FavoriteCurrencyPair]) {
        self.version = version
        self.pairs = pairs
    }
}
