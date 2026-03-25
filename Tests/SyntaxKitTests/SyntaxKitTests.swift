import Foundation
import Testing
@testable import SyntaxKit

@Test func loadsJSONFixtureGrammar() throws {
    let fixtureURL = URL(fileURLWithPath: "/Users/gmao/code/SyntaxKit/languages/JSON.tmLanguage")
    let grammar = try GrammarLoader.load(from: fixtureURL)
    #expect(grammar.scopeName.rawValue == "source.json")
    #expect(grammar.repository["array"] != nil)
}

@Test func loadsINIJSONFixtureGrammar() throws {
    let fixtureURL = URL(fileURLWithPath: "/Users/gmao/code/SyntaxKit/languages/INI.tmLanguage.json")
    let grammar = try GrammarLoader.load(from: fixtureURL)
    #expect(grammar.scopeName.rawValue == "source.ini")
    #expect(grammar.patterns.isEmpty == false)
}

@Test func loadsSampleDarkThemeFixture() throws {
    let fixtureURL = URL(fileURLWithPath: "/Users/gmao/code/SyntaxKit/themes/SampleDark.tmTheme")
    let theme = try ThemeLoader.load(from: fixtureURL)
    #expect(theme.name == "Sample Dark")
    #expect(theme.globals.background?.rawValue == "#1E1F24")
    #expect(theme.globals.background?.rgba?.red == 30)
    #expect(theme.globals.gutter?.rawValue == "#232733")
    #expect(theme.globals.gutterForeground?.rawValue == "#7B8496")
    #expect(theme.rules.contains(where: { $0.scopes.contains("comment") && $0.style.foreground?.rawValue == "#7B8496" }))
    #expect(theme.rules.contains(where: { $0.scopes.contains("constant.numeric") }))
}

@Test func loadsSampleLightThemeFixture() throws {
    let fixtureURL = URL(fileURLWithPath: "/Users/gmao/code/SyntaxKit/themes/SampleLight.tmTheme")
    let theme = try ThemeLoader.load(from: fixtureURL)
    #expect(theme.name == "Sample Light")
    #expect(theme.globals.background?.rawValue == "#FAF8F2")
    #expect(theme.globals.foreground?.rawValue == "#243145")
    #expect(theme.globals.gutter?.rawValue == "#ECE6D8")
    #expect(theme.rules.contains(where: { $0.scopes.contains("string") && $0.style.foreground?.rawValue == "#2F7D4A" }))
}

@Test func rejectsThemeWithoutName() throws {
    let plist = """
    <?xml version="1.0" encoding="UTF-8"?>
    <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
    <plist version="1.0">
    <dict>
      <key>settings</key>
      <array>
        <dict><key>settings</key><dict/></dict>
      </array>
    </dict>
    </plist>
    """
    try expectThemeError(plist: plist, containing: "Theme is missing required key 'name'")
}

@Test func rejectsThemeWithoutSettings() throws {
    let plist = """
    <?xml version="1.0" encoding="UTF-8"?>
    <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
    <plist version="1.0">
    <dict>
      <key>name</key><string>Broken</string>
      <key>settings</key><array/>
    </dict>
    </plist>
    """
    try expectThemeError(plist: plist, containing: "non-empty key 'settings'")
}

@Test func rejectsMalformedThemeStructures() throws {
    let topLevelArray = """
    <?xml version="1.0" encoding="UTF-8"?>
    <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
    <plist version="1.0">
    <array><string>bad</string></array>
    </plist>
    """
    try expectThemeError(plist: topLevelArray, containing: "Top-level theme plist must be a dictionary")

    let badGlobalEntry = """
    <?xml version="1.0" encoding="UTF-8"?>
    <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
    <plist version="1.0">
    <dict>
      <key>name</key><string>Broken</string>
      <key>settings</key>
      <array>
        <string>bad</string>
      </array>
    </dict>
    </plist>
    """
    try expectThemeError(plist: badGlobalEntry, containing: "Theme global settings entry must be a dictionary")

    let missingGlobalSettingsDict = """
    <?xml version="1.0" encoding="UTF-8"?>
    <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
    <plist version="1.0">
    <dict>
      <key>name</key><string>Broken</string>
      <key>settings</key>
      <array>
        <dict/>
      </array>
    </dict>
    </plist>
    """
    try expectThemeError(plist: missingGlobalSettingsDict, containing: "must contain a 'settings' dictionary")

    let badRuleEntry = """
    <?xml version="1.0" encoding="UTF-8"?>
    <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
    <plist version="1.0">
    <dict>
      <key>name</key><string>Broken</string>
      <key>settings</key>
      <array>
        <dict><key>settings</key><dict/></dict>
        <string>bad</string>
      </array>
    </dict>
    </plist>
    """
    try expectThemeError(plist: badRuleEntry, containing: "Theme scope style entry must be a dictionary")

    let missingRuleSettings = """
    <?xml version="1.0" encoding="UTF-8"?>
    <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
    <plist version="1.0">
    <dict>
      <key>name</key><string>Broken</string>
      <key>settings</key>
      <array>
        <dict><key>settings</key><dict/></dict>
        <dict><key>scope</key><string>comment</string></dict>
      </array>
    </dict>
    </plist>
    """
    try expectThemeError(plist: missingRuleSettings, containing: "Theme scope style entry must contain a 'settings' dictionary")
}

@Test func themeLoaderParsesFontStylesAndCommaSeparatedScopes() throws {
    let theme = try ThemeLoader.load(data: Data(sampleTheme.utf8))
    let rule = try #require(theme.rules.first)
    #expect(rule.name == "Multi Scope")
    #expect(rule.scopes == ["comment", "string.quoted"])
    #expect(rule.style.foreground?.rawValue == "#112233")
    #expect(rule.style.background?.rawValue == "#445566")
    #expect(rule.style.fontStyles == [.bold, .italic, .underline])
}

@Test func themeLoaderDefaultsMissingScopeToEmptyList() throws {
    let theme = try ThemeLoader.load(data: Data(themeWithoutScope.utf8))
    let rule = try #require(theme.rules.first)
    #expect(rule.scopes.isEmpty)
}

@Test func themePublicTypesCoverInitializers() throws {
    let color = ThemeColor(rawValue: "#ABCDEF")
    let style = ThemeStyle(foreground: color, background: nil, fontStyles: [.bold])
    let globals = ThemeGlobals(
        background: color,
        foreground: color,
        caret: color,
        selection: color,
        selectionForeground: color,
        lineHighlight: color,
        gutter: color,
        gutterForeground: color
    )
    let rule = ThemeRule(name: "Rule", scopes: ["comment"], style: style)
    let theme = Theme(name: "Theme", globals: globals, rules: [rule])
    #expect(theme.name == "Theme")
    #expect(theme.rules.first?.style.fontStyles == [.bold])
    let themedSpan = ThemedSpan(
        startUTF16: 0,
        endUTF16: 3,
        line: 1,
        column: 1,
        scopes: ["comment.line"],
        style: style
    )
    #expect(themedSpan.style.foreground == color)
}

