import SwiftUI

struct KillSwitchView: View {
    @StateObject private var viewModel = KillSwitchViewModel()
    
    var body: some View {
        ZStack {
            // Background Color
            Color(viewModel.isHalted ? .black : .white)
                .edgesIgnoringSafeArea(.all)
            
            VStack(spacing: 40) {
                // Header
                Text(viewModel.isHalted ? "SYSTEM HALTED" : "SYSTEM ACTIVE")
                    .font(.system(size: 32, weight: .bold, design: .monospaced))
                    .foregroundColor(viewModel.isHalted ? .red : .green)
                
                Text("Status: \(viewModel.systemStatus)")
                    .font(.caption)
                    .foregroundColor(.gray)
                
                Spacer()
                
                // Big Red Button
                if !viewModel.isHalted {
                    Button(action: {
                        viewModel.triggerKillSwitch()
                    }) {
                        ZStack {
                            Circle()
                                .fill(Color.red)
                                .frame(width: 250, height: 250)
                                .shadow(color: .red.opacity(0.6), radius: 20, x: 0, y: 0)
                            
                            if viewModel.isProcessing {
                                ProgressView()
                                    .scaleEffect(2.0)
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            } else {
                                Text("WIPE")
                                    .font(.system(size: 40, weight: .black, design: .rounded))
                                    .foregroundColor(.white)
                            }
                        }
                    }
                    .padding()
                } else {
                    Image(systemName: "exclamationmark.shield.fill")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 150, height: 150)
                        .foregroundColor(.red)
                    
                    Text("All Trading Suspended")
                        .font(.title2)
                        .foregroundColor(.red)
                }
                
                Spacer()
                
                if let error = viewModel.errorMessage {
                    Text(error)
                        .foregroundColor(.white)
                        .padding()
                        .background(Color.red)
                        .cornerRadius(8)
                }
            }
            .padding()
        }
    }
}

struct KillSwitchView_Previews: PreviewProvider {
    static var previews: some View {
        KillSwitchView()
    }
}
