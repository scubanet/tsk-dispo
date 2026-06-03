import XCTest
import AtollCore
@testable import AtollHub

final class AtollEventMapperTests: XCTestCase {
  // Baut ein Assignment aus dem Wire-JSON (so kommen die Daten aus PostgREST).
  private func assignment(_ json: String) throws -> Assignment {
    let decoder = JSONDecoder()
    return try decoder.decode(Assignment.self, from: Data(json.utf8))
  }

  func test_timedModule_becomesTimedEventWithModuleTitle() throws {
    let a = try assignment("""
    {
      "id": "11111111-1111-1111-1111-111111111111",
      "role": "haupt", "confirmed": true,
      "courses": {
        "id": "22222222-2222-2222-2222-222222222222",
        "title": "Open Water", "start_date": "2026-06-10",
        "status": "confirmed", "info": null, "notes": null,
        "location": "Zürich", "additional_dates": null,
        "course_types": null,
        "course_dates": [
          { "id": "33333333-3333-3333-3333-333333333333", "date": "2026-06-10",
            "has_theory": true, "has_pool": false, "has_lake": false,
            "theory_from": "18:00:00", "theory_to": "20:00:00",
            "pool_from": null, "pool_to": null, "lake_from": null, "lake_to": null,
            "pool_location": null, "pool_reserved": null, "note": null }
        ]
      }
    }
    """)
    let events = AtollEventMapper.events(from: [a], accountId: "atoll")
    XCTAssertEqual(events.count, 1)
    XCTAssertEqual(events[0].source, AccountRef(accountId: "atoll", type: .atoll))
    XCTAssertEqual(events[0].title, "Open Water — Theorie")
    XCTAssertFalse(events[0].isAllDay)
    XCTAssertEqual(events[0].location, "Zürich")
    XCTAssertTrue(events[0].id.hasPrefix("atoll:"))
  }

  func test_dayWithoutTimes_becomesAllDayEventWithRoleTitle() throws {
    let a = try assignment("""
    {
      "id": "11111111-1111-1111-1111-111111111111",
      "role": "assist", "confirmed": false,
      "courses": {
        "id": "22222222-2222-2222-2222-222222222222",
        "title": "Rescue", "start_date": "2026-06-12",
        "status": "tentative", "info": null, "notes": null,
        "location": null, "additional_dates": null, "course_types": null,
        "course_dates": [
          { "id": "44444444-4444-4444-4444-444444444444", "date": "2026-06-12",
            "has_theory": false, "has_pool": false, "has_lake": false,
            "theory_from": null, "theory_to": null,
            "pool_from": null, "pool_to": null, "lake_from": null, "lake_to": null,
            "pool_location": null, "pool_reserved": null, "note": null }
        ]
      }
    }
    """)
    let events = AtollEventMapper.events(from: [a], accountId: "atoll")
    XCTAssertEqual(events.count, 1)
    XCTAssertTrue(events[0].isAllDay)
    XCTAssertEqual(events[0].title, "Rescue (assist)")
  }

  func test_cancelledCourse_isSkipped() throws {
    let a = try assignment("""
    {
      "id": "11111111-1111-1111-1111-111111111111",
      "role": "haupt", "confirmed": true,
      "courses": {
        "id": "22222222-2222-2222-2222-222222222222",
        "title": "X", "start_date": "2026-06-10", "status": "cancelled",
        "info": null, "notes": null, "location": null, "additional_dates": null,
        "course_types": null, "course_dates": [] }
    }
    """)
    XCTAssertTrue(AtollEventMapper.events(from: [a], accountId: "atoll").isEmpty)
  }

  func test_poolModuleUsesPoolLocation() throws {
    let a = try assignment("""
    {
      "id": "11111111-1111-1111-1111-111111111111",
      "role": "haupt", "confirmed": true,
      "courses": {
        "id": "22222222-2222-2222-2222-222222222222",
        "title": "AOWD", "start_date": "2026-06-11", "status": "confirmed",
        "info": null, "notes": null, "location": "Zürich", "additional_dates": null,
        "course_types": null,
        "course_dates": [
          { "id": "55555555-5555-5555-5555-555555555555", "date": "2026-06-11",
            "has_theory": false, "has_pool": true, "has_lake": false,
            "theory_from": null, "theory_to": null,
            "pool_from": "09:00:00", "pool_to": "11:00:00",
            "lake_from": null, "lake_to": null,
            "pool_location": "Mooesli", "pool_reserved": true, "note": null }
        ]
      }
    }
    """)
    let events = AtollEventMapper.events(from: [a], accountId: "atoll")
    XCTAssertEqual(events.count, 1)
    XCTAssertEqual(events[0].title, "AOWD — Pool")
    XCTAssertEqual(events[0].location, "Mooesli")
  }
}
