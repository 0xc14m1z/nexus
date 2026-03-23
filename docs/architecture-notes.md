# Nexus Architecture Notes

## Status

This file captures architectural notes discussed during exploration.
These are not frozen decisions yet. They are working notes used to guide
discussion, planning, and later ADRs.

## Educational Goal

Nexus is not only a framework project. It is also an educational project.
That means the architecture should be:

- teachable
- inspectable
- modular
- explicit about boundaries

The design should help explain how agent systems work, not only make one work.

## Foundational View of the System

The recommended mental model is:

- an agent is a stateful process
- a session is the main unit of runtime organization
- the framework core is separate from infrastructure adapters
- the runtime is a process graph, not a monolithic request handler

The minimal runtime path is:

`Channel -> InboundMessage -> Orchestrator -> AgentLoop -> Provider -> OutboundMessage -> Channel`

This should be implemented first with the smallest possible vertical slice.

## Recommended Learning Sequence

To keep the system understandable, the first concepts to internalize are:

1. message
2. session
3. agent process
4. orchestration
5. fake provider
6. tool calling

Provider integration, async tools, subagents, and external channels should come later.

## Critique of Nanobot-Inspired Direction

Nexus should not inherit weaker architectural assumptions from nanobot.
In particular, we want stronger separation between:

- message history
- session state
- long-term memory
- runtime-only ephemeral process state

This is especially important for crash recovery, auditability, and educational clarity.

## State Model

The discussion so far suggests four distinct categories of state:

### 1. Message Log

Durable event history describing what happened.

Examples:

- inbound user message
- assistant reply
- tool call
- tool result
- progress event
- error event

### 2. Session State

Durable or semi-durable operational snapshot of where a session currently is.

Examples:

- session status
- current iteration count
- active capabilities
- selected provider/model
- active child jobs
- timestamps

### 3. Memory

Consolidated knowledge, not raw history.

Examples:

- user preferences
- project facts
- summary notes
- known entities

### 4. Runtime Ephemeral State

Live process state that should not be persisted directly.

Examples:

- pids
- monitor refs
- timers
- ports
- transient buffers

The key idea is:

- persist data needed to reconstruct runtime behavior
- do not attempt to persist process internals directly

## Persistence Direction

The current architectural preference is:

- persist messages
- persist session snapshots
- keep memory as a separate store
- keep runtime state in live OTP processes only

This implies a hybrid model:

- message log as narrative truth
- session snapshot as current operational truth

## Ports and Adapters Direction

A strong ports-and-adapters architecture is preferred.
In Elixir terms, the ports are mainly behaviours and the adapters are concrete modules.

The current direction is:

- core runtime logic stays concrete and domain-oriented
- boundaries to the outside world are adapter-based
- adapters should be small and specific, not a single mega-abstraction

### Core Domain Candidates

- `AgentLoop`
- `Orchestrator`
- `ContextBuilder`
- `ToolExecutor`
- `CapabilityPolicy`

### Port Candidates

- `Channel`
- `Provider`
- `EventBus`
- `MessageStore`
- `SessionStore`
- `MemoryStore`
- possibly `Scheduler`

### Adapter Examples

- `CLIChannel`
- `TelegramChannel`
- `FakeProvider`
- `AnthropicProvider`
- `InMemoryEventBus`
- `PhoenixPubSubEventBus`
- `RedisEventBus`
- `InMemoryMessageStore`
- `SQLiteMessageStore`
- `PostgresMessageStore`
- `FileMemoryStore`
- `SQLiteMemoryStore`

## Important Boundary Distinctions

The following distinctions are currently considered essential:

### EventBus is not Source of Truth

The bus exists for runtime communication and event distribution.
It should not become the authoritative persistence mechanism for state.

### MessageStore is not MemoryStore

Raw message history is different from long-term knowledge.

### SessionStore is not MessageStore

Operational snapshots are different from append-only history.

### Core Domain is not an Adapter Layer

Not everything should become pluggable.
The internal agent runtime should remain understandable and opinionated.

## Message Model Direction

The current direction is to avoid an overly chat-specific internal message model.

## Identifier Strategy Direction

There is an active refinement in progress around runtime identifiers.

### Current Concern

Using a single session-routing identifier may overload two different concerns:

- external routing or conversation scoping
- internal durable session identity

This can make the model harder to understand and harder to evolve.

### Current Preferred Direction

Current working decision:

- use `*_id` naming consistently
- avoid `*_key` naming in the public architecture language
- still keep different identifiers for different concepts

The current preferred direction is to distinguish at least three identifiers:

- `conversation_id`
- `session_id`
- `run_id`

### `conversation_id`

`conversation_id` identifies the external interaction scope used for routing or session resolution.

Examples:

