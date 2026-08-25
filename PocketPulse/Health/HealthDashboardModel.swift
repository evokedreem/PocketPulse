import Combine
import Foundation

@MainActor
final class HealthDashboardModel: ObservableObject {
    @Published private(set) var state: HealthConnectionState
    @Published private(set) var summary: HealthSummary
    @Published private(set) var isRefreshing = false
    @Published private(set) var errorMessage: String?

    private let provider: any HealthDataProviding
    private let now: () -> Date

    init(
        provider: any HealthDataProviding,
        now: @escaping () -> Date = Date.init
    ) {
        self.provider = provider
        self.now = now
        self.state = provider.isHealthDataAvailable ? .notRequested : .unavailable
        self.summary = .empty(at: now())
    }

    func requestAuthorization() async {
        guard provider.isHealthDataAvailable else {
            state = .unavailable
            return
        }

        state = .requesting
        errorMessage = nil
        do {
            try await provider.requestAuthorization()
        } catch {
            fail(with: error)
            return
        }

        await refresh()
    }

    func refresh(metrics: [HealthMetric] = HealthMetric.allCases) async {
        guard provider.isHealthDataAvailable else {
            state = .unavailable
            return
        }

        isRefreshing = true
        errorMessage = nil
        if summary.values.isEmpty {
            state = .loading
        }
        defer { isRefreshing = false }

        do {
            summary = try await provider.fetchSummary(for: metrics, now: now())
            state = .ready
        } catch {
            fail(with: error)
        }
    }

    func history(
        for metric: HealthMetric,
        range: HealthRange
    ) async throws -> MetricHistory {
        do {
            let history = try await provider.fetchHistory(for: metric, range: range, now: now())
            errorMessage = nil
            return history
        } catch {
            fail(with: error)
            throw error
        }
    }

    func save(_ entry: ManualHealthEntry) async throws {
        do {
            try await provider.save(entry)
            await refresh()
        } catch {
            fail(with: error)
            throw error
        }
    }

    func dismissError() {
        errorMessage = nil
        if case .failed = state {
            state = summary.values.isEmpty ? .notRequested : .ready
        }
    }

    private func fail(with error: Error) {
        let message = error.localizedDescription
        errorMessage = message
        state = .failed(message)
    }
}
