import Combine
import CoreData
import SwiftData
import SwiftUI

/// Listens for CloudKit import events and schedules a debounced renumber
/// of all Dive records so that a sync from another device converges on the
/// same deterministic numbering as the local device.
///
/// Debounce window: 1 second.  Multiple in-flight imports collapse into a
/// single renumber pass, preventing UI flicker during a sync flurry.
///
/// Lifecycle: owned by `DiveLogProApp` via `@State`.  SwiftUI's runtime
/// keeps the App struct (and therefore the `@State` storage) alive for the
/// entire process lifetime, so the coordinator receives every notification.
@MainActor
final class CloudKitRenumberCoordinator {
    private let container: ModelContainer
    private var cancellable: AnyCancellable?
    private var debounceTask: Task<Void, Never>?

    init(container: ModelContainer) {
        self.container = container
        cancellable = NotificationCenter.default
            .publisher(for: NSPersistentCloudKitContainer.eventChangedNotification)
            .sink { [weak self] note in
                self?.handleEvent(note)
            }
    }

    private func handleEvent(_ note: Notification) {
        guard
            let event = note.userInfo?[NSPersistentCloudKitContainer.eventNotificationUserInfoKey]
                as? NSPersistentCloudKitContainer.Event,
            event.type == .import,
            event.endDate != nil          // ignore in-progress events
        else { return }

        // Cancel any pending debounce window and start a fresh one.
        debounceTask?.cancel()
        debounceTask = Task { @MainActor [container] in
            try? await Task.sleep(for: .seconds(1))
            guard !Task.isCancelled else { return }

            let ctx = ModelContext(container)
            guard let profile = (try? ctx.fetch(FetchDescriptor<DiverProfile>()))?.first else { return }
            ctx.renumberDives(from: profile)
            try? ctx.save()
        }
    }

    deinit {
        cancellable?.cancel()
        debounceTask?.cancel()
    }
}
