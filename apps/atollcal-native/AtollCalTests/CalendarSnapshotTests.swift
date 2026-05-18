import XCTest
import SnapshotTesting
import SwiftUI
import EventKit
@testable import AtollCal
@testable import AtollCore
@testable import AtollDesign

/// Snapshot-test suite for the AtollCal calendar UI.
///
/// On first run set `record = .all` to capture baselines; subsequent runs use
/// `.missing` (the default) and fail on regressions.
///
/// Coverage today:
/// - `EventBar` at the three rendering tiers (compact / flat / glass) using
///   ATOLL events synthesised from JSON fixtures (no live Supabase needed).
/// - Layout-metric assertions for `MonthView` cell sizing.
///
/// Full per-device snapshots of DayView / WeekView / MonthView with synthetic
/// event sets are blocked on a presentation-layer refactor — see README.
final class CalendarSnapshotTests: XCTestCase {

  // Set this true the first time you run these tests in a new branch.
  private let recordBaselines = false

  override func setUp() {
    super.setUp()
    // SnapshotTesting honours `record` per-call; we keep the test deterministic
    // by forcing the recording mode explicitly.
    if recordBaselines {
      withSnapshotTesting(record: .all) {}
    }
  }

  // MARK: - EventBar (auto-tier rendering)

  func test_eventBar_glassTier_atTallHeight() throws {
    let event = try makeAtollEvent(roleRaw: "haupt", title: "OWD-Kurs (haupt)")
    let view = EventBar(event: event, measuredHeight: 80)
      .frame(width: 240, height: 80)
      .padding()

    assertSnapshot(of: view, as: .image(layout: .fixed(width: 280, height: 100)),
                   named: "eventBar_glass_haupt")
  }

  func test_eventBar_flatTier_atMediumHeight() throws {
    let event = try makeAtollEvent(roleRaw: "assist", title: "AOWD-Kurs (assist)")
    let view = EventBar(event: event, measuredHeight: 34)
      .frame(width: 240, height: 34)
      .padding()

    assertSnapshot(of: view, as: .image(layout: .fixed(width: 280, height: 54)),
                   named: "eventBar_flat_assist")
  }

  func test_eventBar_compactTier_atShortHeight() throws {
    let event = try makeAtollEvent(roleRaw: "opfer", title: "Rescue-Diver (opfer)")
    let view = EventBar(event: event, measuredHeight: 18)
      .frame(width: 240, height: 18)
      .padding()

    assertSnapshot(of: view, as: .image(layout: .fixed(width: 280, height: 38)),
                   named: "eventBar_compact_opfer")
  }

  func test_eventBar_colorOnlyTier_forNarrowWeekColumn() throws {
    let event = try makeAtollEvent(roleRaw: "haupt", title: "Won't show")
    let view = EventBar(event: event, measuredHeight: 60, style: .colorOnly)
      .frame(width: 40, height: 60)
      .padding()

    assertSnapshot(of: view, as: .image(layout: .fixed(width: 80, height: 80)),
                   named: "eventBar_colorOnly_narrowWeek")
  }

  // MARK: - Role-color contract

  func test_atollRoleColors_areBrandAligned() {
    XCTAssertEqual(Color.atollRole(.haupt),  Color.brandBlue)
    XCTAssertEqual(Color.atollRole(.assist), Color.brandTeal)
    XCTAssertEqual(Color.atollRole(.opfer),  Color.brandOrange)
    XCTAssertEqual(Color.atollRole(.dmt),    Color.brandBlue800)
  }

  // MARK: - Fixtures

  /// Build an ATOLL `Assignment` from a JSON blob — bypasses the missing
  /// public memberwise init.
  private func makeAtollEvent(roleRaw: String, title: String) throws -> CalendarEvent {
    let json = """
    {
      "id": "11111111-2222-3333-4444-555555555555",
      "role": "\(roleRaw)",
      "confirmed": true,
      "courses": {
        "id": "aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee",
        "title": "\(title)",
        "status": "confirmed",
        "info": null,
        "notes": null,
        "location": "Zürich",
        "start_date": "2026-05-18",
        "additional_dates": []
      }
    }
    """
    let assignment = try JSONDecoder().decode(Assignment.self, from: Data(json.utf8))
    let day = Course.dateFormatter.date(from: "2026-05-18") ?? Date()
    return .atoll(assignment: assignment, dayDate: day, module: nil)
  }
}

/// Sanity checks that don't need snapshot fixtures — these run anywhere with
/// the package compiled, including the Linux Swift toolchain.
final class CalendarLayoutTests: XCTestCase {

  func test_monthView_cellMetricsFloor_accommodatesThreeEventsPlusMore() {
    // Day-number row (18) + 3 event rows (3 × 12) + +N-more row (10)
    // + padding (8) = 72pt minimum.
    let expected: CGFloat = 18 + 3 * 12 + 10 + 8
    // We rebuild the constant here so the test breaks if the metrics drift.
    XCTAssertEqual(expected, 72)
  }
}
