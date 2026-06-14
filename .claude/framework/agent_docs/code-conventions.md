# Code Conventions

<!-- TEMPLATE: Populate this with your project's naming conventions, patterns, and style rules. -->
<!-- This is what the Reviewer checks against. Keep it concrete and actionable. -->
<!-- This is a LIVING document — update it when new stable patterns emerge during implementation. -->
<!-- The guidance below is stack-neutral starter text; refine it for your language and domain. -->

## Domain Language

List the project's core terms so agents use them consistently. Reference the
contracts source (ECOSYSTEM.md or `contracts/`) for contract-level terminology.

| Concept | Correct Term | Do NOT Use |
| ------- | ------------ | ---------- |
| <!-- example --> The thing users create | workspace | project, space, environment |

## Naming

Follow the language's idiomatic conventions by default. Document only the
project-specific overrides here.

- **TypeScript / JavaScript:** `camelCase` for variables & functions, `PascalCase` for types & React components, `kebab-case` for filenames, `SCREAMING_SNAKE_CASE` for module-level constants
- **Python:** `snake_case` for functions & variables, `PascalCase` for classes, `snake_case.py` for modules
- **Go:** `MixedCaps` (exported) / `mixedCaps` (package-private); short receiver names; no underscores
- **C# / .NET:** `PascalCase` for public members & types, `camelCase` for parameters & locals, `_camelCase` for private fields
- **Rust:** `snake_case` for functions & variables, `PascalCase` for types, `SCREAMING_SNAKE_CASE` for constants

<!-- Record any project-specific deviations from the above. -->

## File Organisation

- One primary export per file when possible
- Colocate tests with source OR use a parallel `tests/` tree — pick one and document it here
- Group files by feature/module rather than by type (e.g., `users/` with its routes, service, tests; not separate `routes/` and `services/` trees)

<!-- Document the project's actual choice. -->

## Error Handling

- Validate at boundaries (user input, external API responses, deserialised config); trust internal types
- Prefer typed/enumerated error shapes over stringly-typed errors
- Fail loudly at startup (missing config, unreachable dependencies); fail gracefully at runtime (retries, fallbacks) — never swallow exceptions silently
- Error shapes at API boundaries should match the contracts in ECOSYSTEM.md (or `contracts/`)

## Logging

- Use the project logger, never `console.log` / `print()` / `fmt.Println` in committed code
- Structured logging preferred (key-value pairs or JSON) over string concatenation — aids grepping + observability tooling
- Do not log secrets, full request bodies, or PII without sanitisation
- Log levels: `error` for broken invariants, `warn` for recoverable issues, `info` for lifecycle events, `debug` for dev-time detail

## Imports

- Group imports: stdlib → third-party → first-party → relative (language formatters usually enforce this)
- Use absolute imports / path aliases where the language supports them (`@/` in TS, explicit package imports in Python/Go)
- Avoid deep relative paths (`../../../`) — refactor to a shared module or restructure directories

## Shared Utilities & Helpers

List the project's shared utilities here so agents reuse them instead of
creating duplicates. Update this list whenever a new stable helper lands.

<!--
Examples:
- Use `asyncHandler()` from `src/lib/async-handler.ts` for all async route handlers.
- Use the shared date formatter from `src/lib/format.ts`; don't write your own.
- Use `with_transaction()` from `app/db/tx.py` rather than opening sessions directly.
-->

## Patterns to Follow

Document the architectural patterns this project commits to, so agents don't
invent parallel styles. Examples:

- Repository pattern for data access (no raw DB queries in request handlers)
- Middleware for cross-cutting concerns (auth, logging, correlation IDs)
- Dependency injection via constructor params / factory functions (no global singletons)

## Patterns to Avoid

- No God objects / kitchen-sink modules — split by responsibility
- No circular imports — refactor into a shared dependency or invert the relationship
- No magic strings — use enums or named constants
- **No preemptive abstractions** — only create shared helpers when there is clear current duplication or an obvious short-term reuse path. Three similar lines is better than a premature abstraction.
- No commented-out code in commits (use git history instead)
- No TODO comments without an owner and a ticket reference
