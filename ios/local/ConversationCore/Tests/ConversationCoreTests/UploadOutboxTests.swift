import XCTest
@testable import ConversationCore

final class UploadOutboxTests: XCTestCase {
    func testMockUploadTransitionsToSucceeded() async throws {
        let uploader = MockUploading()
        let item = OutboxItem(
            localFileURL: URL(fileURLWithPath: "/tmp/a.m4a"),
            durationMs: 1000,
            checksumSHA256: String(repeating: "ab", count: 32),
            byteSize: 12
        )
        let result = try await uploader.process(item)
        XCTAssertEqual(result.state, .succeeded)
        XCTAssertNotNil(result.jobId)
    }

    func testOfflineConfigDefaults() {
        XCTAssertEqual(RemoteConfig.offlineDefaults.baseFreeMinutes, 0)
        XCTAssertEqual(RemoteConfig.offlineDefaults.rewardMinutes, 10)
        XCTAssertTrue(RemoteConfig.offlineDefaults.featureFlags.askAI)
    }
}
