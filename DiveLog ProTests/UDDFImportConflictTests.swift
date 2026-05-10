import Testing
import Foundation
@testable import DiveLog_Pro

@Suite("UDDF Import Conflict Detection")
struct UDDFImportConflictTests {

    private func makeDive(date: Date, depth: Double) -> Dive {
        Dive(number: 100, date: date, maxDepth: depth)
    }

    @Test("identical datetime + depth is a duplicate")
    func exactMatch() {
        let date = Date()
        let existing = [makeDive(date: date, depth: 15.0)]
        let new = makeDive(date: date, depth: 15.0)
        let conflict = UDDFImportCoordinator.findConflict(for: new, in: existing)
        #expect(conflict != nil)
        #expect(conflict?.number == 100)
    }

    @Test("3-minute drift + same depth is a duplicate")
    func nearMatchWithinTolerance() {
        let date = Date()
        let drifted = date.addingTimeInterval(180)
        let existing = [makeDive(date: date, depth: 15.0)]
        let new = makeDive(date: drifted, depth: 15.0)
        #expect(UDDFImportCoordinator.findConflict(for: new, in: existing) != nil)
    }

    @Test("6-minute drift is NOT a duplicate")
    func driftBeyondTolerance() {
        let date = Date()
        let drifted = date.addingTimeInterval(360)
        let existing = [makeDive(date: date, depth: 15.0)]
        let new = makeDive(date: drifted, depth: 15.0)
        #expect(UDDFImportCoordinator.findConflict(for: new, in: existing) == nil)
    }

    @Test("same time but 1m depth difference is NOT a duplicate")
    func depthBeyondTolerance() {
        let date = Date()
        let existing = [makeDive(date: date, depth: 15.0)]
        let new = makeDive(date: date, depth: 16.0)
        #expect(UDDFImportCoordinator.findConflict(for: new, in: existing) == nil)
    }

    @Test("same time and 0.3m depth difference IS a duplicate")
    func depthWithinTolerance() {
        let date = Date()
        let existing = [makeDive(date: date, depth: 15.0)]
        let new = makeDive(date: date, depth: 15.3)
        #expect(UDDFImportCoordinator.findConflict(for: new, in: existing) != nil)
    }
}
