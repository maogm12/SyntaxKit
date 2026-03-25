import Foundation

public final class SyntaxParser {
    private let registry: GrammarRegistry
    private let defaultGrammar: ResolvedGrammar?

    public init(registry: GrammarRegistry) {
        self.registry = registry
        self.defaultGrammar = nil
    }

    public init(resolvedGrammar: ResolvedGrammar, registry: GrammarRegistry) {
        self.registry = registry
        self.defaultGrammar = resolvedGrammar
    }

    public func parse(_ text: String, using scopeName: String) throws -> ParseResult {
        let resolved = try registry.resolve(scopeName: scopeName)
        return try parse(text, using: resolved)
    }

    public func parse(_ text: String, using resolvedGrammar: ResolvedGrammar? = nil) throws -> ParseResult {
        try parseIncrementally(text, using: resolvedGrammar).parseResult
    }

    public func parseIncrementally(_ text: String, using scopeName: String) throws -> IncrementalParseResult {
        let resolved = try registry.resolve(scopeName: scopeName)
        return try parseIncrementally(text, using: resolved)
    }

    public func parseIncrementally(_ text: String, using resolvedGrammar: ResolvedGrammar? = nil) throws -> IncrementalParseResult {
        guard let resolvedGrammar = resolvedGrammar ?? defaultGrammar else {
            throw SyntaxKitError.parsing("No grammar provided for parse request.")
        }

        return try parseCore(
            text,
            using: resolvedGrammar,
            startingAtLine: 1,
            startingUTF16Offset: 0,
            initialContexts: []
        )
    }

    public func reparse(_ text: String, using scopeName: String, from lineState: SyntaxLineState) throws -> IncrementalParseResult {
        let resolved = try registry.resolve(scopeName: scopeName)
        return try reparse(text, using: resolved, from: lineState)
    }

    public func reparse(
        _ text: String,
        using resolvedGrammar: ResolvedGrammar? = nil,
        from lineState: SyntaxLineState
    ) throws -> IncrementalParseResult {
        guard let resolvedGrammar = resolvedGrammar ?? defaultGrammar else {
            throw SyntaxKitError.parsing("No grammar provided for parse request.")
        }

        return try parseCore(
            text,
            using: resolvedGrammar,
            startingAtLine: lineState.line + 1,
            startingUTF16Offset: lineState.nextUTF16Offset,
            initialContexts: try restoreContexts(from: lineState.contexts)
        )
    }

    public func tokenizeIncrementally(_ text: String, using scopeName: String) throws -> IncrementalParseResult {
        try parseIncrementally(text, using: scopeName)
    }

