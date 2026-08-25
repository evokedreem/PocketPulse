import Combine
import Foundation

@MainActor
final class HealthDashboardModel: ObservableObject {
    @Published private(set) var state: HealthConnectionState
    @Published private(set) var summary: HealthSummary
    @Published private(set) var isRefreshing = false
    @Published private(set) var errorMessage: String?

    private let provider: any HealthDataProviding
    private let now: @Sendable () -> Date
    private var stableState: HealthConnectionState
    private var operationGeneration = 0

    init(
        provider: any HealthDataProviding,
        now: @escaping @Sendable () -> Date = Date.init
    ) {
        self.provider = provider
        self.now = now
        let initialState: HealthConnectionState = provider.isHealthDataAvailable
            ? .notRequested
            : .unavailable
        state = initialState
        stableState = initialState
        summary = .empty()
    }

    func requestAuthorization() async {
        guard provider.isHealthDataAvailable else {
            stableState = .unavailable
            state = .unavailable
            return
        }

        operationGeneration &+= 1
        let generation = operationGeneration
        isRefreshing = false
        state = .requesting
        errorMessage = nil

        do {
            try await provider.requestAuthorization()
            try Task.checkCancellation()
            guard generation == operationGeneration else { return }
            stableState = .ready
        } catch is CancellationError {
            guard generation == operationGeneration else { return }
            state = stableState
            return
        } catch {
            guard generation == operationGeneration else { return }
            fail(with: error)
            return
        }

        await refresh()
    }

    func resumeAfterAccessReview() async {
        guard provider.isHealthDataAvailable else {
            stableState = .unavailable
            state = .unavailable
            return
        }
        operationGeneration &+= 1
        isRefreshing = false
        stableState = .ready
        state = .ready
        await refresh()
    }

    func refresh(metrics: [HealthMetric] = HealthMetric.allCases) async {
        guard provider.isHealthDataAvailable else {
            stableState = .unavailable
            state = .unavailable
            return
        }

        operationGeneration &+= 1
        let generation = operationGeneration
        let fallbackState = stableState
        isRefreshing = true
        errorMessage = nil
        if summary.values.isEmpty {
            state = .loading
        }
        defer {
            guard generation == operationGeneration else { return }
            isRefreshing = false
        }

        do {
            let fetched = try await provider.fetchSummary(for: metrics, now: now())
            try Task.checkCancellation()
            guard generation == operationGeneration else { return }
            let requested = Set(metrics)
            summary.values = summary.values.filter { !requested.contains($0.key) }
            summary.values.merge(fetched.values) { _, refreshed in refreshed }
            summary.generatedAt = fetched.generatedAt
            stableState = .ready
            state = .ready
        } catch is CancellationError {
            guard generation == operationGeneration else { return }
            state = fallbackState
        } catch {
            guard generation == operationGeneration else { return }
            fail(with: error)
        }
    }

    func history(for metric: HealthMetric, range: HealthRange) async throws -> MetricHistory {
        try Task.checkCancellation()
        let result = try await provider.fetchHistory(for: metric, range: range, now: now())
        try Task.checkCancellation()
        return result
    }

    func save(_ entry: ManualHealthEntry) async throws {
        do {
            try await provider.save(entry)
            await refresh(metrics: [entry.metric])
        } catch {
            fail(with: error)
            throw error
        }
    }

    func dismissError() {
        errorMessage = nil
        state = stableState
    }

    private func fail(with error: Error) {
        let message: String
        if let localized = error as? LocalizedError, let description = localized.errorDescription {
            message = description
        } else {
            message = error.localizedDescription
        }
        errorMessage = message
        state = .failed(message)
    }
}
