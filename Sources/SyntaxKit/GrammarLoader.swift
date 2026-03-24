import Foundation

public enum GrammarLoader {
    public static func load(from url: URL) throws -> Grammar {
        let data = try Data(contentsOf: url)
        return try load(data: data)
    }

    public static func load(data: Data) throws -> Grammar {
        let plist = try PropertyListSerialization.propertyList(from: data, options: [], format: nil)
        guard let dictionary = plist as? [String: Any] else {
            throw SyntaxKitError.grammarLoading("Top-level grammar plist must be a dictionary.")
        }
        var decoder = GrammarDecoder(dictionary: dictionary)
        return try decoder.decode()
    }
}

private struct GrammarDecoder {
    let dictionary: [String: Any]
    var nextRuleID: Int = 0

    mutating func decode() throws -> Grammar {
        guard let scopeName = dictionary["scopeName"] as? String, !scopeName.isEmpty else {
            throw SyntaxKitError.grammarValidation("Grammar is missing required key 'scopeName'.")
        }

        let repository = try decodeRepository(dictionary["repository"])
        let patterns = try decodeRules(dictionary["patterns"])

        return Grammar(
            name: dictionary["name"] as? String,
            scopeName: ScopeName(rawValue: scopeName),
            fileTypes: (dictionary["fileTypes"] as? [String]) ?? [],
            firstLineMatch: dictionary["firstLineMatch"] as? String,
            foldingStartMarker: dictionary["foldingStartMarker"] as? String,
            foldingStopMarker: dictionary["foldingStopMarker"] as? String,
            patterns: patterns,
            repository: repository
        )
    }

    private mutating func decodeRepository(_ value: Any?) throws -> [String: Rule] {
        guard let dictionary = value as? [String: Any] else { return [:] }
        var result: [String: Rule] = [:]
        for key in dictionary.keys.sorted() {
            guard let ruleDictionary = dictionary[key] as? [String: Any] else {
                throw SyntaxKitError.grammarValidation("Repository entry '\(key)' must be a dictionary.")
            }
            result[key] = try decodeRule(ruleDictionary)
        }
        return result
    }

    private mutating func decodeRules(_ value: Any?) throws -> [Rule] {
        guard let array = value as? [Any] else { return [] }
        return try array.map { item in
            guard let ruleDictionary = item as? [String: Any] else {
                throw SyntaxKitError.grammarValidation("Pattern entries must be dictionaries.")
            }
            return try decodeRule(ruleDictionary)
        }
    }

    private mutating func decodeRule(_ dictionary: [String: Any]) throws -> Rule {
        let id = nextRuleID
        nextRuleID += 1

        let name = dictionary["name"] as? String
        let contentName = dictionary["contentName"] as? String
        let match = dictionary["match"] as? String
        let begin = dictionary["begin"] as? String
        let end = dictionary["end"] as? String
        let include = dictionary["include"] as? String
        let captures = try decodeCaptures(dictionary["captures"])
        let beginCaptures = try decodeCaptures(dictionary["beginCaptures"])
        let endCaptures = try decodeCaptures(dictionary["endCaptures"])
        let patterns = try decodeRules(dictionary["patterns"])

        if match != nil && (begin != nil || end != nil) {
            throw SyntaxKitError.grammarValidation("Rule \(id) mixes 'match' with 'begin'/'end', which is unsupported.")
        }
        if begin != nil && end == nil {
            throw SyntaxKitError.grammarValidation("Rule \(id) declares 'begin' without matching 'end'.")
        }
        if begin == nil && end != nil {
            throw SyntaxKitError.grammarValidation("Rule \(id) declares 'end' without matching 'begin'.")
        }
        if match == nil && begin == nil && include == nil && patterns.isEmpty {
            throw SyntaxKitError.grammarValidation("Rule \(id) must define 'match', 'begin'/'end', 'include', or nested 'patterns'.")
        }

        return Rule(
            id: id,
            name: name,
            contentName: contentName,
            match: match,
            begin: begin,
            end: end,
            captures: captures,
            beginCaptures: beginCaptures,
            endCaptures: endCaptures,
            include: include,
            patterns: patterns
        )
    }

    private func decodeCaptures(_ value: Any?) throws -> [Capture] {
        guard let dictionary = value as? [String: Any] else { return [] }
        var captures: [Capture] = []
        for (indexString, nestedValue) in dictionary {
            guard let index = Int(indexString), index >= 0 else {
                throw SyntaxKitError.grammarValidation("Capture key '\(indexString)' must be a non-negative integer.")
            }
            guard let nestedDictionary = nestedValue as? [String: Any] else {
                throw SyntaxKitError.grammarValidation("Capture '\(indexString)' must be a dictionary.")
            }
            guard let name = nestedDictionary["name"] as? String, !name.isEmpty else {
                throw SyntaxKitError.grammarValidation("Capture '\(indexString)' is missing required key 'name'.")
            }
            captures.append(Capture(index: index, name: name))
        }
        return captures.sorted { $0.index < $1.index }
    }
}
