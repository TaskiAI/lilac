import SwiftUI

/// The writer's "current focus" — a short, editable list of intentions shown as
/// chips on the home screen. Persisted in `UserDefaults` as a JSON string so it
/// survives launches without needing its own `@Model`. These will later be
/// suggested by the AI analyzers; for now the writer curates them by hand.
enum FocusAreas {
    static let storageKey = "home.focusAreas"

    static let defaults = ["Reduce anxiety", "Build self-trust", "Rest & recharge"]

    static func decode(_ raw: String) -> [String] {
        guard let data = raw.data(using: .utf8),
              let list = try? JSONDecoder().decode([String].self, from: data) else {
            return defaults
        }
        return list
    }

    static func encode(_ list: [String]) -> String {
        guard let data = try? JSONEncoder().encode(list),
              let string = String(data: data, encoding: .utf8) else {
            return ""
        }
        return string
    }

    /// A gentle icon guess from the focus text, so the chips carry meaning
    /// without the writer having to pick symbols.
    static func icon(for text: String) -> String {
        let lower = text.lowercased()
        switch true {
        case lower.contains("anx"), lower.contains("calm"), lower.contains("stress"):
            return "cloud"
        case lower.contains("trust"), lower.contains("self"), lower.contains("love"), lower.contains("confiden"):
            return "heart"
        case lower.contains("rest"), lower.contains("recharge"), lower.contains("sleep"), lower.contains("relax"):
            return "moon"
        case lower.contains("focus"), lower.contains("clar"), lower.contains("mind"):
            return "sparkles"
        case lower.contains("grow"), lower.contains("habit"):
            return "leaf"
        case lower.contains("grat"), lower.contains("thank"):
            return "sun.max"
        default:
            return "circle.hexagongrid"
        }
    }
}

/// A small sheet to add, rename, and remove focus chips. Writes back through the
/// `@AppStorage` binding the home screen owns.
struct FocusEditorView: View {
    @Binding var raw: String
    @Environment(\.dismiss) private var dismiss

    @State private var items: [String] = []
    @State private var newItem = ""

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                        HStack(spacing: 12) {
                            Image(systemName: FocusAreas.icon(for: item))
                                .foregroundStyle(Color.homeAccent)
                                .frame(width: 22)
                            Text(item)
                        }
                    }
                    .onDelete { items.remove(atOffsets: $0) }
                    .onMove { items.move(fromOffsets: $0, toOffset: $1) }
                } header: {
                    Text("Your current focus")
                } footer: {
                    Text("These guide the prompts and activities Lilac suggests.")
                }

                Section("Add a focus") {
                    HStack {
                        TextField("e.g. Reduce anxiety", text: $newItem)
                            .onSubmit(add)
                        Button(action: add) {
                            Image(systemName: "plus.circle.fill")
                                .foregroundStyle(Color.homeAccent)
                        }
                        .disabled(trimmed.isEmpty)
                    }
                }
            }
            .navigationTitle("Edit focus")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { save() }
                }
                ToolbarItem(placement: .topBarLeading) { EditButton() }
            }
        }
        .onAppear { items = FocusAreas.decode(raw) }
        .tint(.homeAccent)
    }

    private var trimmed: String {
        newItem.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func add() {
        guard !trimmed.isEmpty else { return }
        items.append(trimmed)
        newItem = ""
    }

    private func save() {
        raw = FocusAreas.encode(items)
        dismiss()
    }
}
