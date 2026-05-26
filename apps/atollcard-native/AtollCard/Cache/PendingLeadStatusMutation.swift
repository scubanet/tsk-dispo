import Foundation
import SwiftData

/// One pending offline status-change for a `Lead`. The `MutationDrainer`
/// pulls these FIFO on reachability recovery and posts them to the remote.
///
/// `id` is the unique mutation id (NOT `leadId` — multiple mutations per
/// lead may be queued, e.g. opened → contacted → archived).
///
/// `isDead` flips to true after 5 failed attempts; the row stays in store
/// so the user can retry or discard from the Dead-Letter UI.
@Model
final class PendingLeadStatusMutation {
  @Attribute(.unique) var id: UUID    // unique mutation id (NOT leadId — multiple mutations per lead are allowed)
  var leadId:        UUID
  var newStatus:     String           // LeadStatus.rawValue
  var enqueuedAt:    Date
  var attempts:      Int
  var lastError:     String?
  var lastAttemptAt: Date?
  var isDead:        Bool

  init(id: UUID, leadId: UUID, newStatus: String, enqueuedAt: Date,
       attempts: Int, lastError: String? = nil, lastAttemptAt: Date? = nil,
       isDead: Bool = false) {
    self.id = id; self.leadId = leadId; self.newStatus = newStatus
    self.enqueuedAt = enqueuedAt; self.attempts = attempts
    self.lastError = lastError; self.lastAttemptAt = lastAttemptAt
    self.isDead = isDead
  }
}
