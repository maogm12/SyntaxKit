import Foundation

public enum SyntaxHighlighter {
    public static func highlight(
        _ text: String,
        using scopeName: String,
        registry: GrammarRegistry,
        theme: Theme
    ) throws -> [ThemedSpan] {
        let parser = SyntaxParser(registry: registry)
        let result = try parser.parse(text, using: scopeName)
        return ThemeResolver.resolve(result: result, using: theme)
    }

    public static func highlight(
        _ text: String,
        grammar: Grammar,
        theme: Theme
    ) throws -> [ThemedSpan] {
        let registry = GrammarRegistry(grammars: [grammar])
        return try highlight(text, using: grammar.scopeName.rawValue, registry: registry, theme: theme)
    }

    public static func highlight(
        _ text: String,
        resolvedGrammar: ResolvedGrammar,
        registry: GrammarRegistry,
        theme: Theme
    ) throws -> [ThemedSpan] {
        let parser = SyntaxParser(resolvedGrammar: resolvedGrammar, registry: registry)
        let result = try parser.parse(text)
        return ThemeResolver.resolve(result: result, using: theme)
    }
}
