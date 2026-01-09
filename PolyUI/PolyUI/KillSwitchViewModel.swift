import Foundation
import SwiftUI

// ViewModel: Connects View to Model. Holds State.
@MainActor
class KillSwitchViewModel: ObservableObject {
    @Published var isHalted: Bool = false
    @Published var errorMessage: String? = nil
    @Published var isProcessing: Bool = false
    @Published var systemStatus: String = "Unknown"
    
    private let client = PolyOpsClient()
    private var timer: Timer?
    
    init() {
        startPolling()
    }
    
    func startPolling() {
        // Poll every 5 seconds to check system health
        timer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                await self?.checkSystemHealth()
            }
        }
    }
    
    func checkSystemHealth() async {
        do {
            let isHealthy = try await client.checkHealth()
            self.systemStatus = isHealthy ? "Online" : "Unreachable"
        } catch {
            self.systemStatus = "Error"
        }
    }
    
    func triggerKillSwitch() {
        guard !isProcessing else { return }
        
        isProcessing = true
        errorMessage = nil
        
        Task {
            do {
                let response = try await client.triggerKillSwitch(operatorId: "PolyUI-User", reason: "Manual Kill Switch Activation")
                
                if response.success {
                    self.isHalted = true
                } else {
                    self.errorMessage = "Failed: \(response.message)"
                }
            } catch {
                self.errorMessage = "Network Error: \(error.localizedDescription)"
            }
            self.isProcessing = false
        }
    }
}
