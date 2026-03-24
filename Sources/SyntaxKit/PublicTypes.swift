import Foundation

public struct ScopeName: RawRepresentable, Hashable, Codable, Sendable, CustomStringConvertible {
    public let rawValue: String

    public init(rawValue: String) {
        self.rawValue = rawValue
    }

    public var description: String { rawValue }
}

public struct Capture: Equatable, Sendable {
    public let index: Int
    public let name: String

    public init(index: Int, name: String) {
        self.index = index
        self.name = name
    }
}

public struct Rule: Equatable, Sendable {
    public let id: Int
    public let name: String?
    public let contentName: String?
    public let match: String?
    public let begin: String?
    public let end: String?
    public let captures: [Capture]
    public let beginCaptures: [Capture]
    public let endCaptures: [Capture]
    public let include: String?
    public let patterns: [Rule]

    public init(
        id: Int,
        name: String?,
        contentName: String?,
        match: String?,
        begin: String?,
        end: String?,
        captures: [Capture],
        beginCaptures: [Capture],
        endCaptures: [Capture],
        include: String?,
        patterns: [Rule]
    ) {
        self.id = id
        self.name = name
        self.contentName = contentName
        self.match = match
        self.begin = begin
        self.end = end
        self.captures = captures.sorted(using: KeyPathComparator(\.index))
        self.beginCaptures = beginCaptures.sorted(using: KeyPathComparator(\.index))
        self.endCaptures = endCaptures.sorted(using: KeyPathComparator(\.index))
        self.include = include
        self.patterns = patterns
    }

    var effectiveBeginCaptures: [Capture] {
        beginCaptures.isEmpty ? captures : beginCaptures
    }

    var effectiveEndCaptures: [Capture] {
        endCaptures.isEmpty ? captures : endCaptures
    }
}

public struct Grammar: Equatable, Sendable {
    public let name: String?
    public let scopeName: ScopeName
    public let fileTypes: [String]
    public let firstLineMatch: String?
    public let foldingStartMarker: String?
    public let foldingStopMarker: String?
    public let patterns: [Rule]
    public let repository: [String: Rule]

    public init(
        name: String?,
        scopeName: ScopeName,
        fileTypes: [String],
        firstLineMatch: String?,
        foldingStartMarker: String?,
        foldingStopMarker: String?,
        patterns: [Rule],
        repository: [String: Rule]
    ) {
        self.name = name
        self.scopeName = scopeName
        self.fileTypes = fileTypes
        self.firstLineMatch = firstLineMatch
        self.foldingStartMarker = foldingStartMarker
        self.foldingStopMarker = foldingStopMarker
        self.patterns = patterns
        self.repository = repository
    }
}

public struct ResolvedGrammar: Sendable {
    public let scopeName: ScopeName
    public let grammar: Grammar

    public init(scopeName: ScopeName, grammar: Grammar) {
        self.scopeName = scopeName
        self.grammar = grammar
    }
}

public enum DiagnosticSeverity: String, Codable, Sendable {
    case warning
    case error
}

public struct Diagnostic: Codable, Equatable, Sendable {
    public let severity: DiagnosticSeverity
    public let message: String
    public let line: Int?
    public let column: Int?

    public init(severity: DiagnosticSeverity, message: String, line: Int? = nil, column: Int? = nil) {
        self.severity = severity
        self.message = message
        self.line = line
        self.column = column
    }
}

public struct SyntaxSpan: Codable, Equatable, Sendable {
    public let startUTF16: Int
    public let endUTF16: Int
    public let line: Int
    public let column: Int
    public let scopes: [String]

    public init(startUTF16: Int, endUTF16: Int, line: Int, column: Int, scopes: [String]) {
        self.startUTF16 = startUTF16
        self.endUTF16 = endUTF16
        self.line = line
        self.column = column
        self.scopes = scopes
    }
}

public struct ParseResult: Codable, Equatable, Sendable {
    public let scopeName: ScopeName
    public let spans: [SyntaxSpan]
    public let diagnostics: [Diagnostic]

    public init(scopeName: ScopeName, spans: [SyntaxSpan], diagnostics: [Diagnostic]) {
        self.scopeName = scopeName
        self.spans = spans
        self.diagnostics = diagnostics
    }
}

public enum IncludeReference: Equatable, Sendable {
    case repository(String)
    case `self`
    case external(ScopeName)

    init(rawValue: String) {
        if rawValue == "$self" {
            self = .self
        } else if let name = rawValue.first, name == "#" {
            self = .repository(String(rawValue.dropFirst()))
        } else {
            self = .external(ScopeName(rawValue: rawValue))
        }
    }
}

public enum SyntaxKitError: Error, CustomStringConvertible {
    case grammarLoading(String)
    case grammarValidation(String)
    case resolution(String)
    case regexCompilation(String)
    case parsing(String)
    case cli(String)

    public var description: String {
        switch self {
        case .grammarLoading(let message),
             .grammarValidation(let message),
             .resolution(let message),
             .regexCompilation(let message),
             .parsing(let message),
             .cli(let message):
            return message
        }
    }
}

extension String {
    var syntaxKitScopeComponents: [String] {
        split(whereSeparator: \.isWhitespace).map(String.init)
    }

    var syntaxKitContainsBackreference: Bool {
        range(of: #"\\[0-9]+"#, options: .regularExpression) != nil
    }

    var syntaxKitScopeLabelCount: Int {
        split(separator: ".").count
    }
}
