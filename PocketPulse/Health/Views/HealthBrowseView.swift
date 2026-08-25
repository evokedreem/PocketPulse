import SwiftUI

struct HealthBrowseView: View {
    @ObservedObject var model: HealthDashboardModel
    @State private var searchText = ""

    var body: some View {
        List {
            Section {
                HStack(spacing: 13) {
                    Image(systemName: "square.grid.2x2.fill")
                        .font(.title2)
                        .foregroundStyle(HealthPalette.accent)
                        .frame(width: 44, height: 44)
                        .background(HealthPalette.accent.opacity(0.12), in: RoundedRectangle(cornerRadius: 14))
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Your Health Library")
                            .font(.headline)
                        Text("Browse the categories PocketPulse can request from Apple Health.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 6)
            }

            ForEach(visibleCategories) { category in
                Section {
                    ForEach(visibleMetrics(in: category)) { metric in
                        NavigationLink {
                            HealthMetricDetailView(metric: metric, model: model)
                        } label: {
                            HealthMetricRow(
                                metric: metric,
                                metricValue: model.summary.values[metric]
                            )
                            .padding(.vertical, 4)
                        }
                    }
                } header: {
                    Label(category.title, systemImage: category.systemImage)
                        .foregroundStyle(category.tint)
                }
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(HealthPalette.background)
        .navigationTitle("Browse")
        .searchable(text: $searchText, prompt: "Search health metrics")
        .overlay {
            if visibleCategories.isEmpty {
                ContentUnavailableView.search(text: searchText)
            }
        }
        .refreshable {
            await model.refresh()
        }
    }

    private var visibleCategories: [HealthCategory] {
        HealthCategory.allCases.filter { !visibleMetrics(in: $0).isEmpty }
    }

    private func visibleMetrics(in category: HealthCategory) -> [HealthMetric] {
        HealthMetric.allCases.filter { metric in
            guard metric.category == category else { return false }
            guard !searchText.isEmpty else { return true }
            return metric.title.localizedCaseInsensitiveContains(searchText)
                || category.title.localizedCaseInsensitiveContains(searchText)
        }
    }
}
