import XCTest
@testable import PocketPulse

@MainActor
final class HealthDashboardModelTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_700_000_000)

    func testUnavailableProviderStartsUnavailable() {
        let provider = FakeHealthDataProvider(isHealthDataAvailable: false)
        let model = HealthDashboardModel(provider: provider, now: { self.now })

        XCTAssertEqual(model.state, .unavailable)
        XCTAssertTrue(model.summary.values.isEmpty)
    }

    func testAvailableProviderStartsNotRequested() {
        let provider = FakeHealthDataProvider()
        let model = HealthDashboardModel(provider: provider, now: { self.now })

        XCTAssertEqual(model.state, .notRequested)
        XCTAssertFalse(model.isRefreshing)
        XCTAssertNil(model.errorMessage)
    }

    func testRequestAuthorizationLoadsSummary() async {
        let expected = summary(steps: 8_432)
        let provider = FakeHealthDataProvider(summaryResult: .success(expected))
        let model = HealthDashboardModel(provider: provider, now: { self.now })

        await model.requestAuthorization()

        XCTAssertEqual(provider.authorizationRequestCount, 1)
        XCTAssertEqual(provider.summaryRequestCount, 1)
        XCTAssertEqual(model.state, .ready)
        XCTAssertEqual(model.summary, expected)
        XCTAssertNil(model.errorMessage)
    }

    func testAuthorizationFailureDoesNotFetchSummary() async {
        let provider = FakeHealthDataProvider(authorizationError: TestHealthError.authorization)
        let model = HealthDashboardModel(provider: provider, now: { self.now })

        await model.requestAuthorization()

        XCTAssertEqual(provider.authorizationRequestCount, 1)
        XCTAssertEqual(provider.summaryRequestCount, 0)
        guard case .failed = model.state else {
            return XCTFail("Expected failed state, got \(model.state)")
        }
        XCTAssertNotNil(model.errorMessage)
    }

    func testRefreshFailurePreservesPreviouslyLoadedSummary() async {
        let initial = summary(steps: 4_000)
        let provider = FakeHealthDataProvider(summaryResult: .success(initial))
        let model = HealthDashboardModel(provider: provider, now: { self.now })
        await model.refresh()

        provider.summaryResult = .failure(TestHealthError.query)
        await model.refresh()

        XCTAssertEqual(model.summary, initial)
        XCTAssertFalse(model.isRefreshing)
        XCTAssertNotNil(model.errorMessage)
        guard case .failed = model.state else {
            return XCTFail("Expected failed state, got \(model.state)")
        }
    }

    func testSaveWritesEntryThenRefreshesSummary() async throws {
        let initial = summary(steps: 1_000)
        let updated = summary(steps: 1_500)
        let provider = FakeHealthDataProvider(summaryResult: .success(initial))
        let model = HealthDashboardModel(provider: provider, now: { self.now })
        await model.refresh()
        provider.summaryResult = .success(updated)

        let entry = ManualHealthEntry(metric: .water, value: 12, date: now)
        try await model.save(entry)

        XCTAssertEqual(provider.savedEntries, [entry])
        XCTAssertEqual(provider.summaryRequestCount, 2)
        XCTAssertEqual(model.summary, updated)
        XCTAssertEqual(model.state, .ready)
    }

    func testHistoryDelegatesToProviderWithSelectedRange() async throws {
        let expected = MetricHistory(metric: .heartRate, range: .month, points: [], latest: nil)
        let provider = FakeHealthDataProvider(historyResult: .success(expected))
        let model = HealthDashboardModel(provider: provider, now: { self.now })

        let actual = try await model.history(for: .heartRate, range: .month)

        XCTAssertEqual(actual, expected)
        XCTAssertEqual(provider.historyRequests, [.init(metric: .heartRate, range: .month)])
    }

    func testSubsetRefreshPreservesPreviouslyLoadedMetrics() async {
        let steps = HealthMetricValue(
            metric: .steps,
            value: 4_000,
            date: now,
            sourceName: "Test iPhone"
        )
        let heartRate = HealthMetricValue(
            metric: .heartRate,
            value: 72,
            date: now,
            sourceName: "Test iPhone"
        )
        let provider = FakeHealthDataProvider(
            summaryResult: .success(HealthSummary(generatedAt: now, values: [.steps: steps, .heartRate: heartRate]))
        )
        let model = HealthDashboardModel(provider: provider, now: { self.now })
        await model.refresh()

        let updatedSteps = HealthMetricValue(
            metric: .steps,
            value: 5_000,
            date: now,
            sourceName: "Test iPhone"
        )
        provider.summaryResult = .success(HealthSummary(generatedAt: now, values: [.steps: updatedSteps]))
        await model.refresh(metrics: [.steps])

        XCTAssertEqual(model.summary.values[.steps], updatedSteps)
        XCTAssertEqual(model.summary.values[.heartRate], heartRate)
    }

    func testCancelledHistoryDoesNotCreateGlobalFailureState() async {
        let provider = FakeHealthDataProvider(historyResult: .failure(CancellationError()))
        let model = HealthDashboardModel(provider: provider, now: { self.now })

        do {
            _ = try await model.history(for: .steps, range: .week)
            XCTFail("Expected cancellation")
        } catch is CancellationError {
            // Expected.
        } catch {
            XCTFail("Expected CancellationError, got \(error)")
        }

        XCTAssertEqual(model.state, .notRequested)
        XCTAssertNil(model.errorMessage)
    }

    func testCancelledNonCooperativeRefreshDoesNotPublishOrRemainLoading() async {
        let provider = NonCooperativeSummaryProvider()
        let model = HealthDashboardModel(provider: provider, now: { self.now })
        let lateSummary = summary(steps: 9_999)

        let refreshTask = Task { await model.refresh() }
        await provider.waitUntilStarted()
        refreshTask.cancel()
        await provider.resolve(with: lateSummary)
        await refreshTask.value

        XCTAssertEqual(model.state, .notRequested)
        XCTAssertTrue(model.summary.values.isEmpty)
        XCTAssertFalse(model.isRefreshing)
        XCTAssertNil(model.errorMessage)
    }

    func testCancelledRefreshPreservesPreviouslyReadyEmptyState() async {
        let provider = NonCooperativeSummaryProvider(
            immediateSummaries: [.empty(at: now)]
        )
        let model = HealthDashboardModel(provider: provider, now: { self.now })
        await model.refresh()
        XCTAssertEqual(model.state, .ready)

        let refreshTask = Task { await model.refresh() }
        await provider.waitUntilStarted()
        refreshTask.cancel()
        await provider.resolve(with: .empty(at: now))
        await refreshTask.value

        XCTAssertEqual(model.state, .ready)
        XCTAssertFalse(model.isRefreshing)
    }

    func testStaleAuthorizationCancellationDoesNotOverwriteNewerRefresh() async {
        let expected = summary(steps: 7_777)
        let provider = NonCooperativeAuthorizationProvider(summary: expected)
        let model = HealthDashboardModel(provider: provider, now: { self.now })

        let authorizationTask = Task { await model.requestAuthorization() }
        await provider.waitUntilAuthorizationStarted()
        await model.refresh()
        XCTAssertEqual(model.state, .ready)
        XCTAssertEqual(model.summary, expected)

        authorizationTask.cancel()
        await provider.cancelAuthorization()
        await authorizationTask.value

        XCTAssertEqual(model.state, .ready)
        XCTAssertEqual(model.summary, expected)
    }

    func testUnavailableRefreshInvalidatesInFlightRefresh() async {
        let provider = AvailabilityChangingSummaryProvider()
        let model = HealthDashboardModel(provider: provider, now: { self.now })
        let lateSummary = summary(steps: 8_888)

        let firstRefresh = Task { await model.refresh() }
        await provider.waitUntilStarted()
        provider.setAvailable(false)
        await model.refresh()
        await provider.resolve(with: lateSummary)
        await firstRefresh.value

        XCTAssertEqual(model.state, .unavailable)
        XCTAssertTrue(model.summary.values.isEmpty)
        XCTAssertFalse(model.isRefreshing)
    }

    func testCancelledSaveDoesNotCreateGlobalFailureState() async {
        let provider = FakeHealthDataProvider(saveResult: .failure(CancellationError()))
        let model = HealthDashboardModel(provider: provider, now: { self.now })
        model.resumeAfterPriorAccessRequest()

        do {
            try await model.save(ManualHealthEntry(metric: .weight, value: 180, date: now))
            XCTFail("Expected cancellation")
        } catch is CancellationError {
            // Expected.
        } catch {
            XCTFail("Expected CancellationError, got \(error)")
        }

        XCTAssertEqual(model.state, .ready)
        XCTAssertNil(model.errorMessage)
        XCTAssertEqual(provider.saveCallCount, 1)
    }

    func testHistoryFailureRemainsRequestLocal() async {
        let provider = FakeHealthDataProvider(historyResult: .failure(TestHealthError.query))
        let model = HealthDashboardModel(provider: provider, now: { self.now })

        do {
            _ = try await model.history(for: .steps, range: .week)
            XCTFail("Expected query failure")
        } catch {
            // The detail screen owns request-specific error presentation.
        }

        XCTAssertEqual(model.state, .notRequested)
        XCTAssertNil(model.errorMessage)
    }

    private func summary(steps: Double) -> HealthSummary {
        let value = HealthMetricValue(
            metric: .steps,
            value: steps,
            date: now,
            sourceName: "Test iPhone"
        )
        return HealthSummary(generatedAt: now, values: [.steps: value])
    }
}

