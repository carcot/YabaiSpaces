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
    @AppStorage("showMenubar") private var showMenubar = true
    @AppStorage("showPanel") private var showPanel = true
    @AppStorage("showDisplaySeparator") private var showDisplaySeparator = true
    @AppStorage("showCurrentSpaceOnly") private var showCurrentSpaceOnly = false

    @AppStorage("buttonStyle") private var buttonStyleRaw = ButtonStyle.windows.rawValue

    @AppStorage("gridPosition") private var gridPosition = GridPosition.atCursor
    @AppStorage("cursorPosition") private var cursorPosition = CursorPosition.onThumbnail
    @AppStorage("saveRestoreCursor") private var saveRestoreCursor = true
    @AppStorage("panelGridAuto") private var panelGridAuto = true
    @AppStorage("panelColumns") private var panelColumns = 4
    @AppStorage("panelRows") private var panelRows = 3

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 8) {
                // Menubar Section
                Toggle("Show Menubar", isOn: $showMenubar)
                    .padding(.leading, 16)

                Toggle("Show Display Separator", isOn: $showDisplaySeparator)
                    .padding(.leading, 32)
                    .disabled(!showMenubar)
                    .opacity(showMenubar ? 1 : 0.4)
                Toggle("Show Current Space Only", isOn: $showCurrentSpaceOnly)
                    .padding(.leading, 32)
                    .disabled(!showMenubar)
                    .opacity(showMenubar ? 1 : 0.4)
                Picker("Button Style", selection: $buttonStyleRaw) {
                    Text("Numeric").tag(ButtonStyle.numeric.rawValue)
                    Text("Windows").tag(ButtonStyle.windows.rawValue)
                    Text("Thumbnail").tag(ButtonStyle.thumbnail.rawValue)
                }
                .pickerStyle(.segmented)
                .padding(.leading, 32)
                .padding(.trailing, 16)
                .disabled(!showMenubar)
                .opacity(showMenubar ? 1 : 0.4)
            }
            .padding(.bottom, 12)

            Rectangle()
                .fill(Color.secondary.opacity(0.3))
                .frame(width: 200, height: 1)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)

            VStack(alignment: .leading, spacing: 8) {
                // Spaces Grid Section
                Toggle("Show Spaces Grid", isOn: $showPanel)
                    .padding(.leading, 16)

                Toggle("Auto-size Grid", isOn: $panelGridAuto)
                    .padding(.leading, 32)
                    .disabled(!showPanel)
                    .opacity(showPanel ? 1 : 0.4)

                HStack(spacing: 16) {
                    // Grid Columns Picker
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Columns")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(.secondary)
                        Picker("", selection: $panelColumns) {
                            ForEach(3...8, id: \.self) { cols in
                                Text("\(cols)").tag(cols)
                            }
                        }
                        .frame(width: 100)
                    }
                    .padding(.leading, 32)

                    // Grid Rows Picker
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Rows")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(.secondary)
                        Picker("", selection: $panelRows) {
                            ForEach(2...5, id: \.self) { rows in
                                Text("\(rows)").tag(rows)
                            }
                        }
                        .frame(width: 100)
                    }
                }
                .disabled(!showPanel || panelGridAuto)
                .opacity((showPanel && !panelGridAuto) ? 1 : 0.4)

                Picker("Grid Position", selection: $gridPosition) {
                    Text("Centered").tag(GridPosition.centered)
                    Text("At Cursor").tag(GridPosition.atCursor)
                }
                .pickerStyle(.segmented)
                .padding(.leading, 32)
                .padding(.trailing, 16)
                .disabled(!showPanel)
                .opacity(showPanel ? 1 : 0.4)
                Picker("Cursor Position", selection: $cursorPosition) {
                    Text("On Active Thumbnail").tag(CursorPosition.onThumbnail)
                    Text("Centered in Grid").tag(CursorPosition.centerGrid)
                    Text("Stay Put").tag(CursorPosition.stayPut)
                }
                .pickerStyle(.segmented)
                .padding(.leading, 32)
                .padding(.trailing, 16)
                .disabled(!showPanel)
                .opacity(showPanel ? 1 : 0.4)
                Toggle("Save and Restore Cursor on Close", isOn: $saveRestoreCursor)
                    .padding(.leading, 32)
                    .disabled(!showPanel)
                    .opacity(showPanel ? 1 : 0.4)
            }
            .padding(.top, 4)
        }
        .padding(12)
    }
}
