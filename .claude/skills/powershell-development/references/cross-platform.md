# Cross-Platform and 5.1 Compatibility

## Platform branching

`$IsWindows`, `$IsLinux`, `$IsMacOS` (PS6+; on 5.1 they don't exist —
guard with `$PSVersionTable.PSEdition -eq 'Desktop'` meaning Windows).
Never sniff `$env:OS`.

## Paths

- `Join-Path` (or `[IO.Path]::Combine()`) always; forward slashes work
  on Windows in most APIs but backslashes break Linux — constructed
  paths must never hand-concatenate separators.
- `$HOME`, `[Environment]::GetFolderPath(...)`, `$env:TEMP` vs `/tmp` —
  resolve via APIs, not literals.
- **Case sensitivity**: Linux file systems are case-sensitive — a
  script that works on Windows with `myfile.TXT` mismatches dies on
  Linux. Match case exactly, always.

## Encoding (the interop killer)

- PS7 defaults to UTF-8 (no BOM); **Windows PowerShell 5.1 defaults to
  UTF-16LE** for `Out-File`/redirect and ANSI for some cmdlets. Files
  exchanged with other tools get an explicit encoding.
- BOM matters to bash/python tooling. On PS7 use `-Encoding utf8NoBOM`
  (or `utf8`, which is BOM-less there). On **5.1, `-Encoding utf8`
  writes a BOM** and `utf8NoBOM` does not exist — write BOM-less text via
  `[IO.File]::WriteAllText($path, $text, [Text.UTF8Encoding]::new($false))`
  (use an absolute path: .NET resolves relative paths against the
  process CWD, not `$PWD`).
- The reading side matters too: Notepad, 5.1 `Out-File -Encoding UTF8`
  and many Windows tools emit a UTF-8 BOM, and strict JSON parsers
  (Node `JSON.parse`, Python `json.loads` on a `str` read as `utf-8`, Rust
  `serde_json`) reject it at byte 0. Code that reads hand-edited or
  Windows-written config should strip a leading `U+FEFF` (Python:
  `encoding="utf-8-sig"`).
- Console output mangling on Windows usually means
  `[Console]::OutputEncoding` vs the terminal — set both to UTF-8 in
  profile for mixed toolchains.

## Windows hosts: PowerShell vs Git Bash/MSYS (Damien's daily reality)

- An agent shelling out on Windows may land in **Git Bash**, not
  PowerShell — `pwd` answers `/c/Users/...` (MSYS), `$PSVersionTable`
  errors. Detect before assuming: try `$PSVersionTable` (PowerShell),
  `echo $MSYSTEM` (MSYS2/Git Bash).
- Path translation: MSYS auto-converts `/c/foo` ↔ `C:\foo` at exe
  boundaries but **mangles arguments that look like paths**
  (`MSYS_NO_PATHCONV=1` to stop it); PowerShell needs no translation.
- Quoting differs (single quotes literal in both, but variable
  expansion and escape characters differ: backtick vs backslash) —
  never paste a bash command into PowerShell unreviewed, or vice versa.
- Invoke explicitly when it matters: `pwsh -NoProfile -Command ...`
  from bash; `& 'C:\Program Files\Git\bin\bash.exe' -c '...'` from
  PowerShell.
- **Bash eats `$` inside a double-quoted `-Command`**:
  `pwsh -Command "Remove-Item $dir -Recurse -Confirm:$false"` reaches
  PowerShell with `$dir` and `$false` already expanded by bash — usually
  to empty strings, a silent mis-parse (this has caused wrong-target
  deletions). From bash, single-quote the whole command, escape `\$`, or
  put the logic in a `.ps1` and call `pwsh -NoProfile -File script.ps1 -Arg …`.

## 5.1 vs 7+ compatibility

| Concern | 5.1 | 7+ |
| --- | --- | --- |
| Platform | Windows only | Win/Linux/macOS |
| Encoding default | UTF-16LE/ANSI mix | UTF-8 |
| `ForEach-Object -Parallel`, ternary, `??` | ✗ | ✓ |
| Module path | separate | separate (see modules-gallery.md) |
| Windows-only modules (GroupPolicy etc.) | native | some via `Import-Module -UseWindowsPowerShell` proxy (serialisation limits) |

Write for 7+, add `#Requires`; when 5.1 must be supported, avoid 6+/7+
syntax entirely (it's a parse error, not a runtime fallback) and test
on real 5.1. Line endings: git `core.autocrlf` plus `.gitattributes`
(`*.ps1 text eol=crlf` is safe for Windows-first repos).

Docs: https://learn.microsoft.com/powershell/scripting/whats-new/differences-from-windows-powershell ·
https://learn.microsoft.com/powershell/scripting/dev-cross-plat/writing-portable-modules
