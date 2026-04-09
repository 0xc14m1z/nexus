# Nexus Implementation Plan v0

## Purpose

This document turns the architectural brief into an executable implementation plan.
It is intentionally written as a `v0` plan: concrete enough to start work, but still
structured around a set of open decisions that we will discuss before locking the
architecture.

The main goal is not only to build `nexus`, but to understand how an extensible
agent framework works end to end:

1. how messages enter the system
2. how they are routed to an agent process
3. how the agent loop builds context and calls the LLM
4. how tools are discovered, filtered, and executed
5. how state, memory, and subagents fit into OTP

## Current State

The repository is currently empty.

The local machine also does not currently have:

- `elixir`
- `mix`
- `erl`

That means the real implementation starts with environment bootstrap and project
creation, not with the agent loop itself.

## Product Boundaries

`nexus` is the base framework:

- OTP application
- agent runtime
- message bus
- plugin contracts
- minimal built-in tools
- base provider adapters
- base channel support
- memory abstraction

Consumer projects such as `nexus-dev` live outside the framework and add:

- external CLI tools
- domain-specific channels
- repo management
- workflow composition
- custom hooks
- custom policies

## Design Principles

1. Every milestone must produce something runnable or testable.
2. Behaviours are the public API of the framework.
3. OTP supervision is the default failure model.
4. Capabilities are allow-lists, not exclusions.
5. Provider-specific formats must not leak into core runtime logic.
6. Long-lived runtime components communicate by messages.
7. Consumer extensions should be plain modules, not registry files or YAML.

## Architecture Map

The system will be designed in these runtime layers:

1. `Channel`
   Converts external events into `Nexus.Message.Inbound` and sends outbound replies.

2. `Bus`
   Delivers inbound, outbound, progress, and control events across runtime components.

3. `Orchestrator`
   Owns agent process lifecycle and routes messages from `conversation_id` to `session_id`.

4. `AgentLoop`
   Runs the ReAct loop: build context, call provider, execute tools, continue or answer.

5. `Provider`
   Talks to a concrete LLM API while exposing a provider-neutral behaviour to the core.

6. `Tool Runtime`
   Executes synchronous tools directly and asynchronous tools as supervised processes.

7. `Session Store`
   Holds short-term conversation state.

8. `Memory`
   Holds long-term facts and journal-like data behind an adapter.

9. `Hooks / Telemetry`
   Exposes observability and controlled extension points around runtime events.

Observability note:

- structured runtime observability should be emitted from the runtime layers via
  `:telemetry`
- channels may display or forward those diagnostics, but should not be the
  primary source of structured runtime events

## Recommended Implementation Order

The order below intentionally differs slightly from the original brief.
The key change is introducing a local, deterministic vertical slice before integrating
Anthropic. This makes the agent runtime understandable earlier and reduces cost,
latency, and ambiguity during development.

### Milestone 0 - Bootstrap

Goal: create a working Elixir project and a basic development baseline.

Tasks:

- install Elixir and Erlang/OTP locally
- choose installation path (`asdf`, `mise`, or Homebrew)
- initialize the project with `mix new nexus --sup`
- initialize Git
- add `.formatter.exs`
- create a minimal test file and confirm `mix test`
- create `docs/` and `docs/adr/` for architecture notes

Exit criteria:

- `mix test` runs successfully
- the OTP app boots
- the repo has a minimal but stable development baseline

Learning outcome:

- understand how an Elixir OTP app is structured before agent-specific logic begins

### Milestone 1 - Core Contracts

Goal: define the core types and interfaces that the rest of the system depends on.

Tasks:

- define `Nexus.Message.Inbound`
- define `Nexus.Message.Outbound`
- define `Nexus.Tool.Context`
- define behaviours:
  - `Nexus.Tool`
  - `Nexus.Channel`
  - `Nexus.Provider`
  - `Nexus.Hook`
  - `Nexus.Memory`
- define a provider-neutral internal message model for LLM interactions
- define capability names and filtering rules
- define config structs or validation layer

Exit criteria:

- all core contracts compile
- tests validate basic behaviour contracts and capability checks
- the internal LLM format is documented well enough to implement providers against it

Learning outcome:

- understand where extensibility really lives in the framework

### Milestone 2 - Local Vertical Slice

