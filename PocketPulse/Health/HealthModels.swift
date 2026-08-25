import Foundation

struct HealthMetricValue: Identifiable, Equatable, Sendable {
    var id: HealthMetric { metric }
    let metric: HealthMetric
    let value: Double
    let date: Date
    let sourceName: String?
}

struct HealthSummary: Equatable, Sendable {
    let generatedAt: Date
    let values: [HealthMetric: HealthMetricValue]

    static func empty(at date: Date = .now) -> HealthSummary {
        HealthSummary(generatedAt: date, values: [:])
    }
}

enum HealthRange: Int, CaseIterable, Identifiable, Sendable {
    case week = 7
    case month = 30
    case quarter = 90

    var id: Int { rawValue }
    var title: String { "\(rawValue)D" }
}

struct MetricDataPoint: Identifiable, Equatable, Sendable {
    let date: Date
    let value: Double

    var id: Date { date }
}

struct MetricHistory: Equatable, Sendable {
    let metric: HealthMetric
    let range: HealthRange
    let points: [MetricDataPoint]
    let latest: HealthMetricValue?
}

struct ManualHealthEntry: Equatable, Sendable {
    let metric: HealthMetric
    let value: Double
    let date: Date
}

enum HealthConnectionState: Equatable, Sendable {
    case notRequested
    case requesting
    case loading
    case ready
    case unavailable
    case failed(String)
}
