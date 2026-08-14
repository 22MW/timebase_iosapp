import Foundation

private let reader = FrontmostActivityReader()
private let formatter = ISO8601DateFormatter()
private let once = CommandLine.arguments.contains("--once")
private var previous: ActivitySnapshot?

print("Timebase Activity Probe")
print("No guarda datos. Pulsa Control+C para terminar.\n")

repeat {
    if let snapshot = reader.capture(), snapshot != previous {
        print("[\(formatter.string(from: snapshot.capturedAt))]")
        print("Aplicación: \(snapshot.applicationName)")
        print("Ventana: \(snapshot.windowTitle ?? "—")")

        if let tab = snapshot.browserTab {
            print("Pestaña: \(tab.title)")
            print("Dominio: \(tab.domain ?? "—")")
            print("URL: \(tab.url?.absoluteString ?? "—")")
        }

        let idleState = snapshot.isIdle ? "inactivo" : "activo"
        print("Estado: \(idleState) · \(Int(snapshot.idleSeconds)) s sin interacción\n")
        previous = snapshot
    }

    if !once {
        Thread.sleep(forTimeInterval: 1)
    }
} while !once
