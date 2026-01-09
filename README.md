# PolyUI: Command & Control Interface

## Mission
To empower human operators with real-time situational awareness and explicit control over the autonomous trading system. PolyUI bridges the gap between opaque algorithmic decisions and human strategic intent.

## Core Capabilities

### 1. Situational Awareness (Visibility)
Provides specific, actionable insights with <5s latency.
- **Live Battlemap**: Real-time visualization of Active positions, Working orders, and PnL velocity.
- **Signal Explainability**: Human-readable context for every trade. ("Why did we buy?", "What key news triggered this?", "What is the LLM's confidence?").
- **Battle Damage Assessment**: Realized PnL analysis relative to benchmarks and risk limits.

### 2. Operational Control (Intervention)
Safe, explicit control surfaces for managing the autonomy levels.
- **Defcon Levels**: One-click configuration changes (e.g., "Full Autonomy" vs "Require Confirmation" vs "Halt").
- **Panic Button**: Immediate, privileged override to cancel all orders and flatten positions.
- **Risk Configuration**: Runtime adjustment of allocation caps and drawdown limits (within hard bounds).

### 3. Workflow Integration
- **Notification Triage**: Unified inbox for system alerts requiring acknowledgement.
- **Confirmation Flow**: Interface for "Human-in-the-loop" strategies requiring manual sign-off before execution.

## Design Philosophy
- **"Cockpit, not Engine"**: Displays state, does not calculate it.
- **Client-Side Only**: Stateless frontend; relies entirely on `polyops` for data and action execution.
- **Explicit Intent**: No implicit logic edits; all actions are clear commands sent to the `polyops` server.

## System Boundaries
- **Scope**: Frontend Visualization, Operator Dashboard.
- **Out of Scope**: Backend Logic, Data Aggregation, Direct Database Access.
- **Dependency**: Strictly coupled to `polyops` API. Does not talk to `polymind` directly.
