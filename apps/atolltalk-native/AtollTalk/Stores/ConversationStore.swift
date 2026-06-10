import Foundation
import SwiftData

@MainActor
struct ConversationStore {
  let context: ModelContext
  // Hold the container strongly so it outlives async suspension points in tests.
  private let _container: ModelContainer

  init(context: ModelContext) {
    self.context = context
    self._container = context.container
  }

  func add(_ turn: Turn) {
    context.insert(turn)
    try? context.save()
  }

  func allNewestFirst() throws -> [Turn] {
    try context.fetch(
      FetchDescriptor<Turn>(sortBy: [SortDescriptor(\.createdAt, order: .reverse)])
    )
  }

  func delete(_ turn: Turn) throws {
    context.delete(turn)
    try context.save()
  }

  func clear() throws {
    try context.delete(model: Turn.self)
    try context.save()
  }
}
