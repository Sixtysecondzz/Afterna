import Foundation
import AVFoundation

protocol AudioCapturing: AnyObject {
    var isRecording: Bool { get }
    func requestPermission() async -> Bool
    func start(sessionId: UUID) throws -> URL
    func stop() throws -> (url: URL, durationMs: Int)
}

/// File-based capture via AVAudioRecorder (stable on Simulator + device).
final class AVAudioCaptureEngine: NSObject, AudioCapturing, AVAudioRecorderDelegate {
    private var recorder: AVAudioRecorder?
    private var outputURL: URL?
    private var startedAt: Date?
    private(set) var isRecording = false

    func requestPermission() async -> Bool {
        await withCheckedContinuation { continuation in
            AVAudioApplication.requestRecordPermission { allowed in
                continuation.resume(returning: allowed)
            }
        }
    }

    func start(sessionId: UUID) throws -> URL {
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(
            .playAndRecord,
            mode: .default,
            options: [.defaultToSpeaker, .allowBluetoothHFP]
        )
        try session.setActive(true, options: .notifyOthersOnDeactivation)

        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            .appendingPathComponent("Recordings/\(sessionId.uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let url = dir.appendingPathComponent("take.m4a")

        // Prefer hardware rate when valid; otherwise 44.1k (Simulator often reports 0).
        let hardwareRate = session.sampleRate
        let sampleRate = hardwareRate > 0 ? hardwareRate : 44_100

        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: sampleRate,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue,
        ]

        let recorder = try AVAudioRecorder(url: url, settings: settings)
        recorder.delegate = self
        recorder.isMeteringEnabled = true
        guard recorder.prepareToRecord(), recorder.record() else {
            throw NSError(domain: "AudioCapturing", code: 2, userInfo: [
                NSLocalizedDescriptionKey: "Could not start AVAudioRecorder",
            ])
        }

        self.recorder = recorder
        self.outputURL = url
        self.startedAt = Date()
        self.isRecording = true
        return url
    }

    func stop() throws -> (url: URL, durationMs: Int) {
        recorder?.stop()
        isRecording = false

        // Keep session tidy for next take
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)

        guard let url = outputURL, let startedAt else {
            throw NSError(domain: "AudioCapturing", code: 1, userInfo: [
                NSLocalizedDescriptionKey: "Recording was not started",
            ])
        }

        // Prefer recorder timeline when available
        let recorded = recorder?.currentTime ?? 0
        let ms: Int
        if recorded > 0 {
            ms = Int(recorded * 1000)
        } else {
            ms = max(Int(Date().timeIntervalSince(startedAt) * 1000), 0)
        }

        self.recorder = nil
        self.outputURL = nil
        self.startedAt = nil
        return (url, ms)
    }
}
