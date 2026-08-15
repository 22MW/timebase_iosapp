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

    private struct Placement: Identifiable {
        let block: Block
        let x: CGFloat
        let width: CGFloat
        let lane: Int
        var id: UUID { block.id }
    }

    @ObservedObject var activityStore: ActivityStore
    let date: Date
    @Binding var selectedSegmentIDs: Set<UUID>
    @State private var hoveredID: UUID?
    @State private var cardWidth = 150.0

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
                Slider(value: $cardWidth, in: 90...260, step: 10).frame(width: 180)
                Image(systemName: "rectangle.expand.vertical")
                Text("Tamaño").font(.caption).foregroundStyle(.secondary)
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
            GeometryReader { proxy in
                let placements = placements(for: hour, availableWidth: proxy.size.width)
                let laneCount = (placements.map(\.lane).max() ?? 0) + 1
                ZStack(alignment: .topLeading) {
                    Divider().offset(y: 5)
                    ForEach(placements) { placement in
                        card(placement.block)
                            .frame(width: placement.width)
                            .offset(x: placement.x, y: CGFloat(placement.lane) * 74 + 14)
                    }
                }
                .frame(height: CGFloat(laneCount) * 74 + 20)
            }
            .frame(height: hourHeight(hour))
        }.padding(.bottom, 16)
    }

    private func placements(for hour: Int, availableWidth: CGFloat) -> [Placement] {
        let hourBlocks = blocks.filter { Calendar.current.component(.hour, from: $0.start) == hour }
        var laneEnds: [CGFloat] = []
        return hourBlocks.map { block in
            let minute = Calendar.current.component(.minute, from: block.start)
            let second = Calendar.current.component(.second, from: block.start)
            let x = (CGFloat(minute) + CGFloat(second) / 60) / 60 * availableWidth
            let naturalWidth = CGFloat(max(1, block.end.timeIntervalSince(block.start))) / 3600 * availableWidth
            let width = min(max(CGFloat(cardWidth), naturalWidth), max(CGFloat(cardWidth), availableWidth - x))
            let lane = laneEnds.firstIndex(where: { $0 + 8 <= x }) ?? laneEnds.count
            if lane == laneEnds.count { laneEnds.append(x + width) } else { laneEnds[lane] = x + width }
            return Placement(block: block, x: x, width: width, lane: lane)
        }
    }

    private func hourHeight(_ hour: Int) -> CGFloat {
        // The width used here only determines the number of visual rows; GeometryReader
        // recalculates exact positions using its real width.
        let estimate = placements(for: hour, availableWidth: 600)
        return CGFloat((estimate.map(\.lane).max() ?? 0) + 1) * 74 + 20
    }

    private func card(_ block: Block) -> some View {
        let selected = !block.assigned && block.ids.allSatisfy(selectedSegmentIDs.contains)
        let color: Color = block.assigned ? .white : (selected ? .blue : .green)
        return Button {
            guard !block.assigned else { return }
            if selected { selectedSegmentIDs.subtract(block.ids) }
            else { selectedSegmentIDs.formUnion(block.ids) }
        } label: {
            HStack(spacing: 8) {
                RoundedRectangle(cornerRadius: 2).fill(color).frame(width: 4)
                VStack(alignment: .leading, spacing: 3) {
                    Text(block.app).font(.caption.bold()).lineLimit(1)
                    Text("\(time(block.start))–\(time(block.end))")
                        .font(.caption2.monospacedDigit()).foregroundStyle(.secondary)
                    Text(duration(block.duration)).font(.caption2).foregroundStyle(.secondary)
                }
                Spacer(minLength: 4)
                Image(systemName: block.assigned ? "lock.fill" : (selected ? "checkmark.circle.fill" : "circle"))
                    .foregroundStyle(color)
            }
            .padding(10).frame(minHeight: 66)
            .background(color.opacity(block.assigned ? 0.1 : 0.15), in: RoundedRectangle(cornerRadius: 8))
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(color.opacity(0.65)))
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
