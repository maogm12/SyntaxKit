import Foundation

public final class GrammarRegistry: @unchecked Sendable {
    private var grammars: [ScopeName: Grammar]
    let regexEngine: any RegexEngine

    public init(grammars: [Grammar] = [], regexEngine: any RegexEngine = DefaultRegexEngine()) {
        self.grammars = [:]
        self.regexEngine = regexEngine
        for grammar in grammars {
            self.grammars[grammar.scopeName] = grammar
        }
    }

    public func register(_ grammar: Grammar) {
        grammars[grammar.scopeName] = grammar
    }

    public func register(contentsOf grammars: [Grammar]) {
        for grammar in grammars {
            register(grammar)
        }
    }

    public func grammar(for scopeName: String) -> Grammar? {
        grammars[ScopeName(rawValue: scopeName)]
    }

    public func resolve(scopeName: String) throws -> ResolvedGrammar {
        let scope = ScopeName(rawValue: scopeName)
        guard let grammar = grammars[scope] else {
            throw SyntaxKitError.resolution("No grammar registered for scope '\(scopeName)'.")
        }

        var visitedRules = Set<String>()
        try validatePatterns(grammar.patterns, in: grammar, visitedRules: &visitedRules)
        try validatePatterns(Array(grammar.repository.values), in: grammar, visitedRules: &visitedRules)
        return ResolvedGrammar(scopeName: grammar.scopeName, grammar: grammar)
    }

    func compiledRegex(for pattern: String) throws -> CompiledRegex {
        try regexEngine.compile(pattern: pattern)
    }

    public var registeredScopeNames: [String] {
        grammars.keys.map(\.rawValue).sorted()
    }

    private func validatePatterns(_ rules: [Rule], in grammar: Grammar, visitedRules: inout Set<String>) throws {
        for rule in rules {
            let token = "\(grammar.scopeName.rawValue)#\(rule.id)"
            if visitedRules.contains(token) {
                continue
            }
            visitedRules.insert(token)

            if let pattern = rule.match {
                _ = try compiledRegex(for: pattern)
            }
            if let pattern = rule.begin {
                _ = try compiledRegex(for: pattern)
            }
            if let pattern = rule.end {
                if !pattern.syntaxKitContainsBackreference {
                    _ = try compiledRegex(for: pattern)
                }
            }

            if let include = rule.include {
                switch IncludeReference(rawValue: include) {
                case .repository(let name):
                    guard let nested = grammar.repository[name] else {
                        throw SyntaxKitError.resolution("Grammar '\(grammar.scopeName)' includes missing repository rule '#\(name)'.")
                    }
                    try validatePatterns([nested], in: grammar, visitedRules: &visitedRules)
                case .self:
                    try validatePatterns(grammar.patterns, in: grammar, visitedRules: &visitedRules)
                case .external(let scope):
                    guard let externalGrammar = grammars[scope] else {
                        throw SyntaxKitError.resolution("Grammar '\(grammar.scopeName)' includes unknown external grammar '\(scope.rawValue)'.")
                    }
                    try validatePatterns(externalGrammar.patterns, in: externalGrammar, visitedRules: &visitedRules)
                    try validatePatterns(Array(externalGrammar.repository.values), in: externalGrammar, visitedRules: &visitedRules)
                }
            }

            try validatePatterns(rule.patterns, in: grammar, visitedRules: &visitedRules)
        }
    }
}
