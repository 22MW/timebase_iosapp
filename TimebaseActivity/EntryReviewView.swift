import SwiftUI

struct EntryReviewView: View {
    private struct SessionDraft: Identifiable {
        let id: UUID
        let session: PreparedSession
        var description: String
    }

    @Environment(\.dismiss) private var dismiss
    @ObservedObject var activityStore: ActivityStore
    let project: TimebaseProject
    @State private var drafts: [SessionDraft]
    @State private var showsSendConfirmation = false
    @State private var isSending = false
    @State private var sentSessionIDs: Set<UUID> = []
    @State private var sendError: String?
    @State private var didFinishSending = false

    init(activityStore: ActivityStore, project: TimebaseProject, sessions: [PreparedSession]) {
        self.activityStore = activityStore
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
                                    if sentSessionIDs.contains(session.id) {
                                        Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
                                    }
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

            if let sendError {
                Label(sendError, systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(.red)
            } else if didFinishSending {
                Label("Entradas creadas correctamente en Timebase.", systemImage: "checkmark.circle.fill")
                    .foregroundStyle(.green)
            }

            HStack {
                Label(isSending ? "Enviando…" : "Se requiere confirmación final", systemImage: "lock.shield")
                    .foregroundStyle(.secondary)
                Spacer()
                Text(durationText(drafts.reduce(0) { $0 + $1.session.duration }))
                    .font(.title3.monospacedDigit().bold())
                Button(didFinishSending ? "Enviado" : "Enviar a Timebase") {
                    showsSendConfirmation = true
                }
                    .buttonStyle(.borderedProminent)
                    .disabled(isSending || didFinishSending || remainingDrafts.isEmpty)
            }
        }
        .padding(24)
        .frame(minWidth: 650, minHeight: 540)
        .alert("¿Crear entradas en Timebase?", isPresented: $showsSendConfirmation) {
            Button("Cancelar", role: .cancel) { }
            Button("Crear \(remainingDrafts.count) entradas") {
                Task { await sendEntries() }
            }
        } message: {
            Text("Se crearán registros reales en \(project.clientName) · \(project.name). Esta acción no se puede deshacer desde la aplicación.")
        }
    }

    private func durationText(_ duration: TimeInterval) -> String {
        let minutes = Int(duration / 60)
        return minutes >= 60 ? "\(minutes / 60) h \(minutes % 60) min" : "\(minutes) min"
    }

    private var remainingDrafts: [SessionDraft] {
        drafts.filter { !sentSessionIDs.contains($0.id) }
    }

    @MainActor
    private func sendEntries() async {
        isSending = true
        sendError = nil
        for draft in remainingDrafts {
            do {
                let entry = try await TimebaseAPIClient().createTimeEntry(
                    projectID: project.id,
                    session: draft.session,
                    description: draft.description
                )
                sentSessionIDs.insert(draft.id)
                activityStore.recordExport(entryID: entry.id, project: project, session: draft.session)
            } catch {
                sendError = "Se enviaron \(sentSessionIDs.count) de \(drafts.count). \(error.localizedDescription)"
                isSending = false
                return
            }
        }
        didFinishSending = true
        isSending = false
    }
}
