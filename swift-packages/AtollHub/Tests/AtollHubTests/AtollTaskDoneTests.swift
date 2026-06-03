import XCTest
@testable import AtollHub

final class AtollTaskDoneTests: XCTestCase {
  func test_donePatch_setsResolvedAndCompletedAt() {
    let now = Date(timeIntervalSince1970: 1_700_000_000)
    let p = AtollTaskDone.patch(isDone: true, now: now)
    XCTAssertEqual(p.status, "resolved")
    XCTAssertNotNil(p.completedAt)
    XCTAssertTrue(p.completedAt?.contains("2023") ?? false)
  }
  func test_undonePatch_setsOpenAndNilCompletedAt() {
    let p = AtollTaskDone.patch(isDone: false, now: Date())
    XCTAssertEqual(p.status, "open")
    XCTAssertNil(p.completedAt)
  }
}
