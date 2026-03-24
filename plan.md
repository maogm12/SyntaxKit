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
- [ ] Add regex-engine compatibility tracking for TextMate's Oniguruma syntax

## Regex Engine Compatibility Plan

### Why This Needs Its Own Workstream

TextMate's manual explicitly says grammars use Oniguruma and reproduces the Oniguruma 5.6.0 syntax in `ONIG_SYNTAX_RUBY`. The current `SyntaxKit` implementation uses `NSRegularExpression`, which is effectively ICU-style regex behavior. These engines overlap heavily, but they are not syntax-identical and they do not expose the same advanced constructs.

This matters because grammar authors often rely on engine-specific behavior in:

- begin/end patterns with backreferences
- nested language patterns using look-around
- advanced capture and backreference forms
- recursive or quasi-recursive grammar tricks that depend on Oniguruma-only constructs

### Key Compatibility Findings

- [ ] Track TextMate as the compatibility target: Oniguruma 5.6.0, Ruby syntax
- [ ] Keep ICU/`NSRegularExpression` as the current default backend while compatibility work is in progress

Known differences to account for in planning:

- [ ] Oniguruma supports subexpression calls like `\g<name>` / `\g<n>` and recursive call patterns documented in the TextMate regex manual; ICU documents named backreferences `\k<name>` but does not document Oniguruma-style subexpression calls
- [ ] Oniguruma allows duplicate named groups with defined backreference behavior; ICU/`NSRegularExpression` behavior should not be assumed equivalent without explicit tests
- [ ] Look-behind constraints differ in wording and likely edge-case behavior: Oniguruma documents fixed-length look-behind with top-level alternative exceptions, while ICU documents that look-behind must not have unbounded length
- [ ] Character class syntax differs: ICU documents set subtraction `--` in addition to intersection `&&`, while TextMate's embedded Oniguruma reference documents intersection but not ICU-style subtraction
- [ ] ICU documents constructs like `\Q...\E`, `\R`, `\X`, and `\N{...}` that are not part of the TextMate Oniguruma excerpt and should not be treated as part of the TextMate compatibility surface by default
- [ ] Option and capture semantics may differ once named groups appear; TextMate's embedded Oniguruma reference documents special behavior around numbered backrefs/calls when named groups exist

### Architecture Tasks

- [ ] Introduce an internal `RegexEngine` protocol or equivalent abstraction for:
  - [ ] compile pattern
  - [ ] search from UTF-16 offset within a single line
  - [ ] expose match range and capture ranges
  - [ ] support begin-capture substitution into end patterns
  - [ ] expose engine identity/capabilities for diagnostics
- [ ] Move the current `NSRegularExpression` implementation behind an `ICURegexEngine` or `FoundationRegexEngine`
- [ ] Ensure the parser depends only on the regex abstraction, not directly on `NSRegularExpression`
- [ ] Keep parser output and rendering fully decoupled from regex-engine choice

### Capability Modeling

- [ ] Add an internal capability model describing features relevant to grammar parsing:
  - [ ] named captures
  - [ ] named backreferences
  - [ ] subexpression calls / recursion
  - [ ] atomic groups
  - [ ] possessive quantifiers
  - [ ] look-behind constraints
  - [ ] character-class set operators
- [ ] Use capability checks to surface targeted diagnostics when a grammar relies on features unsupported by the active backend
- [ ] Distinguish between:
  - [ ] unsupported syntax that should fail during grammar compilation
  - [ ] syntax accepted by the backend but known to differ from TextMate semantics and should emit a warning/diagnostic

### Backend Roadmap

- [ ] Phase 1: Harden the current ICU backend
  - [ ] add compile-time detection for clearly Oniguruma-specific syntax that ICU does not support
  - [ ] document the currently supported regex subset as "ICU-compatible TextMate grammars"
  - [ ] add diagnostics that mention engine mismatch explicitly
- [ ] Phase 2: Add a pluggable Oniguruma-compatible backend
  - [ ] evaluate backend options:
    - [ ] Swift package wrapper around native Oniguruma
    - [ ] vendored C target in SwiftPM
    - [ ] optional feature flag/product so core package can still build on platforms without native dependency setup
  - [ ] define how engine selection works:
    - [ ] parser initializer parameter
    - [ ] registry-level default
    - [ ] CLI flag such as `--regex-engine icu|oniguruma`
- [ ] Phase 3: Make Oniguruma the preferred compatibility backend when available
  - [ ] preserve ICU backend as a fallback for portability
  - [ ] keep output contracts identical regardless of engine choice

### Public API and Integration Plan

- [ ] Keep the current public parsing API stable if possible
- [ ] If engine selection becomes public, add a minimal Swift-friendly surface such as:
  - [ ] `RegexEngineKind`
  - [ ] `SyntaxParser(..., regexEngine: ...)`
  - [ ] parser/CLI diagnostics that report the active engine
- [ ] Do not leak backend-native match objects into public API
- [ ] Keep theme and render layers fully engine-agnostic

### CLI and Tooling

- [ ] Extend `syntaxkit validate` to report regex-engine compatibility issues
- [ ] Add CLI engine selection for testing, for example:
  - [ ] `syntaxkit validate --regex-engine icu`
  - [ ] `syntaxkit validate --regex-engine oniguruma`
  - [ ] `syntaxkit parse --regex-engine ...`
- [ ] Add a compatibility inspection mode or warning output for patterns that are accepted by ICU but may diverge from TextMate/Oniguruma semantics

### Test Strategy

- [ ] Add a dedicated regex-compatibility fixture suite with patterns grouped by feature:
  - [ ] shared syntax supported by both engines
  - [ ] TextMate/Oniguruma-specific syntax
  - [ ] ICU-only syntax that should be rejected or warned for in TextMate mode
- [ ] Add unit tests for engine capability detection and diagnostics
- [ ] Add parser tests that run the same grammar fixtures against multiple backends when available
- [ ] Add golden tests for known divergence cases, especially:
  - [ ] subexpression call / recursion
  - [ ] named backreference behavior
  - [ ] look-behind edge cases
  - [ ] atomic and possessive behavior
  - [ ] character-class operator differences
- [ ] Keep 100% line coverage for library files while adding backend abstraction

### Documentation Tasks

- [ ] Document the current regex behavior explicitly as ICU-backed, not fully TextMate-Oniguruma-compatible
- [ ] Document which grammars/features require the Oniguruma backend once available
- [ ] Add a compatibility matrix to the README:
  - [ ] feature
  - [ ] ICU backend status
  - [ ] Oniguruma backend status
  - [ ] notes / diagnostics
