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
