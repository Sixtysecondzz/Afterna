import Foundation
import Observation
import SwiftData

@Observable
@MainActor
final class AppContainer {
    let modelContainer: ModelContainer
    let flags: FeatureFlagStore
    let api: APIClient
    let uploadOutbox: any Uploading
    let tokenStore: DevTokenStore
    let audio: AudioCapturing
    let usesMockUpload: Bool

    init(useMockUpload: Bool = true) {
        let schema = Schema([ConversationEntity.self, TranscriptSegmentEntity.self])
        let config = ModelConfiguration(isStoredInMemoryOnly: false)
        self.modelContainer = try! ModelContainer(for: schema, configurations: config)

        self.tokenStore = DevTokenStore()
        let base = URL(string: ProcessInfo.processInfo.environment["AFTERNA_API_BASE"] ?? "http://127.0.0.1:8787")!
        self.api = APIClient(baseURL: base, tokenStore: tokenStore)
        self.flags = FeatureFlagStore()
        self.usesMockUpload = useMockUpload
        self.uploadOutbox = useMockUpload ? MockUploading() : UploadOutbox(api: api)
        self.audio = AVAudioCaptureEngine()
    }
}

public final class DevTokenStore: TokenStore, @unchecked Sendable {
    public func accessToken() async -> String? { "dev-user" }
}
