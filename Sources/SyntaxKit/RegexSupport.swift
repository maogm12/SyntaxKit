import Foundation

public final class DefaultRegexEngine: RegexEngine, @unchecked Sendable {
    public let name = "default"

    private let shim: TextMateRegexCompatibilityShim

    public init() {
        self.shim = TextMateRegexCompatibilityShim(backends: defaultRegexBackends(), engineName: name)
    }

    public func compile(pattern: String) throws -> CompiledRegex {
        try shim.compile(pattern: pattern)
    }
}

protocol BuiltinRegexBackend: Sendable {
    var name: String { get }
    func compile(pattern: String) throws -> CompiledRegex
}

struct TextMateRegexCompatibilityShim: Sendable {
    let backends: [any BuiltinRegexBackend]
    let engineName: String

    func compile(pattern: String) throws -> CompiledRegex {
        let normalizedPattern = try normalizedPattern(from: pattern)

        var failures: [String] = []
        for backend in backends {
            do {
                return try backend.compile(pattern: normalizedPattern)
            } catch let error as SyntaxKitError {
                failures.append("\(backend.name): \(error.description)")
            }
        }

        throw aggregatedBackendFailure(pattern: pattern, engineName: engineName, failures: failures)
    }

    private func normalizedPattern(from pattern: String) throws -> String {
        if pattern.contains(#"\g<"#) || pattern.contains(#"\g'"#) {
            throw SyntaxKitError.regexCompilation(
                "Regex '\(pattern)' uses Oniguruma subexpression calls unsupported by engine '\(engineName)'."
            )
        }

        if pattern.syntaxKitUsesOnigurumaRubyMultilineOption {
            throw SyntaxKitError.regexCompilation(
                "Regex '\(pattern)' uses Oniguruma Ruby-style '(?m)' semantics, which differ from engine '\(engineName)'. Rewrite the pattern or provide a custom RegexEngine."
            )
        }

        if pattern.syntaxKitUsesRelativeNamedBackreference {
            throw SyntaxKitError.regexCompilation(
                "Regex '\(pattern)' uses Oniguruma relative named backreferences unsupported by engine '\(engineName)'."
            )
        }

        return pattern
            .syntaxKitRewritingSingleQuotedNamedGroups()
            .syntaxKitRewritingSingleQuotedNamedBackreferences()
    }
}

func aggregatedBackendFailure(pattern: String, engineName: String, failures: [String]) -> SyntaxKitError {
    let details = failures.joined(separator: " | ")
    return SyntaxKitError.regexCompilation("Failed to compile regex '\(pattern)' with engine '\(engineName)'. \(details)")
}

struct FoundationRegexBackend: BuiltinRegexBackend {
    let name = "foundation"
    let cache = FoundationRegexCache()

    func compile(pattern: String) throws -> CompiledRegex {
        let regex = try cache.regex(for: pattern, engineName: name)
        return CompiledRegex(pattern: pattern) { string, location in
            foundationFirstMatch(regex: regex, in: string, from: location)
        }
    }
}

@available(macOS 13, iOS 16, tvOS 16, watchOS 9, *)
struct SwiftNativeRegexBackend: BuiltinRegexBackend {
    let name = "swift-native"

    func compile(pattern: String) throws -> CompiledRegex {
        do {
            // We use .unicodeScalarSemantics to match TextMate's behavior more closely for some patterns,
            // but we fall back to default if it fails.
            let regex = try Regex(pattern)
            let box = SwiftNativeRegexBox(regex: regex)
            return CompiledRegex(pattern: pattern) { string, location in
                swiftNativeFirstMatch(regex: box.regex, in: string, from: location)
            }
        } catch {
            throw SyntaxKitError.regexCompilation("Failed to compile regex '\(pattern)' with engine '\(name)': \(error)")
        }
    }
}

@available(macOS 13, iOS 16, tvOS 16, watchOS 9, *)
private final class SwiftNativeRegexBox: @unchecked Sendable {
    let regex: Regex<AnyRegexOutput>

    init(regex: Regex<AnyRegexOutput>) {
        self.regex = regex
    }
}

final class FoundationRegexCache: @unchecked Sendable {
    private var storage: [String: NSRegularExpression] = [:]
    private var order: [String] = []
    private let maximumSize: Int
    private let lock = NSLock()

    init(maximumSize: Int = 1000) {
        self.maximumSize = maximumSize
    }

    func regex(for pattern: String, engineName: String) throws -> NSRegularExpression {
        lock.lock()
        if let cached = storage[pattern] {
            if let index = order.firstIndex(of: pattern) {
                order.remove(at: index)
            }
            order.append(pattern)
            lock.unlock()
            return cached
        }
        lock.unlock()

        do {
            let regex = try NSRegularExpression(pattern: pattern, options: [])
            lock.lock()
            storage[pattern] = regex
            order.append(pattern)

            if storage.count > maximumSize {
                let oldest = order.removeFirst()
                storage.removeValue(forKey: oldest)
            }
            lock.unlock()
            return regex
        } catch {
            throw SyntaxKitError.regexCompilation("Failed to compile regex '\(pattern)' with engine '\(engineName)': \(error)")
        }
    }
}

