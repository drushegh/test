# Tooling and Project Setup

**Always match an existing repo's toolchain.** For greenfield, two sane
stacks — pick one, don't mix:

| | Standard stack | Fast stack |
|---|---|---|
| Package manager / runtime | pnpm or npm + Node | Bun |
| Typecheck | tsc | tsgo (native port, much faster) |
| Lint + format | ESLint + Prettier | Biome (one tool, fast) |
| Tests | Vitest | Vitest |
| Monorepo | Turborepo (either stack) | Turborepo |

Standard is the safe default for client/enterprise work; the fast stack
trades ubiquity for speed. Vitest is the test runner in both.

## package.json Scripts

```json
{
  "scripts": {
    "dev": "tsx watch src/index.ts",
    "build": "tsc -p tsconfig.build.json",
    "typecheck": "tsc --noEmit",
    "test": "vitest run",
    "test:watch": "vitest",
    "test:coverage": "vitest run --coverage",
    "lint": "eslint .",
    "lint:fix": "eslint . --fix",
    "format": "prettier --write .",
    "format:check": "prettier --check .",
    "check": "npm run typecheck && npm run lint && npm run test"
  }
}
```

Run `check` in order — typecheck, lint, test — to fail fast. Keep `lint`
read-only (no `--fix`) so CI fails on fixable issues instead of silently
rewriting files; use `lint:fix` locally. In CI use
frozen lockfiles (`npm ci` / `pnpm install --frozen-lockfile` /
`bun install --frozen-lockfile`).

Bun quirk worth knowing: `bun test` runs Bun's native test runner, NOT your
package.json test script — use `bun run test`.

## tsconfig.json

```jsonc
{
  "compilerOptions": {
    // Safety — non-negotiable
    "strict": true,
    "noUncheckedIndexedAccess": true,
    "exactOptionalPropertyTypes": true,
    "noFallthroughCasesInSwitch": true,
    "verbatimModuleSyntax": true,

    // Module / output
    "target": "ES2022",
    "module": "ESNext",              // Node libraries: set BOTH of these
    "moduleResolution": "bundler",   // to "NodeNext" — tsc rejects a mismatch
    "esModuleInterop": true,
    "resolveJsonModule": true,
    "isolatedModules": true,
    "skipLibCheck": true,

    // Apps: noEmit + a bundler. Libraries: declaration output
    "noEmit": true
  },
  "include": ["src/**/*.ts"],
  "exclude": ["node_modules", "dist"]
}
```

Libraries additionally need `declaration: true`, `sourceMap: true`, and an
emit config. Large repos: project references + incremental compilation cut
build times.

**Split app and test configs.** The build config (`tsconfig.app.json` /
`tsconfig.build.json`) excludes `**/*.test.ts(x)` and test setup; a
`tsconfig.test.json` (or Vitest's own config) adds `"types":
["vitest/globals"]`. Otherwise either the build type-checks test-only globals
or the tests lose their types. With a references-only root
`tsconfig.json`, the real check is `tsc -b` (or each `-p` config) — see the
SKILL.md warning on bare `tsc`.

## pnpm Specifics

- **Dependency build scripts are blocked by default** (pnpm 10+). Packages
  with native postinstall steps (esbuild, workerd, better-sqlite3, sharp)
  fail the install with `ERR_PNPM_IGNORED_BUILDS` until approved. pnpm
  10.26+ and 11 use an `allowBuilds` map in `pnpm-workspace.yaml`
  (`esbuild: true`); pnpm 11 removed `onlyBuiltDependencies` and friends
  (codemod: `pnpx codemod run pnpm-v10-to-v11`). `pnpm approve-builds` and
  `pnpm add --allow-build` write the map for you — check the written value
  is a real `true`/`false`, not a placeholder.
- **`pnpm --filter web test -- path` forwards a literal `--`** to the script
  and can run the whole suite. Target the binary instead:
  `pnpm --filter web exec vitest run path/to/file.test.ts`.

## Biome (if chosen over ESLint + Prettier)

```json
{
  "$schema": "https://biomejs.dev/schemas/2.0.0/schema.json",
  "vcs": { "enabled": true, "clientKind": "git", "useIgnoreFile": true },
  "files": { "ignoreUnknown": true, "includes": ["**", "!**/dist/**", "!**/*.gen.ts"] },
  "formatter": { "enabled": true, "lineWidth": 100 },
  "linter": { "enabled": true, "rules": { "recommended": true } },
  "assist": { "actions": { "source": { "organizeImports": "on" } } }
}
```

Biome 2 syntax: `files.ignore`/`files.include` became a single
`files.includes` list with `!` negations, and top-level `organizeImports`
moved under `assist.actions.source`. `biome migrate --write` converts a
1.x config. `node_modules` is ignored by default.

Commands: `biome check .` (lint + format check), `biome check --write .`
(fix), `biome ci .` (CI mode). In monorepos, share config via a workspace
package.

## Turborepo (Monorepos)

```jsonc
// turbo.json
{
  "$schema": "https://turbo.build/schema.json",
  "tasks": {
    "build":     { "dependsOn": ["^build"], "outputs": ["dist/**"] },
    "typecheck": { "dependsOn": ["^typecheck"] },
    "lint":      {},
    "test":      { "dependsOn": ["^build"], "env": ["DATABASE_URL"] },
    "dev":       { "cache": false, "persistent": true }
  }
}
```

Structure: `apps/` (deployables) + `packages/` (shared code, configs).
`dependsOn: ["^build"]` means "build my dependencies first". Declare env
vars a task reads in `env` or caching will serve stale results. Useful
filters: `turbo build --filter=api...` (api + its deps),
`--filter=...[origin/main]` (only what changed). Remote caching makes CI
dramatically faster — set it up early.

## CI Skeleton (GitHub Actions)

```yaml
jobs:
  check:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: pnpm/action-setup@v4          # reads "packageManager" from package.json
      - uses: actions/setup-node@v4
        with: { node-version: 22, cache: "pnpm" }
      - run: pnpm install --frozen-lockfile
      - run: pnpm typecheck
      - run: pnpm lint
      - run: pnpm test
```

`setup-node`'s `cache: "pnpm"` needs pnpm already on the PATH, so
`pnpm/action-setup` must come first (npm projects: drop it and use
`cache: "npm"` + `npm ci`).

## Bundle Hygiene

- `import type { ... }` for type-only imports (`verbatimModuleSyntax`
  enforces this) — keeps types out of the runtime bundle.
- `as const` objects over `enum` — enums emit runtime code and resist
  tree-shaking.
- Analyse bundle size before optimising it; lazy-load heavy dependencies.