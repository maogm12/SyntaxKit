import Foundation

public final class DefaultRegexEngine: RegexEngine, @unchecked Sendable {
    public let name = "default"

    private let foundationCache = FoundationRegexCache()

    public init() {}

    public func compile(pattern: String) throws -> CompiledRegex {
        let regex = try foundationCache.regex(for: pattern, engineName: name)
        return CompiledRegex(pattern: pattern) { string, location in
            foundationFirstMatch(regex: regex, in: string, from: location)
        }
    }
}

final class FoundationRegexCache: @unchecked Sendable {
    private var storage: [String: NSRegularExpression] = [:]
    private let lock = NSLock()

    func regex(for pattern: String, engineName: String) throws -> NSRegularExpression {
        lock.lock()
        if let cached = storage[pattern] {
            lock.unlock()
            return cached
        }
        lock.unlock()

        do {
            let regex = try NSRegularExpression(pattern: pattern, options: [])
            lock.lock()
            storage[pattern] = regex
            lock.unlock()
            return regex
        } catch {
            throw SyntaxKitError.regexCompilation("Failed to compile regex '\(pattern)' with engine '\(engineName)': \(error)")
        }
    }
}

func foundationFirstMatch(regex: NSRegularExpression, in string: String, from location: Int) -> RegexMatch? {
    let nsString = string as NSString
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
