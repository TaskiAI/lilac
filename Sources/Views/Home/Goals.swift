import SwiftUI

/// A tracked intention shown on the home "Goals" card, with simple progress
/// (current / target). Persisted as JSON in `UserDefaults` (like `FocusAreas`),
/// seeded with a starter set; editable in `GoalsEditorView`.
struct Goal: Codable, Identifiable, Hashable {
    var id: UUID
    var title: String
    var icon: String
    var current: Int
    var target: Int

    init(id: UUID = UUID(), title: String, icon: String, current: Int = 0, target: Int = 7) {
        self.id = id
        self.title = title
        self.icon = icon
        self.current = current
        self.target = target
    }

    var fraction: Double {
        guard target > 0 else { return 0 }
        return min(1, Double(current) / Double(target))
    }
}

enum Goals {
    static let storageKey = "home.goals"

    static let defaults: [Goal] = [
        Goal(title: "Practice gratitude daily", icon: "heart", current: 4, target: 7),
        Goal(title: "Manage anxiety", icon: "brain.head.profile", current: 2, target: 7),
        Goal(title: "Journal 5x this week", icon: "book", current: 4, target: 5)
    ]

    static func decode(_ raw: String) -> [Goal] {
        guard let data = raw.data(using: .utf8),
              let list = try? JSONDecoder().decode([Goal].self, from: data) else {
            return defaults
        }
        return list
    }

    static func encode(_ list: [Goal]) -> String {
        guard let data = try? JSONEncoder().encode(list),
              let string = String(data: data, encoding: .utf8) else { return "" }
        return string
    }

    /// A gentle icon guess for a new goal from its text.
    static func icon(for text: String) -> String {
        let lower = text.lowercased()
        switch true {
        case lower.contains("grat"), lower.contains("thank"): return "heart"
        case lower.contains("anx"), lower.contains("calm"), lower.contains("stress"): return "brain.head.profile"
        case lower.contains("journal"), lower.contains("write"), lower.contains("read"): return "book"
        case lower.contains("sleep"), lower.contains("rest"): return "moon"
        case lower.contains("move"), lower.contains("walk"), lower.contains("exercise"): return "figure.walk"
        default: return "target"
        }
    }
}

/// Edit the home goals: rename, adjust progress/target, add, remove.
struct GoalsEditorView: View {
    @Binding var raw: String
    @Environment(\.dismiss) private var dismiss

    @State private var goals: [Goal] = []
    @State private var newTitle = ""

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach($goals) { $goal in
                        VStack(alignment: .leading, spacing: 10) {
                            HStack(spacing: 10) {
                                Image(systemName: goal.icon)
                                    .foregroundStyle(Color.homeAccent)
                                    .frame(width: 24)
                                TextField("Goal", text: $goal.title)
                            }
                            Stepper("Progress: \(goal.current) / \(goal.target)", value: $goal.current, in: 0...goal.target)
                            Stepper("Target: \(goal.target)", value: $goal.target, in: 1...30)
                        }
                        .padding(.vertical, 4)
                    }
                    .onDelete { goals.remove(atOffsets: $0) }
                } header: {
                    Text("Your goals")
                }

                Section("Add a goal") {
                    HStack {
                        TextField("e.g. Journal 5x this week", text: $newTitle)
                            .onSubmit(add)
                        Button(action: add) {
                            Image(systemName: "plus.circle.fill").foregroundStyle(Color.homeAccent)
                        }
                        .disabled(trimmed.isEmpty)
                    }
                }
            }
            .navigationTitle("Goals")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("Done") { save() } }
                ToolbarItem(placement: .topBarLeading) { EditButton() }
            }
            .onAppear { goals = Goals.decode(raw) }
        }
        .tint(.homeAccent)
    }

    private var trimmed: String { newTitle.trimmingCharacters(in: .whitespacesAndNewlines) }

    private func add() {
        guard !trimmed.isEmpty else { return }
        goals.append(Goal(title: trimmed, icon: Goals.icon(for: trimmed), current: 0, target: 7))
        newTitle = ""
    }

    private func save() {
        raw = Goals.encode(goals)
        dismiss()
    }
}
