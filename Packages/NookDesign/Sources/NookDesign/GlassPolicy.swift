// Licensed under GPL-3.0. See LICENSE.
//
//  GlassPolicy.swift
//  NookDesign
//
//  The one decision behind every chrome surface: Liquid Glass, an opaque card, or the pre-26
//  look. Foundation-free so `Checks/GlassPolicyCheck.swift` can compile it on its own.
//

public enum GlassMaterial: Equatable, Sendable {
    /// Before macOS 26: the old chrome, old layout included.
    case legacy
    /// Liquid Glass panels and controls.
    case glass
    /// The glass layout with opaque surfaces, for Reduce Transparency or Increase Contrast.
    case solid
}

public enum GlassPolicy {
    public static func material(supportsGlass: Bool, reduceTransparency: Bool, increaseContrast: Bool) -> GlassMaterial {
        guard supportsGlass else { return .legacy }
        return reduceTransparency || increaseContrast ? .solid : .glass
    }
}
