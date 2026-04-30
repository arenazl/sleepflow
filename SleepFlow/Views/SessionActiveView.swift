import SwiftUI

struct SessionActiveView: View {
    @EnvironmentObject var controller: SessionController
    @State private var elapsed: TimeInterval = 0
    @State private var ticker: Timer?

    var body: some View {
        VStack(spacing: 28) {
            header
            heartHero
            metricsCard
            statusCard
            stopButton
            Spacer()
        }
        .padding(.horizontal, 22)
        .padding(.top, 24)
        .onAppear { startTicker() }
        .onDisappear { ticker?.invalidate() }
    }

    private var header: some View {
        VStack(spacing: 4) {
            Text("Sesión activa")
                .font(.system(size: 14))
                .foregroundStyle(Theme.textSecond)
                .kerning(0.6)
                .textCase(.uppercase)
            Text(formatElapsed(elapsed))
                .font(.system(size: 38, weight: .light))
                .foregroundStyle(Theme.textPrimary)
                .monospacedDigit()
        }
    }

    private var heartHero: some View {
        VStack(spacing: 12) {
            PulsingHeart(size: 56)
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(controller.heart.latestHR.map { "\(Int($0))" } ?? "—")
                    .font(.system(size: 78, weight: .ultraLight))
                    .foregroundStyle(Theme.textPrimary)
                    .monospacedDigit()
                Text("bpm")
                    .font(.system(size: 16))
                    .foregroundStyle(Theme.textSecond)
            }
            Text(controller.heart.lastUpdate.map { "Actualizado \(timeAgo($0))" }
                 ?? "Esperando lectura del Watch...")
                .font(.system(size: 12))
                .foregroundStyle(Theme.textTertiary)
        }
    }

    private var metricsCard: some View {
        GlassCard {
            VStack(spacing: 14) {
                metricRow(label: "Relajación",
                          value: controller.currentScore,
                          tint: Theme.success)
                metricRow(label: "Volumen",
                          value: Double(controller.audio.currentVolume),
                          tint: Theme.primary)
            }
        }
    }

    private func metricRow(label: String, value: Double, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(label)
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.textSecond)
                Spacer()
                Text("\(Int(value * 100))%")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Theme.textPrimary)
                    .monospacedDigit()
            }
            ProgressBar(value: value, tint: tint)
        }
    }

    private var statusCard: some View {
        GlassCard {
            HStack(spacing: 14) {
                Image(systemName: iconForStatus(controller.statusLabel))
                    .font(.system(size: 22))
                    .foregroundStyle(Theme.primarySoft)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Estado")
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.textSecond)
                    Text(controller.statusLabel)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(Theme.textPrimary)
                }
                Spacer()
                if let track = controller.audio.currentTrackTitle {
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("Suena")
                            .font(.system(size: 11))
                            .foregroundStyle(Theme.textSecond)
                        Text(track)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(Theme.textPrimary)
                            .lineLimit(1)
                    }
                    .frame(maxWidth: 140, alignment: .trailing)
                }
            }
        }
    }

    private var stopButton: some View {
        Button {
            controller.stop()
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "stop.fill")
                Text("Detener")
            }
        }
        .buttonStyle(PillButtonStyle(tint: Theme.danger))
    }

    private func startTicker() {
        ticker?.invalidate()
        let timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            Task { @MainActor in
                if let start = controller.startDate {
                    elapsed = Date().timeIntervalSince(start)
                }
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        ticker = timer
    }

    private func formatElapsed(_ t: TimeInterval) -> String {
        let h = Int(t) / 3600
        let m = (Int(t) % 3600) / 60
        let s = Int(t) % 60
        if h > 0 { return String(format: "%d:%02d:%02d", h, m, s) }
        return String(format: "%02d:%02d", m, s)
    }

    private func timeAgo(_ d: Date) -> String {
        let s = Int(Date().timeIntervalSince(d))
        if s < 60 { return "hace \(s)s" }
        return "hace \(s / 60) min"
    }

    private func iconForStatus(_ s: String) -> String {
        switch s {
        case "Despierto":      return "eye.fill"
        case "Relajándote":    return "wind"
        case "Casi durmiendo": return "moon.fill"
        case "Sueño ligero":   return "moon.zzz.fill"
        case "Dormido":        return "zzz"
        default:               return "circle.dotted"
        }
    }
}
