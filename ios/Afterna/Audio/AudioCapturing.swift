import Foundation
import AVFoundation

public protocol AudioCapturing: AnyObject {
    var isRecording: Bool { get }
    func requestPermission() async -> Bool
    func start(sessionId: UUID) throws -> URL
    func stop() throws -> (url: URL, durationMs: Int)
}

#if canImport(AVFoundation)
public final class AVAudioCaptureEngine: AudioCapturing {
    private let engine = AVAudioEngine()
    private var file: AVAudioFile?
    private var outputURL: URL?
    private var startedAt: Date?
    public private(set) var isRecording = false

    public init() {}

    public func requestPermission() async -> Bool {
        await withCheckedContinuation { cont in
            AVAudioApplication.requestRecordPermission { allowed in
                cont.resume(returning: allowed)
            }
        }
    }

    public func start(sessionId: UUID) throws -> URL {
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker, .allowBluetooth])
        try session.setActive(true)

        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            .appendingPathComponent("Recordings/\(sessionId.uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let url = dir.appendingPathComponent("take.m4a")

        let input = engine.inputNode
        let format = input.outputFormat(forBus: 0)
        let settings: [String: Any] = [
            AVFormatIDKey: kAudioFormatMPEG4AAC,
            AVSampleRateKey: format.sampleRate,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]
        file = try AVAudioFile(forWriting: url, settings: settings)
        outputURL = url
        startedAt = Date()

        input.installTap(onBus: 0, bufferSize: 4096, format: format) { [weak self] buffer, _ in
            try? self?.file?.write(from: buffer)
        }
        try engine.start()
        isRecording = true
        return url
    }

    public func stop() throws -> (url: URL, durationMs: Int) {
        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
        isRecording = false
        guard let url = outputURL, let startedAt else {
            throw NSError(domain: "AudioCapturing", code: 1)
        }
        let ms = Int(Date().timeIntervalSince(startedAt) * 1000)
        file = nil
        return (url, ms)
    }
}
#else
public final class AVAudioCaptureEngine: AudioCapturing {
    public private(set) var isRecording = false
    public init() {}
    public func requestPermission() async -> Bool { true }
    public func start(sessionId: UUID) throws -> URL {
        isRecording = true
        return FileManager.default.temporaryDirectory.appendingPathComponent("\(sessionId).m4a")
    }
    public func stop() throws -> (url: URL, durationMs: Int) {
        isRecording = false
        return (FileManager.default.temporaryDirectory.appendingPathComponent("mock.m4a"), 1000)
    }
}
#endif
