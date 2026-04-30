import SwiftUI
import SwiftData

struct HistoryView: View {
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \SleepSession.startDate, order: .reverse) private var sessions: [SleepSession]

    var body: some View {
        ZStack {
            AppBackground()
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        Text("Historial")
                            .font(.system(size: 28, weight: .bold))
                            .foregroundStyle(Theme.textPrimary)
                        Spacer()
                        Button {
                            dismiss()
                        } label: {
                            Image(systemName: "xmark")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(Theme.textPrimary)
                                .padding(10)
                                .background(Circle().fill(Color.white.opacity(0.08)))
                        }
                    }
                    .padding(.top, 16)

                    if sessions.isEmpty {
                        emptyState
                    } else {
                        ForEach(sessions) { session in
                            sessionRow(session)
                        }
                    }
                }
                .padding(.horizontal, 22)
                .padding(.bottom, 60)
            }
        }
    }

    private var emptyState: some View {
        GlassCard {
            VStack(spacing: 10) {
                Image(systemName: "moon.stars.fill")
                    .font(.system(size: 36))
                    .foregroundStyle(Theme.primarySoft)
                Text("Sin sesiones todavía")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Theme.textPrimary)
                Text("Cuando termines una sesión, aparecerá acá con tu gráfico de HR.")
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.textSecond)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
        }
        .padding(.top, 30)
    }

    private func sessionRow(_ s: SleepSession) -> some View {
        GlassCard(padding: 16, cornerRadius: 18) {
            HStack(spacing: 14) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(s.startDate.formatted(date: .abbreviated, time: .shortened))
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Theme.textPrimary)
                    Text(s.playlistName)
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.textSecond)
                        .lineLimit(1)
                    HStack(spacing: 12) {
                        if let onset = s.estimatedSleepOnsetMinutes {
                            badge("\(onset) min", icon: "moon.zzz")
                        }
                        if let m = s.minHR {
                            badge("\(Int(m)) bpm", icon: "heart")
                        }
                        badge("\(s.durationMinutes) min", icon: "clock")
                    }
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .foregroundStyle(Theme.textTertiary)
            }
        }
    }

    private func badge(_ text: String, icon: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 10))
                .foregroundStyle(Theme.primarySoft)
            Text(text)
                .font(.system(size: 11))
                .foregroundStyle(Theme.textSecond)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            Capsule().fill(Color.white.opacity(0.05))
        )
    }
}