@Test func themeColorParsesHexAndNamedColors() throws {
    #expect(ThemeColor(parsing: "#123")?.rgba?.red == 17)
    #expect(ThemeColor(parsing: "#1234")?.rgba?.alpha == 68)
    #expect(ThemeColor(parsing: "#112233")?.rgba?.blue == 51)
    #expect(ThemeColor(parsing: "#11223344")?.rgba?.alpha == 68)
    #expect(ThemeColor(parsing: "red")?.rgba?.red == 255)
    #expect(ThemeColor(parsing: "white")?.rgba?.blue == 255)
    #expect(ThemeColor(parsing: "#12g") == nil)
    #expect(ThemeColor(parsing: "#123z") == nil)
    #expect(ThemeColor(parsing: "#12") == nil)
    #expect(ThemeColor(parsing: "not-a-color") == nil)
    #expect(ThemeColor(rawValue: "not-a-color").rgba == nil)
}

@Test func themeLoaderRejectsInvalidColors() throws {
    let badTheme = """
    <?xml version="1.0" encoding="UTF-8"?>
    <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
    <plist version="1.0">
    <dict>
      <key>name</key><string>Bad Color</string>
      <key>settings</key>
      <array>
        <dict>
          <key>settings</key>
          <dict>
            <key>foreground</key><string>not-a-color</string>
          </dict>
        </dict>
      </array>
    </dict>
    </plist>
    """
    try expectThemeError(plist: badTheme, containing: "unsupported color")
}

@Test func themeResolverMatchesPrefixScopesAndUsesGlobals() throws {
    let theme = try ThemeLoader.load(data: Data(sampleTheme.utf8))
    let span = SyntaxSpan(startUTF16: 0, endUTF16: 4, line: 1, column: 1, scopes: ["source.test", "comment.line.double-slash"])
    let themed = ThemeResolver.resolve(span: span, using: theme)
    #expect(themed.style.foreground?.rawValue == "#112233")
    #expect(themed.style.background?.rawValue == "#445566")
    #expect(themed.style.fontStyles == [.bold, .italic, .underline])
}

@Test func themeResolverPrefersMoreSpecificRules() throws {
    let theme = try ThemeLoader.load(data: Data(specificityTheme.utf8))
    let span = SyntaxSpan(startUTF16: 0, endUTF16: 1, line: 1, column: 1, scopes: ["source.test", "constant.numeric.integer.test"])
    let themed = ThemeResolver.resolve(span: span, using: theme)
    #expect(themed.style.foreground?.rawValue == "#202020")
}

@Test func themeResolverAllowsLaterEqualSpecificityRulesToOverride() throws {
    let theme = try ThemeLoader.load(data: Data(equalSpecificityTheme.utf8))
    let span = SyntaxSpan(startUTF16: 0, endUTF16: 1, line: 1, column: 1, scopes: ["keyword.control.test"])
    let themed = ThemeResolver.resolve(span: span, using: theme)
    #expect(themed.style.foreground?.rawValue == "#222222")
}

@Test func themeResolverReturnsGlobalsWhenNoRuleMatches() throws {
    let theme = try ThemeLoader.load(data: Data(sampleTheme.utf8))
    let span = SyntaxSpan(startUTF16: 0, endUTF16: 2, line: 1, column: 1, scopes: ["source.test"])
    let themed = ThemeResolver.resolve(span: span, using: theme)
    #expect(themed.style.foreground?.rawValue == "#FFFFFF")
    #expect(themed.style.background?.rawValue == "#000000")
    #expect(themed.style.fontStyles.isEmpty)
}

@Test func themeResolverCanResolveWholeParseResults() throws {
    let grammar = try GrammarLoader.load(data: Data(simpleNumbersGrammar.utf8))
    let theme = try ThemeLoader.load(data: Data(simpleHighlightTheme.utf8))
    let registry = GrammarRegistry(grammars: [grammar])
    let parser = SyntaxParser(registry: registry)
    let result = try parser.parse("12 true", using: "source.simple")
    let themed = ThemeResolver.resolve(result: result, using: theme)
    #expect(themed.count == result.spans.count)
    #expect(themed.contains(where: { $0.scopes.contains("constant.numeric.simple") && $0.style.foreground?.rawValue == "#101010" }))
    #expect(themed.contains(where: { $0.scopes.contains("constant.language.simple") && $0.style.foreground?.rawValue == "#202020" }))
}

@Test func syntaxHighlighterSupportsGrammarRegistryAndResolvedGrammarInputs() throws {
    let grammar = try GrammarLoader.load(data: Data(simpleNumbersGrammar.utf8))
    let theme = try ThemeLoader.load(data: Data(simpleHighlightTheme.utf8))
    let registry = GrammarRegistry(grammars: [grammar])
    let resolved = try registry.resolve(scopeName: "source.simple")

    let viaRegistry = try SyntaxHighlighter.highlight("12 true", using: "source.simple", registry: registry, theme: theme)
    let viaGrammar = try SyntaxHighlighter.highlight("12 true", grammar: grammar, theme: theme)
    let viaResolved = try SyntaxHighlighter.highlight("12 true", resolvedGrammar: resolved, registry: registry, theme: theme)

    #expect(viaRegistry == viaGrammar)
    #expect(viaGrammar == viaResolved)
    #expect(viaResolved.contains(where: { $0.scopes.contains("constant.numeric.simple") && $0.style.foreground?.rawValue == "#101010" }))
    #expect(viaResolved.contains(where: { $0.scopes.contains("constant.language.simple") && $0.style.foreground?.rawValue == "#202020" }))
}

@Test @available(macOS 12, iOS 15, tvOS 15, watchOS 8, *)
func styledTextAdapterBuildsRunsAndAttributedOutputs() throws {
    let style = ThemeStyle(
        foreground: ThemeColor(rawValue: "#112233"),
        background: ThemeColor(rawValue: "#445566"),
        fontStyles: [.bold, .italic]
    )
    let plainStyle = ThemeStyle(foreground: nil, background: nil, fontStyles: [])
    let spans = [
        ThemedSpan(startUTF16: 0, endUTF16: 1, line: 1, column: 1, scopes: ["scope.one"], style: style),
        ThemedSpan(startUTF16: 2, endUTF16: 3, line: 2, column: 1, scopes: ["scope.two"], style: plainStyle)
    ]

    let runs = StyledTextAdapter.runs(text: "a\nb", themedSpans: spans)
    #expect(runs.count == 3)
    #expect(runs[0] == StyledTextRun(text: "a", startUTF16: 0, endUTF16: 1, scopes: ["scope.one"], style: style))
    #expect(runs[1] == StyledTextRun(text: "\n", startUTF16: 1, endUTF16: 2, scopes: [], style: nil))
    #expect(runs[2] == StyledTextRun(text: "b", startUTF16: 2, endUTF16: 3, scopes: ["scope.two"], style: plainStyle))

    let attributed = StyledTextAdapter.attributedString(text: "a\nb", themedSpans: spans)
    #expect(String(attributed.characters) == "a\nb")
    let attributedRuns = Array(attributed.runs)
    let firstAttributedRun = try #require(attributedRuns.first)
    #expect(firstAttributedRun[SyntaxKitScopesAttribute.self] == ["scope.one"])
    #expect(firstAttributedRun[SyntaxKitForegroundAttribute.self] == "#112233")
    #expect(firstAttributedRun[SyntaxKitBackgroundAttribute.self] == "#445566")
    #expect(firstAttributedRun[SyntaxKitFontStylesAttribute.self] == ["bold", "italic"])

    let nsAttributed = StyledTextAdapter.nsAttributedString(text: "a\nb", themedSpans: spans)
    #expect(nsAttributed.string == "a\nb")
    let styledAttributes = nsAttributed.attributes(at: 0, effectiveRange: nil)
    #expect(styledAttributes[NSAttributedString.Key(StyledTextAdapter.scopesAttributeName)] as? [String] == ["scope.one"])
    #expect(styledAttributes[NSAttributedString.Key(StyledTextAdapter.foregroundAttributeName)] as? String == "#112233")
    #expect(styledAttributes[NSAttributedString.Key(StyledTextAdapter.backgroundAttributeName)] as? String == "#445566")
    #expect(styledAttributes[NSAttributedString.Key(StyledTextAdapter.fontStylesAttributeName)] as? [String] == ["bold", "italic"])
    let plainAttributes = nsAttributed.attributes(at: 1, effectiveRange: nil)
    #expect(plainAttributes.isEmpty)
}

