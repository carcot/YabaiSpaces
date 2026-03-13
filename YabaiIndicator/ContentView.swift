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
                        // Show window preview immediately
                        Image(nsImage: generateImage(active: space.active, visible: space.visible, windows: windows, display: display, scale: layout.scale))
                    }
                }
                .onAppear {
                    loadThumbnail(for: space, display: display, windows: windows, size: targetSize)
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
        NSLog("loadThumbnail for space \(space.index) (spaceId: \(space.spaceid))")

        // Check cache first
        if let cached = gThumbnailCache.get(spaceId: space.spaceid) {
            NSLog("  Found cached thumbnail for spaceId: \(space.spaceid)")
            thumbnail = cached
            thumbnailSpaceId = space.spaceid  // Track which space this belongs to
            return
        }

        NSLog("  No cached thumbnail, using preview windows count: \(windows.count)")

        // Generate preview thumbnail asynchronously
        // IMPORTANT: Do NOT cache this - it's not the actual space content, just a preview
        let targetSpaceId = space.spaceid
        DispatchQueue.global(qos: .userInitiated).async {
            let captured = gPrivateWindowCapture.captureSpace(
                windows: windows,
                display: display,
                targetSize: size
            )

            DispatchQueue.main.async {
                if let captured = captured {
                    // Only set if this view is still showing the same space
                    // Check against current state, not the captured space value
                    if self.thumbnailSpaceId == 0 || self.thumbnailSpaceId == targetSpaceId {
                        self.thumbnail = captured
                        self.thumbnailSpaceId = targetSpaceId
                        NSLog("  Captured preview thumbnail (NOT CACHED) for spaceId: \(targetSpaceId)")
                    }
                    // Don't cache - wait for proper capture on space switch
                }
            }
        }
    }
}

struct ContentView: View {
    @EnvironmentObject var spaceModel: SpaceModel
    @AppStorage("showDisplaySeparator") private var showDisplaySeparator = true
    @AppStorage("showCurrentSpaceOnly") private var showCurrentSpaceOnly = false
    @AppStorage("buttonStyle") private var buttonStyle: ButtonStyle = .numeric

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
            if buttonStyle == .numeric || spaceModel.displays.count > 0 {
                ForEach(generateSpaces(), id: \.self) {space in
                    switch buttonStyle {
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

// Simplified view for status bar - shows current space(s)
struct StatusBarView: View {
    @EnvironmentObject var spaceModel: SpaceModel

    var body: some View {
        HStack(spacing: 2) {
            Text("YI")
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(.white)
            ForEach(spaceModel.spaces.prefix(3).filter({ $0.visible }), id: \.self) { space in
                if space.type == .standard {
                    Text("\(space.index)")
                        .font(.system(size: 11))
                        .foregroundColor(.white.opacity(0.7))
                }
            }
        }
        .frame(height: 22)
        .background(Color.blue.opacity(0.6))
        .cornerRadius(4)
        .onTapGesture {
            appDelegate.togglePanel(at: NSEvent.mouseLocation)
        }
    }
}

// Panel content with context menu for right-click
struct PanelContentView: View {
    @EnvironmentObject var spaceModel: SpaceModel
    @AppStorage("buttonStyle") private var buttonStyle: ButtonStyle = .numeric
    @AppStorage("showDisplaySeparator") private var showDisplaySeparator = true
    @AppStorage("showCurrentSpaceOnly") private var showCurrentSpaceOnly = false

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
            if buttonStyle == .numeric || spaceModel.displays.count > 0 {
                ForEach(generateSpaces(), id: \.self) {space in
                    switch buttonStyle {
                    case .numeric:
                        SpaceButton(space: space, layout: layout)
                    case .windows:
                        WindowSpaceButton(space: space, windows: spaceModel.windows.filter{$0.spaceIndex == space.yabaiIndex}, displays: spaceModel.displays, layout: layout)
                    case .thumbnail:
                        ThumbnailSpaceButton(space: space, windows: spaceModel.windows.filter{$0.spaceIndex == space.yabaiIndex}, displays: spaceModel.displays, layout: layout)
                    }
                }
            }
        }
        .padding(layout.padding)
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
