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
}
