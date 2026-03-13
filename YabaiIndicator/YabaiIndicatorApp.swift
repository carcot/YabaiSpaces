//
//  YabaiIndicatorApp.swift
//  YabaiIndicator
//
//  Created by Max Zhao on 26/12/2021.
//

import SwiftUI

// Global reference to app delegate for access from SwiftUI views
var gAppDelegate: YabaiAppDelegate!

@main
struct YabaiIndicatorApp: App {
    @NSApplicationDelegateAdaptor(YabaiAppDelegate.self) var appDelegate


    init() {
        // Set global reference for access from views
        gAppDelegate = appDelegate
    }
    
    var body: some Scene {
        Settings {
            SettingsView()
        }

    }
}
