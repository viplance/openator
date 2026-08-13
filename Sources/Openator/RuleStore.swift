import Foundation

struct URLRule: Codable {
    let id: UUID
    var urlContains: String
    var browserBundleId: String
}

final class RuleStore {
    static let shared = RuleStore()
    private let key = "url_rules"

    var rules: [URLRule] {
        get {
            guard let data = UserDefaults.standard.data(forKey: key),
                  let decoded = try? JSONDecoder().decode([URLRule].self, from: data)
            else { return [] }
            return decoded
        }
        set {
            let data = try? JSONEncoder().encode(newValue)
            UserDefaults.standard.set(data, forKey: key)
        }
    }

    func matchingRule(for url: URL) -> URLRule? {
        let candidates = Self.matchCandidates(for: url)
        return rules.first { rule in
            let pattern = rule.urlContains
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .lowercased()
            return !pattern.isEmpty && candidates.contains { $0.contains(pattern) }
        }
    }

    /// Match both the URL delivered by LaunchServices and URLs embedded in redirect
    /// wrappers (Slack, mail clients, and trackers commonly percent-encode them).
    static func matchCandidates(for url: URL) -> [String] {
        var candidates: [String] = []
        var candidate = url.absoluteString.lowercased()

        for _ in 0..<3 {
            if !candidates.contains(candidate) {
                candidates.append(candidate)
            }
            guard let decoded = candidate.removingPercentEncoding?.lowercased(),
                  decoded != candidate else { break }
            candidate = decoded
        }
        return candidates
    }

    func addRule(_ rule: URLRule) {
        var current = rules
        current.append(rule)
        rules = current
    }

    func updateRule(_ rule: URLRule) {
        var current = rules
        if let i = current.firstIndex(where: { $0.id == rule.id }) {
            current[i] = rule
            rules = current
        }
    }

    func removeRule(id: UUID) {
        var current = rules
        current.removeAll { $0.id == id }
        rules = current
    }

    func removeAll() {
        rules = []
    }
}
