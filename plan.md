# SyntaxKit Implementation Plan

## Goal

Implement a pure Swift TextMate grammar engine based on the TextMate `tmLanguage` specification documented here:

- [TextMate Language Grammars](https://macromates.com/manual/en/language_grammars)

The engine should load TextMate grammars, resolve references, parse text with TextMate's line-oriented model, expose a Swift-friendly library API for apps, and provide a simple CLI for testing and debugging. Parsing and rendering must remain decoupled.

Theme support should follow the legacy `.tmTheme` plist format documented by Sublime Text for compatibility with TextMate-style color schemes: [tmTheme Color Schemes](https://www.sublimetext.com/docs/color_schemes_tmtheme.html).

Regex compatibility should account for the fact that TextMate documents its grammar regexes against Oniguruma 5.6.0 with Ruby syntax, while the current implementation is backed by `NSRegularExpression`/ICU. Supporting real-world grammars robustly will require a regex-engine abstraction and compatibility plan rather than assuming the two syntaxes are equivalent.

## Status

- [x] Initialize a Swift package with a library target and CLI target
- [x] Add a real grammar fixture using `languages/JSON.tmLanguage`
- [x] Implement grammar loading from plist `.tmLanguage` files
- [x] Implement validation for unsupported or malformed grammar structures
- [x] Implement grammar registry and include resolution
- [x] Implement regex compilation and backreference substitution support
- [x] Implement a line-oriented parser with persistent context stack
- [x] Emit normalized spans with UTF-16 offsets and scope stacks
- [x] Keep rendering out of the core library target
- [x] Add a CLI for `validate`, `parse`, and `preview`
- [x] Add fixture-driven tests for library behavior
- [x] Reach 100% line coverage for library sources in `Sources/SyntaxKit`
- [x] Initialize a git repository and commit the first implementation

## Core Product Tasks

### Library API

- [x] Expose `GrammarLoader.load(from:)`
- [x] Expose `GrammarLoader.load(data:)`
- [x] Expose `GrammarRegistry` for registration and resolution
- [x] Expose `SyntaxParser.parse(_:using:)`
- [x] Expose `SyntaxParser.tokenize(_:using:)`
- [x] Define public result types:
  - [x] `Grammar`
  - [x] `ResolvedGrammar`
  - [x] `ParseResult`
  - [x] `SyntaxSpan`
  - [x] `ScopeName`
  - [x] `Diagnostic`

### Grammar Support

- [x] Support root grammar keys:
  - [x] `scopeName`
  - [x] `fileTypes`
  - [x] `firstLineMatch`
  - [x] `foldingStartMarker`
  - [x] `foldingStopMarker`
  - [x] `patterns`
  - [x] `repository`
- [x] Support rule keys:
  - [x] `name`
  - [x] `contentName`
  - [x] `match`
  - [x] `begin`
  - [x] `end`
  - [x] `captures`
  - [x] `beginCaptures`
  - [x] `endCaptures`
  - [x] `include`
  - [x] `patterns`

### Parsing Behavior

- [x] Support single-pattern `match` rules
- [x] Support multi-line `begin`/`end` region rules
- [x] Support nested patterns inside begin/end regions
- [x] Support repository includes via `#name`
- [x] Support self includes via `$self`
- [x] Support external grammar includes by scope name
- [x] Support begin-to-end backreference substitution
- [x] Support EOF closing for unterminated regions
- [x] Emit capture-derived scopes
- [x] Keep parser output renderer-independent

### Validation Rules

- [x] Reject grammars without `scopeName`
- [x] Reject rules mixing `match` with `begin`/`end`
- [x] Reject `begin` without `end`
- [x] Reject `end` without `begin`
- [x] Reject empty rules with no match, include, or nested patterns
- [x] Reject malformed capture keys and capture payloads
- [x] Reject invalid regexes during resolution
- [x] Reject unresolved repository includes
- [x] Reject unresolved external grammar includes

### CLI

- [x] Add `syntaxkit validate --grammar ...`
- [x] Add `syntaxkit parse --grammar ... --scope ... --input ...`
- [x] Add `syntaxkit parse --json`
- [x] Add `syntaxkit preview --grammar ... --scope ... --input ...`
- [x] Keep CLI implementation on top of public library APIs only

## Testing Tasks

- [x] Add tests for valid grammar loading
- [x] Add tests for malformed grammar rejection
- [x] Add tests for repository include resolution
- [x] Add tests for self include resolution
- [x] Add tests for external grammar resolution
- [x] Add tests for invalid regex rejection
- [x] Add tests for `match` rule parsing
- [x] Add tests for `begin`/`end` parsing
- [x] Add tests for `contentName`
- [x] Add tests for capture handling
- [x] Add tests for backreference-based end patterns
- [x] Add tests for parser behavior using the JSON grammar fixture
- [x] Add tests for parser behavior with manually constructed edge-case grammars
- [x] Verify `swift test` passes
- [x] Verify 100% line coverage for `Sources/SyntaxKit`

## Implementation Notes

- [x] Use Swift Package Manager
- [x] Use Foundation-only runtime dependencies
- [x] Use `NSRegularExpression` behind an internal regex helper
- [x] Use UTF-16 offsets plus line/column metadata in public spans
- [x] Keep theme/render logic decoupled from parsing in the core library
- [x] Add incremental parsing support in a future iteration
- [x] Add broader fixture coverage beyond JSON
- [x] Add tmTheme loading, matching, and style resolution
- [x] Consider richer renderer adapters outside the core library

## Theme Support Tasks

### Theme Model and Loading

- [x] Add a `ThemeLoader` for plist-based `.tmTheme` files
- [x] Define public theme types:
  - [x] `Theme`
  - [x] `ThemeGlobals`
  - [x] `ThemeRule`
  - [x] `ThemeStyle`
  - [x] `ResolvedThemeSpan` or equivalent styled span output
- [x] Parse the top-level theme `name`
- [x] Parse the top-level `settings` array
- [x] Treat the first `settings` entry as global theme settings
- [x] Treat subsequent `settings` entries as scope style rules

### Theme Settings Support

- [x] Support global settings keys needed for app integration:
  - [x] `background`
  - [x] `foreground`
  - [x] `caret`
  - [x] `selection`
  - [x] `selectionForeground`
  - [x] `lineHighlight`
  - [x] `gutter`
  - [x] `gutterForeground`
- [x] Support scope rule settings:
  - [x] `foreground`
  - [x] `background`
  - [x] `fontStyle`
- [x] Support color parsing for:
  - [x] hex RGB
  - [x] hex RGBA
  - [x] X11 named colors
- [x] Support `fontStyle` values:
  - [x] `bold`
  - [x] `italic`
  - [x] `underline`

### Theme Matching and Resolution

- [x] Keep theme resolution outside the parser
- [x] Add a theme resolver that maps parser scope stacks to styles
- [x] Implement prefix-based scope matching on dotted scope names
- [x] Prefer more specific scope matches over less specific ones
- [x] Merge matching scope styles on top of global theme settings
- [x] Expose a Swift-friendly API for styling parser spans without requiring a renderer

### Public API for Theme Integration

- [x] Add `ThemeLoader.load(from:)`
- [x] Add `ThemeLoader.load(data:)`
- [x] Add a theme application API, for example:
  - [x] `ThemeResolver.resolve(spans:using:)`
  - [x] `SyntaxHighlighter.highlight(_:grammar:theme:)`
- [x] Keep the output renderer-neutral so apps can map styled spans into:
  - [x] `AttributedString`
  - [x] `NSAttributedString`
  - [x] custom editor/view models

### CLI Theme Support

- [x] Add `--theme path` support to `syntaxkit preview`
- [x] Make `preview` use parsed tmTheme colors instead of the built-in debug palette when a theme is provided
- [x] Add a CLI mode to inspect resolved styles, such as themed JSON output for spans
- [x] Keep ANSI preview as a debug adapter layered on top of parsed theme styles

### Theme Validation and Testing

- [x] Add fixture `.tmTheme` files for tests
- [x] Add tests for valid theme loading
- [x] Add tests for malformed theme rejection
- [x] Add tests for color parsing:
  - [x] RGB hex
  - [x] RGBA hex
  - [x] X11 named colors
- [x] Add tests for scope prefix matching
- [x] Add tests for specificity ordering
- [x] Add tests for merging globals with matching scope rules
- [x] Add tests proving parser output can be styled without parser changes
- [x] Add CLI tests for `preview --theme`

## Files Delivered

- [x] [Package.swift](/Users/gmao/code/SyntaxKit/Package.swift)
- [x] [Sources/SyntaxKit/GrammarLoader.swift](/Users/gmao/code/SyntaxKit/Sources/SyntaxKit/GrammarLoader.swift)
- [x] [Sources/SyntaxKit/GrammarRegistry.swift](/Users/gmao/code/SyntaxKit/Sources/SyntaxKit/GrammarRegistry.swift)
- [x] [Sources/SyntaxKit/PublicTypes.swift](/Users/gmao/code/SyntaxKit/Sources/SyntaxKit/PublicTypes.swift)
- [x] [Sources/SyntaxKit/RegexSupport.swift](/Users/gmao/code/SyntaxKit/Sources/SyntaxKit/RegexSupport.swift)
- [x] [Sources/SyntaxKit/SyntaxParser.swift](/Users/gmao/code/SyntaxKit/Sources/SyntaxKit/SyntaxParser.swift)
- [x] [Sources/SyntaxKit/ThemeLoader.swift](/Users/gmao/code/SyntaxKit/Sources/SyntaxKit/ThemeLoader.swift)
- [x] [Sources/SyntaxKit/ThemeResolver.swift](/Users/gmao/code/SyntaxKit/Sources/SyntaxKit/ThemeResolver.swift)
- [x] [Sources/SyntaxKit/SyntaxHighlighter.swift](/Users/gmao/code/SyntaxKit/Sources/SyntaxKit/SyntaxHighlighter.swift)
- [x] [Sources/SyntaxKit/StyledTextAdapter.swift](/Users/gmao/code/SyntaxKit/Sources/SyntaxKit/StyledTextAdapter.swift)
- [x] [Sources/SyntaxKitCLI/CLI.swift](/Users/gmao/code/SyntaxKit/Sources/SyntaxKitCLI/CLI.swift)
- [x] [Sources/SyntaxKitCLI/main.swift](/Users/gmao/code/SyntaxKit/Sources/SyntaxKitCLI/main.swift)
- [x] [Tests/SyntaxKitTests/SyntaxKitTests.swift](/Users/gmao/code/SyntaxKit/Tests/SyntaxKitTests/SyntaxKitTests.swift)
- [x] [Tests/SyntaxKitCLITests/SyntaxKitCLITests.swift](/Users/gmao/code/SyntaxKit/Tests/SyntaxKitCLITests/SyntaxKitCLITests.swift)
- [x] [LICENSE](/Users/gmao/code/SyntaxKit/LICENSE)
- [x] [languages/JSON.tmLanguage](/Users/gmao/code/SyntaxKit/languages/JSON.tmLanguage)
- [x] [languages/INI.tmLanguage.json](/Users/gmao/code/SyntaxKit/languages/INI.tmLanguage.json)
- [x] [themes/SampleDark.tmTheme](/Users/gmao/code/SyntaxKit/themes/SampleDark.tmTheme)
- [x] [themes/SampleLight.tmTheme](/Users/gmao/code/SyntaxKit/themes/SampleLight.tmTheme)

## Next TODOs

- [x] Add more real-world grammar fixtures besides JSON
- [x] Add one or more real-world `.tmTheme` fixtures
- [x] Add CLI snapshot-style output tests
- [x] Decide whether to support additional grammar formats beyond plist `.tmLanguage`
- [x] Design an incremental parsing API without coupling it to rendering
- [x] Decide the exact public style/color model for theme output
- [x] Add regex-engine compatibility tracking for TextMate's Oniguruma syntax

## Regex Engine Plan

### Goal

Keep the regex story simple and extensible:

- [x] let the library accept a user-implemented regex engine
- [x] ship one built-in default regex engine
- [x] make the built-in default engine Foundation-backed today
- [x] allow the built-in default engine to use Swift native regex support internally on toolchains where that is a good fit
- [x] add a compatibility shim layer so the default engine is not just "raw backend behavior"

The parser should not care which regex backend is active, and app authors should be able to plug in a different engine later without forking SyntaxKit.

### Compatibility Position

- [x] Keep documenting TextMate compatibility as an Oniguruma-targeted goal, not as something the default engine fully guarantees
- [x] Treat the built-in engine as the portable default, not as a promise of exact TextMate regex semantics
- [x] Keep the design open for a future Oniguruma-backed engine without requiring it now
- [x] Treat the compatibility shim as a best-effort bridge for common TextMate patterns, not as a complete replacement for a real Oniguruma engine

### Public API Direction

- [x] Add a public `RegexEngine` protocol or equivalent public abstraction that app code can implement
- [x] Keep the engine contract minimal and parser-focused:
  - [x] compile a pattern
  - [x] search a single line from a UTF-16 offset
  - [x] return the full match range and capture ranges
  - [x] support escaped backreference substitution for `begin`/`end`
- [x] Avoid exposing backend-native regex types in the public API
- [x] Add parser and/or registry initializers that accept a custom regex engine
- [x] Preserve current convenience initializers so existing users keep getting a default engine automatically
- [x] Keep the compatibility shim internal so app integrators can provide a raw engine without having to implement SyntaxKit-specific compatibility logic unless they want to

### Default Engine Strategy

- [x] Introduce a built-in `DefaultRegexEngine`
- [x] Implement its baseline behavior with `NSRegularExpression`
- [x] Evaluate using Swift native regex APIs internally where the active Swift toolchain supports the required match and capture behavior cleanly
- [x] Keep the built-in engine's observable behavior stable even if its internal implementation changes between Foundation and Swift-native code paths
- [x] Treat Swift native regex as an implementation detail of the default engine unless there is a strong reason to expose separate built-in engine kinds

### Compatibility Shim Layer

- [x] Add an internal compatibility adapter in front of the concrete regex backend used by the built-in engine
- [x] Make the adapter responsible for TextMate-oriented behavior that can be reasonably shimmed without changing the parser contract
- [x] Keep the adapter separate from the concrete backend so the same shim can wrap Foundation or Swift-native regex implementations

The compatibility shim should cover:

- [x] pattern preprocessing and normalization where a safe rewrite is possible
- [x] begin/end backreference substitution and escaping
- [x] targeted rejection of clearly unsupported Oniguruma/TextMate constructs
- [x] targeted diagnostics for patterns likely to differ semantically from TextMate behavior
- [x] normalization of match/capture results where backend output shape needs small adjustments

The compatibility shim should explicitly not promise to emulate:

- [x] true recursive/subexpression-call semantics such as `\g<...>` when the backend cannot execute them
- [x] fundamental regex-engine backtracking differences
- [x] unsupported look-behind semantics that require engine-level support
- [x] any construct whose behavior depends on the backend regex VM rather than syntax rewriting

### Internal Refactor Tasks

- [x] Refactor `RegexCache`, `RegexMatch`, and regex helper functions behind the new abstraction
- [x] Remove direct `NSRegularExpression` dependencies from parser code
- [x] Move regex compilation ownership out of `GrammarRegistry` and into the selected engine
- [x] Keep `GrammarRegistry` responsible for grammar registration/resolution only
- [x] Keep theming and rendering fully independent from regex backend choice
- [x] Decide the layering explicitly:
  - [x] parser
  - [x] compatibility shim
  - [x] concrete regex engine
- [x] Ensure custom engines can be used either:
  - [x] directly, with no SyntaxKit shim
  - [x] wrapped by the built-in compatibility shim if we decide to expose that option later

### Validation and Diagnostics

- [x] Keep regex compilation failures surfaced as `SyntaxKitError.regexCompilation`
- [x] Include the active regex engine name in diagnostics when helpful
- [x] Add targeted diagnostics when a pattern fails under the built-in engine and appears to rely on unsupported TextMate/Oniguruma features
- [x] Prefer simple, actionable diagnostics over a full regex static-analysis system in the first pass
- [x] Distinguish diagnostic sources where helpful:
  - [x] backend compilation failure
  - [x] compatibility-shim rejection
  - [x] compatibility warning about likely semantic mismatch

### Test Plan

- [x] Add tests for the built-in default regex engine contract
- [x] Add tests proving a custom regex engine can be injected and used by parsing flows
- [x] Add a fake test engine to verify:
  - [x] parser uses the injected engine
  - [x] capture ranges flow through the abstraction correctly
  - [x] begin/end backreference substitution still works through the abstraction
  - [x] regex compilation failures propagate correctly
- [x] Add tests for the compatibility shim:
  - [x] supported pattern rewrites
  - [x] unsupported feature rejection
  - [x] warning/diagnostic cases
  - [x] match-result normalization behavior
- [x] Keep the existing parser fixture suite passing under the default engine
- [x] Maintain 100% line coverage for library files while introducing the abstraction

### CLI and Integration Tasks

- [x] Keep the CLI on the built-in default engine for the initial implementation
- [x] Consider a later CLI engine-selection option only after the abstraction is stable
- [x] Document how apps can provide a custom regex engine in Swift
- [x] Document that the CLI uses the default engine plus the built-in compatibility shim

## Potential Improvements and Bug Fixes

### Safety and Stability
- [x] **Fix Force Unwraps in `SyntaxParser`**: Replace `rule.end!` with guards in `parseCore` to prevent crashes if a `Rule` is manually constructed without an end pattern.
- [x] **Replace `try!` in `RegexSupport`**: Move static regexes to lazy initialized properties or use proper error handling instead of `try!`.
- [x] **Thread Safety in `GrammarRegistry`**: Add internal locking to `GrammarRegistry` or convert it to an `actor` to ensure thread-safe registration and resolution.
- [x] **Bound `FoundationRegexCache`**: Implement a simple eviction policy (like LRU) or a maximum size for the regex cache to prevent unbounded memory growth in long-running processes.

### Performance
- [ ] **Cache Expanded Patterns**: In `SyntaxParser`, cache the result of `availablePatterns(in:from:)` for each rule/grammar context. Currently, it recursively expands includes for every cursor position on every line, which is O(Rules * TextLength).
- [ ] **Optimize `bestCandidate` Search**: Consider using a more efficient way to find the next match than iterating through all available patterns for every character.

### Logic and Correctness
- [ ] **Verify Rule ID Uniqueness**: Ensure that `rule.id` combined with `scopeName` is truly unique across all loaded grammars, especially when handling complex cross-grammar includes.
- [ ] **Improve Incremental Parsing**: Refine the `reparse` API to better handle multi-line edits and common editor integration patterns.

### Modernization
- [ ] **Swift Concurrency**: Fully audit the codebase for Swift Concurrency compatibility (strict concurrency checks).
- [ ] **Swift Native Regex**: Expand usage of Swift Native Regex where possible, while maintaining Foundation as a robust fallback.