@Test @available(macOS 12, iOS 15, tvOS 15, watchOS 8, *)
func styledTextAdapterSupportsEmptyInputs() throws {
    let runs = StyledTextAdapter.runs(text: "plain", themedSpans: [])
    #expect(runs == [StyledTextRun(text: "plain", startUTF16: 0, endUTF16: 5, scopes: [], style: nil)])
    let attributed = StyledTextAdapter.attributedString(text: "", themedSpans: [])
    #expect(String(attributed.characters).isEmpty)
    let nsAttributed = StyledTextAdapter.nsAttributedString(text: "", themedSpans: [])
    #expect(nsAttributed.string.isEmpty)
}

@Test func themeResolverInternalHelpersCoverNonMatches() throws {
    let rule = ThemeRule(name: "Rule", scopes: ["comment.line"], style: ThemeStyle(foreground: nil, background: nil, fontStyles: []))
    let multiScopeRule = ThemeRule(name: "Multi", scopes: ["constant", "constant.numeric"], style: ThemeStyle(foreground: nil, background: nil, fontStyles: []))
    #expect(ThemeResolver.scopeMatchSpecificity(ruleScope: "comment", candidateScope: "comment.line") == 1)
    #expect(ThemeResolver.scopeMatchSpecificity(ruleScope: "comment.line", candidateScope: "comment.line") == 2)
    #expect(ThemeResolver.scopeMatchSpecificity(ruleScope: "comment", candidateScope: "string.quoted") == nil)
    #expect(ThemeResolver.scopeMatchSpecificity(ruleScope: "", candidateScope: "comment.line") == nil)
    #expect(ThemeResolver.ruleSpecificity(rule, matching: ["source.test", "string.quoted"]) == nil)
    #expect(ThemeResolver.ruleSpecificity(multiScopeRule, matching: ["constant.numeric.integer.test"]) == 2)
    #expect("comment.line.double-slash".syntaxKitScopeLabelCount == 3)
}

@Test func rejectsMissingScopeName() throws {
    let plist = """
    <?xml version="1.0" encoding="UTF-8"?>
    <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
    <plist version="1.0">
    <dict>
      <key>patterns</key>
      <array/>
    </dict>
    </plist>
    """
    do {
        _ = try GrammarLoader.load(data: Data(plist.utf8))
        Issue.record("Expected loader to reject grammar without scopeName.")
    } catch let error as SyntaxKitError {
        #expect(error.description.contains("scopeName"))
    }
}

@Test func rejectsTopLevelArrayPlist() throws {
    let plist = """
    <?xml version="1.0" encoding="UTF-8"?>
    <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
    <plist version="1.0">
    <array>
      <string>not a dictionary</string>
    </array>
    </plist>
    """
    try expectSyntaxKitError(plist: plist, containing: "Top-level grammar document")
}

@Test func rejectsTopLevelArrayJSONGrammar() throws {
    try expectSyntaxKitError(plist: """
    [
      "not a dictionary"
    ]
    """, containing: "Top-level grammar document")
}

@Test func rejectsInvalidRepositoryEntryType() throws {
    let plist = """
    <?xml version="1.0" encoding="UTF-8"?>
    <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
    <plist version="1.0">
    <dict>
      <key>scopeName</key><string>source.badrepo</string>
      <key>repository</key>
      <dict>
        <key>oops</key><string>bad</string>
      </dict>
    </dict>
    </plist>
    """
    try expectSyntaxKitError(plist: plist, containing: "Repository entry 'oops'")
}

@Test func rejectsInvalidPatternEntryType() throws {
    let plist = """
    <?xml version="1.0" encoding="UTF-8"?>
    <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
    <plist version="1.0">
    <dict>
      <key>scopeName</key><string>source.badpattern</string>
      <key>patterns</key>
      <array>
        <string>bad</string>
      </array>
    </dict>
    </plist>
    """
    try expectSyntaxKitError(plist: plist, containing: "Pattern entries must be dictionaries")
}

@Test func rejectsMixedMatchAndBeginRule() throws {
    try expectSyntaxKitError(plist: plist(ruleBody: """
      <key>patterns</key>
      <array>
        <dict>
          <key>match</key><string>a</string>
          <key>begin</key><string>b</string>
          <key>end</key><string>c</string>
        </dict>
      </array>
    """), containing: "mixes 'match' with 'begin'/'end'")
}

@Test func rejectsBeginWithoutEndRule() throws {
    try expectSyntaxKitError(plist: plist(ruleBody: """
      <key>patterns</key>
      <array>
        <dict>
          <key>begin</key><string>a</string>
        </dict>
      </array>
    """), containing: "begin' without matching 'end'")
}

@Test func rejectsEndWithoutBeginRule() throws {
    try expectSyntaxKitError(plist: plist(ruleBody: """
      <key>patterns</key>
      <array>
        <dict>
          <key>end</key><string>a</string>
        </dict>
      </array>
    """), containing: "end' without matching 'begin'")
}

@Test func rejectsEmptyRule() throws {
    try expectSyntaxKitError(plist: plist(ruleBody: """
      <key>patterns</key>
      <array>
        <dict/>
      </array>
    """), containing: "must define 'match', 'begin'/'end', 'include', or nested 'patterns'")
}

