import SwiftUI

struct KillSwitchView: View {
    @StateObject private var viewModel: KillSwitchViewModel
    
    init(viewModel: KillSwitchViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }
    
    var body: some View {
        NavigationStack {
            Form {
                // Section 1: System Status
                Section(header: Text("System Health")) {
                    HStack {
                        Label("Status", systemImage: iconName)
                            .foregroundColor(.primary)
                        Spacer()
                        Text(viewModel.systemStatus)
                            .foregroundColor(statusColor)
                            .fontWeight(.medium)
                    }
                    
                    if viewModel.isHalted {
                        HStack {
                            Image(systemName: "exclamationmark.octagon.fill")
                                .foregroundColor(.red)
                            Text("Trading Suspended")
                                .bold()
                                .foregroundColor(.red)
                        }
                    }
                }
                
                // Section 2: Actions
                Section(header: Text("Emergency Controls"), footer: Text("This action will immediately halt all trading algorithms. If liquidation is enabled, all positions will be sold at market price.")) {
                    if !viewModel.isHalted {
                        Toggle("Liquidate All Open Positions", isOn: $viewModel.shouldLiquidate)
                            .toggleStyle(SwitchToggleStyle(tint: .red))
                        
                        Button(role: .destructive, action: {
                            viewModel.triggerKillSwitch()
                        }) {
                            if viewModel.isProcessing {
                                ProgressView()
                            } else {
                                Label("Trigger Kill Switch", systemImage: "power")
                                    .frame(maxWidth: .infinity)
                            }
                        }
                        .disabled(viewModel.isProcessing)
                    } else {
                        Label("System Halted", systemImage: "lock.fill")
                            .foregroundColor(.secondary)
                    }
                }
                
                // Section 3: Error Reporting
                if let error = viewModel.errorMessage {
                    Section {
                        HStack {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.red)
                            Text(error)
                                .foregroundColor(.red)
                                .font(.footnote)
                        }
                    }
                }
            }
            .navigationTitle("Risk")
            .refreshable {
                // Pull to refresh
                 await viewModel.checkSystemHealth()
            }
        }
    }
    
    // Helper properties for UI logic
    var statusColor: Color {
        if viewModel.isHalted { return .red }
        switch viewModel.systemStatus {
        case "Online": return .green
        case "Preview Mode": return .blue
        case "Unreachable", "Error": return .orange
        default: return .gray
        }
    }
    
    var iconName: String {
        switch viewModel.systemStatus {
        case "Online": return "network"
        case "Unreachable", "Error": return "network.slash"
        default: return "questionmark.circle"
        }
    }
}

@MainActor
struct KillSwitchView_Previews: PreviewProvider {
    static var previews: some View {
        let vm = KillSwitchViewModel()
        KillSwitchView(viewModel: vm)
    }
}
