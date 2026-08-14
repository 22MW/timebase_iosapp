import ApplicationServices
import Foundation

@MainActor
final class ActivityMonitor: ObservableObject {
    @Published private(set) var snapshot: ActivitySnapshot?
    @Published private(set) var isPaused = false

    let activityStore = ActivityStore()

    private let reader = FrontmostActivityReader()
    private var monitoringTask: Task<Void, Never>?
    private let ownBundleIdentifier = "online.22mw.timebase.activity"

    init() {
        requestAccessibilityIfNeeded()
        startMonitoring()
    }

    var hasAccessibilityPermission: Bool {
        AXIsProcessTrusted()
    }

    func togglePause() {
        isPaused.toggle()
        if isPaused {
            activityStore.finishCurrentSegment()
        } else {
            capture()
        }
    }

    func requestAccessibilityIfNeeded() {
        guard !AXIsProcessTrusted() else {
            return
        }

        AXIsProcessTrustedWithOptions(["AXTrustedCheckOptionPrompt": true] as CFDictionary)
    }

    private func startMonitoring() {
        monitoringTask = Task { [weak self] in
            while !Task.isCancelled {
                self?.capture()
                try? await Task.sleep(for: .seconds(1))
            }
        }
    }

    private func capture() {
        guard !isPaused else {
            return
        }
        guard let latestSnapshot = reader.capture() else { return }
        snapshot = latestSnapshot
        guard latestSnapshot.bundleIdentifier != ownBundleIdentifier else {
            activityStore.interruptCurrentSegment(at: latestSnapshot.capturedAt)
            return
        }
        activityStore.record(latestSnapshot)
    }
}
