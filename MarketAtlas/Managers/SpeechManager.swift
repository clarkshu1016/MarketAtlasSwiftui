import AVFoundation
import Observation

@Observable
final class SpeechManager: NSObject {
    static let shared = SpeechManager()

    private let synthesizer = AVSpeechSynthesizer()
    private(set) var speakingMessageId: UUID?

    private override init() {
        super.init()
        synthesizer.delegate = self
    }

    /// Tap same message → stop. Tap different message → stop old, speak new.
    func toggle(text: String, messageId: UUID) {
        if speakingMessageId == messageId {
            synthesizer.stopSpeaking(at: .immediate)
            speakingMessageId = nil
            return
        }
        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
        utterance.rate = 0.52
        utterance.pitchMultiplier = 1.0
        speakingMessageId = messageId
        synthesizer.speak(utterance)
    }

    func stop() {
        guard synthesizer.isSpeaking else { return }
        synthesizer.stopSpeaking(at: .immediate)
        speakingMessageId = nil
    }
}

extension SpeechManager: AVSpeechSynthesizerDelegate {
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        DispatchQueue.main.async { self.speakingMessageId = nil }
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        DispatchQueue.main.async { self.speakingMessageId = nil }
    }
}
