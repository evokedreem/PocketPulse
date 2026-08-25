import Foundation

protocol HealthDataProviding: Sendable {
    var isHealthDataAvailable: Bool { get }

    func requestAuthorization() async throws
    func fetchSummary(for metrics: [HealthMetric], now: Date) async throws -> HealthSummary
    func fetchHistory(
        for metric: HealthMetric,
        range: HealthRange,
        now: Date
    ) async throws -> MetricHistory
    func save(_ entry: ManualHealthEntry) async throws
}
