# Webviews and Windows (desktop, WebView2-focused)

Behaviour that differs from a browser tab. Most of it was found on
Windows/WebView2; check WebKit (macOS/Linux) separately. API names are
from `tauri` 2.12 docs.rs — re-check on older 2.x.

## Links, popups and navigation

- `<a target="_blank">` and `window.open` **silently do nothing** in a
  Tauri webview unless something handles them. For "open in the system
  browser", use the opener plugin (`openUrl`) from the frontend, or
  intercept on the builder:
  - `WebviewWindowBuilder::on_new_window(|url, features| -> NewWindowResponse)`
    — handles `window.open`/`target=_blank` requests (desktop only).
    Variants: `Allow`, `Create { window }`, `Deny`. For external URLs,
    open them with the opener plugin and return `Deny`.
  - `on_navigation(|url| -> bool)` — return `false` to cancel. Wire
    **both**: a page that navigates itself bypasses `on_new_window`, and a
    popup bypasses `on_navigation`.
- `initialization_script` runs before the HTML is parsed on each
  top-level document load (main frame only; use
  `initialization_script_for_all_frames` for iframes). It does not
  re-run when a hidden window is shown again — to change an already
  loaded page, `webview.eval(...)`. Guard the script with a
  `window.location` check.
- `on_page_load` fires for `Started` and `Finished` on **every** load,
  including reloads and in-page navigations — treat it as an event
  stream and latch one-time work yourself.

## Drag and drop

On Windows, Tauri's native drag-drop handler replaces WebView2's, so
HTML5 drag-and-drop (`dragstart`/`drop` between DOM elements, dnd-kit
HTML5 backends) never fires. Either set `"dragDropEnabled": false` on
the window in `tauri.conf.json` (or `.disable_drag_drop_handler()` on
the builder) and lose Tauri's file-drop events, or keep native file drops
and implement in-app DnD with pointer events.

## Multiple windows and pop-outs

- A DOM subtree cannot move between windows: each window is a separate
  webview and JS realm, so browser-style pop-outs (e.g. dockview's
  `addPopoutGroup`, `window.open` + portal) don't work. Pop out by
  serialising the panel's state, creating a new `WebviewWindow` that
  re-instantiates it, and syncing via events.
- A pop-out window is a fresh webview: no shared session cookies, no
  shared in-memory state, its own zoom.
- `WindowEvent::CloseRequested` handlers registered app-wide fire for
  **every** window. Gate app teardown on `window.label() == "main"`, or
  closing a secondary window shuts the app down.
- Tie secondary windows to the main one (`.parent(&main)` on the
  builder; on Windows this sets the owner) so they minimise and close
  with it.

## Child webviews (multiple webviews in one window)

- The Rust API is behind the `unstable` cargo feature: create with
  `window.add_child(WebviewBuilder::new(...), position, size)` —
  `WebviewBuilder` has no public `build()`. The JS `Webview` class needs
  the same feature.
- **Native child webviews composite above all DOM content of the host
  webview**, regardless of `z-index`. Menus, dialogs and toasts in the
  host page render *under* them. Size each child webview to exclude the
  host chrome (subtract toolbars/sidebars from its bounds) and keep the
  bounds maths in the same change as the CSS layout it mirrors — a layout
  tweak without the matching bounds tweak is the common regression. Hide
  or shrink the child while a host overlay is open.
- The host frontend cannot read a child webview's current URL; ask Rust
  (`Webview::url()`) via a command.

## Sessions, cookies and zoom (WebView2)

- Session cookies (no `Expires`) die when the webview closes, and the
  Chromium `--persist-session-cookies` switch is not honoured through
  WebView2 (observed — verify on your runtime). Logins that use session
  cookies need re-login automation or a token the app stores itself.
- Zoom is per webview and per run; re-apply it when a window is shown or
  re-created.

## Driving a dev window over CDP

WebView2 shares one browser process per user-data folder, so a
`--remote-debugging-port` flag is ignored when the installed copy of the
app is already running. Give the dev run its own folder:
`WEBVIEW2_USER_DATA_FOLDER=<scratch dir>` plus
`WEBVIEW2_ADDITIONAL_BROWSER_ARGUMENTS=--remote-debugging-port=9222`,
then `chromium.connectOverCDP("http://localhost:9222")` from Playwright.
