import AppKit
import Foundation

final class LinearOAuthClient {
    static let shared = LinearOAuthClient()

    private let clientId: String
    private let clientSecret: String
    private let callbackPort: UInt16 = 8847
    private var redirectUri: String { "http://localhost:\(callbackPort)/oauth/callback" }
    private let authorizationEndpoint = "https://linear.app/oauth/authorize"
    private let tokenEndpoint = "https://api.linear.app/oauth/token"

    private var server: LocalOAuthServer?

    private init() {
        let env = Self.loadEnvFile()
        self.clientId = env["LINEAR_CLIENT_ID"] ?? ""
        self.clientSecret = env["LINEAR_CLIENT_SECRET"] ?? ""
    }

    private static func loadEnvFile() -> [String: String] {
        var result: [String: String] = [:]

        let possiblePaths = [
            Bundle.main.path(forResource: "env", ofType: nil),
            Bundle.main.path(forResource: ".env", ofType: nil),
        ].compactMap { $0 }

        for path in possiblePaths {
            if let contents = try? String(contentsOfFile: path, encoding: .utf8) {
                let lines = contents.components(separatedBy: .newlines)
                for line in lines {
                    let trimmed = line.trimmingCharacters(in: .whitespaces)
                    guard !trimmed.isEmpty, !trimmed.hasPrefix("#") else { continue }
                    let parts = trimmed.split(separator: "=", maxSplits: 1)
                    if parts.count == 2 {
                        result[String(parts[0])] = String(parts[1])
                    }
                }
                break
            }
        }

        return result
    }

    @MainActor
    func authenticate() async throws -> String {
        print("🔐 [OAuth] Starting authentication...")
        print(
            "🔐 [OAuth] clientId: \(clientId.isEmpty ? "EMPTY" : String(clientId.prefix(8)) + "...")"
        )
        print("🔐 [OAuth] redirectUri: \(redirectUri)")

        let state = UUID().uuidString

        var components = URLComponents(string: authorizationEndpoint)!
        components.queryItems = [
            URLQueryItem(name: "client_id", value: clientId),
            URLQueryItem(name: "redirect_uri", value: redirectUri),
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "scope", value: "read"),
            URLQueryItem(name: "state", value: state),
        ]

        guard let authUrl = components.url else {
            throw OAuthError.invalidURL
        }

        print("🔐 [OAuth] Auth URL: \(authUrl)")

        let callbackUrl = try await withCheckedThrowingContinuation {
            (continuation: CheckedContinuation<URL, Error>) in

            server = LocalOAuthServer(port: callbackPort) { [weak self] url in
                self?.server?.stop()
                self?.server = nil
                continuation.resume(returning: url)
            }

            do {
                try server?.start()
                print("🔐 [OAuth] Local server started on port \(callbackPort)")

                NSWorkspace.shared.open(authUrl)
                print("🔐 [OAuth] Opened browser for authentication")
            } catch {
                continuation.resume(throwing: error)
            }
        }

        print("🔐 [OAuth] Callback received: \(callbackUrl)")

        guard let components = URLComponents(url: callbackUrl, resolvingAgainstBaseURL: false),
            let code = components.queryItems?.first(where: { $0.name == "code" })?.value,
            let returnedState = components.queryItems?.first(where: { $0.name == "state" })?.value,
            returnedState == state
        else {
            throw OAuthError.invalidCallback
        }

        print("🔐 [OAuth] Authorization code received, exchanging for token...")
        return try await exchangeCodeForToken(code: code)
    }

    private func exchangeCodeForToken(code: String) async throws -> String {
        var request = URLRequest(url: URL(string: tokenEndpoint)!)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

        let body = [
            "grant_type": "authorization_code",
            "client_id": clientId,
            "client_secret": clientSecret,
            "redirect_uri": redirectUri,
            "code": code,
        ]

        request.httpBody =
            body
            .map { "\($0.key)=\($0.value)" }
            .joined(separator: "&")
            .data(using: .utf8)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw OAuthError.tokenExchangeFailed
        }

        if httpResponse.statusCode != 200 {
            let responseBody = String(data: data, encoding: .utf8) ?? "No response body"
            print("🔐 [OAuth] Token exchange failed: \(httpResponse.statusCode)")
            print("🔐 [OAuth] Response: \(responseBody)")
            throw OAuthError.tokenExchangeFailed
        }

        let tokenResponse = try JSONDecoder().decode(TokenResponse.self, from: data)
        print("🔐 [OAuth] Token received successfully")
        return tokenResponse.accessToken
    }
}

enum OAuthError: Error, LocalizedError {
    case invalidURL
    case noCallback
    case invalidCallback
    case tokenExchangeFailed
    case serverStartFailed

    var errorDescription: String? {
        switch self {
        case .invalidURL: return "Invalid authorization URL"
        case .noCallback: return "No callback received"
        case .invalidCallback: return "Invalid callback parameters"
        case .tokenExchangeFailed: return "Failed to exchange code for token"
        case .serverStartFailed: return "Failed to start local OAuth server"
        }
    }
}

private struct TokenResponse: Codable {
    let accessToken: String
    let tokenType: String
    let expiresIn: Int?
    let scope: String?

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case tokenType = "token_type"
        case expiresIn = "expires_in"
        case scope
    }
}
