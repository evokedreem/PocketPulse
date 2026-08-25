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
    private var refreshGeneration = 0
    private var hasCompletedAccessFlow = false

    init(
        provider: any HealthDataProviding,
        now: @escaping () -> Date = Date.init
    ) {
        self.provider = provider
        self.now = now
        self.state = provider.isHealthDataAvailable ? .notRequested : .unavailable
        self.summary = .empty(at: now())
    }

    func resumeAfterPriorAccessRequest() {
        hasCompletedAccessFlow = true
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
            hasCompletedAccessFlow = true
        } catch is CancellationError {
            state = hasCompletedAccessFlow ? .ready : .notRequested
            return
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

        refreshGeneration &+= 1
        let generation = refreshGeneration
        let fallbackState: HealthConnectionState =
            hasCompletedAccessFlow || !summary.values.isEmpty ? .ready : .notRequested
        isRefreshing = true
        errorMessage = nil
        if summary.values.isEmpty {
            state = .loading
        }
        defer {
            if generation == refreshGeneration {
                isRefreshing = false
            }
        }

        do {
            let fetched = try await provider.fetchSummary(for: metrics, now: now())
            try Task.checkCancellation()
            guard generation == refreshGeneration else { return }

            if Set(metrics) == Set(HealthMetric.allCases) {
                summary = fetched
            } else {
                var merged = summary.values
                for metric in metrics {
                    merged.removeValue(forKey: metric)
                }
                merged.merge(fetched.values) { _, refreshed in refreshed }
                summary = HealthSummary(generatedAt: fetched.generatedAt, values: merged)
            }
            state = .ready
        } catch is CancellationError {
            guard generation == refreshGeneration else { return }
            state = fallbackState
        } catch {
            guard generation == refreshGeneration else { return }
            fail(with: error)
        }
    }

    func history(
        for metric: HealthMetric,
        range: HealthRange
    ) async throws -> MetricHistory {
        try await provider.fetchHistory(for: metric, range: range, now: now())
    }

    func save(_ entry: ManualHealthEntry) async throws {
        do {
            try await provider.save(entry)
            await refresh()
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            fail(with: error)
            throw error
        }
    }

    func dismissError() {
        errorMessage = nil
        if case .failed = state {
            state = hasCompletedAccessFlow || !summary.values.isEmpty ? .ready : .notRequested
        }
    }

    private func fail(with error: Error) {
        let message = error.localizedDescription
        errorMessage = message
        state = .failed(message)
    }
}
