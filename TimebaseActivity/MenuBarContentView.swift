import AppKit
import SwiftUI

struct MenuBarContentView: View {
    @Environment(\.openWindow) private var openWindow
    @EnvironmentObject private var monitor: ActivityMonitor

    var body: some View {
        if let snapshot = monitor.snapshot {
            Text(snapshot.applicationName)
            if let domain = snapshot.browserTab?.domain {
                Text(domain)
                    .foregroundStyle(.secondary)
            }
            Divider()
        }

        Button("Abrir actividad") {
            openWindow(id: "activity")
            NSApplication.shared.activate()
        }

        Button(monitor.isPaused ? "Reanudar seguimiento" : "Pausar seguimiento") {
            monitor.togglePause()
        }

        Divider()

        Button("Salir") {
            NSApplication.shared.terminate(nil)
        }
        .keyboardShortcut("q")
    }
}
