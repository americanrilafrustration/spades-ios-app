import AudioToolbox
import Foundation
import UIKit

struct AppSettings: Equatable {
    var music: Bool = true
    var sfx: Bool = true
    var vibration: Bool = true

    private static let defaults = UserDefaults.standard

    static func load() -> AppSettings {
        AppSettings(
            music: defaults.object(forKey: "music") as? Bool ?? true,
            sfx: defaults.object(forKey: "sfx") as? Bool ?? true,
            vibration: defaults.object(forKey: "vibration") as? Bool ?? true
        )
    }

    func persist() {
        Self.defaults.set(music, forKey: "music")
        Self.defaults.set(sfx, forKey: "sfx")
        Self.defaults.set(vibration, forKey: "vibration")
    }
}

enum GameAudio {
    static func playShuffle(enabled: Bool) {
        guard enabled else { return }
        AudioServicesPlaySystemSound(1104)
    }

    static func playCard(enabled: Bool) {
        guard enabled else { return }
        AudioServicesPlaySystemSound(1103)
    }

    static func playSpades(enabled: Bool) {
        guard enabled else { return }
        AudioServicesPlaySystemSound(1057)
    }

    static func vibrateTurn(enabled: Bool) {
        guard enabled else { return }
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
        UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
    }
}
