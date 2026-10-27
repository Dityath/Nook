// Licensed under GPL-3.0. See LICENSE.
//
//  View+Surface.swift
//  Nook
//
//  The surface recipes every layer goes through. Floating layers and the selected row follow the
//  window's `GlassMaterial` (View+Glass.swift): Liquid Glass on macOS 26, the solid card with
//  Reduce Transparency or Increase Contrast, and the old solid look before 26.
//

import SwiftUI

public extension View {
    /// A layer that floats over content: glass, or a solid raised card with a hairline edge.
    func nookFloatingSurface<S: InsettableShape>(in shape: S) -> some View {
        modifier(FloatingSurface(shape: shape))
    }

    /// Controls over video: a dark scrim, whatever the page or appearance.
    func nookMediaControl<S: Shape>(in shape: S) -> some View {
        background(shape.fill(NookDesign.Surface.mediaScrim))
    }

    /// The selected sidebar row or pinned tile. Branch-free on the selection so view identity is
    /// stable and the change animates; the row applies its own `.raised` elevation.
    func nookRowSelection(_ isSelected: Bool, radius: CGFloat = NookDesign.Radius.md) -> some View {
        modifier(RowSelection(isSelected: isSelected, radius: radius))
    }

    /// A sidebar chrome control or group: history, sidebar and AI toggles, bottom bar buttons,
    /// search fields, filter chips. `tint` marks the chosen one of a set.
    func nookControlSurface<S: InsettableShape>(_ isOn: Bool = true, tint: Color? = nil, in shape: S) -> some View {
        background(shape.fill(isOn ? (tint?.opacity(NookDesign.Surface.tintOpacity) ?? NookDesign.Surface.fill) : .clear))
    }
}
