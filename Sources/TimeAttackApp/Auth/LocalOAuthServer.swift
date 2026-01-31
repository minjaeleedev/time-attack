import AppKit
import Foundation
import Network

final class LocalOAuthServer {
    private let port: UInt16
    private let onCallback: (URL) -> Void
    private var listener: NWListener?

    init(port: UInt16, onCallback: @escaping (URL) -> Void) {
        self.port = port
        self.onCallback = onCallback
    }

    func start() throws {
        let parameters = NWParameters.tcp
        parameters.allowLocalEndpointReuse = true

        guard let nwPort = NWEndpoint.Port(rawValue: port) else {
            throw OAuthError.serverStartFailed
        }

        listener = try NWListener(using: parameters, on: nwPort)

        listener?.stateUpdateHandler = { [weak self] state in
            switch state {
            case .ready:
                print("🌐 [Server] Ready on port \(self?.port ?? 0)")
            case .failed(let error):
                print("🌐 [Server] Failed: \(error)")
            case .cancelled:
                print("🌐 [Server] Cancelled")
            default:
                break
            }
        }

        listener?.newConnectionHandler = { [weak self] connection in
            self?.handleConnection(connection)
        }

        listener?.start(queue: .main)
    }

    func stop() {
        listener?.cancel()
        listener = nil
        print("🌐 [Server] Stopped")
    }

    private func handleConnection(_ connection: NWConnection) {
        connection.stateUpdateHandler = { state in
            switch state {
            case .ready:
                self.receiveRequest(connection)
            case .failed(let error):
                print("🌐 [Server] Connection failed: \(error)")
                connection.cancel()
            default:
                break
            }
        }

        connection.start(queue: .main)
    }

    private func receiveRequest(_ connection: NWConnection) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 65536) {
            [weak self] content, _, isComplete, error in

            guard let self = self else { return }

            if let error = error {
                print("🌐 [Server] Receive error: \(error)")
                connection.cancel()
                return
            }

            guard let data = content, let requestString = String(data: data, encoding: .utf8) else {
                connection.cancel()
                return
            }

            print("🌐 [Server] Received request:\n\(requestString.prefix(200))...")

            if let url = self.parseRequestURL(from: requestString) {
                self.sendSuccessResponse(connection) {
                    DispatchQueue.main.async {
                        NSApp.activate(ignoringOtherApps: true)
                        self.onCallback(url)
                    }
                }
            } else {
                self.sendErrorResponse(connection)
            }
        }
    }

    private func parseRequestURL(from request: String) -> URL? {
        let lines = request.components(separatedBy: "\r\n")
        guard let requestLine = lines.first else { return nil }

        let parts = requestLine.split(separator: " ")
        guard parts.count >= 2 else { return nil }

        let path = String(parts[1])

        guard path.hasPrefix("/oauth/callback") else { return nil }

        return URL(string: "http://localhost:\(port)\(path)")
    }

    private func sendSuccessResponse(_ connection: NWConnection, completion: @escaping () -> Void) {
        let html = """
            <!DOCTYPE html>
            <html>
            <head>
                <title>Authorization Successful</title>
                <style>
                    body {
                        font-family: -apple-system, BlinkMacSystemFont, sans-serif;
                        display: flex;
                        justify-content: center;
                        align-items: center;
                        height: 100vh;
                        margin: 0;
                        background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
                        color: white;
                    }
                    .container {
                        text-align: center;
                        padding: 40px;
                        background: rgba(255,255,255,0.1);
                        border-radius: 20px;
                        backdrop-filter: blur(10px);
                    }
                    h1 { font-size: 24px; margin-bottom: 10px; }
                    p { opacity: 0.9; }
                </style>
            </head>
            <body>
                <div class="container">
                    <h1>Authorization Successful</h1>
                    <p>You can close this window and return to TimeAttack.</p>
                </div>
                <script>setTimeout(() => window.close(), 2000);</script>
            </body>
            </html>
            """

        let response = """
            HTTP/1.1 200 OK\r
            Content-Type: text/html; charset=utf-8\r
            Content-Length: \(html.utf8.count)\r
            Connection: close\r
            \r
            \(html)
            """

        connection.send(
            content: response.data(using: .utf8),
            completion: .contentProcessed { _ in
                connection.cancel()
                completion()
            }
        )
    }

    private func sendErrorResponse(_ connection: NWConnection) {
        let response = """
            HTTP/1.1 400 Bad Request\r
            Content-Type: text/plain\r
            Content-Length: 11\r
            Connection: close\r
            \r
            Bad Request
            """

        connection.send(
            content: response.data(using: .utf8),
            completion: .contentProcessed { _ in
                connection.cancel()
            }
        )
    }
}
