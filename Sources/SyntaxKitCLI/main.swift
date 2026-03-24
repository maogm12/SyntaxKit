import Foundation
import SyntaxKit

enum CLI {
    static func run() throws {
        var arguments = Array(CommandLine.arguments.dropFirst())
        guard let command = arguments.first else {
            throw SyntaxKitError.cli(usage())
        }
        arguments.removeFirst()

        switch command {
        case "validate":
            try validate(arguments)
        case "parse":
            try parse(arguments)
        case "preview":
            try preview(arguments)
        default:
            throw SyntaxKitError.cli("Unknown command '\(command)'.\n\n\(usage())")
        }
    }

    private static func usage() -> String {
        """
        Usage:
          syntaxkit validate --grammar path [--grammar path ...]
          syntaxkit parse --grammar path [--grammar path ...] --scope scope.name --input file [--json]
          syntaxkit preview --grammar path [--grammar path ...] --scope scope.name --input file
        """
    }

    private static func validate(_ arguments: [String]) throws {
        let options = try parseOptions(arguments)
        let registry = try loadRegistry(grammarPaths: options.grammarPaths)
        let scopes = options.scopeNames.isEmpty ? registry.registeredScopeNames : options.scopeNames
        for scope in scopes {
            _ = try registry.resolve(scopeName: scope)
            FileHandle.standardOutput.write(Data("Validated \(scope)\n".utf8))
        }
    }

    private static func parse(_ arguments: [String]) throws {
        let options = try parseOptions(arguments)
        let registry = try loadRegistry(grammarPaths: options.grammarPaths)
        let scope = try requiredScope(from: options, registry: registry)
        let input = try readInput(from: options)
        let parser = SyntaxParser(registry: registry)
        let result = try parser.parse(input, using: scope)
        if options.jsonOutput {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(result)
            FileHandle.standardOutput.write(data)
            FileHandle.standardOutput.write(Data("\n".utf8))
        } else {
            for span in result.spans {
                let scopes = span.scopes.joined(separator: " ")
                let line = "\(span.startUTF16)-\(span.endUTF16) @\(span.line):\(span.column) \(scopes)\n"
                FileHandle.standardOutput.write(Data(line.utf8))
            }
        }
    }

    private static func preview(_ arguments: [String]) throws {
        let options = try parseOptions(arguments)
        let registry = try loadRegistry(grammarPaths: options.grammarPaths)
        let scope = try requiredScope(from: options, registry: registry)
        let input = try readInput(from: options)
        let parser = SyntaxParser(registry: registry)
        let spans = try parser.tokenize(input, using: scope)
        let rendered = ANSIHighlighter.render(text: input, spans: spans)
        FileHandle.standardOutput.write(Data(rendered.utf8))
    }

    private static func requiredScope(from options: CLIOptions, registry: GrammarRegistry) throws -> String {
        if let scope = options.scopeNames.first {
            return scope
        }
        if registry.registeredScopeNames.count == 1, let only = registry.registeredScopeNames.first {
            return only
        }
        throw SyntaxKitError.cli("A --scope value is required when multiple grammars are loaded.")
    }

    private static func readInput(from options: CLIOptions) throws -> String {
        guard let inputPath = options.inputPath else {
            throw SyntaxKitError.cli("Missing required --input path.")
        }
        return try String(contentsOfFile: inputPath, encoding: .utf8)
    }

    private static func loadRegistry(grammarPaths: [String]) throws -> GrammarRegistry {
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

    private static func parseOptions(_ arguments: [String]) throws -> CLIOptions {
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
            case "--json":
                options.jsonOutput = true
            default:
                throw SyntaxKitError.cli("Unknown option '\(argument)'.")
            }
            index += 1
        }
        return options
    }
}

private struct CLIOptions {
    var grammarPaths: [String] = []
    var scopeNames: [String] = []
    var inputPath: String?
    var jsonOutput = false
}

private enum ANSIHighlighter {
    private static let reset = "\u{001B}[0m"

    static func render(text: String, spans: [SyntaxSpan]) -> String {
        let utf16 = Array(text.utf16)
        var output = ""
        var cursor = 0

        for span in spans {
            if span.startUTF16 > cursor {
                output += string(from: utf16, start: cursor, end: span.startUTF16)
            }
            let fragment = string(from: utf16, start: span.startUTF16, end: span.endUTF16)
            output += color(for: span.scopes) + fragment + reset
            cursor = span.endUTF16
        }

        if cursor < utf16.count {
            output += string(from: utf16, start: cursor, end: utf16.count)
        }
        return output
    }

    private static func string(from utf16: [UInt16], start: Int, end: Int) -> String {
        String(decoding: utf16[start..<end], as: UTF16.self)
    }

    private static func color(for scopes: [String]) -> String {
        let joined = scopes.joined(separator: " ")
        if joined.contains("string") { return "\u{001B}[32m" }
        if joined.contains("numeric") || joined.contains("number") { return "\u{001B}[36m" }
        if joined.contains("constant.language") { return "\u{001B}[35m" }
        if joined.contains("comment") { return "\u{001B}[90m" }
        if joined.contains("invalid") { return "\u{001B}[31m" }
        if joined.contains("punctuation") { return "\u{001B}[33m" }
        return "\u{001B}[0m"
    }
}

do {
    try CLI.run()
} catch {
    let message: String
    if let syntaxKitError = error as? SyntaxKitError {
        message = syntaxKitError.description
    } else {
        message = String(describing: error)
    }
    FileHandle.standardError.write(Data((message + "\n").utf8))
    Foundation.exit(1)
}
