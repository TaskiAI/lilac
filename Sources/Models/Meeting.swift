import Foundation
import SwiftData

/// A scheduled meeting — a therapy session, a check-in with a trusted person, a
/// support group. Lilac has no backend, so "sharing sessions" is modelled
/// locally: the writer keeps their own record of who they meet and when, and can
/// jot notes to bring or take away.
@Model
final class Meeting {
    var title: String
    var personName: String
    var date: Date
    var notes: String
    var location: String

    init(
        title: String = "",
        personName: String = "",
        date: Date = .now,
        notes: String = "",
        location: String = ""
    ) {
        self.title = title
        self.personName = personName
        self.date = date
        self.notes = notes
        self.location = location
    }
}