func foundationFirstMatch(regex: NSRegularExpression, in string: String, from location: Int) -> RegexMatch? {
    let nsString = string as NSString
    guard location >= 0, location <= nsString.length else {
        return nil
    }
    let searchRange = NSRange(location: location, length: nsString.length - location)
    guard let match = regex.firstMatch(in: string, options: [], range: searchRange) else {
        return nil
    }

    var captures: [Int: NSRange] = [:]
    for index in 0..<match.numberOfRanges {
        captures[index] = match.range(at: index)
    }
    return RegexMatch(range: match.range, captures: captures)
}

@available(macOS 13, iOS 16, tvOS 16, watchOS 9, *)
private func swiftNativeFirstMatch(regex: Regex<AnyRegexOutput>, in string: String, from location: Int) -> RegexMatch? {
    guard let startIndex = stringIndex(in: string, utf16Offset: location) else {
        return nil
    }
    let substring = string[startIndex...]
    guard let match = try? regex.firstMatch(in: substring) else {
        return nil
    }

    let fullRange = NSRange(match.range, in: string)
    var captures: [Int: NSRange] = [0: fullRange]
    for index in match.output.indices where index != 0 {
        captures[index] = match.output[index].range.map { NSRange($0, in: string) } ?? NSRange(location: NSNotFound, length: 0)
    }
    return RegexMatch(range: fullRange, captures: captures)
}

private func stringIndex(in string: String, utf16Offset: Int) -> String.Index? {
    guard utf16Offset >= 0 else { return nil }
    let utf16 = string.utf16
    guard let utf16Index = utf16.index(utf16.startIndex, offsetBy: utf16Offset, limitedBy: utf16.endIndex),
          let index = String.Index(utf16Index, within: string) else {
        return nil
    }
    return index
}

func defaultSubstituteBackreferences(pattern: String, using beginMatch: RegexMatch, in line: String) -> String {
    let nsString = line as NSString
    let backreferenceRegex = try! NSRegularExpression(pattern: #"\\([0-9]+)"#, options: [])
    let fullRange = NSRange(location: 0, length: (pattern as NSString).length)
    let mutable = NSMutableString(string: pattern)
    let matches = backreferenceRegex.matches(in: pattern, options: [], range: fullRange).reversed()
    for match in matches {
        let numberRange = match.range(at: 1)
        let numberString = (pattern as NSString).substring(with: numberRange)
        guard let captureIndex = Int(numberString),
              let captureRange = beginMatch.captures[captureIndex],
              captureRange.location != NSNotFound else {
            continue
        }
        let replacement = NSRegularExpression.escapedPattern(for: nsString.substring(with: captureRange))
        mutable.replaceCharacters(in: match.range, with: replacement)
    }
    return mutable as String
}

private func defaultRegexBackends() -> [any BuiltinRegexBackend] {
    var backends: [any BuiltinRegexBackend] = []
    if #available(macOS 13, iOS 16, tvOS 16, watchOS 9, *) {
        backends.append(SwiftNativeRegexBackend())
    }
    backends.append(FoundationRegexBackend())
    return backends
}

private struct TextMateRegexHelpers {
    static let singleQuotedNamedGroupRegex = try! NSRegularExpression(pattern: #"\(\?'([[:word:]]+)'"#, options: [])
    static let singleQuotedNamedBackreferenceRegex = try! NSRegularExpression(pattern: #"\\k'([[:word:]]+)'"#, options: [])
    static let relativeNamedBackreferenceRegex = try! NSRegularExpression(pattern: #"\\k(?:<[^>]*[+-][0-9]+>|'[^']*[+-][0-9]+')"#, options: [])
    static let onigurumaRubyMultilineOptionRegex = try! NSRegularExpression(pattern: #"\(\?[[:alpha:]-]*m[[:alpha:]-]*:?"#, options: [])
}

extension String {
    func syntaxKitRewritingSingleQuotedNamedGroups() -> String {
        let regex = TextMateRegexHelpers.singleQuotedNamedGroupRegex
        let range = NSRange(location: 0, length: (self as NSString).length)
        return regex.stringByReplacingMatches(
            in: self,
            options: [],
            range: range,
            withTemplate: "(?<$1>"
        )
    }

    func syntaxKitRewritingSingleQuotedNamedBackreferences() -> String {
        let regex = TextMateRegexHelpers.singleQuotedNamedBackreferenceRegex
        let range = NSRange(location: 0, length: (self as NSString).length)
        return regex.stringByReplacingMatches(
            in: self,
            options: [],
            range: range,
            withTemplate: #"\\k<$1>"#
        )
    }

    var syntaxKitUsesRelativeNamedBackreference: Bool {
        let regex = TextMateRegexHelpers.relativeNamedBackreferenceRegex
        let range = NSRange(location: 0, length: (self as NSString).length)
        return regex.firstMatch(in: self, options: [], range: range) != nil
    }

    var syntaxKitUsesOnigurumaRubyMultilineOption: Bool {
        let regex = TextMateRegexHelpers.onigurumaRubyMultilineOptionRegex
        let range = NSRange(location: 0, length: (self as NSString).length)
        return regex.firstMatch(in: self, options: [], range: range) != nil
    }
}
