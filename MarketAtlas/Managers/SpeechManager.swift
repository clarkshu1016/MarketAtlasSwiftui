import AVFoundation
import NaturalLanguage
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
        // Dictation leaves the session in a record category; make sure we can actually play.
        let session = AVAudioSession.sharedInstance()
        if session.category != .playAndRecord {
            try? session.setCategory(.playback, mode: .spokenAudio)
        }
        try? session.setActive(true)

        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = Self.voice(for: text)
        utterance.rate = 0.52
        utterance.pitchMultiplier = 1.0
        speakingMessageId = messageId
        synthesizer.speak(utterance)
    }

    /// Pick a voice that matches the text — the chat now answers in the user's language,
    /// and an English voice reading Japanese or Chinese is unintelligible.
    private static func voice(for text: String) -> AVSpeechSynthesisVoice? {
        let identifier: String
        switch NLLanguageRecognizer.dominantLanguage(for: text) {
        case .japanese:           identifier = "ja-JP"
        case .simplifiedChinese:  identifier = "zh-CN"
        case .traditionalChinese: identifier = "zh-TW"
        default:                  identifier = "en-US"
        }
        return AVSpeechSynthesisVoice(language: identifier) ?? AVSpeechSynthesisVoice(language: "en-US")
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
