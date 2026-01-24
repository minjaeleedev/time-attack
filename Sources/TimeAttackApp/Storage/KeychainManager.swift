import Foundation
import KeychainAccess

final class KeychainManager {
    static let shared = KeychainManager()
    
    private let keychain = Keychain(service: "com.timeattack.app")
    private let accessTokenKey = "linear_access_token"
    
    private init() {}
    
    func saveAccessToken(_ token: String) throws {
        try keychain.set(token, key: accessTokenKey)
    }
    
    func getAccessToken() -> String? {
        try? keychain.get(accessTokenKey)
    }
    
    func deleteAccessToken() throws {
        try keychain.remove(accessTokenKey)
    }
}
