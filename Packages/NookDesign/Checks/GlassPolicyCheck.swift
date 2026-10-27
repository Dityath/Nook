// Licensed under GPL-3.0. See LICENSE.
//
//  GlassPolicyCheck.swift
//  Nook
//
//  Which material the chrome draws. NookDesign has no test target, so this compiles the shipped
//  source directly:
//
//    swiftc Packages/NookDesign/Sources/NookDesign/GlassPolicy.swift \
//           Packages/NookDesign/Checks/GlassPolicyCheck.swift -o "$TMPDIR/glass-policy" && "$TMPDIR/glass-policy"
//

@main
struct GlassPolicyCheck {
    static func main() {
        func material(_ glass: Bool, _ reduce: Bool, _ contrast: Bool) -> GlassMaterial {
            GlassPolicy.material(supportsGlass: glass, reduceTransparency: reduce, increaseContrast: contrast)
        }

        // Before macOS 26 the old chrome stays, whatever the accessibility settings say.
        precondition(material(false, false, false) == .legacy)
        precondition(material(false, true, true) == .legacy)

        precondition(material(true, false, false) == .glass)

        // Either setting asks for an opaque surface; the layout does not change with it.
        precondition(material(true, true, false) == .solid)
        precondition(material(true, false, true) == .solid)
    }
}
