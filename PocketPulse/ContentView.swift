import SwiftUI

struct ContentView: View {
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage("healthAccessRequested") private var healthAccessRequested = false
    @StateObject private var model: HealthDashboardModel

    init(provider: any HealthDataProviding = HealthKitStore()) {
        _model = StateObject(wrappedValue: HealthDashboardModel(provider: provider))
    }

    var body: some View {
        TabView {
            NavigationStack {
                HealthSummaryView(
                    model: model,
                    healthAccessRequested: $healthAccessRequested
                )
            }
            .tabItem {
                Label("Summary", systemImage: "heart.text.square.fill")
            }

            NavigationStack {
                HealthBrowseView(model: model)
            }
            .tabItem {
                Label("Browse", systemImage: "square.grid.2x2.fill")
            }

            NavigationStack {
                HealthPrivacyView(
                    model: model,
                    healthAccessRequested: $healthAccessRequested
                )
            }
            .tabItem {
                Label("Privacy", systemImage: "lock.shield.fill")
            }
        }
        .tint(HealthPalette.accent)
        .task {
            if healthAccessRequested, model.state == .notRequested {
                await model.refresh()
            }
        }
        .onChange(of: scenePhase) { _, newPhase in
            guard newPhase == .active,
                  healthAccessRequested,
                  model.state != .requesting,
                  model.state != .loading else { return }
            Task { await model.refresh() }
        }
    }
}

#Preview {
    ContentView(provider: PreviewHealthDataProvider())
}

private struct PreviewHealthDataProvider: HealthDataProviding {
    let isHealthDataAvailable = true

    func requestAuthorization() async throws {}

    func fetchSummary(for metrics: [HealthMetric], now: Date) async throws -> HealthSummary {
        let seeded: [HealthMetric: Double] = [
            .steps: 8_432,
            .heartRate: 72,
            .sleep: 7.5,
            .activeEnergy: 486,
            .oxygenSaturation: 0.98,
            .bodyMass: 184.2
        ]
        return HealthSummary(
            generatedAt: now,
            values: Dictionary(uniqueKeysWithValues: seeded.compactMap { metric, value in
                guard metrics.contains(metric) else { return nil }
                return (
                    metric,
                    HealthMetricValue(
                        metric: metric,
                        value: value,
                        date: now,
                        sourceName: "Garrette’s iPhone"
                    )
                )
            })
        )
    }

    func fetchHistory(
        for metric: HealthMetric,
        range: HealthRange,
        now: Date
    ) async throws -> MetricHistory {
        let calendar = Calendar.current
        let points = (0..<range.rawValue).compactMap { offset -> MetricDataPoint? in
            guard let date = calendar.date(byAdding: .day, value: -offset, to: now) else { return nil }
            return MetricDataPoint(date: date, value: Double(6_500 + ((offset * 733) % 4_000)))
        }.reversed()
        return MetricHistory(metric: metric, range: range, points: Array(points), latest: nil)
    }

    func save(_ entry: ManualHealthEntry) async throws {}
}