- a Telegram private chat
- a Slack thread
- a CLI conversation scope

It is typically derived from channel and transport data.

It answers:

- where does this inbound event belong at the transport level
- which ongoing session, if any, should handle this message

### `session_id`

`session_id` is the opaque internal durable identity of a Nexus session.

It should likely be:

- generated by Nexus
- stable for the life of that session
- used by durable stores and foreign-key-style relationships

It answers:

- which internal session record is this
- which transcript, snapshots, and runtime artifacts belong together

### `run_id`

`run_id` identifies a single execution run or loop cycle within a session.

It answers:

- which specific attempt or iteration chain produced these events
- which provider call, tool chain, or error path belongs to the same execution

### Working Interpretation

At the moment, earlier `*_key` references should be treated as obsolete working placeholders.
The cleaner likely model is:

- `conversation_id` for routing
- `session_id` for durable session identity
- `run_id` for execution identity

This makes it easier to support cases such as:

- multiple sessions over time in the same external conversation
- `/new` creating a fresh session inside the same channel scope
- Phoenix inspection keyed by durable session identity
- runtime routing keyed by external conversation scope

### Possible Resolution Flow

A likely inbound flow is:

1. derive or normalize `conversation_id` from transport data
2. resolve the active `session_id` for that conversation, or create a new one
3. create a new `run_id` when execution starts

This gives the runtime a clearer identity model than using one key for everything.

### Transport scope vs session identity

These two concepts should remain distinct.

- a transport identifier such as `conversation_id` refers to where the message came from
  or where a reply should be delivered on a specific channel
- `session_id` is the internal runtime identity used to decide which agent/session state
  should handle the interaction

In the simplest cases they may be derived or resolved from each other, but they should
not be collapsed into the same concept.

Examples:

- one external chat may host multiple internal sessions over time
- a reset or `/new` command may create a new session inside the same chat
- thread-based channels may need transport identifiers that differ from internal session identity

### `metadata` vs structured transport fields

Current working decision:

- `transport` remains the canonical structured block for transport identifiers
- `metadata` remains an adapter-specific metadata map

Reasoning:

- the core needs stable semantics for routing, reply delivery, and session derivation
- a generic metadata bag alone makes the internal model too opaque
- adapters still need a place for channel-specific details that should not pollute the core schema

This means the system can remain both extensible and internally understandable.

### `text` vs `content`

The current direction is that `text` alone is too limiting for the long-term model.

The preferred internal representation is:

- `content` as the canonical field
- structured content parts for text, image, file, and future media types

Plain text convenience helpers may still exist, but the internal message model should
not assume all channels are text-only.

This matters both for channel extensibility and for provider/tool interoperability.

## External Extensibility

External extensibility is considered a first-class goal.
The preferred mechanism is:

- consumer projects depend on `nexus`
- consumer projects define modules implementing Nexus behaviours
- the core runtime interacts through those behaviours

This means extensibility should come from:

- custom channels
- custom providers
- custom tools
- custom storage adapters
- custom hooks
- custom policies where appropriate

The framework should avoid requiring YAML manifests or custom plugin registries
for basic extension scenarios.

### Working Direction for Extension Model

The current working distinction is:

- adapters replace infrastructure boundaries
- tools add operational capabilities to the agent
- hooks insert logic at specific lifecycle moments
- policies enforce security and approval rules

This distinction is considered important and should remain explicit in the public API.

## Hooks Direction

Hooks are considered valuable, but they should be treated as a precise extension
mechanism rather than a generic escape hatch.

Current position:

- yes to hooks
- no to undefined or overly magical hook behavior

Hooks should be:

- explicit
- lifecycle-based
- well-scoped
- documented
- testable

Candidate hook moments include:

- message received
- before context build
- after context build
- before provider call
- after provider call
- before tool execution
- after tool execution
- on progress
- on error
- before outbound send
- after outbound send
- on subagent spawn
- on subagent complete

There should be a clear distinction between:

- observer hooks
- mutating hooks
- veto or policy hooks

These should not all share the same semantics by default.

### Working Direction for Hook Semantics

The current working direction is:

- observer hooks should inspect only
- transform hooks should modify only well-defined payloads
- policy hooks should explicitly allow, deny, or require approval

The architecture should avoid a single omnipotent hook API that can do anything
from anywhere in the runtime.

## Observability Direction

Observability is a first-class architecture concern from the beginning, not a later
operations concern.

The educational goal is to make runtime behavior inspectable:

- what happened
- in what order
- inside which session
- inside which iteration
- through which tool or provider
- with what result

### Desired Observability Layers

The current direction is to have multiple complementary layers:

1. structured logs
2. telemetry events
3. execution timeline events
4. durable message and state persistence

