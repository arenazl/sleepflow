# SleepFlow — Especificación Completa para Desarrollo

> Documento de contexto para Claude Code. Leer completo antes de generar código.

---

## 1. Concepto

App iOS que usa el Apple Watch como sensor pasivo de frecuencia cardíaca para adaptar el volumen del audio (música o podcast) mientras el usuario se duerme. Cuando el sistema detecta que el usuario se durmió (HR baja + sin movimiento), baja el audio hasta silenciarlo.

**Inspiración:** Muse S Headband — sin EEG, usando HRV/HR como proxy fisiológico.

---

## 2. Plataforma y Restricciones

| Item | Decisión |
|---|---|
| Plataforma | iOS únicamente |
| Lenguaje | Swift + SwiftUI |
| Versión mínima iOS | iOS 17+ |
| Apple Watch | Solo como sensor — NO se crea watchOS app |
| Trigger desde Watch | Shortcut de iOS con URL Scheme (complication nativa) |
| Audio | AVAudioEngine |
| Datos de salud | HealthKit |
| Backend | Ninguno — todo on-device |
| Subscripción/Auth | Ninguna en MVP |

---

## 3. Arquitectura

```
SleepFlowApp (SwiftUI)
│
├── AppDelegate
│   └── Registra URL Scheme: sleepflow://start y sleepflow://stop
│
├── Views/
│   ├── HomeView                  ← pantalla principal
│   ├── SessionActiveView         ← pantalla mientras duerme
│   └── SessionSummaryView        ← resumen de la noche
│
├── Services/
│   ├── AudioEngineService        ← AVAudioEngine, fade, playlist
│   ├── HeartRateService          ← HealthKit observer query
│   └── RelaxationCalculator      ← algoritmo HR → score 0.0-1.0
│
├── Models/
│   ├── SleepSession              ← datos de una sesión
│   ├── HRSample                  ← timestamp + valor HR
│   └── AudioTrack                ← referencia a archivo de audio
│
└── Persistence/
    └── SessionStore              ← SwiftData (historial de sesiones)
```

---

## 4. Flujo de Usuario

### 4.1 Antes de dormir (HomeView)
1. Usuario abre la app en iPhone
2. Elige fuente de audio: **Playlist** (archivos locales o Apple Music) o **Podcast** (URL de feed)
3. Configura alarma de despertar (opcional)
4. Toca "Iniciar" — o toca la **complication en el Watch**

### 4.2 Durante la sesión (SessionActiveView)
- Pantalla muestra HR actual, score de relajación, volumen actual
- Pantalla se apaga normalmente (no keepAwake)
- Audio sigue reproduciéndose en background
- HealthKit observer recibe HR cada ~5 minutos del Watch
- `RelaxationCalculator` calcula si la tendencia es descendente
- `AudioEngineService` ajusta volumen suavemente

### 4.3 Al despertar (SessionSummaryView)
- Muestra gráfico de HR a lo largo de la noche
- Muestra en qué minuto se detectó el "sleep onset"
- Muestra duración total con audio
- Botón para exportar o compartir

---

## 5. Módulos Detallados

### 5.1 HeartRateService

**Responsabilidad:** Registrarse en HealthKit para recibir actualizaciones de HR en background.

```
Permisos requeridos:
  - HKQuantityTypeIdentifier.heartRate (lectura)

Tipo de query:
  - HKObserverQuery sobre heartRate
  - enableBackgroundDelivery(frequency: .immediate)

Al recibir notificación:
  - Ejecutar HKSampleQuery para obtener el último valor
  - Publicar via Combine: @Published var latestHR: Double

Frecuencia real de datos en reposo:
  - Apple Watch escribe HR cada ~5 minutos cuando no hay workout activo
  - Es suficiente para detectar tendencia durante el sueño
```

**No se necesita HKWorkoutSession** — el Watch escribe HR automáticamente en HealthKit.

---

### 5.2 RelaxationCalculator

**Responsabilidad:** Convertir los últimos N samples de HR en un score de relajación 0.0 a 1.0.

```
Inputs:
  - Array de HRSample (últimos 20 minutos)
  - HR basal del usuario (configurable, default 65)

Algoritmo (simple, ajustable):
  1. Calcular HR promedio de últimos 3 samples
  2. Calcular tendencia: ¿está bajando respecto a los 3 anteriores?
  3. Normalizar respecto al HR basal del usuario

  score = clamp((basalHR - currentAvgHR) / 15.0, 0.0, 1.0)
  
  Modificadores:
  - Si tendencia es descendente: score += 0.1
  - Si hay 10+ minutos sin movimiento (del Watch via HealthKit): score += 0.15

Outputs:
  - relaxationScore: Double (0.0 = alerta, 1.0 = dormido)
  - estimatedSleepOnset: Bool (score > 0.75 por más de 5 min)
```

