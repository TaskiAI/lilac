import Foundation
import SwiftData

/// One message in the AI companion conversation. The whole thread is persisted
/// so the companion feels continuous across launches. `roleRawValue` is stored
/// as a raw string for the same clean-migration reason as `JournalEntry.style`.
@Model
final class CompanionMessage {
    var createdAt: Date
    var text: String
    private var roleRawValue: String

    var role: CompanionRole {
        get { CompanionRole(rawValue: roleRawValue) ?? .assistant }
        set { roleRawValue = newValue.rawValue }
    }

    init(role: CompanionRole, text: String, createdAt: Date = .now) {
        self.roleRawValue = role.rawValue
        self.text = text
        self.createdAt = createdAt
    }
}

/// Who authored a companion message.
enum CompanionRole: String, Codable {
    case user
    case assistant
}
