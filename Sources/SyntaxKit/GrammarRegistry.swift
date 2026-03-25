import Foundation

public final class GrammarRegistry: @unchecked Sendable {
    private var grammars: [ScopeName: Grammar]
    private var patternCache: [String: [ResolvedRule]] = [:]
    private let lock = NSLock()
    let regexEngine: any RegexEngine

    public init(grammars: [Grammar] = [], regexEngine: any RegexEngine = DefaultRegexEngine()) {
        self.grammars = [:]
        self.regexEngine = regexEngine
        for grammar in grammars {
            self.grammars[grammar.scopeName] = grammar
        }
    }

    public func register(_ grammar: Grammar) {
        lock.lock()
        defer { lock.unlock() }
        grammars[grammar.scopeName] = grammar
        patternCache.removeAll()
    }

    public func register(contentsOf grammars: [Grammar]) {
        lock.lock()
        defer { lock.unlock() }
        for grammar in grammars {
            self.grammars[grammar.scopeName] = grammar
        }
        patternCache.removeAll()
    }

    func cachedPatterns(for grammar: Grammar, parent: Rule?) -> [ResolvedRule]? {
        lock.lock()
        defer { lock.unlock() }
        let key = cacheKey(for: grammar, parent: parent)
        return patternCache[key]
    }

    func setCachedPatterns(_ resolved: [ResolvedRule], for grammar: Grammar, parent: Rule?) {
        lock.lock()
        defer { lock.unlock() }
        let key = cacheKey(for: grammar, parent: parent)
        patternCache[key] = resolved
    }

    private func cacheKey(for grammar: Grammar, parent: Rule?) -> String {
        "\(grammar.scopeName.rawValue)[\(parent?.id ?? -1)]"
    }

    public func grammar(for scopeName: String) -> Grammar? {
        lock.lock()
        defer { lock.unlock() }
        return grammars[ScopeName(rawValue: scopeName)]
    }

    public func resolve(scopeName: String) throws -> ResolvedGrammar {
        let scope = ScopeName(rawValue: scopeName)
        
        lock.lock()
        let grammar = grammars[scope]
        lock.unlock()

        guard let grammar = grammar else {
            throw SyntaxKitError.resolution("No grammar registered for scope '\(scopeName)'.")
        }

        var visitedRules = Set<String>()
        try validateReferences(grammar.patterns, in: grammar, visitedRules: &visitedRules)
        try validateReferences(Array(grammar.repository.values), in: grammar, visitedRules: &visitedRules)
        return ResolvedGrammar(scopeName: grammar.scopeName, grammar: grammar)
    }

    func compiledRegex(for pattern: String) throws -> CompiledRegex {
        try regexEngine.compile(pattern: pattern)
    }

    public var registeredScopeNames: [String] {
        lock.lock()
        defer { lock.unlock() }
        return grammars.keys.map(\.rawValue).sorted()
    }

    private func validateReferences(_ rules: [Rule], in grammar: Grammar, visitedRules: inout Set<String>) throws {
        for rule in rules {
            let token = "\(grammar.scopeName.rawValue)#\(rule.id)"
            if visitedRules.contains(token) {
                continue
            }
            visitedRules.insert(token)

            if let include = rule.include {
                switch IncludeReference(rawValue: include) {
                case .repository(let name):
                    guard let nested = grammar.repository[name] else {
                        throw SyntaxKitError.resolution("Grammar '\(grammar.scopeName)' includes missing repository rule '#\(name)'.")
                    }
                    try validateReferences([nested], in: grammar, visitedRules: &visitedRules)
                case .self:
                    try validateReferences(grammar.patterns, in: grammar, visitedRules: &visitedRules)
                case .external(let scope):
                    lock.lock()
                    let externalGrammar = grammars[scope]
                    lock.unlock()
                    
                    guard let externalGrammar = externalGrammar else {
                        throw SyntaxKitError.resolution("Grammar '\(grammar.scopeName)' includes unknown external grammar '\(scope.rawValue)'.")
                    }
                    try validateReferences(externalGrammar.patterns, in: externalGrammar, visitedRules: &visitedRules)
                    try validateReferences(Array(externalGrammar.repository.values), in: externalGrammar, visitedRules: &visitedRules)
                }
            }

            try validateReferences(rule.patterns, in: grammar, visitedRules: &visitedRules)
        }
    }
}