Goal: make the runtime flow visible without a real remote LLM.

Tasks:

- add message bus support with `Phoenix.PubSub`
- create `Nexus.Agent.Orchestrator`
- create a first `Nexus.Agent.Loop`
- create a basic ETS-backed session store
- create a minimal CLI channel
- implement `Nexus.Provider.Fake`
- wire the path:
  - CLI input
  - inbound message
  - orchestrator routing
  - agent loop execution
  - fake provider response
  - outbound reply

Exit criteria:

- a user can type into the CLI and receive a response through the full runtime path
- a session is created and reused for the same `conversation_id`

Learning outcome:

- understand the runtime as a process graph, not as a single function call

### Milestone 3 - Tool Execution Path

Goal: add real tool invocation inside the loop.

Tasks:

- implement plugin registry and lookup
- implement initial discovery strategy
- filter tools by capability set
- support tool call -> tool result -> loop continuation
- add minimal built-in tools:
  - `file_list`
  - `file_read`
  - optional `echo_tool` for deterministic testing
- define error feedback rules when a tool fails
- add iteration limits and loop timeouts

Exit criteria:

- the fake provider can request a tool
- the tool executes
- the result is fed back into the loop
- the loop can continue and produce a final answer

Learning outcome:

- understand the core dynamic that makes an "agent" different from plain chat

### Milestone 4 - Anthropic Provider

Goal: replace the fake provider path with a real provider adapter while keeping the
runtime core provider-neutral.

Tasks:

- implement `Nexus.Providers.Anthropic`
- map internal message model to Anthropic request format
- map Anthropic response format back to the internal model
- implement non-streaming `chat/3`
- add retries and error normalization
- add token accounting hooks or placeholders
- add streaming support after non-streaming is stable

Exit criteria:

- the runtime can talk to Anthropic through the provider behaviour
- the core loop does not need Anthropic-specific logic

Learning outcome:

- understand how to isolate provider-specific complexity from the framework core

### Milestone 5 - Memory and Context

Goal: add short-term and long-term context in a way that is adapter-friendly.

Tasks:

- implement default memory adapter
- add facts API
- add journal API
- persist journal entries to files
- load recent journal into context builder
- add memory recall tool(s)
- decide when memory consolidation runs

Exit criteria:

- the agent can store and retrieve simple long-term information
- recent session or journal context can influence prompt assembly

Learning outcome:

- understand the difference between session state, memory, and prompt context

### Milestone 6 - Async Tools and Ports

Goal: support long-running tools as supervised processes.

Tasks:

- support `{:async, module, args, ctx}` execution flow
- spawn async tools under a supervisor
- stream progress messages over the bus
- add timeout and cancellation support
- implement one reference async tool pattern using `GenServer` + `Port`

Exit criteria:

- an async tool can run, stream progress, finish, and deliver its result back
- async tool failures are visible and supervised cleanly

Learning outcome:

- understand why OTP is a better fit than a thread-based model for long-running tools

### Milestone 7 - Subagents

Goal: support nested agent execution with isolated capabilities and state.

Tasks:

- distinguish clearly between async tool process and subagent
- implement subagent spawn path
- isolate tool registry by capability set
- isolate working context
- route completion events back to the parent session
- add cancellation propagation

Exit criteria:

- a parent agent can spawn a child agent and receive its result
- child capabilities are narrower than parent capabilities

Learning outcome:

- understand how agent hierarchies map naturally onto OTP supervision trees

### Milestone 8 - Hooks and Telemetry

Goal: make the framework observable and extensible around events.

Tasks:

- implement hook registry
- dispatch hook events around:
  - inbound message
  - pre LLM call
  - post LLM call
  - pre tool
  - post tool
  - error
  - outbound message
- decide whether hooks can mutate payloads or only observe
- add telemetry events for runtime tracing

Exit criteria:

- consumer code can observe or modify selected lifecycle events
- we can trace what the runtime is doing without attaching a debugger

Learning outcome:

- understand how to add extension points without turning the system into spaghetti

### Milestone 9 - Packaging and Consumer Example

Goal: make the framework distributable and prove that the framework/consumer split is real.

Tasks:

- add release configuration
- add a Dockerfile for the base framework image
- define runtime config expectations
- create a first minimal consumer example
- document how a consumer project adds a tool or channel

Exit criteria:

