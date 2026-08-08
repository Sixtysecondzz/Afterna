import Foundation

struct LiveCaptionTurn: Identifiable, Equatable, Sendable {
    let id: UUID
    var speakerLabel: String
    var text: String
    var startMs: Int
    var endMs: Int
    var isFinal: Bool
}

/// Client → AssemblyAI Streaming v3 WebSocket using a short-lived token from Afterna API.
actor AssemblyAIStreamingClient {
    enum StreamError: Error, LocalizedError {
        case invalidURL
        case notConnected
        case serverClosed(String)

        var errorDescription: String? {
            switch self {
            case .invalidURL: return "Invalid streaming URL"
            case .notConnected: return "Streaming socket not connected"
            case .serverClosed(let reason): return reason
            }
        }
    }

    private var task: URLSessionWebSocketTask?
    private var session: URLSession?
    private var receiveLoop: Task<Void, Never>?
    private var reconnectAttempt = 0
    private var shouldRun = false
    private var tokenProvider: (@Sendable () async throws -> StreamingTokenResponse)?
    private var onTurn: (@Sendable (LiveCaptionTurn) -> Void)?
    private var onStatus: (@Sendable (String) -> Void)?
    private var fixtureMode = false
    private var fixtureTask: Task<Void, Never>?
    private var lastConnection: (wsURL: URL, token: String, params: [String: String])?

    func start(
        tokenProvider: @escaping @Sendable () async throws -> StreamingTokenResponse,
        onTurn: @escaping @Sendable (LiveCaptionTurn) -> Void,
        onStatus: @escaping @Sendable (String) -> Void
    ) async throws {
        self.tokenProvider = tokenProvider
        self.onTurn = onTurn
        self.onStatus = onStatus
        shouldRun = true
        reconnectAttempt = 0
        try await connect()
    }

    func sendPCM(_ data: Data) {
        guard !fixtureMode else { return }
        guard let task, task.state == .running else { return }
        task.send(.data(data)) { _ in }
    }

    func stop() async {
        shouldRun = false
        fixtureTask?.cancel()
        fixtureTask = nil
        receiveLoop?.cancel()
        receiveLoop = nil
        if let task, task.state == .running {
            let terminate = #"{"type":"Terminate"}"#
            try? await task.send(.string(terminate))
        }
        task?.cancel(with: .goingAway, reason: nil)
        task = nil
        session?.invalidateAndCancel()
        session = nil
        lastConnection = nil
    }

    private func connect() async throws {
        guard let tokenProvider else { return }
        onStatus?("Connecting captions…")
        let tokenResponse = try await tokenProvider()
        fixtureMode = tokenResponse.fixture

        if fixtureMode {
            onStatus?("Live captions (fixture)")
            startFixtureCaptions()
            return
        }

        var components = URLComponents(string: tokenResponse.wsUrl)
        var items = tokenResponse.params.map { URLQueryItem(name: $0.key, value: $0.value.description) }
        items.append(URLQueryItem(name: "token", value: tokenResponse.token))
        // Ensure required streaming defaults exist
        if !items.contains(where: { $0.name == "speech_model" }) {
            items.append(URLQueryItem(name: "speech_model", value: "universal-3-5-pro"))
        }
        if !items.contains(where: { $0.name == "sample_rate" }) {
            items.append(URLQueryItem(name: "sample_rate", value: "16000"))
        }
        components?.queryItems = items
        guard let url = components?.url else { throw StreamError.invalidURL }

        lastConnection = (
            url,
            tokenResponse.token,
            Dictionary(uniqueKeysWithValues: tokenResponse.params.map { ($0.key, $0.value.description) })
        )
        let session = URLSession(configuration: .default)
        self.session = session
        let task = session.webSocketTask(with: url)
        self.task = task
        task.resume()
        onStatus?("Live captions")
        reconnectAttempt = 0
        receiveLoop?.cancel()
        receiveLoop = Task { await self.receiveForever() }
    }

    private func receiveForever() async {
        while shouldRun, let task, !Task.isCancelled {
            do {
                let message = try await task.receive()
                switch message {
                case .string(let text):
                    handleMessage(text)
                case .data(let data):
                    if let text = String(data: data, encoding: .utf8) {
                        handleMessage(text)
                    }
                @unknown default:
                    break
                }
            } catch {
                if shouldRun {
                    onStatus?("Captions reconnecting…")
                    await reconnect()
                }
                return
            }
        }
    }

    private func reconnect() async {
        guard shouldRun else { return }
        reconnectAttempt += 1
        let delay = min(pow(2.0, Double(min(reconnectAttempt, 4))), 16)
        try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
        task?.cancel(with: .goingAway, reason: nil)
        task = nil
        do {
            try await connect()
        } catch {
            onStatus?("Caption stream failed: \(error.localizedDescription)")
            if shouldRun {
                await reconnect()
            }
        }
    }

    private func handleMessage(_ text: String) {
        guard let data = text.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let type = json["type"] as? String
        else { return }

        switch type {
        case "Begin":
            onStatus?("Live captions")
        case "Turn":
            let transcript = (json["transcript"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            guard !transcript.isEmpty else { return }
            let endOfTurn = json["end_of_turn"] as? Bool ?? false
            let words = json["words"] as? [[String: Any]] ?? []
            let startMs = words.compactMap { $0["start"] as? Int }.min() ?? 0
            let endMs = words.compactMap { $0["end"] as? Int }.max() ?? startMs
            let speaker = (json["speaker"] as? String)
                ?? (words.compactMap { $0["speaker"] as? String }.first)
                ?? "A"
            let turn = LiveCaptionTurn(
                id: UUID(),
                speakerLabel: speaker,
                text: transcript,
                startMs: startMs,
                endMs: endMs,
                isFinal: endOfTurn
            )
            onTurn?(turn)
        case "Termination":
            onStatus?("Captions ended")
        default:
            break
        }
    }

    private func startFixtureCaptions() {
        fixtureTask?.cancel()
        fixtureTask = Task {
            let lines = [
                "Let's ship the Afterna live caption pipeline this week.",
                "Agreed — archive after stop, then extract key points.",
                "File uploads can still use the async AssemblyAI path.",
            ]
            var t = 0
            for (idx, line) in lines.enumerated() {
                if Task.isCancelled || !shouldRun { return }
                t += 1200
                let partial = LiveCaptionTurn(
                    id: UUID(),
                    speakerLabel: idx % 2 == 0 ? "A" : "B",
                    text: line,
                    startMs: t,
                    endMs: t + 900,
                    isFinal: false
                )
                onTurn?(partial)
                try? await Task.sleep(nanoseconds: 700_000_000)
                if Task.isCancelled || !shouldRun { return }
                var final = partial
                final = LiveCaptionTurn(
                    id: partial.id,
                    speakerLabel: partial.speakerLabel,
                    text: line,
                    startMs: partial.startMs,
                    endMs: partial.endMs,
                    isFinal: true
                )
                onTurn?(final)
                try? await Task.sleep(nanoseconds: 1_200_000_000)
            }
        }
    }
}
