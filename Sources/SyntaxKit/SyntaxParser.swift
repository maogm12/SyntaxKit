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
        guard let resolvedGrammar = resolvedGrammar ?? defaultGrammar else {
            throw SyntaxKitError.parsing("No grammar provided for parse request.")
        }

        var builder = SpanBuilder()
        var contexts: [ContextFrame] = []
        let lines = splitLines(text)
        let rootScopes = [resolvedGrammar.scopeName.rawValue]

        for lineInfo in lines {
            var cursor = 0
            let lineLength = lineInfo.textUTF16Length

            while cursor < lineLength {
                let activeScopes = contexts.last?.contentScopes ?? rootScopes
                guard let candidate = try bestCandidate(
                    in: lineInfo.text,
                    at: cursor,
                    contexts: contexts,
                    rootGrammar: resolvedGrammar.grammar
                ) else {
                    builder.add(
                        start: lineInfo.startUTF16 + cursor,
                        end: lineInfo.startUTF16 + lineLength,
                        line: lineInfo.number,
                        column: cursor + 1,
                        scopes: activeScopes
                    )
                    cursor = lineLength
                    continue
                }

                if candidate.start > cursor {
                    builder.add(
                        start: lineInfo.startUTF16 + cursor,
                        end: lineInfo.startUTF16 + candidate.start,
                        line: lineInfo.number,
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
                        lineInfo: lineInfo,
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
                        lineInfo: lineInfo,
                        match: match,
                        baseScopes: scopes,
                        captures: rule.captures
                    )
                    cursor = match.range.length == 0 ? min(cursor + 1, lineLength) : match.range.location + match.range.length
                case .begin(let rule, let grammar, let match):
                    let delimiterScopes = activeScopes + scopeComponents(from: rule.name)
                    emitSegmentedMatch(
                        builder: &builder,
                        lineInfo: lineInfo,
                        match: match,
                        baseScopes: delimiterScopes,
                        captures: rule.effectiveBeginCaptures
                    )

                    let resolvedEnd = substituteBackreferences(
                        pattern: rule.end!,
                        using: match,
                        in: lineInfo.text
                    )
                    let endRegex = try registry.compiledRegex(for: resolvedEnd)
                    let contentScopes = delimiterScopes + scopeComponents(from: rule.contentName)
                    contexts.append(
                        ContextFrame(
                            rule: rule,
                            grammar: grammar,
                            endRegex: endRegex,
                            delimiterScopes: delimiterScopes,
                            contentScopes: contentScopes.isEmpty ? delimiterScopes : contentScopes
                        )
                    )
                    cursor = match.range.length == 0 ? min(cursor + 1, lineLength) : match.range.location + match.range.length
                }
            }
        }

        return ParseResult(scopeName: resolvedGrammar.scopeName, spans: builder.spans, diagnostics: [])
    }

    public func tokenize(_ text: String, using scopeName: String) throws -> [SyntaxSpan] {
        try parse(text, using: scopeName).spans
    }

    private func bestCandidate(
        in line: String,
        at location: Int,
        contexts: [ContextFrame],
        rootGrammar: Grammar
    ) throws -> Candidate? {
        var best: Candidate?

        if let context = contexts.last, let match = firstMatch(regex: context.endRegex, in: line, from: location) {
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
                guard let match = firstMatch(regex: regex, in: line, from: location) else { continue }
                let candidate = Candidate(kind: .match(rule, resolvedRule.grammar, match), start: match.range.location, order: index)
                best = chooseBetter(current: best, challenger: candidate)
            } else if let beginPattern = rule.begin {
                let regex = try registry.compiledRegex(for: beginPattern)
                guard let match = firstMatch(regex: regex, in: line, from: location) else { continue }
                let candidate = Candidate(kind: .begin(rule, resolvedRule.grammar, match), start: match.range.location, order: index)
                best = chooseBetter(current: best, challenger: candidate)
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

    private func availablePatterns(in grammar: Grammar, from rules: [Rule]) throws -> [ResolvedRule] {
        var results: [ResolvedRule] = []
        var visited = Set<String>()
        try expand(rules, in: grammar, visited: &visited, into: &results)
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

private struct ResolvedRule {
    let rule: Rule
    let grammar: Grammar
}

private struct ContextFrame {
    let rule: Rule
    let grammar: Grammar
    let endRegex: NSRegularExpression
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