private enum TestHealthError: Error {
    case authorization
    case query
}

private final class AvailabilityChangingSummaryProvider: HealthDataProviding, @unchecked Sendable {
    private let lock = NSLock()
    private var available = true
    private var started = false
    private var continuation: CheckedContinuation<HealthSummary, Never>?

    var isHealthDataAvailable: Bool {
        locked { available }
    }

    func setAvailable(_ value: Bool) {
        locked { available = value }
    }

    func requestAuthorization() async throws {}

    func fetchSummary(for metrics: [HealthMetric], now: Date) async throws -> HealthSummary {
        await withCheckedContinuation { continuation in
            locked {
                self.continuation = continuation
                started = true
            }
        }
    }

    func waitUntilStarted() async {
        while !locked({ started }) {
            await Task.yield()
        }
    }

    func resolve(with summary: HealthSummary) async {
        let pending = locked {
            let pending = continuation
            continuation = nil
            return pending
        }
        pending?.resume(returning: summary)
    }

    func fetchHistory(
        for metric: HealthMetric,
        range: HealthRange,
        now: Date
    ) async throws -> MetricHistory {
        MetricHistory(metric: metric, range: range, points: [], latest: nil)
    }

    func save(_ entry: ManualHealthEntry) async throws {}

    private func locked<T>(_ body: () -> T) -> T {
        lock.lock()
        defer { lock.unlock() }
        return body()
    }
}

