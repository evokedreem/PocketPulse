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
        now: @escaping @Sendable () -> Date = { Date() }
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
        operationGeneration &+= 1
        let generation = operationGeneration

        guard provider.isHealthDataAvailable else {
            isRefreshing = false
            stableState = .unavailable
            state = .unavailable
            return
        }

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

    func resumeAfterPriorAccessRequest() {
        operationGeneration &+= 1

        guard provider.isHealthDataAvailable else {
            isRefreshing = false
            stableState = .unavailable
            state = .unavailable
            return
        }

        isRefreshing = false
        stableState = .ready
        state = .ready
    }

    func refresh(metrics: [HealthMetric] = HealthMetric.allCases) async {
        operationGeneration &+= 1
        let generation = operationGeneration

        guard provider.isHealthDataAvailable else {
            isRefreshing = false
            stableState = .unavailable
            state = .unavailable
            return
        }

        let fallbackState = stableState
        isRefreshing = true
        errorMessage = nil
        if summary.values.isEmpty {
            state = .loading
        }
        defer {
            if generation == operationGeneration {
                isRefreshing = false
            }
        }

        do {
            let fetched = try await provider.fetchSummary(for: metrics, now: now())
            try Task.checkCancellation()
            guard generation == operationGeneration else { return }
            let requested = Set(metrics)
            var mergedValues = summary.values.filter { !requested.contains($0.key) }
            mergedValues.merge(fetched.values) { _, refreshed in refreshed }
            summary = HealthSummary(generatedAt: fetched.generatedAt, values: mergedValues)
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
        } catch is CancellationError {
            throw CancellationError()
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