These layers should not be collapsed into a single logging system.

### Structured Logs

Structured logs should exist from the first runnable slice.
They should include correlation fields such as:

- `conversation_id`
- `session_id`
- `run_id`
- `message_id`
- `agent_id`
- `iteration`
- `tool_name`
- `tool_call_id`
- `provider`
- `channel`

### Telemetry Events

Runtime actions should emit telemetry events that external systems can subscribe to.
This is useful for:

- metrics
- performance measurement
- tracing integration
- dashboards

### Execution Timeline

In addition to logs and telemetry, the system should likely produce explicit runtime
events describing lifecycle steps.

Candidate execution events:

- message received
- session loaded
- agent spawned
- agent resumed
- context built
- provider request started
- provider response received
- tool requested
- tool started
- tool progress
- tool completed
- tool failed
- subagent spawned
- subagent completed
- outbound message queued
- outbound message sent
- session snapshot persisted

This execution timeline is especially valuable for understanding exactly what the
agent did during development and debugging.

### Durable Runtime Insight

There is a strong preference to preserve enough durable information to reconstruct
what happened after crashes or failures.

This does not mean persisting raw process internals.
It means persisting enough structured events and state transitions to explain runtime behavior.

### Practical Consumption Direction

The current working direction is that observability data should be consumable in
more than one way, depending on the question being asked:

- logs answer "what did the system print while it was running"
- telemetry answers "how often and how long did things happen"
- execution events answer "what exactly happened in this run"
- persisted session and message data answer "what state did the system end up in"

The architecture should therefore avoid relying on logs alone as the debugging interface.

### Working Product Direction for Observability

There is interest in a practical local stack for observing Nexus during development.
The current idea under exploration is:

- containerized supporting services via `docker-compose`
- durable storage for execution data
- a Phoenix internal app or dashboard surface for visualization

This suggests a likely split between:

- raw operational logs
- queryable execution timeline
- session and message persistence
- live or near-live UI for inspecting a session run

### Early Recommendation

The current recommendation is not to collapse everything into one storage system.
Instead:

- use one path for raw logs
- use one path for structured execution events
- use one path for durable domain persistence

A likely future stack could include:

- Postgres or SQLite for domain and execution records
- Loki for raw logs
- Grafana for metrics and log exploration
- Phoenix for agent/session-aware runtime visualization

This is not yet a final decision, but the direction is to make observability
developer-friendly from the start.

### Persist and Publish Direction

The current working direction is that important runtime actions should both:

- be persisted as durable structured data when they matter for history or reconstruction
- be published on the event bus when they matter for live reactions or streaming visibility

This means persistence and event publication are complementary, not competing ideas.

The intended distinction is:

- stores are for durable truth and queryability
- the event bus is for runtime propagation

### Working Event Flow

A likely event flow is:

1. normalize inbound transport payload into internal message form
2. persist the inbound message if it belongs to durable history
3. append execution events for important lifecycle steps
4. update session snapshot when operational state changes
5. publish corresponding runtime events to the event bus
6. let UI or other consumers subscribe for live updates

This allows:

- Postgres-backed history and inspection
- Redis-backed or local bus distribution
- Phoenix UI reading durable data while optionally subscribing to live updates

### Phoenix Consumption Direction

The current direction for a Phoenix internal app is:

- query Postgres for durable views such as sessions, messages, and execution timelines
- optionally subscribe to runtime events for live tail behavior

This means Phoenix should not depend on raw logs as its primary data source.
It should be domain-aware and read structured persistence records first.

### Reliability Note

If we need stronger guarantees later, we may introduce an outbox-style pattern so that
durable writes and bus publication stay consistent.

For now, the key architectural idea is that durable persistence and live event
distribution should remain separate but aligned concerns.

## Event Store Direction

There is active interest in an event-oriented persistence layer for runtime lifecycle data.

### Current Position

An event store is considered useful, but only if its scope is defined clearly.

The current preferred interpretation is:

- store append-only execution and lifecycle events
- keep it separate from the runtime event bus
- do not assume full event sourcing for the whole domain from day one

### Naming Consideration

Current working decision:

- prefer the name `RuntimeEventStore`

Reasoning:

- `EventStore` suggests full event sourcing too early
- `RuntimeEventStore` is more explicit about scope
- it preserves the option to evolve toward stronger event-sourcing patterns later

### Relationship to Other Stores

The current working distinction is:

- `MessageStore` stores durable transcript and message history
- `SessionStore` stores current operational snapshots
- `RuntimeEventStore` stores append-only lifecycle events for observability and reconstruction support

Some events may reference messages or sessions, but these stores should not be collapsed
into one abstraction unless we consciously choose an event-sourced architecture later.

## Context Assembly and Inspectability

