// Licensed under GPL-3.0. See LICENSE.
//
//  SwipeBubbleView.swift
//  Nook
//
//  The glass bubble a two-finger swipe pulls in from the page's edge: a chevron in a ring that
//  fills with the swipe, swelling a little once letting go would navigate.
//

import SwiftUI
import NookDesign
import NookWeb

extension EnvironmentValues {
    /// How much of the page area floating panels cover on each side, so overlays that belong to
    /// the page's edge (the swipe bubble) sit beside the panels rather than under them.
    @Entry var nookPagePanelInsets = EdgeInsets()
}

/// The bubble for one page, placed at its edge inside `rect` (the page's frame in this view).
struct SwipeBubbleOverlay: View {
    let session: PageSession
    var rect: CGRect? = nil
    @Environment(\.nookPagePanelInsets) private var panelInsets
    @Environment(\.layoutDirection) private var layoutDirection

    var body: some View {
        GeometryReader { proxy in
            if let indicator = session.swipeIndicator {
                let frame = rect ?? CGRect(origin: .zero, size: proxy.size)
                let leading = frame.minX + (frame.minX == 0 ? panelInsets.leading : 0)
                let trailing = frame.maxX - (frame.maxX >= proxy.size.width ? panelInsets.trailing : 0)
                let atLeadingEdge = (indicator.direction == .back) == (layoutDirection == .leftToRight)
                let size = NookDesign.Size.swipeBubble
                // Slides from half hidden at the edge to fully in as the ring fills.
                let travel = size * (indicator.progress - 0.5)
                SwipeBubbleView(indicator: indicator)
                    .position(
                        x: atLeadingEdge ? leading + travel : trailing - travel,
                        y: frame.midY)
                    .animation(NookDesign.Motion.quick, value: indicator.isArmed)
            }
        }
        .allowsHitTesting(false)
    }
}

struct SwipeBubbleView: View {
    let indicator: SwipeIndicator

    var body: some View {
        let size = NookDesign.Size.swipeBubble
        ZStack {
            Circle()
                .trim(from: 0, to: indicator.progress)
                .stroke(.primary.opacity(indicator.isArmed ? 0.9 : 0.5),
                        style: StrokeStyle(lineWidth: NookDesign.Size.swipeRing, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .padding(NookDesign.Size.swipeRing)
            Image(systemName: indicator.direction == .back ? "chevron.backward" : "chevron.forward")
                .font(NookDesign.Font.titleLarge)
                .foregroundStyle(.primary)
        }
        .frame(width: size, height: size)
        .nookControlGlass(in: Circle())
        .scaleEffect(indicator.isArmed ? 1.1 : 0.85 + 0.15 * indicator.progress)
        .opacity(0.4 + 0.6 * indicator.progress)
    }
}
