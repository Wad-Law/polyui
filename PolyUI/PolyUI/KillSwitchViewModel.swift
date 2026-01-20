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
                    // Update State based on push data (Ignore generic hello messages)
                    if state.mode == "DEBUG_CONNECTING" { continue }
                    
                    self.systemStatus = state.mode.starts(with: "halted") ? "Halted" : "Online"
                    self.isHalted = state.mode.starts(with: "halted")
                }
            } catch {
                if let urlError = error as? URLError, urlError.code == .cannotParseResponse {
                     self.systemStatus = urlError.localizedDescription // "server Error: ..."
                } else {
                     self.systemStatus = "Disconnected"
                }
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
    
    func setSystemState(active: Bool) {
        guard !isProcessing else { return }
        
        isProcessing = true
        errorMessage = nil
        
        Task {
            do {
                let stateStr = active ? "active" : "halted"
                let liq = active ? false : shouldLiquidate
                let reason = active ? "Manual Resume" : "Manual Kill Switch"
                
                let response = try await client.setSystemState(
                    operatorId: "PolyUI-User",
                    reason: reason,
                    state: stateStr,
                    liquidate: liq
                )
                
                if response.success {
                    // Optimistic update
                    self.isHalted = !active
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
