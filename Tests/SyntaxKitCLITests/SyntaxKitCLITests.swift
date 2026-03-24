import Foundation
import Testing
@testable import SyntaxKit
@testable import SyntaxKitCLI

@Test func cliParsesThemeOption() throws {
    let options = try CLI.parseOptions([
        "--grammar", "grammar.tmLanguage",
        "--scope", "source.json",
        "--input", "sample.json",
        "--theme", "theme.tmTheme"
    ])
    #expect(options.themePath == "theme.tmTheme")
}

@Test func cliParseJsonUsesThemedSpanOutputWhenThemeIsProvided() throws {
    let grammarPath = "/Users/gmao/code/SyntaxKit/languages/JSON.tmLanguage"
    let themePath = "/Users/gmao/code/SyntaxKit/themes/Monokai.tmTheme"
    let samplePath = "/tmp/syntaxkit-cli-parse-themed.json"
    try "{ \"ok\": true }\n".write(toFile: samplePath, atomically: true, encoding: .utf8)

    var stdout = ""
    var stderr = ""
    let exitCode = CLI.run(
        arguments: ["parse", "--grammar", grammarPath, "--scope", "source.json", "--input", samplePath, "--json", "--theme", themePath],
        stdout: { stdout += $0 },
        stderr: { stderr += $0 }
    )

    #expect(exitCode == 0)
    #expect(stderr.isEmpty)
    #expect(stdout.contains("\"style\""))
    #expect(stdout.contains("\"foreground\""))
    #expect(stdout.contains("punctuation.definition.dictionary.begin.json"))
}

@Test func cliParseOutputMatchesSnapshotFixture() throws {
    let grammarPath = "/Users/gmao/code/SyntaxKit/languages/JSON.tmLanguage"
    let samplePath = "/tmp/syntaxkit-cli-snapshot.json"
    try "{ \"ok\": true }\n".write(toFile: samplePath, atomically: true, encoding: .utf8)

    var stdout = ""
    var stderr = ""
    let exitCode = CLI.run(
        arguments: ["parse", "--grammar", grammarPath, "--scope", "source.json", "--input", samplePath],
        stdout: { stdout += $0 },
        stderr: { stderr += $0 }
    )

    #expect(exitCode == 0)
    #expect(stderr.isEmpty)
    let expected = try fixture(named: "parse_snapshot.txt")
    #expect(stdout == expected)
}

@Test func cliThemedJSONOutputMatchesSnapshotFixture() throws {
    let grammarPath = "/Users/gmao/code/SyntaxKit/languages/JSON.tmLanguage"
    let themePath = "/Users/gmao/code/SyntaxKit/themes/Monokai.tmTheme"
    let samplePath = "/tmp/syntaxkit-cli-themed-snapshot.json"
    try "{ \"ok\": true }\n".write(toFile: samplePath, atomically: true, encoding: .utf8)

    var stdout = ""
    var stderr = ""
    let exitCode = CLI.run(
        arguments: ["parse", "--grammar", grammarPath, "--scope", "source.json", "--input", samplePath, "--json", "--theme", themePath],
        stdout: { stdout += $0 },
        stderr: { stderr += $0 }
    )

    #expect(exitCode == 0)
    #expect(stderr.isEmpty)
    let expected = try fixture(named: "parse_themed_snapshot.json")
    #expect(stdout == expected)
}

@Test func cliPreviewUsesThemeWhenProvided() throws {
    let grammarPath = "/Users/gmao/code/SyntaxKit/languages/JSON.tmLanguage"
    let themePath = "/Users/gmao/code/SyntaxKit/themes/Monokai.tmTheme"
    let samplePath = "/tmp/syntaxkit-cli-preview.json"
    try "{ \"name\": \"SyntaxKit\" }\n".write(toFile: samplePath, atomically: true, encoding: .utf8)

    var stdout = ""
    var stderr = ""
    let exitCode = CLI.run(
        arguments: ["preview", "--grammar", grammarPath, "--scope", "source.json", "--input", samplePath, "--theme", themePath],
        stdout: { stdout += $0 },
        stderr: { stderr += $0 }
    )

    #expect(exitCode == 0)
    #expect(stderr.isEmpty)
    #expect(stdout.contains("38;2;230;219;116"))
}

@Test func cliPreviewFallsBackToDebugPaletteWithoutTheme() throws {
    let span = SyntaxSpan(startUTF16: 0, endUTF16: 3, line: 1, column: 1, scopes: ["string.quoted"])
    let rendered = ANSIHighlighter.render(text: "abc", spans: [span])
    #expect(rendered.contains("\u{001B}[32m"))
}

@Test func cliThemeAnsiRendererHandlesForegroundBackgroundAndRGBA() throws {
    let style = ThemeStyle(
        foreground: ThemeColor(rawValue: "#010203"),
        background: ThemeColor(rawValue: "#AABBCCDD"),
        fontStyles: [.bold, .italic, .underline]
    )
    let ansi = ANSIHighlighter.ansiStyle(for: style)
    #expect(ansi.contains("[1;3;4;38;2;1;2;3;48;2;170;187;204m"))
}

@Test func cliThemeAnsiRendererSupportsNamedColorsAndRejectsInvalidOnes() throws {
    let style = ThemeStyle(
        foreground: ThemeColor(rawValue: "red"),
        background: nil,
        fontStyles: []
    )
    #expect(ANSIHighlighter.ansiStyle(for: style).contains("[38;2;255;0;0m"))
    #expect(ANSIHighlighter.rgb(from: "red")?.red == 255)
    #expect(ANSIHighlighter.rgb(from: "not-a-color") == nil)
    #expect(ANSIHighlighter.rgb(from: "#010203")?.red == 1)
    #expect(ANSIHighlighter.rgb(from: "#01020304")?.blue == 3)
}

@Test func cliPrettyJSONStringFormatsSortedOutput() throws {
    struct Example: Codable {
        let beta: Int
        let alpha: Int
    }

    let json = try CLI.prettyJSONString(from: Example(beta: 2, alpha: 1))
    #expect(json.contains("\n"))
    let alphaRange = try #require(json.range(of: "\"alpha\""))
    let betaRange = try #require(json.range(of: "\"beta\""))
    #expect(alphaRange.lowerBound < betaRange.lowerBound)
}

private func fixture(named name: String) throws -> String {
    guard let url = Bundle.module.url(forResource: name, withExtension: nil, subdirectory: "Fixtures") else {
        Issue.record("Missing fixture \(name)")
        return ""
    }
    return try String(contentsOf: url, encoding: .utf8)
}
