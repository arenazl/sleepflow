# SleepFlow — Guía para el Agente

## Qué es SleepFlow
App iOS nativa (SwiftUI, iOS 17+) que reproduce música/podcast mientras el usuario se duerme y baja el volumen automáticamente al detectar sleep onset, usando la frecuencia cardíaca del Apple Watch via HealthKit. Inspirada en Muse S Headband. Se distribuye via AltStore (sideloading).

## Workflow de desarrollo
1. El agente escribe/modifica código Swift
2. El agente commitea y pushea a `master` (o `main`)
3. GitHub Actions buildea el IPA y lo pushea a `arenazl/sleepflow-dist`
4. El usuario abre AltStore en su iPhone y actualiza

**El usuario NO toca código, NO usa Xcode, NO edita archivos.**
Su única acción es abrir AltStore y tocar "actualizar".

## Qué hace el agente en cada cambio
1. Modificar los `.swift` necesarios
2. Si se crea un archivo `.swift` nuevo, agregarlo al `SleepFlow.xcodeproj/project.pbxproj` (silenciosamente)
3. Bumpear `version` y `buildVersion` en `altstore-source.json`
4. Commitear todo y pushear
5. Avisar al usuario "refrescá AltStore"

## Qué NO hacer
- No mencionar pbxproj, xcodeproj ni internals de Xcode
- No pedirle al usuario tareas técnicas (Xcode, certs, paths locales)
- Hablar de funcionalidades, no de archivos
- No regenerar `DIST_PAT` salvo que falle la CI por auth

## Estructura del proyecto
```
SleepFlow/
├── SleepFlowApp.swift          # Entry point + URL scheme handler
├── Info.plist                  # Permisos: HealthKit, Apple Music, Audio background
├── SleepFlow.entitlements      # HealthKit entitlement
├── Assets.xcassets/            # Iconos
├── Models/
│   ├── SleepSession.swift      # @Model SwiftData (sesión completa)
│   ├── HRSample.swift          # struct Codable (timestamp + bpm)
│   └── AudioTrack.swift        # struct (título, artista, persistentID)
├── Services/
│   ├── HeartRateService.swift  # HKObserverQuery + background delivery
│   ├── AudioEngineService.swift# AVPlayer + fade gradual + queue
│   ├── RelaxationCalculator.swift # HR → score 0-1, sleep onset
│   └── MusicPickerService.swift   # MPMediaPicker wrapper
└── Views/
    ├── Theme.swift             # Tokens de diseño (colores, transiciones)
    ├── HomeView.swift          # Pantalla inicial: playlist + alarma + iniciar
    ├── SessionActiveView.swift # En sesión: HR + score + volumen
    ├── SessionSummaryView.swift# Post-sesión: gráfico HR + métricas
    └── HistoryView.swift       # Lista de sesiones anteriores
```

## Stack
- **UI:** SwiftUI (gradientes, glass morphism oscuro)
- **Audio:** AVFoundation (AVPlayer + custom fade)
- **HR:** HealthKit (HKObserverQuery, sin app watchOS)
- **Persistencia:** SwiftData (iOS 17+)
- **Música:** MediaPlayer / MPMediaPickerController
- **CI/CD:** GitHub Actions → IPA → `arenazl/sleepflow-dist` → AltStore

## URL Scheme (trigger desde Watch)
- `sleepflow://start` — inicia sesión con configuración guardada
- `sleepflow://stop` — detiene sesión activa

El usuario configura un atajo en iPhone → Atajos → "Abrir URL" → `sleepflow://start`, lo nombra "Dormir" y lo pone como complication en el Watch.

## Permisos clave (Info.plist)
- `NSHealthShareUsageDescription` — leer HR
- `NSHealthUpdateUsageDescription` — guardar sesión en Salud (opcional)
- `NSAppleMusicUsageDescription` — leer librería de Apple Music
- `UIBackgroundModes: audio` — playback con pantalla apagada
- `CFBundleURLSchemes: sleepflow` — atajo desde Watch

## Constraint conocido
HealthKit con cuenta Apple Developer **gratuita** funciona en dispositivo personal pero NO se puede publicar a App Store (lo cual da igual — sideload via AltStore). Si en runtime HealthKit niega permisos por entitlement, la app cae en modo manual (HR ingresado a mano).

## Versionado
- El JSON `altstore-source.json` lleva el historial
- Commits: `feat: vN - descripción`
- `CURRENT_PROJECT_VERSION` en pbxproj debe ir en sync con `buildVersion` del JSON
