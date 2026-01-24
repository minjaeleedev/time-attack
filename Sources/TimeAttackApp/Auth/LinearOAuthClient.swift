import Foundation
import AuthenticationServices

final class LinearOAuthClient: NSObject {
    static let shared = LinearOAuthClient()
    
    private let clientId = "YOUR_LINEAR_CLIENT_ID"
    private let clientSecret = "YOUR_LINEAR_CLIENT_SECRET"
    private let redirectUri = "timeattack://oauth/callback"
    private let authorizationEndpoint = "https://linear.app/oauth/authorize"
    private let tokenEndpoint = "https://api.linear.app/oauth/token"
    
    private var authSession: ASWebAuthenticationSession?
    private var presentationAnchor: ASPresentationAnchor?
    
    private override init() {
        super.init()
    }
    
    func setPresentationAnchor(_ anchor: ASPresentationAnchor) {
        self.presentationAnchor = anchor
    }
    
    @MainActor
    func authenticate() async throws -> String {
        let state = UUID().uuidString
        
        var components = URLComponents(string: authorizationEndpoint)!
        components.queryItems = [
            URLQueryItem(name: "client_id", value: clientId),
            URLQueryItem(name: "redirect_uri", value: redirectUri),
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "scope", value: "read"),
            URLQueryItem(name: "state", value: state)
        ]
        
        guard let authUrl = components.url else {
            throw OAuthError.invalidURL
        }
        
        let callbackUrl = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<URL, Error>) in
            authSession = ASWebAuthenticationSession(
                url: authUrl,
                callbackURLScheme: "timeattack"
            ) { callbackURL, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                guard let callbackURL = callbackURL else {
                    continuation.resume(throwing: OAuthError.noCallback)
                    return
                }
                continuation.resume(returning: callbackURL)
            }
            
            authSession?.presentationContextProvider = self
            authSession?.prefersEphemeralWebBrowserSession = false
            authSession?.start()
        }
        
        guard let components = URLComponents(url: callbackUrl, resolvingAgainstBaseURL: false),
              let code = components.queryItems?.first(where: { $0.name == "code" })?.value,
              let returnedState = components.queryItems?.first(where: { $0.name == "state" })?.value,
              returnedState == state else {
            throw OAuthError.invalidCallback
        }
        
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
            "code": code
        ]
        
        request.httpBody = body
            .map { "\($0.key)=\($0.value)" }
            .joined(separator: "&")
            .data(using: .utf8)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw OAuthError.tokenExchangeFailed
        }
        
        let tokenResponse = try JSONDecoder().decode(TokenResponse.self, from: data)
        return tokenResponse.accessToken
    }
}

extension LinearOAuthClient: ASWebAuthenticationPresentationContextProviding {
    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        presentationAnchor ?? ASPresentationAnchor()
    }
}

enum OAuthError: Error, LocalizedError {
    case invalidURL
    case noCallback
    case invalidCallback
    case tokenExchangeFailed
    
    var errorDescription: String? {
        switch self {
        case .invalidURL: return "Invalid authorization URL"
        case .noCallback: return "No callback received"
        case .invalidCallback: return "Invalid callback parameters"
        case .tokenExchangeFailed: return "Failed to exchange code for token"
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
