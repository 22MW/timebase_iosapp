import SwiftUI

struct EntryReviewView: View {
    private struct SessionDraft: Identifiable {
        let id: UUID
        let session: PreparedSession
        var description: String
    }

    @Environment(\.dismiss) private var dismiss
    let project: TimebaseProject
    @State private var drafts: [SessionDraft]

    init(project: TimebaseProject, sessions: [PreparedSession]) {
        self.project = project
        _drafts = State(initialValue: sessions.map { session in
            SessionDraft(
                id: session.id,
                session: session,
                description: PreparedEntryBuilder.suggestedDescription(from: session.segments)
            )
        })
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

            ScrollView {
                VStack(spacing: 12) {
                    ForEach(Array(drafts.indices), id: \.self) { index in
                        let session = drafts[index].session
                        GroupBox {
                            VStack(alignment: .leading, spacing: 10) {
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

                                Text("Descripción").font(.caption).foregroundStyle(.secondary)
                                TextEditor(text: $drafts[index].description)
                                    .font(.body)
                                    .frame(minHeight: 65)
                                    .padding(6)
                                    .background(.quaternary.opacity(0.25), in: RoundedRectangle(cornerRadius: 8))
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }
            }
            Text("Cada sesión tendrá su propia descripción. Los títulos y URLs detallados permanecen en este Mac.")
                .font(.caption).foregroundStyle(.secondary)

            HStack {
                Label("Modo de revisión: no se enviará nada", systemImage: "lock.shield")
                    .foregroundStyle(.secondary)
                Spacer()
                Text(durationText(drafts.reduce(0) { $0 + $1.session.duration }))
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
