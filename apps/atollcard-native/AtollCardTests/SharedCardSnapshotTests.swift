import XCTest
@testable import AtollCard

final class SharedCardSnapshotTests: XCTestCase {
  func test_codable_roundtrip_preserves_all_fields() throws {
    let original = SharedCardSnapshot(
      slug:           "dominik-cd",
      title:          "PADI Course Director",
      badge:          "PADI CD",
      personInitials: "DW",
      publicURL:      URL(string: "https://atoll-os.com/c/dominik-cd")!,
      updatedAt:      Date(timeIntervalSince1970: 1_716_739_200)  // 2024-05-26T12:00:00Z
    )

    let data    = try SharedCardSnapshot.encoder.encode(original)
    let decoded = try SharedCardSnapshot.decoder.decode(SharedCardSnapshot.self, from: data)

    XCTAssertEqual(decoded, original)
  }

  func test_badge_nil_roundtrip() throws {
    let original = SharedCardSnapshot(
      slug: "privat",
      title: "Privat",
      badge: nil,
      personInitials: "DW",
      publicURL: URL(string: "https://atoll-os.com/c/privat")!,
      updatedAt: Date(timeIntervalSince1970: 0)
    )

    let data    = try SharedCardSnapshot.encoder.encode(original)
    let decoded = try SharedCardSnapshot.decoder.decode(SharedCardSnapshot.self, from: data)

    XCTAssertEqual(decoded, original)
    XCTAssertNil(decoded.badge)
  }

  func test_iso8601_date_format_is_stable() throws {
    let snapshot = SharedCardSnapshot(
      slug: "x", title: "X", badge: nil, personInitials: "X",
      publicURL: URL(string: "https://x.invalid")!,
      updatedAt: Date(timeIntervalSince1970: 1_716_739_200)
    )
    let data = try SharedCardSnapshot.encoder.encode(snapshot)
    let json = String(data: data, encoding: .utf8)!
    XCTAssertTrue(json.contains("\"updatedAt\":\"2024-05-26T"), "ISO-8601 prefix missing in \(json)")
  }
}
