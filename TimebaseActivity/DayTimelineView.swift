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

    private struct PositionedBlock: Identifiable {
        let block: Block
        let lane: Int
        let y: CGFloat
        let height: CGFloat
        var id: UUID { block.id }
    }

    @ObservedObject var activityStore: ActivityStore
    let date: Date
    @Binding var selectedSegmentIDs: Set<UUID>
    @State private var detailBlockID: UUID?

    private let hourLabelWidth: CGFloat = 72
    private let laneWidth: CGFloat = 190
    private let pointsPerHour: CGFloat = 120

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header
            if blocks.isEmpty {
                ContentUnavailableView("No hay actividad este día", systemImage: "calendar")
            } else {
                GeometryReader { proxy in
                    ScrollView([.vertical, .horizontal]) {
                        ZStack(alignment: .topLeading) {
                            hourGrid(width: max(proxy.size.width, contentWidth))
                            ForEach(positionedBlocks) { item in timelineItem(item) }
                        }
                        .frame(width: max(proxy.size.width, contentWidth), height: timelineHeight, alignment: .topLeading)
                    }
                }
                .frame(minHeight: 430, maxHeight: 680)
            }
        }
    }

    private var header: some View {
        VStack(spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Vista por horas").font(.headline)
                    Text(date.formatted(date: .complete, time: .omitted))
                        .font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                HStack(spacing: 14) {
                    Label("Pendiente", systemImage: "circle.fill").foregroundStyle(.green)
                    Label("Seleccionado", systemImage: "circle.fill").foregroundStyle(.blue)
                    Label("Asignado", systemImage: "circle.fill").foregroundStyle(.white)
                }.font(.caption)
            }
        }
    }

    private func hourGrid(width: CGFloat) -> some View {
        ForEach(startHour...endHour, id: \.self) { hour in
            let y = CGFloat(hour - startHour) * pointsPerHour
            ZStack(alignment: .leading) {
                Rectangle()
                    .fill(Color.secondary.opacity(0.38))
                    .frame(width: width, height: 1)
                Text(String(format: "%02d:00", hour))
                    .font(.callout.monospacedDigit())
                    .fontWeight(.semibold)
                    .foregroundStyle(.primary)
                    .padding(.horizontal, 6)
                    .background(.background)
                    .frame(width: hourLabelWidth, alignment: .leading)
            }
            .frame(width: width)
            .offset(y: y)
        }
    }

    private func timelineItem(_ item: PositionedBlock) -> some View {
        let selected = allSelected(item.block)
        let color: Color = item.block.assigned ? .white : (selected ? .blue : .green)
        return HStack(alignment: .top, spacing: 7) {
            Button { toggle(item.block.ids) } label: {
                RoundedRectangle(cornerRadius: 6)
                    .fill(color.opacity(item.block.assigned ? 0.9 : 0.85))
                    .frame(width: 8, height: item.height)
            }
            .buttonStyle(.plain)
            .disabled(item.block.assigned)

            Button {
                detailBlockID = item.block.id
            } label: {
                VStack(alignment: .leading, spacing: 1) {
                    Text(item.block.app).font(.caption.bold()).lineLimit(1)
                    Text(primaryTitle(item.block)).font(.caption2).foregroundStyle(.secondary).lineLimit(1)
                }
                .frame(width: laneWidth - 32, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .popover(isPresented: detailBinding(item.block.id), arrowEdge: .leading) {
                detail(item.block).padding(16).frame(width: 430)
            }
        }
        .offset(
            x: hourLabelWidth + 22 + CGFloat(item.lane) * laneWidth,
            y: item.y
        )
    }

    private func detailBinding(_ id: UUID) -> Binding<Bool> {
        Binding(get: { detailBlockID == id }, set: { if !$0 && detailBlockID == id { detailBlockID = nil } })
    }

    private func detail(_ block: Block) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(block.app).font(.headline)
                Spacer()
                if block.assigned {
                    Label("Asignado", systemImage: "lock.fill").foregroundStyle(.secondary)
                } else {
                    Button(allSelected(block) ? "Quitar todas" : "Seleccionar todas") { toggle(block.ids) }
                        .buttonStyle(.borderedProminent)
                }
            }
            Text("\(time(block.start))–\(time(block.end)) · \(duration(block.duration))")
                .foregroundStyle(.secondary)
            if let project = assignment(block) {
                Label(project, systemImage: "folder.fill").foregroundStyle(.secondary)
            }
            Divider()
            ForEach(block.segments) { segment in
                HStack(alignment: .top, spacing: 8) {
                    Button { toggle([segment.id]) } label: {
                        Image(systemName: block.assigned ? "lock.fill" : (selectedSegmentIDs.contains(segment.id) ? "checkmark.circle.fill" : "circle"))
                            .foregroundStyle(block.assigned ? .white : (selectedSegmentIDs.contains(segment.id) ? .blue : .green))
                    }.buttonStyle(.plain).disabled(block.assigned)
                    Text(time(segment.startedAt)).font(.caption.monospacedDigit()).foregroundStyle(.secondary)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(segment.tabTitle ?? segment.windowTitle ?? "Sin título")
                            .font(.caption).lineLimit(2)
                        if let url = segment.url?.absoluteString {
                            Text(url).font(.caption2).foregroundStyle(.secondary).lineLimit(1)
                        }
                    }
                    Spacer()
                    Text(duration(segment.duration)).font(.caption.monospacedDigit()).foregroundStyle(.secondary)
                }
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
            if let matching = result.indices.reversed().first(where: {
                result[$0].assigned == assigned
                    && result[$0].segments.last?.bundleIdentifier == segment.bundleIdentifier
                    && segment.startedAt.timeIntervalSince(result[$0].end) <= 5 * 60
            }) {
                result[matching].segments.append(segment)
            } else {
                result.append(Block(id: segment.id, segments: [segment], assigned: assigned))
            }
        }
        .sorted { $0.start < $1.start }
    }

    private var positionedBlocks: [PositionedBlock] {
        var laneEnds: [CGFloat] = []
        return blocks.map { block in
            let y = yPosition(block.start)
            let naturalHeight = CGFloat(max(1, block.duration)) / 3600 * pointsPerHour
            let height = max(18, naturalHeight)
            let lane = laneEnds.firstIndex(where: { $0 + 5 <= y }) ?? laneEnds.count
            if lane == laneEnds.count { laneEnds.append(y + height) } else { laneEnds[lane] = y + height }
            return PositionedBlock(block: block, lane: lane, y: y, height: height)
        }
    }

    private var laneCount: Int { (positionedBlocks.map(\.lane).max() ?? 0) + 1 }
    private var contentWidth: CGFloat { hourLabelWidth + 32 + CGFloat(laneCount) * laneWidth }
    private var timelineHeight: CGFloat { CGFloat(endHour - startHour + 1) * pointsPerHour }
    private var startHour: Int { max(0, (segments.map { Calendar.current.component(.hour, from: $0.startedAt) }.min() ?? 0) - 1) }
    private var endHour: Int { min(24, (segments.map { Calendar.current.component(.hour, from: $0.endedAt) }.max() ?? 23) + 2) }

    private func yPosition(_ date: Date) -> CGFloat {
        let parts = Calendar.current.dateComponents([.hour, .minute, .second], from: date)
        let hours = CGFloat((parts.hour ?? 0) - startHour)
        let fraction = CGFloat(parts.minute ?? 0) / 60 + CGFloat(parts.second ?? 0) / 3600
        return (hours + fraction) * pointsPerHour
    }

    private func primaryTitle(_ block: Block) -> String {
        block.segments.first?.tabTitle ?? block.segments.first?.windowTitle ?? "Sin título"
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

    private func allSelected(_ block: Block) -> Bool {
        !block.ids.isEmpty && block.ids.allSatisfy(selectedSegmentIDs.contains)
    }

    private func toggle(_ ids: [UUID]) {
        let available = ids.filter { !activityStore.assignedSegmentIDs.contains($0) }
        if !available.isEmpty && available.allSatisfy(selectedSegmentIDs.contains) {
            selectedSegmentIDs.subtract(available)
        } else {
            selectedSegmentIDs.formUnion(available)
        }
    }

    private func time(_ date: Date) -> String { date.formatted(date: .omitted, time: .shortened) }
    private func duration(_ interval: TimeInterval) -> String {
        let seconds = Int(interval.rounded(.down)), hours = seconds / 3600, minutes = seconds % 3600 / 60
        if hours > 0 { return "\(hours) h \(minutes) min" }
        if minutes > 0 { return "\(minutes) min" }
        return "\(seconds) s"
    }
}
