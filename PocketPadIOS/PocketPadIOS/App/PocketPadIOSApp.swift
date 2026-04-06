// PocketPadIOSApp.swift
// PocketPadIOS
// Main entry point for the iPhone app

import SwiftUI

@main
struct PocketPadIOSApp: App {
    @StateObject private var viewModel = TrackpadViewModel()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(viewModel)
                .preferredColorScheme(nil) // Respect system setting
        }
    }
}
