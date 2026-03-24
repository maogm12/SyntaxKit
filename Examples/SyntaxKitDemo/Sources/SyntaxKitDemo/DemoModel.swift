import AppKit
import Combine
import Foundation
import SyntaxKit
import UniformTypeIdentifiers

@MainActor
final class DemoModel: ObservableObject {
    @Published var sourceText = DemoAsset.jsonSample
    @Published private(set) var preview = NSAttributedString(string: "")
    @Published private(set) var themedSpans: [ThemedSpan] = []
    @Published private(set) var lineStates: [SyntaxLineState] = []
    @Published private(set) var parseDurationMilliseconds: Double = 0
    @Published private(set) var renderDurationMilliseconds: Double = 0
    @Published private(set) var errorMessage: String?
    @Published private(set) var grammarName = "JSON"
    @Published private(set) var grammarScopeName = "source.json"
    @Published private(set) var themeName = "Sample Dark"

    private var parser: SyntaxParser?
    private var theme: Theme?

    var statusText: String {
        errorMessage == nil ? "Ready" : "Rendering issue"
    }

    func load() async {
        do {
            try loadBundledGrammar(.json, replaceSource: false)
            try loadBundledTheme(.dark)
        } catch {
            errorMessage = String(describing: error)
            preview = NSAttributedString(string: "")
        }
    }

    private func resourceURL(named name: String) throws -> URL {
        guard let url = demoResourceBundle.url(forResource: name, withExtension: nil) else {
            throw SyntaxKitError.parsing("Missing demo resource '\(name)'.")
        }
        return url
    }

    private func render() {
        guard let parser, let theme else { return }
        do {
            let parseStart = CFAbsoluteTimeGetCurrent()
            let incremental = try parser.parseIncrementally(sourceText, using: grammarScopeName)
            parseDurationMilliseconds = (CFAbsoluteTimeGetCurrent() - parseStart) * 1000

            let renderStart = CFAbsoluteTimeGetCurrent()
            let spans = ThemeResolver.resolve(result: incremental.parseResult, using: theme)
            themedSpans = spans
            lineStates = incremental.lineStates
            preview = DemoRenderer.render(text: sourceText, spans: spans)
            renderDurationMilliseconds = (CFAbsoluteTimeGetCurrent() - renderStart) * 1000
            errorMessage = nil
        } catch {
            themedSpans = []
            lineStates = []
            parseDurationMilliseconds = 0
            renderDurationMilliseconds = 0
            preview = NSAttributedString(string: sourceText)
            errorMessage = String(describing: error)
        }
    }

    nonisolated private static let debounceNanoseconds: UInt64 = 120_000_000

    private var renderTask: Task<Void, Never>?

    init() {}

    deinit {
        renderTask?.cancel()
    }

    func scheduleRender() {
        renderTask?.cancel()
        renderTask = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: Self.debounceNanoseconds)
            guard !Task.isCancelled else { return }
            self?.render()
        }
    }

    func loadBundledGrammar(_ asset: DemoAsset, replaceSource: Bool = true) throws {
        let grammarURL = try resourceURL(named: asset.grammarResourceName)
        let grammar = try GrammarLoader.load(from: grammarURL)
        let registry = GrammarRegistry(grammars: [grammar])
        parser = SyntaxParser(registry: registry)
        grammarName = asset.displayName
        grammarScopeName = grammar.scopeName.rawValue
        if replaceSource {
            sourceText = asset.sampleText
        }
        render()
    }

    func loadBundledTheme(_ asset: DemoThemeAsset = .dark) throws {
        let themeURL = try resourceURL(named: asset.resourceName)
        theme = try ThemeLoader.load(from: themeURL)
        themeName = asset.displayName
        render()
    }

    func importGrammar() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [
            UTType(filenameExtension: "tmLanguage") ?? .data,
            UTType.json
        ]
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.prompt = "Load Grammar"

        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            let grammar = try GrammarLoader.load(from: url)
            let registry = GrammarRegistry(grammars: [grammar])
            parser = SyntaxParser(registry: registry)
            grammarName = url.lastPathComponent
            grammarScopeName = grammar.scopeName.rawValue
            render()
        } catch {
            errorMessage = String(describing: error)
        }
    }

    func importTheme() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [
            UTType(filenameExtension: "tmTheme") ?? .data
        ]
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.prompt = "Load Theme"

        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            theme = try ThemeLoader.load(from: url)
            themeName = url.lastPathComponent
            render()
        } catch {
            errorMessage = String(describing: error)
        }
    }
}

