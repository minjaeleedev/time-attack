import Foundation

public struct Team: Identifiable, Codable, Equatable {
    public let id: String
    public let name: String
    public let key: String

    public init(id: String, name: String, key: String) {
        self.id = id
        self.name = name
        self.key = key
    }
}
