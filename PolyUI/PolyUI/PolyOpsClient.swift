import Foundation

enum SystemStatus: String, Codable {
    case active
    case halted
    case unknown
}

struct KillRequest: Codable {
    let operator_id: String
    let reason: String
    let liquidate: Bool
}

struct KillResponse: Codable {
    let success: Bool
    let message: String
}

class PolyOpsClient {
    let baseURL = "https://polyops.wad-law.net"
    
    func checkHealth() async throws -> Bool {
        guard let url = URL(string: "\(baseURL)/health") else { return false }
        let (_, response) = try await URLSession.shared.data(from: url)
        return (response as? HTTPURLResponse)?.statusCode == 200
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
