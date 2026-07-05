import Speech
import AVFoundation
import Observation

@Observable
final class SpeechRecognizer: @unchecked Sendable {
    static let shared = SpeechRecognizer()

    var isRecording = false
    var transcript = ""
    var permissionDenied = false

    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let audioEngine = AVAudioEngine()
    private let recognizer = SFSpeechRecognizer(locale: .current)

    private init() {}

    // MARK: - Public

    /// User-initiated toggle: stops audio capture but lets recognition
    /// finish so the final transcript is delivered via onUpdate.
    func toggle(onUpdate: @escaping (String) -> Void) {
        if isRecording {
            endAudioCapture()   // ← don't cancel task; let it finalise
        } else {
            Task { await start(onUpdate: onUpdate) }
        }
    }

    /// Hard stop — cancels everything immediately (used when sending a message).
    func stop() {
        endAudioCapture()
        recognitionTask?.cancel()
        recognitionTask = nil
    }

    // MARK: - Private

    /// Stop the microphone and signal end-of-audio to the recogniser,
    /// but do NOT cancel recognitionTask so the final result can arrive.
    private func endAudioCapture() {
        guard audioEngine.isRunning else { return }
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        recognitionRequest?.endAudio()
        recognitionRequest = nil
        DispatchQueue.main.async { self.isRecording = false }
    }

    private func start(onUpdate: @escaping (String) -> Void) async {
        let speechAuth = await withCheckedContinuation { cont in
            SFSpeechRecognizer.requestAuthorization { cont.resume(returning: $0) }
        }
        let micAuth = await AVAudioApplication.requestRecordPermission()

        guard speechAuth == .authorized, micAuth else {
            DispatchQueue.main.async { self.permissionDenied = true }
            return
        }

        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.record, mode: .measurement, options: .allowBluetoothHFP)
            try session.setActive(true, options: .notifyOthersOnDeactivation)

            let request = SFSpeechAudioBufferRecognitionRequest()
            request.shouldReportPartialResults = true
            request.addsPunctuation = true
            recognitionRequest = request

            recognitionTask = recognizer?.recognitionTask(with: request) { [weak self] result, error in
                guard let self else { return }
                if let result {
                    let text = result.bestTranscription.formattedString
                    DispatchQueue.main.async {
                        self.transcript = text
                        onUpdate(text)
                    }
                }
                // Task finished (final result or error) — clean up task reference only
                if error != nil || result?.isFinal == true {
                    DispatchQueue.main.async {
                        self.recognitionTask = nil
                        // If audio engine somehow still running, stop it
                        if self.audioEngine.isRunning { self.endAudioCapture() }
                    }
                }
            }

            let inputNode = audioEngine.inputNode
            let format = inputNode.outputFormat(forBus: 0)
            inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { buffer, _ in
                request.append(buffer)
            }

            audioEngine.prepare()
            try audioEngine.start()
            DispatchQueue.main.async { self.isRecording = true }
        } catch {
            stop()
        }
    }
}
