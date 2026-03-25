import SwiftUI
import SyntaxKit

struct ContentView: View {
    @StateObject private var model = DemoModel()
    @State private var showingSettings = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                SyntaxTextView(
                    text: $model.sourceText,
                    attributedText: model.preview,
                    backgroundColor: model.previewBackgroundColor,
                    onTextChange: { model.updateSource($0) }
                )
                .edgesIgnoringSafeArea(.bottom)

                VStack(alignment: .leading, spacing: 4) {
                    Divider()
                    HStack {
                        Text(model.timingText)
                            .font(.caption2)
                            .monospacedDigit()
                        Spacer()
                        Text(model.statusText)
                            .font(.caption2)
                            .foregroundColor(model.errorMessage == nil ? .secondary : .red)
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 4)
                }
                .background(Color(uiColor: .systemBackground))
            }
            .navigationTitle("SyntaxKit Demo")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showingSettings = true
                    } label: {
                        Image(systemName: "gear")
                    }
                }
            }
            .sheet(isPresented: $showingSettings) {
                SettingsView(model: model)
            }
            .task {
                await model.load()
            }
        }
    }
}

struct SettingsView: View {
    @ObservedObject var model: DemoModel
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section("Language") {
                    Picker("Grammar", selection: Binding(
                        get: { DemoAsset.allCases.first { $0.displayName == model.grammarName } ?? .json },
                        set: { try? model.loadBundledGrammar($0) }
                    )) {
                        ForEach(DemoAsset.allCases) { asset in
                            Text(asset.displayName).tag(asset)
                        }
                    }
                }

                Section("Appearance") {
                    Picker("Theme", selection: Binding(
                        get: { DemoThemeAsset.allCases.first { $0.displayName == model.themeName } ?? .dark },
                        set: { try? model.loadBundledTheme($0) }
                    )) {
                        ForEach(DemoThemeAsset.allCases) { asset in
                            Text(asset.displayName).tag(asset)
                        }
                    }
                }

                if let error = model.errorMessage {
                    Section("Errors") {
                        Text(error)
                            .font(.caption)
                            .foregroundColor(.red)
                    }
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents([.medium])
    }
}
