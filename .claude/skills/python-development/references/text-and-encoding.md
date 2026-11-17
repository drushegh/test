# Text, Encoding and Strings-as-Code

Text bugs are silent: the program runs, the output is wrong. Most show up
first on Windows, where the default encoding is still a legacy code page.

## Default encodings on Windows (before Python 3.15)

Until UTF-8 mode became the default in **Python 3.15** (PEP 686), Python
on Windows used the locale code page (typically cp1252) for `open()`
without `encoding=`, for `subprocess` pipes opened with `text=True`, and
for console stdio in some hosts. Symptoms:

- `UnicodeEncodeError: 'charmap' codec can't encode character` on a
  `print()` of a non-ASCII character (arrows, emoji, accented names).
- `subprocess.run(..., text=True)` decoding a UTF-8 child's output as
  cp1252 — mojibake, or "phantom" mismatches when comparing output to
  expected strings.
- Files that round-trip fine on Linux CI corrupting on a Windows laptop.

Rules, whatever the version floor:

```python
Path(p).read_text(encoding="utf-8")                  # always pass encoding
open(p, "w", encoding="utf-8", newline="\n")         # LF when it matters
subprocess.run(cmd, capture_output=True, text=True,
               encoding="utf-8", errors="replace")   # child output
```

- For scripts and hooks run by other tools (CI, agent hooks, git hooks),
  set `PYTHONUTF8=1` (UTF-8 mode) or `PYTHONIOENCODING=utf-8` (stdio only)
  in the calling environment, or keep console output ASCII-only.
- Ruff rule `PLW1514` (`unspecified-encoding`) flags `open()` without an
  encoding — it is a preview rule (needs `--preview` / `preview = true`),
  worth enabling in projects that run on Windows.
- `/tmp` in a Python script on Windows is `C:\tmp` (relative to the current
  drive), not Git Bash's `/tmp` — use `tempfile` and pass paths
  explicitly between shells.

## Reading files of unknown origin

`encoding="utf-8"` with the default `errors="strict"` raises on
Windows-1252/Latin-1 documents; with `errors="ignore"` it silently drops
characters. Neither is acceptable for a document parser. Decode
deliberately:

```python
def read_text_lenient(path: Path) -> str:
    raw = path.read_bytes()
    for enc in ("utf-8-sig", "cp1252"):   # utf-8-sig also strips a BOM
        try:
            return raw.decode(enc)
        except UnicodeDecodeError:
            continue
    return raw.decode("latin-1")          # never fails: every byte maps
```

Log which encoding won, so a mis-detected file is diagnosable.
`utf-8-sig` matters on its own: Windows tools often write a UTF-8 BOM and
`json.loads` rejects it ("Unexpected UTF-8 BOM").

## Strings that contain code (JS, CSS, regex, SQL)

A non-raw Python string processes backslash escapes **before** the
embedded language sees them:

- `"\n"` inside an embedded JS regex becomes a real newline; `"\s"` is an
  invalid escape (`SyntaxWarning` since 3.12) that happens to survive.
- `"\1"` in CSS or a regex replacement becomes the control byte `\x01`,
  which can silently invalidate the surrounding rule.

Use raw strings (`r"""..."""`) for embedded code, or keep the code in its
own file and read it. Verify extracted output with the target toolchain
(`node --check out.js`, a CSS parser, `re.compile`) rather than by eye.

## `str.format()` on content you don't control

`template.format(doc=text)` is safe; `text.format(...)` or building a
template by concatenating document content is not — any `{` or `}` in
the content raises `KeyError`/`ValueError` (JSON, code samples and LaTeX
are full of braces). For prompt builders and report templates: put the
content in a *value*, never in the template, or escape it
(`s.replace("{", "{{").replace("}", "}}")`), or use `string.Template`.
Format strings that come from users also leak attributes
(`"{0.__class__}"`) — never call `.format` on an untrusted template.
