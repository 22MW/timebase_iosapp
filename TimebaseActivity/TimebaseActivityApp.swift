import AppKit
import SwiftUI

@main
struct TimebaseActivityApp: App {
    @StateObject private var monitor = ActivityMonitor()

    var body: some Scene {
        MenuBarExtra {
            MenuBarContentView()
                .environmentObject(monitor)
        } label: {
            Image(systemName: monitor.isPaused ? "pause.circle.fill" : "clock.arrow.circlepath")
        }

        Window("Timebase Activity", id: "activity") {
            ActivityDetailView()
                .environmentObject(monitor)
        }
        .defaultSize(width: 620, height: 440)
        .commands {
            CommandGroup(replacing: .appTermination) {
                Button("Salir de Timebase Activity") {
                    NSApplication.shared.terminate(nil)
                }
                .keyboardShortcut("q")
            }
        }
    }
}
