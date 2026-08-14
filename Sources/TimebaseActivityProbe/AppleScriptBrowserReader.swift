import AppKit
import Foundation

struct AppleScriptBrowserReader {
    func activeTab(bundleIdentifier: String) -> BrowserReadOutcome {
        guard let source = scriptSource(for: bundleIdentifier) else {
            return .unsupported
        }

        var error: NSDictionary?
        guard let script = NSAppleScript(source: source) else {
            return .failure("No se pudo preparar el lector del navegador.")
        }

        let result = script.executeAndReturnError(&error)
        if let error {
            let number = error[NSAppleScript.errorNumber] ?? "—"
            let message = error[NSAppleScript.errorMessage] ?? "Error desconocido"
            return .failure("Apple Events \(number): \(message)")
        }

        let parts = result.stringValue?.split(separator: "\n", maxSplits: 1, omittingEmptySubsequences: false)
        guard let parts, parts.count == 2 else {
            return .failure("El navegador no devolvió título y URL.")
        }

        let title = String(parts[0])
        let url = URL(string: String(parts[1]))
        return .success(BrowserTab(title: title, url: url))
    }

    private func scriptSource(for bundleIdentifier: String) -> String? {
        switch bundleIdentifier {
        case "com.apple.Safari":
            return """
            tell application "Safari"
                if (count of windows) is 0 then return ""
                set selectedTab to current tab of front window
                return (name of selectedTab) & linefeed & (URL of selectedTab)
            end tell
            """

        case "com.brave.Browser":
            return """
            tell application "System Events"
                tell process "Brave Browser"
                    if (count of windows) is 0 then return ""
                    set focusedTitle to name of front window
                end tell
            end tell
            tell application "Brave Browser"
                repeat with browserWindow in windows
                    set selectedTab to active tab of browserWindow
                    set tabTitle to title of selectedTab
                    if focusedTitle contains tabTitle then
                        return tabTitle & linefeed & (URL of selectedTab)
                    end if
                end repeat
                return ""
            end tell
            """

        case "ai.perplexity.comet":
            return """
            tell application "Comet"
                if (count of windows) is 0 then return ""
                set selectedTab to active tab of front window
                return (title of selectedTab) & linefeed & (URL of selectedTab)
            end tell
            """

        case "company.thebrowser.Browser":
            return """
            tell application "Arc"
                if (count of windows) is 0 then return ""
                set tabTitle to title of active tab of first window
                set tabURL to URL of active tab of first window
                return tabTitle & linefeed & tabURL
            end tell
            """

        default:
            return nil
        }
    }
}
