import XCTest
@testable import Lilac

/// These target `RewindSelector` — the single guardrail chokepoint — because the
/// three properties we most need to guarantee (crisis content is never surfaced
/// passively, muted themes never appear, and `off` never generates a rewind) are
/// all decided there, in pure code with no SwiftData or network.
final class RewindSelectorTests: XCTestCase {

    private func candidate(
        score: Double = 1,
        tags: [String] = ["general"],
        crisis: Bool = false,
        lastSurfaced: Date? = nil
    ) -> RewindSelector.Candidate {
        RewindSelector.Candidate(salienceScore: score, themeTags: tags, crisisFlagged: crisis, lastSurfaced: lastSurfaced)
    }

    private func settings(
        enabled: Bool = true,
        frequency: RewindFrequency = .weekly,
        muted: [String] = [],
        lastRewindAt: Date? = nil
    ) -> RewindSelector.Settings {
        RewindSelector.Settings(enabled: enabled, frequency: frequency, mutedThemes: muted, lastRewindAt: lastRewindAt)
    }

    // MARK: off / disabled

    func testOffFrequencyNeverSurfaces() {
        let result = RewindSelector.select(
            from: [candidate(score: 999)],
            settings: settings(frequency: .off)
        )
        XCTAssertNil(result, "frequency = off must never generate a rewind")
    }

    func testDisabledNeverSurfaces() {
        let result = RewindSelector.select(
            from: [candidate(score: 999)],
            settings: settings(enabled: false)
        )
        XCTAssertNil(result, "disabled feature must never generate a rewind")
    }

    // MARK: crisis safety

    func testCrisisOnlyCandidateNeverSurfaces() {
        let result = RewindSelector.select(
            from: [candidate(score: 999, crisis: true)],
            settings: settings()
        )
        XCTAssertNil(result, "a crisis-flagged entry must never surface passively")
    }

    func testCrisisExcludedEvenWithHigherScore() {
        // Crisis candidate has the higher score; the clean one must win anyway.
        let candidates = [
            candidate(score: 999, tags: ["grief"], crisis: true),
            candidate(score: 1, tags: ["gratitude"], crisis: false),
        ]
        let result = RewindSelector.select(from: candidates, settings: settings())
        XCTAssertEqual(result, 1, "must pick the clean candidate, never the crisis one")
    }

    // MARK: muted themes

    func testMutedThemeExcluded() {
        let candidates = [candidate(score: 5, tags: ["work-stress"])]
        let result = RewindSelector.select(from: candidates, settings: settings(muted: ["work-stress"]))
        XCTAssertNil(result, "a muted theme must never surface")
    }

    func testMutedThemeExcludedAmongOthers() {
        let candidates = [
            candidate(score: 9, tags: ["work-stress", "sleep"]),
            candidate(score: 2, tags: ["gratitude"]),
        ]
        let result = RewindSelector.select(from: candidates, settings: settings(muted: ["work-stress"]))
        XCTAssertEqual(result, 1, "muting one of a candidate's tags removes it, even if higher-scored")
    }

    // MARK: recency + frequency

    func testRecentlyShownExcluded() {
        let fiveDaysAgo = Calendar.current.date(byAdding: .day, value: -5, to: .now)
        let result = RewindSelector.select(
            from: [candidate(lastSurfaced: fiveDaysAgo)],
            settings: settings()
        )
        XCTAssertNil(result, "an entry shown within 30 days must not resurface")
    }

    func testOldEnoughResurfaces() {
        let longAgo = Calendar.current.date(byAdding: .day, value: -40, to: .now)
        let result = RewindSelector.select(
            from: [candidate(lastSurfaced: longAgo)],
            settings: settings()
        )
        XCTAssertEqual(result, 0)
    }

    func testFrequencyGateBlocksTooSoon() {
        let threeDaysAgo = Calendar.current.date(byAdding: .day, value: -3, to: .now)
        let result = RewindSelector.select(
            from: [candidate()],
            settings: settings(frequency: .weekly, lastRewindAt: threeDaysAgo)
        )
        XCTAssertNil(result, "weekly cadence must not surface again after only 3 days")
    }

    func testFrequencyGateAllowsAfterInterval() {
        let eightDaysAgo = Calendar.current.date(byAdding: .day, value: -8, to: .now)
        let result = RewindSelector.select(
            from: [candidate()],
            settings: settings(frequency: .weekly, lastRewindAt: eightDaysAgo)
        )
        XCTAssertEqual(result, 0)
    }

    // MARK: ranking

    func testPicksHighestSalience() {
        let candidates = [
            candidate(score: 0.2, tags: ["a"]),
            candidate(score: 0.9, tags: ["b"]),
            candidate(score: 0.5, tags: ["c"]),
        ]
        let result = RewindSelector.select(from: candidates, settings: settings())
        XCTAssertEqual(result, 1)
    }
}
