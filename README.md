# PolyUI: Command & Control Interface

## Mission
To empower human operators with real-time situational awareness and explicit control over the autonomous trading system. PolyUI bridges the gap between opaque algorithmic decisions and human strategic intent.

## Architecture: The "Command Center"
We follow a hierarchical, list-based "Settings App" navigation pattern. This ensures density of information without overwhelming the operator. The application is divided into a Global HUD and four core functional sections.

### 0. Header: Global HUD
**Always visible summary of system health.**
*   **System Status**: 🟢 Active / 🔴 Halted (Visual heartbeat).
*   **Net Liquidity**: Real-time Total Equity (Cash + Positions).
*   **Day P&L**: Daily Profit/Loss with absolute value and percentage.

### 1. Intelligence (The "Eyes")
**Goal**: Visualize the external information stream the bot is consuming.
*   **Views**:
    *   **Live News Feed**: A scrolling list of ingested headlines (FinJuice, RSS).
    *   **Sentiment Analysis**: LLM-derived sentiment score (e.g., "Bullish 80%") displayed inline with each headline.
*   **Operations**:
    *   **Inspect**: Tap a headline to see specific Market Candidates generated from it.
    *   **Verify**: Check "Why did the bot think this was relevant?"

### 2. Treasury (The "Wallet")
**Goal**: Manage capital allocation and solvency.
*   **Views**:
    *   **Asset Breakdown**: Pie chart visualizing Cash vs. Invested Capital.
    *   **Allocation List**: Table showing capital assigned to each Strategy.
*   **Operations**:
    *   **Reallocate**: Edit the "Budget" for a specific strategy dynamically (e.g., "Move $500 from Cash to NewsMomentum").
    *   **Transfer**: (Future) Withdraw/Deposit instructions.

### 3. Strategies (The "Hands")
**Goal**: Monitor and control active trading logic.
*   **Views**:
    *   **Strategy List**: Overview of all deployed strategies (e.g., "NewsMomentum", "Arbitrage").
    *   **Detail View**:
        *   **State**: Idle / Processing / Trading.
        *   **Open Positions**: Specific breakdown of positions owned by this strategy.
*   **Operations**:
    *   **Pause (Soft Stop)**: Stop a specific strategy from opening *new* trades without closing existing ones.
    *   **Surgical Liquidate**: Trigger liquidation for *only* this strategy's positions (leaving others untouched).

### 4. Risk & System (The "Brain")
**Goal**: Safety enforcement and emergency controls.
*   **Views**:
    *   **Risk Metrics**: Real-time gauges for Max Drawdown and Daily Loss limits.
    *   **System Health**: Component connectivity status (DB, API, Executors).
*   **Operations**:
    *   **Global Kill Switch**: The "Nuclear Option". Instantly halts the entire engine.
        *   **Toggle**: "Liquidate All Open Positions" (Optional cleanup during halt).
    *   **Defcon Configuration**: Adjust global risk parameters (e.g., "Tighten Max Drawdown to 5%").

## Design Philosophy
-   **"Cockpit, not Engine"**: Displays state, does not calculate it.
-   **Client-Side Only**: Stateless frontend; relies entirely on `polyops` for data and action execution.
-   **Explicit Intent**: No implicit logic edits; all actions are clear commands sent to the `polyops` backend.

## System Boundaries
-   **Scope**: Frontend Visualization, Operator Dashboard.
-   **Out of Scope**: Backend Logic, Data Aggregation, Direct Database Access.
-   **Dependency**: Strictly coupled to `polyops` API via Cloudflare Tunnel.

---

## ⚠️ Operational Considerations

### Network Resilience

**WebSocket Connection Management**
- **Current**: Automatic reconnection with exponential backoff
- **Enhancement**: Display connection status indicator in UI
  - 🟢 Connected
  - 🟡 Reconnecting...
  - 🔴 Disconnected (with retry countdown)

**Offline Mode**
- **Current**: App requires active connection to PolyOps
- **Consideration**: Cache last-known system state for offline viewing
- **Limitation**: Control actions (kill switch) require online connection

### Error Handling & User Feedback

**Network Failures**
- **Pattern**: Show user-friendly error messages
  - ✅ "No internet connection" (not "URLError -1009")
  - ✅ "Server unreachable. Check VPN?" (not "Connection timeout")

**Action Confirmation**
- **Critical Actions**: Kill switch should require double confirmation
  ```swift
  .confirmationDialog("Emergency Halt", isPresented: $showingKillConfirmation) {
      Button("Halt System", role: .destructive) {
          Task { await triggerKillSwitch() }
      }
  }
  ```

### Security & Authentication

**Current State**
- No authentication (trust model)
- Endpoint URLs hardcoded in app

**Production Enhancements**
- **API Key**: Store securely in iOS Keychain
- **Biometric Auth**: Require Face ID/Touch ID for kill switch
- **Certificate Pinning**: Pin PolyOps TLS certificate to prevent MITM

**Pattern**:
```swift
import LocalAuthentication

func authenticateUser() async -> Bool {
    let context = LAContext()
    do {
        return try await context.evaluatePolicy(
            .deviceOwnerAuthenticationWithBiometrics,
            localizedReason: "Authenticate to halt trading system"
        )
    } catch {
        return false
    }
}
```

### Data Privacy

**No Sensitive Data Storage**
- ✅ App doesn't cache API keys or credentials
- ✅ No persistent storage of financial data
- ✅ WebSocket streams are ephemeral (not logged)

**GDPR Compliance**
- Operator IDs in kill switch requests
- **Consideration**: Allow users to clear operator ID from device

### Performance & Battery

**WebSocket Efficiency**
- **Current**: Persistent connection for real-time updates
- **Battery Impact**: Moderate (network activity keeps radio active)
- **Optimization**: Consider WebSocket heartbeat tuning (reduce frequency when app is backgrounded)

**SwiftUI Performance**
- Avoid expensive recomputations on every status update
- Use `@Observable` instead of deprecated `@ObservedObject` ✅

### Testing & Quality Assurance

**Manual Testing Checklist**
- [ ] Kill switch triggers system halt
- [ ] WebSocket reconnects after network interruption
- [ ] UI updates reflect real-time status changes
- [ ] Error messages are user-friendly
- [ ] App handles PolyOps downtime gracefully

**Automated Testing**
- **Current**: Build validation in CI ✅
- **Gap**: UI tests, mock API tests
- **Tool**: XCTest for UI automation

### Deployment & Distribution

**TestFlight Beta Testing**
- Internal testing before production release
- Gather feedback from operators on usability

**App Store Considerations**
- If distributing via App Store:
  - Ensure compliance with financial app guidelines
  - Disclose risk warnings (automated trading)

**Enterprise Distribution**
- Alternative: Ad-hoc or Enterprise provisioning (no App Store)
- Better for proprietary trading tools

---

## 📚 Documentation

See [CLAUDE.md](CLAUDE.md) for iOS development guidelines, SwiftUI patterns, and API integration details.
