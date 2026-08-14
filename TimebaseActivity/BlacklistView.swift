import SwiftUI

struct BlacklistView: View {
    private struct ApplicationOption: Identifiable {
        let id: String
        let name: String
    }

    @Environment(\.dismiss) private var dismiss
    @ObservedObject var activityStore: ActivityStore
    @State private var searchText = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Aplicaciones excluidas").font(.title2.bold())
                    Text("No aparecerán para seleccionar ni contarán como tiempo disponible.")
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button("Cerrar") { dismiss() }
            }

            TextField("Buscar aplicación", text: $searchText)
                .textFieldStyle(.roundedBorder)

            List(filteredApplications) { application in
                Toggle(isOn: blacklistBinding(application.id)) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(application.name)
                        Text(application.id).font(.caption).foregroundStyle(.secondary)
                    }
                }
                .toggleStyle(.checkbox)
            }
            .listStyle(.inset)
        }
        .padding(20)
        .frame(minWidth: 520, minHeight: 460)
    }

    private var applications: [ApplicationOption] {
        var names: [String: String] = [:]
        for segment in activityStore.segments {
            guard let identifier = segment.bundleIdentifier,
                  identifier != "online.22mw.timebase.activity" else { continue }
            names[identifier] = segment.applicationName
        }
        return names.map { ApplicationOption(id: $0.key, name: $0.value) }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    private var filteredApplications: [ApplicationOption] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return applications }
        return applications.filter {
            $0.name.localizedCaseInsensitiveContains(query)
                || $0.id.localizedCaseInsensitiveContains(query)
        }
    }

    private func blacklistBinding(_ bundleIdentifier: String) -> Binding<Bool> {
        Binding(
            get: { activityStore.blacklistedBundleIDs.contains(bundleIdentifier) },
            set: { activityStore.setBlacklisted($0, bundleIdentifier: bundleIdentifier) }
        )
    }
}
