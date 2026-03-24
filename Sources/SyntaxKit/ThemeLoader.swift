import Foundation

public struct ThemeColor: RawRepresentable, Equatable, Sendable, Codable {
    public let rawValue: String
    public let red: Int?
    public let green: Int?
    public let blue: Int?
    public let alpha: Int?

    public init(rawValue: String) {
        self.rawValue = rawValue
        if let rgba = ThemeColor.parse(rawValue) {
            self.red = rgba.red
            self.green = rgba.green
            self.blue = rgba.blue
            self.alpha = rgba.alpha
        } else {
            self.red = nil
            self.green = nil
            self.blue = nil
            self.alpha = nil
        }
    }

    public init?(parsing rawValue: String) {
        guard let rgba = ThemeColor.parse(rawValue) else { return nil }
        self.rawValue = rawValue
        self.red = rgba.red
        self.green = rgba.green
        self.blue = rgba.blue
        self.alpha = rgba.alpha
    }

    public var rgba: (red: Int, green: Int, blue: Int, alpha: Int)? {
        guard let red, let green, let blue, let alpha else { return nil }
        return (red, green, blue, alpha)
    }

    static func parse(_ rawValue: String) -> (red: Int, green: Int, blue: Int, alpha: Int)? {
        let normalized = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty else { return nil }

        if normalized.hasPrefix("#") {
            let hex = String(normalized.dropFirst())
            switch hex.count {
            case 3:
                let chars = Array(hex)
                guard let red = expandedHex(chars[0]),
                      let green = expandedHex(chars[1]),
                      let blue = expandedHex(chars[2]) else {
                    return nil
                }
                return (red, green, blue, 255)
            case 4:
                let chars = Array(hex)
                guard let red = expandedHex(chars[0]),
                      let green = expandedHex(chars[1]),
                      let blue = expandedHex(chars[2]),
                      let alpha = expandedHex(chars[3]) else {
                    return nil
                }
                return (red, green, blue, alpha)
            case 6:
                guard let value = Int(hex, radix: 16) else { return nil }
                return ((value >> 16) & 0xFF, (value >> 8) & 0xFF, value & 0xFF, 255)
            case 8:
                guard let value = Int(hex, radix: 16) else { return nil }
                return ((value >> 24) & 0xFF, (value >> 16) & 0xFF, (value >> 8) & 0xFF, value & 0xFF)
            default:
                return nil
            }
        }

        return x11Colors[normalized.lowercased()]
    }

    private static func expandedHex(_ character: Character) -> Int? {
        let repeated = String([character, character])
        return Int(repeated, radix: 16)
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
            background: try color(settings["background"]),
            foreground: try color(settings["foreground"]),
            caret: try color(settings["caret"]),
            selection: try color(settings["selection"]),
            selectionForeground: try color(settings["selectionForeground"]),
            lineHighlight: try color(settings["lineHighlight"]),
            gutter: try color(gutterDictionary?["background"] ?? settings["gutter"]),
            gutterForeground: try color(gutterDictionary?["foreground"] ?? settings["gutterForeground"])
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
        let foreground = try color(settings["foreground"])
        let background = try color(settings["background"])
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

    private func color(_ value: Any?) throws -> ThemeColor? {
        guard let string = value as? String, !string.isEmpty else { return nil }
        guard let color = ThemeColor(parsing: string) else {
            throw SyntaxKitError.grammarValidation("Theme contains unsupported color '\(string)'.")
        }
        return color
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

private let x11Colors: [String: (red: Int, green: Int, blue: Int, alpha: Int)] = [
    "aqua": (0, 255, 255, 255),
    "black": (0, 0, 0, 255),
    "blue": (0, 0, 255, 255),
    "brown": (165, 42, 42, 255),
    "cyan": (0, 255, 255, 255),
    "fuchsia": (255, 0, 255, 255),
    "gray": (128, 128, 128, 255),
    "grey": (128, 128, 128, 255),
    "green": (0, 128, 0, 255),
    "lime": (0, 255, 0, 255),
    "magenta": (255, 0, 255, 255),
    "maroon": (128, 0, 0, 255),
    "navy": (0, 0, 128, 255),
    "olive": (128, 128, 0, 255),
    "orange": (255, 165, 0, 255),
    "purple": (128, 0, 128, 255),
    "red": (255, 0, 0, 255),
    "silver": (192, 192, 192, 255),
    "teal": (0, 128, 128, 255),
    "white": (255, 255, 255, 255),
    "yellow": (255, 255, 0, 255)
]
