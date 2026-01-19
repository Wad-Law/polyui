import Foundation
import SwiftUI
import Combine

// ViewModel: Connects View to Model. Holds State.
@MainActor
class KillSwitchViewModel: ObservableObject {
    @Published var shouldLiquidate: Bool = false
    @Published var isHalted: Bool = false
    @Published var errorMessage: String? = nil
    @Published var isProcessing: Bool = false
    @Published var systemStatus: String = "Unknown"
    
    private let client = PolyOpsClient()
    private var timer: Timer?
    
    init() {
        // Start persistent connection immediately
        Task {
            await startMonitoring()
        }
    }
    
    func startMonitoring() async {
        // Infinite loop to handle reconnections if the stream ends
        while true {
            self.systemStatus = "Connecting..."
            do {
                for try await state in client.monitorSystemStatus() {
                    // Update State based on push data
                    self.systemStatus = state.mode.starts(with: "halted") ? "Halted" : "Online"
                    self.isHalted = state.mode.starts(with: "halted")
                }
            } catch {
                self.systemStatus = "Disconnected"
                print("WebSocket Error: \(error)")
            }
            
            // Wait before reconnecting
            try? await Task.sleep(nanoseconds: 3 * 1_000_000_000)
        }
    }
    
    // Kept for manual refresh (Verify connectivity)
    func checkSystemHealth() async {
        do {
            let isHealthy = try await client.checkHealth()
            // Only update status if we aren't already halted (WS is source of truth)
            if !isHalted {
                self.systemStatus = isHealthy ? "Online" : "Unreachable"
            }
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
                let response = try await client.triggerKillSwitch(
                    operatorId: "PolyUI-User",
                    reason: "Manual Kill Switch Activation",
                    liquidate: shouldLiquidate
                )
                
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
