import Foundation

public struct StyledTextRun: Equatable, Sendable {
    public let text: String
    public let startUTF16: Int
    public let endUTF16: Int
    public let scopes: [String]
    public let style: ThemeStyle?

    public init(text: String, startUTF16: Int, endUTF16: Int, scopes: [String], style: ThemeStyle?) {
        self.text = text
        self.startUTF16 = startUTF16
        self.endUTF16 = endUTF16
        self.scopes = scopes
        self.style = style
    }
}

public enum StyledTextAdapter {
    public static func runs(text: String, themedSpans: [ThemedSpan]) -> [StyledTextRun] {
        let utf16 = Array(text.utf16)
        var results: [StyledTextRun] = []
        var cursor = 0

        for span in themedSpans {
            if span.startUTF16 > cursor {
                results.append(
                    StyledTextRun(
                        text: string(from: utf16, start: cursor, end: span.startUTF16),
                        startUTF16: cursor,
                        endUTF16: span.startUTF16,
                        scopes: [],
                        style: nil
                    )
                )
            }

            results.append(
                StyledTextRun(
                    text: string(from: utf16, start: span.startUTF16, end: span.endUTF16),
                    startUTF16: span.startUTF16,
                    endUTF16: span.endUTF16,
                    scopes: span.scopes,
                    style: span.style
                )
            )
            cursor = span.endUTF16
        }

        if cursor < utf16.count {
            results.append(
                StyledTextRun(
                    text: string(from: utf16, start: cursor, end: utf16.count),
                    startUTF16: cursor,
                    endUTF16: utf16.count,
                    scopes: [],
                    style: nil
                )
            )
        }

        return results
    }

    @available(macOS 12, iOS 15, tvOS 15, watchOS 8, *)
    public static func attributedString(text: String, themedSpans: [ThemedSpan]) -> AttributedString {
        var output = AttributedString()
        for run in runs(text: text, themedSpans: themedSpans) {
            var fragment = AttributedString(run.text)
            applyAttributes(to: &fragment, run: run)
            output += fragment
        }
        return output
    }

    public static func nsAttributedString(text: String, themedSpans: [ThemedSpan]) -> NSAttributedString {
        let output = NSMutableAttributedString()
        for run in runs(text: text, themedSpans: themedSpans) {
            output.append(NSAttributedString(string: run.text, attributes: nsAttributes(for: run)))
        }
        return output.copy() as! NSAttributedString
    }

    static let scopesAttributeName = "SyntaxKitScopes"
    static let foregroundAttributeName = "SyntaxKitForeground"
    static let backgroundAttributeName = "SyntaxKitBackground"
    static let fontStylesAttributeName = "SyntaxKitFontStyles"

    private static func string(from utf16: [UInt16], start: Int, end: Int) -> String {
        String(decoding: utf16[start..<end], as: UTF16.self)
    }

    @available(macOS 12, iOS 15, tvOS 15, watchOS 8, *)
    private static func applyAttributes(to fragment: inout AttributedString, run: StyledTextRun) {
        guard run.style != nil || !run.scopes.isEmpty else { return }
        var container = AttributeContainer()
        if !run.scopes.isEmpty {
            container[SyntaxKitScopesAttribute.self] = run.scopes
        }
        if let style = run.style {
            if let foreground = style.foreground?.rawValue {
                container[SyntaxKitForegroundAttribute.self] = foreground
            }
            if let background = style.background?.rawValue {
                container[SyntaxKitBackgroundAttribute.self] = background
            }
            if !style.fontStyles.isEmpty {
                container[SyntaxKitFontStylesAttribute.self] = style.fontStyles.map(\.rawValue)
            }
        }
        fragment.mergeAttributes(container)
    }

    private static func nsAttributes(for run: StyledTextRun) -> [NSAttributedString.Key: Any] {
        var attributes: [NSAttributedString.Key: Any] = [:]
        if !run.scopes.isEmpty {
            attributes[NSAttributedString.Key(scopesAttributeName)] = run.scopes
        }
        if let style = run.style {
            if let foreground = style.foreground?.rawValue {
                attributes[NSAttributedString.Key(foregroundAttributeName)] = foreground
            }
            if let background = style.background?.rawValue {
                attributes[NSAttributedString.Key(backgroundAttributeName)] = background
            }
            if !style.fontStyles.isEmpty {
                attributes[NSAttributedString.Key(fontStylesAttributeName)] = style.fontStyles.map(\.rawValue)
            }
        }
        return attributes
    }
}

@available(macOS 12, iOS 15, tvOS 15, watchOS 8, *)
public enum SyntaxKitScopesAttribute: CodableAttributedStringKey {
    public typealias Value = [String]
    public static let name = StyledTextAdapter.scopesAttributeName
}

@available(macOS 12, iOS 15, tvOS 15, watchOS 8, *)
public enum SyntaxKitForegroundAttribute: CodableAttributedStringKey {
    public typealias Value = String
    public static let name = StyledTextAdapter.foregroundAttributeName
}

@available(macOS 12, iOS 15, tvOS 15, watchOS 8, *)
public enum SyntaxKitBackgroundAttribute: CodableAttributedStringKey {
    public typealias Value = String
    public static let name = StyledTextAdapter.backgroundAttributeName
}

@available(macOS 12, iOS 15, tvOS 15, watchOS 8, *)
public enum SyntaxKitFontStylesAttribute: CodableAttributedStringKey {
    public typealias Value = [String]
    public static let name = StyledTextAdapter.fontStylesAttributeName
}
