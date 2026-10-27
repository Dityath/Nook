// Licensed under GPL-3.0. See LICENSE.
//
//  SwipeNavigationTrackerCheck.swift
//  Nook
//
//  When a two-finger swipe arms back/forward and when it plays a haptic. NookWeb has no test
//  target, so this compiles the shipped source directly:
//
//    swiftc Packages/NookWeb/Sources/NookWeb/SwipeNavigationTracker.swift \
//           Packages/NookWeb/Checks/SwipeNavigationTrackerCheck.swift -o "$TMPDIR/swipe-check" && "$TMPDIR/swipe-check"
//

@main
struct SwipeNavigationTrackerCheck {
    static func main() {
        progressScales()
        armsAtThreshold()
        hysteresisFiresOncePerCrossing()
        cancelBelowThreshold()
    }

    static func progressScales() {
        var tracker = SwipeNavigationTracker(direction: .back)
        let event = tracker.update(amount: 0.15)
        precondition(tracker.progress == 0.5, "progress \(tracker.progress)")
        precondition(!tracker.isArmed)
        precondition(event == nil)
    }

    static func armsAtThreshold() {
        var tracker = SwipeNavigationTracker(direction: .forward)
        precondition(tracker.update(amount: 0.3) == .armed)
        precondition(tracker.shouldCommit)
        precondition(tracker.progress == 1)
    }

    /// Jitter around the commit point plays one haptic per real crossing, not one per frame.
    static func hysteresisFiresOncePerCrossing() {
        var tracker = SwipeNavigationTracker(direction: .back)
        let events = [0.29, 0.31, 0.28, 0.31, 0.24, 0.32].map { tracker.update(amount: $0) }
        precondition(events == [nil, .armed, nil, nil, .disarmed, .armed], "\(events)")
    }

    static func cancelBelowThreshold() {
        var tracker = SwipeNavigationTracker(direction: .back)
        _ = tracker.update(amount: 0.31)
        _ = tracker.update(amount: 0.1)
        precondition(!tracker.shouldCommit)
    }
}
