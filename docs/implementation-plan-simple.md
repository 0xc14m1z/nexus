# Nexus Implementation Plan - Simple Vertical Slices

## Goal

This plan is intentionally optimized for:

- learning the architecture
- keeping code small at each stage
- testing the system manually as early as possible
- avoiding large scaffolding phases before seeing the runtime work

The project should become runnable in very small increments.
Each slice must produce a working end-to-end path, not just unit-testable modules.

## Architecture Recap

The current working architecture is:

### Core Runtime

- `Orchestrator`
- `AgentLoop`
- `ContextBuilder`
- `ToolExecutor`

### Core Ports

- `Channel`
- `Provider`
- `EventBus`
- `MessageStore`
- `SessionStore`
- `RuntimeEventStore`
- later: `MemoryStore`

### Identity Model

- `conversation_id` identifies external conversation scope
- `session_id` identifies the internal durable Nexus session
- `run_id` identifies a single execution run inside a session

### Message Model

- internal messages should use `content`, not only `text`
- `transport` is the canonical structured transport block
- `metadata` is a free map for adapter-specific details

### Persistence and Runtime Signaling

- `MessageStore` keeps transcript history
- `SessionStore` keeps the current operational snapshot
- `RuntimeEventStore` keeps append-only execution timeline events
- `EventBus` distributes live runtime events and is not the source of truth

### Observability Direction

- raw logs go to logs
- runtime events go to `RuntimeEventStore`
- sessions and transcript go to dedicated stores
- Phoenix should inspect structured persisted data, not parse raw logs
- runtime-level observability should be emitted through `:telemetry`
- channels may render or expose debug data, but they should not be the place where
  runtime observability originates

## Implementation Method

The main rule is:

1. define only the contracts needed for the next runnable slice
2. implement the smallest working adapter set
3. manually run the full slice
4. only then add the next layer

This means:

- no auto-discovery in the first slice
- no Redis in the first slice
- no Postgres in the first slice
- no Anthropic in the first slice
- no async tools in the first slice
- no subagents in the first slice

The architecture should allow those things, but the first implementation should not depend on them.

## Testing Philosophy

At the start, prioritize:

- manual end-to-end smoke tests
- small integration tests
- deterministic fake adapters

Do not start by writing large numbers of narrow unit tests for components that have
never been exercised together.

Each slice should answer:

- can we run it
- can we observe it
- can we explain what happened

## Slice 0 - Environment and Project Bootstrap

### Goal

Create a minimal Elixir project that can boot and be iterated on.

### Scope

- install Elixir and OTP locally
- `mix new nexus --sup`
- initialize Git
- add formatter
- create docs folders
- add a tiny smoke test

### Manual Proof

- `mix test`
- `iex -S mix`
- verify the application boots without runtime errors

### Why This Exists

Without this, nothing else is runnable.

## Slice 1 - Minimal Live Agent Path

### Goal

Make one user message travel through the whole runtime with the smallest possible architecture.

### Scope

- define `InboundMessage`
- define `OutboundMessage`
- define `transport`, `content`, and core ids
- define minimal behaviours for:
  - `Channel`
  - `Provider`
  - `EventBus`
  - `MessageStore`
  - `SessionStore`
  - `RuntimeEventStore`
- implement in-memory adapters for all of them
- implement `CLIChannel`
- implement `FakeProvider`
- implement minimal `Orchestrator`
- implement minimal `AgentLoop`

### What The System Must Do

- receive input from CLI
- derive `conversation_id`
- create or reuse a `session_id`
- create a `run_id`
- call `FakeProvider`
- emit an outbound reply
- persist inbound and outbound transcript
- persist runtime events
- update session snapshot

### Manual Proof

Run the app and type two messages in the same CLI conversation.
Verify that:

- the second message reuses the same session
- transcript exists in memory
- session snapshot exists in memory
- runtime timeline exists in memory
- the provider reply returns through the channel

### Why This Slice Matters

This is the first true proof that the architecture works.

## Slice 2 - Session Inspection from Inside the App

### Goal

Make the first slice inspectable, not just runnable.

### Scope

- add a simple inspect command or dev API
- print session transcript
- print session snapshot
- print runtime event timeline

### Manual Proof

After interacting through CLI, run an inspect command and verify that you can see:

- `session_id`
- transcript items
- runtime events in order
- current session snapshot

### Why This Slice Matters

If we cannot inspect the system early, we will not learn from it effectively.

## Slice 3 - Real Context Builder and Provider Call Records

### Goal

Make the LLM context explicit and inspectable.

### Scope