@Test func rejectsInvalidCaptureKeyAndShape() throws {
    try expectSyntaxKitError(plist: plist(ruleBody: """
      <key>patterns</key>
      <array>
        <dict>
          <key>match</key><string>a</string>
          <key>captures</key>
          <dict>
            <key>-1</key>
            <dict><key>name</key><string>scope.bad</string></dict>
          </dict>
        </dict>
      </array>
    """), containing: "non-negative integer")

    try expectSyntaxKitError(plist: plist(ruleBody: """
      <key>patterns</key>
      <array>
        <dict>
          <key>match</key><string>a</string>
          <key>captures</key>
          <dict>
            <key>0</key>
            <string>bad</string>
          </dict>
        </dict>
      </array>
    """), containing: "Capture '0' must be a dictionary")

    try expectSyntaxKitError(plist: plist(ruleBody: """
      <key>patterns</key>
      <array>
        <dict>
          <key>match</key><string>a</string>
          <key>captures</key>
          <dict>
            <key>0</key>
            <dict/>
          </dict>
        </dict>
      </array>
    """), containing: "missing required key 'name'")
}

@Test func rejectsUnresolvedRepositoryInclude() throws {
    let grammar = try GrammarLoader.load(data: Data(invalidRepositoryGrammar.utf8))
    let registry = GrammarRegistry(grammars: [grammar])
    do {
        _ = try registry.resolve(scopeName: "source.invalid")
        Issue.record("Expected unresolved include to fail resolution.")
    } catch let error as SyntaxKitError {
        #expect(error.description.contains("missing repository rule"))
    }
}

@Test func registrySupportsRegisterAPIsAndMissingScopeErrors() throws {
    let grammar = try GrammarLoader.load(data: Data(simpleNumbersGrammar.utf8))
    let secondGrammar = try GrammarLoader.load(data: Data(embeddedGrammar.utf8))
    let registry = GrammarRegistry()
    registry.register(grammar)
    registry.register(contentsOf: [secondGrammar])
    #expect(registry.grammar(for: "source.simple")?.scopeName.rawValue == "source.simple")
    #expect(registry.registeredScopeNames == ["source.embedded", "source.simple"])
    do {
        _ = try registry.resolve(scopeName: "source.unknown")
        Issue.record("Expected resolve to fail for an unknown scope.")
    } catch let error as SyntaxKitError {
        #expect(error.description.contains("No grammar registered"))
    }
}

@Test func registryRejectsInvalidRegexAndMissingExternalGrammar() throws {
    let badRegex = try GrammarLoader.load(data: Data(plist(ruleBody: """
      <key>patterns</key>
      <array>
        <dict>
          <key>match</key><string>(</string>
          <key>name</key><string>invalid.regex</string>
        </dict>
      </array>
    """).utf8))
    let registry = GrammarRegistry(grammars: [badRegex])
    do {
        _ = try registry.resolve(scopeName: "source.generated")
        Issue.record("Expected invalid regex to fail resolution.")
    } catch let error as SyntaxKitError {
        #expect(error.description.contains("Failed to compile regex"))
    }

    let missingExternal = try GrammarLoader.load(data: Data(plist(ruleBody: """
      <key>patterns</key>
      <array>
        <dict><key>include</key><string>source.missing</string></dict>
      </array>
    """).utf8))
    let secondRegistry = GrammarRegistry(grammars: [missingExternal])
    do {
        _ = try secondRegistry.resolve(scopeName: "source.generated")
        Issue.record("Expected missing external grammar to fail resolution.")
    } catch let error as SyntaxKitError {
        #expect(error.description.contains("unknown external grammar"))
    }
}

@Test func supportsSelfIncludeResolution() throws {
    let grammar = try GrammarLoader.load(data: Data(selfIncludeGrammar.utf8))
    let registry = GrammarRegistry(grammars: [grammar])
    let resolved = try registry.resolve(scopeName: "source.self")
    #expect(resolved.scopeName.rawValue == "source.self")
}

@Test func parsesSimpleMatchGrammar() throws {
    let grammar = try GrammarLoader.load(data: Data(simpleNumbersGrammar.utf8))
    let registry = GrammarRegistry(grammars: [grammar])
    let parser = SyntaxParser(registry: registry)
    let spans = try parser.tokenize("12 true", using: "source.simple")
    #expect(spans.contains(where: { $0.scopes.contains("constant.numeric.simple") }))
    #expect(spans.contains(where: { $0.scopes.contains("constant.language.simple") }))
    #expect(spans == spans.sorted { ($0.startUTF16, $0.endUTF16) < ($1.startUTF16, $1.endUTF16) })
}

@Test func parsesJSONFixture() throws {
    let fixtureURL = URL(fileURLWithPath: "/Users/gmao/code/SyntaxKit/languages/JSON.tmLanguage")
    let grammar = try GrammarLoader.load(from: fixtureURL)
    let registry = GrammarRegistry(grammars: [grammar])
    let parser = SyntaxParser(registry: registry)
    let sample = """
    {
      "name": "SyntaxKit",
      "enabled": true,
      "count": 2
    }
    """
    let result = try parser.parse(sample, using: "source.json")
    #expect(result.spans.contains(where: { $0.scopes.contains("string.quoted.double.json") }))
    #expect(result.spans.contains(where: { $0.scopes.contains("constant.language.json") }))
    #expect(result.spans.contains(where: { $0.scopes.contains("constant.numeric.json") }))
}

@Test func parsesINIFixture() throws {
    let fixtureURL = URL(fileURLWithPath: "/Users/gmao/code/SyntaxKit/languages/INI.tmLanguage.json")
    let grammar = try GrammarLoader.load(from: fixtureURL)
    let registry = GrammarRegistry(grammars: [grammar])
    let parser = SyntaxParser(registry: registry)
    let sample = """
    [section]
    name=value
    ; comment
    """
    let result = try parser.parse(sample, using: "source.ini")
    #expect(result.spans.contains(where: { $0.scopes.contains("entity.name.section.group-title.ini") }))
    #expect(result.spans.contains(where: { $0.scopes.contains("keyword.other.definition.ini") }))
}

@Test func parsesJSONClosingBraceWithDelimiterScope() throws {
    let fixtureURL = URL(fileURLWithPath: "/Users/gmao/code/SyntaxKit/languages/JSON.tmLanguage")
    let grammar = try GrammarLoader.load(from: fixtureURL)
    let registry = GrammarRegistry(grammars: [grammar])
    let parser = SyntaxParser(registry: registry)
    let sample = """
    {
      "name": "SyntaxKit"
    }
    """
    let result = try parser.parse(sample, using: "source.json")
    #expect(result.spans.contains(where: {
        $0.scopes.contains("punctuation.definition.dictionary.end.json")
    }))
}

@Test func parserSupportsResolvedGrammarInitializerAndEmptyText() throws {
    let grammar = try GrammarLoader.load(data: Data(simpleNumbersGrammar.utf8))
    let registry = GrammarRegistry(grammars: [grammar])
    let resolved = try registry.resolve(scopeName: "source.simple")
    let parser = SyntaxParser(resolvedGrammar: resolved, registry: registry)
    let result = try parser.parse("")
    #expect(result.scopeName.rawValue == "source.simple")
    #expect(result.spans.isEmpty)
}

