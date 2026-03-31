# Nexus Project Rules

## Teaching-First Rule

This project is explicitly being built as a learning exercise.
That means implementation must optimize for understanding, not only speed.

## Working Rules

1. Build in very small steps.
2. Add as little code as possible before the next manual test.
3. Prefer adding one file at a time when the user is learning a new concept.
4. Explain what each new file is for, how it is structured, and how it fits into the runtime.
5. Keep diffs readable enough that the user can follow them step by step.
6. Prefer real runnable smoke tests over large batches of isolated unit tests.
7. Avoid introducing multiple new abstractions in the same step unless they are inseparable.
8. If the current code becomes too dense to follow, simplify before continuing.
9. After each meaningful architecture change, update `docs/architecture-diagrams.md`.
10. Prefer a small Mermaid diagram when it makes structure or runtime flow easier to understand.

## Practical Consequence

The project should be built as a sequence of tiny vertical and inspectable steps.
The user should be able to stop after each step and still understand what exists.