- implement `ContextBuilder`
- stop treating provider input as an ad hoc list built inline
- add immutable provider call or context snapshot persistence
- store:
  - selected message ids
  - system prompt version or content
  - effective provider payload
  - token estimate placeholders
- connect runtime events to these persisted artifacts

### Manual Proof

Send a multi-turn conversation, then inspect:

- what transcript existed
- what exact context was sent to the provider on each run
- which messages were selected

### Why This Slice Matters

This is the basis for later compaction, caching, and debugging decisions.

## Slice 4 - Durable Persistence with Postgres

### Goal

Swap in-memory stores for durable stores without changing the core runtime shape.

### Scope

- add `Ecto`
- add `Postgres` via `docker-compose`
- implement:
  - `PostgresMessageStore`
  - `PostgresSessionStore`
  - `PostgresRuntimeEventStore`
  - provider call/context persistence in Postgres
- keep in-memory adapters for tests and fast local experimentation

### Manual Proof

- run the app against Postgres
- interact through CLI
- restart the app
- verify that session, transcript, and runtime events are still inspectable

### Why This Slice Matters

It proves that ports and adapters are real, not theoretical.

## Slice 5 - Real Provider Adapter

### Goal

Replace `FakeProvider` with a real provider while preserving the architecture.

### Scope

- implement `AnthropicProvider` in non-streaming mode first
- normalize provider request and response
- persist provider call metadata
- keep `FakeProvider` available for deterministic testing

### Manual Proof

- run one real conversation through the CLI
- inspect transcript, runtime events, and provider call records

### Why This Slice Matters

We validate that the provider is an adapter, not a hidden dependency of the core.

## Slice 6 - First Tool Loop

### Goal

Turn the chat runtime into a real agent runtime.

### Scope

- define `Tool` behaviour
- add explicit tool registration first
- implement `ToolExecutor`
- add one or two tiny synchronous tools:
  - `echo_tool`
  - `file_list`
- support:
  - tool request
  - tool execution
  - tool result reinjection
- persist tool-related runtime events

### Manual Proof

- trigger a tool through the fake or real provider
- inspect transcript, tool events, and final answer

### Why This Slice Matters

This is where the system becomes an agent instead of a chat wrapper.

## Slice 7 - Phoenix Inspect UI

### Goal

Build a first-class internal inspection surface for learning and debugging.

### Scope

- create a small Phoenix app or Phoenix surface inside the project boundary
- add pages for:
  - sessions list
  - session detail
  - transcript
  - runtime timeline
  - provider calls and context snapshots
- keep it read-only at first

### Manual Proof

Run a conversation, open the Phoenix UI, and verify that you can inspect:

- transcript
- runtime event order
- session state
- provider inputs and outputs

### Why This Slice Matters

This makes the architecture visible and teaches us how the system actually behaves.

## Slice 8 - Live Runtime Updates

### Goal

Add live updates without changing the durable inspection model.

### Scope

- add a more formal `EventBus`
- start with in-process implementation if not already sufficient
- later add `RedisEventBus`
- let Phoenix subscribe to live runtime events for active session views

### Manual Proof

Open a session detail page and watch events appear live during a run.

### Why This Slice Matters

It separates historical inspection from real-time monitoring.

## Slice 9 - Hook System

### Goal

Add controlled extension points after the runtime is already understandable.

### Scope

- implement explicit hook points
- start with observer hooks
- then add transform hooks where needed
- keep policy hooks separate from generic lifecycle hooks

### Manual Proof

- add a logging hook or context-enrichment hook
- verify in runtime events and behavior that it executed as expected

### Why This Slice Matters

It keeps extensibility disciplined instead of magical.

## Slice 10 - Async Tools, Redis Bus, Subagents

### Goal

Add the more advanced concurrency features only after the synchronous core is solid.

### Scope

- async tool execution
- progress events
- Redis-backed event bus
- subagent spawning
- later memory compaction and caching strategies

### Manual Proof

Run a long task and observe:

- live progress
- durable runtime events
- correct session linkage

### Why This Slice Matters

These features are powerful but should not be introduced before the core is easy to understand.

## Explicit Deferrals

The following features should be intentionally deferred until the basic runtime is proven:

- plugin auto-discovery
- Redis as the first event bus
- Postgres as the first adapter
- streaming provider support
- async tool processes
- subagents
- memory compaction
- context caching
- approval workflows

## Definition of Success

The plan is working if:

- we can run a real end-to-end path very early
- every new slice stays inspectable
- the runtime remains explainable in terms of processes, stores, and events
- adapters can be swapped without rewriting the core
- we learn the architecture while building it