There is a strong requirement to inspect, after the fact, what context was actually sent
to the LLM at each step.

This is important for:

- debugging
- prompt quality analysis
- compaction strategy design
- cache strategy design
- post-mortem analysis from Phoenix

### Current Working Direction

The current direction is:

- do not treat session context as a single mutable blob stored in one place
- build context on each LLM call from durable sources
- persist an immutable snapshot of the effective context used for each provider call

### Source of Context

The effective LLM context is expected to be assembled from multiple inputs:

- system prompt and its version or hash
- relevant session messages
- tool call and tool result messages if included in the conversation model
- memory facts or journal entries
- compaction artifacts or summaries
- runtime policy or hook contributions

### SessionStore Responsibility

The `SessionStore` should not be the full prompt history store.
Its main role is to keep the current operational session state and references needed to
reconstruct or continue execution.

Examples of likely session snapshot fields:

- `session_id`
- `conversation_id`
- current status
- active run id
- current iteration
- last processed message sequence
- active compaction generation
- references to active summaries
- last known provider/model
- timestamps

This means `SessionStore` primarily answers:

- where are we now
- what should the next run resume from

### MessageStore Responsibility

The `MessageStore` is the durable transcript history.
It answers:

- what conversation items exist in this session
- in what order they happened
- which items are user, assistant, tool call, or tool result messages

It is not the operational snapshot of the session.

### Need for Immutable Context Snapshots

Reconstructing old LLM context only from current stores is not sufficient, because:

- memory may change
- compaction may replace or summarize old messages
- system prompts may evolve
- hook outputs may differ over time

Therefore, if historical inspectability matters, the effective context for each provider
call should be snapshotted immutably.

### Likely Additional Artifact

There is a likely need for a dedicated persisted artifact such as:

- `ContextSnapshot`
- `ProviderCallRecord`
- or another similarly named immutable run artifact

This artifact would store:

- the normalized content sent to the provider
- source references used to build it
- prompt or system versions
- selected message ids
- selected memory ids or revisions
- compaction generation
- token estimates
- cache metadata
- provider response payload or a reference to it

### Relationship to RuntimeEventStore

The `RuntimeEventStore` should record that a context was built and that a provider call
started or completed.

The heavy context payload itself should likely live in a dedicated artifact record and be
referenced by runtime events, rather than duplicated into every event row.

### Phoenix Inspection Direction

The current direction for Phoenix session inspection is:

- timeline from `RuntimeEventStore`
- transcript from `MessageStore`
- current operational state from `SessionStore`
- exact LLM context and provider exchanges from immutable context/provider call artifacts

This gives both:

- live and historical execution visibility
- the ability to inspect what the model actually saw at any point in time

### Compaction and Cache Analysis

Because immutable context snapshots are preserved, Phoenix can later help answer:

- which messages were included before and after compaction
- whether a summary replaced raw history
- whether a context build was served from cache
- how token usage changed over time
- what exact input led to a bad response

## Working Infrastructure Mapping

The current working mapping between ports and infrastructure is:

- Postgres as implementation for durable/queryable stores
- Redis as implementation for runtime event distribution
- Loki as raw log storage
- Grafana as log and metrics exploration surface
- Phoenix internal UI as domain-aware inspection surface

### Postgres Direction

Postgres is currently preferred as an adapter for one or more of:

- `SessionStore`
- `MessageStore`
- `ExecutionStore`
- possibly `MemoryStore`

Reasoning:

- durable persistence
- relational querying
- indexing
- auditability
- strong Phoenix and Ecto fit
- good support for structured payloads via JSONB

### Redis Direction

Redis is currently preferred as an adapter candidate for:

- `EventBus`
- possibly future queue or coordination concerns

Reasoning:

- fast runtime fan-out
- good fit for distributed signaling
- useful when multiple nodes need to react to the same runtime event

Current architectural constraint:

- Redis should not become the canonical source of truth for agent state
- EventBus remains separate from durable persistence concerns

### Current Working Decision

The working direction is:

- Postgres-backed persistence adapters
- Redis-backed event bus adapter

This is not yet a frozen ADR, but it is the preferred architecture direction.

## Open Questions Captured Here

The discussion has surfaced these active architecture questions:

1. what are the exact core ports for v1
2. what is the right persistence model for messages and session state
3. how should external extensions be discovered or registered
4. which hook points may mutate payloads and which may only observe
5. where should message-based communication stop and direct function calls begin
6. how observability events differ from business messages and persistence records
7. what the minimal useful local observability stack should be

## Suggested Next Focus

The next useful design topic is the extension model itself:

- what "extensible from outside" means concretely
- which extension points are stable public API
- how hooks differ from adapters and tools

That conversation should happen before freezing plugin discovery.
