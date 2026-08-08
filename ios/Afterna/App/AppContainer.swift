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
    let credits: CreditsWallet
    let memoryOrg: MemoryOrgStore

    init(useMockUpload: Bool? = nil) {
        let schema = Schema([
            ConversationEntity.self,
            TranscriptSegmentEntity.self,
            FolderEntity.self,
            ActionItemEntity.self,
            QuoteEntity.self,
        ])
        let config = ModelConfiguration(isStoredInMemoryOnly: false)
        self.modelContainer = try! ModelContainer(for: schema, configurations: config)

        let auth = AuthService()
        self.auth = auth

        let base = URL(string: APIConfig.baseURLString)!
        self.api = APIClient(baseURL: base, tokenStore: auth.tokenStore)
        self.flags = FeatureFlagStore()
        let defaults = RemoteConfig.offlineDefaults
        self.credits = CreditsWallet(
            rewardMinutes: defaults.rewardMinutes,
            maxDailyRewards: defaults.maxDailyRewards,
            welcomeCredits: AdMobConfig.welcomeCredits
        )
        self.memoryOrg = MemoryOrgStore(auth: auth, tokenStore: auth.tokenStore)
        let mock = useMockUpload ?? APIConfig.useMockUpload
        self.usesMockUpload = mock
        self.uploadOutbox = mock ? MockUploading() : UploadOutbox(api: api)
        self.audio = StreamingMicEngine()
    }

    func bindCreditsToCurrentUser() {
        credits.bind(userId: auth.userId)
    }
}
