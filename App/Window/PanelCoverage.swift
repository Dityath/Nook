// Licensed under GPL-3.0. See LICENSE.
//
//  PanelCoverage.swift
//  Nook
//
//  How far the floating glass panels reach in from each side of a window. The page fills the
//  window under them, and each web view turns the overlap into `obscuredContentInsets`, so WebKit
//  lays the page out clear of the panels and fills the covered strip with its background.
//

import AppKit
import SwiftUI

@MainActor
enum PanelCoverage {
    /// Points covered from the window's left and right edges, panel insets included.
    struct Edges: Equatable {
        var left: CGFloat = 0
        var right: CGFloat = 0
    }

    private static var byWindow: [ObjectIdentifier: Edges] = [:]

    static func edges(for window: NSWindow) -> Edges {
        byWindow[ObjectIdentifier(window)] ?? Edges()
    }

    fileprivate static func set(_ edges: Edges, for window: NSWindow) {
        guard byWindow[ObjectIdentifier(window)] != edges else { return }
        byWindow[ObjectIdentifier(window)] = edges
        // Each web view recomputes its insets in layout(); split panes take only their own overlap.
        window.contentView.map(invalidateWebViews)
    }

    fileprivate static func clear(for window: NSWindow) {
        byWindow[ObjectIdentifier(window)] = nil
    }

    private static func invalidateWebViews(in view: NSView) {
        if view is FocusableWKWebView {
            view.needsLayout = true
            return
        }
        view.subviews.forEach(invalidateWebViews)
    }
}

/// Reports a window's panel coverage from SwiftUI, where the panel widths live.
struct PanelCoverageReporter: NSViewRepresentable {
    let left: CGFloat
    let right: CGFloat

    func makeNSView(context: Context) -> ReporterView { ReporterView() }

    func updateNSView(_ view: ReporterView, context: Context) {
        view.edges = PanelCoverage.Edges(left: left, right: right)
    }

    final class ReporterView: NSView {
        var edges = PanelCoverage.Edges() {
            didSet { report() }
        }

        override func viewWillMove(toWindow newWindow: NSWindow?) {
            if newWindow == nil, let window { PanelCoverage.clear(for: window) }
            super.viewWillMove(toWindow: newWindow)
        }

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            report()
        }

        override func hitTest(_ point: NSPoint) -> NSView? { nil }

        private func report() {
            guard let window else { return }
            PanelCoverage.set(edges, for: window)
        }
    }
}
