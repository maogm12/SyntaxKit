import Foundation
import Testing
@testable import SyntaxKit

@Test func loadsJSONFixtureGrammar() throws {
    let fixtureURL = URL(fileURLWithPath: "/Users/gmao/code/SyntaxKit/languages/JSON.tmLanguage")
    let grammar = try GrammarLoader.load(from: fixtureURL)
    #expect(grammar.scopeName.rawValue == "source.json")
    #expect(grammar.repository["array"] != nil)
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
    try expectSyntaxKitError(plist: plist, containing: "Top-level grammar plist")
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

@Test func parserSupportsResolvedGrammarInitializerAndEmptyText() throws {
    let grammar = try GrammarLoader.load(data: Data(simpleNumbersGrammar.utf8))
    let registry = GrammarRegistry(grammars: [grammar])
    let resolved = try registry.resolve(scopeName: "source.simple")
    let parser = SyntaxParser(resolvedGrammar: resolved, registry: registry)
    let result = try parser.parse("")
    #expect(result.scopeName.rawValue == "source.simple")
    #expect(result.spans.isEmpty)
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

    let diagnostic = Diagnostic(severity: .warning, message: "warning", line: 2, column: 3)
    #expect(diagnostic.line == 2)
    #expect(Diagnostic(severity: .error, message: "error").severity == .error)

    #expect(IncludeReference(rawValue: "$self") == .self)
    #expect(IncludeReference(rawValue: "#repo") == .repository("repo"))
    #expect(IncludeReference(rawValue: "source.external") == .external(ScopeName(rawValue: "source.external")))

    #expect(SyntaxKitError.cli("hello").description == "hello")
    #expect("one two".syntaxKitScopeComponents == ["one", "two"])
    #expect(#"\\1"#.syntaxKitContainsBackreference)
    #expect(!"plain".syntaxKitContainsBackreference)
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
    let substituted = substituteBackreferences(pattern: #"\\1"#, using: beginMatch, in: "a")
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
