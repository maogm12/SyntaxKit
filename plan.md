# SyntaxKit Implementation Plan

## Goal

Implement a pure Swift TextMate grammar engine based on the TextMate `tmLanguage` specification documented here:

- [TextMate Language Grammars](https://macromates.com/manual/en/language_grammars)

The engine should load TextMate grammars, resolve references, parse text with TextMate's line-oriented model, expose a Swift-friendly library API for apps, and provide a simple CLI for testing and debugging. Parsing and rendering must remain decoupled.

Theme support should follow the legacy `.tmTheme` plist format documented by Sublime Text for compatibility with TextMate-style color schemes: [tmTheme Color Schemes](https://www.sublimetext.com/docs/color_schemes_tmtheme.html).

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
- [ ] Add incremental parsing support in a future iteration
- [ ] Add broader fixture coverage beyond JSON
- [x] Add tmTheme loading, matching, and style resolution
- [ ] Consider richer renderer adapters outside the core library

## Theme Support Tasks

### Theme Model and Loading

- [x] Add a `ThemeLoader` for plist-based `.tmTheme` files
- [ ] Define public theme types:
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
- [ ] Add a theme application API, for example:
  - [x] `ThemeResolver.resolve(spans:using:)`
  - [ ] or `SyntaxHighlighter.highlight(_:grammar:theme:)`
- [ ] Keep the output renderer-neutral so apps can map styled spans into:
  - [ ] `AttributedString`
  - [ ] `NSAttributedString`
  - [ ] custom editor/view models

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
- [x] [Sources/SyntaxKitCLI/CLI.swift](/Users/gmao/code/SyntaxKit/Sources/SyntaxKitCLI/CLI.swift)
- [x] [Sources/SyntaxKitCLI/main.swift](/Users/gmao/code/SyntaxKit/Sources/SyntaxKitCLI/main.swift)
- [x] [Tests/SyntaxKitTests/SyntaxKitTests.swift](/Users/gmao/code/SyntaxKit/Tests/SyntaxKitTests/SyntaxKitTests.swift)
- [x] [Tests/SyntaxKitCLITests/SyntaxKitCLITests.swift](/Users/gmao/code/SyntaxKit/Tests/SyntaxKitCLITests/SyntaxKitCLITests.swift)
- [x] [languages/JSON.tmLanguage](/Users/gmao/code/SyntaxKit/languages/JSON.tmLanguage)
- [x] [themes/Monokai.tmTheme](/Users/gmao/code/SyntaxKit/themes/Monokai.tmTheme)

## Next TODOs

- [ ] Add more real-world grammar fixtures besides JSON
- [x] Add one or more real-world `.tmTheme` fixtures
- [ ] Add CLI snapshot-style output tests
- [ ] Decide whether to support additional grammar formats beyond plist `.tmLanguage`
- [ ] Design an incremental parsing API without coupling it to rendering
- [x] Decide the exact public style/color model for theme output
