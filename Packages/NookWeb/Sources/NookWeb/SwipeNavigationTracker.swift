// Licensed under GPL-3.0. See LICENSE.
//
//  SwipeNavigationTracker.swift
//  NookWeb
//
//  The state of one two-finger swipe for back or forward: how far the bubble has filled, whether
//  letting go now navigates, and when a haptic plays. No imports, so
//  `Checks/SwipeNavigationTrackerCheck.swift` can compile it on its own.
//

public enum SwipeDirection: Equatable, Sendable {
    case back, forward
}

public enum SwipeHapticEvent: Equatable, Sendable {
    /// The swipe crossed the commit point: letting go now navigates.
    case armed
    /// It came back far enough that letting go cancels.
    case disarmed
}

public struct SwipeNavigationTracker: Sendable {
    /// Gesture amount (a fraction of the page width, as `trackSwipeEvent` reports it) that arms.
    public static let commitThreshold = 0.3
    /// How far below the threshold the swipe has to come back before it disarms, so jitter at the
    /// threshold plays one haptic, not one per frame.
    public static let rearmMargin = 0.05

    public let direction: SwipeDirection
    /// 0 to 1: how full the bubble's ring is.
    public private(set) var progress = 0.0
    public private(set) var isArmed = false

    public init(direction: SwipeDirection) {
        self.direction = direction
    }

    /// Feeds the current absolute gesture amount; returns a haptic event when the armed state flips.
    public mutating func update(amount: Double) -> SwipeHapticEvent? {
        progress = min(amount / Self.commitThreshold, 1)
        if !isArmed, amount >= Self.commitThreshold {
            isArmed = true
            return .armed
        }
        if isArmed, amount < Self.commitThreshold - Self.rearmMargin {
            isArmed = false
            return .disarmed
        }
        return nil
    }

    public var shouldCommit: Bool { isArmed }
}