    private func parseCore(
        _ text: String,
        using resolvedGrammar: ResolvedGrammar,
        startingAtLine: Int,
        startingUTF16Offset: Int,
        initialContexts: [ContextFrame]
    ) throws -> IncrementalParseResult {
        try validateCompiledPatterns(in: resolvedGrammar.grammar)

        var builder = SpanBuilder()
        var contexts = initialContexts
        var lineStates: [SyntaxLineState] = []
        let lines = splitLines(text)
        let rootScopes = [resolvedGrammar.scopeName.rawValue]

        for lineInfo in lines {
            let absoluteLineInfo = LineInfo(
                number: lineInfo.number + startingAtLine - 1,
                startUTF16: lineInfo.startUTF16 + startingUTF16Offset,
                text: lineInfo.text
            )
            var cursor = 0
            let lineLength = absoluteLineInfo.textUTF16Length

            while cursor < lineLength {
                let activeScopes = contexts.last?.contentScopes ?? rootScopes
                guard let candidate = try bestCandidate(
                    in: absoluteLineInfo.text,
                    at: cursor,
                    contexts: contexts,
                    rootGrammar: resolvedGrammar.grammar
                ) else {
                    builder.add(
                        start: absoluteLineInfo.startUTF16 + cursor,
                        end: absoluteLineInfo.startUTF16 + lineLength,
                        line: absoluteLineInfo.number,
                        column: cursor + 1,
                        scopes: activeScopes
                    )
                    cursor = lineLength
                    continue
                }

                if candidate.start > cursor {
                    builder.add(
                        start: absoluteLineInfo.startUTF16 + cursor,
                        end: absoluteLineInfo.startUTF16 + candidate.start,
                        line: absoluteLineInfo.number,
                        column: cursor + 1,
                        scopes: activeScopes
                    )
                    cursor = candidate.start
                    continue
                }

                switch candidate.kind {
                case .end(let match):
                    let context = contexts[contexts.count - 1]
                    let scopes = context.delimiterScopes
                    emitSegmentedMatch(
                        builder: &builder,
                        lineInfo: absoluteLineInfo,
                        match: match,
                        baseScopes: scopes,
                        captures: context.rule.effectiveEndCaptures
                    )
                    if match.range.length == 0 {
                        contexts.removeLast()
                        continue
                    } else {
                        contexts.removeLast()
                        cursor = match.range.location + match.range.length
                    }
                case .match(let rule, _, let match):
                    let scopes = activeScopes + scopeComponents(from: rule.name)
                    emitSegmentedMatch(
                        builder: &builder,
                        lineInfo: absoluteLineInfo,
                        match: match,
                        baseScopes: scopes,
                        captures: rule.captures
                    )
                    cursor = match.range.length == 0 ? min(cursor + 1, lineLength) : match.range.location + match.range.length
                case .begin(let rule, let grammar, let match):
                    let delimiterScopes = activeScopes + scopeComponents(from: rule.name)
                    emitSegmentedMatch(
                        builder: &builder,
                        lineInfo: absoluteLineInfo,
                        match: match,
                        baseScopes: delimiterScopes,
                        captures: rule.effectiveBeginCaptures
                    )

                    guard let endPattern = rule.end else {
                        throw SyntaxKitError.parsing("Begin rule \(rule.id) is missing required 'end' pattern.")
                    }

                    let resolvedEnd = registry.regexEngine.substituteBackreferences(
                        in: endPattern,
                        using: match,
                        line: absoluteLineInfo.text
                    )
                    let endRegex = try registry.compiledRegex(for: resolvedEnd)
                    let contentScopes = delimiterScopes + scopeComponents(from: rule.contentName)
                    contexts.append(
                        ContextFrame(
                            rule: rule,
                            grammar: grammar,
                            endPattern: resolvedEnd,
                            endRegex: endRegex,
                            delimiterScopes: delimiterScopes,
                            contentScopes: contentScopes.isEmpty ? delimiterScopes : contentScopes
                        )
                    )
                    cursor = match.range.length == 0 ? min(cursor + 1, lineLength) : match.range.location + match.range.length
                }
            }

            lineStates.append(
                SyntaxLineState(
                    line: absoluteLineInfo.number,
                    nextUTF16Offset: absoluteLineInfo.startUTF16 + lineLength,
                    contexts: contexts.map(snapshot(from:))
                )
            )
        }

        return IncrementalParseResult(
            parseResult: ParseResult(scopeName: resolvedGrammar.scopeName, spans: builder.spans, diagnostics: []),
            lineStates: lineStates
        )
    }

    public func tokenize(_ text: String, using scopeName: String) throws -> [SyntaxSpan] {
        try parse(text, using: scopeName).spans
    }

    private func snapshot(from context: ContextFrame) -> SyntaxContextSnapshot {
        SyntaxContextSnapshot(
            grammarScopeName: context.grammar.scopeName,
            ruleID: context.rule.id,
            endPattern: context.endPattern,
            delimiterScopes: context.delimiterScopes,
            contentScopes: context.contentScopes
        )
    }

    private func restoreContexts(from snapshots: [SyntaxContextSnapshot]) throws -> [ContextFrame] {
        try snapshots.map { snapshot in
            guard let grammar = registry.grammar(for: snapshot.grammarScopeName.rawValue) else {
                throw SyntaxKitError.parsing("Missing grammar '\(snapshot.grammarScopeName.rawValue)' for incremental parse state.")
            }
            guard let rule = findRule(withID: snapshot.ruleID, in: grammar) else {
                throw SyntaxKitError.parsing("Missing rule \(snapshot.ruleID) in grammar '\(snapshot.grammarScopeName.rawValue)' for incremental parse state.")
            }
            return ContextFrame(
                rule: rule,
                grammar: grammar,
                endPattern: snapshot.endPattern,
                endRegex: try registry.compiledRegex(for: snapshot.endPattern),
                delimiterScopes: snapshot.delimiterScopes,
                contentScopes: snapshot.contentScopes
            )
        }
    }

    private func findRule(withID id: Int, in grammar: Grammar) -> Rule? {
        for rule in grammar.patterns {
            if let found = findRule(withID: id, in: rule) {
                return found
            }
        }
        for rule in grammar.repository.values {
            if let found = findRule(withID: id, in: rule) {
                return found
            }
        }
        return nil
    }

    private func findRule(withID id: Int, in rule: Rule) -> Rule? {
        if rule.id == id {
            return rule
        }
        for nested in rule.patterns {
            if let found = findRule(withID: id, in: nested) {
                return found
            }
        }
        return nil
    }

    private func validateCompiledPatterns(in grammar: Grammar) throws {
        var visitedRules = Set<String>()
        try validateCompiledPatterns(grammar.patterns, in: grammar, visitedRules: &visitedRules)
        try validateCompiledPatterns(Array(grammar.repository.values), in: grammar, visitedRules: &visitedRules)
    }

