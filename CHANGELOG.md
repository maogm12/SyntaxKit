# Changelog

All notable changes to this project will be documented in this file.

The format is based on Keep a Changelog and the project uses Semantic Versioning.

## [Unreleased]

## [2.0.3] - 2026-03-24

### Refactored

- Moved internal TextMate regex compatibility helpers into a structured `TextMateRegexHelpers` container.
- Replaced `try!` with safe `try?` in `defaultSubstituteBackreferences` with fallback to original pattern if backreference regex fails to compile.

## [2.0.2] - 2026-03-24

### Fixed

- Replaced force unwrap of rule end pattern in `SyntaxParser` with safe unwrap and descriptive error when a begin rule is missing its required end pattern.

## [2.0.1] - 2026-03-24

### Added

- Added MIT license and updated the README license section to reflect the addition of the LICENSE file.

## [2.0.0] - 2026-03-24

### Changed

- Moved regex-pattern validation out of `GrammarRegistry.resolve(...)` and into parser-side validation so the registry now focuses on grammar registration and include resolution only
- Kept CLI `validate` behavior intact by running parser validation after resolution, so invalid regexes are still reported from the command-line workflow

## [1.9.0] - 2026-03-24

### Added

- Added compatibility-shim rewrites for Oniguruma single-quoted named capture groups and named backreferences so common TextMate patterns can compile under the built-in default engine
- Added targeted default-engine diagnostics for Oniguruma relative named backreferences and Ruby-style `(?m)` option usage when those constructs would silently diverge from TextMate semantics
- Added regression tests that keep Foundation and Swift-native backend match results aligned under the shared `CompiledRegex` abstraction

## [1.8.0] - 2026-03-24

### Added

- Added an internal TextMate compatibility shim in the built-in default regex engine so unsupported Oniguruma subexpression-call constructs are rejected with targeted diagnostics instead of falling through as raw backend failures
- Added a Swift-native regex backend inside `DefaultRegexEngine` on supported toolchains while keeping Foundation as the portable fallback backend and normalizing match results into the shared `CompiledRegex` contract
- Added direct tests for injected custom engines, compatibility-shim failure aggregation, and default-engine backend helpers while keeping library line coverage at 100%

## [1.7.0] - 2026-03-24

### Added

- Added a public regex-engine abstraction with `RegexEngine`, `CompiledRegex`, and public `RegexMatch` types
- Added a built-in `DefaultRegexEngine` backed by Foundation regex behavior and refactored the parser to use compiled regex abstractions instead of `NSRegularExpression` directly

## [1.6.1] - 2026-03-24

### Fixed

- Applied the loaded tmTheme global `background` color to the demo preview text view so the whole preview pane matches the active theme instead of only span backgrounds

## [1.6.0] - 2026-03-24

### Added

- Replaced the old bundled theme fixture with two repo-owned sample themes: `SampleDark.tmTheme` and `SampleLight.tmTheme`
- Updated the macOS demo app to bundle both sample themes and switch between them from the Theme menu
- Updated CLI tests, theme fixtures, and README examples to use the new sample themes

## [1.5.0] - 2026-03-24

### Added

- Added parse and render timing readouts to the macOS demo app so you can see reparse and preview costs separately while editing

## [1.4.0] - 2026-03-24

### Added

- Added `bin/launch-demo` to open the demo Xcode project or build and launch the `.app` bundle directly from the repo root
- Updated the README demo section with the new helper script usage

## [1.3.0] - 2026-03-24

### Added

- Added an Xcode macOS app project for `Examples/SyntaxKitDemo` so the demo can be launched as a normal `.app` bundle instead of only through `swift run`
- Shared the existing demo SwiftUI sources and resources with the Xcode app target and updated resource loading so the demo works under both SwiftPM and Xcode
- Updated the README to recommend opening the demo app project in Xcode for normal desktop app behavior

## [1.2.0] - 2026-03-24

### Added

- Extended the macOS demo app so users can switch between bundled JSON and INI grammars and load custom grammar and theme files at runtime
- Updated the README demo section to mention the new language and theme loading behavior

## [1.1.0] - 2026-03-24

### Added

- Added a standalone macOS SwiftUI demo app in `Examples/SyntaxKitDemo` that showcases live parsing, tmTheme styling, scope inspection, and incremental line-state updates
- Added README instructions for building and running the demo app locally

## [1.0.0] - 2026-03-24

### Added

- Added incremental parsing support with `IncrementalParseResult`, resumable `SyntaxLineState` snapshots, and parser reparse APIs that resume from saved line context
- Added incremental parsing tests covering saved-state replay, invalid state handling, and rule lookup restoration

## [0.9.0] - 2026-03-24

### Added

- Added fixture-backed CLI snapshot tests for plain parse output and themed JSON output
- Added bundled CLI snapshot resources so public command output can be regression-tested without reimplementing parsing in the tests

## [0.8.0] - 2026-03-24

### Added

- Added `StyledTextAdapter` for converting themed spans into full-text custom runs, `AttributedString`, and `NSAttributedString` outputs without coupling the parser to rendering
- Added tests covering gap preservation and attribute propagation across the new adapter APIs

## [0.7.0] - 2026-03-24

### Added

- Added automatic JSON grammar loading alongside plist `.tmLanguage` loading
- Added a real INI grammar fixture in JSON format and parser coverage against it

## [0.6.0] - 2026-03-24

### Added

- Added `SyntaxHighlighter` as a renderer-neutral convenience API for combining parsing with theme resolution from grammars, registries, or resolved grammars
- Added tests covering the new app-facing highlight entry points while keeping library line coverage at 100%

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
- Fixture-driven tests using the bundled JSON grammar and sample themes
- Workspace guidance in `agent.md`
- Root `VERSION` file for release tracking
