import Foundation

enum RelaxationCalculator {
    /// Returns 0.0 (alert) → 1.0 (asleep) given recent HR samples vs basal.
    static func score(samples: [HRSample], basalHR: Double) -> Double {
        guard !samples.isEmpty else { return 0 }
        let recent = Array(samples.suffix(3))
        let avg = recent.map(\.value).reduce(0, +) / Double(recent.count)

        var s = (basalHR - avg) / 15.0

        if samples.count >= 6 {
            let prev = Array(samples.dropLast(3).suffix(3))
            let prevAvg = prev.map(\.value).reduce(0, +) / Double(prev.count)
            if avg < prevAvg { s += 0.10 }
        }

        return max(0.0, min(1.0, s))
    }

    /// Minute (relative to first sample) when score has been ≥ threshold for ≥ sustainedMinutes.
    static func sleepOnsetMinute(samples: [HRSample],
                                 basalHR: Double,
                                 threshold: Double = 0.75,
                                 sustainedMinutes: Int = 5) -> Int? {
        guard let first = samples.first else { return nil }
        var aboveSince: Date?
        for i in samples.indices {
            let window = Array(samples.prefix(i + 1))
            let s = score(samples: window, basalHR: basalHR)
            if s >= threshold {
                if aboveSince == nil { aboveSince = window.last?.timestamp }
                if let since = aboveSince,
                   let now = window.last?.timestamp,
                   now.timeIntervalSince(since) >= Double(sustainedMinutes) * 60 {
                    return Int(now.timeIntervalSince(first.timestamp) / 60)
                }
            } else {
                aboveSince = nil
            }
        }
        return nil
    }

    static func targetVolume(score: Double) -> Float {
        Float(max(0.0, min(1.0, 1.0 - score)))
    }

    /// Human-friendly status string for UI.
    static func statusLabel(score: Double) -> String {
        switch score {
        case ..<0.20: return "Despierto"
        case ..<0.45: return "Relajándote"
        case ..<0.70: return "Casi durmiendo"
        case ..<0.85: return "Sueño ligero"
        default:      return "Dormido"
        }
    }
}
