//
//  ContentView.swift
//  YabaiIndicator
//
//  Created by Max Zhao on 26/12/2021.
//

import SwiftUI
import AppKit

// Reference to app delegate for accessing panel
// Note: Use gAppDelegate instead of NSApp.delegate due to SwiftUI App lifecycle wrapping
var appDelegate: YabaiAppDelegate {
    return gAppDelegate
}

struct SpaceButton : View {
    var space: Space
    var layout: PanelLayout = PanelLayout()
    
    func getText() -> String {
        switch space.type {
        case .standard:
            return "\(space.index)"
        case .fullscreen:
            return "F"
        case .divider:
            return ""
        }
    }
    
    func switchSpace() {
        if !space.active && space.yabaiIndex > 0 {
            gYabaiClient.focusSpace(index: space.yabaiIndex)
        }        
    }
    
    var body: some View {
        if space.type == .divider {
            Divider().background(Color(.systemGray)).frame(height: 14)
        } else {
            Image(nsImage: generateImage(symbol: getText() as NSString, active: space.active, visible: space.visible, scale: layout.scale)).onTapGesture {
                switchSpace()
            }.frame(width: layout.imageSize.width, height: layout.imageSize.height)
        }
    }
}

struct WindowSpaceButton : View {
    var space: Space
    var windows: [Window]
    var displays: [Display]
    var layout: PanelLayout = PanelLayout()

    func switchSpace() {
        if !space.active && space.yabaiIndex > 0 {
            gYabaiClient.focusSpace(index: space.yabaiIndex)
        }
    }

    var body : some View {
        switch space.type {
        case .standard:
            // Safely get display, fallback to a default Display if index is invalid
            let displayIndex = space.display - 1
            if displayIndex >= 0 && displayIndex < displays.count {
                let display = displays[displayIndex]
                // Calculate frame size proportional to display aspect ratio
                let aspect = display.frame.width / display.frame.height
                let frameSize = CGSize(width: layout.baseImageHeight * aspect, height: layout.baseImageHeight)
                Image(nsImage: generateImage(active: space.active, visible: space.visible, windows: windows, display: display, scale: layout.scale)).onTapGesture {
                    switchSpace()
                }.frame(width: frameSize.width, height: frameSize.height)
            } else {
                // Fallback to numeric style if display data is invalid
                Image(nsImage: generateImage(symbol: "\(space.index)" as NSString, active: space.active, visible: space.visible, scale: layout.scale)).onTapGesture {
                    switchSpace()
                }.frame(width: layout.imageSize.width, height: layout.imageSize.height)
            }
        case .fullscreen:
            Image(nsImage: generateImage(symbol: "F" as NSString, active: space.active, visible: space.visible, scale: layout.scale)).onTapGesture {
                switchSpace()
            }.frame(width: layout.imageSize.width, height: layout.imageSize.height)
        case .divider:
            Divider().background(Color(.systemGray)).frame(height: layout.dividerHeight)
        }
    }
}

struct ThumbnailSpaceButton : View {
    var space: Space
    var windows: [Window]
    var displays: [Display]
    var layout: PanelLayout = PanelLayout()
    var isSelected: Bool = false  // Keyboard selection state
    @State private var thumbnail: NSImage?
    @State private var thumbnailSpaceId: UInt64 = 0  // Track which space this thumbnail belongs to

    func switchSpace() {
        if !space.active && space.yabaiIndex > 0 {
            appDelegate.switchSpace(to: space.yabaiIndex)
        }
    }

    var body: some View {
        switch space.type {
        case .standard:
            let displayIndex = space.display - 1

            if displayIndex >= 0 && displayIndex < displays.count {
                let display = displays[displayIndex]
                // Calculate thumbnail size proportional to display aspect ratio
                let aspect = display.frame.width / display.frame.height
                let targetSize = CGSize(width: layout.baseImageHeight * aspect, height: layout.baseImageHeight)

                Group {
                    // Only show thumbnail if it matches current space spaceid
                    if let thumbnail = thumbnail, thumbnailSpaceId == space.spaceid {
                        Image(nsImage: thumbnail)
                    } else {
                        // Show hybrid preview (desktop + window outlines) for unvisited spaces
                        Image(nsImage: generateHybridPreviewImage(active: space.active, visible: space.visible, windows: windows, display: display, scale: layout.scale))
                    }
                }
                .overlay(
                    // Border styling: selection (navigation) + active state
                    // Border drawn outside the edge using negative inset
                    ZStack {
                        // Border: accent when active or selected, secondary gray otherwise
                        // Thickness: 3px when active, 2px when selected inactive, 1px when inactive
                        let isAccent = space.active || isSelected
                        let thickness: CGFloat = space.active ? 3 : (isSelected ? 2 : 1)

                        RoundedRectangle(cornerRadius: 0)
                            .inset(by: -thickness / 2)
                            .stroke(
                                isAccent ? Color.accentColor : Color.secondary,
                                lineWidth: thickness
                            )
                    }
                )
                .onAppear {
                    loadThumbnail(for: space, display: display, windows: windows, size: targetSize)
                }
                .onReceive(NotificationCenter.default.publisher(for: .thumbnailDidCache)) { notification in
                    // Reload thumbnail if cached for this space
                    if let cachedSpaceId = notification.userInfo?["spaceId"] as? UInt64,
                       cachedSpaceId == space.spaceid {
                        loadThumbnail(for: space, display: display, windows: windows, size: targetSize)
                    }
                }
                .onChange(of: space.spaceid) { _ in
                    thumbnail = nil
                    thumbnailSpaceId = 0
                    loadThumbnail(for: space, display: display, windows: windows, size: targetSize)
                }
                .onChange(of: windows.count) { _ in
                    thumbnail = nil
                    thumbnailSpaceId = 0
                    loadThumbnail(for: space, display: display, windows: windows, size: targetSize)
                }
                .frame(width: targetSize.width, height: targetSize.height)
                .onTapGesture { switchSpace() }
            } else {
                Image(nsImage: generateImage(active: space.active, visible: space.visible, windows: windows, display: displays[0], scale: layout.scale))
                    .onTapGesture { switchSpace() }
                    .frame(width: layout.imageSize.width, height: layout.imageSize.height)
            }

        case .fullscreen:
            Image(nsImage: generateImage(symbol: "F" as NSString, active: space.active, visible: space.visible, scale: layout.scale))
                .onTapGesture { switchSpace() }
                .frame(width: layout.imageSize.width, height: layout.imageSize.height)

        case .divider:
            Divider().background(Color(.systemGray)).frame(height: layout.dividerHeight)
        }
    }

