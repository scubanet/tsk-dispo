import XCTest
@testable import AtollHub

final class DesignHelpersTests: XCTestCase {
  func test_initials_firstAndLast() {
    XCTAssertEqual(Initials.from("Anna Muster"), "AM")
  }
  func test_initials_singleWordTakesTwoLetters() {
    XCTAssertEqual(Initials.from("Lumen"), "LU")
  }
  func test_initials_stripsNonLettersAndEmptyIsQuestion() {
    XCTAssertEqual(Initials.from("  "), "?")
    XCTAssertEqual(Initials.from("Tauchschule Z (GmbH)"), "TZ")
  }

  func test_avatarPalette_isDeterministicAndInRange() {
    let a = AvatarPalette.index(for: "Anna Muster", count: 10)
    let b = AvatarPalette.index(for: "Anna Muster", count: 10)
    XCTAssertEqual(a, b)
    XCTAssertTrue((0..<10).contains(a))
  }
  func test_avatarPalette_differsByName() {
    XCTAssertNotEqual(AvatarPalette.index(for: "Anna", count: 10),
                      AvatarPalette.index(for: "Ben", count: 10))
  }

  func test_greeting_byHour() {
    XCTAssertEqual(Greeting.phrase(forHour: 7), "Guten Morgen")
    XCTAssertEqual(Greeting.phrase(forHour: 13), "Guten Tag")
    XCTAssertEqual(Greeting.phrase(forHour: 20), "Guten Abend")
  }
}
