# Nexus

Nexus is an Elixir/OTP agent framework designed to be extensible, observable,
and easy to learn from while it is being built.

The project is currently in the first implementation phase:

- architecture and terminology are being stabilized
- a minimal end-to-end synchronous runtime path exists
- the next goal is the first real-provider smoke test

## Current Status

The repository currently includes:

- a bootable OTP application
- a passing test suite
- a minimal runtime path with:
  - `CLI Channel`
  - `Orchestrator`
  - `AgentLoop`
  - `ContextBuilder`
  - `FakeProvider`
  - `AnthropicProvider` (minimal, non-streaming)
  - in-memory `SessionStore`
  - in-memory `TranscriptStore`
- architecture notes and implementation plans
- project rules for step-by-step learning
- architecture diagrams for the current structure and flow

## Architecture At A Glance

```mermaid
flowchart LR
    User --> CLI[CLI Channel]
    CLI --> NexusRun[Nexus.run/3]
    NexusRun --> Orchestrator
    Orchestrator --> SessionStore
    Orchestrator --> TranscriptStore
    NexusRun --> ProviderInstance
    Orchestrator --> AgentLoop
    AgentLoop --> ContextBuilder
    ContextBuilder --> Provider
    AgentLoop --> Orchestrator
    Orchestrator --> NexusRun
    NexusRun --> CLI
```

## How One Turn Works

1. A channel normalizes external input into `Message.Inbound`.
2. `Nexus.run/3` builds a `ProviderInstance` from runtime configuration.
3. The `Orchestrator` resolves or creates the session.
4. The inbound user message is persisted in the transcript.
5. The `AgentLoop` receives the current session transcript.
6. The `ContextBuilder` turns the transcript into `Message.LLM[]`.
7. The provider adapter generates assistant content.
8. The `Orchestrator` persists the new transcript messages and builds `Message.Outbound`.

Provider-specific configuration is expected to come from external runtime
configuration, not from the provider adapter itself.

## Run the Baseline

Use these commands from the project root:

```bash
mix test
mix run -e 'Application.ensure_all_started(:nexus) |> IO.inspect()'
iex -S mix
```

## Project Docs

The working architecture and plan live in:

- `docs/architecture-notes.md`
- `docs/architecture-diagrams.md`
- `docs/implementation-plan-simple.md`
- `docs/implementation-plan-v0.md`
- `docs/project-rules.md`

## Read This Next

If you want to understand the runtime step by step, read these in order:

1. `docs/architecture-diagrams.md`
2. `lib/nexus.ex`
3. `lib/nexus/orchestrator.ex`
4. `lib/nexus/agent_loop.ex`
5. `lib/nexus/context_builder.ex`
6. `lib/nexus/provider.ex`

## Near-Term Goal

The next implementation target is a tiny manual smoke path for the Anthropic
provider, and it will continue to be built slowly and explicitly:

- one small file at a time
- with explanations of purpose and structure
- with diagrams updated as the runtime evolves
- with manual verification after each meaningful step
