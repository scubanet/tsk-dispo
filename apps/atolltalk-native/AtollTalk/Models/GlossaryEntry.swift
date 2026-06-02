import Foundation

struct GlossaryEntry: Codable, Identifiable, Equatable, Sendable {
  var id: UUID = UUID()
  var de: String
  var uk: String
}
