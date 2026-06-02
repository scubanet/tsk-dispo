import XCTest
@testable import AtollHub

final class ProvidersTests: XCTestCase {
  func test_fakeCalendar_conformsAndFiltersByInterval() async throws {
    let provider: CalendarProvider = FakeCalendar([
      makeEvent("inside", type: .apple, start: 100),
      makeEvent("outside", type: .apple, start: 10_000),
    ])
    let window = DateInterval(start: Date(timeIntervalSince1970: 0),
                              end: Date(timeIntervalSince1970: 1_000))
    let result = try await provider.events(in: window)
    XCTAssertEqual(result.map(\.id), ["inside"])
  }
}
