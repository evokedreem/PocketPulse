import SwiftUI

struct HealthSectionHeader: View {
    let title: String
    var actionTitle: String?
    var action: (() -> Void)?

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .font(.title3.bold())
                .foregroundStyle(HealthPalette.ink)
            Spacer()
            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .font(.subheadline.weight(.semibold))
            }
        }
        .accessibilityAddTraits(.isHeader)
    }
}

struct MetricIcon: View {
    let metric: HealthMetric
    var size: CGFloat = 42

    var body: some View {
        Image(systemName: metric.systemImage)
            .font(.system(size: size * 0.42, weight: .semibold))
            .foregroundStyle(metric.tint)
            .frame(width: size, height: size)
            .background(metric.tint.opacity(0.13), in: RoundedRectangle(cornerRadius: size * 0.31, style: .continuous))
            .accessibilityHidden(true)
    }
}

struct MetricGridCard: View {
    let metric: HealthMetric
    let metricValue: HealthMetricValue?

    var body: some View {
        VStack(alignment: .leading, spacing: 13) {
            HStack(alignment: .top) {
                MetricIcon(metric: metric, size: 38)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption.bold())
                    .foregroundStyle(.tertiary)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(metric.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                Text(metricValue.map { HealthValueFormatter.display($0.value, for: metric) } ?? "No Data")
                    .font(.system(.title3, design: .rounded, weight: .bold))
                    .foregroundStyle(HealthPalette.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 118, alignment: .leading)
        .padding(16)
        .healthCard()
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(metric.title), \(metricValue.map { HealthValueFormatter.display($0.value, for: metric) } ?? "no data")")
    }
}

struct HealthMetricRow: View {
    let metric: HealthMetric
    let metricValue: HealthMetricValue?

    var body: some View {
        HStack(spacing: 14) {
            MetricIcon(metric: metric)
            VStack(alignment: .leading, spacing: 3) {
                Text(metric.title)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(HealthPalette.ink)
                Text(metric.category.title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 8)
            VStack(alignment: .trailing, spacing: 3) {
                Text(metricValue.map { HealthValueFormatter.display($0.value, for: metric) } ?? "—")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(metricValue == nil ? .secondary : HealthPalette.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                if let date = metricValue?.date {
                    Text(date, style: .relative)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
            Image(systemName: "chevron.right")
                .font(.caption.bold())
                .foregroundStyle(.tertiary)
        }
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }
}

struct HealthEmptyState: View {
    let metric: HealthMetric?

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: metric?.systemImage ?? "waveform.path.ecg.rectangle")
                .font(.system(size: 34, weight: .medium))
                .foregroundStyle((metric?.tint ?? HealthPalette.accent).gradient)
            Text("No Health Data Yet")
                .font(.headline)
            Text("Once this data is available and you allow access, it will appear here automatically.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(28)
        .healthCard()
    }
}

struct HealthConnectionCard: View {
    let state: HealthConnectionState
    let connect: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            HStack(spacing: 12) {
                Image(systemName: "heart.text.square.fill")
                    .font(.system(size: 27))
                    .foregroundStyle(.white)
                    .frame(width: 48, height: 48)
                    .background(
                        LinearGradient(
                            colors: [HealthPalette.accent, HealthPalette.accentSecondary],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        in: RoundedRectangle(cornerRadius: 15, style: .continuous)
                    )
                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.headline)
                    Text(message)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            if state != .unavailable {
                Button(action: connect) {
                    HStack {
                        if state == .requesting || state == .loading {
                            ProgressView()
                                .tint(.white)
                        }
                        Text(buttonTitle)
                            .fontWeight(.semibold)
                        Spacer()
                        Image(systemName: "arrow.right")
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 16)
                    .frame(height: 48)
                    .background(HealthPalette.accent.gradient, in: RoundedRectangle(cornerRadius: 15, style: .continuous))
                }
                .disabled(state == .requesting || state == .loading)
            }
        }
        .padding(18)
        .healthCard()
    }

    private var title: String {
        switch state {
        case .unavailable: "Apple Health Unavailable"
        case .failed: "Health Access Needs Attention"
        case .requesting, .loading: "Connecting Securely"
        default: "Connect Apple Health"
        }
    }

    private var message: String {
        switch state {
        case .unavailable: "HealthKit is only available on a supported iPhone."
        case .failed(let message): message
        case .requesting, .loading: "Your authorized health data is being prepared on this iPhone."
        default: "Choose the categories you want PocketPulse to read or update. Your health data stays in Apple Health."
        }
    }

    private var buttonTitle: String {
        if case .failed = state { return "Try Again" }
        return "Choose Health Access"
    }
}
