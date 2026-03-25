import Foundation
import SyntaxKit

struct CLI {
    static func run(arguments: [String], stdout: @escaping (String) -> Void, stderr: @escaping (String) -> Void) -> Int32 {
        do {
            try runThrowing(arguments: arguments, stdout: stdout, stderr: stderr)
            return 0
        } catch {
            let message: String
            if let syntaxKitError = error as? SyntaxKitError {
                message = syntaxKitError.description
            } else {
                message = String(describing: error)
            }
            stderr(message + "\n")
            return 1
        }
    }

    static func runThrowing(arguments: [String], stdout: @escaping (String) -> Void, stderr: @escaping (String) -> Void) throws {
        var arguments = arguments
        guard let command = arguments.first else {
            throw SyntaxKitError.cli(usage())
        }
        arguments.removeFirst()

        switch command {
        case "validate":
            try validate(arguments, stdout: stdout)
        case "parse":
            try parse(arguments, stdout: stdout)
        case "preview":
            try preview(arguments, stdout: stdout)
        default:
            throw SyntaxKitError.cli("Unknown command '\(command)'.\n\n\(usage())")
        }
    }

    static func usage() -> String {
        """
        Usage:
          syntaxkit validate --grammar path [--grammar path ...]
          syntaxkit parse --grammar path [--grammar path ...] --scope scope.name --input file [--json] [--theme path]
          syntaxkit preview --grammar path [--grammar path ...] --scope scope.name --input file [--theme path]
        """
    }

    static func validate(_ arguments: [String], stdout: @escaping (String) -> Void) throws {
        let options = try parseOptions(arguments)
        let registry = try loadRegistry(grammarPaths: options.grammarPaths)
        let parser = SyntaxParser(registry: registry)
        let scopes = options.scopeNames.isEmpty ? registry.registeredScopeNames : options.scopeNames
        for scope in scopes {
            _ = try registry.resolve(scopeName: scope)
            _ = try parser.parse("", using: scope)
            stdout("Validated \(scope)\n")
        }
    }

    static func parse(_ arguments: [String], stdout: @escaping (String) -> Void) throws {
        let options = try parseOptions(arguments)
        let registry = try loadRegistry(grammarPaths: options.grammarPaths)
        let scope = try requiredScope(from: options, registry: registry)
        let input = try readInput(from: options)
        let parser = SyntaxParser(registry: registry)
        let result = try parser.parse(input, using: scope)
        if options.jsonOutput {
            if let themePath = options.themePath {
                let theme = try ThemeLoader.load(from: URL(fileURLWithPath: themePath))
                let themed = ThemeResolver.resolve(result: result, using: theme)
                stdout(try prettyJSONString(from: themed))
            } else {
                stdout(try prettyJSONString(from: result))
            }
        } else {
            for span in result.spans {
                let scopes = span.scopes.joined(separator: " ")
                stdout("\(span.startUTF16)-\(span.endUTF16) @\(span.line):\(span.column) \(scopes)\n")
            }
        }
    }

    static func preview(_ arguments: [String], stdout: @escaping (String) -> Void) throws {
        let options = try parseOptions(arguments)
        let registry = try loadRegistry(grammarPaths: options.grammarPaths)
        let scope = try requiredScope(from: options, registry: registry)
        let input = try readInput(from: options)
        let parser = SyntaxParser(registry: registry)
        let spans = try parser.tokenize(input, using: scope)

        if let themePath = options.themePath {
            let theme = try ThemeLoader.load(from: URL(fileURLWithPath: themePath))
            let themed = ThemeResolver.resolve(spans: spans, using: theme)
            stdout(ANSIHighlighter.render(text: input, themedSpans: themed))
        } else {
            stdout(ANSIHighlighter.render(text: input, spans: spans))
        }
    }

    static func requiredScope(from options: CLIOptions, registry: GrammarRegistry) throws -> String {
        if let scope = options.scopeNames.first {
            return scope
        }
        if registry.registeredScopeNames.count == 1, let only = registry.registeredScopeNames.first {
            return only
        }
        throw SyntaxKitError.cli("A --scope value is required when multiple grammars are loaded.")
    }

    static func readInput(from options: CLIOptions) throws -> String {
        guard let inputPath = options.inputPath else {
            throw SyntaxKitError.cli("Missing required --input path.")
        }
        return try String(contentsOfFile: inputPath, encoding: .utf8)
    }

    static func loadRegistry(grammarPaths: [String]) throws -> GrammarRegistry {
        guard !grammarPaths.isEmpty else {
            throw SyntaxKitError.cli("At least one --grammar path is required.")
        }
        let registry = GrammarRegistry()
        for path in grammarPaths {
            let grammar = try GrammarLoader.load(from: URL(fileURLWithPath: path))
            registry.register(grammar)
        }
        return registry
    }

