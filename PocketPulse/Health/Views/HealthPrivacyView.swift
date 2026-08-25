import SwiftUI

struct HealthPrivacyView: View {
    @ObservedObject var model: HealthDashboardModel
    @Binding var healthAccessRequested: Bool
    @Environment(\.openURL) private var openURL

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 16) {
                    Image(systemName: "lock.shield.fill")
                        .font(.system(size: 36, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 68, height: 68)
                        .background(
                            LinearGradient(
                                colors: [HealthPalette.success, HealthPalette.accentSecondary],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            in: RoundedRectangle(cornerRadius: 22, style: .continuous)
                        )
                    Text("Your health stays yours.")
                        .font(.title2.bold())
                        .foregroundStyle(HealthPalette.ink)
                    Text("PocketPulse reads only the HealthKit categories you approve. Health values are not uploaded to a PocketPulse database or advertising service.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 10)
            }

            Section("Apple Health Access") {
                Button {
                    requestAccess()
                } label: {
                    Label("Review Health Access", systemImage: "heart.text.square")
                }

                Button {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        openURL(url)
                    }
                } label: {
                    Label("Open PocketPulse Settings", systemImage: "gearshape")
                }

                LabeledContent("Connection", value: connectionLabel)
                LabeledContent("Loaded categories", value: "\(loadedCategoryCount)")
            }

            Section("How Synchronization Works") {
                PrivacyExplanationRow(
                    icon: "arrow.triangle.2.circlepath",
                    tint: HealthPalette.accent,
                    title: "Shared HealthKit Store",
                    detail: "PocketPulse and Apple Health read the same authorized HealthKit records on this iPhone."
                )
                PrivacyExplanationRow(
                    icon: "icloud.fill",
                    tint: .blue,
                    title: "Apple Controls iCloud Sync",
                    detail: "If Health in iCloud is enabled, Apple handles encrypted Health synchronization. PocketPulse never receives your iCloud credentials."
                )
                PrivacyExplanationRow(
                    icon: "iphone.gen3",
                    tint: HealthPalette.success,
                    title: "Local Preferences",
                    detail: "Favorites and connection state stay in this app’s private storage on the iPhone."
                )
                PrivacyExplanationRow(
                    icon: "server.rack",
                    tint: .secondary,
                    title: "No PocketPulse Health Server",
                    detail: "The app does not create a second remote copy of your health values."
                )
            }

            Section("Export") {
                ShareLink(item: exportText) {
                    Label("Share Current Summary", systemImage: "square.and.arrow.up")
                }
                Text("Sharing occurs only when you tap the button and choose a destination in Apple’s share sheet.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Apple-Managed Features") {
                Text("Medical records, medications, emergency access, and Apple Health Sharing remain managed in Apple’s Health app. iOS does not provide third-party apps full control over those private system features.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(HealthPalette.background)
        .navigationTitle("Privacy")
    }

    private var connectionLabel: String {
        switch model.state {
        case .ready: "Access reviewed"
        case .unavailable: "Unavailable"
        case .requesting, .loading: "Refreshing"
        case .failed: "Needs attention"
        case .notRequested: "Not reviewed"
        }
    }

    private var loadedCategoryCount: Int {
        Set(model.summary.values.keys.map(\.category)).count
    }

    private var exportText: String {
        let lines = model.summary.values.values
            .sorted { $0.metric.title < $1.metric.title }
            .map { item in
                "\(item.metric.title): \(HealthValueFormatter.display(item.value, for: item.metric))"
            }
        let body = lines.isEmpty ? "No authorized health values are currently available." : lines.joined(separator: "\n")
        return "PocketPulse Health Summary\n\(Date.now.formatted(date: .long, time: .shortened))\n\n\(body)"
    }

    private func requestAccess() {
        Task {
            await model.requestAuthorization()
            if model.state == .ready {
                healthAccessRequested = true
            }
        }
    }
}

private struct PrivacyExplanationRow: View {
    let icon: String
    let tint: Color
    let title: String
    let detail: String

    var body: some View {
        HStack(alignment: .top, spacing: 13) {
            Image(systemName: icon)
                .font(.body.weight(.semibold))
                .foregroundStyle(tint)
                .frame(width: 35, height: 35)
                .background(tint.opacity(0.12), in: RoundedRectangle(cornerRadius: 11))
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(HealthPalette.ink)
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 3)
    }
}
