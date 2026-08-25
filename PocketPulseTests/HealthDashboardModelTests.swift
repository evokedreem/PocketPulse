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
