import Speech
import AVFoundation
import Observation
import UIKit

/// Language used for dictation. `auto` follows the device; the others force a recogniser
/// so e.g. an English-language phone can still dictate Japanese or Chinese.
enum VoiceLanguage: String, CaseIterable, Identifiable {
    case auto
    case english            = "en-US"
    case japanese           = "ja-JP"
    case chineseSimplified  = "zh-CN"
    case chineseTraditional = "zh-TW"

    static let storageKey = "voice_language"
    var id: String { rawValue }

    var label: String {
        switch self {
        case .auto:               return "Automatic"
        case .english:            return "English"
        case .japanese:           return "日本語"
        case .chineseSimplified:  return "简体中文"
        case .chineseTraditional: return "繁體中文"
        }
    }

    /// The user's saved choice (`auto` if unset or unknown).
    static var selected: VoiceLanguage {
        VoiceLanguage(rawValue: UserDefaults.standard.string(forKey: storageKey) ?? "") ?? .auto
    }
}

/// Push-to-talk dictation for the chat input.
///
/// Every recording gets its own `sessionID`; recognition callbacks that arrive for an
/// older session (e.g. the previous recording is still finalising when the user taps the
/// mic again) are ignored, so they can no longer stop or overwrite the new recording.
@Observable
final class SpeechRecognizer {
    static let shared = SpeechRecognizer()

    private(set) var isRecording = false
    private(set) var transcript = ""
    var permissionDenied = false
    /// A user-presentable problem (recognizer unavailable, no microphone, …).
    var errorMessage: String?

    private var audioEngine: AVAudioEngine?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private var sessionID = UUID()
    private var isStarting = false
    /// True once the user (or an interruption) ended this recording. The recogniser then reports a
    /// cancellation/"no more audio" error while it wraps up — that is how stopping normally ends.
    private var userEnded = false

    private init() {
        // Anything that silently kills the audio engine must also reset our state,
        // otherwise `isRecording` stays true and the mic button does nothing.
        let center = NotificationCenter.default
        let reset: (Notification) -> Void = { [weak self] _ in
            Task { @MainActor in
                // Only while recording — otherwise this would also cut off text-to-speech.
                guard let self, self.isRecording else { return }
                self.stop()
            }
        }
        center.addObserver(forName: AVAudioSession.interruptionNotification, object: nil, queue: .main, using: reset)
        center.addObserver(forName: .AVAudioEngineConfigurationChange, object: nil, queue: .main, using: reset)
        center.addObserver(forName: UIApplication.didEnterBackgroundNotification, object: nil, queue: .main, using: reset)
    }

    // MARK: - Public

    /// Starts dictation, or — if already recording — stops the microphone but lets
    /// recognition finish so the final transcript is still delivered to `onUpdate`.
    func toggle(onUpdate: @escaping (String) -> Void) {
        if isRecording {
            stopCapture()
        } else {
            guard !isStarting else { return }   // ignore taps while permissions / engine spin up
            isStarting = true
            Task {
                await start(onUpdate: onUpdate)
                isStarting = false
            }
        }
    }

    /// Stops the microphone but lets recognition finish, so the last words aren't lost.
    func finish() {
        stopCapture()
    }

    /// Hard stop — cancels recognition immediately (used when sending a message).
    func stop() {
        stopCapture()
        recognitionTask?.cancel()
        recognitionTask = nil
        sessionID = UUID()
        releaseAudioSession()
    }

    // MARK: - Recording

    private func start(onUpdate: @escaping (String) -> Void) async {
        let speechAuth = await withCheckedContinuation { cont in
            SFSpeechRecognizer.requestAuthorization { cont.resume(returning: $0) }
        }
        let micAuth = await AVAudioApplication.requestRecordPermission()
        guard speechAuth == .authorized, micAuth else {
            permissionDenied = true
            return
        }

        guard let recognizer = Self.makeRecognizer(), recognizer.isAvailable else {
            errorMessage = "Speech recognition isn't available right now. Check your connection and try again."
            return
        }

        // Tear down whatever the previous recording left behind before starting a new one.
        stop()
        SpeechManager.shared.stop()   // don't talk over the microphone
        let id = UUID()
        sessionID = id
        userEnded = false
        transcript = ""

        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playAndRecord, mode: .measurement,
                                    options: [.duckOthers, .allowBluetooth, .defaultToSpeaker])
            try session.setActive(true, options: .notifyOthersOnDeactivation)

