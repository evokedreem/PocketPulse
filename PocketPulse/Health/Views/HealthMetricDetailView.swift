import Charts
import SwiftUI

struct HealthMetricDetailView: View {
    let metric: HealthMetric
    @ObservedObject var model: HealthDashboardModel

    @State private var range: HealthRange = .week
    @State private var history: MetricHistory?
    @State private var isLoading = false
    @State private var historyError: String?
    @State private var historyRequestID = UUID()
    @State private var showingEntry = false

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 18) {
                valueCard
                rangePicker
                chartCard
                trendCard
                sourceCard
            }
            .padding(16)
            .padding(.bottom, 24)
        }
        .background(HealthPalette.background.ignoresSafeArea())
        .navigationTitle(metric.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if metric.isWritable {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingEntry = true
                    } label: {
                        Label("Add Data", systemImage: "plus")
                    }
                }
            }
        }
        .task(id: range) {
            await loadHistory(for: range)
        }
        .sheet(isPresented: $showingEntry) {
            ManualEntrySheet(metric: metric, model: model) {
                Task { await loadHistory(for: range) }
            }
        }
    }

    private var valueCard: some View {
        HStack(alignment: .top, spacing: 15) {
            MetricIcon(metric: metric, size: 54)
            VStack(alignment: .leading, spacing: 6) {
                Text(metric.category.title.uppercased())
                    .font(.caption2.bold())
                    .tracking(1)
                    .foregroundStyle(metric.tint)
                Text(currentValue.map { HealthValueFormatter.display($0.value, for: metric) } ?? "No Data")
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundStyle(HealthPalette.ink)
                    .minimumScaleFactor(0.65)
                    .lineLimit(1)
                if let date = currentValue?.date {
                    Text("Updated \(date.formatted(date: .abbreviated, time: .shortened))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    Text("Connect Apple Health or add data to begin.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .healthCard()
    }

    private var rangePicker: some View {
        Picker("Date range", selection: $range) {
            ForEach(HealthRange.allCases) { range in
                Text(range.title).tag(range)
            }
        }
        .pickerStyle(.segmented)
    }

    @ViewBuilder
    private var chartCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("History")
                    .font(.headline)
                Spacer()
                if isLoading {
                    ProgressView()
                        .controlSize(.small)
                }
            }

            if let historyError {
                ContentUnavailableView(
                    "Couldn’t Load History",
                    systemImage: "exclamationmark.arrow.triangle.2.circlepath",
                    description: Text(historyError)
                )
                .frame(minHeight: 220)
            } else if let points = history?.points, !points.isEmpty {
                Chart(points) { point in
                    AreaMark(
                        x: .value("Date", point.date, unit: .day),
                        y: .value(metric.title, point.value)
                    )
                    .foregroundStyle(
                        LinearGradient(
                            colors: [metric.tint.opacity(0.32), metric.tint.opacity(0.02)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .interpolationMethod(.catmullRom)

                    LineMark(
                        x: .value("Date", point.date, unit: .day),
                        y: .value(metric.title, point.value)
                    )
                    .foregroundStyle(metric.tint)
                    .lineStyle(StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
                    .interpolationMethod(.catmullRom)

                    if point.id == points.last?.id {
                        PointMark(
                            x: .value("Date", point.date, unit: .day),
                            y: .value(metric.title, point.value)
                        )
                        .foregroundStyle(metric.tint)
                        .symbolSize(52)
                    }
                }
                .chartXAxis {
                    AxisMarks(values: .automatic(desiredCount: range == .week ? 7 : 5)) { value in
                        AxisGridLine().foregroundStyle(.clear)
                        AxisTick().foregroundStyle(.secondary.opacity(0.35))
                        AxisValueLabel(format: range == .week ? .dateTime.weekday(.narrow) : .dateTime.month().day())
                            .font(.caption2)
                    }
                }
                .chartYAxis {
                    AxisMarks(position: .leading, values: .automatic(desiredCount: 4)) { value in
                        AxisGridLine().foregroundStyle(.secondary.opacity(0.12))
                        AxisValueLabel()
                            .font(.caption2)
                    }
                }
                .frame(height: 230)
                .accessibilityLabel("\(metric.title) chart for the last \(range.rawValue) days")
            } else {
                HealthEmptyState(metric: metric)
            }
        }
        .padding(18)
        .healthCard()
    }

    private var trendCard: some View {
        HStack(spacing: 14) {
            Image(systemName: trendSymbol)
                .font(.title2.bold())
                .foregroundStyle(trendColor)
                .frame(width: 46, height: 46)
                .background(trendColor.opacity(0.12), in: Circle())
            VStack(alignment: .leading, spacing: 3) {
                Text("Recent Direction")
                    .font(.headline)
                Text(trendDescription)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
        .padding(18)
        .healthCard()
    }

    private var sourceCard: some View {
        VStack(alignment: .leading, spacing: 13) {
            Label("Data Source", systemImage: "iphone.gen3")
                .font(.headline)
                .foregroundStyle(HealthPalette.ink)
            Text(currentValue?.sourceName ?? "Apple Health")
                .font(.subheadline.weight(.semibold))
            Text("PocketPulse requests this value from HealthKit when you open or refresh the app. Read access is controlled by you in iPhone Health settings.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .healthCard()
    }

    private var currentValue: HealthMetricValue? {
        model.summary.values[metric] ?? history?.latest
    }

    private var recentTrend: HealthTrendDirection {
        guard let points = history?.points, let latest = points.last?.value else { return .insufficient }
        let previous = points.dropLast()
        guard !previous.isEmpty else { return .insufficient }
        let baseline = previous.reduce(0) { $0 + $1.value } / Double(previous.count)
        return HealthTrendAnalyzer.direction(current: latest, baseline: baseline)
    }

    private var trendSymbol: String {
        switch recentTrend {
        case .up: "arrow.up.right"
        case .down: "arrow.down.right"
        case .stable: "arrow.right"
        case .insufficient: "minus"
        }
    }

    private var trendColor: Color {
        switch recentTrend {
        case .up: HealthPalette.success
        case .down: Color.orange
        case .stable: HealthPalette.accent
        case .insufficient: .secondary
        }
    }

    private var trendDescription: String {
        guard let points = history?.points, let latest = points.last?.value else {
            return "More data is needed before a direction can be calculated."
        }
        let previous = points.dropLast()
        guard !previous.isEmpty else {
            return "More data is needed before a direction can be calculated."
        }
        let baseline = previous.reduce(0) { $0 + $1.value } / Double(previous.count)
        let change = HealthTrendAnalyzer.percentageChange(current: latest, baseline: baseline)
        switch recentTrend {
        case .up: return "Up \(abs(change ?? 0).formatted(.number.precision(.fractionLength(1))))% versus this period’s earlier average."
        case .down: return "Down \(abs(change ?? 0).formatted(.number.precision(.fractionLength(1))))% versus this period’s earlier average."
        case .stable: return "Holding steady versus this period’s earlier average."
        case .insufficient: return "More data is needed before a direction can be calculated."
        }
    }

    private func loadHistory(for requestedRange: HealthRange) async {
        let requestID = UUID()
        historyRequestID = requestID
        isLoading = true
        history = nil
        historyError = nil
        defer {
            if historyRequestID == requestID {
                isLoading = false
            }
        }
        do {
            let loaded = try await model.history(for: metric, range: requestedRange)
            try Task.checkCancellation()
            guard historyRequestID == requestID, range == requestedRange else { return }
            history = loaded
        } catch is CancellationError {
            return
        } catch {
            guard historyRequestID == requestID, range == requestedRange else { return }
            historyError = error.localizedDescription
        }
    }
}

private struct ManualEntrySheet: View {
    @Environment(\.dismiss) private var dismiss
    let metric: HealthMetric
    @ObservedObject var model: HealthDashboardModel
    let onSaved: () -> Void

    @State private var valueText = ""
    @State private var date = Date.now
    @State private var isSaving = false
    @State private var validationMessage: String?
    @FocusState private var valueFocused: Bool

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack(spacing: 13) {
                        MetricIcon(metric: metric, size: 44)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(metric.title)
                                .font(.headline)
                            Text("Saved securely to Apple Health")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                Section("Value") {
                    HStack {
                        TextField("Enter value", text: $valueText)
                            .keyboardType(.decimalPad)
                            .focused($valueFocused)
                        Text(metric.manualUnitLabel)
                            .foregroundStyle(.secondary)
                    }
                    if let validationMessage {
                        Text(validationMessage)
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                }

                Section(metric == .mindfulMinutes ? "End Time" : "Date & Time") {
                    DatePicker("Recorded", selection: $date, in: ...Date.now)
                        .datePickerStyle(.compact)
                }

                Section {
                    Label("You can review or delete this entry later in Apple Health.", systemImage: "checkmark.shield.fill")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Add Health Data")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .fontWeight(.semibold)
                        .disabled(valueText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSaving)
                }
            }
            .overlay {
                if isSaving {
                    ZStack {
                        Color.black.opacity(0.08).ignoresSafeArea()
                        ProgressView("Saving to Apple Health…")
                            .padding(20)
                            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
                    }
                }
            }
            .onAppear { valueFocused = true }
        }
    }

    private func save() {
        validationMessage = nil
        do {
            let value = try ManualEntryValidator.value(valueText, for: metric)
            isSaving = true
            Task {
                defer { isSaving = false }
                do {
                    try await model.save(
                        ManualHealthEntry(metric: metric, value: value, date: date)
                    )
                    onSaved()
                    dismiss()
                } catch {
                    validationMessage = error.localizedDescription
                }
            }
        } catch {
            validationMessage = error.localizedDescription
        }
    }
}
