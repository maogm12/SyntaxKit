import Foundation

public struct ThemeColor: RawRepresentable, Equatable, Sendable, Codable {
    public let rawValue: String

    public init(rawValue: String) {
        self.rawValue = rawValue
    }
}

public enum ThemeFontStyle: String, Equatable, Sendable, Codable, CaseIterable {
    case bold
    case italic
    case underline
}

public struct ThemeStyle: Equatable, Sendable, Codable {
    public let foreground: ThemeColor?
    public let background: ThemeColor?
    public let fontStyles: [ThemeFontStyle]

    public init(foreground: ThemeColor?, background: ThemeColor?, fontStyles: [ThemeFontStyle]) {
        self.foreground = foreground
        self.background = background
        self.fontStyles = fontStyles
    }
}

public struct ThemeGlobals: Equatable, Sendable, Codable {
    public let background: ThemeColor?
    public let foreground: ThemeColor?
    public let caret: ThemeColor?
    public let selection: ThemeColor?
    public let selectionForeground: ThemeColor?
    public let lineHighlight: ThemeColor?
    public let gutter: ThemeColor?
    public let gutterForeground: ThemeColor?

    public init(
        background: ThemeColor?,
        foreground: ThemeColor?,
        caret: ThemeColor?,
        selection: ThemeColor?,
        selectionForeground: ThemeColor?,
        lineHighlight: ThemeColor?,
        gutter: ThemeColor?,
        gutterForeground: ThemeColor?
    ) {
        self.background = background
        self.foreground = foreground
        self.caret = caret
        self.selection = selection
        self.selectionForeground = selectionForeground
        self.lineHighlight = lineHighlight
        self.gutter = gutter
        self.gutterForeground = gutterForeground
    }
}

public struct ThemeRule: Equatable, Sendable, Codable {
    public let name: String?
    public let scopes: [String]
    public let style: ThemeStyle

    public init(name: String?, scopes: [String], style: ThemeStyle) {
        self.name = name
        self.scopes = scopes
        self.style = style
    }
}

public struct Theme: Equatable, Sendable, Codable {
    public let name: String
    public let globals: ThemeGlobals
    public let rules: [ThemeRule]

    public init(name: String, globals: ThemeGlobals, rules: [ThemeRule]) {
        self.name = name
        self.globals = globals
        self.rules = rules
    }
}

public enum ThemeLoader {
    public static func load(from url: URL) throws -> Theme {
        let data = try Data(contentsOf: url)
        return try load(data: data)
    }

    public static func load(data: Data) throws -> Theme {
        let plist = try PropertyListSerialization.propertyList(from: data, options: [], format: nil)
        guard let dictionary = plist as? [String: Any] else {
            throw SyntaxKitError.grammarLoading("Top-level theme plist must be a dictionary.")
        }
        return try ThemeDecoder(dictionary: dictionary).decode()
    }
}

private struct ThemeDecoder {
    let dictionary: [String: Any]

    func decode() throws -> Theme {
        guard let name = dictionary["name"] as? String, !name.isEmpty else {
            throw SyntaxKitError.grammarValidation("Theme is missing required key 'name'.")
        }
        guard let settings = dictionary["settings"] as? [Any], !settings.isEmpty else {
            throw SyntaxKitError.grammarValidation("Theme is missing required non-empty key 'settings'.")
        }

        let globals = try decodeGlobals(settings[0], gutterSettings: dictionary["gutterSettings"])
        let rules = try settings.dropFirst().map(decodeRule)
        return Theme(name: name, globals: globals, rules: rules)
    }

    private func decodeGlobals(_ value: Any, gutterSettings: Any?) throws -> ThemeGlobals {
        guard let dictionary = value as? [String: Any] else {
            throw SyntaxKitError.grammarValidation("Theme global settings entry must be a dictionary.")
        }
        guard let settings = dictionary["settings"] as? [String: Any] else {
            throw SyntaxKitError.grammarValidation("Theme global settings entry must contain a 'settings' dictionary.")
        }

        let gutterDictionary = gutterSettings as? [String: Any]
        return ThemeGlobals(
            background: color(settings["background"]),
            foreground: color(settings["foreground"]),
            caret: color(settings["caret"]),
            selection: color(settings["selection"]),
            selectionForeground: color(settings["selectionForeground"]),
            lineHighlight: color(settings["lineHighlight"]),
            gutter: color(gutterDictionary?["background"] ?? settings["gutter"]),
            gutterForeground: color(gutterDictionary?["foreground"] ?? settings["gutterForeground"])
        )
    }

    private func decodeRule(_ value: Any) throws -> ThemeRule {
        guard let dictionary = value as? [String: Any] else {
            throw SyntaxKitError.grammarValidation("Theme scope style entry must be a dictionary.")
        }
        guard let settings = dictionary["settings"] as? [String: Any] else {
            throw SyntaxKitError.grammarValidation("Theme scope style entry must contain a 'settings' dictionary.")
        }

        let scopeString = dictionary["scope"] as? String ?? ""
        var scopes: [String] = []
        for fragment in scopeString.split(separator: ",") {
            let scope = fragment.trimmingCharacters(in: .whitespacesAndNewlines)
            if !scope.isEmpty {
                scopes.append(scope)
            }
        }

        let name = dictionary["name"] as? String
        let foreground = color(settings["foreground"])
        let background = color(settings["background"])
        let parsedFontStyles = fontStyles(settings["fontStyle"])

        return ThemeRule(
            name: name,
            scopes: scopes,
            style: ThemeStyle(
                foreground: foreground,
                background: background,
                fontStyles: parsedFontStyles
            )
        )
    }

    private func color(_ value: Any?) -> ThemeColor? {
        guard let string = value as? String, !string.isEmpty else { return nil }
        return ThemeColor(rawValue: string)
    }

    private func fontStyles(_ value: Any?) -> [ThemeFontStyle] {
        guard let string = value as? String, !string.isEmpty else { return [] }
        var styles: [ThemeFontStyle] = []
        for fragment in string.split(whereSeparator: \.isWhitespace) {
            if let style = ThemeFontStyle(rawValue: String(fragment)) {
                styles.append(style)
            }
        }
        return styles
    }
}
