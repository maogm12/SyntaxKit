# SyntaxKit Implementation Plan

## Goal

Implement a pure Swift TextMate grammar engine based on the TextMate `tmLanguage` specification documented here:

- [TextMate Language Grammars](https://macromates.com/manual/en/language_grammars)

The engine should be capable of loading TextMate grammars, resolving rule references, parsing text using the TextMate line-oriented model, and emitting scopes/tokens that downstream consumers can use for syntax highlighting, editor behaviors, or structural analysis.

This document is an implementation plan, not a final architecture contract. It is intended to guide the first complete version of the library and make the major decisions explicit before writing code.

## Core Product Intent

The first version should optimize for:

- Correctness relative to the documented TextMate grammar behavior
- A clean pure-Swift API with no external runtime dependency
- A well-factored internal design so parsing, loading, and rule resolution can evolve independently
- Good testability with fixture-driven parser validation
- Room for future incremental parsing and editor integration

The first version does not need to optimize for:

- Perfect compatibility with every undocumented edge case from every TextMate-compatible implementation
- Full theme engine support
- Full editor integration
- Maximum performance before correctness is established

## Scope of the First Implementation

### Supported Grammar Structure

The first implementation should support the major grammar keys described in the TextMate manual:

- Root-level keys:
  - `scopeName`
  - `fileTypes`
  - `firstLineMatch`
  - `foldingStartMarker`
  - `foldingStopMarker`
  - `patterns`
  - `repository`

- Rule-level keys:
  - `name`
  - `contentName`
  - `match`
  - `begin`
  - `end`
  - `captures`
  - `beginCaptures`
  - `endCaptures`
  - `include`
  - `patterns`

### Behavioral Support

The first implementation should support:

- Single-pattern `match` rules
- Multi-line `begin`/`end` region rules
- Nested patterns inside begin/end regions
- Capture-based scope assignment
- Repository rule reuse via `#name`
- Self-recursive includes via `$self`
- Embedded grammar includes by scope name
- Backreference usage from `begin` captures inside `end`
- End-of-document fallback for unterminated `begin`/`end` regions
- Line-oriented matching semantics

### Out of Scope for v1

Unless discovered as necessary during implementation, do not treat these as blockers for the first release:

- A theme/styling engine
- Scope selector matching
- Full bundle loading behavior
- Editor commands, preferences, snippets, or folding UI
- Full on-the-fly incremental reparsing
- Behavioral emulation of implementation-specific quirks outside the documented spec

## Important Spec Constraints

The linked TextMate documentation creates several non-negotiable constraints that should shape the architecture:

1. Parsing is line-oriented.
   The spec explicitly states that regular expressions are matched against a single line at a time. Multi-line behavior comes from `begin`/`end` regions, not from regexes that span arbitrary line breaks.

2. Parser state must survive across lines.
   Because `begin`/`end` rules can remain open across line boundaries, the parser must carry a stack of active contexts as it moves line by line.

3. Includes are semantic references, not just textual expansion.
   Rules can reference:
   - repository rules in the current grammar
   - the grammar itself using `$self`
   - another grammar by scope name

4. Captures are part of the public parsing behavior.
   Scope assignment is not only attached to the entire rule match. Individual regex capture groups can receive separate scopes.

5. Recursive constructs are expected.
   The spec explicitly shows balanced nesting implemented through repository recursion, so the parser and resolver must tolerate recursive rule graphs.

These constraints suggest a layered design rather than a single monolithic parser object.

## High-Level Architecture

The package should be split into a few major subsystems:

1. Grammar loading
2. Grammar normalization and validation
3. Include/reference resolution
4. Parsing engine
5. Public result model and API
6. Test fixtures and verification helpers

This separation keeps the parser focused on matching behavior rather than file decoding or raw dictionary traversal.

## Proposed Package Layout

Recommended initial layout:

```text
Sources/
  SyntaxKit/
    PublicAPI/
    Model/
    Grammar/
    Resolver/
    Regex/
    Parser/
    Diagnostics/
Tests/
  SyntaxKitTests/
    Fixtures/
    GrammarLoading/
    Resolution/
    Parsing/
    Integration/
```

Suggested responsibilities:

- `PublicAPI/`
  - Entry points for loading grammars and parsing text
  - Stable types meant for library consumers

- `Model/`
  - Core shared types such as scopes, spans, captures, parser state, and diagnostics

- `Grammar/`
  - Raw plist decoding
  - Typed grammar/rule definitions
  - Validation and normalization

- `Resolver/`
  - Include resolution
  - Repository lookup
  - Cross-grammar lookup by scope name

- `Regex/`
  - Regex abstraction layer
  - Match result normalization
  - Backreference substitution support for `end` patterns

- `Parser/`
  - Stateful line parser
  - Rule application engine
  - Context stack transitions

- `Diagnostics/`
  - Validation errors
  - Resolution errors
  - Parser warnings or unsupported feature markers

## Phase 1: Package Scaffolding

### Deliverables

- Initialize a Swift package
- Define target structure
- Add test target
- Add a small set of fixture grammars and fixture source files

### Decisions

- Use Swift Package Manager
- Depend only on Foundation unless a strong reason appears later
- Keep APIs synchronous for v1

### Why This First

Because the workspace is empty, scaffolding is the shortest path to meaningful progress. It also forces early decisions about module boundaries and test organization.

## Phase 2: Grammar Data Model

### Objective

Represent the `tmLanguage` format in strongly typed Swift structures.

### Recommended Types

At minimum, define:

- `Grammar`
- `RawGrammar`
- `Rule`
- `RawRule`
- `CaptureRule`
- `Repository`
- `IncludeReference`
- `ScopeName`

### Raw vs Normalized Model

Use a two-step approach:

1. `Raw*` types represent decoded plist data as closely as possible.
2. Normalized types transform raw values into a parser-friendly representation with validation already applied.

This is worth the extra code because:

- The plist shape is permissive
- Validation errors should be isolated to the loading phase
- The parser should not need to branch around malformed input constantly

### Validation Rules

Add validation for:

- A grammar must have a `scopeName`
- A rule must not define both `match` and `begin`/`end`
- A `begin` rule should also have an `end` rule for v1 unless explicitly modeled as recoverable malformed input
- `captures`, `beginCaptures`, and `endCaptures` should only refer to non-negative capture group indices
- Include references should be syntactically classified as:
  - repository include
  - self include
  - external grammar include

### Output of This Phase

A validated in-memory grammar model that can be consumed without raw plist knowledge.

## Phase 3: Grammar Loading

### Objective

Load TextMate grammars from plist-based `.tmLanguage` files.

### Loading Approach

Use Foundation property list support first. The linked spec describes grammars in property list format, so the initial loader should target that directly.

Potential entry points:

- `GrammarLoader.load(url:)`
- `GrammarLoader.load(data:)`
- `GrammarLoader.load(string:)`

### Behaviors

- Parse plist into raw representation
- Normalize into validated grammar model
- Return structured diagnostics on failure

### Notes

- Keep filesystem concerns outside the parser
- Grammar loading should not automatically resolve external includes yet
- The loader should preserve enough source context to produce useful error messages

## Phase 4: Include Resolution

### Objective

Resolve all `include` references into navigable rule references without flattening away important semantics.

### Include Forms to Support

1. Repository include: `#ruleName`
2. Self include: `$self`
3. External grammar include: `source.some-language`

### Design Recommendation

Create a resolver abstraction that has access to:

- The current grammar
- A registry of other grammars keyed by `scopeName`

Suggested types:

- `GrammarRegistry`
- `ResolvedGrammar`
- `ResolvedRule`
- `ResolvedPattern`
- `IncludeResolver`

### Why Not Inline Expansion

Naively cloning rules into place will make recursion and debugging much harder. Instead, preserve references explicitly so the parser can walk a resolved graph without losing identity.

### Edge Cases

- Missing repository rule
- Missing external grammar
- Recursive repository references
- Mutual recursion between grammars

### Output of This Phase

A parser-ready rule graph where includes are represented as concrete references and the resolver has already rejected invalid references.

## Phase 5: Regex Abstraction

### Objective

Abstract regex execution enough that the parser is not tightly coupled to one matching API shape.

### Why a Dedicated Layer

TextMate grammars rely heavily on:

- Capture groups
- Positional matching from the current parsing index
- Backreferences from `begin` into `end`

Even if the initial implementation uses `NSRegularExpression`, a thin wrapper will reduce parser complexity and make future changes easier.

### Recommended Responsibilities

- Compile regex patterns
- Match against a single line or line slice
- Return captures with string ranges
- Support substitution of begin-capture values into end patterns
- Normalize range handling between Swift `String.Index` and UTF-16-backed APIs

### Important Detail

TextMate-like engines are extremely sensitive to range correctness. Plan for a careful strategy around:

- Source storage as `String`
- Per-line slices
- Converting capture ranges back into stable absolute ranges in the full document

## Phase 6: Parser State Model

### Objective

Define the state that moves line by line through the document.

### Core Concept

The parser must keep a stack of active contexts. Each open `begin`/`end` rule contributes a context with enough information to determine:

- Which end pattern is currently active
- Which nested patterns are available inside the region
- Which captures were recorded from the `begin` match
- Which scopes are applied to the full region and its content

### Recommended Types

- `ParserState`
- `ContextFrame`
- `ActiveRegion`
- `LineParseResult`
- `Token`
- `ScopeStack`
- `CaptureAssignment`

### What a Context Frame Should Store

- The resolved rule that opened the region
- The concrete end regex for this specific activation
- The begin match result, including captures
- The active content scope, if any
- The inherited scope stack from the parent

## Phase 7: Parsing Algorithm

### Objective

Implement a full-document parser that follows the TextMate line model.

### High-Level Algorithm

For each line in the document:

1. Start with the current parser state from the previous line.
2. At the current character position, first determine whether the current top context ends here.
3. Evaluate the available patterns for the current context.
4. Select the earliest valid match.
5. Emit tokens/scopes for:
   - matched region name
   - content name where appropriate
   - capture scopes
6. If the match is:
   - a `match` rule: emit and advance
   - a `begin` rule: push a new context and advance past the begin match
   - an `end` rule for the active context: close the context and advance
7. If nothing matches, advance by one unit or emit plain text under the current inherited scopes.
8. Continue until end of line, then carry the resulting context stack into the next line.

### Rule Selection Semantics

The parser must have a deterministic match selection strategy. At minimum:

- Prefer the earliest match position
- Resolve ties consistently
- Ensure the active context’s end match competes appropriately with nested patterns

This is a critical area to document in code because many subtle highlighting bugs originate here.

### End-of-Document Behavior

If a `begin`/`end` region is still open when the document ends, the spec says the region extends to the end of the document. The parser should therefore close any remaining open regions logically at EOF.

## Phase 8: Scope Emission Model

### Objective

Define what the parser produces.

### Recommended v1 Output

Return token spans with scope stacks. For example:

- Absolute source range
- Ordered list of scope names active over that range

Possible public type:

```swift
public struct SyntaxToken {
    public let range: Range<String.Index>
    public let scopes: [String]
}
```

Additional convenience representations can be added later:

- line-relative tokens
- UTF-16 or byte offsets
- flattened style-ready spans

### Why Scope Stacks

TextMate consumers typically care about the full scope stack, not just a single name, because theme and selector logic rely on ancestry.

## Phase 9: Capture Handling

### Objective

Implement correct scope assignment for captured subranges.

### Required Cases

- `captures` for `match` rules
- `beginCaptures` on opening delimiter
- `endCaptures` on closing delimiter
- `captures` shorthand on `begin`/`end` rules mapping to both begin and end captures

### Behavioral Notes

- Captures assign scope to subranges, not necessarily the full match
- Capture ranges may overlap with the enclosing rule name/content name
- Token emission should preserve a stable ordering when multiple scopes apply

This is a high-value area for early tests because many grammars depend on delimiter scopes and escape scopes.

## Phase 10: Embedded Grammars

### Objective

Support `include = "source.xyz"` style grammar embedding.

### Design

Use `GrammarRegistry` keyed by scope name.

The parser should be able to enter an embedded grammar’s top-level patterns while preserving the outer context stack. This is especially important for grammars like HTML with embedded JavaScript, CSS, or template languages.

### Risks

- Scope inheritance between host and embedded grammar
- Cross-grammar recursion
- Parser performance if includes are repeatedly re-resolved during parsing

### Mitigation

- Resolve includes ahead of time
- Keep embedded grammar entry points cached

## Phase 11: Testing Strategy

### Overall Approach

Use a fixture-driven test suite from the beginning. This project is mostly about behavioral correctness, so tests should mirror real grammar examples and expected scope outputs.

### Test Categories

1. Grammar loading tests
   - Valid plist grammar loads successfully
   - Malformed grammar reports useful errors

2. Validation tests
   - Illegal combinations of rule keys are rejected
   - Missing includes are diagnosed

3. Resolver tests
   - Repository includes resolve
   - `$self` resolves
   - External grammar includes resolve through the registry
   - Recursive rule graphs do not crash resolution

4. Parser unit tests
   - Single `match` tokenization
   - `begin`/`end` region parsing across lines
   - `contentName`
   - begin/end capture application
   - unterminated region behavior

5. Integration tests
   - String interpolation
   - Balanced recursive delimiters
   - Embedded language block handling

### Suggested Early Fixtures

- A minimal toy language
- Quoted string with escapes
- Here-doc style region using backreference in `end`
- Parentheses-balanced recursive construct from a repository rule
- HTML-like grammar that embeds a second grammar

### Assertion Style

Prefer asserting on:

- ordered token ranges
- emitted scope stacks
- final parser stack state where relevant

Snapshot-style helpers may also be useful once the token output stabilizes.

## Phase 12: Diagnostics and Error Handling

### Objective

Make failures understandable without complicating the parser API.

### Diagnostics Should Cover

- Invalid grammar structure
- Unknown include target
- Unsupported or malformed regex
- Ambiguous or invalid capture definitions

### Recommendation

Use typed errors for fatal failures and optional warnings for recoverable issues.

Examples:

- `GrammarLoadingError`
- `GrammarValidationError`
- `ResolutionError`
- `RegexCompilationError`

This will help library users debug grammar issues without stepping into parser internals.

## Phase 13: Performance Considerations

### v1 Performance Principles

- Compile regex patterns once
- Resolve includes once
- Avoid repeated dictionary traversal during parsing
- Avoid unnecessary string copies for per-line operations

### Do Not Prematurely Optimize

Do not attempt incremental parsing before the full parser is correct and test-covered.

### Future Performance Work

After correctness:

- Incremental line reparsing
- Parse caching per line or region
- Faster range conversion utilities
- Arena-style storage for parser frames or tokens if needed

## Phase 14: Incremental Parsing Roadmap

This is not required for the initial implementation, but the design should leave room for it.

### Future Direction

Maintain parser state snapshots at line boundaries so reparsing can start from the nearest known valid state and continue until the state converges again.

### Why This Matters

The TextMate spec’s line-based design is specifically motivated by efficient reparsing after edits, so the architecture should not close that door.

## Open Design Questions

These should be answered during implementation, but they do not block initial scaffolding:

1. Public range type
   Should public tokens expose `String.Index` ranges, UTF-16 offsets, or line/column coordinates?

2. Regex backend
   Is `NSRegularExpression` sufficient for all required backreference behavior, or should the abstraction be broader from day one?

3. Token normalization
   Should overlapping scope applications be flattened eagerly into non-overlapping spans, or should the parser preserve richer intermediate structure?

4. External grammar discovery
   Should grammar lookup be fully manual in v1, or should a convenience loader support loading multiple grammars into a registry?

## Recommended Build Order

Implement in this order:

1. Swift package scaffolding
2. Raw plist grammar loading
3. Normalized grammar model and validation
4. Include resolution and grammar registry
5. Regex wrapper and range utilities
6. Basic `match` rule parsing
7. `begin`/`end` region parsing
8. Capture application
9. Recursive repository rules
10. Embedded grammar support
11. Public API cleanup
12. Broader fixture suite

This order minimizes the chance of building parser logic on unstable foundations.

## Definition of Done for v1

The first version should be considered complete when all of the following are true:

- A `.tmLanguage` plist can be loaded into Swift types
- Includes resolve for repository rules, `$self`, and external grammars
- A document can be parsed line by line with persistent state
- `match` and `begin`/`end` rules both work
- Capture scopes are emitted
- Recursive rules work on at least one representative balanced-construct fixture
- Embedded grammar includes work in at least one representative fixture
- The parser returns stable token/scope output
- The test suite covers the major behaviors listed in this plan

## Immediate Next Steps

The next concrete implementation steps should be:

1. Create `Package.swift` and the source/test directory layout
2. Define raw and normalized grammar model types
3. Implement plist loading for a minimal grammar fixture
4. Add validation tests for illegal rule combinations
5. Implement the first resolver pass for repository includes

Once those are in place, the parser can be built on a stable base instead of raw dictionaries.
