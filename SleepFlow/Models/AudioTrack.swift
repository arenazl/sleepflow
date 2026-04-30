import Foundation

struct AudioTrack: Codable, Hashable, Identifiable {
    var id: UUID = UUID()
    let title: String
    let artist: String
    let persistentID: UInt64
    let duration: TimeInterval

    var subtitle: String {
        artist.isEmpty ? "Apple Music" : artist
    }
}

struct Playlist: Codable, Hashable {
    let name: String
    let tracks: [AudioTrack]

    var totalDuration: TimeInterval {
        tracks.reduce(0) { $0 + $1.duration }
    }
}