@Test func incrementalParsingCapturesLineStatesAndSupportsReparse() throws {
    let fixtureURL = URL(fileURLWithPath: "/Users/gmao/code/SyntaxKit/languages/JSON.tmLanguage")
    let grammar = try GrammarLoader.load(from: fixtureURL)
    let registry = GrammarRegistry(grammars: [grammar])
    let parser = SyntaxParser(registry: registry)
    let sample = """
    {
      "ok": true
    }
    """

    let incremental = try parser.parseIncrementally(sample, using: "source.json")
    #expect(incremental.lineStates.count == 3)
    #expect(SyntaxLineState.initial.line == 0)
    let firstLineState = try #require(incremental.lineStates.first)
    #expect(firstLineState.contexts.isEmpty == false)

    let suffix = """
      "ok": true
    }
    """
    let reparsed = try parser.reparse(suffix, using: "source.json", from: firstLineState)
    let expectedSuffixSpans = incremental.parseResult.spans.filter { $0.startUTF16 >= firstLineState.nextUTF16Offset }
    #expect(reparsed.parseResult.spans == expectedSuffixSpans)

    let tokenized = try parser.tokenizeIncrementally(sample, using: "source.json")
    #expect(tokenized.parseResult.spans == incremental.parseResult.spans)
}

@Test func incrementalParsingRejectsInvalidSavedStates() throws {
    let grammar = try GrammarLoader.load(data: Data(simpleNumbersGrammar.utf8))
    let registry = GrammarRegistry(grammars: [grammar])
    let parser = SyntaxParser(registry: registry)

    do {
        _ = try parser.reparse(
            "true",
            using: "source.simple",
            from: SyntaxLineState(
                line: 1,
                nextUTF16Offset: 0,
                contexts: [
                    SyntaxContextSnapshot(
                        grammarScopeName: ScopeName(rawValue: "missing.scope"),
                        ruleID: 99,
                        endPattern: "x",
                        delimiterScopes: [],
                        contentScopes: []
                    )
                ]
            )
        )
        Issue.record("Expected reparse to fail when the saved grammar is missing.")
    } catch let error as SyntaxKitError {
        #expect(error.description.contains("Missing grammar"))
    }

    do {
        _ = try parser.reparse(
            "true",
            using: "source.simple",
            from: SyntaxLineState(
                line: 1,
                nextUTF16Offset: 0,
                contexts: [
                    SyntaxContextSnapshot(
                        grammarScopeName: ScopeName(rawValue: "source.simple"),
                        ruleID: 999,
                        endPattern: "x",
                        delimiterScopes: [],
                        contentScopes: []
                    )
                ]
            )
        )
        Issue.record("Expected reparse to fail when the saved rule is missing.")
    } catch let error as SyntaxKitError {
        #expect(error.description.contains("Missing rule"))
    }
}

@Test func incrementalParsingCoversDefaultGrammarAndRuleLookupPaths() throws {
    let parserWithoutDefault = SyntaxParser(registry: GrammarRegistry())
    do {
        _ = try parserWithoutDefault.reparse("value", from: .initial)
        Issue.record("Expected reparse without a grammar to fail.")
    } catch let error as SyntaxKitError {
        #expect(error.description.contains("No grammar provided"))
    }

    let iniGrammar = try GrammarLoader.load(from: URL(fileURLWithPath: "/Users/gmao/code/SyntaxKit/languages/INI.tmLanguage.json"))
    let registry = GrammarRegistry(grammars: [iniGrammar])
    let parser = SyntaxParser(registry: registry)

    let topRule = try #require(iniGrammar.patterns.first)
    let topState = SyntaxLineState(
        line: 1,
        nextUTF16Offset: 0,
        contexts: [
            SyntaxContextSnapshot(
                grammarScopeName: iniGrammar.scopeName,
                ruleID: topRule.id,
                endPattern: topRule.end ?? "(?!\\G)",
                delimiterScopes: ["source.ini"],
                contentScopes: ["source.ini"]
            )
        ]
    )
    let topReparse = try parser.reparse("# note\n", using: "source.ini", from: topState)
    #expect(topReparse.parseResult.spans.isEmpty == false)

    let nestedRule = try #require(topRule.patterns.first)
    let nestedState = SyntaxLineState(
        line: 1,
        nextUTF16Offset: 0,
        contexts: [
            SyntaxContextSnapshot(
                grammarScopeName: iniGrammar.scopeName,
                ruleID: nestedRule.id,
                endPattern: nestedRule.end ?? "\\n",
                delimiterScopes: ["source.ini", "comment.line.number-sign.ini"],
                contentScopes: ["source.ini", "comment.line.number-sign.ini"]
            )
        ]
    )
    let nestedReparse = try parser.reparse(" comment\n", using: "source.ini", from: nestedState)
    #expect(nestedReparse.parseResult.spans.isEmpty == false)
}

@Test func parserRejectsMissingDefaultGrammar() throws {
    let parser = SyntaxParser(registry: GrammarRegistry())
    do {
        _ = try parser.parse("abc")
        Issue.record("Expected parse without a grammar to fail.")
    } catch let error as SyntaxKitError {
        #expect(error.description.contains("No grammar provided"))
    }
}

@Test func parserSupportsBackreferencesAndContentNames() throws {
    let grammar = try GrammarLoader.load(data: Data(backreferenceGrammar.utf8))
    let registry = GrammarRegistry(grammars: [grammar])
    let parser = SyntaxParser(registry: registry)
    let result = try parser.parse("<tag>inner</tag>", using: "text.backref")
    #expect(result.spans.contains(where: { $0.scopes.contains("meta.tag.backref") }))
    #expect(result.spans.contains(where: { $0.scopes.contains("meta.tag.content.backref") }))
    #expect(result.spans.contains(where: { $0.scopes.contains("punctuation.definition.tag.begin.backref") }))
}

@Test func parserSupportsZeroWidthMatchRules() throws {
    let grammar = try GrammarLoader.load(data: Data(zeroWidthMatchGrammar.utf8))
    let registry = GrammarRegistry(grammars: [grammar])
    let parser = SyntaxParser(registry: registry)
    let result = try parser.parse("abc", using: "source.zero")
    #expect(result.scopeName.rawValue == "source.zero")
}

@Test func supportsExternalGrammarInclude() throws {
    let host = try GrammarLoader.load(data: Data(hostGrammar.utf8))
    let embedded = try GrammarLoader.load(data: Data(embeddedGrammar.utf8))
    let registry = GrammarRegistry(grammars: [host, embedded])
    let parser = SyntaxParser(registry: registry)
    let result = try parser.parse("{{abc}}", using: "text.host")
    #expect(result.spans.contains(where: { $0.scopes.contains("meta.embedded.host") }))
    #expect(result.spans.contains(where: { $0.scopes.contains("variable.embedded") }))
}

