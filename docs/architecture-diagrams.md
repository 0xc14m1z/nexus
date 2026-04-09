# Nexus Architecture Diagrams

This file exists to keep the project understandable as it evolves.

When the runtime changes in a meaningful way, this file should be updated so the
current structure and flow can be inspected quickly before reading code.

## Current Runtime Structure

```mermaid
flowchart LR
    User[User]
    CLI[CLI Channel]
    Runtime[Nexus.run/2]
    Inbound[Message.Inbound]
    Orchestrator[Orchestrator]
    SessionStoreInstance[SessionStoreInstance]
    TranscriptStoreInstance[TranscriptStoreInstance]
    SessionStore[SessionStore]
    TranscriptStore[TranscriptStore]
    ProviderInstance[ProviderInstance]
    AgentLoop[AgentLoop]
    ContextBuilder[ContextBuilder]
    SystemPrompt[priv/prompts/system.md]
    LLMMessages[Message.LLM[]]
    Provider[Provider Adapter]
    Result[AgentLoop.Result]
    Outbound[Message.Outbound]

    User --> CLI
    CLI --> Inbound
    Inbound --> Runtime
    Runtime --> SessionStoreInstance
    Runtime --> TranscriptStoreInstance
    Runtime --> ProviderInstance
    Runtime --> Orchestrator
    Orchestrator --> SessionStoreInstance
    Orchestrator --> TranscriptStoreInstance
    SessionStoreInstance --> SessionStore
    TranscriptStoreInstance --> TranscriptStore
    ProviderInstance --> Provider
    Orchestrator --> AgentLoop
    TranscriptStore --> AgentLoop
    AgentLoop --> ContextBuilder
    ContextBuilder --> SystemPrompt
    ContextBuilder --> LLMMessages
    LLMMessages --> Provider
    Provider --> ProviderInstance
    ProviderInstance --> AgentLoop
    AgentLoop --> Result
    Result --> Orchestrator
    Orchestrator --> Outbound
    Outbound --> CLI
```

## Current Single-Turn Flow

```mermaid
sequenceDiagram
    participant U as User
    participant C as CLI Channel
    participant R as Nexus.run/2
    participant O as Orchestrator
    participant SSI as SessionStoreInstance
    participant TSI as TranscriptStoreInstance
    participant S as SessionStore
    participant T as TranscriptStore
    participant PI as ProviderInstance
    participant A as AgentLoop
    participant B as ContextBuilder
    participant P as Provider Adapter

    U->>C: raw input
    C->>R: Message.Inbound
    R->>PI: build provider instance from runtime config
    R->>SSI: build session store instance
    R->>TSI: build transcript store instance
    R->>O: run(inbound, provider_instance, session_store_instance, transcript_store_instance)
    O->>SSI: get/save session
    SSI->>S: delegate
    S-->>O: session
    O->>TSI: append Transcript.User
    TSI->>T: delegate
    O->>TSI: list_by_session(session_id)
    TSI->>T: delegate
    T-->>O: transcript history
    O->>A: run(session_id, transcript, provider_instance)
    A->>B: build_messages(transcript)
    B-->>A: system + transcript as Message.LLM[]
    A->>PI: generate(messages)
    PI->>P: adapter.generate(messages, config)
    P-->>PI: assistant content
    PI-->>A: assistant content
    A-->>O: AgentLoop.Result
    O->>TSI: append transcript messages from result
    TSI->>T: delegate
    O-->>C: Message.Outbound
    C-->>U: rendered output
```

## Current Message Layers

```mermaid
flowchart TD
    Inbound[Message.Inbound<br/>transport boundary]
    Outbound[Message.Outbound<br/>transport boundary]
    Transcript[Message.Transcript.*<br/>persisted session history]
    LLM[Message.LLM<br/>provider-facing format]

    Inbound --> Transcript
    Transcript --> LLM
    LLM --> Outbound
```

## Current Responsibilities

- `Channel`
  normalizes external input into `Message.Inbound` and delivers `Message.Outbound`
- `Orchestrator`
  resolves the session, persists transcript boundaries, and coordinates one turn
- `Nexus.run/2`
  reads runtime config, builds provider/session/transcript store instances, and delegates to the orchestrator
- `ProviderInstance`
  wraps a provider adapter plus resolved config so the agent loop does not deal with setup concerns
- `SessionStoreInstance`
  wraps a session store adapter plus resolved config so the orchestrator does not know storage setup details
- `TranscriptStoreInstance`
  wraps a transcript store adapter plus resolved config so the orchestrator can persist transcript entries uniformly
- `ToolInstance`
  wraps one configured tool adapter and records whether it came from `system_tools` or runtime `tools`
- `AgentLoop`
  executes one turn against the provider and returns assistant output plus transcript items
- `ContextBuilder`
  turns persisted transcript into provider-facing `Message.LLM[]`
- `SessionStore`
  persists session snapshots
- `TranscriptStore`
  persists canonical session history
- `Provider`
  turns `Message.LLM[]` into assistant content
- `Tool`
  exposes a provider-facing definition plus executable behavior

## Current Limitations

- tools are configured and validated, but they are not yet connected to the provider path or the agent loop
- `ContextBuilder` currently supports only transcript messages of type:
  - `Message.Transcript.User`
  - `Message.Transcript.Assistant`
- tool-related transcript messages are defined, but not yet consumed by the builder
- the current provider path is still synchronous and non-streaming
- the default runtime config still uses in-memory stores and the fake provider

## Next Likely Step

The next planned implementation step is:

- use the new file-backed stores in a real manual Anthropic smoke path
- then pressure-test the provider abstraction with a second real adapter
