import Foundation

/// The tier targets for one achievement, scaled to how many species its group has.
///
/// Every group uses the same ladder (1, 5, 10, 25, 50, then every 50: 100, 150, 200, ...), so
/// targets read as round numbers. The group's size picks where the ladder starts (about a twentieth
/// of the group, so a big group doesn't open with "meet 1"), and the group size itself is added as a
/// "met them all" target when it isn't already close to a ladder value. Tiers never run out: the
/// live catalogue (D-012) can show more species than the bundled list, so targets above the group
/// size stay reachable. Pure logic.
enum AchievementTiers {
    static let ladderHead = [1, 5, 10, 25, 50]
    static let step = 50
    /// The group size is skipped as a target when a ladder value is within this share of it.
    static let completionTolerance = 0.2
    /// The first target is the first ladder value at or above `groupSize / startDivisor`.
    static let startDivisor = 20

    /// The i-th ladder value, from 0.
    static func ladderValue(_ i: Int) -> Int {
        i < ladderHead.count ? ladderHead[i] : step * (i - ladderHead.count + 2)
    }

    static func firstLadderIndex(groupSize: Int) -> Int {
        let floor = max(1, (groupSize + startDivisor - 1) / startDivisor)
        var i = 0
        while ladderValue(i) < floor { i += 1 }
        return i
    }

    /// Whether the group size gets its own target.
    static func addsCompletionTarget(groupSize n: Int) -> Bool {
        guard n > ladderValue(firstLadderIndex(groupSize: n)) else { return false }
        let tolerance = max(1, Int(Double(n) * completionTolerance))
        var i = 0
        while true {
            let v = ladderValue(i)
            if abs(v - n) <= tolerance { return false }
            if v > n { return true }
            i += 1
        }
    }

    /// Ascending targets up to and including the first one above `count`, so the caller gets
    /// every reached target plus the next one.
    static func targets(groupSize: Int, through count: Int) -> [Int] {
        var out: [Int] = []
        var completionPending = addsCompletionTarget(groupSize: groupSize)
        var i = firstLadderIndex(groupSize: groupSize)
        while true {
            let v = ladderValue(i)
            if completionPending, groupSize < v {
                completionPending = false
                out.append(groupSize)
                if groupSize > count { return out }
            }
            out.append(v)
            if v > count { return out }
            i += 1
        }
    }

    static func progress(for achievement: Achievement, metCount: Int) -> AchievementProgress {
        let all = targets(groupSize: achievement.groupSize, through: metCount)
        return AchievementProgress(achievement: achievement, metCount: metCount,
                                   reachedTargets: all.filter { $0 <= metCount },
                                   nextTarget: all.last ?? 1)
    }
}
