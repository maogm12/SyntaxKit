# SyntaxKit

SyntaxKit is a pure Swift TextMate grammar engine.

It can:

- load TextMate grammars from plist `.tmLanguage` and JSON `.tmLanguage.json`
- resolve repository, self, and external grammar includes
- parse text into UTF-16 based scoped spans
- load legacy `.tmTheme` files
- resolve theme styles without coupling parsing to rendering
- provide a small CLI for validation, parsing, previewing, and regression testing
- resume parsing from saved line state for incremental workflows

## Status

`SyntaxKit` is currently at `1.0.0`.

The implementation in this repo covers the v1 plan in [plan.md](/Users/gmao/code/SyntaxKit/plan.md).

## Installation

Add the package in SwiftPM:

```swift
dependencies: [
    .package(url: "https://github.com/your-org/SyntaxKit.git", from: "1.0.0")
]
```

Then add the product to your target:

```swift
dependencies: [
    .product(name: "SyntaxKit", package: "SyntaxKit")
]
```

## Core Concepts

- `GrammarLoader` loads a grammar file into a `Grammar`
- `GrammarRegistry` stores grammars and resolves includes across them
- `SyntaxParser` parses text into `SyntaxSpan` values
- `ThemeLoader` loads a `.tmTheme`
- `ThemeResolver` maps parser spans to `ThemedSpan` values
- `SyntaxHighlighter` combines parsing and theming in one step
- `StyledTextAdapter` turns themed spans into runs, `NSAttributedString`, or `AttributedString`
- `SyntaxLineState` and `IncrementalParseResult` support resumable parsing

## Load A Grammar

```swift
import Foundation
import SyntaxKit

let grammarURL = URL(fileURLWithPath: "/path/to/JSON.tmLanguage")
let grammar = try GrammarLoader.load(from: grammarURL)

let registry = GrammarRegistry()
registry.register(grammar)
```

You can also load JSON grammars:

```swift
let grammarURL = URL(fileURLWithPath: "/path/to/INI.tmLanguage.json")
let grammar = try GrammarLoader.load(from: grammarURL)
```

## Parse Text

```swift
let parser = SyntaxParser(registry: registry)
let result = try parser.parse("""
{
  "name": "SyntaxKit",
  "enabled": true
}
""", using: "source.json")

for span in result.spans {
    print(span.startUTF16, span.endUTF16, span.scopes)
}
```

`SyntaxSpan` uses UTF-16 offsets plus line and column metadata so it is easier to bridge into common Swift text systems.

## Load And Apply A Theme

```swift
let themeURL = URL(fileURLWithPath: "/path/to/Monokai.tmTheme")
let theme = try ThemeLoader.load(from: themeURL)

let themedSpans = ThemeResolver.resolve(result: result, using: theme)
```

Each `ThemedSpan` contains:

- the original span offsets and scope stack
- a resolved `ThemeStyle`
- parsed theme colors and font style flags

If you want a one-call parse + theme API:

```swift
let themedSpans = try SyntaxHighlighter.highlight(
    "{ \"ok\": true }\n",
    using: "source.json",
    registry: registry,
    theme: theme
)
```

## Adapt Themed Spans For Apps

SyntaxKit does not render terminal colors or UI styling in the core parser. Instead it gives you renderer-neutral adapters.

Custom runs:

```swift
let runs = StyledTextAdapter.runs(text: "{ \"ok\": true }\n", themedSpans: themedSpans)
```

`NSAttributedString`:

```swift
let attributed = StyledTextAdapter.nsAttributedString(
    text: "{ \"ok\": true }\n",
    themedSpans: themedSpans
)
```

`AttributedString` on supported platforms:

```swift
if #available(macOS 12, iOS 15, tvOS 15, watchOS 8, *) {
    let attributed = StyledTextAdapter.attributedString(
        text: "{ \"ok\": true }\n",
        themedSpans: themedSpans
    )
    _ = attributed
}
```

The adapters preserve SyntaxKit metadata as attributes instead of assigning framework-specific colors or fonts directly.

## Incremental Parsing

You can parse while saving line state snapshots:

```swift
let incremental = try parser.parseIncrementally("""
{
  "ok": true
}
""", using: "source.json")

let lineStates = incremental.lineStates
```

Then resume from a saved line state:

```swift
let firstLineState = lineStates[0]

let reparsed = try parser.reparse("""
  "ok": true
}
""", using: "source.json", from: firstLineState)
```

This is useful for editor-style workflows where you only want to reparse from a known invalidation point.

## CLI

Run the CLI from the repo root:

```bash
swift run syntaxkit validate --grammar languages/JSON.tmLanguage
swift run syntaxkit parse --grammar languages/JSON.tmLanguage --scope source.json --input /tmp/sample.json
swift run syntaxkit parse --grammar languages/JSON.tmLanguage --scope source.json --input /tmp/sample.json --json
swift run syntaxkit parse --grammar languages/JSON.tmLanguage --scope source.json --input /tmp/sample.json --json --theme themes/Monokai.tmTheme
swift run syntaxkit preview --grammar languages/JSON.tmLanguage --scope source.json --input /tmp/sample.json
swift run syntaxkit preview --grammar languages/JSON.tmLanguage --scope source.json --input /tmp/sample.json --theme themes/Monokai.tmTheme
```

Commands:

- `validate` loads grammars and resolves includes
- `parse` emits structured spans
- `parse --json` emits machine-readable parse output
- `parse --json --theme` emits themed spans as JSON
- `preview` prints an ANSI-colored debug preview

## Bundled Fixtures

This repo includes real fixtures you can use while developing:

- [languages/JSON.tmLanguage](/Users/gmao/code/SyntaxKit/languages/JSON.tmLanguage)
- [languages/INI.tmLanguage.json](/Users/gmao/code/SyntaxKit/languages/INI.tmLanguage.json)
- [themes/Monokai.tmTheme](/Users/gmao/code/SyntaxKit/themes/Monokai.tmTheme)

## Development

Run tests:

```bash
swift test
```

Run tests with coverage:

```bash
swift test --enable-code-coverage
```

The repo keeps 100% line coverage for library files under `Sources/SyntaxKit`.

## License

No license file is included in this repository yet.
