# Portability

Declare your targets, then verify on each. The portability matrix:

| Environment | Reality |
|---|---|
| Linux | GNU coreutils, `/proc`, full Bash |
| macOS | **BSD** coreutils (different flags), Bash 3.2 default (ancient — target `/usr/bin/env bash` for Homebrew Bash, or zsh-aware) |
| WSL | Effectively Linux; Windows FS at `/mnt/c` |
| Git Bash / MSYS2 | Most of Bash; path auto-conversion quirks; no systemd/proc parity |
| Containers | Depends on image — **Alpine ships BusyBox `/bin/sh`, no Bash** |

```bash
detect_platform() {
    case "$OSTYPE" in
        linux*)        echo "linux" ;;   # linux-gnu, linux-musl (Alpine), ...
        darwin*)       echo "macos" ;;
        msys*|cygwin*) echo "windows" ;;
        *)             echo "unknown" ;;
    esac
}
# WSL: grep -qi microsoft /proc/version
# Container: [ -f /.dockerenv ] || [ -n "${KUBERNETES_SERVICE_HOST:-}" ]
```

## macOS (BSD vs GNU)

| Command | GNU (Linux) | BSD (macOS) |
|---|---|---|
| in-place sed | `sed -i 's/a/b/' f` | `sed -i '' 's/a/b/' f` |
| canonical path | `readlink -f path` | macOS 12.3+ ships `readlink -f`; older: `greadlink -f` (coreutils) or pure-bash fallback |
| date maths | `date -d '1 day ago'` | `date -v-1d` |
| stat format | `stat -c '%s'` | `stat -f '%z'` |

```bash
# Prefer GNU tools when installed (brew install coreutils gnu-sed)
if command -v gsed >/dev/null 2>&1; then SED=gsed; else SED=sed; fi
"$SED" -i.bak 's/old/new/' "$file"     # -i.bak works on both as a fallback
```

macOS's default `/bin/bash` is 3.2 — no associative arrays, no
`mapfile`. Scripts using Bash 4+ features must require Homebrew bash or
degrade.

## Git Bash / MSYS2 (Windows)

MSYS **auto-converts Unix-looking arguments to Windows paths** —
`/foo` becomes `C:/Program Files/Git/foo` (the MSYS root is the Git
install dir; only `/usr/...` lands under `.../Git/usr/`). The biggest single source
of Windows shell bugs:

```bash
# Disable conversion per command
MSYS_NO_PATHCONV=1 docker run -v /host/path:/container/path image

# Convert explicitly
unix_path=$(cygpath -u "C:\Windows\System32")
win_path=$(cygpath -w "/c/Users/me")

# Flags that look like paths: double-slash escapes conversion
cmd //e //s        # instead of /e /s

# Detect
[[ "$OSTYPE" == "msys" || "$OSTYPE" == mingw* ]] && in_git_bash=true
```

Other Git Bash realities: no systemd, `/proc` is partial, some tools are
MSYS builds with subtle flag differences; line endings — enforce LF via
`.gitattributes` (`*.sh text eol=lf`) or CRLF shebangs break with
`bad interpreter: /bin/bash^M`.

### CRLF data and Windows-native tools

Native Windows tools called from Git Bash (winget `jq`, `node`, `python`,
`.exe` CLIs) can emit CRLF, and data files may be CRLF. Behaviour observed
on Git Bash (bash 5.3, grep 3.0):

| Construct | What happens | Do instead |
|---|---|---|
| `x=$(tool)` | strips the *final* `\r\n`, keeps interior `\r` | `x=$(tool \| tr -d '\r')` |
| `while IFS= read -r line` / `read < <(jq …)` | `\r` stays on every line — comparisons silently fail | `line=${line%$'\r'}` at every read site, or pipe through `tr -d '\r'` |
| `n=$(grep -c $'\r' file)` to detect CRLF | **false positive** — inside `$( )` the `$'\r'` pattern arrives empty, so every line matches | `tr -cd '\r' < file \| wc -c` (0 means no CR) |
| `sed -i 's/\r$//'` to normalise | unreliable across MSYS builds | `tr -d '\r' < f > f.tmp && mv f.tmp f`, or a binary-mode Python rewrite |

### Calling PowerShell from bash

Bash expands `$vars` inside double quotes **before** PowerShell sees them:
`powershell.exe -Command "Remove-Item x -Recurse:$false"` arrives as
`-Recurse:` (empty). Single-quote the command, escape `\$`, or put the
logic in a `.ps1` and use `-File`. `.cmd`/`.bat` shims (npm globals,
some vendor CLIs) may not resolve from bash by bare name — call `cmd //c
tool …` or run them from PowerShell.

### awk has no `\b` word boundary

`\b` in an awk regex is a backspace, not a word boundary — in mawk, BWK
awk **and** gawk (gawk's word boundary is `\y`, which mawk lacks). For
portable matching use explicit classes:
`awk '/(^|[^[:alnum:]_])foo([^[:alnum:]_]|$)/'`, or `grep -w`.

## POSIX `sh` (containers, init scripts, maximum reach)

When targeting `#!/bin/sh`:

| Bash-only (avoid) | POSIX replacement |
|---|---|
| `[[ ]]`, `=~` | `[ ]`, `case`, `expr`/`grep` |
| arrays, `mapfile` | positional params, `set --`, files |
| `<(cmd)` process substitution | temp files, pipes |
| `${var//x/y}` (some expansions) | `sed`/`tr` |
| `local` (strictly) | widely supported but not POSIX — acceptable in practice |
| `echo -e/-n` portability mess | `printf '%s\n'` always |

Verify with `checkbashisms script.sh` and run under `dash` (strict
POSIX-ish) as a smoke test. In Dockerfiles: either `apk add bash` and
shebang bash, or stay genuinely POSIX — don't pretend.

## Container Notes

PID 1 must handle signals and reap zombies — use `tini`/
`--init`, or `exec` your main process so it receives signals directly
(`exec "$@"` as the entrypoint's last line). Minimal images lack
`curl`/`procps`/etc. — check with `command -v` and fail with a clear
message rather than mid-script surprises.

## Version/Feature Gating

```bash
# Require a minimum Bash where features demand it
if (( BASH_VERSINFO[0] < 4 )); then
    echo "ERROR: bash >= 4 required (found $BASH_VERSION)" >&2
    exit 1
fi

# Tool presence
require() { command -v "$1" >/dev/null 2>&1 || { echo "ERROR: $1 not installed" >&2; exit 1; }; }
require jq
```
