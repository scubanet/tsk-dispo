import XCTest
@testable import Speech

final class SpeechTests: XCTestCase {
  func testProtocolShapeIsStable() {
    // Compile-only check: AppleSpeechRecognizer conforms.
    let _: any SpeechRecognizer.Type = AppleSpeechRecognizer.self
  }
}
