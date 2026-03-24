import SwiftUI

struct ContentView: View {
    @StateObject private var model = DemoModel()

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            HSplitView {
                editorPane
                previewPane
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .task {
            await model.load()
        }
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                Text("SyntaxKit Demo")
                    .font(.system(size: 24, weight: .semibold, design: .rounded))
                Text("Edit JSON on the left. The preview, scopes, and line-state snapshots update using the local SyntaxKit library.")
                    .foregroundStyle(.secondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 6) {
                Label(model.statusText, systemImage: model.errorMessage == nil ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                    .foregroundStyle(model.errorMessage == nil ? .green : .orange)
                Text("Spans: \(model.themedSpans.count)  |  Line States: \(model.lineStates.count)")
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(20)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private var editorPane: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Input")
                .font(.headline)
            TextEditor(text: Binding(
                get: { model.sourceText },
                set: { model.updateSource($0) }
            ))
                .font(.system(size: 14, weight: .regular, design: .monospaced))
                .scrollContentBackground(.hidden)
                .background(Color(nsColor: .textBackgroundColor))
                .border(Color.secondary.opacity(0.2))
            if let errorMessage = model.errorMessage {
                Text(errorMessage)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(.orange)
            } else {
                Text("Theme: Monokai  |  Grammar: source.json")
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(16)
        .frame(minWidth: 420)
    }

    private var previewPane: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Preview")
                .font(.headline)
            HighlightingTextView(attributedString: model.preview)
                .border(Color.secondary.opacity(0.2))
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            Text("Scopes")
                .font(.headline)
            List(model.themedSpans.prefix(20), id: \.startUTF16) { span in
                VStack(alignment: .leading, spacing: 4) {
                    Text("\(span.startUTF16)-\(span.endUTF16) @\(span.line):\(span.column)")
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(.secondary)
                    Text(span.scopes.joined(separator: " "))
                        .font(.system(.caption, design: .monospaced))
                        .lineLimit(2)
                }
            }
            .frame(minHeight: 220)
        }
        .padding(16)
        .frame(minWidth: 520)
    }
}
