import SwiftUI
import Charts

struct SessionSummaryView: View {
    @EnvironmentObject var controller: SessionController
    let session: SleepSession?

    var body: some View {
        ScrollView {
            VStack(spacing: 22) {
                header
                if let session {
                    chartCard(session: session)
                    metricsCard(session: session)
                } else {
                    emptyCard
                }
                doneButton
            }
            .padding(.horizontal, 22)
            .padding(.top, 24)
            .padding(.bottom, 60)
        }
    }

    private var header: some View {
        VStack(spacing: 6) {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 36))
                .foregroundStyle(Theme.success)
            Text("Sesión completada")
                .font(.system(size: 24, weight: .bold))
                .foregroundStyle(Theme.textPrimary)
        }
        .padding(.top, 12)
    }

    private func chartCard(session: SleepSession) -> some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("Frecuencia cardíaca")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Theme.textPrimary)

                if session.hrSamples.isEmpty {
                    Text("Sin datos de HR registrados durante la sesión.")
                        .font(.system(size: 13))
                        .foregroundStyle(Theme.textSecond)
                        .frame(maxWidth: .infinity, minHeight: 140)
                } else {
                    Chart(session.hrSamples) { sample in
                        LineMark(
                            x: .value("Tiempo", sample.timestamp),
                            y: .value("BPM", sample.value)
                        )
                        .foregroundStyle(Theme.heart)
                        .interpolationMethod(.catmullRom)
                        AreaMark(
                            x: .value("Tiempo", sample.timestamp),
                            y: .value("BPM", sample.value)
                        )
                        .foregroundStyle(
                            LinearGradient(
                                colors: [Theme.heart.opacity(0.4), .clear],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                    }
                    .chartYAxis {
                        AxisMarks(position: .leading) {
                            AxisGridLine().foregroundStyle(Color.white.opacity(0.08))
                            AxisValueLabel().foregroundStyle(Theme.textTertiary)
                        }
                    }
                    .chartXAxis {
                        AxisMarks {
                            AxisGridLine().foregroundStyle(Color.white.opacity(0.08))
                            AxisValueLabel(format: .dateTime.hour().minute())
                                .foregroundStyle(Theme.textTertiary)
                        }
                    }
                    .frame(height: 180)
                }
            }
        }
    }

    private func metricsCard(session: SleepSession) -> some View {
        GlassCard {
            VStack(spacing: 12) {
                LabelChip(
                    icon: "moon.zzz.fill",
                    title: "Te dormiste en",
                    value: session.estimatedSleepOnsetMinutes.map { "~\($0) min" } ?? "—"
                )
                LabelChip(
                    icon: "speaker.wave.2.fill",
                    title: "Audio activo",
                    value: "\(session.durationMinutes) min"
                )
                LabelChip(
                    icon: "waveform.path.ecg",
                    title: "HR mínima",
                    value: session.minHR.map { "\(Int($0)) bpm" } ?? "—"
                )
                LabelChip(
                    icon: "music.note",
                    title: "Playlist",
                    value: session.playlistName
                )
            }
        }
    }

    private var emptyCard: some View {
        GlassCard {
            Text("Sin datos de la sesión.")
                .font(.system(size: 14))
                .foregroundStyle(Theme.textSecond)
        }
    }

    private var doneButton: some View {
        Button {
            controller.dismissSummary()
        } label: {
            Text("Cerrar")
        }
        .buttonStyle(PillButtonStyle())
        .padding(.top, 6)
    }
}
