import Foundation
import Combine
import CoreLocation

/// Single-shot location wrapper. Call `requestOneShot()` from MainActor context.
/// Handles permission prompting, success, failure, and an 8-second timeout fallback.
@MainActor
final class LocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    private var continuation: CheckedContinuation<CLLocation, Error>?
    private var timeoutTask: Task<Void, Never>?

    @Published var authStatus: CLAuthorizationStatus = .notDetermined

    enum LocationError: LocalizedError {
        case permissionDenied
        case timeout
        case unavailable

        var errorDescription: String? {
            switch self {
            case .permissionDenied: return "Location permission denied."
            case .timeout:          return "Location request timed out."
            case .unavailable:      return "Location services unavailable."
            }
        }
    }

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
        authStatus = manager.authorizationStatus
    }

    /// Requests one location, or throws. Handles permission prompting.
    func requestOneShot() async throws -> CLLocation {
        if authStatus == .notDetermined {
            manager.requestWhenInUseAuthorization()
            // Poll up to 3s for permission dialog resolution
            for _ in 0..<30 {
                try await Task.sleep(nanoseconds: 100_000_000)
                if authStatus != .notDetermined { break }
            }
        }
        guard authStatus == .authorizedWhenInUse || authStatus == .authorizedAlways else {
            throw LocationError.permissionDenied
        }

        return try await withCheckedThrowingContinuation { cont in
            self.continuation = cont
            self.manager.requestLocation()

            // 8s timeout safety net — cancelled when location arrives.
            self.timeoutTask = Task { @MainActor in
                try? await Task.sleep(nanoseconds: 8_000_000_000)
                guard !Task.isCancelled else { return }
                if let c = self.continuation {
                    self.continuation = nil
                    c.resume(throwing: LocationError.timeout)
                }
            }
        }
    }

    /// Resolves the pending continuation (if any) and cancels the timeout task.
    private func resolve(with result: Result<CLLocation, Error>) {
        timeoutTask?.cancel()
        timeoutTask = nil
        guard let c = continuation else { return }
        continuation = nil
        switch result {
        case .success(let loc): c.resume(returning: loc)
        case .failure(let err): c.resume(throwing: err)
        }
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task { @MainActor in self.authStatus = manager.authorizationStatus }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        Task { @MainActor in
            guard let loc = locations.last else { return }
            self.resolve(with: .success(loc))
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor in
            self.resolve(with: .failure(error))
        }
    }
}
