# HTML and CSS Foundations

## Semantic HTML

Structure carries meaning for browsers, assistive tech, and search:

```html
<body>
  <header>…site header…</header>
  <nav aria-label="Main">…</nav>
  <main>
    <article>
      <h1>One h1 per page</h1>
      <section aria-labelledby="features-heading">
        <h2 id="features-heading">Headings descend in order</h2>
      </section>
    </article>
  </main>
  <footer>…</footer>
</body>
```

- Interactive = real elements: `<button>` for actions, `<a href>` for
  navigation — never `<div onclick>` (no keyboard, no focus, no
  semantics).
- Every input has a `<label for>`; groups of inputs use
  `<fieldset>`/`<legend>`.
- Every `<img>` has `alt` — descriptive for content images, `alt=""` for
  decorative ones.
- Lists are `<ul>`/`<ol>`, tabular data is `<table>` with `<th scope>` —
  not styled divs.
- Use `<dialog>`, `popover`, and `<details>` before reaching for JS
  re-implementations.

## Accessibility Floor

- **Keyboard**: everything operable by keyboard; visible
  `:focus-visible` styles (never remove outlines without replacing);
  logical tab order; skip link for long nav.
- **Contrast**: ≥ 4.5:1 body text, ≥ 3:1 large text and UI components —
  check both themes.
- **Motion**: wrap non-essential animation in
  `@media (prefers-reduced-motion: no-preference)` or disable under
  `reduce`.
- **ARIA is a last resort** — prefer native semantics; when used, keep
  state attributes (`aria-expanded`, `aria-selected`) updated, and hide
  decorative icons with `aria-hidden="true"` + provide `.sr-only` text
  for icon-only buttons.
- **Zoom**: layout survives 200% zoom and 375px-wide viewports.

## Layout: Flexbox vs Grid

- **Flexbox** — one dimension: toolbars, nav rows, centring, spacing a
  line of items (`display: flex; gap: …`).
- **Grid** — two dimensions or explicit tracks: page scaffolds, card
  grids, form layouts.

```css
/* Responsive card grid without media queries */
.cards {
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(16rem, 1fr));
  gap: 1.5rem;
}
```

- Prefer `gap` over margins between siblings — no first/last special
  cases.
- Prefer intrinsic sizing (`min-height`, `fit-content`, `minmax`) over
  fixed heights — content always grows.
- Container queries size components by their container, not the viewport:

```css
.card-host { container-type: inline-size; }

@container (min-width: 24rem) {
  .card { grid-template-columns: auto 1fr; }
}
```

## Custom Properties and Fluid Type

```css
:root {
  --space-1: 0.25rem;
  --space-2: 0.5rem;
  --space-4: 1rem;
  /* Fluid type: scales between viewport sizes without breakpoints */
  --text-display: clamp(2.25rem, 1.5rem + 3vw, 4rem);
}

.hero h1 {
  font-size: var(--text-display);
  line-height: 1.1;
  text-wrap: balance;     /* even multi-line headlines */
}
```

`text-wrap: balance` for headings, `text-wrap: pretty` for body;
`max-width: 65ch` keeps prose measure readable.

## Specificity Discipline

Generated CSS commonly breaks through selectors cancelling each other —
e.g. `.section` padding fighting an element selector's margins.

- Keep specificity flat: single-class selectors; avoid type selectors for
  layout adjustments and IDs for styling entirely.
- One source of truth per axis: vertical rhythm between sections comes
  from the section container's `gap` or a single margin convention — not
  from both ends.
