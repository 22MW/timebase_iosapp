import SwiftUI

struct ProjectPickerView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var loader: ProjectLoader
    let onSelect: (TimebaseProject) -> Void
    @State private var searchText = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Elegir proyecto de Timebase")
                    .font(.title2.bold())
                Spacer()
                Button("Cancelar") { dismiss() }
            }

            TextField("Buscar cliente o proyecto", text: $searchText)
                .textFieldStyle(.roundedBorder)

            if loader.isLoading {
                ProgressView("Cargando proyectos…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let error = loader.errorMessage {
                ContentUnavailableView {
                    Label("No se pudieron cargar los proyectos", systemImage: "exclamationmark.triangle")
                } description: {
                    Text(error)
                } actions: {
                    Button("Reintentar") { Task { await loader.load() } }
                }
            } else if filteredProjects.isEmpty {
                ContentUnavailableView("No hay proyectos", systemImage: "folder")
            } else {
                List(filteredProjects) { project in
                    Button {
                        onSelect(project)
                        dismiss()
                    } label: {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(project.name)
                            Text(project.clientName)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
                .listStyle(.inset)
            }
        }
        .padding(20)
        .frame(minWidth: 520, minHeight: 460)
        .task { await loader.load() }
    }

    private var filteredProjects: [TimebaseProject] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return loader.projects }
        return loader.projects.filter {
            $0.name.localizedCaseInsensitiveContains(query)
                || $0.clientName.localizedCaseInsensitiveContains(query)
        }
    }
}
