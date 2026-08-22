import SwiftUI
import UIKit

struct ContentView: View {
    @AppStorage("pulseCount") private var storedCount = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var pulseScale = 1.0

    private var counter: PulseCounter {
        PulseCounter(count: storedCount)
    }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.08, green: 0.06, blue: 0.18),
                    Color(red: 0.22, green: 0.08, blue: 0.32)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 28) {
                VStack(spacing: 8) {
                    Text("POCKETPULSE")
                        .font(.caption.weight(.bold))
                        .tracking(3)
                        .foregroundStyle(.white.opacity(0.7))

                    Text("Tap Check")
                        .font(.largeTitle.bold())
                        .foregroundStyle(.white)
                }

                ZStack {
                    Circle()
                        .fill(.white.opacity(0.08))
                    Circle()
                        .stroke(
                            LinearGradient(
                                colors: [.pink, .purple, .cyan],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 8
                        )
                    VStack(spacing: 4) {
                        Text("\(storedCount)")
                            .font(.system(size: 72, weight: .bold, design: .rounded))
                            .contentTransition(.numericText())
                        Text(storedCount == 1 ? "pulse" : "pulses")
                            .font(.headline)
                            .foregroundStyle(.white.opacity(0.7))
                    }
                    .foregroundStyle(.white)
                }
                .frame(width: 230, height: 230)
                .scaleEffect(pulseScale)
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Pulse count")
                .accessibilityValue("\(storedCount)")

                Text(counter.message)
                    .font(.headline)
                    .foregroundStyle(.white.opacity(0.85))
                    .animation(.easeInOut, value: counter.message)

                Button(action: recordPulse) {
                    Label("Log a pulse", systemImage: "heart.fill")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 17)
                }
                .buttonStyle(.plain)
                .foregroundStyle(Color(red: 0.13, green: 0.06, blue: 0.22))
                .background(.white, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                .accessibilityHint("Increases the pulse count by one")

                Button("Reset", role: .destructive, action: reset)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(storedCount == 0 ? .white.opacity(0.3) : .white.opacity(0.75))
                    .disabled(storedCount == 0)
                    .accessibilityHint("Returns the pulse count to zero")
            }
            .padding(28)
        }
        .preferredColorScheme(.dark)
    }

    private func recordPulse() {
        var updatedCounter = counter
        updatedCounter.recordPulse()
        storedCount = updatedCounter.count
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()

        guard !reduceMotion else { return }
        withAnimation(.spring(response: 0.22, dampingFraction: 0.55)) {
            pulseScale = 1.1
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.16) {
            withAnimation(.spring(response: 0.28, dampingFraction: 0.7)) {
                pulseScale = 1.0
            }
        }
    }

    private func reset() {
        var updatedCounter = counter
        updatedCounter.reset()
        storedCount = updatedCounter.count
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }
}

#Preview {
    ContentView()
}
