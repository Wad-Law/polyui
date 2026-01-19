import Foundation

struct SystemStatusResponse: Codable, Sendable {
    let healthy: Bool
    let mode: String
    let active_strategies: Int
}

struct KillRequest: Codable, Sendable {
    let operator_id: String
    let reason: String
    let liquidate: Bool
}

struct KillResponse: Codable, Sendable {
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
                                        do {
                                            let status = try JSONDecoder().decode(SystemStatusResponse.self, from: data)
                                            continuation.yield(status)
                                        } catch {
                                            print("JSON Parsing Error: \(error)")
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
    
    func triggerKillSwitch(operatorId: String, reason: String, liquidate: Bool) async throws -> KillResponse {
        guard let url = URL(string: "\(baseURL)/api/v1/system/kill") else {
            throw URLError(.badURL)
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let payload = KillRequest(operator_id: operatorId, reason: reason, liquidate: liquidate)
        request.httpBody = try JSONEncoder().encode(payload)
        
        let (data, _) = try await URLSession.shared.data(for: request)
        return try JSONDecoder().decode(KillResponse.self, from: data)
    }
}
