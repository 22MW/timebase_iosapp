import SwiftUI

struct ProjectPickerView: View {
    private struct ClientOption: Identifiable {
        let id: String
        let name: String
    }

    @Environment(\.dismiss) private var dismiss
    @ObservedObject var loader: ProjectLoader
    let onSelect: (TimebaseProject) -> Void
    @State private var selectedClientID = ""
    @State private var selectedProjectID = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                Text("Elegir proyecto de Timebase")
                    .font(.title2.bold())
                Spacer()
                Button("Cancelar") { dismiss() }
            }

            if loader.isLoading {
                ProgressView("Cargando clientes y proyectos…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let error = loader.errorMessage {
                ContentUnavailableView {
                    Label("No se pudieron cargar los proyectos", systemImage: "exclamationmark.triangle")
                } description: {
                    Text(error)
                } actions: {
                    Button("Reintentar") { Task { await loader.load() } }
                }
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Cliente").font(.headline)
                    Picker("Cliente", selection: $selectedClientID) {
                        Text("Selecciona un cliente").tag("")
                        ForEach(clients) { client in
                            Text(client.name).tag(client.id)
                        }
                    }
                    .labelsHidden()
                    .frame(maxWidth: .infinity)
                    .onChange(of: selectedClientID) { _, _ in
                        selectedProjectID = ""
                    }
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Proyecto").font(.headline)
                    Picker("Proyecto", selection: $selectedProjectID) {
                        Text("Selecciona un proyecto").tag("")
                        ForEach(projectsForSelectedClient) { project in
                            Text(project.name).tag(project.id)
                        }
                    }
                    .labelsHidden()
                    .frame(maxWidth: .infinity)
                    .disabled(selectedClientID.isEmpty)
                }

                Spacer()

                Button("Usar este proyecto") {
                    guard let project = selectedProject else { return }
                    onSelect(project)
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .frame(maxWidth: .infinity)
                .disabled(selectedProject == nil)
            }
        }
        .padding(24)
        .frame(minWidth: 480, minHeight: 340)
        .task { await loader.load() }
    }

    private var clients: [ClientOption] {
        var seen: Set<String> = []
        return loader.projects.compactMap { project in
            guard seen.insert(project.clientID).inserted else { return nil }
            return ClientOption(id: project.clientID, name: project.clientName)
        }
    }

    private var projectsForSelectedClient: [TimebaseProject] {
        loader.projects.filter { $0.clientID == selectedClientID }
    }

    private var selectedProject: TimebaseProject? {
        projectsForSelectedClient.first { $0.id == selectedProjectID }
    }
}
