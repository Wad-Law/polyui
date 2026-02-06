# PolyUI - Claude Code Guidelines

## Project Overview

PolyUI is the iOS mobile command center for the Polymind trading ecosystem. Built with SwiftUI, it provides real-time system monitoring and control capabilities for human operators. It communicates with the polyops HTTP API for system control and receives live updates via WebSocket streaming.

## Core Architecture

### System Role
- **Type**: iOS Mobile App (SwiftUI)
- **Platform**: iOS 17+
- **Communication**: HTTP REST API + WebSocket to polyops
- **Philosophy**: "Cockpit, not Engine" - displays state, does not calculate it

### Integration Flow
```
PolyUI (iOS) --> HTTP/WebSocket --> PolyOps (:3001) --> gRPC --> Polymind
                                         |
                                         v
                                    Control Plane
```

### Tech Stack
- **UI Framework**: SwiftUI
- **Async**: Swift Concurrency (async/await, AsyncThrowingStream)
- **Networking**: URLSession with native async support
- **WebSocket**: URLSession WebSocket API
- **Architecture**: MVVM (Model-View-ViewModel)

## App Structure

### Navigation Hierarchy
The app follows a "Settings App" pattern with four core sections:

1. **Intelligence** (The "Eyes")
   - Live news feed visualization
   - Sentiment analysis display
   - Market candidate inspection

2. **Treasury** (The "Wallet")
   - Asset breakdown (Cash vs. Invested)
   - Capital allocation management
   - Strategy budget control

3. **Strategies** (The "Hands")
   - Active strategy monitoring
   - Position tracking per strategy
   - Strategy-specific controls (pause, liquidate)

4. **Risk & System** (The "Brain")
   - Risk metrics dashboard
   - System health monitoring
   - **Global Kill Switch**

### Global HUD (Always Visible)
- System Status: 🟢 Active / 🔴 Halted
- Net Liquidity (Total Equity)
- Day P&L (Profit/Loss with %)

## API Integration

### PolyOps Client Pattern

**File**: `PolyUI/PolyUI/PolyOpsClient.swift`

```swift
final class PolyOpsClient: Sendable {
    let baseURL = "https://polyops.wad-law.net"
    let wsURL = "wss://polyops.wad-law.net/ws/status"

    // Health check endpoint
    func checkHealth() async throws -> Bool {
        guard let url = URL(string: "\(baseURL)/health") else { return false }
        let (_, response) = try await URLSession.shared.data(from: url)
        return (response as? HTTPURLResponse)?.statusCode == 200
    }

    // WebSocket streaming for real-time updates
    func monitorSystemStatus() -> AsyncThrowingStream<SystemStatusResponse, Error> {
        // Returns async stream of status updates
    }

    // Control action: set system state
    func setSystemState(
        operatorId: String,
        reason: String,
        state: String,
        liquidate: Bool
    ) async throws -> SetStateResponse {
        // POST to /api/v1/system/state
    }
}
```

### Data Models

All API models must be `Codable` and `Sendable` (for Swift 6 concurrency):

```swift
struct SystemStatusResponse: Codable, Sendable {
    let healthy: Bool
    let mode: String
    let active_strategies: Int
}

struct SetStateRequest: Codable, Sendable {
    let operator_id: String
    let reason: String
    let state: String         // "active" or "halted"
    let liquidate: Bool

    // Custom CodingKeys for snake_case API
    enum CodingKeys: String, CodingKey {
        case operator_id = "operator"
        case reason, state, liquidate
    }
}

struct SetStateResponse: Codable, Sendable {
    let success: Bool
    let message: String
}
```

## MVVM Architecture

### ViewModel Pattern

ViewModels use `@Observable` macro (iOS 17+) for reactive state management:

```swift
@Observable
final class KillSwitchViewModel {
    var systemStatus: SystemStatusResponse?
    var isLoading = false
    var errorMessage: String?

    private let client = PolyOpsClient()

    @MainActor
    func startMonitoring() async {
        for try await status in client.monitorSystemStatus() {
            self.systemStatus = status
        }
    }

    @MainActor
    func triggerKillSwitch(reason: String, liquidate: Bool) async {
        isLoading = true
        defer { isLoading = false }

        do {
            let response = try await client.setSystemState(
                operatorId: "PolyUI-User",
                reason: reason,
                state: "halted",
                liquidate: liquidate
            )
            // Handle success
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
```

