// Licensed under GPL-3.0. See LICENSE.
//
//  BehindWindowMaterial.swift
//  Nook
//
//  The browser window's background on macOS 26: the desktop and the windows behind Nook, frosted,
//  the way a Finder sidebar shows them. AppKit's behind-window blending is the only material that
//  sees past the window; SwiftUI's glass samples the window's own content. It dims with the
//  window going inactive and turns opaque under Reduce Transparency on its own.
//

import AppKit
import SwiftUI

struct BehindWindowMaterial: NSViewRepresentable {
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = .sidebar
        view.blendingMode = .behindWindow
        view.state = .followsWindowActiveState
        return view
    }

    func updateNSView(_ view: NSVisualEffectView, context: Context) {}
}
