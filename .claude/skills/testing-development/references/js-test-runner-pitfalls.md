# JS test-runner pitfalls — Vitest, jsdom, Windows, workspaces

Runner- and environment-level traps that make a JS/TS suite hang, lie or pass
locally and fail in CI. General Vitest/TypeScript test-writing →
`typescript-development`. Versions move fast; facts marked (verify) were
observed in projects rather than confirmed in official docs.

## Windows and Node versions

- **Worker crash in `initSuite`** — `Cannot read properties of undefined
  (reading 'config')` on Windows (seen with Vitest 4 / Node 22): switching to
  `pool: 'vmThreads'` fixed it (verify). Vitest's default pool is `forks`, and
  the VM pools have caveats: ESM instability, memory leaks and worker recycling,
  and `err instanceof Error` can be false for native-module errors. Prefer
  `vmForks` for large suites.
- **Node 25+ built-in Web Storage** — Node 25 exposes global
  `localStorage`/`sessionStorage`. In some setups these are incomplete objects
  that shadow jsdom's, so `getItem` is missing. Fix seen in projects: pass
  `--no-experimental-webstorage` through the test pool's `execArgv` (verify the
  flag against your Node version's docs), or stub storage in setup.

## CLI and workspaces

- **`vitest run -w <ws>` is `--watch`**, not npm's workspace flag. It hangs. Use
  `npm run test -w <ws>` (npm parses `-w`).
- **`npm run test --workspaces` prints no aggregate.** The tail shows only the
  last workspace, and a miscounted "full suite" total once shipped as a
  baseline. Report per workspace and sum explicitly.

## Environment leakage (local green, CI red)

- **Vite loads `.env.local` in Vitest's test mode.** A module-scope env guard
  satisfied by a developer's `.env.local` passes locally and fails in CI
  (red for hours across dozens of runs). Set `envDir: false` when `VITEST` is
  set (`false` disables `.env` loading in Vite), and provide test env
  explicitly. **When CI is red and local is green, diff the environments
  first.**
- **`import.meta.env.X = undefined` stores the string `"undefined"`.** Use
  `delete import.meta.env.X` or `vi.stubEnv('X', undefined)` plus
  `vi.unstubAllEnvs()` in teardown.

## Mocks

- **`clearAllMocks` vs `resetAllMocks`.** `clearAllMocks` clears call history
  only. `resetAllMocks` also resets implementations: only a `vi.fn(impl)`
  survives, and defaults set with `.mockReturnValue`/`.mockResolvedValue` in a
  `vi.mock` factory are wiped. Use `clearAllMocks` in `beforeEach` to keep
  factory defaults.
- **A full-replacement `window.fetch` mock must forward URLs it does not own**
  to the real fetch. A fake-404 fallback silently killed real calls while tests
  stayed green. Set any re-entrancy guard synchronously. Prove cross-app
  plumbing with two live servers, not two mocks.
- **New self-fetching children fire real calls into frozen tests.** Mounting a
  component that fetches on mount into a screen with existing tests sends
  unmocked requests. Give the shared `vi.mock` factory a never-resolving default
  (`() => new Promise(() => {})`) for each new endpoint.
- **Module-scope expensive singletons** (a client, a parser, a large table)
  run in full for every test file that imports *any* named export from that
  module, because ESM top-level code always executes. `vi.mock` the module with
  a lightweight double.

## Timers and async

- **Plain `vi.useFakeTimers()` deadlocks Testing Library `waitFor`/`findBy*`.**
  Use `vi.useFakeTimers({ shouldAdvanceTime: true })`.
- **`findBy*` defaults to a 1000 ms timeout.** Component tests that follow
  fake-indexeddb or other async storage work can exceed it under parallel load.
  Pass `{ timeout: 5000 }` on those queries rather than raising it globally.

## jsdom gaps

jsdom is not a browser. Known holes:

- No `ResizeObserver`: stub it in setup.
- Layout libraries that measure in `requestAnimationFrame` (docking/grid
  libraries) can throw uncaught *after* the tests finish, so the run exits 1
  with every assertion passing. Stub the component in unit tests.
- No real viewport or layout: overflow and sizing bugs are invisible.
- CSS custom properties and Tailwind `@theme` tokens do not resolve. Test token
  resolution in a real browser (Playwright).
- Native `<dialog>` needs a `showModal`/`close` polyfill.
- **Component-library adoption gate:** some libraries' focus management hangs
  `userEvent.click()` for tens of seconds under jsdom (a menu took ~52 s; a
  `ResizeObserver` stub did not help). Before adopting a component library,
  require a 5-second `userEvent.click()` smoke test on its menu and dialog under
  jsdom.
