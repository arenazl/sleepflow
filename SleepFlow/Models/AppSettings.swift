import Foundation
import SwiftUI

final class AppSettings: ObservableObject {
    @AppStorage("basalHR") var basalHR: Double = 65
    @AppStorage("alarmHour") var alarmHour: Int = 7
    @AppStorage("alarmMinute") var alarmMinute: Int = 30
    @AppStorage("alarmEnabled") var alarmEnabled: Bool = false
    @AppStorage("fadeOutAfterSilenceSeconds") var fadeOutAfterSilenceSeconds: Double = 180
    @AppStorage("maxSessionMinutes") var maxSessionMinutes: Int = 240
    @AppStorage("hasGrantedHealth") var hasGrantedHealth: Bool = false
    @AppStorage("lastPlaylistName") var lastPlaylistName: String = ""

    static let shared = AppSettings()
}
