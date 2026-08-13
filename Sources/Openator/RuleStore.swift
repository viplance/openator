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
    /// When a query parameter contains a JWT, only string values from its payload
    /// are considered. The wrapper URL must not affect routing in that case.
    static func matchCandidates(for url: URL) -> [String] {
        if let jwtCandidates = jwtPayloadCandidates(in: url) {
            return jwtCandidates
        }

        return decodedCandidates(from: url.absoluteString)
    }

    private static func decodedCandidates(from value: String) -> [String] {
        var candidates: [String] = []
        var candidate = value.lowercased()

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

    /// Returns nil when the URL has no valid JWT query value. A non-nil result
    /// deliberately replaces candidates derived from the wrapper URL.
    private static func jwtPayloadCandidates(in url: URL) -> [String]? {
        guard let queryItems = URLComponents(
            url: url,
            resolvingAgainstBaseURL: false
        )?.queryItems else { return nil }

        var foundJWT = false
        var candidates: [String] = []

        for value in queryItems.compactMap(\.value) {
            let segments = value.split(
                separator: ".",
                omittingEmptySubsequences: false
            )
            guard segments.count == 3,
                  let payloadData = decodeBase64URL(String(segments[1])),
                  let payload = try? JSONSerialization.jsonObject(with: payloadData),
                  payload is [String: Any]
            else { continue }

            foundJWT = true
            collectStringCandidates(from: payload, into: &candidates)
        }

        guard foundJWT else { return nil }
        var seen = Set<String>()
        return candidates.filter { seen.insert($0).inserted }
    }

    private static func decodeBase64URL(_ value: String) -> Data? {
        var base64 = value
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        let remainder = base64.count % 4
        if remainder != 0 {
            base64 += String(repeating: "=", count: 4 - remainder)
        }
        return Data(base64Encoded: base64)
    }

    private static func collectStringCandidates(
        from value: Any,
        into candidates: inout [String]
    ) {
        switch value {
        case let string as String:
            candidates.append(contentsOf: decodedCandidates(from: string))
        case let dictionary as [String: Any]:
            for nestedValue in dictionary.values {
                collectStringCandidates(from: nestedValue, into: &candidates)
            }
        case let array as [Any]:
            for nestedValue in array {
                collectStringCandidates(from: nestedValue, into: &candidates)
            }
        default:
            break
        }
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