@Test func publicTypesCoverInitializersAndDescriptions() throws {
    let scope = ScopeName(rawValue: "source.example")
    #expect(scope.description == "source.example")

    let firstCapture = Capture(index: 1, name: "b")
    let secondCapture = Capture(index: 2, name: "a")
    #expect(firstCapture.index < secondCapture.index)

    let diagnostic = Diagnostic(severity: .warning, message: "warning", line: 2, column: 3)
    #expect(diagnostic.line == 2)
    #expect(Diagnostic(severity: .error, message: "error").severity == .error)

    #expect(IncludeReference(rawValue: "$self") == .self)
    #expect(IncludeReference(rawValue: "#repo") == .repository("repo"))
    #expect(IncludeReference(rawValue: "source.external") == .external(ScopeName(rawValue: "source.external")))

    let compiled = CompiledRegex(pattern: "x") { string, offset in
        string == "x" && offset == 0 ? RegexMatch(range: NSRange(location: 0, length: 1), captures: [0: NSRange(location: 0, length: 1)]) : nil
    }
    #expect(compiled.pattern == "x")
    #expect(compiled.firstMatch(in: "x", from: 0)?.range == NSRange(location: 0, length: 1))

    let engine = DefaultRegexEngine()
    #expect(engine.name == "default")
    let regex = try engine.compile(pattern: "a+")
    #expect(regex.firstMatch(in: "caa", from: 0)?.range == NSRange(location: 1, length: 2))
    let beginMatch = RegexMatch(range: NSRange(location: 0, length: 1), captures: [1: NSRange(location: 0, length: 1)])
    #expect(engine.substituteBackreferences(in: #"\1"#, using: beginMatch, line: "a") == "a")

    #expect(SyntaxKitError.cli("hello").description == "hello")
    #expect("one two".syntaxKitScopeComponents == ["one", "two"])
    #expect(#"\\1"#.syntaxKitContainsBackreference)
    #expect(!"plain".syntaxKitContainsBackreference)
}

@Test func customRegexEngineCanBeInjectedIntoParsingFlows() throws {
    let grammar = try GrammarLoader.load(data: Data(simpleCustomEngineGrammar.utf8))
    let engine = RecordingRegexEngine()
    let registry = GrammarRegistry(grammars: [grammar], regexEngine: engine)
    let parser = SyntaxParser(registry: registry)

    let result = try parser.parse("x", using: "source.custom-engine")

    #expect(result.spans.contains(where: { $0.scopes.contains("constant.custom-engine") }))
    #expect(engine.compiledPatterns.contains("x"))
}

@Test func customRegexEngineUsesProtocolBackreferenceDefaultAndPropagatesFailures() throws {
    let beginMatch = RegexMatch(range: NSRange(location: 0, length: 1), captures: [1: NSRange(location: 0, length: 1)])
    let engine = RecordingRegexEngine()
    #expect(engine.substituteBackreferences(in: #"\1"#, using: beginMatch, line: "a") == "a")

    let grammar = try GrammarLoader.load(data: Data(simpleCustomEngineGrammar.utf8))
    let failingRegistry = GrammarRegistry(grammars: [grammar], regexEngine: FailingRegexEngine())
    do {
        _ = try failingRegistry.resolve(scopeName: "source.custom-engine")
        Issue.record("Expected custom regex engine failure to propagate.")
    } catch let error as SyntaxKitError {
        #expect(error.description.contains("custom failure"))
    }
}

