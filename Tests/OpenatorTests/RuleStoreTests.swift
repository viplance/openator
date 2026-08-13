import XCTest
@testable import Openator

final class RuleStoreTests: XCTestCase {
    func testPlainURLIsMatchCandidate() throws {
        let url = try XCTUnwrap(URL(string: "https://n-rich.atlassian.net/browse/NRICH-13416"))
        XCTAssertTrue(RuleStore.matchCandidates(for: url).contains {
            $0.contains("n-rich")
        })
    }

    func testPercentEncodedRedirectIsDecodedForMatching() throws {
        let url = try XCTUnwrap(URL(string:
            "https://redirect.example/open?url=https%3A%2F%2Fn-rich.atlassian.net%2Fbrowse%2FNRICH-13416"
        ))
        XCTAssertTrue(RuleStore.matchCandidates(for: url).contains {
            $0.contains("n-rich.atlassian.net")
        })
    }

    func testJWTRedirectUsesPayloadTargetURI() throws {
        let payload = try XCTUnwrap(
            """
            {"iss":"https://issuer.example","https://slack.com/target_uri":"https://n-rich.atlassian.net/browse/NRICH-13498"}
            """.data(using: .utf8)
        )
        let token = "header.\(base64URL(payload)).signature"
        let encodedToken = try XCTUnwrap(
            token.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)
        )
        let url = try XCTUnwrap(URL(string:
            "https://slack.com/openid/connect/login_initiate_redirect?login_hint=\(encodedToken)"
        ))

        let candidates = RuleStore.matchCandidates(for: url)
        XCTAssertTrue(candidates.contains { $0.contains("n-rich.atlassian.net") })
        XCTAssertFalse(candidates.contains { $0.contains("login_initiate_redirect") })
    }

    func testValidJWTDoesNotMatchWrapperURL() throws {
        let payload = try XCTUnwrap(
            "{\"target_uri\":\"https://example.com\"}".data(using: .utf8)
        )
        let token = "header.\(base64URL(payload)).signature"
        let url = try XCTUnwrap(URL(string:
            "https://outer-wrapper.example/open?token=\(token)"
        ))

        XCTAssertFalse(RuleStore.matchCandidates(for: url).contains {
            $0.contains("outer-wrapper.example")
        })
    }

    private func base64URL(_ data: Data) -> String {
        data.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}