### View Pattern

Views bind to ViewModel state using SwiftUI property wrappers:

```swift
struct KillSwitchView: View {
    @State private var viewModel = KillSwitchViewModel()

    var body: some View {
        VStack {
            // System status display
            if let status = viewModel.systemStatus {
                StatusIndicator(healthy: status.healthy, mode: status.mode)
            }

            // Kill switch button
            Button("Emergency Halt") {
                Task {
                    await viewModel.triggerKillSwitch(
                        reason: "User initiated",
                        liquidate: true
                    )
                }
            }
            .disabled(viewModel.isLoading)
        }
        .task {
            await viewModel.startMonitoring()
        }
    }
}
```

## Networking Best Practices

### Error Handling

Always handle network errors gracefully with user-friendly messages:

```swift
do {
    let result = try await client.setSystemState(...)
    // Success handling
} catch let error as URLError {
    switch error.code {
    case .notConnectedToInternet:
        showAlert("No internet connection")
    case .timedOut:
        showAlert("Request timed out. Check network connection.")
    default:
        showAlert("Network error: \(error.localizedDescription)")
    }
} catch {
    showAlert("Unexpected error: \(error.localizedDescription)")
}
```

### Timeout Configuration

Set appropriate timeouts for control actions:

```swift
let config = URLSessionConfiguration.ephemeral
config.timeoutIntervalForRequest = 10  // 10 seconds for kill switch
let session = URLSession(configuration: config)
```

### WebSocket Reconnection

Implement automatic reconnection for WebSocket streams:

```swift
func startMonitoring() async {
    while !Task.isCancelled {
        do {
            for try await status in client.monitorSystemStatus() {
                self.systemStatus = status
            }
        } catch {
            // Log error and retry after delay
            try? await Task.sleep(for: .seconds(3))
        }
    }
}
```

## Testing

### Running Tests

Tests run on iOS Simulator via Xcode or CI:

```bash
xcodebuild test \
  -project PolyUI/PolyUI/PolyUI.xcodeproj \
  -scheme PolyUI \
  -destination 'platform=iOS Simulator,name=iPhone 17,OS=latest'
```

### Mock API Client

Create mock client for testing:

```swift
final class MockPolyOpsClient: PolyOpsClient {
    var mockStatus = SystemStatusResponse(
        healthy: true,
        mode: "active",
        active_strategies: 1
    )

    override func monitorSystemStatus() -> AsyncThrowingStream<SystemStatusResponse, Error> {
        return AsyncThrowingStream { continuation in
            continuation.yield(mockStatus)
            continuation.finish()
        }
    }
}
```

## Build & Deployment

### CI/CD

GitHub Actions workflow (`.github/workflows/ios-ci.yml`):
- **Runs on**: `macos-latest` (uses default Xcode version)
- **Triggers**: Push to `main`, Pull requests, Manual dispatch
- **Steps**:
  1. Checkout code
  2. Show Xcode version (for debugging)
  3. List available simulators
  4. Build for iOS Simulator (`iPhone 15 Pro`)
  5. Validate build success

**Key Settings:**
- Code signing disabled for CI builds (`CODE_SIGNING_REQUIRED=NO`)
- Builds for `iPhone 15 Pro` simulator (guaranteed to be available)
- Uses `Debug` configuration
- No test execution (focuses on build validation only)

### TestFlight Distribution

For production builds:
1. Archive in Xcode: `Product > Archive`
2. Validate app
3. Distribute to TestFlight
4. Add tester groups for internal testing

## Security

### API Endpoints

**Production**: `https://polyops.wad-law.net`
- Exposed via **Cloudflare Tunnel** (secure, no open ports)
- TLS/HTTPS enforced
- WebSocket uses `wss://` (secure WebSocket)

### Authentication

Currently unauthenticated (operator trust model). Future considerations:
- API key authentication
- OAuth/OIDC integration
- Biometric authentication (Face ID/Touch ID) for kill switch

### Sensitive Data

- No API keys stored in code (only endpoint URLs)
- No credentials cached on device
- All control actions require explicit user confirmation

## Swift Coding Conventions

