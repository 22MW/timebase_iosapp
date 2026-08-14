import SwiftUI

struct DayTimelineView: View {
    private struct TimelineBlock: Identifiable {
        let id: UUID
        var segments: [ActivitySegment]
        let isAssigned: Bool

        var applicationName: String { segments.first?.applicationName ?? "Aplicación" }
        var startedAt: Date { segments.first?.startedAt ?? .distantPast }
        var endedAt: Date { segments.last?.endedAt ?? startedAt }
        var duration: TimeInterval { segments.reduce(0) { $0 + $1.duration } }
        var segmentIDs: [UUID] { segments.map(\.id) }
    }

    @ObservedObject var activityStore: ActivityStore
    let date: Date
    @Binding var selectedSegmentIDs: Set<UUID>

    private let pointsPerHour: CGFloat = 92
    private let labelWidth: CGFloat = 58

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

            if blocks.isEmpty {
                ContentUnavailableView(
                    "No hay actividad este día",
                    systemImage: "calendar",
                    description: Text("Selecciona otro día para ver su actividad.")
                )
            } else {
                ScrollView(.vertical) {
                    ZStack(alignment: .topLeading) {
                        hourGrid
                        ForEach(blocks) { block in
                            timelineBlock(block)
                        }
                    }
                    .frame(height: CGFloat(endHour - startHour) * pointsPerHour)
                }
                .frame(minHeight: 380, maxHeight: 620)
            }
        }
    }

    private var legend: some View {
        HStack(spacing: 14) {
            Label("Pendiente", systemImage: "circle.fill").foregroundStyle(.green)
            Label("Seleccionado", systemImage: "circle.fill").foregroundStyle(.blue)
            Label("Asignado", systemImage: "circle.fill").foregroundStyle(.white)
        }
        .font(.caption)
    }

    private var hourGrid: some View {
        ForEach(startHour...endHour, id: \.self) { hour in
            let y = CGFloat(hour - startHour) * pointsPerHour
            HStack(spacing: 10) {
                Text(String(format: "%02d:00", hour))
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
                    .frame(width: labelWidth, alignment: .trailing)
                Divider()
                    .frame(height: 1)
                    .overlay(.secondary.opacity(0.3))
            }
            .offset(y: y)
        }
    }

    private func timelineBlock(_ block: TimelineBlock) -> some View {
        let selected = !block.isAssigned && block.segmentIDs.allSatisfy(selectedSegmentIDs.contains)
        let color: Color = block.isAssigned ? .white : (selected ? .blue : .green)
        let top = yPosition(for: block.startedAt)
        let actualHeight = CGFloat(max(1, block.endedAt.timeIntervalSince(block.startedAt))) / 3600 * pointsPerHour
        let height = max(30, actualHeight)

        return Button {
            guard !block.isAssigned else { return }
            if selected {
                selectedSegmentIDs.subtract(block.segmentIDs)
            } else {
                selectedSegmentIDs.formUnion(block.segmentIDs)
            }
        } label: {
            HStack(spacing: 8) {
                RoundedRectangle(cornerRadius: 2).fill(color).frame(width: 4)
                VStack(alignment: .leading, spacing: 1) {
                    Text(block.applicationName).font(.caption.bold()).lineLimit(1)
                    Text("\(block.startedAt.formatted(date: .omitted, time: .shortened))–\(block.endedAt.formatted(date: .omitted, time: .shortened)) · \(durationText(block.duration))")
                        .font(.caption2).foregroundStyle(.secondary).lineLimit(1)
                }
                Spacer()
                Image(systemName: block.isAssigned ? "lock.fill" : (selected ? "checkmark.circle.fill" : "circle"))
                    .foregroundStyle(color)
            }
            .padding(.horizontal, 10)
            .frame(height: height)
            .background(color.opacity(block.isAssigned ? 0.12 : 0.16), in: RoundedRectangle(cornerRadius: 8))
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(color.opacity(0.65)))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(block.isAssigned)
        .popover(isPresented: hoverBinding(for: block.id), arrowEdge: .leading) {
            blockDetails(block).padding(16).frame(width: 380)
        }
        .onHover { hovering in hoveredBlockID = hovering ? block.id : (hoveredBlockID == block.id ? nil : hoveredBlockID) }
        .offset(x: labelWidth + 76, y: top)
        .padding(.trailing, labelWidth + 92)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @State private var hoveredBlockID: UUID?

    private func hoverBinding(for id: UUID) -> Binding<Bool> {
        Binding(get: { hoveredBlockID == id }, set: { if !$0 && hoveredBlockID == id { hoveredBlockID = nil } })
    }

    private func blockDetails(_ block: TimelineBlock) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(block.applicationName).font(.headline)
            Text("\(block.startedAt.formatted(date: .omitted, time: .shortened))–\(block.endedAt.formatted(date: .omitted, time: .shortened)) · \(durationText(block.duration))")
                .foregroundStyle(.secondary)
            if let assignment = assignmentText(for: block) {
                Label(assignment, systemImage: "folder.fill").foregroundStyle(.secondary)
            }
            Divider()
            ForEach(block.segments.prefix(12)) { segment in
                HStack(alignment: .top) {
                    Text(segment.startedAt, style: .time).font(.caption.monospacedDigit()).foregroundStyle(.secondary)
                    Text(segment.tabTitle ?? segment.windowTitle ?? "Sin título")
                        .font(.caption).lineLimit(2)
                    Spacer()
                    Text(durationText(segment.duration)).font(.caption.monospacedDigit()).foregroundStyle(.secondary)
                }
            }
            if block.segments.count > 12 {
                Text("Y \(block.segments.count - 12) actividades más…").font(.caption).foregroundStyle(.secondary)
            }
        }
    }

    private var daySegments: [ActivitySegment] {
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: date)
        let end = calendar.date(byAdding: .day, value: 1, to: start) ?? date
        return activityStore.segments.filter {
            $0.startedAt >= start && $0.startedAt < end
                && $0.bundleIdentifier != "online.22mw.timebase.activity"
                && !activityStore.blacklistedBundleIDs.contains($0.bundleIdentifier ?? "")
        }.sorted { $0.startedAt < $1.startedAt }
    }

    private var blocks: [TimelineBlock] {
        let assignedIDs = activityStore.assignedSegmentIDs
        return daySegments.reduce(into: [TimelineBlock]()) { result, segment in
            let assigned = assignedIDs.contains(segment.id)
            if let index = result.indices.last,
               result[index].segments.last?.bundleIdentifier == segment.bundleIdentifier,
               result[index].isAssigned == assigned,
               segment.startedAt.timeIntervalSince(result[index].endedAt) <= 3 {
                result[index].segments.append(segment)
            } else {
                result.append(TimelineBlock(id: segment.id, segments: [segment], isAssigned: assigned))
            }
        }
    }

    private var startHour: Int {
        max(0, (blocks.map { Calendar.current.component(.hour, from: $0.startedAt) }.min() ?? 0) - 1)
    }

    private var endHour: Int {
        min(24, (blocks.map { Calendar.current.component(.hour, from: $0.endedAt) }.max() ?? 23) + 2)
    }

    private func yPosition(for date: Date) -> CGFloat {
        let components = Calendar.current.dateComponents([.hour, .minute, .second], from: date)
        let hour = CGFloat((components.hour ?? 0) - startHour)
        let fraction = CGFloat(components.minute ?? 0) / 60 + CGFloat(components.second ?? 0) / 3600
        return (hour + fraction) * pointsPerHour
    }

    private func assignmentText(for block: TimelineBlock) -> String? {
        let ids = Set(block.segmentIDs)
        let labels = activityStore.exports.filter { !ids.isDisjoint(with: Set($0.segmentIDs)) }.map {
            if let client = $0.clientName, !client.isEmpty { return "\(client) · \($0.projectName)" }
            return $0.projectName
        }
        return Array(Set(labels)).sorted().joined(separator: ", ").nilIfEmpty
    }

    private func durationText(_ duration: TimeInterval) -> String {
        let seconds = Int(duration.rounded(.down))
        let hours = seconds / 3600
        let minutes = (seconds % 3600) / 60
        if hours > 0 { return "\(hours) h \(minutes) min" }
        if minutes > 0 { return "\(minutes) min" }
        return "\(seconds) s"
    }
}

private extension String {
    var nilIfEmpty: String? { isEmpty ? nil : self }
}
