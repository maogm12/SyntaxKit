import AppKit
import Combine
import Foundation
import SyntaxKit

@MainActor
final class DemoModel: ObservableObject {
    @Published var sourceText = """
    {
      "name": "SyntaxKit",
      "version": "1.0.0",
      "features": [
        "tmLanguage",
        "tmTheme",
        "incremental parsing"
      ],
      "active": true,
      "stars": 5
    }
    """
    @Published private(set) var preview = NSAttributedString(string: "")
    @Published private(set) var themedSpans: [ThemedSpan] = []
    @Published private(set) var lineStates: [SyntaxLineState] = []
    @Published private(set) var errorMessage: String?

    private var parser: SyntaxParser?
    private var theme: Theme?

    var statusText: String {
        errorMessage == nil ? "Ready" : "Rendering issue"
    }

    func load() async {
        do {
            let grammarURL = try resourceURL(named: "JSON.tmLanguage")
            let themeURL = try resourceURL(named: "Monokai.tmTheme")
            let grammar = try GrammarLoader.load(from: grammarURL)
            let registry = GrammarRegistry(grammars: [grammar])
            parser = SyntaxParser(registry: registry)
            theme = try ThemeLoader.load(from: themeURL)
            render()
        } catch {
            errorMessage = String(describing: error)
            preview = NSAttributedString(string: "")
        }
    }

    private func resourceURL(named name: String) throws -> URL {
        guard let url = Bundle.module.url(forResource: name, withExtension: nil) else {
            throw SyntaxKitError.parsing("Missing demo resource '\(name)'.")
        }
        return url
    }

    private func render() {
        guard let parser, let theme else { return }
        do {
            let incremental = try parser.parseIncrementally(sourceText, using: "source.json")
            let spans = ThemeResolver.resolve(result: incremental.parseResult, using: theme)
            themedSpans = spans
            lineStates = incremental.lineStates
            preview = DemoRenderer.render(text: sourceText, spans: spans)
            errorMessage = nil
        } catch {
            themedSpans = []
            lineStates = []
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
}

extension DemoModel {
    func updateSource(_ value: String) {
        sourceText = value
        scheduleRender()
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
