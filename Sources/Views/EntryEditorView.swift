import SwiftUI

/// The free-form diary: the reusable journal page with no prompt.
/// Prompted / typed journaling modes are new screens that pass an accessory
/// (and optionally a theme) into `JournalPage`.
struct EntryEditorView: View {
    let entry: JournalEntry

    var body: some View {
        JournalPage(entry: entry)
    }
}