**Nota:** Este algoritmo se puede mejorar con datos históricos. Después de 30 sesiones, se puede calcular el HR personal de "sleep onset" y ajustar automáticamente el umbral.

---

### 5.3 AudioEngineService

**Responsabilidad:** Reproducir audio y ajustar volumen en respuesta al relaxationScore.

```
Engine: AVAudioEngine
Nodos:
  - AVAudioPlayerNode (playerNode) — reproduce el archivo
  - AVAudioMixerNode (mainMixer) — controla volumen global

Categoría de sesión de audio:
  AVAudioSession.Category.playback
  AVAudioSession.Mode.default
  Opciones: .mixWithOthers (para no cortar otros audios)

Background Audio:
  Requiere "Audio, AirPlay, and Picture in Picture" en Info.plist
  (UIBackgroundModes: audio)

Métodos principales:
  - loadPlaylist(tracks: [AudioTrack])
  - play()
  - pause()
  - stop()
  - setVolume(_ volume: Float, fadeDuration: TimeInterval)
  
Lógica de fade:
  - Se llama desde RelaxationCalculator cada vez que llega nuevo HR
  - volumenTarget = 1.0 - relaxationScore
  - Si volumenTarget < 0.05 por más de 3 minutos → fade out completo → stop
  - El fade es gradual (5-10 segundos de transición)

Crossfade entre tracks (nice to have):
  - Dos playerNodes alternados
  - Al finalizar track 1, fade in en track 2 simultáneamente
```

---

### 5.4 URL Scheme (Trigger desde Watch)

**Configuración en Info.plist:**
```xml
<key>CFBundleURLTypes</key>
<array>
  <dict>
    <key>CFBundleURLSchemes</key>
    <array>
      <string>sleepflow</string>
    </array>
  </dict>
</array>
```

**URLs soportadas:**
- `sleepflow://start` → inicia sesión con configuración guardada
- `sleepflow://stop` → detiene sesión activa
- `sleepflow://start?playlist=last` → inicia con última playlist usada

**Cómo el usuario lo configura en Watch (cero código):**
1. En iPhone: app Atajos → Nuevo atajo → "Abrir URL" → `sleepflow://start`
2. Nombrar el atajo "Dormir"
3. En Watch: Settings → Dock o complication → agregar atajo "Dormir"

---

### 5.5 SleepSession (SwiftData Model)

```swift
@Model
class SleepSession {
    var id: UUID
    var startDate: Date
    var endDate: Date?
    var estimatedSleepOnsetMinutes: Int?   // minutos hasta dormirse
    var hrSamples: [HRSample]              // array de muestras
    var playlistName: String
    var notes: String?
}

struct HRSample: Codable {
    var timestamp: Date
    var value: Double
}
```

---

## 6. Pantallas (SwiftUI)

### HomeView
```
┌─────────────────────────────┐
│  🌙 SleepFlow               │
│                             │
│  ┌─────────────────────┐    │
│  │  Fuente de Audio    │    │
│  │  [Playlist ▾]       │    │
│  │  Cosmic Healing Mix │    │
│  └─────────────────────┘    │
│                             │
│  Alarma: 07:30 ▾            │
│                             │
│  HR Basal: 65 bpm  ✎        │
│                             │
│  ┌─────────────────────┐    │
│  │    Iniciar Sesión   │    │
│  └─────────────────────┘    │
│                             │
│  Historial  ·  Ajustes      │
└─────────────────────────────┘
```

### SessionActiveView
```
┌─────────────────────────────┐
│  Sesión activa — 00:34      │
│                             │
│         💓 62 bpm           │
│                             │
│  Relajación: ████████░░ 82% │
│  Volumen:    ████░░░░░░ 40% │
│                             │
│  Estado: Casi dormido...    │
│                             │
│  [Detener]                  │
└─────────────────────────────┘
```

### SessionSummaryView
```
┌─────────────────────────────┐
│  ✅ Sesión completada       │
│                             │
│  [Gráfico HR vs tiempo]     │
│  ─────────────────────────  │
│  Te dormiste en: ~18 min    │
│  Audio activo: 23 min       │
│  HR al dormirte: 58 bpm     │
│                             │
│  [Guardar]   [Compartir]    │
└─────────────────────────────┘
```