private let demoResourceBundle: Bundle = {
#if SWIFT_PACKAGE
    return .module
#else
    return .main
#endif
}()

extension DemoModel {
    func updateSource(_ value: String) {
        sourceText = value
        scheduleRender()
    }

    var timingText: String {
        "Parse: \(Self.format(milliseconds: parseDurationMilliseconds))  |  Render: \(Self.format(milliseconds: renderDurationMilliseconds))"
    }

    private static func format(milliseconds: Double) -> String {
        String(format: "%.2f ms", milliseconds)
    }
}

enum DemoAsset: String, CaseIterable, Identifiable {
    case json
    case ini

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .json:
            return "JSON"
        case .ini:
            return "INI"
        }
    }

    var grammarResourceName: String {
        switch self {
        case .json:
            return "JSON.tmLanguage"
        case .ini:
            return "INI.tmLanguage.json"
        }
    }

    var sampleText: String {
        switch self {
        case .json:
            return Self.jsonSample
        case .ini:
            return Self.iniSample
        }
    }

    static let jsonSample = """
    {
      "name": "SyntaxKit",
      "version": "1.1.0",
      "features": [
        "tmLanguage",
        "sample tmTheme",
        "incremental parsing"
      ],
      "active": true,
      "stars": 5
    }
    """

    static let iniSample = """
    [syntaxkit]
    name=SyntaxKit
    theme=Sample Dark
    incremental=true
    ; change the grammar or load your own file
    """
}

enum DemoThemeAsset: String, CaseIterable, Identifiable {
    case dark
    case light

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .dark:
            return "Sample Dark"
        case .light:
            return "Sample Light"
        }
    }

    var resourceName: String {
        switch self {
        case .dark:
            return "SampleDark.tmTheme"
        case .light:
            return "SampleLight.tmTheme"
        }
    }
}

private enum DemoRenderer {
    static func render(text: String, spans: [ThemedSpan]) -> NSAttributedString {
        let output = NSMutableAttributedString(string: text)
        let fullRange = NSRange(location: 0, length: output.length)
        output.addAttributes(
            [
                .font: NSFont.monospacedSystemFont(ofSize: 14, weight: .regular),
                .foregroundColor: NSColor.textColor,
                .backgroundColor: NSColor.textBackgroundColor
            ],
            range: fullRange
        )

        for span in spans {
            let range = NSRange(location: span.startUTF16, length: span.endUTF16 - span.startUTF16)
            var attributes: [NSAttributedString.Key: Any] = [:]
            if let color = color(from: span.style.foreground) {
                attributes[.foregroundColor] = color
            }
            if let color = color(from: span.style.background) {
                attributes[.backgroundColor] = color
            }
            if span.style.fontStyles.contains(.italic) {
                attributes[.obliqueness] = 0.2
            }
            if span.style.fontStyles.contains(.underline) {
                attributes[.underlineStyle] = NSUnderlineStyle.single.rawValue
            }
            if span.style.fontStyles.contains(.bold) {
                attributes[.font] = NSFont.monospacedSystemFont(ofSize: 14, weight: .bold)
            }
            output.addAttributes(attributes, range: range)
        }

        return output
    }

    private static func color(from themeColor: ThemeColor?) -> NSColor? {
        guard let rgba = themeColor?.rgba else { return nil }
        return NSColor(
            calibratedRed: CGFloat(rgba.red) / 255.0,
            green: CGFloat(rgba.green) / 255.0,
            blue: CGFloat(rgba.blue) / 255.0,
            alpha: CGFloat(rgba.alpha) / 255.0
        )
    }
}
