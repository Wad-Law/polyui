import Foundation

struct SystemStatusResponse: Codable, Sendable {
    let healthy: Bool
    let mode: String
    let active_strategies: Int
}

struct SetStateRequest: Codable, Sendable {
    let operator_id: String
    let reason: String
    let state: String // "active" or "halted"
    let liquidate: Bool
    
    enum CodingKeys: String, CodingKey {
        case operator_id = "operator"
        case reason
        case state
        case liquidate
    }
}

struct SetStateResponse: Codable, Sendable {
    let success: Bool
    let message: String
}

final class PolyOpsClient: Sendable {
    let baseURL = "https://polyops.wad-law.net"
    let wsURL = "wss://polyops.wad-law.net/ws/status"
    
    func checkHealth() async throws -> Bool {
        guard let url = URL(string: "\(baseURL)/health") else { return false }
        let (_, response) = try await URLSession.shared.data(from: url)
        return (response as? HTTPURLResponse)?.statusCode == 200
    }
    
    func monitorSystemStatus() -> AsyncThrowingStream<SystemStatusResponse, Error> {
        return AsyncThrowingStream { continuation in
            guard let url = URL(string: wsURL) else {
                continuation.finish(throwing: URLError(.badURL))
                return
            }
            
            let task = URLSession.shared.webSocketTask(with: url)
            task.resume()
            
            @Sendable func listen() {
                task.receive { result in
                    switch result {
                        case .success(let message):
                            switch message {
                                case .string(let text):
                                    if let data = text.data(using: .utf8) {
                                        if text.starts(with: "Error:") {
                                            print("Server Error: \(text)")
                                            continuation.finish(throwing: URLError(.cannotParseResponse, userInfo: [NSLocalizedDescriptionKey: text]))
                                            return
                                        }
                                        
                                        do {
                                            let status = try JSONDecoder().decode(SystemStatusResponse.self, from: data)
                                            continuation.yield(status)
                                        } catch {
                                            print("JSON Parsing Error: \(error), Text: \(text)")
                                        }
                                    }
                                default:
                                    break
                            }
                            listen() // Recursively listen for next message
                            
                        case .failure(let error):
                            continuation.finish(throwing: error)
                        }
                }
            }
            
            listen()
            
            // Handle cancelation
            continuation.onTermination = { @Sendable _ in
                task.cancel(with: .normalClosure, reason: nil)
            }
        }
    }
    
    func setSystemState(operatorId: String, reason: String, state: String, liquidate: Bool) async throws -> SetStateResponse {
        guard let url = URL(string: "\(baseURL)/api/v1/system/state") else {
            throw URLError(.badURL)
        }
                
        var request = URLRequest(url: url)

        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
     
        let payload = SetStateRequest(operator_id: operatorId, reason: reason, state: state, liquidate: liquidate)
        request.httpBody = try JSONEncoder().encode(payload)
        
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 10
        let session = URLSession(configuration: config)
        let (data, _) = try await session.data(for: request)
        
        return try JSONDecoder().decode(SetStateResponse.self, from: data)
    }
}
