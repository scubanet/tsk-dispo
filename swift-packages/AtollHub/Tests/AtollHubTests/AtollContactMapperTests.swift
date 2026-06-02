import XCTest
@testable import AtollHub

final class AtollContactMapperTests: XCTestCase {
  private func rows(_ json: String) throws -> [AtollContactRow] {
    try JSONDecoder().decode([AtollContactRow].self, from: Data(json.utf8))
  }

  func test_mapsPersonWithEmailsAndPhones() throws {
    let r = try rows("""
    [{
      "id": "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa",
      "kind": "person", "first_name": "Anna", "last_name": "Muster",
      "primary_email": "anna@example.com",
      "emails": [{"label":"work","email":"anna@example.com","primary":true},
                 {"label":"home","email":"a.muster@gmx.ch"}],
      "phones": [{"label":"mobile","e164":"+41791234567","whatsapp":true}]
    }]
    """)
    let contacts = AtollContactMapper.contacts(from: r, accountId: "atoll")
    XCTAssertEqual(contacts.count, 1)
    let c = contacts[0]
    XCTAssertEqual(c.id, "atoll:aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa")
    XCTAssertEqual(c.source.type, .atoll)
    XCTAssertEqual(c.firstName, "Anna")
    XCTAssertEqual(c.lastName, "Muster")
    XCTAssertEqual(c.emails, ["anna@example.com", "a.muster@gmx.ch"])
    XCTAssertEqual(c.phones, ["+41791234567"])
  }

  func test_organizationUsesTradingNameAsFirstNameFallback() throws {
    let r = try rows("""
    [{
      "id": "bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb",
      "kind": "organization", "first_name": null, "last_name": null,
      "trading_name": "Tauchschule Z", "legal_name": "Tauchschule Z GmbH",
      "primary_email": "info@tsz.ch", "emails": null, "phones": null
    }]
    """)
    let c = AtollContactMapper.contacts(from: r, accountId: "atoll")[0]
    XCTAssertEqual(c.firstName, "")
    XCTAssertEqual(c.lastName, "Tauchschule Z")
    XCTAssertEqual(c.emails, ["info@tsz.ch"])
  }

  func test_deduplicatesPrimaryEmailAlreadyInArray() throws {
    let r = try rows("""
    [{
      "id": "cccccccc-cccc-cccc-cccc-cccccccccccc",
      "kind": "person", "first_name": "Ben", "last_name": "B",
      "primary_email": "ben@x.ch",
      "emails": [{"label":"work","email":"ben@x.ch"}],
      "phones": null
    }]
    """)
    let c = AtollContactMapper.contacts(from: r, accountId: "atoll")[0]
    XCTAssertEqual(c.emails, ["ben@x.ch"])
  }
}
