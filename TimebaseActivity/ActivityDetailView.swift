import AppKit
import SwiftUI

struct ActivityDetailView: View {
    private enum ViewMode: String, CaseIterable, Identifiable {
        case day = "Día", timeline = "Cronología", grouped = "Agrupado", selection = "Selección", summary = "Resumen"
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
    private enum AssignmentStatus: String, CaseIterable, Identifiable {
        case unassigned = "Sin asignar", assigned = "Asignado", all = "Todos"
        var id: Self { self }
    }
    private struct SummaryRow: Identifiable {
        let id: String
        let name: String
        var assigned: TimeInterval
        var unassigned: TimeInterval
        var unassignedSegmentIDs: [UUID]
        var total: TimeInterval { assigned + unassigned }
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
    @State private var showsBlacklist = false
    @State private var period = "Hoy"
    @State private var rangeStart = Calendar.current.startOfDay(for: Date())
    @State private var rangeEnd = Calendar.current.startOfDay(for: Date())
    @State private var viewMode = ViewMode.day
    @State private var activityKind = ActivityKind.all
    @State private var activityStatus = ActivityStatus.all
    @State private var sortMode = SortMode.time
    @State private var assignmentStatus = AssignmentStatus.all
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
            if !selectedSegments.isEmpty {
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
                    activityStore: monitor.activityStore,
                    project: selectedProject,
                    sessions: preparedSessions
                ) { sentSegmentIDs in
                    selectedSegmentIDs.subtract(sentSegmentIDs)
                }
            }
        }
        .sheet(isPresented: $showsBlacklist) {
            BlacklistView(activityStore: monitor.activityStore)
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
            Button("Salir") {
                NSApplication.shared.terminate(nil)
            }
            Button("Lista negra") {
                showsBlacklist = true
            }
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
                if viewMode == .timeline {
                    Picker("Asignación", selection: $assignmentStatus) {
                        ForEach(AssignmentStatus.allCases) { Text($0.rawValue).tag($0) }
                    }
                    .frame(width: 145)
                }
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
            if viewMode == .summary {
                summaryView
            } else if viewMode == .day {
                DayTimelineView(
                    activityStore: monitor.activityStore,
                    date: rangeStart,
                    selectedSegmentIDs: $selectedSegmentIDs
                )
            } else if viewMode == .selection {
                selectionActivityList
            } else if let error = monitor.activityStore.storageError {
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

    private var selectionActivityList: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Pendientes seleccionadas").font(.headline)
            if selectedPendingGroups.isEmpty {
                Text("No hay actividades pendientes seleccionadas.")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(selectedPendingGroups) { group in
                    activityGroup(group)
                    Divider()
                }
            }

            Text("Ya asignadas").font(.headline).padding(.top, 8)
            if assignedReferenceGroups.isEmpty {
                Text("No hay actividades asignadas en este periodo.")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(assignedReferenceGroups) { group in
                    activityGroup(group)
                    Divider()
                }
            }
        }
    }

