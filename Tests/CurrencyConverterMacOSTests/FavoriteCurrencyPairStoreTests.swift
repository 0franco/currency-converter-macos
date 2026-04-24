import Foundation
import XCTest
@testable import CurrencyConverterMacOS

final class FavoriteCurrencyPairStoreTests: XCTestCase {
    private var suiteName: String!
    private var defaults: UserDefaults!

    override func setUp() {
        super.setUp()

        suiteName = "FavoriteCurrencyPairStoreTests.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
        defaults.removePersistentDomain(forName: suiteName)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        defaults = nil
        suiteName = nil

        super.tearDown()
    }

    func testLoadFavoritePairsReturnsEmptyArrayWhenNothingHasBeenStored() {
        let store = FavoriteCurrencyPairStore(defaults: defaults)

        XCTAssertEqual(store.loadFavoritePairs(), [])
    }

    func testSaveFavoritePairsPersistsVersionedPayload() throws {
        let store = FavoriteCurrencyPairStore(defaults: defaults)
        let pairs = [
            FavoriteCurrencyPair(sourceCode: "usd", targetCode: "eur"),
            FavoriteCurrencyPair(sourceCode: "eur", targetCode: "cny")
        ]

        try store.saveFavoritePairs(pairs)

        let rawData = try XCTUnwrap(
            defaults.data(forKey: FavoriteCurrencyPairStore.defaultStorageKey)
        )
        let payload = try JSONDecoder().decode(
            FavoriteCurrencyPairStoragePayload.self,
            from: rawData
        )

        XCTAssertEqual(payload.version, FavoriteCurrencyPairStoragePayload.currentVersion)
        XCTAssertEqual(payload.pairs, [
            FavoriteCurrencyPair(sourceCode: "USD", targetCode: "EUR"),
            FavoriteCurrencyPair(sourceCode: "EUR", targetCode: "CNY")
        ])
    }

    func testLoadFavoritePairsRoundTripsPersistedPairs() throws {
        let store = FavoriteCurrencyPairStore(defaults: defaults)
        let pairs = [
            FavoriteCurrencyPair(sourceCode: "USD", targetCode: "EUR"),
            FavoriteCurrencyPair(sourceCode: "USD", targetCode: "CNY")
        ]

        try store.saveFavoritePairs(pairs)

        XCTAssertEqual(store.loadFavoritePairs(), pairs)
    }

    func testLoadFavoritePairsReturnsEmptyArrayWhenStoredPayloadIsCorrupted() {
        let store = FavoriteCurrencyPairStore(defaults: defaults)

        defaults.set(Data("not-json".utf8), forKey: FavoriteCurrencyPairStore.defaultStorageKey)

        XCTAssertEqual(store.loadFavoritePairs(), [])
    }

    func testStoredPayloadUsesStableTopLevelKeys() throws {
        let store = FavoriteCurrencyPairStore(defaults: defaults)

        try store.saveFavoritePairs([
            FavoriteCurrencyPair(sourceCode: "USD", targetCode: "EUR")
        ])

        let rawData = try XCTUnwrap(
            defaults.data(forKey: FavoriteCurrencyPairStore.defaultStorageKey)
        )
        let rawJSON = try XCTUnwrap(String(data: rawData, encoding: .utf8))

        XCTAssertEqual(
            rawJSON,
            #"{"pairs":[{"sourceCode":"USD","targetCode":"EUR"}],"version":1}"#
        )
    }
}
