import SwiftUI

struct HealthSummaryView: View {
    @ObservedObject var model: HealthDashboardModel
    @Binding var healthAccessRequested: Bool
    @AppStorage("pinnedHealthMetricIDs") private var pinnedHealthMetricIDs = ""
    @State private var showingFavorites = false

    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 22) {
                overviewHero

                if model.state != .ready {
                    HealthConnectionCard(state: model.state, connect: connect)
                }

                VStack(spacing: 12) {
                    HealthSectionHeader(
                        title: "Favorites",
                        actionTitle: "Edit",
                        action: { showingFavorites = true }
                    )
                    LazyVGrid(columns: columns, spacing: 12) {
                        ForEach(pinnedMetrics) { metric in
                            NavigationLink {
                                HealthMetricDetailView(metric: metric, model: model)
                            } label: {
                                MetricGridCard(
                                    metric: metric,
                                    metricValue: model.summary.values[metric]
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                if model.state == .ready, model.summary.values.isEmpty {
                    HealthEmptyState(metric: nil)
                }

                if !recentValues.isEmpty {
                    VStack(spacing: 8) {
                        HealthSectionHeader(title: "Latest Updates")
                        VStack(spacing: 0) {
                            ForEach(recentValues) { item in
                                NavigationLink {
                                    HealthMetricDetailView(metric: item.metric, model: model)
                                } label: {
                                    HealthMetricRow(metric: item.metric, metricValue: item)
                                        .padding(.horizontal, 16)
                                        .padding(.vertical, 12)
                                }
                                .buttonStyle(.plain)
                                if item.id != recentValues.last?.id {
                                    Divider().padding(.leading, 72)
                                }
                            }
                        }
                        .healthCard()
                    }
                }

                privacyCallout
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 28)
        }
        .background(HealthPalette.background.ignoresSafeArea())
        .navigationTitle("PocketPulse")
        .navigationBarTitleDisplayMode(.large)
        .refreshable {
            await model.refresh()
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showingFavorites = true
                } label: {
                    Image(systemName: "slider.horizontal.3")
                }
                .accessibilityLabel("Edit favorites")
            }
        }
        .sheet(isPresented: $showingFavorites) {
            FavoritesEditorView(initial: pinnedMetrics) { metrics in
                pinnedHealthMetricIDs = metrics.map(\.id).joined(separator: ",")
            }
        }
    }

    private var pinnedMetrics: [HealthMetric] {
        PinnedMetricSelection.normalized(
            identifiers: pinnedHealthMetricIDs
                .split(separator: ",")
                .map(String.init)
        )
    }

    private var recentValues: [HealthMetricValue] {
        Array(model.summary.values.values.sorted { $0.date > $1.date }.prefix(6))
    }

    private var overviewHero: some View {
        let steps = model.summary.values[.steps]?.value
        return ZStack(alignment: .topTrailing) {
            Circle()
                .fill(.white.opacity(0.11))
                .frame(width: 180, height: 180)
                .offset(x: 70, y: -78)
            Circle()
                .fill(.white.opacity(0.07))
                .frame(width: 110, height: 110)
                .offset(x: 34, y: 92)

            VStack(alignment: .leading, spacing: 22) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 5) {
                        Text(Date.now.formatted(.dateTime.weekday(.wide).month(.wide).day()))
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.white.opacity(0.76))
                        Text("Your health,\none clear view.")
                            .font(.system(size: 31, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                    }
                    Spacer()
                    Image(systemName: "heart.fill")
                        .font(.title2)
                        .foregroundStyle(.white)
                        .frame(width: 48, height: 48)
                        .background(.white.opacity(0.16), in: Circle())
                }

                VStack(alignment: .leading, spacing: 9) {
                    HStack(alignment: .firstTextBaseline) {
                        Text("TODAY’S STEPS")
                            .font(.caption2.bold())
                            .tracking(1.1)
                            .foregroundStyle(.white.opacity(0.7))
                        Spacer()
                        Text(steps.map { HealthValueFormatter.display($0, for: .steps) } ?? "No Data")
                            .font(.subheadline.bold())
                            .foregroundStyle(.white)
                    }
                    GeometryReader { proxy in
                        ZStack(alignment: .leading) {
                            Capsule().fill(.white.opacity(0.16))
                            Capsule()
                                .fill(.white)
                                .frame(width: proxy.size.width * min(max((steps ?? 0) / 10_000, 0), 1))
                        }
                    }
                    .frame(height: 8)
                    Text("A private dashboard powered by the data you allow from Apple Health.")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.73))
                }
            }
            .padding(22)
        }
        .frame(maxWidth: .infinity, minHeight: 255, alignment: .leading)
        .background(
            LinearGradient(
                colors: [HealthPalette.accent, Color(red: 0.19, green: 0.48, blue: 0.91), HealthPalette.accentSecondary],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            in: RoundedRectangle(cornerRadius: 28, style: .continuous)
        )
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .shadow(color: HealthPalette.accent.opacity(0.22), radius: 18, y: 10)
        .accessibilityElement(children: .combine)
    }

    private var privacyCallout: some View {
        HStack(alignment: .top, spacing: 13) {
            Image(systemName: "lock.shield.fill")
                .font(.title2)
                .foregroundStyle(HealthPalette.success)
            VStack(alignment: .leading, spacing: 4) {
                Text("Private by design")
                    .font(.headline)
                Text("Health values are requested directly from HealthKit and are not copied to a PocketPulse server.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
        .padding(18)
        .healthCard()
    }

    private func connect() {
        Task {
            await model.requestAuthorization()
            if model.state == .ready {
                healthAccessRequested = true
            }
        }
    }
}

private struct FavoritesEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var selection: Set<HealthMetric>
    let onSave: ([HealthMetric]) -> Void

    init(initial: [HealthMetric], onSave: @escaping ([HealthMetric]) -> Void) {
        _selection = State(initialValue: Set(initial))
        self.onSave = onSave
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Text("Choose the metrics shown at the top of your Summary. These preferences stay on this iPhone.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                ForEach(HealthCategory.allCases) { category in
                    FavoriteCategorySection(
                        category: category,
                        selection: $selection
                    )
                }
            }
            .navigationTitle("Edit Favorites")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        let ordered = HealthMetric.allCases.filter(selection.contains)
                        onSave(ordered.isEmpty ? HealthMetric.defaultPinned : ordered)
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }
}

private struct FavoriteCategorySection: View {
    let category: HealthCategory
    @Binding var selection: Set<HealthMetric>

    var body: some View {
        Section(category.title) {
            ForEach(metrics) { metric in
                FavoriteMetricToggleRow(
                    metric: metric,
                    isSelected: selection.contains(metric),
                    toggle: { toggle(metric) }
                )
            }
        }
    }

    private var metrics: [HealthMetric] {
        HealthMetric.allCases.filter { $0.category == category }
    }

    private func toggle(_ metric: HealthMetric) {
        if selection.contains(metric) {
            selection.remove(metric)
        } else {
            selection.insert(metric)
        }
    }
}

private struct FavoriteMetricToggleRow: View {
    let metric: HealthMetric
    let isSelected: Bool
    let toggle: () -> Void

    var body: some View {
        Button(action: toggle) {
            HStack(spacing: 12) {
                MetricIcon(metric: metric, size: 36)
                Text(metric.title)
                    .foregroundStyle(HealthPalette.ink)
                Spacer()
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isSelected ? metric.tint : Color.secondary)
            }
        }
    }
}
