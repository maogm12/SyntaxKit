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

@Test func cliThemeAnsiRendererIgnoresUnsupportedColors() throws {
    let style = ThemeStyle(
        foreground: ThemeColor(rawValue: "red"),
        background: nil,
        fontStyles: []
    )
    #expect(ANSIHighlighter.ansiStyle(for: style) == ANSIHighlighter.reset)
    #expect(ANSIHighlighter.rgb(from: "red") == nil)
    #expect(ANSIHighlighter.rgb(from: "#010203")?.red == 1)
    #expect(ANSIHighlighter.rgb(from: "#01020304")?.blue == 3)
}
