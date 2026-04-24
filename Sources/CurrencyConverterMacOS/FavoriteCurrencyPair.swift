import Foundation

public struct FavoriteCurrencyPair: Codable, Hashable, Identifiable, Sendable {
    public let sourceCode: String
    public let targetCode: String

    public var id: String {
        "\(sourceCode)->\(targetCode)"
    }

    public init(sourceCode: String, targetCode: String) {
        self.sourceCode = sourceCode.uppercased()
        self.targetCode = targetCode.uppercased()
    }
}
