import Foundation

struct HRSample: Codable, Hashable, Identifiable {
    var id: UUID = UUID()
    let timestamp: Date
    let value: Double

    init(timestamp: Date = .now, value: Double) {
        self.timestamp = timestamp
        self.value = value
    }
}
