import SwiftUI

/// Rewind settings, exposed from the activity section: master switch, frequency,
/// depth, and the muted-theme list. Turning the feature off stops the pipeline
/// (and the DeepSeek calls) entirely — see `RewindEngine.run`.
struct RewindSettingsPanel: View {
    let engine: RewindEngine
    @Environment(\.dismiss) private var dismiss
    @State private var settings: RewindSettings?

    var body: some View {
        NavigationStack {
            Group {
                if let settings {
                    RewindSettingsForm(settings: settings)
                } else {
                    ProgressView()
                }
            }
            .navigationTitle("Rewind")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .task { settings = engine.settings() }
        }
    }
}

private struct RewindSettingsForm: View {
    @Bindable var settings: RewindSettings

    var body: some View {
        Form {
            Section("Surfacing") {
                Toggle("Enable Rewind", isOn: $settings.enabled)
                Picker("Frequency", selection: $settings.frequency) {
                    ForEach(RewindFrequency.allCases) { Text($0.label).tag($0) }
                }
                Picker("Depth", selection: $settings.intensity) {
                    ForEach(RewindIntensity.allCases) { Text($0.label).tag($0) }
                }
                .disabled(!settings.enabled)
            }

            if !settings.mutedThemes.isEmpty {
                Section("Muted themes") {
                    ForEach(settings.mutedThemes, id: \.self) { theme in
                        Text(theme.replacingOccurrences(of: "-", with: " "))
                    }
                    .onDelete(perform: unmute)
                } footer: {
                    Text("Swipe to unmute. Muted themes are never resurfaced.")
                }
            }

            Section {
                EmptyView()
            } footer: {
                Text("Rewind sends entry text to DeepSeek to screen for safety and to write short bridge sentences. Turn Rewind off to stop this.")
            }
        }
    }

    private func unmute(at offsets: IndexSet) {
        var muted = settings.mutedThemes
        muted.remove(atOffsets: offsets)
        settings.mutedThemes = muted
    }
}
