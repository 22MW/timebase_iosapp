import AppKit
import Foundation

struct AppleScriptBrowserReader {
    func activeTab(bundleIdentifier: String) -> BrowserTab? {
        guard let source = scriptSource(for: bundleIdentifier) else {
            return nil
        }

        var error: NSDictionary?
        guard let result = NSAppleScript(source: source)?.executeAndReturnError(&error), error == nil else {
            return nil
        }

        let parts = result.stringValue?.split(separator: "\n", maxSplits: 1, omittingEmptySubsequences: false)
        guard let parts, parts.count == 2 else {
            return nil
        }

        let title = String(parts[0])
        let url = URL(string: String(parts[1]))
        return BrowserTab(title: title, url: url)
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
            using terms from application "Brave Browser"
                tell application id "company.thebrowser.Browser"
                    if (count of windows) is 0 then return ""
                    set selectedTab to active tab of front window
                    return (title of selectedTab) & linefeed & (URL of selectedTab)
                end tell
            end using terms from
            """

        default:
            return nil
        }
    }
}
