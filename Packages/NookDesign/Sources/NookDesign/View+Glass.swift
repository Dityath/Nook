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

    /// A field-like control (URL bar, chat box): a glass `glassShape` on a glass panel, otherwise
    /// the `nookControlSurface` fill in `shape`, clipped to whichever it draws.
    func nookPanelControl<G: InsettableShape, S: InsettableShape>(glass glassShape: G, else shape: S) -> some View {
        modifier(PanelControl(glassShape: glassShape, shape: shape))
    }
}

// Every recipe below is one modifier chain whatever the material, switching values rather than
// branches (`.identity` glass, clear fills), so turning Reduce Transparency on or off keeps the
// views under it, their state and any web view they host, where they are. The only branch is
// `#available`, which never changes while the app runs.

private struct PanelControl<G: InsettableShape, S: InsettableShape>: ViewModifier {
    let glassShape: G
    let shape: S
    @Environment(\.nookOnGlassPanel) private var onGlassPanel

    func body(content: Content) -> some View {
        if #available(macOS 26, iOS 26, *) {
            let drawn = onGlassPanel ? AnyShape(glassShape) : AnyShape(shape)
            content
                .clipShape(drawn)
                .background(drawn.fill(onGlassPanel ? Color.clear : NookDesign.Surface.fill))
                .glassEffect(onGlassPanel ? .regular.interactive() : .identity, in: drawn)
        } else {
            content.clipShape(shape).background(shape.fill(NookDesign.Surface.fill))
        }
    }
}

private struct PanelSurface<S: InsettableShape>: ViewModifier {
    let shape: S
    let tint: Color?
    @Environment(\.nookGlassMaterial) private var material
    @Environment(\.appearsActive) private var appearsActive

    func body(content: Content) -> some View {
        // `.legacy` is fixed by the OS, so this branch never flips at run time.
        if material != .legacy, #available(macOS 26, iOS 26, *) {
            let glass = material == .glass
            content
                .environment(\.nookOnGlassPanel, glass)
                // Under the content, over the glass: an inactive window's panel steps back.
                .background(shape.fill(glass && !appearsActive ? NookDesign.Surface.inactivePanelDim : Color.clear))
                // Opaque: the raised card, tinted for a private window.
                .background(shape.fill(glass ? Color.clear : (tint ?? Color.clear)))
                .background(shape.fill(glass ? Color.clear : NookDesign.Surface.raised))
                // glassEffect leaves the content unclipped, so a full-bleed fill would run out
                // to square corners and the shadow would trace the square.
                .clipShape(shape)
                .overlay(shape.strokeBorder(NookDesign.Surface.hairline.opacity(glass ? 0 : 1), lineWidth: NookDesign.Size.hairlineWidth))
                .glassEffect(glass ? .regular.tint(tint) : .identity, in: shape)
                .nookElevation(glass ? .flat : .floating)
        } else {
            content
        }
    }
}

private struct ControlGlass<S: InsettableShape>: ViewModifier {
    let shape: S
    @Environment(\.nookGlassMaterial) private var material

    func body(content: Content) -> some View {
        if #available(macOS 26, iOS 26, *) {
            let glass = material == .glass
            content
                .background(shape.fill(glass ? Color.clear : NookDesign.Surface.fill))
                .glassEffect(glass ? .regular.interactive() : .identity, in: shape)
        } else {
            content.background(shape.fill(NookDesign.Surface.fill))
        }
    }
}

/// `nookFloatingSurface`'s body: glass over the page, else the solid card it always was. A card
/// inside a glass panel (update and what's-new cards, downloads hover) stays solid: never glass
/// on glass.
struct FloatingSurface<S: InsettableShape>: ViewModifier {
    let shape: S
    @Environment(\.nookGlassMaterial) private var material
    @Environment(\.nookOnGlassPanel) private var onGlassPanel

    func body(content: Content) -> some View {
        if #available(macOS 26, iOS 26, *) {
            let glass = material == .glass && !onGlassPanel
            content
                .clipShape(shape)
                .background(shape.fill(glass ? Color.clear : NookDesign.Surface.raised))
                .overlay(shape.strokeBorder(NookDesign.Surface.hairline.opacity(glass ? 0 : 1), lineWidth: NookDesign.Size.hairlineWidth))
                .glassEffect(glass ? .regular : .identity, in: shape)
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
        let fill = onGlassPanel ? NookDesign.Surface.glassRowSelected : NookDesign.Surface.raised
        content
            .background(shape.fill(isSelected ? fill : .clear))
            .overlay(shape.strokeBorder(NookDesign.Surface.hairline.opacity(isSelected && !onGlassPanel ? 1 : 0), lineWidth: NookDesign.Size.hairlineWidth))
    }
}