@Test func defaultRegexEngineCompatibilityShimRejectsUnsupportedOnigurumaConstructs() throws {
    let engine = DefaultRegexEngine()
    do {
        _ = try engine.compile(pattern: #"\g<1>"#)
        Issue.record("Expected unsupported Oniguruma construct to be rejected.")
    } catch let error as SyntaxKitError {
        #expect(error.description.contains("unsupported by engine 'default'"))
    }

    let compiled = try engine.compile(pattern: "a+")
    #expect(compiled.firstMatch(in: "aa", from: 10) == nil)
}

@Test func foundationRegexHelpersCoverCachingAndMatching() throws {
    let cache = FoundationRegexCache()
    let regex = try cache.regex(for: "a+", engineName: "test-foundation")
    let cachedRegex = try cache.regex(for: "a+", engineName: "test-foundation")
    #expect(regex == cachedRegex)

    let compiled = CompiledRegex(pattern: "a+") { string, offset in
        foundationFirstMatch(regex: regex, in: string, from: offset)
    }
    #expect(compiled.firstMatch(in: "caa", from: 0)?.range == NSRange(location: 1, length: 2))
    #expect(compiled.firstMatch(in: "bbb", from: 0) == nil)
    #expect(compiled.firstMatch(in: "bbb", from: 10) == nil)

    do {
        _ = try cache.regex(for: "(", engineName: "test-foundation")
        Issue.record("Expected Foundation regex compilation to fail.")
    } catch let error as SyntaxKitError {
        #expect(error.description.contains("test-foundation"))
    }

    let backend = FoundationRegexBackend()
    let backendCompiled = try backend.compile(pattern: "a+")
    #expect(backendCompiled.firstMatch(in: "caa", from: 0)?.range == NSRange(location: 1, length: 2))
}

@Test func regexCompatibilityShimReportsAggregatedBackendFailures() throws {
    let shim = TextMateRegexCompatibilityShim(backends: [AlwaysFailingBuiltinRegexBackend(name: "fail-one"), AlwaysFailingBuiltinRegexBackend(name: "fail-two")], engineName: "test-default")
    do {
        _ = try shim.compile(pattern: "abc")
        Issue.record("Expected aggregated backend failure.")
    } catch let error as SyntaxKitError {
        #expect(error.description.contains("test-default"))
        #expect(error.description.contains("fail-one"))
        #expect(error.description.contains("fail-two"))
    }
}

@Test func regexCompatibilityShimRewritesSingleQuotedNamedForms() throws {
    let shim = TextMateRegexCompatibilityShim(backends: [FoundationRegexBackend()], engineName: "test-default")
    let compiled = try shim.compile(pattern: #"(?'word'a)\k'word'"#)
    let match = try #require(compiled.firstMatch(in: "aa", from: 0))
    #expect(match.range == NSRange(location: 0, length: 2))
    #expect(#"(?'word'a)"#.syntaxKitRewritingSingleQuotedNamedGroups() == #"(?<word>a)"#)
    #expect(#"\k'word'"#.syntaxKitRewritingSingleQuotedNamedBackreferences() == #"\k<word>"#)
}

@Test func regexCompatibilityShimRejectsKnownSemanticMismatches() throws {
    let shim = TextMateRegexCompatibilityShim(backends: [FoundationRegexBackend()], engineName: "test-default")

    do {
        _ = try shim.compile(pattern: #"\k<word+1>"#)
        Issue.record("Expected relative named backreference rejection.")
    } catch let error as SyntaxKitError {
        #expect(error.description.contains("relative named backreferences"))
    }

    do {
        _ = try shim.compile(pattern: #"(?m)abc"#)
        Issue.record("Expected Oniguruma Ruby multiline semantic rejection.")
    } catch let error as SyntaxKitError {
        #expect(error.description.contains("Oniguruma Ruby-style '(?m)' semantics"))
    }

    #expect(#"\k<word+1>"#.syntaxKitUsesRelativeNamedBackreference)
    #expect(#"(?m)abc"#.syntaxKitUsesOnigurumaRubyMultilineOption)
}

@Test func defaultRegexEngineKeepsBuiltinBackendsBehaviorAligned() throws {
    let pattern = #"(?<word>a+)(b)"#
    let source = "zaab"
    let foundation = try FoundationRegexBackend().compile(pattern: pattern)
    let foundationMatch = try #require(foundation.firstMatch(in: source, from: 0))
    #expect(foundationMatch.range == NSRange(location: 1, length: 3))
    #expect(foundationMatch.captures[1] == NSRange(location: 1, length: 2))
    #expect(foundationMatch.captures[2] == NSRange(location: 3, length: 1))

    if #available(macOS 13, iOS 16, tvOS 16, watchOS 9, *) {
        let swiftNative = try SwiftNativeRegexBackend().compile(pattern: pattern)
        let swiftNativeMatch = try #require(swiftNative.firstMatch(in: source, from: 0))
        #expect(swiftNativeMatch == foundationMatch)
    }
}

@Test func parserRejectsMissingExternalGrammarAtParseTime() throws {
    let grammar = try GrammarLoader.load(data: Data(hostGrammar.utf8))
    let registry = GrammarRegistry(grammars: [grammar])
    let parser = SyntaxParser(registry: registry)
    do {
        _ = try parser.parse("{{abc}}", using: "text.host")
        Issue.record("Expected parsing with unresolved external grammar to fail.")
    } catch let error as SyntaxKitError {
        #expect(error.description.contains("unknown external grammar"))
    }
}

@Test func parserCoversBypassedResolutionFailures() throws {
    let unresolvedRepositoryGrammar = Grammar(
        name: nil,
        scopeName: ScopeName(rawValue: "source.manualrepo"),
        fileTypes: [],
        firstLineMatch: nil,
        foldingStartMarker: nil,
        foldingStopMarker: nil,
        patterns: [
            Rule(
                id: 1,
                name: nil,
                contentName: nil,
                match: nil,
                begin: nil,
                end: nil,
                captures: [],
                beginCaptures: [],
                endCaptures: [],
                include: "#missing",
                patterns: []
            )
        ],
        repository: [:]
    )
    let unresolvedExternalGrammar = Grammar(
        name: nil,
        scopeName: ScopeName(rawValue: "source.manualexternal"),
        fileTypes: [],
        firstLineMatch: nil,
        foldingStartMarker: nil,
        foldingStopMarker: nil,
        patterns: [
            Rule(
                id: 2,
                name: nil,
                contentName: nil,
                match: nil,
                begin: nil,
                end: nil,
                captures: [],
                beginCaptures: [],
                endCaptures: [],
                include: "source.missing",
                patterns: []
            )
        ],
        repository: [:]
    )
    let registry = GrammarRegistry()

    do {
        let parser = SyntaxParser(resolvedGrammar: ResolvedGrammar(scopeName: unresolvedRepositoryGrammar.scopeName, grammar: unresolvedRepositoryGrammar), registry: registry)
        _ = try parser.parse("x")
        Issue.record("Expected unresolved repository include to fail during parsing.")
    } catch let error as SyntaxKitError {
        #expect(error.description.contains("Missing repository rule"))
    }

    do {
        let parser = SyntaxParser(resolvedGrammar: ResolvedGrammar(scopeName: unresolvedExternalGrammar.scopeName, grammar: unresolvedExternalGrammar), registry: registry)
        _ = try parser.parse("x")
        Issue.record("Expected unresolved external include to fail during parsing.")
    } catch let error as SyntaxKitError {
        #expect(error.description.contains("Missing external grammar"))
    }
}

@Test func selfIncludeGrammarParsesAndRegexHelpersCoverFallbacks() throws {
    let grammar = try GrammarLoader.load(data: Data(selfIncludeGrammar.utf8))
    let registry = GrammarRegistry(grammars: [grammar])
    let parser = SyntaxParser(registry: registry)
    let spans = try parser.tokenize("x", using: "source.self")
    #expect(spans.contains(where: { $0.scopes.contains("constant.self") }))

    let beginMatch = RegexMatch(range: NSRange(location: 0, length: 1), captures: [:])
    let substituted = defaultSubstituteBackreferences(pattern: #"\\1"#, using: beginMatch, in: "a")
    #expect(substituted == #"\\1"#)
}

@Test func parserHandlesMissingCaptureRanges() throws {
    let grammar = try GrammarLoader.load(data: Data(missingCaptureGrammar.utf8))
    let registry = GrammarRegistry(grammars: [grammar])
    let parser = SyntaxParser(registry: registry)
    let result = try parser.parse("a", using: "source.capture")
    #expect(result.spans.contains(where: { $0.scopes.contains("meta.capture.test") }))
}

@Test func parserSkipsRepeatedContainerRules() throws {
    let containerRule = Rule(
        id: 77,
        name: nil,
        contentName: nil,
        match: nil,
        begin: nil,
        end: nil,
        captures: [],
        beginCaptures: [],
        endCaptures: [],
        include: nil,
        patterns: [
            Rule(
                id: 78,
                name: "constant.container",
                contentName: nil,
                match: "z",
                begin: nil,
                end: nil,
                captures: [],
                beginCaptures: [],
                endCaptures: [],
                include: nil,
                patterns: []
            )
        ]
    )
    let grammar = Grammar(
        name: nil,
        scopeName: ScopeName(rawValue: "source.container"),
        fileTypes: [],
        firstLineMatch: nil,
        foldingStartMarker: nil,
        foldingStopMarker: nil,
        patterns: [containerRule, containerRule],
        repository: [:]
    )
    let registry = GrammarRegistry()
    let parser = SyntaxParser(resolvedGrammar: ResolvedGrammar(scopeName: grammar.scopeName, grammar: grammar), registry: registry)
    let result = try parser.parse("z")
    #expect(result.spans.contains(where: { $0.scopes.contains("constant.container") }))
}

private func expectSyntaxKitError(plist: String, containing needle: String) throws {
    do {
        _ = try GrammarLoader.load(data: Data(plist.utf8))
        Issue.record("Expected GrammarLoader to throw.")
    } catch let error as SyntaxKitError {
        #expect(error.description.contains(needle))
    }
}

private final class RecordingRegexEngine: RegexEngine, @unchecked Sendable {
    let name = "recording"

    private var storage: [String] = []
    private let lock = NSLock()

    var compiledPatterns: [String] {
        lock.lock()
        defer { lock.unlock() }
        return storage
    }

    func compile(pattern: String) throws -> CompiledRegex {
        lock.lock()
        storage.append(pattern)
        lock.unlock()

        return CompiledRegex(pattern: pattern) { string, offset in
            let nsString = string as NSString
            let range = nsString.range(of: pattern, options: [], range: NSRange(location: offset, length: nsString.length - offset))
            guard range.location != NSNotFound else {
                return nil
            }
            return RegexMatch(range: range, captures: [0: range])
        }
    }
}

private struct FailingRegexEngine: RegexEngine {
    let name = "failing"

    func compile(pattern: String) throws -> CompiledRegex {
        throw SyntaxKitError.regexCompilation("custom failure for \(pattern)")
    }
}

private struct AlwaysFailingBuiltinRegexBackend: BuiltinRegexBackend {
    let name: String

    func compile(pattern: String) throws -> CompiledRegex {
        throw SyntaxKitError.regexCompilation("forced failure for \(pattern)")
    }
}

private func expectThemeError(plist: String, containing needle: String) throws {
    do {
        _ = try ThemeLoader.load(data: Data(plist.utf8))
        Issue.record("Expected ThemeLoader to throw.")
    } catch let error as SyntaxKitError {
        #expect(error.description.contains(needle))
    }
}

private func plist(ruleBody: String) -> String {
    """
    <?xml version="1.0" encoding="UTF-8"?>
    <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
    <plist version="1.0">
    <dict>
      <key>scopeName</key><string>source.generated</string>
      \(ruleBody)
    </dict>
    </plist>
    """
}

private let simpleNumbersGrammar = """
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>scopeName</key><string>source.simple</string>
  <key>patterns</key>
  <array>
    <dict><key>include</key><string>#value</string></dict>
  </array>
  <key>repository</key>
  <dict>
    <key>value</key>
    <dict>
      <key>patterns</key>
      <array>
        <dict>
          <key>match</key><string>\\b\\d+\\b</string>
          <key>name</key><string>constant.numeric.simple</string>
        </dict>
        <dict>
          <key>match</key><string>\\b(?:true|false)\\b</string>
          <key>name</key><string>constant.language.simple</string>
        </dict>
      </array>
    </dict>
  </dict>
</dict>
</plist>
"""

private let simpleCustomEngineGrammar = """
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>scopeName</key><string>source.custom-engine</string>
  <key>patterns</key>
  <array>
    <dict>
      <key>match</key><string>x</string>
      <key>name</key><string>constant.custom-engine</string>
    </dict>
  </array>
</dict>
</plist>
"""

private let invalidRepositoryGrammar = """
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>scopeName</key><string>source.invalid</string>
  <key>patterns</key>
  <array>
    <dict><key>include</key><string>#missing</string></dict>
  </array>
</dict>
</plist>
"""

private let embeddedGrammar = """
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>scopeName</key><string>source.embedded</string>
  <key>patterns</key>
  <array>
    <dict>
      <key>match</key><string>[a-z]+</string>
      <key>name</key><string>variable.embedded</string>
    </dict>
  </array>
</dict>
</plist>
"""

private let hostGrammar = """
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>scopeName</key><string>text.host</string>
  <key>patterns</key>
  <array>
    <dict>
      <key>begin</key><string>\\{\\{</string>
      <key>end</key><string>\\}\\}</string>
      <key>name</key><string>meta.embedded.host</string>
      <key>patterns</key>
      <array>
        <dict><key>include</key><string>source.embedded</string></dict>
      </array>
    </dict>
  </array>
</dict>
</plist>
"""

private let selfIncludeGrammar = """
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>scopeName</key><string>source.self</string>
  <key>patterns</key>
  <array>
    <dict><key>include</key><string>$self</string></dict>
    <dict><key>match</key><string>x</string><key>name</key><string>constant.self</string></dict>
  </array>
</dict>
</plist>
"""

private let backreferenceGrammar = """
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>scopeName</key><string>text.backref</string>
  <key>patterns</key>
  <array>
    <dict>
      <key>begin</key><string>&lt;([A-Za-z]+)&gt;</string>
      <key>end</key><string>&lt;/\\1&gt;</string>
      <key>name</key><string>meta.tag.backref</string>
      <key>contentName</key><string>meta.tag.content.backref</string>
      <key>beginCaptures</key>
      <dict>
        <key>0</key><dict><key>name</key><string>punctuation.definition.tag.begin.backref</string></dict>
      </dict>
      <key>endCaptures</key>
      <dict>
        <key>0</key><dict><key>name</key><string>punctuation.definition.tag.end.backref</string></dict>
      </dict>
    </dict>
  </array>
</dict>
</plist>
"""

private let zeroWidthMatchGrammar = """
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>scopeName</key><string>source.zero</string>
  <key>patterns</key>
  <array>
    <dict>
      <key>match</key><string>(?=a)</string>
      <key>name</key><string>keyword.zero.match</string>
    </dict>
  </array>
</dict>
</plist>
"""

private let sampleTheme = """
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>name</key><string>Sample</string>
  <key>settings</key>
  <array>
    <dict>
      <key>settings</key>
      <dict>
        <key>background</key><string>#000000</string>
        <key>foreground</key><string>#FFFFFF</string>
      </dict>
    </dict>
    <dict>
      <key>name</key><string>Multi Scope</string>
      <key>scope</key><string>comment, string.quoted</string>
      <key>settings</key>
      <dict>
        <key>foreground</key><string>#112233</string>
        <key>background</key><string>#445566</string>
        <key>fontStyle</key><string>bold italic underline</string>
      </dict>
    </dict>
  </array>
</dict>
</plist>
"""

private let themeWithoutScope = """
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>name</key><string>No Scope</string>
  <key>settings</key>
  <array>
    <dict><key>settings</key><dict/></dict>
    <dict>
      <key>name</key><string>Fallback</string>
      <key>settings</key>
      <dict>
        <key>foreground</key><string>#010203</string>
      </dict>
    </dict>
  </array>
</dict>
</plist>
"""

private let specificityTheme = """
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>name</key><string>Specificity</string>
  <key>settings</key>
  <array>
    <dict><key>settings</key><dict><key>foreground</key><string>#000000</string></dict></dict>
    <dict><key>scope</key><string>constant</string><key>settings</key><dict><key>foreground</key><string>#101010</string></dict></dict>
    <dict><key>scope</key><string>constant.numeric</string><key>settings</key><dict><key>foreground</key><string>#202020</string></dict></dict>
  </array>
</dict>
</plist>
"""

private let equalSpecificityTheme = """
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>name</key><string>Equal</string>
  <key>settings</key>
  <array>
    <dict><key>settings</key><dict><key>foreground</key><string>#000000</string></dict></dict>
    <dict><key>scope</key><string>keyword</string><key>settings</key><dict><key>foreground</key><string>#111111</string></dict></dict>
    <dict><key>scope</key><string>keyword</string><key>settings</key><dict><key>foreground</key><string>#222222</string></dict></dict>
  </array>
</dict>
</plist>
"""

private let simpleHighlightTheme = """
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>name</key><string>Simple Highlight</string>
  <key>settings</key>
  <array>
    <dict><key>settings</key><dict><key>foreground</key><string>#FFFFFF</string><key>background</key><string>#000000</string></dict></dict>
    <dict><key>scope</key><string>constant.numeric</string><key>settings</key><dict><key>foreground</key><string>#101010</string></dict></dict>
    <dict><key>scope</key><string>constant.language</string><key>settings</key><dict><key>foreground</key><string>#202020</string></dict></dict>
  </array>
</dict>
</plist>
"""

private let missingCaptureGrammar = """
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>scopeName</key><string>source.capture</string>
  <key>patterns</key>
  <array>
    <dict>
      <key>match</key><string>a</string>
      <key>name</key><string>meta.capture.test</string>
      <key>captures</key>
      <dict>
        <key>1</key><dict><key>name</key><string>missing.capture.scope</string></dict>
      </dict>
    </dict>
  </array>
</dict>
</plist>
"""
