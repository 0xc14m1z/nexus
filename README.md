# Nexus

Nexus is an Elixir/OTP agent framework designed to be extensible, observable,
and easy to learn from while it is being built.

The project is currently in the first implementation phase:

- architecture and terminology are being stabilized
- the Mix project baseline is in place
- the next goal is the first minimal end-to-end agent slice

## Current Status

The repository currently includes:

- a bootable OTP application
- a passing baseline test suite
- architecture notes and implementation plans
- project rules for step-by-step learning

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
- `docs/implementation-plan-simple.md`
- `docs/implementation-plan-v0.md`
- `docs/project-rules.md`

## Near-Term Goal

The next implementation target is still the first minimal live vertical slice,
but it will now be built more slowly and explicitly:

- one small file at a time
- with explanations of purpose and structure
- with manual verification after each meaningful step
