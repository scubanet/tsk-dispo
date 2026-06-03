import XCTest
@testable import AtollHub

final class KomboxMapperTests: XCTestCase {
  private func rows(_ json: String) throws -> [KomboxEventRow] {
    try JSONDecoder().decode([KomboxEventRow].self, from: Data(json.utf8))
  }

  func test_mapsWhatsappOutboundWithContactName() throws {
    let r = try rows("""
    [{
      "id": "e1", "contact_id": "c1", "event_type": "whatsapp_log",
      "occurred_at": "2026-06-02T14:30:00+00:00",
      "summary": "Hallo", "body": "Hallo Welt", "status": "open",
      "payload": {"direction": "outbound"},
      "contacts": {"id":"c1","kind":"person","first_name":"Anna","last_name":"Muster"}
    }]
    """)
    let events = KomboxMapper.events(from: r)
    XCTAssertEqual(events.count, 1)
    let e = events[0]
    XCTAssertEqual(e.id, "e1")
    XCTAssertEqual(e.contactId, "c1")
    XCTAssertEqual(e.contactName, "Anna Muster")
    XCTAssertEqual(e.kind, .whatsapp)
    XCTAssertEqual(e.direction, .outbound)
    XCTAssertEqual(e.summary, "Hallo")
    XCTAssertNil(e.subject)
  }

  func test_mapsEmailInboundWithSubjectFromPayload() throws {
    let r = try rows("""
    [{
      "id": "e2", "contact_id": "c2", "event_type": "email_external",
      "occurred_at": "2026-06-02T08:15:00+00:00",
      "summary": "Re: Kurs", "body": "Text", "status": "open",
      "payload": {"direction": "inbound", "subject": "Re: Kurs"},
      "contacts": {"id":"c2","kind":"organization","trading_name":"Tauchschule Z"}
    }]
    """)
    let e = KomboxMapper.events(from: r)[0]
    XCTAssertEqual(e.kind, .email)
    XCTAssertEqual(e.direction, .inbound)
    XCTAssertEqual(e.subject, "Re: Kurs")
    XCTAssertEqual(e.contactName, "Tauchschule Z")
  }

  func test_unknownTypeBecomesSystemAndNilDirection() throws {
    let r = try rows("""
    [{
      "id": "e3", "contact_id": "c3", "event_type": "irgendwas",
      "occurred_at": "2026-06-02T09:00:00+00:00",
      "summary": "Notiz", "body": null, "status": "open",
      "payload": null, "contacts": {"id":"c3","first_name":"Ben","last_name":"B"}
    }]
    """)
    let e = KomboxMapper.events(from: r)[0]
    XCTAssertEqual(e.kind, .system)
    XCTAssertNil(e.direction)
  }

  func test_mapsLogEventTypesToOwnKinds() throws {
    let r = try rows("""
    [
      {"id":"n","contact_id":"c","event_type":"note","occurred_at":"2026-06-02T09:00:00+00:00",
       "summary":"Notiz","body":null,"status":"open","payload":null,
       "contacts":{"id":"c","first_name":"A","last_name":"B"}},
      {"id":"a","contact_id":"c","event_type":"call","occurred_at":"2026-06-02T09:01:00+00:00",
       "summary":"Anruf","body":null,"status":"open","payload":null,
       "contacts":{"id":"c","first_name":"A","last_name":"B"}},
      {"id":"m","contact_id":"c","event_type":"meeting_past","occurred_at":"2026-06-02T09:02:00+00:00",
       "summary":"Meeting","body":null,"status":"open","payload":null,
       "contacts":{"id":"c","first_name":"A","last_name":"B"}},
      {"id":"t","contact_id":"c","event_type":"task","occurred_at":"2026-06-02T09:03:00+00:00",
       "summary":"Aufgabe","body":null,"status":"open","payload":null,
       "contacts":{"id":"c","first_name":"A","last_name":"B"}}
    ]
    """)
    let kinds = Dictionary(uniqueKeysWithValues: KomboxMapper.events(from: r).map { ($0.id, $0.kind) })
    XCTAssertEqual(kinds["n"], .note)
    XCTAssertEqual(kinds["a"], .call)
    XCTAssertEqual(kinds["m"], .meeting)
    XCTAssertEqual(kinds["t"], .task)
  }

  func test_parsesFractionalSecondsTimestamp() throws {
    let r = try rows("""
    [{
      "id": "e4", "contact_id": "c4", "event_type": "whatsapp_log",
      "occurred_at": "2026-06-02T14:30:00.123456+00:00",
      "summary": "x", "body": null, "status": "open",
      "payload": {"direction":"inbound"}, "contacts": {"id":"c4","first_name":"A","last_name":"B"}
    }]
    """)
    XCTAssertEqual(KomboxMapper.events(from: r).count, 1)
  }

  func test_dropsRowWithUnparsableTimestamp() throws {
    let r = try rows("""
    [{
      "id": "bad", "contact_id": "c5", "event_type": "note",
      "occurred_at": "not-a-date",
      "summary": "x", "body": null, "status": "open",
      "payload": null, "contacts": {"id":"c5","first_name":"A","last_name":"B"}
    }]
    """)
    XCTAssertTrue(KomboxMapper.events(from: r).isEmpty)
  }
}