private actor NonCooperativeAuthorizationProvider: HealthDataProviding {
    nonisolated let isHealthDataAvailable = true

    private let summary: HealthSummary
    private var authorizationContinuation: CheckedContinuation<Void, Error>?
    private var authorizationStarted = false

    init(summary: HealthSummary) {
        self.summary = summary
    }

    func requestAuthorization() async throws {
        try await withCheckedThrowingContinuation { continuation in
            authorizationContinuation = continuation
            authorizationStarted = true
        }
    }

    func waitUntilAuthorizationStarted() async {
        while !authorizationStarted {
            await Task.yield()
        }
    }

    func cancelAuthorization() {
        authorizationContinuation?.resume(throwing: CancellationError())
        authorizationContinuation = nil
    }

    func fetchSummary(for metrics: [HealthMetric], now: Date) async throws -> HealthSummary {
        summary
    }

    func fetchHistory(
        for metric: HealthMetric,
        range: HealthRange,
        now: Date
    ) async throws -> MetricHistory {
        MetricHistory(metric: metric, range: range, points: [], latest: nil)
    }

    func save(_ entry: ManualHealthEntry) async throws {}
}

private actor NonCooperativeSummaryProvider: HealthDataProviding {
    nonisolated let isHealthDataAvailable = true

    private var continuation: CheckedContinuation<HealthSummary, Never>?
    private var immediateSummaries: [HealthSummary]
    private var started = false

    init(immediateSummaries: [HealthSummary] = []) {
        self.immediateSummaries = immediateSummaries
    }

    func requestAuthorization() async throws {}

    func fetchSummary(for metrics: [HealthMetric], now: Date) async throws -> HealthSummary {
        if !immediateSummaries.isEmpty {
            return immediateSummaries.removeFirst()
        }
        return await withCheckedContinuation { continuation in
            self.continuation = continuation
            started = true
        }
    }

    func waitUntilStarted() async {
        while !started {
            await Task.yield()
        }
    }

    func resolve(with summary: HealthSummary) {
        continuation?.resume(returning: summary)
        continuation = nil
    }

    func fetchHistory(
        for metric: HealthMetric,
        range: HealthRange,
        now: Date
    ) async throws -> MetricHistory {
        MetricHistory(metric: metric, range: range, points: [], latest: nil)
    }

    func save(_ entry: ManualHealthEntry) async throws {}
}

private final class FakeHealthDataProvider: HealthDataProviding, @unchecked Sendable {
    struct HistoryRequest: Equatable {
        let metric: HealthMetric
        let range: HealthRange
    }

    let isHealthDataAvailable: Bool
    var authorizationError: Error?
    var summaryResult: Result<HealthSummary, Error>
    var historyResult: Result<MetricHistory, Error>
    private(set) var authorizationRequestCount = 0
    private(set) var summaryRequestCount = 0
    private(set) var savedEntries: [ManualHealthEntry] = []
    private(set) var historyRequests: [HistoryRequest] = []

    init(
        isHealthDataAvailable: Bool = true,
        authorizationError: Error? = nil,
        summaryResult: Result<HealthSummary, Error> = .success(.empty()),
        historyResult: Result<MetricHistory, Error> = .success(
            MetricHistory(metric: .steps, range: .week, points: [], latest: nil)
        )
    ) {
        self.isHealthDataAvailable = isHealthDataAvailable
        self.authorizationError = authorizationError
        self.summaryResult = summaryResult
        self.historyResult = historyResult
    }

    func requestAuthorization() async throws {
        authorizationRequestCount += 1
        if let authorizationError { throw authorizationError }
    }

    func fetchSummary(for metrics: [HealthMetric], now: Date) async throws -> HealthSummary {
        summaryRequestCount += 1
        return try summaryResult.get()
    }

    func fetchHistory(
        for metric: HealthMetric,
        range: HealthRange,
        now: Date
    ) async throws -> MetricHistory {
        historyRequests.append(.init(metric: metric, range: range))
        return try historyResult.get()
    }

    func save(_ entry: ManualHealthEntry) async throws {
        savedEntries.append(entry)
    }
}
