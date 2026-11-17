# Headless Runs, Tests and CI

The traps in this file all have the same shape: a headless run that
reports green, or never returns, while the project is broken. Treat
every headless signal as unproven until you have seen it fail.

## 1. Warm the import cache first

`.godot/` is gitignored, and it holds two things a headless run needs:
the imported assets (`.godot/imported/*`) and the global script class
cache (the `class_name` registry). Run this before any headless work:

```bash
godot --headless --path <project> --import
```

`--import` starts the editor, waits for every resource to import, then
quits (it implies `--editor --quit`). Re-run it when:

- the project is a fresh clone or a copied folder;
- you added or renamed a `class_name` script (the registry is rebuilt
  by the import/scan, not by running a scene);
- you edited an `.import` file (`loop`, compression, mipmaps, filter);
- new assets were dropped in by a script or another agent.

Symptoms of a cold cache: `Cannot open file 'res://.godot/imported/…'`,
"invalid UID" warnings, `Identifier "X" not declared` for a
`class_name` that plainly exists, untextured meshes. None of them is a
code bug, so don't "fix" code until the import has run.

## 2. Never run headless without a timeout

A headless `-s` script that fails to compile, or that hits a script
error inside a coroutine, can wait forever and CI never exits. Use two
layers of protection:

```bash
timeout 600 godot --headless --path . -s res://tests/run_all.gd \
  > test.log 2>&1; status=$?
grep -E 'SCRIPT ERROR|ERROR:' test.log && status=1
```

```gdscript
# res://tests/run_all.gd: in-script watchdog as a second line of defence
extends SceneTree

func _init() -> void:
	create_timer(600.0).timeout.connect(func() -> void:
		push_error("watchdog: test run exceeded 600 s")
		quit(2))
	# ... run the suite, then quit(0 or 1)
```

`-s` scripts compile before the autoloads exist as identifiers, so
reach autoloads through the tree (`root.get_node("/root/GameState")`),
not by bare name. A `class_name X` on a script that is also registered
as an autoload called `X` is a parse error ("hides an autoload
singleton"). Name one of them differently.

## 3. GUT / gdUnit4: prove the suite actually ran

Observed on Godot 4.6.3 with GUT: a test script that fails to PARSE is
skipped, and the run still prints "All tests passed!" with exit 0. In
one project, five of eight scripts were silently dropped. `load()` on
the broken script can still return a non-null `GDScript`, so a null
check is not enough of a guard:

```gdscript
func _script_is_usable(path: String) -> bool:
	var s: Script = load(path) as Script
	return s != null and s.can_instantiate() \
		and s.get_instance_base_type() != &""
```

Rules:

- Run `--import` before the suite (see section 1).
- Pin expected counts: scripts, tests, asserts. A drop in any of them
  fails CI. Print them in a machine-greppable line.
- Ship the parse guard with a positive and a negative control: one
  deliberately broken fixture script the guard must reject. Without
  the negative control you can't tell a working guard from a no-op.
- Under strict warnings (`debug/gdscript/warnings/unsafe_*` set to
  Error), unsafe code becomes a parse error and drops the script
  without warning. See `gdscript.md` for the patterns that trip it.

CLI shapes (flags vary by addon version, so check the addon's docs):
GUT `godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://test -gexit`;
gdUnit4 via its `GdUnitCmdTool.gd` (`resources-export.md`).

## 4. Smoke boots miss runtime errors

`godot --path . res://scenes/level.tscn --quit-after 300` (iterations,
roughly frames) proves the scene loads. It does not prove gameplay
works. Many errors only fire with real input and timing: deferred
physics violations, signal argument mismatches and freed-instance
access. Mitigations:

- Widen the error filter beyond `ERROR:` to include
  `flushing queries|blocked during in/out signal|Use set_deferred|Use call_deferred|Error calling from signal`.
- After any human play-test, grep the real play log (`user://logs/`
  when file logging is on) for `ERROR:` / `SCRIPT ERROR`. A single
  physics-flush error repeated hundreds of times per session went
  unnoticed until someone did this.
- Drive input-dependent paths with a **command-line-gated self-test**:
  `if "--selftest-vehicle" in OS.get_cmdline_user_args():` (user args
  follow a `--` on the command line). It runs the logic, prints
  PASS/FAIL asserts and quits. Strip it or keep it debug-only.

## 5. Isolate tests from the real user profile

Tests that read or write the real `user://` save/profile are flaky,
and they destroy the developer's data. Add a debug-only override
(`--profile=user://test_profile.json` via user args), point tests at a
scratch file and reset it in setup. The same rule holds in every
stack; see `testing-development`.

## 6. Renderer-dependent checks

- `--headless` uses a dummy renderer. Draw-call counts read zero, and
  GPU-side data such as MultiMesh instance buffers can't be read back.
  Run render and perf assertions with a real renderer (windowed, or an
  offscreen GPU runner).
- **Measure before optimising.** A command-line-gated `--perf` probe
  that prints `Performance.get_monitor(Performance.TIME_FPS)`,
  `RENDER_TOTAL_DRAW_CALLS_IN_FRAME` and `OBJECT_NODE_COUNT` after a
  warm-up. In one open-world prototype, five towns came to about 193
  draw calls at 120 fps with roughly 1,900 nodes, so MultiMesh would
  have been premature.
- Record the renderer the engine reports, not the flag you passed,
  when capturing evidence (`ui-verification`).

## 7. Clean exits

- Audio: quitting while `AudioStreamPlayer`s are playing Ogg streams
  has been seen to log `ObjectDB instances leaked at exit`. Stop all
  players and wait about 0.25 s before `quit()` (verify on your
  version). A noisy exit hides real leak warnings.
- Setting `loop` on a loaded stream at runtime mutates the shared
  cached resource for every user of that path. Set it in the
  `.import` (then re-import) or `duplicate()` first.
- On Windows, capture stdout from the `*_console.exe` build. The GUI
  executable does not reliably give a pipe its output.
  `application/run/flush_stdout_on_print` (default off; `.debug`
  override on) controls per-line flushing.

## CI shape

Pinned Godot (and matching export templates) → `--import` →
`timeout` + tests with pinned counts → error-grep the log → smoke boot
of key scenes with the widened filter → export. Runner wiring belongs
to `devops-development`.
