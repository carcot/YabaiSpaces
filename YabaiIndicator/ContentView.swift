//
//  ContentView.swift
//  YabaiIndicator
//
//  Created by Max Zhao on 26/12/2021.
//

import SwiftUI
import AppKit

// Reference to app delegate for accessing panel
var appDelegate: YabaiAppDelegate {
    return NSApp.delegate as! YabaiAppDelegate
}

struct SpaceButton : View {
    var space: Space
    
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
            Image(nsImage: generateImage(symbol: getText() as NSString, active: space.active, visible: space.visible)).onTapGesture {
                switchSpace()
            }.frame(width:28, height: 20)
        }
    }
}

struct WindowSpaceButton : View {
    var space: Space
    var windows: [Window]
    var displays: [Display]

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
                Image(nsImage: generateImage(active: space.active, visible: space.visible, windows: windows, display: displays[displayIndex])).onTapGesture {
                    switchSpace()
                }.frame(width:28, height: 20)
            } else {
                // Fallback to numeric style if display data is invalid
                Image(nsImage: generateImage(symbol: "\(space.index)" as NSString, active: space.active, visible: space.visible)).onTapGesture {
                    switchSpace()
                }.frame(width:28, height: 20)
            }
        case .fullscreen:
            Image(nsImage: generateImage(symbol: "F" as NSString, active: space.active, visible: space.visible)).onTapGesture {
                switchSpace()
            }
        case .divider:
            Divider().background(Color(.systemGray)).frame(height: 14)
        }
    }
}

struct ContentView: View {
    @EnvironmentObject var spaceModel: SpaceModel
    @AppStorage("showDisplaySeparator") private var showDisplaySeparator = true
    @AppStorage("showCurrentSpaceOnly") private var showCurrentSpaceOnly = false
    @AppStorage("buttonStyle") private var buttonStyle: ButtonStyle = .numeric

    let columns = [
        GridItem(.fixed(32), spacing: 2),
        GridItem(.fixed(32), spacing: 2),
        GridItem(.fixed(32), spacing: 2),
        GridItem(.fixed(32), spacing: 2)
    ]

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
        LazyVGrid(columns: columns, spacing: 4) {
            if buttonStyle == .numeric || spaceModel.displays.count > 0 {
                ForEach(generateSpaces(), id: \.self) {space in
                    switch buttonStyle {
                    case .numeric:
                        SpaceButton(space: space)
                    case .windows:
                        WindowSpaceButton(space: space, windows: spaceModel.windows.filter{$0.spaceIndex == space.yabaiIndex}, displays: spaceModel.displays)
                    }
                }
            }
        }.padding(4)
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

    let columns = [
        GridItem(.fixed(32), spacing: 2),
        GridItem(.fixed(32), spacing: 2),
        GridItem(.fixed(32), spacing: 2),
        GridItem(.fixed(32), spacing: 2)
    ]

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
        LazyVGrid(columns: columns, spacing: 4) {
            if buttonStyle == .numeric || spaceModel.displays.count > 0 {
                ForEach(generateSpaces(), id: \.self) {space in
                    switch buttonStyle {
                    case .numeric:
                        SpaceButton(space: space)
                    case .windows:
                        WindowSpaceButton(space: space, windows: spaceModel.windows.filter{$0.spaceIndex == space.yabaiIndex}, displays: spaceModel.displays)
                    }
                }
            }
        }
        .padding(4)
        .contextMenu {
            Button("Preferences...") {
                NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
                NSApp.activate(ignoringOtherApps: true)
            }
            Button("Toggle Button Style") {
                let currentStyle = UserDefaults.standard.buttonStyle
                let newStyle: ButtonStyle = currentStyle == .numeric ? .windows : .numeric
                UserDefaults.standard.set(newStyle.rawValue, forKey: "buttonStyle")
            }
            Divider()
            Button("Quit YabaiIndicator") {
                NSApp.terminate(nil)
            }
        }
    }
}
