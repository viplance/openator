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
        let s = url.absoluteString.lowercased()
        return rules.first { s.contains($0.urlContains.lowercased()) }
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