    private func validateCompiledPatterns(_ rules: [Rule], in grammar: Grammar, visitedRules: inout Set<String>) throws {
        for rule in rules {
            let token = "\(grammar.scopeName.rawValue)#\(rule.id)"
            if visitedRules.contains(token) {
                continue
            }
            visitedRules.insert(token)

            if let pattern = rule.match {
                _ = try registry.compiledRegex(for: pattern)
            }
            if let pattern = rule.begin {
                _ = try registry.compiledRegex(for: pattern)
            }
            if let pattern = rule.end, !pattern.syntaxKitContainsBackreference {
                _ = try registry.compiledRegex(for: pattern)
            }

            if let include = rule.include {
                switch IncludeReference(rawValue: include) {
                case .repository(let name):
                    guard let nested = grammar.repository[name] else {
                        throw SyntaxKitError.parsing("Missing repository rule '#\(name)' while validating grammar '\(grammar.scopeName.rawValue)'.")
                    }
                    try validateCompiledPatterns([nested], in: grammar, visitedRules: &visitedRules)
                case .self:
                    try validateCompiledPatterns(grammar.patterns, in: grammar, visitedRules: &visitedRules)
                case .external(let scope):
                    guard let externalGrammar = registry.grammar(for: scope.rawValue) else {
                        throw SyntaxKitError.parsing("Missing external grammar '\(scope.rawValue)' while validating grammar '\(grammar.scopeName.rawValue)'.")
                    }
                    try validateCompiledPatterns(externalGrammar.patterns, in: externalGrammar, visitedRules: &visitedRules)
                    try validateCompiledPatterns(Array(externalGrammar.repository.values), in: externalGrammar, visitedRules: &visitedRules)
                }
            }

            try validateCompiledPatterns(rule.patterns, in: grammar, visitedRules: &visitedRules)
        }
    }

    private func bestCandidate(
        in line: String,
        at location: Int,
        contexts: [ContextFrame],
        rootGrammar: Grammar
    ) throws -> Candidate? {
        var best: Candidate?

        if let context = contexts.last, let match = context.endRegex.firstMatch(in: line, from: location) {
            if match.range.location == location {
                return Candidate(
                    kind: .end(match),
                    start: match.range.location,
                    order: -1
                )
            }
            best = Candidate(
                kind: .end(match),
                start: match.range.location,
                order: -1
            )
        }

        let patterns = try availablePatterns(in: contexts.last?.grammar ?? rootGrammar, from: contexts.last?.rule.patterns ?? rootGrammar.patterns)
        for (index, resolvedRule) in patterns.enumerated() {
            let rule = resolvedRule.rule
            if let matchPattern = rule.match {
                let regex = try registry.compiledRegex(for: matchPattern)
                guard let match = regex.firstMatch(in: line, from: location) else { continue }
                if match.range.location == location {
                    return Candidate(kind: .match(rule, resolvedRule.grammar, match), start: match.range.location, order: index)
                }
                best = chooseBetter(current: best, challenger: Candidate(kind: .match(rule, resolvedRule.grammar, match), start: match.range.location, order: index))
            } else if let beginPattern = rule.begin {
                let regex = try registry.compiledRegex(for: beginPattern)
                guard let match = regex.firstMatch(in: line, from: location) else { continue }
                if match.range.location == location {
                    return Candidate(kind: .begin(rule, resolvedRule.grammar, match), start: match.range.location, order: index)
                }
                best = chooseBetter(current: best, challenger: Candidate(kind: .begin(rule, resolvedRule.grammar, match), start: match.range.location, order: index))
            }
        }

        return best
    }

    private func chooseBetter(current: Candidate?, challenger: Candidate) -> Candidate {
        guard let current else { return challenger }
        if challenger.start < current.start {
            return challenger
        }
        if challenger.start > current.start {
            return current
        }

        switch current.kind {
        case .end:
            return current
        case .match, .begin:
            return challenger.order < current.order ? challenger : current
        }
    }

    func availablePatterns(in grammar: Grammar, from rules: [Rule]) throws -> [ResolvedRule] {
        if let cached = registry.cachedPatterns(for: grammar, rules: rules) {
            return cached
        }

        var results: [ResolvedRule] = []
        var visited = Set<String>()
        try expand(rules, in: grammar, visited: &visited, into: &results)
        
        registry.setCachedPatterns(results, for: grammar, rules: rules)
        return results
    }

