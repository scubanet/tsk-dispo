import Foundation

enum MovementKind: String, Codable, Hashable {
    case payment   = "vergütung"
    case opening   = "übertrag"
    case correction = "korrektur"

    var label: String {
        switch self {
        case .payment:    "Vergütung"
        case .opening:    "Übertrag"
        case .correction: "Korrektur"
        }
    }
}

/// Saldo-Bewegung — entspricht Zeile in `account_movements`.
struct Movement: Codable, Identifiable, Hashable {
    let id: UUID
    let date: String                 // YYYY-MM-DD
    let amountChf: Double
    let kind: MovementKind
    let description: String?
    let breakdownJson: BreakdownData?
    let refAssignmentId: UUID?
    /// Embedded course (über ref_assignment_id → course_assignments → courses) — nur für Saldo-Filter.
    let courseAssignments: NestedAssignment?

    enum CodingKeys: String, CodingKey {
        case id, date, kind, description
        case amountChf = "amount_chf"
        case breakdownJson = "breakdown_json"
        case refAssignmentId = "ref_assignment_id"
        case courseAssignments = "course_assignments"
    }

    /// Zählt diese Bewegung in den Saldo? Vergütungen nur wenn Kurs completed.
    /// Übertrag und Korrektur (ohne ref_assignment_id) immer.
    var countsToBalance: Bool {
        guard refAssignmentId != nil else { return true }
        return courseAssignments?.courses?.status == .completed
    }

    var dateAsDate: Date? {
        AppDate.parseISODate(date)
    }
}

/// Container für PostgREST-Embed `course_assignments(courses(status))`.
struct NestedAssignment: Codable, Hashable {
    let courses: NestedCourse?
}

struct NestedCourse: Codable, Hashable {
    let status: CourseStatus?
}

/// Breakdown-Tabelle aus dem Comp-Engine (JSONB-Spalte breakdown_json).
struct BreakdownData: Codable, Hashable {
    let courseTypeCode: String?
    let role: String?
    let padiLevel: String?
    let theoryH: Double?
    let poolH: Double?
    let lakeH: Double?
    let totalH: Double?
    let share: Double?
    let hourlyRate: Double?

    enum CodingKeys: String, CodingKey {
        case role, share
        case courseTypeCode = "course_type_code"
        case padiLevel      = "padi_level"
        case theoryH        = "theory_h"
        case poolH          = "pool_h"
        case lakeH          = "lake_h"
        case totalH         = "total_h"
        case hourlyRate     = "hourly_rate"
    }
}
