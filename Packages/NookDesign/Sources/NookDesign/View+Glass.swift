// Licensed under GPL-3.0. See LICENSE.
//
//  View+Glass.swift
//  NookDesign
//
//  Liquid Glass for the fork's chrome. Every glass surface goes through these recipes, and each
//  recipe draws what `GlassPolicy` picked for the window: glass, an opaque card, or the old look.
//

import SwiftUI

public extension EnvironmentValues {
    /// What this window's chrome draws. Set once at the browser window's root (`WindowView`) from
    /// `GlassPolicy`; anything outside a browser window (Settings, the mini window) keeps the old look.
    @Entry var nookGlassMaterial: GlassMaterial = .legacy
    /// True for content on a glass panel, so rows and buttons inside it pick their glass variants.
    @Entry var nookOnGlassPanel: Bool = false
}

public extension GlassPolicy {
    /// Liquid Glass exists from macOS 26 on.
    static var osSupportsGlass: Bool {
        if #available(macOS 26, iOS 26, *) { return true }
        return false
    }
}

public extension View {
    /// A floating panel over the page: the sidebar, the AI panel, the hover sidebar. `tint` marks a
    /// window that must not pass for a regular one (private).
    func nookPanelSurface<S: InsettableShape>(in shape: S, tint: Color? = nil) -> some View {
        modifier(PanelSurface(shape: shape, tint: tint))
    }

    /// An interactive glass control on a panel: icon buttons, the URL bar, favorite tiles, the chat
    /// box. Without glass it is the control fill `nookControlSurface` draws.
    func nookControlGlass<S: InsettableShape>(in shape: S) -> some View {
        modifier(ControlGlass(shape: shape))
    }
}

private struct PanelSurface<S: InsettableShape>: ViewModifier {
    let shape: S
    let tint: Color?
    @Environment(\.nookGlassMaterial) private var material
    @Environment(\.appearsActive) private var appearsActive

    func body(content: Content) -> some View {
        switch material {
        case .legacy:
            content
        case .glass:
            if #available(macOS 26, iOS 26, *) {
                content
                    .environment(\.nookOnGlassPanel, true)
                    // Under the content, over the glass: an inactive window's panel steps back.
                    .background(shape.fill(appearsActive ? Color.clear : NookDesign.Surface.inactivePanelDim))
                    // glassEffect leaves the content unclipped, so a full-bleed fill would run out
                    // to square corners and the shadow would trace the square.
                    .clipShape(shape)
                    .glassEffect(.regular.tint(tint), in: shape)
            } else {
                content
            }
        case .solid:
            content
                .background(shape.fill(tint ?? .clear))
                .background(shape.fill(NookDesign.Surface.raised))
                .clipShape(shape)
                .overlay(shape.strokeBorder(NookDesign.Surface.hairline, lineWidth: NookDesign.Size.hairlineWidth))
                .nookElevation(.floating)
        }
    }
}

private struct ControlGlass<S: InsettableShape>: ViewModifier {
    let shape: S
    @Environment(\.nookGlassMaterial) private var material

    func body(content: Content) -> some View {
        if material == .glass, #available(macOS 26, iOS 26, *) {
            content.glassEffect(.regular.interactive(), in: shape)
        } else {
            content.background(shape.fill(NookDesign.Surface.fill))
        }
    }
}

/// `nookFloatingSurface`'s body: glass over the page, else the solid card it always was.
struct FloatingSurface<S: InsettableShape>: ViewModifier {
    let shape: S
    @Environment(\.nookGlassMaterial) private var material

    func body(content: Content) -> some View {
        if material == .glass, #available(macOS 26, iOS 26, *) {
            content
                .clipShape(shape)
                .glassEffect(.regular, in: shape)
                .nookElevation(.floating)
        } else {
            content
                .clipShape(shape)
                .background(shape.fill(NookDesign.Surface.raised))
                .overlay(shape.strokeBorder(NookDesign.Surface.hairline, lineWidth: NookDesign.Size.hairlineWidth))
                .nookElevation(.floating)
        }
    }
}

/// `nookRowSelection`'s body: on a glass panel a soft vibrant fill, never glass; elsewhere the
/// raised card.
struct RowSelection: ViewModifier {
    let isSelected: Bool
    let radius: CGFloat
    @Environment(\.nookOnGlassPanel) private var onGlassPanel

    func body(content: Content) -> some View {
        let shape = NookDesign.Radius.shape(radius)
        if onGlassPanel {
            content.background(shape.fill(isSelected ? NookDesign.Surface.glassRowSelected : .clear))
        } else {
            content
                .background(shape.fill(isSelected ? NookDesign.Surface.raised : .clear))
                .overlay(shape.strokeBorder(NookDesign.Surface.hairline.opacity(isSelected ? 1 : 0), lineWidth: NookDesign.Size.hairlineWidth))
        }
    }
}
