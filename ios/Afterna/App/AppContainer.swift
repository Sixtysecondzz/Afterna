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
    let audio: AudioCapturing
    let usesMockUpload: Bool
    let auth: AuthService

    init(useMockUpload: Bool = true) {
        let schema = Schema([ConversationEntity.self, TranscriptSegmentEntity.self])
        let config = ModelConfiguration(isStoredInMemoryOnly: false)
        self.modelContainer = try! ModelContainer(for: schema, configurations: config)

        let auth = AuthService()
        self.auth = auth

        let base = URL(string: ProcessInfo.processInfo.environment["AFTERNA_API_BASE"] ?? "http://127.0.0.1:8787")!
        self.api = APIClient(baseURL: base, tokenStore: auth.tokenStore)
        self.flags = FeatureFlagStore()
        self.usesMockUpload = useMockUpload
        self.uploadOutbox = useMockUpload ? MockUploading() : UploadOutbox(api: api)
        self.audio = AVAudioCaptureEngine()
    }
}
