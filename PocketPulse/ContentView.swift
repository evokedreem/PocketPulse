import SwiftUI

struct ContentView: View {
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage("healthAccessRequested") private var healthAccessRequested = false
    @StateObject private var model: HealthDashboardModel

    init(provider: any HealthDataProviding = HealthKitStore()) {
        _model = StateObject(wrappedValue: HealthDashboardModel(provider: provider))
    }

    var body: some View {
        ZStack {
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

            if scenePhase != .active {
                HealthAppSwitcherCover()
                    .transition(.opacity)
                    .zIndex(1)
            }
        }
        .tint(HealthPalette.accent)
        .task {
            if healthAccessRequested, model.state == .notRequested {
                model.resumeAfterPriorAccessRequest()
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

private struct HealthAppSwitcherCover: View {
    var body: some View {
        ZStack {
            HealthPalette.background.ignoresSafeArea()
            VStack(spacing: 14) {
                Image(systemName: "lock.shield.fill")
                    .font(.system(size: 46, weight: .semibold))
                    .foregroundStyle(HealthPalette.accent)
                Text("PocketPulse")
                    .font(.title2.bold())
                    .foregroundStyle(HealthPalette.ink)
                Text("Health details are hidden while the app is inactive.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(32)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("PocketPulse health details hidden")
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
