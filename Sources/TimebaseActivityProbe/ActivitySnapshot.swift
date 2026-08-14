import Foundation

struct BrowserTab: Equatable {
    let title: String
    let url: URL?

    var domain: String? {
        url?.host()
    }
}

struct ActivitySnapshot: Equatable {
    let capturedAt: Date
    let applicationName: String
    let bundleIdentifier: String?
    let windowTitle: String?
    let browserTab: BrowserTab?
    let idleSeconds: TimeInterval

    static func == (lhs: ActivitySnapshot, rhs: ActivitySnapshot) -> Bool {
        lhs.applicationName == rhs.applicationName
            && lhs.bundleIdentifier == rhs.bundleIdentifier
            && lhs.windowTitle == rhs.windowTitle
            && lhs.browserTab == rhs.browserTab
            && Int(lhs.idleSeconds) == Int(rhs.idleSeconds)
    }
}
