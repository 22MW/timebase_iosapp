import SwiftUI

struct DayTimelineView: View {
    private struct Block: Identifiable {
        let id: UUID
        var segments: [ActivitySegment]
        let assigned: Bool
        var app: String { segments.first?.applicationName ?? "Aplicación" }
        var start: Date { segments.first?.startedAt ?? .distantPast }
        var end: Date { segments.last?.endedAt ?? start }
        var duration: TimeInterval { segments.reduce(0) { $0 + $1.duration } }
        var ids: [UUID] { segments.map(\.id) }
    }

    @ObservedObject var activityStore: ActivityStore
    let date: Date
    @Binding var selectedSegmentIDs: Set<UUID>
    @State private var hoveredID: UUID?
    @State private var hourSpacing = 90.0

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Vista por horas").font(.headline)
                    Text(date.formatted(date: .complete, time: .omitted))
                        .font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                legend
            }
            HStack(spacing: 9) {
                Image(systemName: "rectangle.compress.vertical")
                Slider(value: $hourSpacing, in: 60...240, step: 10).frame(width: 180)
                Image(systemName: "rectangle.expand.vertical")
                Text("Espacio entre horas").font(.caption).foregroundStyle(.secondary)
            }.frame(maxWidth: .infinity, alignment: .trailing)

            if blocks.isEmpty {
                ContentUnavailableView("No hay actividad este día", systemImage: "calendar")
            } else {
                ScrollView(.vertical) {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        ForEach(hours, id: \.self) { hour in hourRow(hour) }
                    }
                }.frame(minHeight: 380, maxHeight: 650)
            }
        }
    }

    private var legend: some View {
        HStack(spacing: 14) {
            Label("Pendiente", systemImage: "circle.fill").foregroundStyle(.green)
            Label("Seleccionado", systemImage: "circle.fill").foregroundStyle(.blue)
            Label("Asignado", systemImage: "circle.fill").foregroundStyle(.white)
        }.font(.caption)
    }

    private func hourRow(_ hour: Int) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Text(String(format: "%02d:00", hour))
                .font(.caption.monospacedDigit()).foregroundStyle(.secondary)
                .frame(width: 50, alignment: .trailing).padding(.top, 12)
            VStack(alignment: .leading, spacing: 8) {
                Divider()
                LazyVGrid(
                    columns: [GridItem(.adaptive(minimum: 165, maximum: 225), spacing: 8)],
                    alignment: .leading,
                    spacing: 8
                ) {
                    ForEach(hourBlocks(hour)) { block in
                        compactItem(block)
                    }
                }
                .frame(minHeight: hourSpacing, alignment: .top)
            }
        }.padding(.bottom, 16)
    }

    private func hourBlocks(_ hour: Int) -> [Block] {
        blocks.filter { Calendar.current.component(.hour, from: $0.start) == hour }
    }

    private func compactItem(_ block: Block) -> some View {
        let selected = !block.assigned && block.ids.allSatisfy(selectedSegmentIDs.contains)
        let color: Color = block.assigned ? .white : (selected ? .blue : .green)
        return Button {
            guard !block.assigned else { return }
            if selected { selectedSegmentIDs.subtract(block.ids) }
            else { selectedSegmentIDs.formUnion(block.ids) }
        } label: {
            HStack(spacing: 6) {
                Circle().fill(color).frame(width: 8, height: 8)
                VStack(alignment: .leading, spacing: 1) {
                    Text(block.app).font(.caption.bold()).lineLimit(1)
                    Text("\(time(block.start)) · \(duration(block.duration))")
                        .font(.caption2.monospacedDigit()).foregroundStyle(.secondary).lineLimit(1)
                }
                Spacer(minLength: 2)
                if selected { Image(systemName: "checkmark.circle.fill").foregroundStyle(.blue) }
            }
            .padding(.horizontal, 8).frame(height: 38, alignment: .leading)
            .background(color.opacity(block.assigned ? 0.08 : 0.12), in: RoundedRectangle(cornerRadius: 7))
            .overlay(RoundedRectangle(cornerRadius: 7).stroke(color.opacity(0.45)))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain).disabled(block.assigned)
        .popover(isPresented: hoverBinding(block.id), arrowEdge: .leading) {
            details(block).padding(16).frame(width: 390)
        }
        .onHover { over in hoveredID = over ? block.id : (hoveredID == block.id ? nil : hoveredID) }
    }

    private func hoverBinding(_ id: UUID) -> Binding<Bool> {
        Binding(get: { hoveredID == id }, set: { if !$0 && hoveredID == id { hoveredID = nil } })
    }

    private func details(_ block: Block) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(block.app).font(.headline)
            Text("\(time(block.start))–\(time(block.end)) · \(duration(block.duration))")
                .foregroundStyle(.secondary)
            if let project = assignment(block) {
                Label(project, systemImage: "folder.fill").foregroundStyle(.secondary)
            }
            Divider()
            ForEach(block.segments.prefix(12)) { segment in
                HStack(alignment: .top) {
                    Text(time(segment.startedAt)).font(.caption.monospacedDigit()).foregroundStyle(.secondary)
                    Text(segment.tabTitle ?? segment.windowTitle ?? "Sin título").font(.caption).lineLimit(2)
                    Spacer()
                    Text(duration(segment.duration)).font(.caption.monospacedDigit()).foregroundStyle(.secondary)
                }
            }
            if block.segments.count > 12 {
                Text("Y \(block.segments.count - 12) actividades más…").font(.caption).foregroundStyle(.secondary)
            }
        }
    }

    private var segments: [ActivitySegment] {
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: date)
        let end = calendar.date(byAdding: .day, value: 1, to: start) ?? date
        return activityStore.segments.filter {
            $0.startedAt >= start && $0.startedAt < end
                && $0.bundleIdentifier != "online.22mw.timebase.activity"
                && !activityStore.blacklistedBundleIDs.contains($0.bundleIdentifier ?? "")
        }.sorted { $0.startedAt < $1.startedAt }
    }

    private var blocks: [Block] {
        let assignedIDs = activityStore.assignedSegmentIDs
        return segments.reduce(into: [Block]()) { result, segment in
            let assigned = assignedIDs.contains(segment.id)
            if let index = result.indices.last,
               result[index].segments.last?.bundleIdentifier == segment.bundleIdentifier,
               result[index].assigned == assigned,
               segment.startedAt.timeIntervalSince(result[index].end) <= 3 {
                result[index].segments.append(segment)
            } else {
                result.append(Block(id: segment.id, segments: [segment], assigned: assigned))
            }
        }
    }

    private var hours: [Int] {
        Array(Set(blocks.map { Calendar.current.component(.hour, from: $0.start) })).sorted()
    }

    private func assignment(_ block: Block) -> String? {
        let ids = Set(block.ids)
        let labels = activityStore.exports.filter { !ids.isDisjoint(with: Set($0.segmentIDs)) }.map {
            if let client = $0.clientName, !client.isEmpty { return "\(client) · \($0.projectName)" }
            return $0.projectName
        }
        let text = Array(Set(labels)).sorted().joined(separator: ", ")
        return text.isEmpty ? nil : text
    }

    private func time(_ date: Date) -> String { date.formatted(date: .omitted, time: .shortened) }
    private func duration(_ interval: TimeInterval) -> String {
        let seconds = Int(interval.rounded(.down)), hours = seconds / 3600, minutes = seconds % 3600 / 60
        if hours > 0 { return "\(hours) h \(minutes) min" }
        if minutes > 0 { return "\(minutes) min" }
        return "\(seconds) s"
    }
}