    private var summaryView: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 12) {
                summaryCard("Actividad total", summaryEligibleDuration, color: .blue)
                summaryCard("Asignado", summaryAssignedDuration, color: .green)
                summaryCard("Sin asignar", summaryUnassignedDuration, color: .orange)
                summaryCard("Lista negra", summaryExcludedDuration, color: .gray)
            }
            Text("Aplicaciones y sitios").font(.headline)
            ForEach(summaryRows) { row in
                HStack {
                    selectionButton(for: row.unassignedSegmentIDs)
                    Text(row.name).lineLimit(1)
                    Spacer()
                    Text("Asignado \(durationText(row.assigned))").foregroundStyle(.green)
                    Text("Pendiente \(durationText(row.unassigned))").foregroundStyle(.orange)
                    Text(durationText(row.total)).monospacedDigit()
                        .frame(width: 110, alignment: .trailing)
                }
                Divider()
            }
        }
    }

    private func summaryCard(_ title: String, _ duration: TimeInterval, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.caption).foregroundStyle(.secondary)
            Text(durationText(duration)).font(.headline.monospacedDigit()).foregroundStyle(color)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(color.opacity(0.1), in: RoundedRectangle(cornerRadius: 10))
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
                    if !monitor.activityStore.assignedSegmentIDs.contains(segment.id) {
                        selectionButton(for: [segment.id])
                    }
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
                if !isAssigned(group) {
                    selectionButton(for: group.segments.map(\.id))
                }
                Circle()
                    .fill(statusColor(for: group))
                    .frame(width: 8, height: 8)
                VStack(alignment: .leading, spacing: 2) {
                    Text(group.title).lineLimit(1)
                    Text(group.segments.count == 1
                         ? (group.segments[0].tabTitle ?? group.segments[0].windowTitle ?? "Sin título")
                         : "\(group.segments.count) pestañas o segmentos")
                        .font(.caption).foregroundStyle(.secondary).lineLimit(1)
                    if let assignment = assignmentText(for: group) {
                        Text(assignment).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                    }
                }
                Spacer()
                if isAssigned(group) {
                    Label("Asignado", systemImage: "circle.fill")
                        .font(.caption).foregroundStyle(.white)
                } else if viewMode == .grouped {
                    Label("Pendiente", systemImage: "circle.fill")
                        .font(.caption).foregroundStyle(.orange)
                }
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

    private var rawDateSegments: [ActivitySegment] {
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: rangeStart)
        let end = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: rangeEnd)) ?? rangeEnd
        return monitor.activityStore.segments.filter {
            $0.bundleIdentifier != "online.22mw.timebase.activity"
                && $0.startedAt >= start && $0.startedAt < end
        }
    }

    private var visibleGroups: [ActivityGroup] {
        var groups = dateGroups.filter(matchesFilters)
        if viewMode == .grouped {
            groups = aggregate(splitByAssignment(groups))
        } else if viewMode == .selection {
            groups = selectedPendingGroups + assignedReferenceGroups
        } else if viewMode == .timeline {
            groups = nearbyApplicationGroups(splitByAssignment(groups)).filter(matchesAssignmentFilter)
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
            let key = "\(group.isIdle)|\(isAssigned(group))|\(group.domain ?? group.applicationName)"
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

    private func splitByAssignment(_ groups: [ActivityGroup]) -> [ActivityGroup] {
        let assignedIDs = monitor.activityStore.assignedSegmentIDs
        return groups.flatMap { group -> [ActivityGroup] in
            var result: [ActivityGroup] = []
            var current: [ActivitySegment] = []
            var currentIsAssigned: Bool?

            for segment in group.segments {
                let segmentIsAssigned = assignedIDs.contains(segment.id)
                if currentIsAssigned != nil && currentIsAssigned != segmentIsAssigned {
                    result.append(ActivityGroup(id: current[0].id, segments: current))
                    current = []
                }
                current.append(segment)
                currentIsAssigned = segmentIsAssigned
            }
            if let first = current.first {
                result.append(ActivityGroup(id: first.id, segments: current))
            }
            return result
        }
    }

    private func nearbyApplicationGroups(_ groups: [ActivityGroup]) -> [ActivityGroup] {
        let assignedIDs = monitor.activityStore.assignedSegmentIDs
        var result: [ActivityGroup] = []
        for group in groups.sorted(by: { $0.startedAt < $1.startedAt }) {
            let assigned = isAssigned(group)
            let key = group.segments.first?.bundleIdentifier ?? group.applicationName
            if let index = result.indices.reversed().first(where: {
                let candidateKey = result[$0].segments.first?.bundleIdentifier ?? result[$0].applicationName
                return candidateKey == key
                    && result[$0].segments.allSatisfy { assignedIDs.contains($0.id) } == assigned
                    && group.startedAt.timeIntervalSince(result[$0].endedAt) <= 5 * 60
            }) {
                result[index].segments.append(contentsOf: group.segments)
            } else {
                result.append(ActivityGroup(
                    id: group.id,
                    segments: group.segments,
                    displayTitle: group.applicationName
                ))
            }
        }
        return result
    }

    private func statusColor(for group: ActivityGroup) -> Color {
        if isAssigned(group) {
            return .white
        }
        return group.isIdle ? .gray : .green
    }

    private var selectedPendingGroups: [ActivityGroup] {
        let assignedIDs = monitor.activityStore.assignedSegmentIDs
        return sortedGroups(dateGroups.filter(matchesFilters).compactMap { group in
            let segments = group.segments.filter {
                selectedSegmentIDs.contains($0.id) && !assignedIDs.contains($0.id)
            }
            guard let first = segments.first else { return nil }
            return ActivityGroup(id: first.id, segments: segments)
        })
    }

    private var assignedReferenceGroups: [ActivityGroup] {
        let assignedIDs = monitor.activityStore.assignedSegmentIDs
        return sortedGroups(dateGroups.filter(matchesFilters).compactMap { group in
            let segments = group.segments.filter { assignedIDs.contains($0.id) }
            guard let first = segments.first else { return nil }
            return ActivityGroup(id: first.id, segments: segments)
        })
    }

    private func matchesAssignmentFilter(_ group: ActivityGroup) -> Bool {
        let assignedIDs = monitor.activityStore.assignedSegmentIDs
        let hasAssigned = group.segments.contains { assignedIDs.contains($0.id) }
        let hasPending = group.segments.contains { !assignedIDs.contains($0.id) }
        switch assignmentStatus {
        case .assigned: return hasAssigned
        case .unassigned: return hasPending
        case .all: return true
        }
    }

    private func isAssigned(_ group: ActivityGroup) -> Bool {
        group.segments.allSatisfy { monitor.activityStore.assignedSegmentIDs.contains($0.id) }
    }

    private func sortedGroups(_ groups: [ActivityGroup]) -> [ActivityGroup] {
        switch sortMode {
        case .time: return groups.sorted { $0.startedAt > $1.startedAt }
        case .duration: return groups.sorted { $0.duration > $1.duration }
        case .name: return groups.sorted {
            $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending
        }
        }
    }

    private var selectedSegments: [ActivitySegment] {
        let assignedIDs = monitor.activityStore.assignedSegmentIDs
        return monitor.activityStore.segments.filter {
            selectedSegmentIDs.contains($0.id)
                && !assignedIDs.contains($0.id)
                && !monitor.activityStore.blacklistedBundleIDs.contains($0.bundleIdentifier ?? "")
        }
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
        let assignedIDs = monitor.activityStore.assignedSegmentIDs
        let availableIDs = ids.filter { !assignedIDs.contains($0) }
        let isSelected = !availableIDs.isEmpty && availableIDs.allSatisfy(selectedSegmentIDs.contains)
        return Button {
            if isSelected {
                selectedSegmentIDs.subtract(availableIDs)
            } else {
                selectedSegmentIDs.formUnion(availableIDs)
            }
        } label: {
            Image(systemName: availableIDs.isEmpty ? "circle.fill" : (isSelected ? "checkmark.circle.fill" : "circle"))
                .foregroundStyle(availableIDs.isEmpty ? .white : (isSelected ? .blue : .secondary))
        }
        .buttonStyle(.plain)
        .disabled(availableIDs.isEmpty)
    }

    private var summaryAssignedDuration: TimeInterval {
        let assignedIDs = monitor.activityStore.assignedSegmentIDs
        return rawDateSegments.filter { assignedIDs.contains($0.id) }.reduce(0) { $0 + $1.duration }
    }

    private var summaryUnassignedDuration: TimeInterval {
        let assignedIDs = monitor.activityStore.assignedSegmentIDs
        return rawDateSegments.filter {
            !assignedIDs.contains($0.id)
                && !monitor.activityStore.blacklistedBundleIDs.contains($0.bundleIdentifier ?? "")
        }.reduce(0) { $0 + $1.duration }
    }

    private var summaryExcludedDuration: TimeInterval {
        let assignedIDs = monitor.activityStore.assignedSegmentIDs
        return rawDateSegments.filter {
            !assignedIDs.contains($0.id)
                && monitor.activityStore.blacklistedBundleIDs.contains($0.bundleIdentifier ?? "")
        }.reduce(0) { $0 + $1.duration }
    }

    private var summaryEligibleDuration: TimeInterval {
        summaryAssignedDuration + summaryUnassignedDuration
    }

    private var summaryRows: [SummaryRow] {
        let assignedIDs = monitor.activityStore.assignedSegmentIDs
        var rows: [String: SummaryRow] = [:]
        for segment in rawDateSegments
        where !monitor.activityStore.blacklistedBundleIDs.contains(segment.bundleIdentifier ?? "") {
            let name = segment.domain ?? segment.applicationName
            var row = rows[name] ?? SummaryRow(
                id: name,
                name: name,
                assigned: 0,
                unassigned: 0,
                unassignedSegmentIDs: []
            )
            if assignedIDs.contains(segment.id) {
                row.assigned += segment.duration
            } else {
                row.unassigned += segment.duration
                row.unassignedSegmentIDs.append(segment.id)
            }
            rows[name] = row
        }
        return rows.values.sorted { $0.total > $1.total }
    }

    private func assignmentText(for group: ActivityGroup) -> String? {
        let segmentIDs = Set(group.segments.map(\.id))
        let records = monitor.activityStore.exports.filter { record in
            !segmentIDs.isDisjoint(with: Set(record.segmentIDs))
        }
        guard !records.isEmpty else { return nil }
        let labels = records.map { record in
            if let clientName = record.clientName, !clientName.isEmpty {
                return "\(clientName) · \(record.projectName)"
            }
            return record.projectName
        }
        return Array(Set(labels)).sorted().joined(separator: ", ")
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
        if hours > 0 { return "\(hours) h \(minutes) min" }
        if minutes > 0 { return "\(minutes) min \(remainingSeconds) s" }
        return "\(remainingSeconds) s"
    }
}
