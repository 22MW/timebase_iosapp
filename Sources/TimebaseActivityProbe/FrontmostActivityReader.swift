import AppKit
import ApplicationServices
import Foundation

struct FrontmostActivityReader {
    private let browserReader = AppleScriptBrowserReader()

    func capture() -> ActivitySnapshot? {
        guard let application = NSWorkspace.shared.frontmostApplication else {
            return nil
        }

        let bundleIdentifier = application.bundleIdentifier
        let tab = bundleIdentifier.flatMap(browserReader.activeTab(bundleIdentifier:))

        return ActivitySnapshot(
            capturedAt: Date(),
            applicationName: application.localizedName ?? "Aplicación desconocida",
            bundleIdentifier: bundleIdentifier,
            windowTitle: focusedWindowTitle(processIdentifier: application.processIdentifier),
            browserTab: tab,
            idleSeconds: idleSeconds()
        )
    }

    private func focusedWindowTitle(processIdentifier: pid_t) -> String? {
        let application = AXUIElementCreateApplication(processIdentifier)
        var windowValue: CFTypeRef?

        guard AXUIElementCopyAttributeValue(
            application,
            kAXFocusedWindowAttribute as CFString,
            &windowValue
        ) == .success,
        let windowValue else {
            return nil
        }

        let window = unsafeDowncast(windowValue, to: AXUIElement.self)
        var titleValue: CFTypeRef?

        guard AXUIElementCopyAttributeValue(
            window,
            kAXTitleAttribute as CFString,
            &titleValue
        ) == .success else {
            return nil
        }

        return titleValue as? String
    }

    private func idleSeconds() -> TimeInterval {
        let eventTypes: [CGEventType] = [
            .keyDown,
            .mouseMoved,
            .leftMouseDown,
            .rightMouseDown,
            .otherMouseDown,
            .scrollWheel
        ]

        return eventTypes
            .map { CGEventSource.secondsSinceLastEventType(.combinedSessionState, eventType: $0) }
            .min() ?? 0
    }
}
