// Licensed under GPL-3.0. See LICENSE.
//
//  SidebarHoverOverlayView.swift
//  Nook
//
//  Created by Jonathan Caudill on 2025-09-13.
//

import SwiftUI
import AppKit
import NookDesign
import NookWeb
import NookUI

struct SidebarHoverOverlayView: View {
    @EnvironmentObject var browserManager: BrowserManager
    @EnvironmentObject var hoverManager: HoverSidebarManager
    @Environment(BrowserWindowState.self) private var windowState
    @Environment(CommandPalette.self) private var commandPalette
    @Environment(\.nookSettings) var nookSettings
    @Environment(\.nookGlassMaterial) private var glassMaterial

    private let horizontalInset: CGFloat = NookDesign.Spacing.md
    private let verticalInset: CGFloat = NookDesign.Spacing.md

    var body: some View {
        // Only render overlay plumbing when the real sidebar is collapsed
        if !windowState.isSidebarVisible {
            ZStack(alignment: nookSettings.sidebarPosition == .left ? .leading : .trailing) {
                // Edge hover hotspot
                Color.clear
                    .frame(width: hoverManager.triggerWidth)
                    .contentShape(Rectangle())
                    .onHoverTracking { isIn in
                        if isIn && !windowState.isSidebarVisible {
                            withAnimation(NookDesign.Motion.quick) {
                                hoverManager.isOverlayVisible = true
                            }
                        }
                        NSCursor.arrow.set()
                    }

                if hoverManager.isOverlayVisible {
                    SpacesSideBarView()
                        .frame(width: windowState.sidebarWidth)
                        .environmentObject(browserManager)
                        .environment(windowState)
                        .environment(commandPalette)
                        .environmentObject(browserManager.gradientColorManager)
                        .frame(maxHeight: .infinity)
                        .modifier(OverlaySurface(
                            material: glassMaterial,
                            legacyBackground: sidebarBackground,
                            agentChrome: isAgentSpace,
                            isIncognito: windowState.isIncognito))
                        .alwaysArrowCursor()
                        .padding(nookSettings.sidebarPosition == .left ? .leading : .trailing, horizontalInset)
                        .padding(.vertical, verticalInset)
                        .transition(
                            .move(edge: nookSettings.sidebarPosition == .left ? .leading : .trailing)
                                .combined(with: .opacity)
                        )
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: nookSettings.sidebarPosition == .left ? .topLeading : .topTrailing)
            // Container remains passive; only overlay/hotspot intercept
        }
    }

    private var isAgentSpace: Bool {
        windowState.spaceID != nil && windowState.spaceID == browserManager.tabs.agentSpaceID
    }

    /// The docked sidebar's own background, so the overlay reads as the same sidebar.
    private var sidebarBackground: some View {
        let accent = windowState.isIncognito ? SpaceGradient.incognito.primaryColor : browserManager.gradientColorManager.accentColor
        return NookDesign.Surface.containerGradient(accent: accent, isActive: true)
            .overlay(windowState.isIncognito ? NookDesign.Surface.privateTint : Color.clear)
            .overlay(Rectangle().fill(NookDesign.Surface.agentGradient).opacity(isAgentSpace ? NookDesign.Surface.agentChromeOpacity : 0))
    }
}

/// Before macOS 26 the overlay is a card wearing the sidebar's gradient; from 26 on it is the same
/// glass panel the docked sidebar floats in.
private struct OverlaySurface<Legacy: View>: ViewModifier {
    let material: GlassMaterial
    let legacyBackground: Legacy
    let agentChrome: Bool
    let isIncognito: Bool

    func body(content: Content) -> some View {
        if material == .legacy {
            content
                .background(legacyBackground)
                .nookFloatingSurface(in: NookDesign.Radius.shape(NookDesign.Radius.lg))
        } else {
            content
                .background(Rectangle().fill(NookDesign.Surface.agentGradient).opacity(agentChrome ? NookDesign.Surface.agentChromeOpacity : 0))
                .nookPanelSurface(
                    in: NookDesign.Radius.shape(NookDesign.Radius.windowInset),
                    tint: isIncognito ? NookDesign.Surface.privateTint : nil)
        }
    }
}