- the framework can be packaged and run predictably
- a consumer app can add behaviour modules without touching the core

Learning outcome:

- understand where the boundary between framework and distribution really sits

## Cross-Cutting Workstreams

These concerns should be reviewed throughout the milestones:

1. Testing strategy
   - unit tests for contracts and filtering
   - integration tests for loop behaviour
   - provider adapter tests with fixtures
   - async tool tests with timeouts and failure cases

2. Observability
   - structured logs
   - telemetry events
   - traceability by `session_id` and `run_id`

3. Security model
   - tool capability filtering
   - shell command policy
   - path restrictions
   - approval gates for dangerous actions

4. Documentation
   - ADRs for major decisions
   - module docs
   - examples for consumer implementers

## Open Decisions

These are the main questions we should discuss one by one before the plan is frozen.

### Q1 - Plugin Discovery Strategy

Should discovery be based on:

- loaded modules only
- modules declared in loaded applications
- an explicit registration API
- a hybrid approach

Why it matters:

The wrong choice either makes discovery unreliable or makes the framework less ergonomic.

### Q2 - Internal LLM Message Model

Do we define a normalized internal message format such as:

- `system`
- `user`
- `assistant`
- `tool_call`
- `tool_result`
- structured content parts

Why it matters:

Without this layer, provider-specific formats leak into the agent runtime and reduce extensibility.

### Q3 - Boundary for Message-Based Communication

Which components must communicate through PubSub and which may call each other directly?

Why it matters:

If everything becomes PubSub, the system gets noisy and hard to follow.
If everything becomes direct calls, we lose process isolation and event traceability.

### Q4 - Capability Model

Should capabilities be:

- flat atoms only
- hierarchical
- role-based presets on top of flat atoms

Why it matters:

Tool filtering becomes security-critical as soon as subagents and shell access exist.

### Q5 - Session Lifecycle

Does one `AgentLoop` process live:

- for the duration of a session
- until idle timeout
- for a single request only

Why it matters:

This decision affects memory use, session recovery, and how "stateful" an agent truly is.

### Q6 - Tool Call Concurrency

If a provider returns multiple tool calls at once, do we execute them:

- serially
- concurrently
- serially first, concurrent later

Why it matters:

Concurrency changes ordering, error handling, and output interpretation.

### Q7 - Async Tool vs Subagent Contract

When do we model work as:

- an async tool process
- a child agent loop

Why it matters:

These are different architectural concepts and should not collapse into one abstraction.

### Q8 - Memory Consolidation Timing

When does long-term memory extraction happen:

- after every conversation turn
- after significant milestones
- on explicit command
- as a scheduled background task

Why it matters:

This affects cost, quality, and how noisy memory becomes.

### Q9 - Shell and Filesystem Guardrails

What is the initial security posture for:

- allowed commands
- working directory restrictions
- write permissions
- approval gates

Why it matters:

Security controls are easiest to design before tool interfaces spread through the codebase.

### Q10 - Base Framework Scope

What must exist in `nexus` from day one, and what should wait for the first consumer?

Why it matters:

If the base grows too fast, the framework becomes opinionated and heavy before its API stabilizes.

## Proposed Discussion Order

To avoid thrashing, the recommended order for discussion is:

1. Q2 - internal LLM message model
2. Q1 - plugin discovery strategy
3. Q5 - session lifecycle
4. Q4 - capability model
5. Q7 - async tool vs subagent
6. Q3 - message bus boundaries
7. Q9 - security posture
8. Q8 - memory consolidation timing
9. Q6 - tool concurrency
10. Q10 - base framework scope

The reason for this order is simple: the first five decisions shape the core runtime
interfaces. The later questions can be decided once the skeleton is clearer.

## Immediate Next Tasks

Once we agree on the first open decisions, the first concrete tasks should be:

1. install Elixir/OTP
2. scaffold the Mix project
3. write ADR-001 for the internal LLM message model
4. write ADR-002 for plugin discovery
5. write ADR-003 for session lifecycle
6. implement the contract layer from Milestone 1

## Notes

This plan should remain a living document.
As we discuss each open decision, we should either:

- update this file directly, or
- capture the decision in an ADR and reference it here

The main success criterion is not just "framework compiles".
It is that the architecture remains teachable, extensible, and understandable while it grows.
