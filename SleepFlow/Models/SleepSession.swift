import Foundation
import SwiftData

@Model
final class SleepSession {
    @Attribute(.unique) var id: UUID
    var startDate: Date
    var endDate: Date?
    var estimatedSleepOnsetMinutes: Int?
    var hrSamples: [HRSample]
    var playlistName: String
    var trackTitles: [String]
    var basalHR: Double
    var minHR: Double?
    var maxHR: Double?
    var notes: String?

    init(
        id: UUID = UUID(),
        startDate: Date = .now,
        playlistName: String = "Sin playlist",
        trackTitles: [String] = [],
        basalHR: Double = 65
    ) {
        self.id = id
        self.startDate = startDate
        self.endDate = nil
        self.estimatedSleepOnsetMinutes = nil
        self.hrSamples = []
        self.playlistName = playlistName
        self.trackTitles = trackTitles
        self.basalHR = basalHR
        self.minHR = nil
        self.maxHR = nil
        self.notes = nil
    }

    var duration: TimeInterval {
        (endDate ?? .now).timeIntervalSince(startDate)
    }

    var durationMinutes: Int {
        Int(duration / 60)
    }

    func appendSample(_ sample: HRSample) {
        hrSamples.append(sample)
        if minHR == nil || sample.value < (minHR ?? .infinity) { minHR = sample.value }
        if maxHR == nil || sample.value > (maxHR ?? 0) { maxHR = sample.value }
    }
}
