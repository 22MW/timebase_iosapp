import SwiftUI

struct EntryReviewView: View {
    @Environment(\.dismiss) private var dismiss
    let project: TimebaseProject
    let sessions: [PreparedSession]
    @State private var description: String

    init(project: TimebaseProject, sessions: [PreparedSession], suggestedDescription: String) {
        self.project = project
        self.sessions = sessions
        _description = State(initialValue: suggestedDescription)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Revisar entradas")
                        .font(.title2.bold())
                    Text("\(project.clientName) · \(project.name)")
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button("Cerrar") { dismiss() }
            }

            GroupBox("Sesiones propuestas") {
                VStack(spacing: 0) {
                    ForEach(Array(sessions.enumerated()), id: \.element.id) { index, session in
                        HStack {
                            VStack(alignment: .leading, spacing: 3) {
                                Text("Sesión \(index + 1)").fontWeight(.semibold)
                                Text(session.startedAt.formatted(date: .abbreviated, time: .shortened))
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                            Text("\(session.startedAt.formatted(date: .omitted, time: .shortened))–\(session.calculatedEnd.formatted(date: .omitted, time: .shortened))")
                                .foregroundStyle(.secondary)
                            Text(durationText(session.duration))
                                .monospacedDigit().fontWeight(.semibold)
                                .frame(width: 72, alignment: .trailing)
                        }
                        .padding(.vertical, 9)
                        if index < sessions.count - 1 { Divider() }
                    }
                }
                .padding(.horizontal, 6)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Descripción general").font(.headline)
                TextEditor(text: $description)
                    .font(.body)
                    .frame(minHeight: 90)
                    .padding(6)
                    .background(.quaternary.opacity(0.25), in: RoundedRectangle(cornerRadius: 8))
                Text("Puedes modificarla antes de enviar. Los títulos y URLs detallados permanecen en este Mac.")
                    .font(.caption).foregroundStyle(.secondary)
            }

            HStack {
                Label("Modo de revisión: no se enviará nada", systemImage: "lock.shield")
                    .foregroundStyle(.secondary)
                Spacer()
                Text(durationText(sessions.reduce(0) { $0 + $1.duration }))
                    .font(.title3.monospacedDigit().bold())
                Button("Enviar a Timebase") { }
                    .buttonStyle(.borderedProminent)
                    .disabled(true)
                    .help("Se activará después de validar esta pantalla")
            }
        }
        .padding(24)
        .frame(minWidth: 650, minHeight: 540)
    }

    private func durationText(_ duration: TimeInterval) -> String {
        let minutes = Int(duration / 60)
        return minutes >= 60 ? "\(minutes / 60) h \(minutes % 60) min" : "\(minutes) min"
    }
}