### Concurrency

Use modern Swift concurrency (async/await, not callbacks):

```swift
// ✅ Good
func fetchData() async throws -> Data {
    try await URLSession.shared.data(from: url).0
}

// ❌ Bad (old completion handler style)
func fetchData(completion: @escaping (Data?, Error?) -> Void) {
    URLSession.shared.dataTask(with: url) { data, _, error in
        completion(data, error)
    }.resume()
}
```

### Sendable Conformance

Mark types as `Sendable` to ensure thread safety:

```swift
struct SystemStatus: Codable, Sendable {  // ✅ Safe to pass across concurrency boundaries
    let healthy: Bool
}

class APIClient: Sendable {  // ✅ Can be used from any actor
    let baseURL: String
}
```

### SwiftUI State Management

Use `@State` for view-local state, `@Observable` for shared ViewModel state:

```swift
struct ContentView: View {
    @State private var viewModel = ContentViewModel()  // ViewModel
    @State private var isShowingSheet = false         // Local UI state

    var body: some View {
        // ...
    }
}
```

## Common Patterns

### Loading States

Show loading indicators during async operations:

```swift
@Observable
final class ViewModel {
    var isLoading = false

    func performAction() async {
        isLoading = true
        defer { isLoading = false }  // Always reset, even on error

        // Perform async work
    }
}

struct ContentView: View {
    @State private var viewModel = ViewModel()

    var body: some View {
        Button("Action") {
            Task { await viewModel.performAction() }
        }
        .disabled(viewModel.isLoading)
        .overlay {
            if viewModel.isLoading {
                ProgressView()
            }
        }
    }
}
```

### Error Presentation

Use alerts or inline error messages:

```swift
@Observable
final class ViewModel {
    var errorMessage: String?
}

struct ContentView: View {
    @State private var viewModel = ViewModel()

    var body: some View {
        // Content
        .alert("Error", isPresented: .constant(viewModel.errorMessage != nil)) {
            Button("OK") { viewModel.errorMessage = nil }
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
    }
}
```

## Anti-Patterns (DO NOT)

❌ **DO NOT** use `@ObservedObject` or `@StateObject` (deprecated in iOS 17+) - use `@Observable` instead
❌ **DO NOT** perform network calls directly in Views - always use ViewModels
❌ **DO NOT** block main thread with synchronous network calls
❌ **DO NOT** hardcode API endpoints - use configuration or environment variables
❌ **DO NOT** ignore error states - always provide user feedback
❌ **DO NOT** use completion handlers when async/await is available
❌ **DO NOT** create retain cycles with `[weak self]` in Tasks (not needed)

## File Organization

```
PolyUI/
├── PolyUI/
│   ├── PolyUIApp.swift           # App entry point
│   ├── PolyOpsClient.swift       # API client
│   ├── KillSwitchView.swift      # View layer
│   ├── KillSwitchViewModel.swift # ViewModel layer
│   └── Assets.xcassets           # Images, colors
└── PolyUI.xcodeproj
```

## Configuration Files

- **Info.plist**: App configuration, permissions, URL schemes
- **Assets.xcassets**: App icons, colors, images
- **CLAUDE.md**: This file - development guidelines

## Dependencies

Currently **zero external dependencies** (uses only system frameworks):
- Foundation (networking, JSON)
- SwiftUI (UI framework)
- Combine (reactive streams - minimal usage)

**Philosophy**: Prefer system APIs over third-party libraries to minimize bloat and maintenance burden.

## Deployment Targets

- **Minimum iOS**: 17.0
- **Target Device**: iPhone (optimized for iPhone 14 Pro and later)
- **Orientation**: Portrait only (for now)

---

## Quick Reference

**PolyOps API Base URL**: `https://polyops.wad-law.net`
**WebSocket URL**: `wss://polyops.wad-law.net/ws/status`
**CI Runner**: `macos-latest` with Xcode 15.4
**Minimum iOS Version**: 17.0

**Key Endpoints**:
- `GET /health` - Health check
- `POST /api/v1/system/state` - Set system state (kill switch)
- `WS /ws/status` - Real-time status stream

**Dependencies**: None (system frameworks only)

---

**Last Updated**: 2025-02-06 (Initial CLAUDE.md for iOS app)