- `@layer` (or Tailwind's layers) to make override order explicit.
- Modern selectors reduce specificity wrestling: `:where()` contributes
  zero specificity; `:has()` enables parent-state styling
  (`label:has(input:invalid)`).

## Responsive Strategy

Mobile-first: base styles for small screens, `min-width` queries (or
Tailwind's `sm:`/`md:`/`lg:`) layering enhancements upward. Test at
375px, a mid tablet width, and wide desktop; verify long content, long
words (`overflow-wrap: break-word`), and empty states don't break the
layout.

## Images and Performance

- `width`/`height` (or `aspect-ratio`) on media to prevent layout shift.
- `loading="lazy"` below the fold; `srcset`/`sizes` for responsive
  images; prefer SVG for icons and logos.
- Self-host fonts with `font-display: swap`, preload the display face,
  subset where possible; system font stack is a legitimate choice.
- Variable-font packages split axes into separate CSS entry points (for
  Fontsource, the default import carries only the weight axis — import the
  file that includes `wdth`/`opsz` when you use `font-stretch` or optical
  sizing; check the package's file list, verify). A missing axis falls back
  to synthesised or default widths without any error.

## Layout, Cascade and Parsing Traps

Each of these renders "fine" in the happy path and fails silently.

**Clipping and stacking**
- `overflow-x: auto` (or `hidden`) forces the other axis from `visible` to
  `auto`, so absolutely positioned popups inside a horizontally scrolling
  row get clipped. Render the popup in a portal at `document.body` with
  `position: fixed`, placed from the trigger's `getBoundingClientRect()` and
  clamped to the viewport; close on outside click and Escape, not
  `mouseleave`. The native `popover` attribute / top layer avoids the
  clipping without a portal.
- A portalled popup opened from inside another portalled overlay (modal,
  drawer) can sit under that overlay's backdrop whatever its `z-index`,
  because each portal root is its own stacking context. Portal into the open
  overlay's subtree (or the top layer), and confirm in a real browser with
  `document.elementFromPoint(x, y)` at the popup's centre — jsdom cannot see
  this.
- `transform`, `filter`, `opacity < 1`, `will-change` and `contain` create
  stacking contexts and containing blocks; a `position: fixed` child of a
  transformed ancestor is positioned relative to that ancestor.
- `translate(50%)` is relative to the element's own box, not the parent;
  use `left`/`top` (or `inset`) percentages for parent-relative placement.

**Responsive**
- A viewport `@media` breakpoint is blind to sidebars and split panes: the
  main column can be 500px wide on a 1280px viewport. Size components with
  container queries or `repeat(auto-fit, minmax(…))`, and capture at the
  in-between widths, not only the standard breakpoints.
- Responsive grids need an explicit base (`grid-cols-1` / a single-column
  default) — without it, `truncate`/`nowrap` children force overflow on
  mobile. Pair `truncate` with `min-width: 0` on the grid/flex child.

**Custom properties and theming**
- Custom properties inherit; they are not specificity contests. A token
  re-declared on a descendant (a scoped screen, a third-party widget root)
  wins over a `:root` or `.dark` theme block by proximity. When a theme
  switch misses a screen, look for local re-declarations and mirror the
  theme block on that scope.
- `var(--token, fallback)` hides typos and stale names — an undefined token
  silently renders the fallback. Grep for every `var(--x, …)` fallback copy
  when retuning a token: fallbacks paint before a post-mount theme provider
  runs, so a stale fallback flashes the old value.
- Changing the default theme means updating the pre-hydration floors too —
  inline styles or a blocking script in `index.html`, and fallback values in
  the base stylesheet — or first paint flashes the old theme.
- `light-dark()` is not accepted as the value of a registered (`@property`
  with `syntax: "<color>"`) custom property in Chromium (observed; verify
  against current engines). Keep `light-dark()` on unregistered tokens, or
  switch registered tokens under a `.dark` / `color-scheme` selector.
- Native `<select>` options can render dim or low-contrast in Chromium dark
  mode even with `color-scheme: dark`; give `option` an explicit background
  and colour from your tokens (verify per browser).
- Customisable select: Chromium's default `::picker(select)` uses
  `position-try-order: most-block-size`, so the picker can open over its
  own label; set `position-try-order: normal` with explicit
  `position-try-fallbacks` when placement matters (experimental; verify).

**Parsing**
- A unitless `0` inside a length `calc()` (`calc(0 + 1rem)`) is a number,
  not a length — the whole declaration is invalid and dropped. Write `0px`.
- CSS comments do not nest: a literal `*/` inside a comment ends it early
  and the rest is parsed as garbage, often swallowing following rules.
- When generating CSS from code, use raw strings: an escape such as `"\1"` in
  a non-raw Python string emits a control character that invalidates
  declarations.
- `text-shadow` paints over text that uses `background-clip: text` with a
  transparent fill; use `filter: drop-shadow()` on a wrapper instead.
