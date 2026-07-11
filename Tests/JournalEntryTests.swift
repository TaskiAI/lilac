import XCTest
@testable import Lilac

final class JournalEntryTests: XCTestCase {
    func testDisplayTitlePrefersUserTitle() {
        let entry = JournalEntry(title: "My day", text: "some body text")
        XCTAssertEqual(entry.displayTitle, "My day")
    }

    func testDisplayTitleFallsBackToFirstLine() {
        let entry = JournalEntry(title: "", text: "First line\nsecond line")
        XCTAssertEqual(entry.displayTitle, "First line")
    }

    func testDisplayTitleFallsBackToPrompt() {
        let entry = JournalEntry(text: "", prompt: "What came up this week?")
        XCTAssertEqual(entry.displayTitle, "What came up this week?")
    }

    func testDisplayTitleIsUntitledWhenBlank() {
        let entry = JournalEntry(title: "   ", text: "   ")
        XCTAssertEqual(entry.displayTitle, "Untitled")
    }

    func testGenericReflectionPromptIsNonEmpty() {
        XCTAssertFalse(JournalAI.genericPrompt().isEmpty)
    }
}
