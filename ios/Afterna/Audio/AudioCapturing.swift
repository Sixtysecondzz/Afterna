import Foundation
import AVFoundation

protocol AudioCapturing: AnyObject {
    var isRecording: Bool { get }
    func requestPermission() async -> Bool
    func start(sessionId: UUID) throws -> URL
    func stop() throws -> (url: URL, durationMs: Int)
}

final class AVAudioCaptureEngine: AudioCapturing {
    private let engine = AVAudioEngine()
    private var file: AVAudioFile?
    private var outputURL: URL?
    private var startedAt: Date?
    private(set) var isRecording = false

    init() {}

    func requestPermission() async -> Bool {
        await withCheckedContinuation { continuation in
            AVAudioApplication.requestRecordPermission { allowed in
                continuation.resume(returning: allowed)
            }
        }
    }

    func start(sessionId: UUID) throws -> URL {
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker, .allowBluetooth])
        try session.setActive(true)

        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            .appendingPathComponent("Recordings/\(sessionId.uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let url = dir.appendingPathComponent("take.m4a")

        let input = engine.inputNode
        let format = input.outputFormat(forBus: 0)
        // Use hardware format channel count when available; force mono AAC file.
        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: format.sampleRate > 0 ? format.sampleRate : 44100,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue,
        ]
        file = try AVAudioFile(forWriting: url, settings: settings)
        outputURL = url
        startedAt = Date()

        let fileRef = file
        input.installTap(onBus: 0, bufferSize: 4096, format: format) { buffer, _ in
            try? fileRef?.write(from: buffer)
        }
        try engine.start()
        isRecording = true
        return url
    }

    func stop() throws -> (url: URL, durationMs: Int) {
        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
        isRecording = false
        guard let url = outputURL, let startedAt else {
            throw NSError(domain: "AudioCapturing", code: 1, userInfo: [
                NSLocalizedDescriptionKey: "Recording was not started",
            ])
        }
        let ms = Int(Date().timeIntervalSince(startedAt) * 1000)
        file = nil
        outputURL = nil
        self.startedAt = nil
        return (url, ms)
    }
}
