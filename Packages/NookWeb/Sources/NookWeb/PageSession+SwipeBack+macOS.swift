// Licensed under GPL-3.0. See LICENSE.
//
//  PageSession+SwipeBack+macOS.swift
//  NookWeb
//
//  Two-finger swipes for back and forward. WebKit's own gesture is off: the page stays still while
//  a glass bubble (`swipeIndicator`, drawn by the app) fills at the edge, a haptic marks the point
//  where letting go navigates, and the page it lands on fades in.
//

#if os(macOS)
import AppKit
import NookDesign
import WebKit

/// What the swipe bubble shows.
public struct SwipeIndicator: Equatable, Sendable {
    public let direction: SwipeDirection
    /// 0 to 1: how full the bubble's ring is.
    public let progress: Double
    /// Letting go now navigates.
    public let isArmed: Bool
}

extension PageSession {
    /// Opacity the page a swipe lands on starts from before it fades in.
    private static let swipeFadeStartOpacity: CGFloat = 0.35

    /// WebKit reports only the wheel events the page did not scroll with, so a carousel or map
    /// under the pointer keeps its swipe. `FocusableWKWebView.scrollWheel` keeps the edge being
    /// swiped from rubber-banding, which would use the events up first.
    @objc(_webView:didNotHandleWheelEvent:)
    func webView(_ webView: WKWebView, didNotHandleWheelEvent event: NSEvent) {
        guard event.phase == .began, event.hasPreciseScrollingDeltas,
              NSEvent.isSwipeTrackingFromScrollEventsEnabled, !isAgentPage, swipeIndicator == nil,
              abs(event.scrollingDeltaY) < abs(event.scrollingDeltaX) / 2 else { return }
        let rightToLeft = webView.userInterfaceLayoutDirection == .rightToLeft
        let backward = rightToLeft ? event.scrollingDeltaX < 0 : event.scrollingDeltaX > 0
        guard backward ? canGoBackOrReturn : canGoForward else { return }

        let direction: SwipeDirection = backward ? .back : .forward
        var tracker = SwipeNavigationTracker(direction: direction)
        var decided: Bool?
        let fingersMoveRight = event.scrollingDeltaX > 0
        event.trackSwipeEvent(
            options: [.lockDirection, .clampGestureAmount],
            dampenAmountThresholdMin: fingersMoveRight ? 0 : -1, max: fingersMoveRight ? 1 : 0
        ) { [weak self, weak webView] amount, phase, isComplete, _ in
            guard let self else { return }
            // Once the fingers lift, AppKit animates the amount home or out; the decision is the
            // tracker's state at that moment, not where the animation ends.
            if decided == nil {
                if tracker.update(amount: abs(Double(amount))) != nil {
                    NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .now)
                }
                if phase == .ended || phase == .cancelled { decided = tracker.shouldCommit }
            }
            // The ring follows the amount all the way, so a cancelled swipe drains as it slides back.
            swipeIndicator = isComplete ? nil : SwipeIndicator(
                direction: direction,
                progress: min(Double(abs(amount)) / SwipeNavigationTracker.commitThreshold, 1),
                isArmed: decided ?? tracker.isArmed)
            guard isComplete, decided == true, let webView else { return }
            navigateAfterSwipe(direction, in: webView)
        }
    }

    private func navigateAfterSwipe(_ direction: SwipeDirection, in webView: WKWebView) {
        switch direction {
        case .back:
            // With no history, back closes the tab and shows its opener: nothing to fade in.
            pendingSwipeFade = webView.canGoBack
            goBack(in: webView)
        case .forward:
            pendingSwipeFade = true
            if webView.canGoForward { webView.goForward() } else { goForward() }
        }
    }

    /// The page a swipe landed on fades in once it commits. A page that never commits keeps full
    /// opacity, since nothing dimmed it.
    func fadeInAfterSwipe(_ webView: WKWebView) {
        guard pendingSwipeFade else { return }
        pendingSwipeFade = false
        webView.alphaValue = Self.swipeFadeStartOpacity
        NSAnimationContext.runAnimationGroup { context in
            context.duration = NookDesign.Motion.standardDuration
            webView.animator().alphaValue = 1
        }
    }
}
#endif
