# Effects, Lifecycle and State-Library Traps

Load when writing or debugging `useEffect`/`useLayoutEffect`, refs, imperative
DOM libraries, StrictMode double-mount behaviour, external stores (Zustand,
Redux), error boundaries, or component-library adoption. These are the traps
that pass type-check and unit tests and then misbehave in the browser.

## StrictMode Double-Mount (development only)

In development, `<StrictMode>` (React 18+) mounts every component, runs its
effects, tears them down, then mounts again. It also double-calls component
bodies, `useState`/`useMemo` initialisers and reducers. Production runs once,
so StrictMode-only bugs are real bugs in your cleanup, not noise to disable.

- **Cleanup must fully undo setup.** A closure flag such as
  `let cancelled = false; return () => { cancelled = true }` is correct for
  ignoring a stale *result*; it is wrong when the guarded work is a spawn of an
  external resource (a process, socket, worker, terminal session). The first
  mount's cleanup flips the flag and the second mount's spawn is the only one
  that should survive, so own the resource explicitly: create in setup, dispose
  in cleanup, and make creation idempotent (key by a stable id).
- **Co-locate setup and teardown of imperative-DOM libraries** (terminal
  emulators, code editors, canvas/WebGL renderers, charting libs) in ONE
  effect. Splitting `new Lib(container)` and `lib.dispose()` across two
  effects leaves a dead instance after the remount. In cleanup, dispose and
  clear the container (`container.replaceChildren()`) so the second mount
  starts clean.
- **Timer-driven animation keyed on a "did it change?" ref freezes** under
  double-invoke: the ref already holds the new value on the second run, so the
  transition is never detected. Split detection (derive during render or in
  one effect) from scheduling (a second effect whose cleanup clears the timer).
  Verify transitions on the real dev server, not a seeded static preview.
- **No side effects in render.** Logging, network calls, store writes or
  `ref.current = …` mutations during render repeat on every render and twice
  under StrictMode — under polling they spam. Move them to effects or handlers.

## Effects and Stale Closures

- **Event-subscription hooks** keyed only on `[eventName]` keep the first
  handler closure forever. Store the latest handler in a ref
  (`handlerRef.current = handler` in a layout effect) and subscribe once with a
  stable dispatcher that calls `handlerRef.current(...)`. React 19.2's
  `useEffectEvent` is the built-in form of this pattern (verify the version in
  use before relying on it).
- **Every fetch-per-selection hook needs a race guard from day one** — an
  `AbortController` aborted in cleanup, or a generation counter checked before
  `setState`. Without it, a slow earlier response overwrites a later selection.
- **A prop-keyed effect is not a revert-on-failure guard.** If an optimistic
  update fails, the prop did not change, so an effect keyed on it never re-runs.
  Revert explicitly in the failure branch of the handler.
- **Effects run child-first, parent-last.** A provider that sets
  context-gating state (current role, tenant, feature flags) in its own
  `useEffect` lets every child's effects run first with the stale value. Derive
  such state during render (or initialise it synchronously) so children never
  see the pre-sync value; include the identity key (user/persona id) in the
  deps of anything derived from it.
- **Hook initialisers run before a later early return.** `useState(() =>
  seedMockData())` executes even when the component returns `null` two lines
  later for a "not enabled" gate. Put the gate inside the initialiser/callback.

## Rules of Hooks

Hooks must run in the same order on every render: never below an early
`return`, inside a condition, or in a loop. A hook added under an existing
early return compiles, then throws "Rendered more hooks than during the
previous render" when the branch flips. Make `eslint-plugin-react-hooks`
(`rules-of-hooks` as error, `exhaustive-deps` as warn) part of the lint gate
in every React repo — if the repo lacks it, recommend adding it rather than
relying on review to spot ordering bugs.

## Identity and Keys

- **Key by the stable handle,** not an id that is reassigned after creation
  (for example, a client temp id replaced by a server id). Re-keying remounts
  the subtree, losing state and invalidating closures that captured the old id.
- **Ternary swaps unmount.** `{confirming ? <Confirm/> : <Form/>}` destroys the
  form's DOM — uncontrolled input values are gone even if the user cancels.
  Keep both mounted and hide one (`hidden` attribute / `display:none`), or lift
  the values into state.
- **"Can submit" and "is dirty" are different booleans.** A disabled submit
  button (invalid or unchanged) is not an unsaved-changes guard; derive `dirty`
  separately and wire it to the close/navigate confirmation.

## Data-Layer Hooks

- **In-flight de-duplication across mounts needs module scope.** A `useRef`
  guard resets on remount, so a remount (StrictMode, route change) starts a
  duplicate request sweep. Keep the in-flight `Map<key, Promise>` at module
  level and export a `__resetForTests()` so tests stay isolated. Prefer SWR or
  TanStack Query, which already de-duplicate.
- **Cap and sort at the consumer, not in the shared data layer.** A
  "priority sort then slice to N" inside a shared hook silently drops rows that
  a different consumer (a wider date window, a timeline) needed.

## External Stores (Zustand, Redux, useSyncExternalStore)

A selector that builds a new array/object on every call
(`useStore(s => s.items.filter(...))`) returns a fresh reference each time;
`useSyncExternalStore` treats that as a change and loops — "The result of
getSnapshot should be cached to avoid an infinite loop" / "Maximum update depth
exceeded". Select the stable slice and derive in the component body (memoise
if expensive), or wrap the selector with `useShallow` from
`zustand/react/shallow` when you need several fields.

## Error Boundaries

A render-phase throw anywhere without a boundary unmounts the whole root —
a blank page. Typical culprit: parsing untrusted data inside a table/grid
`accessor` or cell renderer. Parse defensively with a safe fallback, and wrap
page content in a route-keyed boundary (`<ErrorBoundary key={pathname}>`) so
navigation resets it while the shell (nav, header) survives. Boundaries do NOT
catch errors in event handlers, async code or server rendering — handle those
explicitly.

## Interop Traps

- **Outside-click to close**: listening on `mousedown` and deferring with
  `setTimeout(0)` races React's `onClick` — the menu unmounts before the click
  on its item lands. Listen for `click` on `document`, and test containment
  against a ref (`menuRef.current?.contains(e.target as Node)`).
- **Hash-routed SPAs swallow in-page anchors**: `<a href="#section">` is read as
  a route and 404s. Handle with `preventDefault()` +
  `document.getElementById(id)?.scrollIntoView()`.
- **Two copies of React** in npm/pnpm workspaces (a package resolving its own
  `react`) break hooks ("Invalid hook call") or tests ("A React Element from an
  older version of React was rendered"). Hoist `react`/`react-dom` to the root,
  declare them as `peerDependencies` in libraries, and check with
  `npm ls react`.

## Component-Library Adoption Smoke

Before adopting a component library, render its menu and dialog under the
project's unit-test environment (jsdom/happy-dom) and run one
`userEvent.click()` on each with a five-second timeout. Some libraries' focus
management stalls for tens of seconds per interaction under jsdom (observed
with a popular design-system `Menu`), which makes the suite unusable. Native
`<dialog>` also needs a `showModal`/`close` polyfill in jsdom. Real-browser
behaviour still belongs to Playwright (see testing-development and
ui-verification).
