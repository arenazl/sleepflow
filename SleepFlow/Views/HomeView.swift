import SwiftUI
import MediaPlayer

struct HomeView: View {
    @EnvironmentObject var controller: SessionController
    @ObservedObject private var settings = AppSettings.shared
    @State private var showPicker = false
    @State private var showHistory = false
    @State private var showBasalEdit = false
    @State private var showAlarmPicker = false
    @State private var alarmDate: Date = Calendar.current.date(
        bySettingHour: 7, minute: 30, second: 0, of: .now
    ) ?? .now

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                header
                heartCard
                playlistCard
                alarmCard
                basalCard
                startButton
                footer
            }
            .padding(.horizontal, 22)
            .padding(.top, 18)
            .padding(.bottom, 60)
        }
        .sheet(isPresented: $showPicker) {
            MusicPickerView { items in
                controller.setPicked(items: items)
                showPicker = false
            }
            .ignoresSafeArea()
        }
        .sheet(isPresented: $showHistory) {
            HistoryView()
        }
        .sheet(isPresented: $showAlarmPicker) {
            alarmPickerSheet
                .presentationDetents([.medium])
        }
        .alert("Frecuencia cardíaca basal", isPresented: $showBasalEdit) {
            TextField("65", value: $settings.basalHR, formatter: NumberFormatter())
                .keyboardType(.numberPad)
            Button("Guardar") {}
        } message: {
            Text("Tu HR de descanso. SleepFlow lo usa como referencia para detectar cuándo bajás.")
        }
        .onAppear { syncAlarmFromSettings() }
    }

    private var header: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 4) {
                Text("SleepFlow")
                    .font(.system(size: 32, weight: .bold))
                    .foregroundStyle(Theme.textPrimary)
                    .kerning(0.5)
                Text("Audio que se duerme con vos")
                    .font(.system(size: 14))
                    .foregroundStyle(Theme.textSecond)
            }
            Spacer()
            Button {
                showHistory = true
            } label: {
                Image(systemName: "clock.arrow.circlepath")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(Theme.textPrimary)
                    .padding(12)
                    .background(Circle().fill(Color.white.opacity(0.08)))
            }
        }
    }

    private var heartCard: some View {
        GlassCard {
            HStack(spacing: 16) {
                PulsingHeart(size: 38)
                VStack(alignment: .leading, spacing: 2) {
                    Text(controller.heart.isAuthorized
                         ? "Watch conectado a Salud"
                         : (controller.heart.authorizationDenied
                            ? "Permiso de HR denegado"
                            : "Pidiendo permiso de HR..."))
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Theme.textPrimary)
                    Text(controller.heart.latestHR.map { "Última lectura: \(Int($0)) bpm" }
                         ?? "Esperando primer dato del Apple Watch")
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.textSecond)
                }
                Spacer()
            }
        }
    }

    private var playlistCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Image(systemName: "music.note.list")
                        .foregroundStyle(Theme.primarySoft)
                    Text("Música para dormir")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Theme.textPrimary)
                    Spacer()
                }
                if controller.pickedTracks.isEmpty {
                    Text("Elegí canciones de tu librería de Apple Music. Se reproducirán en bucle hasta que detectemos sleep onset.")
                        .font(.system(size: 13))
                        .foregroundStyle(Theme.textSecond)
                } else {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(controller.pickedTracks.prefix(3)) { t in
                            HStack(spacing: 10) {
                                Image(systemName: "play.circle.fill")
                                    .foregroundStyle(Theme.primary)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(t.title)
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundStyle(Theme.textPrimary)
                                        .lineLimit(1)
                                    Text(t.subtitle)
                                        .font(.system(size: 11))
                                        .foregroundStyle(Theme.textTertiary)
                                        .lineLimit(1)
                                }
                                Spacer()
                            }
                        }
                        if controller.pickedTracks.count > 3 {
                            Text("+ \(controller.pickedTracks.count - 3) más")
                                .font(.system(size: 12))
                                .foregroundStyle(Theme.textTertiary)
                        }
                    }
                }
                Button {
                    showPicker = true
                } label: {
                    Text(controller.pickedTracks.isEmpty ? "Elegir música" : "Cambiar selección")
                }
                .buttonStyle(GhostButtonStyle())
            }
        }
    }

    private var alarmCard: some View {
        GlassCard {
            HStack(spacing: 14) {
                Image(systemName: "alarm.fill")
                    .foregroundStyle(Theme.primarySoft)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Alarma")
                        .font(.system(size: 13))
                        .foregroundStyle(Theme.textSecond)
                    Text(settings.alarmEnabled
                         ? String(format: "%02d:%02d", settings.alarmHour, settings.alarmMinute)
                         : "Apagada")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(Theme.textPrimary)
                }
                Spacer()
                Toggle("", isOn: $settings.alarmEnabled).labelsHidden()
                    .tint(Theme.primary)
                Button {
                    showAlarmPicker = true
                } label: {
                    Image(systemName: "chevron.right")
                        .foregroundStyle(Theme.textTertiary)
                }
            }
        }
    }

    private var basalCard: some View {
        Button { showBasalEdit = true } label: {
            GlassCard {
                HStack(spacing: 14) {
                    Image(systemName: "waveform.path.ecg")
                        .foregroundStyle(Theme.primarySoft)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("HR basal")
                            .font(.system(size: 13))
                            .foregroundStyle(Theme.textSecond)
                        Text("\(Int(settings.basalHR)) bpm")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(Theme.textPrimary)
                    }
                    Spacer()
                    Image(systemName: "pencil")
                        .foregroundStyle(Theme.textTertiary)
                }
            }
        }
        .buttonStyle(.plain)
    }

    private var startButton: some View {
        Button {
            controller.start()
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "moon.zzz.fill")
                Text("Iniciar sesión")
            }
        }
        .buttonStyle(PillButtonStyle())
        .disabled(!controller.heart.isAuthorized && !controller.heart.authorizationDenied)
        .padding(.top, 6)
    }

    private var footer: some View {
        HStack {
            Spacer()
            Text("Atajo desde Watch: sleepflow://start")
                .font(.system(size: 11))
                .foregroundStyle(Theme.textTertiary)
            Spacer()
        }
        .padding(.top, 10)
    }

    private var alarmPickerSheet: some View {
        VStack(spacing: 18) {
            Text("Hora de despertar")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(Theme.textPrimary)
                .padding(.top, 18)
            DatePicker("", selection: $alarmDate, displayedComponents: .hourAndMinute)
                .datePickerStyle(.wheel)
                .labelsHidden()
                .colorScheme(.dark)
            Button("Listo") {
                let comp = Calendar.current.dateComponents([.hour, .minute], from: alarmDate)
                settings.alarmHour = comp.hour ?? 7
                settings.alarmMinute = comp.minute ?? 30
                settings.alarmEnabled = true
                showAlarmPicker = false
            }
            .buttonStyle(PillButtonStyle())
            .padding(.horizontal, 22)
            .padding(.bottom, 22)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AppBackground())
    }

    private func syncAlarmFromSettings() {
        if let d = Calendar.current.date(
            bySettingHour: settings.alarmHour,
            minute: settings.alarmMinute,
            second: 0,
            of: .now
        ) {
            alarmDate = d
        }
    }
}