            let engine = AVAudioEngine()
            let format = engine.inputNode.outputFormat(forBus: 0)
            // No usable input (route changed mid-flight, no mic): installTap would raise an exception.
            guard format.sampleRate > 0, format.channelCount > 0 else {
                errorMessage = "No microphone is available."
                releaseAudioSession()
                return
            }

            let request = SFSpeechAudioBufferRecognitionRequest()
            request.shouldReportPartialResults = true
            request.addsPunctuation = true
            request.taskHint = .dictation
            recognitionRequest = request

            recognitionTask = recognizer.recognitionTask(with: request) { [weak self] result, error in
                let text = result?.bestTranscription.formattedString
                let isFinal = result?.isFinal ?? false
                let nsError = error as NSError?
                Task { @MainActor in
                    guard let self, self.sessionID == id else { return }   // stale session
                    if let text {
                        self.transcript = text
                        onUpdate(text)
                    }
                    if isFinal || nsError != nil {
                        // After a user-initiated stop the wrap-up error is expected; only surface errors
                        // when the recording died on its own, or ended without producing any text.
                        if let nsError, text == nil, !self.userEnded || self.transcript.isEmpty {
                            self.report(nsError)
                        }
                        self.recognitionTask = nil
                        self.stopCapture()
                        self.releaseAudioSession()
                    }
                }
            }

            engine.inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { buffer, _ in
                request.append(buffer)
            }
            engine.prepare()
            try engine.start()
            audioEngine = engine
            isRecording = true
        } catch {
            errorMessage = "Couldn't start the microphone. Please try again."
            stop()
        }
    }

    /// Stops the microphone and signals end-of-audio, but does NOT cancel the task,
    /// so the final transcript can still arrive.
    private func stopCapture() {
        userEnded = true
        if let engine = audioEngine {
            if engine.isRunning { engine.stop() }
            engine.inputNode.removeTap(onBus: 0)   // safe even if the engine was already stopped
        }
        audioEngine = nil
        recognitionRequest?.endAudio()
        recognitionRequest = nil
        isRecording = false
    }

    /// Gives the audio session back so text-to-speech plays at normal volume after dictation
    /// (it used to stay in the record-only category).
    private func releaseAudioSession() {
        guard !isRecording else { return }
        let session = AVAudioSession.sharedInstance()
        try? session.setActive(false, options: .notifyOthersOnDeactivation)
        try? session.setCategory(.playback, mode: .default)
    }

    // MARK: - Helpers

    /// `SFSpeechRecognizer(locale: .current)` is nil for combinations like en_JP, which made
    /// recording "work" while recognising nothing. Fall back to any supported locale with the
    /// same language, then to en-US.
    private static func makeRecognizer() -> SFSpeechRecognizer? {
        let supported = SFSpeechRecognizer.supportedLocales()
        var wanted: [Locale] = []
        if VoiceLanguage.selected != .auto {
            wanted.append(Locale(identifier: VoiceLanguage.selected.rawValue))   // explicit choice wins
        }
        wanted += [Locale.current] + Locale.preferredLanguages.map(Locale.init(identifier:))

        for locale in wanted {
            if let direct = SFSpeechRecognizer(locale: locale) { return direct }
            let language = locale.language.languageCode
            if let match = supported.first(where: { $0.language.languageCode == language }),
               let recognizer = SFSpeechRecognizer(locale: match) {
                return recognizer
            }
        }
        return SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    }

    private func report(_ error: NSError) {
        // 1110 = no speech detected, 216 / 301 = cancelled. The code is reported under either domain
        // depending on whether recognition ran on-device (kLSR…) or on the server (kAFAssistant…).
        let benign = ["kAFAssistantErrorDomain", "kLSRErrorDomain"].contains(error.domain)
            && [1110, 216, 301].contains(error.code)
        guard !benign, (error as NSError).code != NSUserCancelledError else { return }
        errorMessage = "Voice input stopped unexpectedly. Please try again."
    }
}
