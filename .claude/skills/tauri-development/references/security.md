# Security: Capabilities, Permissions, Scopes

v2 replaces v1's `allowlist` with deny-by-default capabilities. Three
layers: **capability** (named permission set bound to windows, in
`src-tauri/capabilities/*.json`) → **permission** (grants one
command/feature) → **scope** (constrains paths/URLs/args).

## Capability File

```json
{
    "$schema": "../gen/schemas/desktop-schema.json",
    "identifier": "default",
    "description": "Main window baseline",
    "windows": ["main"],
    "permissions": [
        "core:default",
        "core:window:default",
        "core:event:default"
    ]
}
```

Referenced from `tauri.conf.json` → `app.security.capabilities` (or all
files in the directory apply by default). A window in multiple
capabilities gets the merged set. **Bind `windows` explicitly** — don't
leak permissions to unrelated windows/webviews.

## Scoped Permissions — the important pattern

```json
{
    "permissions": [
        {
            "identifier": "fs:allow-read-file",
            "allow": [
                { "path": "$APPDATA/*" },
                { "path": "$HOME/Documents/*" }
            ]
        },
        {
            "identifier": "http:default",
            "allow": [{ "url": "https://api.example.com/*" }]
        },
        {
            "identifier": "shell:allow-execute",
            "allow": [
                { "name": "git-status", "cmd": "git", "args": ["status", "--porcelain"] },
                { "name": "npm-run", "cmd": "npm", "args": ["run", { "validator": "^[a-z:-]+$" }] }
            ]
        }
    ]
}
```

Each shell scope entry needs a `name` (the handle the frontend passes to
`Command.create`), the `cmd` binary, and `args`. `args` is positional:
an array lists the exact arguments in order (a string is fixed, a
`{ "validator": "<regex>" }` object is a checked dynamic slot), so
`["run", {...}]` allows `npm run <script>` and nothing else. `"args": true`
allows **any** arguments — for `git` that means `-c core.sshCommand=...`
and `clone`/`push` to anywhere, i.e. unrestricted execution. Avoid it.

`fs`, `http`, and `shell` must always be scoped — a blanket
`fs:default`-style grant for the whole filesystem or any URL is the
desktop equivalent of `chmod 777`. Use path variables (`$APPDATA`,
`$HOME`, `$RESOURCE`) — never hardcoded absolute paths.

## Common Plugin Permission Strings

| Plugin | Baseline | Notable granular |
|---|---|---|
| fs | `fs:default` | `fs:allow-read-file`, `allow-write-file`, `allow-read-dir`, `allow-remove-file` |
| dialog | `dialog:default` | `allow-open`, `allow-save`, `allow-message`, `allow-confirm` |
| shell | `shell:default` | `allow-open` (URLs), `allow-execute` (scope it!) |
| http | `http:default` | scope URLs |
| store | `store:default` | `allow-get/set/delete/keys/clear` |
| clipboard-manager | `clipboard-manager:default` | `allow-read`, `allow-write` |
| notification | `notification:default` | `allow-send`, `allow-request-permission` |
| global-shortcut | `global-shortcut:default` | `allow-register/unregister` (desktop-only) |
| updater | `updater:default` | — |
| deep-link | `deep-link:default` | — |

**Installing a plugin without its permission in a capability = silent
runtime failure.** Always pair install + permission + verify.

## Platform-Specific and Remote

```json
{ "identifier": "desktop-only", "platforms": ["linux", "macOS", "windows"],
  "permissions": ["global-shortcut:default"] }
```

```json
{ "identifier": "remote-api", "remote": { "urls": ["https://*.myapp.com"] },
  "permissions": ["http:default"] }
```

Valid `platforms` values are case-sensitive: `linux`, `macOS`, `windows`,
`android`, `iOS`.

Remote access lets pages from those URLs call Tauri commands — grant with
extreme care; default is local-only.

## Custom Permissions

Define app-specific permissions in `src-tauri/permissions/*.toml`:

```toml
[[permission]]
identifier = "allow-home-documents"
description = "Allow access to home documents"
commands.allow = ["read_file", "write_file"]

[[scope.allow]]
path = "$HOME/Documents/**"
```

Reference as `"custom:allow-home-documents"` in capabilities.

## Webview Hardening

In `tauri.conf.json` → `app.security`:

- **CSP**: `"csp": "default-src 'self'; img-src 'self' data:"` — keep
  tight; loosen per-source deliberately. If you use the asset protocol,
  its origins must be allowed too: `img-src 'self' asset: http://asset.localhost`
  (the second origin is what Windows/Android serve it as).
- **assetProtocol**: off by default; `"assetProtocol": { "enable": true,
  "scope": ["$APPDATA/assets/**"] }` enables it and limits which local
  paths it may serve (the `tauri` crate needs the `protocol-asset` feature).
  v1's `assetScope` key does not exist in v2.

## Webviews That Load Other Content

Tauri 2 injects `window.__TAURI_INTERNALS__` (the IPC bridge and invoke
key) into every top-level webview, and **app commands registered in
`generate_handler!` are callable from every window and webview of the
app** unless you restrict them with an app manifest (`AppManifest::commands`
in `build.rs`, then grant them per capability). Remote origins are denied
IPC by default, but pages served from the app's own origin are not.
Consequences for preview / mini-browser panes:

- Never let a preview window load the app's own origin or dev-server port
  (`http://localhost:<devPort>`, `tauri://localhost`) — that page gets
  full command access.
- Add `on_navigation` / `on_new_window` guards (webviews-and-windows.md)
  so untrusted pages can't steer a webview onto a local origin or spawn
  new windows.
- Bind capabilities to window labels, and give preview windows labels no
  capability matches.
- Rust-side HTTP through `tauri_plugin_http::reqwest` is plain reqwest:
  the `http:` capability scope constrains only the **JS** API. Validate
  the scheme/host yourself before fetching a URL that came from the
  frontend.

## Review Checklist

- Every permission justified by a feature; no "full-desktop" blanket sets
  in production.
- `fs`/`http`/`shell` scoped to specific paths/URLs/binaries with
  constrained args.
- Capabilities split per window/feature; new windows covered explicitly.
- No unused plugin permissions left behind (audit when removing features).
- Descriptions present — they're the audit trail for why a grant exists.
