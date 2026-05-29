# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Commands

```bash
brew style --fix --changed          # Lint and auto-fix changed files with RuboCop
brew style --fix Library/Homebrew/cmd/reinstall.rb  # Lint a specific file
brew typecheck                      # Run Sorbet type checking (always run globally)
brew tests --online --changed       # Run RSpec tests for changed files
brew tests --only=cmd/reinstall     # Run a specific test file (maps to test/cmd/reinstall_spec.rb)
brew generate-man-completions       # Regenerate manpages and shell completions (do not edit those files directly)
```

**Hooks**: After every file edit, `brew style --changed --fix` and `brew typecheck` run automatically. When the session ends, `brew tests --changed` runs.

**Sandbox note**: In sandboxed environments (e.g. CI without write access to `$(brew --cache)/api/`), copy that directory to `tmp/cache/api/` and `export HOMEBREW_CACHE` to it before running tests.

## Architecture

The repository provides the `brew` CLI. The entry point is `bin/brew` (Bash), which sets up the environment and delegates to `Library/Homebrew/brew.rb` (Ruby).

### Core directories under `Library/Homebrew/`

| Path | Purpose |
|---|---|
| `cmd/` | User-facing commands (`install`, `uninstall`, `list`, etc.) |
| `dev-cmd/` | Developer commands (`style`, `typecheck`, `tests`, `bump`, etc.) |
| `test/` | RSpec test suite — mirrors the source tree, files end in `_spec.rb` |
| `cask/` | Cask DSL and installer for macOS applications |
| `bundle/` | `brew bundle` support |
| `extend/os/` | macOS/Linux-specific class extensions |
| `language/` | Per-language helpers (Java, Node, Python, etc.) |
| `livecheck/` | Version-bump detection strategies |
| `utils/` | Shared utilities (inreplace, git, shell, output, etc.) |
| `api/` | API data models and fetching |
| `cli/` | Argument parsing |
| `startup/` | Initialization and configuration loading |
| `sorbet/` | Sorbet type configuration and generated RBI files |
| `vendor/` | Vendored gems |

Key top-level files: `formula.rb` (Formula DSL base class), `brew.rb` (Ruby entry point), `commands.rb` (command registry).

### Command pattern

Every command is a class inheriting `AbstractCommand` inside `Homebrew::Cmd` (user commands) or `Homebrew::DevCmd` (dev commands). The `cmd_args` block declares CLI flags and descriptions. Example: `Library/Homebrew/cmd/install.rb` → `Homebrew::Cmd::InstallCmd`.

### Formula and Cask DSLs

- **Formula**: `formula.rb` — Ruby DSL where each package is a class inheriting `Formula`. Core formulae live in the external `homebrew-core` tap, not this repo.
- **Cask**: `cask/cask.rb` — Similar DSL for macOS `.app` bundles. Core casks live in the external `homebrew-cask` tap.
- **Taps**: External GitHub repositories that extend Homebrew with additional formulae/casks.

### OS extensions

`extend/os/mac/` and `extend/os/linux/` reopen existing classes to add platform-specific behaviour. The main classes stay platform-neutral; OS overrides layer on top.

## Code conventions

- All Ruby files start with `# typed: strict` and `# frozen_string_literal: true`. New files must follow this.
- Use Sorbet `sig` type signatures for all methods in non-test files. Never add `typed: strict` to `*_spec.rb` files.
- One `expect` assertion per RSpec example. Avoid more than one `:integration_test` per spec file (they are slow).
- `completions/` and `manpages/` are auto-generated — never edit them directly.
- Keep diffs minimal; follow DRY and YAGNI.
