import Foundation
import SwiftUI

enum SkillStatus: String, CaseIterable, Codable {
    case notStarted
    case introduced
    case practiced
    case mastered
    case needsReview

    var cycleNext: SkillStatus {
        switch self {
        case .notStarted:  return .introduced
        case .introduced:  return .practiced
        case .practiced:   return .mastered
        case .mastered:    return .notStarted
        case .needsReview: return .practiced
        }
    }

    var displayLabel: String {
        let isDE = L10n.currentLanguage == "de"
        switch self {
        case .notStarted:  return isDE ? "Nicht begonnen" : "Not started"
        case .introduced:  return isDE ? "Eingeführt"     : "Introduced"
        case .practiced:   return isDE ? "Geübt"          : "Practiced"
        case .mastered:    return isDE ? "Gemeistert"     : "Mastered"
        case .needsReview: return isDE ? "Wdh. nötig"     : "Needs review"
        }
    }

    var sfSymbol: String {
        switch self {
        case .notStarted:  return "circle"
        case .introduced:  return "circle.lefthalf.filled"
        case .practiced:   return "circle.righthalf.filled"
        case .mastered:    return "checkmark.circle.fill"
        case .needsReview: return "exclamationmark.triangle.fill"
        }
    }

    var color: Color {
        switch self {
        case .notStarted:  return .gray
        case .introduced:  return .blue.opacity(0.7)
        case .practiced:   return .orange
        case .mastered:    return .green
        case .needsReview: return .red
        }
    }
}
