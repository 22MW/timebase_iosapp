import Foundation

struct PreparedSession: Identifiable {
    let id: UUID
    let startedAt: Date
    let duration: TimeInterval
    let segments: [ActivitySegment]

    var calculatedEnd: Date {
        startedAt.addingTimeInterval(duration)
    }
}

enum PreparedEntryBuilder {
    static func sessions(
        from source: [ActivitySegment],
        maximumGap: TimeInterval = 30 * 60
    ) -> [PreparedSession] {
        let sorted = source.sorted { $0.startedAt < $1.startedAt }
        guard let first = sorted.first else { return [] }

        var result: [PreparedSession] = []
        var current: [ActivitySegment] = [first]
        var previousEnd = first.endedAt

        for segment in sorted.dropFirst() {
            if segment.startedAt.timeIntervalSince(previousEnd) > maximumGap {
                result.append(makeSession(current))
                current = [segment]
            } else {
                current.append(segment)
            }
            previousEnd = max(previousEnd, segment.endedAt)
        }
        result.append(makeSession(current))
        return result
    }

    static func suggestedDescription(from segments: [ActivitySegment]) -> String {
        let domains = unique(segments.compactMap(\.domain))
        let applications = unique(segments.map(\.applicationName))
        let titles = unique(segments.compactMap { $0.tabTitle ?? $0.windowTitle })
            .filter { !$0.isEmpty && $0 != "Sin título" }

        let context = domains.isEmpty ? applications.prefix(3).joined(separator: ", ")
                                      : domains.prefix(3).joined(separator: ", ")
        let details = titles.prefix(3).joined(separator: "; ")

        if !context.isEmpty && !details.isEmpty {
            return "Trabajo en \(context): \(details)."
        }
        if !context.isEmpty {
            return "Trabajo relacionado con \(context)."
        }
        return "Trabajo realizado en el proyecto."
    }

    private static func makeSession(_ segments: [ActivitySegment]) -> PreparedSession {
        PreparedSession(
            id: segments[0].id,
            startedAt: segments[0].startedAt,
            duration: segments.reduce(0) { $0 + $1.duration },
            segments: segments
        )
    }

    private static func unique(_ values: [String]) -> [String] {
        var seen: Set<String> = []
        return values.filter { seen.insert($0).inserted }
    }
}
