import XCTest
@testable import AnimalScroller

final class AchievementTiersTests: XCTestCase {
    func testLadder() {
        XCTAssertEqual((0..<9).map(AchievementTiers.ladderValue), [1, 5, 10, 25, 50, 100, 150, 200, 250])
    }

    func testBigGroupsStartHigherAndClimbByFifty() {
        // About 60 birds: 5, 10, 25, 50, then every 50 (the "50, 100, 150" ask).
        XCTAssertEqual(AchievementTiers.targets(groupSize: 61, through: 120), [5, 10, 25, 50, 100, 150])
        XCTAssertEqual(AchievementTiers.targets(groupSize: 126, through: 0), [10])
        XCTAssertEqual(AchievementTiers.targets(groupSize: 361, through: 0), [25])
        XCTAssertEqual(AchievementTiers.targets(groupSize: 1000, through: 0), [50])
    }

    func testSmallGroupsGetAMetThemAllTarget() {
        XCTAssertEqual(AchievementTiers.targets(groupSize: 3, through: 7), [1, 3, 5, 10])
        XCTAssertTrue(AchievementTiers.addsCompletionTarget(groupSize: 3))
        // Within 20% of a ladder value: no extra target.
        XCTAssertFalse(AchievementTiers.addsCompletionTarget(groupSize: 61))
        XCTAssertFalse(AchievementTiers.addsCompletionTarget(groupSize: 1))
        XCTAssertFalse(AchievementTiers.addsCompletionTarget(groupSize: 2))
    }

    func testTargetsAlwaysEndAboveTheCount() {
        for n in [1, 2, 3, 7, 18, 43, 61, 126, 361, 1000] {
            for count in [0, 1, 4, 49, 50, 51, 400, 2000] {
                let t = AchievementTiers.targets(groupSize: n, through: count)
                XCTAssertGreaterThan(t.last ?? 0, count, "n=\(n) count=\(count)")
                XCTAssertEqual(t, t.sorted(), "n=\(n)")
                XCTAssertEqual(Set(t).count, t.count, "n=\(n)")
            }
        }
    }

    func testProgress() {
        let a = Achievement(kind: .overall, name: "", scientificName: nil, groupSize: 61)
        let p = AchievementTiers.progress(for: a, metCount: 30)
        XCTAssertEqual(p.reachedTargets, [5, 10, 25])
        XCTAssertEqual(p.tier, 3)
        XCTAssertEqual(p.nextTarget, 50)
        XCTAssertEqual(p.fractionToNext, 0.2, accuracy: 0.0001)

        let none = AchievementTiers.progress(for: a, metCount: 0)
        XCTAssertEqual(none.tier, 0)
        XCTAssertEqual(none.nextTarget, 5)
        XCTAssertEqual(none.fractionToNext, 0)

        // Exactly on a target counts as reached.
        XCTAssertEqual(AchievementTiers.progress(for: a, metCount: 50).tier, 4)
    }
}