    static func parseOptions(_ arguments: [String]) throws -> CLIOptions {
        var options = CLIOptions()
        var index = 0
        while index < arguments.count {
            let argument = arguments[index]
            switch argument {
            case "--grammar":
                index += 1
                guard index < arguments.count else { throw SyntaxKitError.cli("Missing value for --grammar.") }
                options.grammarPaths.append(arguments[index])
            case "--scope":
                index += 1
                guard index < arguments.count else { throw SyntaxKitError.cli("Missing value for --scope.") }
                options.scopeNames.append(arguments[index])
            case "--input":
                index += 1
                guard index < arguments.count else { throw SyntaxKitError.cli("Missing value for --input.") }
                options.inputPath = arguments[index]
            case "--theme":
                index += 1
                guard index < arguments.count else { throw SyntaxKitError.cli("Missing value for --theme.") }
                options.themePath = arguments[index]
            case "--json":
                options.jsonOutput = true
            default:
                throw SyntaxKitError.cli("Unknown option '\(argument)'.")
            }
            index += 1
        }
        return options
    }

    static func prettyJSONString<T: Encodable>(from value: T) throws -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(value)
        return String(decoding: data, as: UTF8.self) + "\n"
    }
}

struct CLIOptions {
    var grammarPaths: [String] = []
    var scopeNames: [String] = []
    var inputPath: String?
    var themePath: String?
    var jsonOutput = false
}

enum ANSIHighlighter {
    static let reset = "\u{001B}[0m"

    static func render(text: String, spans: [SyntaxSpan]) -> String {
        let utf16 = Array(text.utf16)
        var output = ""
        var cursor = 0

        for span in spans {
            if span.startUTF16 > cursor {
                output += string(from: utf16, start: cursor, end: span.startUTF16)
            }
            let fragment = string(from: utf16, start: span.startUTF16, end: span.endUTF16)
            output += debugColor(for: span.scopes) + fragment + reset
            cursor = span.endUTF16
        }

        if cursor < utf16.count {
            output += string(from: utf16, start: cursor, end: utf16.count)
        }
        return output
    }

    static func render(text: String, themedSpans: [ThemedSpan]) -> String {
        let utf16 = Array(text.utf16)
        var output = ""
        var cursor = 0

        for span in themedSpans {
            if span.startUTF16 > cursor {
                output += string(from: utf16, start: cursor, end: span.startUTF16)
            }
            let fragment = string(from: utf16, start: span.startUTF16, end: span.endUTF16)
            output += ansiStyle(for: span.style) + fragment + reset
            cursor = span.endUTF16
        }

        if cursor < utf16.count {
            output += string(from: utf16, start: cursor, end: utf16.count)
        }
        return output
    }

    static func string(from utf16: [UInt16], start: Int, end: Int) -> String {
        String(decoding: utf16[start..<end], as: UTF16.self)
    }

    static func debugColor(for scopes: [String]) -> String {
        let joined = scopes.joined(separator: " ")
        if joined.contains("string") { return "\u{001B}[32m" }
        if joined.contains("numeric") || joined.contains("number") { return "\u{001B}[36m" }
        if joined.contains("constant.language") { return "\u{001B}[35m" }
        if joined.contains("comment") { return "\u{001B}[90m" }
        if joined.contains("invalid") { return "\u{001B}[31m" }
        if joined.contains("punctuation") { return "\u{001B}[33m" }
        return "\u{001B}[0m"
    }

    static func ansiStyle(for style: ThemeStyle) -> String {
        var codes: [String] = []
        if style.fontStyles.contains(.bold) {
            codes.append("1")
        }
        if style.fontStyles.contains(.italic) {
            codes.append("3")
        }
        if style.fontStyles.contains(.underline) {
            codes.append("4")
        }
        if let rgb = style.foreground?.rgba {
            codes.append("38;2;\(rgb.red);\(rgb.green);\(rgb.blue)")
        }
        if let rgb = style.background?.rgba {
            codes.append("48;2;\(rgb.red);\(rgb.green);\(rgb.blue)")
        }
        if codes.isEmpty {
            return reset
        }
        return "\u{001B}[\(codes.joined(separator: ";"))m"
    }

    static func rgb(from rawColor: String) -> (red: Int, green: Int, blue: Int)? {
        guard let rgba = ThemeColor(parsing: rawColor)?.rgba else { return nil }
        return (rgba.red, rgba.green, rgba.blue)
    }
}
