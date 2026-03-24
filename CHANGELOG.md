# Changelog

All notable changes to this project will be documented in this file.

The format is based on Keep a Changelog and the project uses Semantic Versioning.

## [Unreleased]

## [0.5.0] - 2026-03-24

### Added

- Added themed JSON inspection output via `syntaxkit parse --json --theme <path>` so CLI users can inspect resolved styles without using ANSI preview
- Added CLI coverage for themed JSON output and JSON formatting helpers

## [0.4.0] - 2026-03-24

### Added

- Added parsed tmTheme color support for short and long hex forms, including RGB and RGBA variants
- Added X11 named color support for theme loading and CLI ANSI preview rendering
- Added validation so unsupported tmTheme colors fail during loading instead of being silently carried through
- Added regression tests for valid and invalid theme color parsing paths

## [0.3.1] - 2026-03-24

### Fixed

- Fixed zero-width end-pattern handling so nested JSON object value contexts no longer skip the closing `}` delimiter
- Added a regression test covering the real JSON grammar's closing brace tokenization

## [0.3.0] - 2026-03-24

### Added

- Added `--theme <path>` support to `syntaxkit preview` so CLI output can render from loaded `.tmTheme` files instead of only the built-in debug palette
- Added a dedicated CLI test target covering option parsing and themed ANSI rendering

## [0.2.0] - 2026-03-24

### Added

- Removed the macOS-only Swift Package manifest restriction so the library can be built on any platform supported by Swift Package Manager and Foundation

## [0.1.0] - 2026-03-24

### Added

- Pure Swift TextMate grammar loading for plist-based `.tmLanguage` files
- Grammar registry and include resolution for repository, self, and external grammar references
- Line-oriented parser that emits normalized syntax spans with scope stacks
- CLI commands for `validate`, `parse`, `parse --json`, and `preview`
- tmTheme loading for plist-based `.tmTheme` files
- Theme resolution layered on parser spans with prefix matching, specificity handling, and global fallback
- Fixture-driven tests using the bundled JSON grammar and Monokai theme
- Workspace guidance in `agent.md`
- Root `VERSION` file for release tracking
