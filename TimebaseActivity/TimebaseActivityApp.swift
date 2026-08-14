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
    }
}
