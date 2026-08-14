import SwiftUI

struct ActivityDetailView: View {
    private enum ViewMode: String, CaseIterable, Identifiable {
        case timeline = "Cronología", grouped = "Agrupado", selection = "Selección"
        var id: Self { self }
    }
    private enum ActivityKind: String, CaseIterable, Identifiable {
        case all = "Todo", websites = "Sitios", applications = "Aplicaciones"
        var id: Self { self }
    }
    private enum ActivityStatus: String, CaseIterable, Identifiable {
        case all = "Activo e inactivo", active = "Activo", idle = "Inactivo"
        var id: Self { self }
    }
    private enum SortMode: String, CaseIterable, Identifiable {
        case time = "Hora", duration = "Duración", name = "Nombre"
        var id: Self { self }
    }
    private static let periodOptions = [
        "Rango personalizado", "Hoy", "Ayer", "Esta semana", "La semana pasada",
        "Las últimas dos semanas", "Este mes", "El mes pasado", "Este año", "El año pasado"
    ]

    @EnvironmentObject private var monitor: ActivityMonitor
    @StateObject private var projectLoader = ProjectLoader()
    @State private var selectedSegmentIDs: Set<UUID> = []
    @State private var selectedProject: TimebaseProject?
    @State private var showsProjectPicker = false
    @State private var showsEntryReview = false
    @State private var period = "Hoy"
    @State private var rangeStart = Calendar.current.startOfDay(for: Date())
    @State private var rangeEnd = Calendar.current.startOfDay(for: Date())
    @State private var viewMode = ViewMode.timeline
    @State private var activityKind = ActivityKind.all
    @State private var activityStatus = ActivityStatus.all
    @State private var sortMode = SortMode.time
    @State private var searchText = ""
    @State private var hidesShortActivities = true
    @State private var isLiveExpanded = false

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    header
                    if !monitor.hasAccessibilityPermission { permissionNotice }
                    liveActivity
                    navigation
                    filters
                    activityList
                }
                .padding(20)
            }
            if !selectedSegmentIDs.isEmpty {
                Divider()
                selectionSummary
                    .padding(16)
                    .background(.regularMaterial)
            }
        }
        .frame(minWidth: 720, minHeight: 560)
        .sheet(isPresented: $showsProjectPicker) {
            ProjectPickerView(loader: projectLoader) { project in
                selectedProject = project
            }
        }
        .sheet(isPresented: $showsEntryReview) {
            if let selectedProject {
                EntryReviewView(
                    project: selectedProject,
                    sessions: preparedSessions,
                    suggestedDescription: PreparedEntryBuilder.suggestedDescription(from: selectedSegments)
                )
            }
        }
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 3) {
                Text("Timebase Activity").font(.title2.bold())
                Text("Historial local · todavía no se envía nada a Timebase")
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button(monitor.isPaused ? "Reanudar" : "Pausar") { monitor.togglePause() }
                .buttonStyle(.borderedProminent)
        }
    }

    private var liveActivity: some View {
        DisclosureGroup(isExpanded: $isLiveExpanded) {
            if let snapshot = monitor.snapshot {
                activityDetails(snapshot).padding(.top, 10)
            } else {
                Text("Esperando la primera lectura del sistema.")
                    .foregroundStyle(.secondary).padding(.top, 8)
            }
        } label: {
            HStack {
                Label("Actividad en directo", systemImage: "dot.radiowaves.left.and.right")
                    .font(.headline)
                Spacer()
                if let snapshot = monitor.snapshot {
                    Text(snapshot.browserTab?.domain ?? snapshot.applicationName)
                        .foregroundStyle(.secondary).lineLimit(1)
                }
            }
        }
        .padding()
        .background(.quaternary.opacity(0.25), in: RoundedRectangle(cornerRadius: 12))
    }

    private var navigation: some View {
        VStack(spacing: 12) {
            HStack {
                Text("Periodo").foregroundStyle(.secondary)
                Picker("Periodo", selection: $period) {
                    ForEach(Self.periodOptions, id: \.self) { Text($0).tag($0) }
                }
                .labelsHidden()
                .frame(width: 210)
                .onChange(of: period) { _, newPeriod in
                    updateRange(for: newPeriod)
                }

                if period == "Rango personalizado" {
                    DatePicker("Desde", selection: $rangeStart, in: ...rangeEnd, displayedComponents: .date)
                    DatePicker("Hasta", selection: $rangeEnd, in: rangeStart..., displayedComponents: .date)
                } else {
                    Text(periodRangeText).foregroundStyle(.secondary)
                }
                Spacer()
                Text("\(visibleGroups.count) actividades").foregroundStyle(.secondary)
            }
            Picker("Vista", selection: $viewMode) {
                ForEach(ViewMode.allCases) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)
        }
    }

    private var filters: some View {
        VStack(spacing: 10) {
            HStack {
                TextField("Buscar título, dominio, aplicación o URL", text: $searchText)
                    .textFieldStyle(.roundedBorder)
                Picker("Tipo", selection: $activityKind) {
                    ForEach(ActivityKind.allCases) { Text($0.rawValue).tag($0) }
                }.frame(width: 140)
                Picker("Estado", selection: $activityStatus) {
                    ForEach(ActivityStatus.allCases) { Text($0.rawValue).tag($0) }
                }.frame(width: 165)
            }
            HStack {
                Toggle("Ocultar menos de 10 segundos", isOn: $hidesShortActivities)
                    .toggleStyle(.checkbox)
                Spacer()
                Text("Ordenar por").foregroundStyle(.secondary)
                Picker("Orden", selection: $sortMode) {
                    ForEach(SortMode.allCases) { Text($0.rawValue).tag($0) }
                }.labelsHidden().frame(width: 125)
            }
        }
        .padding()
        .background(.quaternary.opacity(0.18), in: RoundedRectangle(cornerRadius: 12))
    }

    private var activityList: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let error = monitor.activityStore.storageError {
                Label(error, systemImage: "exclamationmark.triangle.fill").foregroundStyle(.orange)
            } else if visibleGroups.isEmpty {
                ContentUnavailableView(
                    viewMode == .selection ? "No hay actividades seleccionadas" : "No hay resultados",
                    systemImage: "line.3.horizontal.decrease.circle",
                    description: Text("Cambia la fecha o modifica los filtros.")
                )
            } else {
                ForEach(visibleGroups) { group in
                    activityGroup(group)
                    Divider()
                }
            }
        }
        .padding()
        .background(.quaternary.opacity(0.25), in: RoundedRectangle(cornerRadius: 14))
    }

    private var permissionNotice: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "hand.raised.fill").foregroundStyle(.orange)
            VStack(alignment: .leading, spacing: 6) {
                Text("Falta permiso de Accesibilidad").font(.headline)
                Text("Concédelo a TimebaseActivity para leer el título de la ventana activa.")
                    .foregroundStyle(.secondary)
                Button("Solicitar permiso") { monitor.requestAccessibilityIfNeeded() }
            }
        }
        .padding()
        .background(.orange.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))
    }

    private func activityDetails(_ snapshot: ActivitySnapshot) -> some View {
        Grid(alignment: .leading, horizontalSpacing: 20, verticalSpacing: 10) {
            row("Aplicación", snapshot.applicationName)
            row("Ventana", snapshot.windowTitle ?? "—")
            if let tab = snapshot.browserTab {
                row("Pestaña", tab.title)
                row("Dominio", tab.domain ?? "—")
                row("URL", tab.url?.absoluteString ?? "—")
            } else if let error = snapshot.browserError { row("Automatización", error) }
            row("Estado", snapshot.isIdle ? "Inactivo" : "Activo")
            row("Sin interacción", "\(Int(snapshot.idleSeconds)) segundos")
        }.textSelection(.enabled)
    }

    private func row(_ label: String, _ value: String) -> some View {
        GridRow {
            Text(label).fontWeight(.semibold).foregroundStyle(.secondary)
            Text(value).lineLimit(2)
        }
    }

    private func activityGroup(_ group: ActivityGroup) -> some View {
        DisclosureGroup {
            ForEach(group.segments) { segment in
                HStack {
                    selectionButton(for: [segment.id])
                    Text(segment.tabTitle ?? segment.windowTitle ?? "Sin título")
                        .font(.caption).foregroundStyle(.secondary).lineLimit(1)
                    Spacer()
                    Text(segment.startedAt, style: .time)
                        .font(.caption.monospacedDigit()).foregroundStyle(.tertiary)
                    Text(durationText(segment.duration))
                        .font(.caption.monospacedDigit()).foregroundStyle(.secondary)
                        .frame(width: 58, alignment: .trailing)
                }.padding(.leading, 18)
            }
        } label: {
            HStack(spacing: 10) {
                selectionButton(for: group.segments.map(\.id))
                Circle().fill(group.isIdle ? .gray : .green).frame(width: 8, height: 8)
                VStack(alignment: .leading, spacing: 2) {
                    Text(group.title).lineLimit(1)
                    Text(group.segments.count == 1
                         ? (group.segments[0].tabTitle ?? group.segments[0].windowTitle ?? "Sin título")
                         : "\(group.segments.count) pestañas o segmentos")
                        .font(.caption).foregroundStyle(.secondary).lineLimit(1)
                }
                Spacer()
                Text(group.startedAt, style: .time).monospacedDigit().foregroundStyle(.tertiary)
                Text(durationText(group.duration)).monospacedDigit().foregroundStyle(.secondary)
                    .frame(width: 64, alignment: .trailing)
            }
        }
    }

    private var selectionSummary: some View {
        HStack(spacing: 18) {
            VStack(alignment: .leading, spacing: 3) {
                Text("Selección preparada").font(.headline)
                Text("\(selectedSegments.count) segmentos · \(preparedSessionCount) sesiones · huecos no incluidos")
                    .font(.caption).foregroundStyle(.secondary)
                if let selectedProject {
                    Text("\(selectedProject.clientName) · \(selectedProject.name)")
                        .font(.caption).foregroundStyle(.blue)
                }
            }
            Spacer()
            Text(durationText(selectedDuration)).font(.title3.monospacedDigit().bold())
            Button("Limpiar") { selectedSegmentIDs.removeAll() }
            Button(selectedProject == nil ? "Elegir proyecto" : "Cambiar proyecto") {
                showsProjectPicker = true
            }
            .buttonStyle(.borderedProminent)
            if selectedProject != nil {
                Button("Revisar entradas") {
                    showsEntryReview = true
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding()
        .background(.blue.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))
    }

    private var dateGroups: [ActivityGroup] {
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: rangeStart)
        let end = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: rangeEnd)) ?? rangeEnd
        return monitor.activityStore.groupedActivities.filter {
            $0.startedAt >= start && $0.startedAt < end
        }
    }

    private var visibleGroups: [ActivityGroup] {
        var groups = dateGroups.filter(matchesFilters)
        if viewMode == .grouped {
            groups = aggregate(groups)
        } else if viewMode == .selection {
            groups = groups.filter { group in group.segments.contains { selectedSegmentIDs.contains($0.id) } }
        }
        switch sortMode {
        case .time: return groups.sorted { $0.startedAt > $1.startedAt }
        case .duration: return groups.sorted { $0.duration > $1.duration }
        case .name: return groups.sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
        }
    }

    private func matchesFilters(_ group: ActivityGroup) -> Bool {
        if hidesShortActivities && group.duration < 10 { return false }
        if activityKind == .websites && group.domain == nil { return false }
        if activityKind == .applications && group.domain != nil { return false }
        if activityStatus == .active && group.isIdle { return false }
        if activityStatus == .idle && !group.isIdle { return false }
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return true }
        return group.segments.contains { segment in
            [segment.applicationName, segment.windowTitle, segment.tabTitle, segment.domain,
             segment.url?.absoluteString].compactMap { $0 }
                .contains { $0.localizedCaseInsensitiveContains(query) }
        }
    }

    private func aggregate(_ groups: [ActivityGroup]) -> [ActivityGroup] {
        var result: [ActivityGroup] = []
        var indexes: [String: Int] = [:]
        for group in groups.sorted(by: { $0.startedAt < $1.startedAt }) {
            let key = "\(group.isIdle)|\(group.domain ?? group.applicationName)"
            if let index = indexes[key],
               group.startedAt.timeIntervalSince(result[index].endedAt) <= 30 * 60 {
                result[index].segments.append(contentsOf: group.segments)
            } else {
                indexes[key] = result.count
                result.append(group)
            }
        }
        return result
    }

    private var selectedSegments: [ActivitySegment] {
        monitor.activityStore.segments.filter { selectedSegmentIDs.contains($0.id) }
            .sorted { $0.startedAt < $1.startedAt }
    }
    private var selectedDuration: TimeInterval { selectedSegments.reduce(0) { $0 + $1.duration } }
    private var preparedSessions: [PreparedSession] {
        PreparedEntryBuilder.sessions(from: selectedSegments)
    }
    private var preparedSessionCount: Int {
        preparedSessions.count
    }

    private func selectionButton(for ids: [UUID]) -> some View {
        let isSelected = ids.allSatisfy(selectedSegmentIDs.contains)
        return Button {
            if isSelected { selectedSegmentIDs.subtract(ids) } else { selectedSegmentIDs.formUnion(ids) }
        } label: {
            Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                .foregroundStyle(isSelected ? .blue : .secondary)
        }.buttonStyle(.plain)
    }

    private var periodRangeText: String {
        if Calendar.current.isDate(rangeStart, inSameDayAs: rangeEnd) {
            return rangeStart.formatted(date: .long, time: .omitted)
        }
        return "\(rangeStart.formatted(date: .abbreviated, time: .omitted)) – \(rangeEnd.formatted(date: .abbreviated, time: .omitted))"
    }

    private func updateRange(for newPeriod: String) {
        guard newPeriod != "Rango personalizado" else { return }
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        switch newPeriod {
        case "Rango personalizado":
            break
        case "Hoy":
            rangeStart = today; rangeEnd = today
        case "Ayer":
            let day = calendar.date(byAdding: .day, value: -1, to: today) ?? today
            rangeStart = day; rangeEnd = day
        case "Esta semana":
            let start = calendar.dateInterval(of: .weekOfYear, for: today)?.start ?? today
            rangeStart = start; rangeEnd = today
        case "La semana pasada":
            let thisStart = calendar.dateInterval(of: .weekOfYear, for: today)?.start ?? today
            rangeStart = calendar.date(byAdding: .weekOfYear, value: -1, to: thisStart) ?? today
            rangeEnd = calendar.date(byAdding: .day, value: -1, to: thisStart) ?? today
        case "Las últimas dos semanas":
            rangeStart = calendar.date(byAdding: .day, value: -13, to: today) ?? today
            rangeEnd = today
        case "Este mes":
            rangeStart = calendar.dateInterval(of: .month, for: today)?.start ?? today
            rangeEnd = today
        case "El mes pasado":
            let thisStart = calendar.dateInterval(of: .month, for: today)?.start ?? today
            let lastStart = calendar.date(byAdding: .month, value: -1, to: thisStart) ?? today
            rangeStart = lastStart
            rangeEnd = calendar.date(byAdding: .day, value: -1, to: thisStart) ?? today
        case "Este año":
            rangeStart = calendar.dateInterval(of: .year, for: today)?.start ?? today
            rangeEnd = today
        case "El año pasado":
            let thisStart = calendar.dateInterval(of: .year, for: today)?.start ?? today
            rangeStart = calendar.date(byAdding: .year, value: -1, to: thisStart) ?? today
            rangeEnd = calendar.date(byAdding: .day, value: -1, to: thisStart) ?? today
        default:
            break
        }
    }

    private func durationText(_ duration: TimeInterval) -> String {
        let seconds = Int(duration.rounded(.down))
        let hours = seconds / 3600
        let minutes = (seconds % 3600) / 60
        let remainingSeconds = seconds % 60
        return hours > 0
            ? String(format: "%d:%02d:%02d", hours, minutes, remainingSeconds)
            : String(format: "%02d:%02d", minutes, remainingSeconds)
    }
}
