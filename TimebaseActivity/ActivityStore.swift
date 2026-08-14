import Foundation

struct ActivitySegment: Codable, Identifiable, Equatable {
    let id: UUID
    let startedAt: Date
    var endedAt: Date
    let applicationName: String
    let bundleIdentifier: String?
    let windowTitle: String?
    let tabTitle: String?
    let url: URL?
    let domain: String?
    let isIdle: Bool

    var duration: TimeInterval {
        max(0, endedAt.timeIntervalSince(startedAt))
    }

    init(snapshot: ActivitySnapshot) {
        id = UUID()
        startedAt = snapshot.capturedAt
        endedAt = snapshot.capturedAt
        applicationName = snapshot.applicationName
        bundleIdentifier = snapshot.bundleIdentifier
        windowTitle = snapshot.windowTitle
        tabTitle = snapshot.browserTab?.title
        url = snapshot.browserTab?.url
        domain = snapshot.browserTab?.domain
        isIdle = snapshot.isIdle
    }

    func belongsToSameActivity(as snapshot: ActivitySnapshot) -> Bool {
        applicationName == snapshot.applicationName
            && bundleIdentifier == snapshot.bundleIdentifier
            && windowTitle == snapshot.windowTitle
            && tabTitle == snapshot.browserTab?.title
            && url == snapshot.browserTab?.url
            && isIdle == snapshot.isIdle
    }
}

struct ActivityGroup: Identifiable {
    let id: UUID
    var segments: [ActivitySegment]

    var domain: String? { segments.first?.domain }
    var applicationName: String { segments.first?.applicationName ?? "Aplicación desconocida" }
    var isIdle: Bool { segments.first?.isIdle ?? false }
    var title: String { domain ?? applicationName }
    var startedAt: Date { segments.first?.startedAt ?? .distantPast }
    var endedAt: Date { segments.last?.endedAt ?? startedAt }
    var duration: TimeInterval { segments.reduce(0) { $0 + $1.duration } }

    fileprivate func canInclude(_ segment: ActivitySegment) -> Bool {
        guard isIdle == segment.isIdle else { return false }
        if let domain {
            return domain == segment.domain
        }
        return segment.domain == nil
            && segments.last?.bundleIdentifier == segment.bundleIdentifier
            && segments.last?.windowTitle == segment.windowTitle
    }
}

struct TimebaseExportRecord: Codable, Identifiable {
    let id: UUID
    let timebaseEntryID: String
    let projectID: String
    let projectName: String
    let segmentIDs: [UUID]
    let exportedAt: Date
}

@MainActor
final class ActivityStore: ObservableObject {
    @Published private(set) var segments: [ActivitySegment] = []
    @Published private(set) var exports: [TimebaseExportRecord] = []
    @Published private(set) var storageError: String?

    private let fileURL: URL
    private let exportsFileURL: URL
    private var forceNewSegment = false

    var groupedActivities: [ActivityGroup] {
        segments
            .filter { $0.bundleIdentifier != "online.22mw.timebase.activity" }
            .reduce(into: [ActivityGroup]()) { groups, segment in
                if let index = groups.indices.last, groups[index].canInclude(segment) {
                    groups[index].segments.append(segment)
                } else {
                    groups.append(ActivityGroup(id: segment.id, segments: [segment]))
                }
            }
    }

    var todayGroupedActivities: [ActivityGroup] {
        groupedActivities.filter {
            Calendar.current.isDate($0.startedAt, inSameDayAs: Date())
        }
    }

    init(fileManager: FileManager = .default) {
        let applicationSupport = fileManager.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first!
        let directory = applicationSupport.appending(
            component: "TimebaseActivity",
            directoryHint: .isDirectory
        )
        fileURL = directory.appending(component: "activities.json")
        exportsFileURL = directory.appending(component: "exports.json")

        do {
            try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
            if fileManager.fileExists(atPath: fileURL.path) {
                let data = try Data(contentsOf: fileURL)
                let decoder = JSONDecoder()
                decoder.dateDecodingStrategy = .iso8601
                segments = try decoder.decode([ActivitySegment].self, from: data)
            }
            if fileManager.fileExists(atPath: exportsFileURL.path) {
                let data = try Data(contentsOf: exportsFileURL)
                let decoder = JSONDecoder()
                decoder.dateDecodingStrategy = .iso8601
                exports = try decoder.decode([TimebaseExportRecord].self, from: data)
            }
        } catch {
            storageError = "No se pudo leer el historial local: \(error.localizedDescription)"
        }
    }

    func record(_ snapshot: ActivitySnapshot) {
        if !forceNewSegment,
           let index = segments.indices.last,
           segments[index].belongsToSameActivity(as: snapshot) {
            segments[index].endedAt = snapshot.capturedAt
        } else {
            if let index = segments.indices.last {
                segments[index].endedAt = max(segments[index].endedAt, snapshot.capturedAt)
            }
            segments.append(ActivitySegment(snapshot: snapshot))
        }
        forceNewSegment = false
        save()
    }

    func interruptCurrentSegment(at date: Date = Date()) {
        guard !forceNewSegment else { return }
        finishCurrentSegment(at: date)
        forceNewSegment = true
    }

    func recordExport(
        entryID: String,
        project: TimebaseProject,
        session: PreparedSession
    ) {
        exports.append(TimebaseExportRecord(
            id: UUID(),
            timebaseEntryID: entryID,
            projectID: project.id,
            projectName: project.name,
            segmentIDs: session.segments.map(\.id),
            exportedAt: Date()
        ))
        saveExports()
    }

    func finishCurrentSegment(at date: Date = Date()) {
        guard let index = segments.indices.last else { return }
        segments[index].endedAt = max(segments[index].endedAt, date)
        save()
    }

    private func save() {
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            encoder.dateEncodingStrategy = .iso8601
            try encoder.encode(segments).write(to: fileURL, options: .atomic)
            storageError = nil
        } catch {
            storageError = "No se pudo guardar el historial local: \(error.localizedDescription)"
        }
    }


    private func saveExports() {
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            encoder.dateEncodingStrategy = .iso8601
            try encoder.encode(exports).write(to: exportsFileURL, options: .atomic)
            storageError = nil
        } catch {
            storageError = "No se pudo guardar el registro de envíos: \(error.localizedDescription)"
        }
    }
}
