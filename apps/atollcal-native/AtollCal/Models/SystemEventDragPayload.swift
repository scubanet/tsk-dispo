import Foundation
import SwiftUI
import CoreTransferable
import UniformTypeIdentifiers
import EventKit
import AtollCore

/// In-app drag payload for System (EventKit) calendar events. Carries only
/// the EKEvent persistent identifier — the drop handler looks the event back
/// up via `SystemCalendarStore.event(withIdentifier:)` to mutate it.
///
/// ATOLL events are deliberately not draggable; rescheduling them lives on
/// the admin web flow against Supabase, not on the calendar surface.
struct SystemEventDragPayload: Codable, Transferable {
  let eventIdentifier: String
  /// Duration in minutes — used by the drop handler to shift the cursor
  /// position by half the event height, so the cursor "feels" anchored at
  /// the event's center instead of its top edge.
  let durationMinutes: Int

  static var transferRepresentation: some TransferRepresentation {
    CodableRepresentation(contentType: .atollSystemEvent)
  }
}

extension UTType {
  /// In-process UTI for system event drags. Not registered in Info.plist —
  /// drags don't cross the app boundary, so OS-level registration isn't
  /// required.
  static let atollSystemEvent = UTType(exportedAs: "swiss.atoll.cal.system-event")
}

extension CalendarEvent {
  /// True for System events whose backing EKEvent is in a writable calendar
  /// and has a stable identifier. ATOLL events always return false.
  var isReschedulable: Bool {
    guard case .system(let ek) = self,
          ek.eventIdentifier != nil,
          ek.calendar?.allowsContentModifications == true
    else { return false }
    return true
  }

  /// Drag payload for this event, or `nil` when the event cannot be moved.
  var dragPayload: SystemEventDragPayload? {
    guard case .system(let ek) = self, let id = ek.eventIdentifier else { return nil }
    let durationMin = max(1, Int(ek.endDate.timeIntervalSince(ek.startDate) / 60))
    return SystemEventDragPayload(eventIdentifier: id, durationMinutes: durationMin)
  }
}

extension View {
  /// Attaches `.draggable(_:)` only when the payload is non-nil. Lets call
  /// sites stay branch-free for ATOLL/system mix.
  @ViewBuilder
  func draggableIfPossible<T: Transferable>(_ payload: T?) -> some View {
    if let payload {
      self.draggable(payload)
    } else {
      self
    }
  }
}

/// Live drag/drop state for the calendar grids — captures the current cursor
/// y inside the drop target and, once the dragged payload has been
/// asynchronously loaded, the duration of the dragged event so the live
/// preview can anchor at the event center.
@MainActor
@Observable
final class CalendarDropState {
  var hoverY: CGFloat?
  /// Which day column / day cell currently has the cursor inside it. Lets
  /// multi-column views (WeekView) render the live hint only in the hovered
  /// column.
  var activeDayStart: Date?

  func reset() {
    hoverY = nil
    activeDayStart = nil
  }
}

/// `DropDelegate` that powers the time-grid drop zones (DayView / WeekView).
/// Tracks live cursor y and exposes the dragged payload for the perform
/// callback. The async `loadDataRepresentation` round-trip is needed because
/// `DropDelegate` doesn't expose the typed payload directly — only an
/// `NSItemProvider` which we decode manually.
struct CalendarRescheduleDropDelegate: DropDelegate {
  let state: CalendarDropState
  /// Day this drop zone represents (used to disambiguate which column in a
  /// multi-column view should render the live hint).
  let dayStart: Date
  let onPerform: @MainActor (SystemEventDragPayload, CGFloat) -> Bool

  func validateDrop(info: DropInfo) -> Bool {
    info.hasItemsConforming(to: [.atollSystemEvent])
  }

  func dropEntered(info: DropInfo) {
    state.hoverY = info.location.y
    state.activeDayStart = dayStart
  }

  func dropUpdated(info: DropInfo) -> DropProposal? {
    state.hoverY = info.location.y
    state.activeDayStart = dayStart
    return DropProposal(operation: .move)
  }

  func dropExited(info: DropInfo) {
    // Only clear if we're still the active column. When dragging across
    // multiple drop zones (WeekView columns), `dropEntered` for the new
    // column may have already set `activeDayStart` to a different day —
    // in that case we must not wipe it here.
    if state.activeDayStart == dayStart {
      state.reset()
    }
  }

  func performDrop(info: DropInfo) -> Bool {
    let providers = info.itemProviders(for: [.atollSystemEvent])
    let location = info.location
    let capturedState = state
    let perform = onPerform

    Task { @MainActor in
      defer { capturedState.reset() }
      guard let payload = await Self.decodePayload(from: providers) else { return }
      _ = perform(payload, location.y)
    }
    return true
  }

  /// Wraps `NSItemProvider.loadDataRepresentation`'s callback API in an async
  /// helper so callers can stay on `MainActor` end-to-end and dodge Swift 6
  /// "sending closure" data-race warnings.
  private static func decodePayload(from providers: [NSItemProvider]) async -> SystemEventDragPayload? {
    guard let provider = providers.first else { return nil }
    let typeID = UTType.atollSystemEvent.identifier
    let data: Data? = await withCheckedContinuation { cont in
      provider.loadDataRepresentation(forTypeIdentifier: typeID) { data, _ in
        cont.resume(returning: data)
      }
    }
    guard let data else { return nil }
    return try? JSONDecoder().decode(SystemEventDragPayload.self, from: data)
  }
}
