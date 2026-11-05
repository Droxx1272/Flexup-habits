import Foundation
import AVFoundation
import UIKit

/// The running games' voice: speaks over music (ducking it, not stopping
/// it) and taps the wrist with a haptic. One shared instance so a closing
/// line still finishes after the run screen goes away.
///
/// Speech keeps going with the screen locked only when the app declares the
/// "audio" background mode next to "location" (Xcode → Signing &
/// Capabilities → Background Modes). Without it, prompts play while the
/// app is open.
final class Announcer: NSObject, AVSpeechSynthesizerDelegate {
    static let shared = Announcer()

    enum Haptic {
        case alert, success, failure, tap
    }

    /// Off = haptics only. Toggled from the run screen.
    var voiceOn = true

    private let synthesizer = AVSpeechSynthesizer()

    override init() {
        super.init()
        synthesizer.delegate = self
    }

    func say(_ text: String, haptic: Haptic? = nil) {
        if let haptic { play(haptic) }
        guard voiceOn else { return }
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playback, mode: .voicePrompt, options: [.duckOthers, .interruptSpokenAudioAndMixWithOthers])
        try? session.setActive(true)
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: AVSpeechSynthesisVoice.currentLanguageCode())
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate
        synthesizer.speak(utterance)
    }

    func stop() {
        _ = synthesizer.stopSpeaking(at: .word)
    }

    private func play(_ haptic: Haptic) {
        switch haptic {
        case .alert: UINotificationFeedbackGenerator().notificationOccurred(.warning)
        case .success: UINotificationFeedbackGenerator().notificationOccurred(.success)
        case .failure: UINotificationFeedbackGenerator().notificationOccurred(.error)
        case .tap: UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        }
    }

    // Give the music its volume back once nothing is queued.
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        guard !synthesizer.isSpeaking else { return }
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }
}
