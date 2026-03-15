//
//  SettingsView.swift
//  YabaiIndicator
//
//  Created by Max Zhao on 1/1/22.
//

import SwiftUI

@objc enum GridPosition: Int, CaseIterable {
    case centered = 0
    case atCursor = 1
}

@objc enum CursorPosition: Int, CaseIterable {
    case stayPut = 0
    case centerGrid = 1
    case onThumbnail = 2
}

struct SettingsView : View {
    @AppStorage("showDisplaySeparator") private var showDisplaySeparator = true
    @AppStorage("showCurrentSpaceOnly") private var showCurrentSpaceOnly = false

    @AppStorage("menubarButtonStyle") private var menubarButtonStyle = ButtonStyle.numeric

    @AppStorage("gridPosition") private var gridPosition = GridPosition.atCursor
    @AppStorage("cursorPosition") private var cursorPosition = CursorPosition.onThumbnail
    @AppStorage("saveRestoreCursor") private var saveRestoreCursor = true

    private enum Tabs: Hashable {
        case menubar, spacesGrid
    }

    var body: some View {
        TabView {
            Form {
                Toggle("Show Display Separator", isOn: $showDisplaySeparator)
                Toggle("Show Current Space Only", isOn: $showCurrentSpaceOnly)
                Picker("Button Style", selection: $menubarButtonStyle) {
                    Text("Numeric").tag(ButtonStyle.numeric)
                    Text("Windows").tag(ButtonStyle.windows)
                }
            }.padding(10)
                .tabItem {
                    Label("Menubar", systemImage: "menubar.rectangle")
                }
                .tag(Tabs.menubar)

            Form {
                Picker("Grid Position", selection: $gridPosition) {
                    Text("Centered").tag(GridPosition.centered)
                    Text("At Cursor").tag(GridPosition.atCursor)
                }
                Picker("Cursor Position", selection: $cursorPosition) {
                    Text("Stay Put").tag(CursorPosition.stayPut)
                    Text("Center in Grid").tag(CursorPosition.centerGrid)
                    Text("On Active Thumbnail").tag(CursorPosition.onThumbnail)
                }
                Toggle("Save and Restore Cursor on Close", isOn: $saveRestoreCursor)
                Text("Panel always shows hybrid preview (window outlines)").font(.caption).foregroundColor(.secondary)
            }.padding(10)
                .tabItem {
                    Label("Spaces Grid", systemImage: "square.grid.3x3")
                }
                .tag(Tabs.spacesGrid)

        }
        .frame(width: 375, height: 180)
    }
}
