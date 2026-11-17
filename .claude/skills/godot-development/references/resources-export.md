# Resources, Data-Driven Design and Export/CI

## Custom Resources (the data layer)

```gdscript
class_name ItemDefinition
extends Resource

@export var id: StringName
@export var display_name: String
@export var icon: Texture2D
@export var max_stack: int = 99
@export var value: int = 0
@export_multiline var description: String
```

Create `.tres` files from it in the editor (or
`ResourceSaver.save()`); reference from scenes:
`@export var item: ItemDefinition`. Wins: typed, inspector-editable,
diff-able text files, sub-resource composition (an EnemyDefinition
holding an attack pattern Resource), loadable by path.

Rules:

- **Shared by reference**: assigning the same `.tres` to two enemies
  shares state — `.duplicate(true)` at runtime for mutable
  instances; keep definition Resources immutable at runtime by
  convention.
- Resources persist data; Nodes do behaviour. A skill tree, dialogue
  graph or loot table is Resources; the thing executing it is a
  node.
- `ResourceLoader.load()` caches by path; `CACHE_MODE_IGNORE` for
  fresh copies.
- `ResourceLoader.exists()`/`load()` have been seen to succeed for a
  file deleted from disk in the same session (served from the cache or
  stale import data). In editor tooling and tests that check deletion,
  use `FileAccess.file_exists()`. Don't use that in exported games for
  imported assets: they are remapped into the `.pck`, and the original
  path no longer exists as a file.
- `ResourceSaver.save(res, path)` does not set `res.resource_path`
  unless you pass `ResourceSaver.FLAG_CHANGE_PATH`. A container
  Resource that references it afterwards **embeds a copy** instead of
  linking the file. Save with the flag (or `take_over_path`) before
  referencing.
- Loaded resources are shared: setting `loop` on a cached
  `AudioStream` (or any property on a cached texture or material)
  changes it for every user of that path. `duplicate()` first, or set
  it in the `.import` file and re-import.
- Save systems: custom Resource + `ResourceSaver` is quick but
  EXECUTES code on load (`set` calls) — for untrusted saves prefer
  JSON/ConfigFile (no code execution) and validate
  (→ `secure-development` input-handling logic applies to save
  files).

## Settings and files

`ConfigFile` for user settings (`user://settings.cfg`);
`FileAccess` for raw IO; `user://` is the writable sandbox
(`res://` is read-only in exports — a classic export-day surprise).

## Export pipeline

- **Export templates must match the editor version** — first thing
  to check on "export fails after upgrade".
- Presets per platform in `export_presets.cfg` (commit it; keep
  secrets — keystores, signing identities — OUT via credentials
  overrides/environment).
- Per-platform essentials: Windows (optional code signing), Web
  (served with cross-origin isolation headers for threads; verify
  current C#-on-web support), Android (keystore, permissions,
  gradle build for plugins), iOS (Xcode project export, signing on
  Mac runner).
- Resource inclusion: exports include `res://` per preset filters —
  dynamically `load()`-ed string paths must not be excluded by
  filter; PCK patches for content updates.

## Headless CI

```bash
# export (release) per preset name
godot --headless --export-release "Windows Desktop" build/game.exe
godot --headless --export-release "Web" build/web/index.html

# import-only pass (first CI run must warm the .godot import cache)
godot --headless --import

# tests (gdUnit4 example)
godot --headless -s addons/gdUnit4/bin/GdUnitCmdTool.gd --add res://tests
```

CI shape: pinned Godot + matching templates in the runner image →
`--import` warm-up → run tests → export per platform → artefact
upload. The `.godot/` directory is cache — never commit, always
regenerate. Runner/hosting wiring → `devops-development`.

## Versioning and content updates

Text scenes/resources diff well — review them like code (node
renames and reordered properties are the noise to tolerate). Asset
budgets and import settings (`.import` files DO get committed)
reviewed alongside. An edited `.import` takes effect only after a
re-import (`godot --headless --path . --import`).

Android: `application/config/quit_on_go_back` defaults to `true`, so
the system Back button quits the game outright. Turn it off and handle
`NOTIFICATION_WM_GO_BACK_REQUEST` if Back should open a pause menu. For localisation: `tr()` + translation CSV/PO
from day one if multi-language is plausible.

## Data at scale

Hundreds of definitions: generate `.tres` from a source spreadsheet/
JSON via an `@tool` import script rather than hand-editing;
StringName ids + a registry autoload (id → Resource) for lookup;
validate registry integrity in a unit test (missing icons, duplicate
ids) — cheap insurance designers will trip daily without.
