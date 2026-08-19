import AppKit

struct BrowserInfo {
    let bundleId: String
    let name: String
}

final class BrowserManager {
    static let shared = BrowserManager()
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
        ) else { return false }
        let config = NSWorkspace.OpenConfiguration()
        NSWorkspace.shared.open(
            [url],
            withApplicationAt: appURL,
            configuration: config
        )
        return true
    }
}