    private func loadThumbnail(for space: Space, display: Display, windows: [Window], size: CGSize) {
        // Only check cache - real thumbnails are captured on space switch in YabaiAppDelegate
        // For spaces without cached thumbnails, the windows-style preview (desktop + outlines)
        // shown in the body view provides the fallback appearance
        if let cached = gThumbnailCache.get(spaceId: space.spaceid) {
            thumbnail = cached
            thumbnailSpaceId = space.spaceid
        } else {
            // No cached thumbnail - let the windows-style preview show in the body
            thumbnail = nil
            thumbnailSpaceId = 0
        }
    }
}

struct ContentView: View {
    @EnvironmentObject var spaceModel: SpaceModel
    @AppStorage("showDisplaySeparator") private var showDisplaySeparator = true
    @AppStorage("showCurrentSpaceOnly") private var showCurrentSpaceOnly = false
    @AppStorage("menubarButtonStyle") private var menubarButtonStyle: ButtonStyle = .windows

    var layout: PanelLayout { PanelLayout(from: UserDefaults.standard) }

    private func generateSpaces() -> [Space] {
        var shownSpaces:[Space] = []
        var lastDisplay = 0
        for space in spaceModel.spaces {
            if lastDisplay > 0 && space.display != lastDisplay {
                if showDisplaySeparator {
                    shownSpaces.append(Space(spaceid: 0, uuid: "", visible: true, active: false, display: 0, index: 0, yabaiIndex: 0, type: .divider))
                }
            }
            if space.visible || !showCurrentSpaceOnly{
                shownSpaces.append(space)
            }
            lastDisplay = space.display
        }
        return shownSpaces
    }

    var body: some View {
        LazyVGrid(columns: layout.columns, spacing: layout.rowSpacing) {
            if menubarButtonStyle == .numeric || spaceModel.displays.count > 0 {
                ForEach(generateSpaces(), id: \.self) {space in
                    switch menubarButtonStyle {
                    case .numeric:
                        SpaceButton(space: space, layout: layout)
                    case .windows:
                        WindowSpaceButton(space: space, windows: spaceModel.windows.filter{$0.spaceIndex == space.yabaiIndex}, displays: spaceModel.displays, layout: layout)
                    case .thumbnail:
                        ThumbnailSpaceButton(space: space, windows: spaceModel.windows.filter{$0.spaceIndex == space.yabaiIndex}, displays: spaceModel.displays, layout: layout)
                    }
                }
            }
        }.padding(layout.padding)
    }
}

// Dedicated menubar view - matches original pre-panel ContentView
// This can be easily merged with upstream if needed
struct MenubarView: View {
    @EnvironmentObject var spaceModel: SpaceModel
    @AppStorage("showDisplaySeparator") private var showDisplaySeparator = true
    @AppStorage("showCurrentSpaceOnly") private var showCurrentSpaceOnly = false
    // Read from menubarButtonStyle for compatibility
    @AppStorage("menubarButtonStyle") private var menubarButtonStyle: ButtonStyle = .windows

    private func generateSpaces() -> [Space] {
        var shownSpaces:[Space] = []
        var lastDisplay = 0
        for space in spaceModel.spaces {
            if lastDisplay > 0 && space.display != lastDisplay {
                if showDisplaySeparator {
                    shownSpaces.append(Space(spaceid: 0, uuid: "", visible: true, active: false, display: 0, index: 0, yabaiIndex: 0, type: .divider))
                }
            }
            if space.visible || !showCurrentSpaceOnly{
                shownSpaces.append(space)
            }
            lastDisplay = space.display
        }
        return shownSpaces
    }

