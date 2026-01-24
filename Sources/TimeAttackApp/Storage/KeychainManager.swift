import Foundation
import KeychainAccess

final class KeychainManager {
    static let shared = KeychainManager()
    
    #if DEBUG
    private static let isDebug = true
    #else
    private static let isDebug = false
    #endif
    
    private let keychain = Keychain(service: "com.timeattack.app")
    private let accessTokenKey = "linear_access_token"
    private let userDefaultsKey = "debug_access_token"
    
    private init() {}
    
    func saveAccessToken(_ token: String) throws {
        if Self.isDebug {
            UserDefaults.standard.set(token, forKey: userDefaultsKey)
        } else {
            try keychain.set(token, key: accessTokenKey)
        }
    }
    
    func getAccessToken() -> String? {
        if Self.isDebug {
            return UserDefaults.standard.string(forKey: userDefaultsKey)
        } else {
            return try? keychain.get(accessTokenKey)
        }
    }
    
    func deleteAccessToken() throws {
        if Self.isDebug {
            UserDefaults.standard.removeObject(forKey: userDefaultsKey)
        } else {
            try keychain.remove(accessTokenKey)
        }
    }
}
