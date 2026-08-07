import Foundation

public actor FeatureFlagStore {
    private var config: RemoteConfig
    private let diskURL: URL

    public init(defaults: RemoteConfig = .offlineDefaults, cacheDirectory: URL? = nil) {
        self.config = defaults
        let dir = cacheDirectory ?? FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
        self.diskURL = dir.appendingPathComponent("afterna-remote-config.json")
        if let data = try? Data(contentsOf: diskURL),
           let decoded = try? JSONDecoder().decode(RemoteConfig.self, from: data) {
            self.config = decoded
        }
    }

    public func current() -> RemoteConfig { config }

    public func refresh(using api: APIClient) async {
        do {
            let remote = try await api.fetchConfig()
            self.config = remote
            if let data = try? JSONEncoder().encode(remote) {
                try? data.write(to: diskURL, options: .atomic)
            }
        } catch {
            // Keep disk/offline defaults
        }
    }
}