    var body: some View {
        HStack(spacing: 4) {
            if menubarButtonStyle == .numeric || spaceModel.displays.count > 0 {
                ForEach(generateSpaces(), id: \.self) { space in
                    switch menubarButtonStyle {
                    case .numeric:
                        SpaceButton(space: space)
                    case .windows:
                        WindowSpaceButton(space: space, windows: spaceModel.windows.filter{$0.spaceIndex == space.yabaiIndex}, displays: spaceModel.displays)
                    case .thumbnail:
                        // Thumbnail style not in original - fall back to windows
                        WindowSpaceButton(space: space, windows: spaceModel.windows.filter{$0.spaceIndex == space.yabaiIndex}, displays: spaceModel.displays)
                    }
                }
            }
        }.padding(2)
    }
}

// Legacy StatusBarView (no longer used - kept for reference)
struct StatusBarView: View {
    @EnvironmentObject var spaceModel: SpaceModel
    @AppStorage("menubarButtonStyle") private var menubarButtonStyle: ButtonStyle = .windows

    var body: some View {
        HStack(spacing: 2) {
            ForEach(spaceModel.spaces.filter({ $0.visible }), id: \.self) { space in
                if space.type == .standard {
                    Text("\(space.index)")
                        .font(.system(size: 11, weight: space.active ? .bold : .regular))
                        .foregroundColor(.white)
                }
            }
        }
        .frame(height: 22)
        .background(Color.blue.opacity(0.6))
        .cornerRadius(4)
        .onTapGesture {
            HotkeyManager.shared.execute(.toggle(.atMouse(NSEvent.mouseLocation)))
        }
    }
}

// Panel content with context menu for right-click
struct PanelContentView: View {
    @EnvironmentObject var spaceModel: SpaceModel
    @AppStorage("showDisplaySeparator") private var showDisplaySeparator = true

    @State private var selectedSpaceIndex: Int? = nil  // Track keyboard-selected space

    // Panel always uses thumbnail style (hybrid preview with window outlines)
    private let panelButtonStyle: ButtonStyle = .thumbnail

    var layout: PanelLayout { PanelLayout(from: UserDefaults.standard) }

    private func generateSpaces() -> [Space] {
        var shownSpaces:[Space] = []
        var lastDisplay = 0
        for space in spaceModel.spaces {
            if lastDisplay > 0 && space.display != lastDisplay {
                if showDisplaySeparator {
                    shownSpaces.append(Space(spaceid: 0, uuid: "", visible: true, active: false, display: 0, index: 0, yabaiIndex: 0, type: .divider))
                }
            }
            // Panel always shows all spaces (ignoring showCurrentSpaceOnly setting)
            shownSpaces.append(space)
            lastDisplay = space.display
        }
        return shownSpaces
    }

    // Get only navigable spaces (exclude dividers) for keyboard navigation
    private func getNavigableSpaces() -> [Space] {
        return generateSpaces().filter { $0.type != .divider }
    }

    var body: some View {
        let spaces = generateSpaces()
        let navigableSpaces = spaces.filter { $0.type != .divider }

        LazyVGrid(columns: layout.columns, spacing: layout.rowSpacing) {
            if panelButtonStyle == .numeric || spaceModel.displays.count > 0 {
                ForEach(Array(spaces.enumerated()), id: \.element) { index, space in
                    // Calculate navigable index for this space
                    let navigableIndex = navigableSpaces.firstIndex(where: { $0.spaceid == space.spaceid && $0.type != .divider })

                    Group {
                        switch panelButtonStyle {
                        case .numeric:
                            SpaceButton(space: space, layout: layout)
                        case .windows:
                            WindowSpaceButton(space: space, windows: spaceModel.windows.filter{$0.spaceIndex == space.yabaiIndex}, displays: spaceModel.displays, layout: layout)
                        case .thumbnail:
                            ThumbnailSpaceButton(
                                space: space,
                                windows: spaceModel.windows.filter{$0.spaceIndex == space.yabaiIndex},
                                displays: spaceModel.displays,
                                layout: layout,
                                isSelected: navigableIndex == selectedSpaceIndex
                            )
                        }
                    }
                }
            }
        }
        .padding(layout.padding)
        .onReceive(NotificationCenter.default.publisher(for: YabaiAppDelegate.panelNavigationNotification)) { notification in
            if let index = notification.userInfo?["selectedIndex"] as? Int {
                selectedSpaceIndex = index >= 0 ? index : nil
            }
        }
        .contextMenu {
            Button("Preferences...") {
                NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
                NSApp.activate(ignoringOtherApps: true)
            }
            Button("Toggle Button Style") {
                let currentStyle = UserDefaults.standard.buttonStyle
                let newStyle: ButtonStyle
                switch currentStyle {
                case .numeric: newStyle = .windows
                case .windows: newStyle = .thumbnail
                case .thumbnail: newStyle = .numeric
                }
                UserDefaults.standard.set(newStyle.rawValue, forKey: "buttonStyle")
            }
            Divider()
            Button("Quit YabaiIndicator") {
                NSApp.terminate(nil)
            }
        }
    }
}
