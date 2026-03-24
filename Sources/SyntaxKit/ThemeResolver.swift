import Foundation

public struct ThemedSpan: Equatable, Sendable, Codable {
    public let startUTF16: Int
    public let endUTF16: Int
    public let line: Int
    public let column: Int
    public let scopes: [String]
    public let style: ThemeStyle

    public init(
        startUTF16: Int,
        endUTF16: Int,
        line: Int,
        column: Int,
        scopes: [String],
        style: ThemeStyle
    ) {
        self.startUTF16 = startUTF16
        self.endUTF16 = endUTF16
        self.line = line
        self.column = column
        self.scopes = scopes
        self.style = style
    }
}

public enum ThemeResolver {
    public static func resolve(spans: [SyntaxSpan], using theme: Theme) -> [ThemedSpan] {
        spans.map { resolve(span: $0, using: theme) }
    }

    public static func resolve(result: ParseResult, using theme: Theme) -> [ThemedSpan] {
        resolve(spans: result.spans, using: theme)
    }

    public static func resolve(span: SyntaxSpan, using theme: Theme) -> ThemedSpan {
        let resolvedStyle = resolvedStyle(for: span.scopes, using: theme)
        return ThemedSpan(
            startUTF16: span.startUTF16,
            endUTF16: span.endUTF16,
            line: span.line,
            column: span.column,
            scopes: span.scopes,
            style: resolvedStyle
        )
    }

    static func resolvedStyle(for scopes: [String], using theme: Theme) -> ThemeStyle {
        var candidates: [(specificity: Int, index: Int, style: ThemeStyle)] = []

        for (index, rule) in theme.rules.enumerated() {
            if let specificity = ruleSpecificity(rule, matching: scopes) {
                candidates.append((specificity: specificity, index: index, style: rule.style))
            }
        }

        candidates.sort {
            if $0.specificity == $1.specificity {
                return $0.index < $1.index
            }
            return $0.specificity < $1.specificity
        }

        var foreground = theme.globals.foreground
        var background = theme.globals.background
        var fontStyles: [ThemeFontStyle] = []

        for candidate in candidates {
            if let value = candidate.style.foreground {
                foreground = value
            }
            if let value = candidate.style.background {
                background = value
            }
            if !candidate.style.fontStyles.isEmpty {
                fontStyles = candidate.style.fontStyles
            }
        }

        return ThemeStyle(foreground: foreground, background: background, fontStyles: fontStyles)
    }

    static func ruleSpecificity(_ rule: ThemeRule, matching scopes: [String]) -> Int? {
        var best: Int?
        for ruleScope in rule.scopes {
            for candidate in scopes {
                if let specificity = scopeMatchSpecificity(ruleScope: ruleScope, candidateScope: candidate) {
                    if let current = best {
                        best = max(current, specificity)
                    } else {
                        best = specificity
                    }
                }
            }
        }
        return best
    }

    static func scopeMatchSpecificity(ruleScope: String, candidateScope: String) -> Int? {
        if ruleScope.isEmpty {
            return nil
        }
        let normalizedRule = ruleScope.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedRule.isEmpty else { return nil }
        if candidateScope == normalizedRule {
            return normalizedRule.syntaxKitScopeLabelCount
        }
        let prefix = normalizedRule + "."
        if candidateScope.hasPrefix(prefix) {
            return normalizedRule.syntaxKitScopeLabelCount
        }
        return nil
    }
}
