// Licensed under GPL-3.0. See LICENSE.
//
//  PinnedButtonView.swift
//  Nook
//
//  Created by Maciek Bagiński on 30/07/2025.
//

import SwiftUI
import NookDesign

public struct PinnedTabView<Icon: View>: View {
    var tabName: String
    var tabURL: String
    var tabIcon: Icon
    var isActive: Bool
    var isUnloaded: Bool = false
    /// The favorite's open page has left its pinned URL; hovering shows a reset button.
    var hasLeftPinnedURL: Bool = false
    var onResetToPinnedURL: () -> Void = {}
    var action: () -> Void

    @State private var isHovered: Bool = false
    @Environment(\.nookOnGlassPanel) private var onGlassPanel

    public init(
        tabName: String,
        tabURL: String,
        tabIcon: Icon,
        isActive: Bool,
        isUnloaded: Bool = false,
        hasLeftPinnedURL: Bool = false,
        onResetToPinnedURL: @escaping () -> Void = {},
        action: @escaping () -> Void
    ) {
        self.tabName = tabName
        self.tabURL = tabURL
        self.tabIcon = tabIcon
        self.isActive = isActive
        self.isUnloaded = isUnloaded
        self.hasLeftPinnedURL = hasLeftPinnedURL
        self.onResetToPinnedURL = onResetToPinnedURL
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            ZStack {
                NookDesign.Radius.shape(NookDesign.Radius.lg)
                    .fill(backgroundColor)
                    .animation(NookDesign.Motion.quick, value: isHovered)

                tabIcon
                    .frame(height: NookDesign.Size.essentialsFavicon)
                    .opacity(isUnloaded ? NookDesign.Surface.unloadedOpacity : 1)
            }
            .overlay(alignment: .topTrailing) {
                if hasLeftPinnedURL && isHovered {
                    Button(action: onResetToPinnedURL) {
                        Image(systemName: "arrow.uturn.backward")
                            .font(NookDesign.Font.caption)
                            .foregroundStyle(.primary)
                            .frame(width: NookDesign.Size.cornerButton, height: NookDesign.Size.cornerButton)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .help("Reset to Pinned URL")
                    .padding(NookDesign.Spacing.xxs)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: NookDesign.Size.essentialsTile)
            .frame(minWidth: NookDesign.Size.essentialsTile)
            .contentShape(NookDesign.Radius.shape(NookDesign.Radius.lg))
            .nookRowSelection(isActive, radius: NookDesign.Radius.lg)
            // On a glass panel the tile is a glass control; the selection fill sits on it.
            .background {
                if onGlassPanel {
                    NookDesign.Radius.shape(NookDesign.Radius.lg)
                        .fill(.clear)
                        .nookControlGlass(in: NookDesign.Radius.shape(NookDesign.Radius.lg))
                }
            }
            .nookElevation(isActive ? .raised : .flat)
        }
        .buttonStyle(.plain)
        .onHoverTracking { hovering in
            self.isHovered = hovering
        }
    }

    //MARK: - Colors
    /// Clear when selected: `nookRowSelection` draws the raised surface. On a glass panel the
    /// glass is the idle tile, so only hover adds a fill.
    private var backgroundColor: Color {
        if isActive { return .clear }
        if onGlassPanel { return isHovered ? NookDesign.Surface.glassRowHover : .clear }
        return isHovered ? NookDesign.Surface.fillPressed : NookDesign.Surface.fill
    }
}