    private func expand(_ rules: [Rule], in grammar: Grammar, visited: inout Set<String>, into results: inout [ResolvedRule]) throws {
        for rule in rules {
            if let include = rule.include {
                let token = "\(grammar.scopeName.rawValue)::include::\(include)"
                if visited.contains(token) {
                    continue
                }
                visited.insert(token)
                switch IncludeReference(rawValue: include) {
                case .repository(let name):
                    guard let nested = grammar.repository[name] else {
                        throw SyntaxKitError.resolution("Missing repository rule '#\(name)' in grammar '\(grammar.scopeName.rawValue)'.")
                    }
                    try expand([nested], in: grammar, visited: &visited, into: &results)
                case .self:
                    try expand(grammar.patterns, in: grammar, visited: &visited, into: &results)
                case .external(let scope):
                    guard let external = registry.grammar(for: scope.rawValue) else {
                        throw SyntaxKitError.resolution("Missing external grammar '\(scope.rawValue)'.")
                    }
                    try expand(external.patterns, in: external, visited: &visited, into: &results)
                }
                continue
            }

            if rule.match != nil || rule.begin != nil {
                results.append(ResolvedRule(rule: rule, grammar: grammar))
            } else if !rule.patterns.isEmpty {
                let token = "\(grammar.scopeName.rawValue)::container::\(rule.id)"
                if visited.contains(token) {
                    continue
                }
                visited.insert(token)
                try expand(rule.patterns, in: grammar, visited: &visited, into: &results)
            }
        }
    }
}

struct ResolvedRule {
    let rule: Rule
    let grammar: Grammar
}

private struct ContextFrame {
    let rule: Rule
    let grammar: Grammar
    let endPattern: String
    let endRegex: CompiledRegex
    let delimiterScopes: [String]
    let contentScopes: [String]
}

private enum CandidateKind {
    case end(RegexMatch)
    case match(Rule, Grammar, RegexMatch)
    case begin(Rule, Grammar, RegexMatch)
}

private struct Candidate {
    let kind: CandidateKind
    let start: Int
    let order: Int
}

private struct LineInfo {
    let number: Int
    let startUTF16: Int
    let text: String

    var textUTF16Length: Int { text.utf16.count }
}

private struct SpanBuilder {
    private(set) var spans: [SyntaxSpan] = []

    mutating func add(start: Int, end: Int, line: Int, column: Int, scopes: [String]) {
        guard start < end, !scopes.isEmpty else { return }
        spans.append(SyntaxSpan(startUTF16: start, endUTF16: end, line: line, column: column, scopes: scopes))
    }
}

private func splitLines(_ text: String) -> [LineInfo] {
    if text.isEmpty {
        return [LineInfo(number: 1, startUTF16: 0, text: "")]
    }

    var lines: [LineInfo] = []
    var current = ""
    var lineNumber = 1
    var lineStart = 0

    func flushLine() {
        lines.append(LineInfo(number: lineNumber, startUTF16: lineStart, text: current))
        lineStart += current.utf16.count
        lineNumber += 1
        current.removeAll(keepingCapacity: true)
    }

    var iterator = text.makeIterator()
    while let character = iterator.next() {
        current.append(character)
        if character == "\n" {
            flushLine()
        }
    }

    if !current.isEmpty {
        lines.append(LineInfo(number: lineNumber, startUTF16: lineStart, text: current))
    }

    return lines
}

private func scopeComponents(from value: String?) -> [String] {
    value?.syntaxKitScopeComponents ?? []
}

private func emitSegmentedMatch(
    builder: inout SpanBuilder,
    lineInfo: LineInfo,
    match: RegexMatch,
    baseScopes: [String],
    captures: [Capture]
) {
    let fullRange = match.range
    guard fullRange.location != NSNotFound, fullRange.length >= 0 else { return }

    var boundaries = [fullRange.location, fullRange.location + fullRange.length]
    for capture in captures {
        if let range = match.captures[capture.index], range.location != NSNotFound, range.length > 0 {
            boundaries.append(range.location)
            boundaries.append(range.location + range.length)
        }
    }

    let sortedBoundaries = Array(Set(boundaries)).sorted()
    guard sortedBoundaries.count >= 2 else { return }

    for index in 0..<(sortedBoundaries.count - 1) {
        let start = sortedBoundaries[index]
        let end = sortedBoundaries[index + 1]
        guard start < end else { continue }
        guard start >= fullRange.location, end <= fullRange.location + fullRange.length else { continue }

        var scopes = baseScopes
        for capture in captures {
            guard let captureRange = match.captures[capture.index],
                  captureRange.location != NSNotFound,
                  captureRange.length > 0 else {
                continue
            }
            let captureStart = captureRange.location
            let captureEnd = captureRange.location + captureRange.length
            if start >= captureStart && end <= captureEnd {
                scopes.append(contentsOf: capture.name.syntaxKitScopeComponents)
            }
        }

        builder.add(
            start: lineInfo.startUTF16 + start,
            end: lineInfo.startUTF16 + end,
            line: lineInfo.number,
            column: start + 1,
            scopes: scopes
        )
    }
}
