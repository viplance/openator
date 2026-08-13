import AppKit
import OSLog

struct BrowserInfo {
    let bundleId: String
    let name: String
}

final class BrowserManager {
    static let shared = BrowserManager()
    private let routingLogger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "com.openator.app",
        category: "Routing"
    )
    private var cached: [BrowserInfo]?

    func availableBrowsers() -> [BrowserInfo] {
        if let cached { return cached }

        let testURL = URL(string: "https://example.com")!
        let appURLs = NSWorkspace.shared.urlsForApplications(toOpen: testURL)

        let ownId = (Bundle.main.bundleIdentifier ?? "").lowercased()
        var seen = Set<String>()
        var result: [BrowserInfo] = []

        for appURL in appURLs {
            guard let bundle = Bundle(url: appURL),
                  let bundleId = bundle.bundleIdentifier else { continue }
            let lower = bundleId.lowercased()
            if lower == ownId || seen.contains(lower) { continue }
            seen.insert(lower)

            let name = FileManager.default.displayName(atPath: appURL.path)
            result.append(BrowserInfo(bundleId: bundleId, name: name))
        }

        result.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        cached = result
        return result
    }

    func invalidateCache() { cached = nil }

    func browserName(for bundleId: String) -> String {
        availableBrowsers()
            .first { $0.bundleId.caseInsensitiveCompare(bundleId) == .orderedSame }?
            .name ?? bundleId
    }

    @discardableResult
    func openURL(_ url: URL, withBrowser bundleId: String) -> Bool {
        guard let appURL = NSWorkspace.shared.urlForApplication(
            withBundleIdentifier: bundleId
        ) else {
            routingLogger.error(
                "Browser unavailable: \(bundleId, privacy: .public)"
            )
            return false
        }
        routingLogger.info(
            "Opening with \(bundleId, privacy: .public) at \(appURL.path, privacy: .public)"
        )
        let config = NSWorkspace.OpenConfiguration()
        NSWorkspace.shared.open(
            [url],
            withApplicationAt: appURL,
            configuration: config
        ) { _, error in
            if let error {
                self.routingLogger.error(
                    "Open failed for \(bundleId, privacy: .public): \(error.localizedDescription, privacy: .public)"
                )
            } else {
                self.routingLogger.info(
                    "Open completed for \(bundleId, privacy: .public)"
                )
            }
        }
        return true
    }
}
