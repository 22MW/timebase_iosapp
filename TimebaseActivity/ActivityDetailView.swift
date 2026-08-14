import SwiftUI

struct ActivityDetailView: View {
    @EnvironmentObject private var monitor: ActivityMonitor

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                header

                if !monitor.hasAccessibilityPermission {
                    permissionNotice
                }

                if let snapshot = monitor.snapshot {
                    activityDetails(snapshot)
                } else {
                    ContentUnavailableView(
                        "Sin actividad",
                        systemImage: "clock.badge.questionmark",
                        description: Text("Esperando la primera lectura del sistema.")
                    )
                }

                localHistory

                Spacer(minLength: 0)
            }
            .padding(24)
        }
        .frame(minWidth: 560, minHeight: 390)
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Timebase Activity")
                    .font(.title2.bold())
                Text("Vista en directo · guardado únicamente en este Mac")
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button(monitor.isPaused ? "Reanudar" : "Pausar") {
                monitor.togglePause()
            }
            .buttonStyle(.borderedProminent)
        }
    }

    private var permissionNotice: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "hand.raised.fill")
                .foregroundStyle(.orange)
            VStack(alignment: .leading, spacing: 6) {
                Text("Falta permiso de Accesibilidad")
                    .font(.headline)
                Text("Concédelo a TimebaseActivity para leer el título de la ventana activa.")
                    .foregroundStyle(.secondary)
                Button("Solicitar permiso") {
                    monitor.requestAccessibilityIfNeeded()
                }
            }
        }
        .padding()
        .background(.orange.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))
    }

    private func activityDetails(_ snapshot: ActivitySnapshot) -> some View {
        Grid(alignment: .leading, horizontalSpacing: 20, verticalSpacing: 14) {
            row("Aplicación", snapshot.applicationName)
            row("Ventana", snapshot.windowTitle ?? "—")

            if let tab = snapshot.browserTab {
                row("Pestaña", tab.title)
                row("Dominio", tab.domain ?? "—")
                row("URL", tab.url?.absoluteString ?? "—")
            } else if let error = snapshot.browserError {
                row("Automatización", error)
            }

            row("Estado", snapshot.isIdle ? "Inactivo" : "Activo")
            row("Sin interacción", "\(Int(snapshot.idleSeconds)) segundos")
        }
        .textSelection(.enabled)
        .padding()
        .background(.quaternary.opacity(0.45), in: RoundedRectangle(cornerRadius: 14))
    }

    private func row(_ label: String, _ value: String) -> some View {
        GridRow {
            Text(label)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)
            Text(value)
                .lineLimit(2)
        }
    }

    private var localHistory: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Actividad reciente")
                    .font(.headline)
                Spacer()
                Text("\(monitor.activityStore.groupedActivities.count) actividades")
                    .foregroundStyle(.secondary)
            }

            if let error = monitor.activityStore.storageError {
                Label(error, systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
            } else if monitor.activityStore.segments.isEmpty {
                Text("Todavía no hay actividad guardada.")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(monitor.activityStore.groupedActivities.suffix(5).reversed()) { group in
                    activityGroup(group)
                }
            }
        }
        .padding()
        .background(.quaternary.opacity(0.25), in: RoundedRectangle(cornerRadius: 14))
    }

    private func activityGroup(_ group: ActivityGroup) -> some View {
        DisclosureGroup {
            ForEach(group.segments) { segment in
                HStack {
                    Text(segment.tabTitle ?? segment.windowTitle ?? "Sin título")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                    Spacer()
                    Text(durationText(segment.duration))
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
                .padding(.leading, 18)
            }
        } label: {
            HStack(spacing: 10) {
                Circle()
                    .fill(group.isIdle ? .gray : .green)
                    .frame(width: 8, height: 8)
                VStack(alignment: .leading, spacing: 2) {
                    Text(group.title)
                        .lineLimit(1)
                    Text(group.segments.count == 1
                         ? (group.segments[0].tabTitle ?? group.segments[0].windowTitle ?? "Sin título")
                         : "\(group.segments.count) pestañas o segmentos")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Spacer()
                Text(durationText(group.duration))
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func durationText(_ duration: TimeInterval) -> String {
        let seconds = Int(duration.rounded(.down))
        return String(format: "%02d:%02d", seconds / 60, seconds % 60)
    }
}