---

## 7. Permisos Requeridos (Info.plist)

```xml
<!-- HealthKit -->
<key>NSHealthShareUsageDescription</key>
<string>SleepFlow usa tu frecuencia cardíaca para adaptar el audio mientras te dormís.</string>

<key>NSHealthUpdateUsageDescription</key>
<string>SleepFlow guarda datos de sesiones de sueño en Salud.</string>

<!-- Background Audio -->
<key>UIBackgroundModes</key>
<array>
  <string>audio</string>
</array>

<!-- URL Scheme -->
<key>CFBundleURLTypes</key>
<array>
  <dict>
    <key>CFBundleURLSchemes</key>
    <array><string>sleepflow</string></array>
  </dict>
</array>
```

---

## 8. Dependencias

| Dependencia | Uso | Cómo agregar |
|---|---|---|
| Ninguna externa | Todo es frameworks nativos | — |
| AVFoundation | Audio engine | Nativo iOS |
| HealthKit | Lectura de HR | Nativo iOS |
| SwiftData | Persistencia | Nativo iOS 17+ |
| Combine | Reactividad HR → Audio | Nativo iOS |

**No hay dependencias de terceros.** Todo es SDK nativo de Apple.

---

## 9. Roadmap de Fases

### Fase 1 — MVP (objetivo inicial)
- [ ] Proyecto Xcode configurado con HealthKit + Audio background
- [ ] `HeartRateService` con HKObserverQuery funcionando
- [ ] `AudioEngineService` con reproducción y fade manual
- [ ] `RelaxationCalculator` algoritmo básico
- [ ] `HomeView` + `SessionActiveView`
- [ ] URL Scheme `sleepflow://start`
- [ ] Persistencia básica con SwiftData

### Fase 2 — Mejoras
- [ ] `SessionSummaryView` con gráfico (Charts framework)
- [ ] Soporte para podcast via URL (AVPlayer)
- [ ] Alarma inteligente (leer sleep stages de HealthKit al día siguiente)
- [ ] Crossfade entre tracks

### Fase 3 — Personalización
- [ ] Calibración automática de HR basal por historial
- [ ] Widget de iOS para inicio rápido
- [ ] Exportar sesiones a CSV

---

## 10. Decisiones de Diseño y Justificaciones

| Decisión | Justificación |
|---|---|
| No app de watchOS | Evita complejidad de WatchConnectivity y review adicional en App Store. El Watch ya escribe HR en HealthKit automáticamente. |
| HKObserverQuery vs HKWorkoutSession | Para sueño, HR cada 5 min es suficiente. No vale la pena el consumo de batería de una workout session activa. |
| AVAudioEngine vs AVPlayer | AVAudioEngine permite control granular del volumen con fade suave. AVPlayer solo tiene `.volume` sin transiciones nativas. |
| SwiftData vs CoreData | SwiftData es el reemplazo moderno nativo. Más simple, totalmente compatible con Swift Concurrency. |
| Shortcut como trigger | Cero código watchOS. Funciona en cualquier Watch con watchOS 7+. El usuario lo configura en 2 pasos. |
| Sin backend | Los datos de sueño son muy personales. On-device + HealthKit es la decisión correcta en privacidad y simplicidad. |
| Soporte podcast + música | El usuario reporta que escucha podcasts y se duerme bien. No forzar cambio de hábito — adaptar la tecnología al usuario. |

---

## 11. Notas para el Agente de Desarrollo

1. **Empezar por `HeartRateService`** — es el módulo central y conviene validar que HealthKit funciona antes de construir la UI.
2. **Probar en dispositivo físico** — HealthKit no funciona en simulador.
3. **El fade de audio** debe ser gradual (mínimo 5 segundos de transición) para no despertar al usuario si hay un pico de HR momentáneo.
4. **Background delivery de HealthKit** requiere que la app haya sido abierta al menos una vez después de instalarse.
5. **AVAudioSession category** debe configurarse antes de iniciar el engine, no después.
6. **El relaxationScore no debe reaccionar a un solo sample** — siempre promediar los últimos 3 para evitar falsos positivos (HR spike por movimiento nocturno).
7. **Nombre de app sugerido:** SleepFlow — verificar disponibilidad en App Store antes de hardcodear.
