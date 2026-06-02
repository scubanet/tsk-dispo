import Foundation
import SwiftData

@MainActor
struct ConversationStore {
  let context: ModelContext

  func add(_ turn: Turn) {
    context.insert(turn)
    try? context.save()
  }

  func allNewestFirst() throws -> [Turn] {
    try context.fetch(
      FetchDescriptor<Turn>(sortBy: [SortDescriptor(\.createdAt, order: .reverse)])
    )
  }

  func clear() throws {
    try context.delete(model: Turn.self)
    try context.save()
  }
}
