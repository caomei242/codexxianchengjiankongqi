import Foundation
import Testing
@testable import CodexThreadRadarCore

@MainActor
struct ThreadRadarStoreTests {
    @Test("store creates a current thread, persists it, and syncs markdown")
    func createsThreadAndSyncs() {
        let repository = RecordingThreadRepository()
        let markdownSync = RecordingMarkdownSync()
        let now = Date(timeIntervalSince1970: 10_000)
        let store = ThreadRadarStore(
            repository: repository,
            markdownSync: markdownSync,
            now: { now }
        )
        let draft = DevelopmentThreadDraft(
            title: "openclaw 安装助手",
            projectName: "个人--小开发",
            goal: "把 openclaw 在这台电脑装好并验证启动",
            nextAction: "切到备用账号后继续安装并跑启动验证",
            status: .quotaBlocked,
            accountAlias: "备用账号 A"
        )

        store.createThread(from: draft)

        #expect(store.records.count == 1)
        #expect(store.records.first?.title == "openclaw 安装助手")
        #expect(repository.savedRecords.last?.count == 1)
        #expect(markdownSync.lastSyncedRecords?.count == 1)
        #expect(store.errorMessage == nil)
    }

    @Test("closing a thread removes it from current visible threads")
    func closingThreadRemovesItFromCurrentView() {
        let thread = DevelopmentThread(
            id: UUID(uuidString: "66666666-6666-6666-6666-666666666666")!,
            title: "桌面文件隐藏器",
            projectName: "个人--小开发",
            goal: "新增线程雷达",
            nextAction: "跑一次打包验证",
            status: .readyToClose,
            accountAlias: nil,
            createdAt: Date(timeIntervalSince1970: 1),
            updatedAt: Date(timeIntervalSince1970: 2),
            closedAt: nil
        )
        let repository = RecordingThreadRepository(initialRecords: [thread])
        let store = ThreadRadarStore(repository: repository, markdownSync: nil, now: { Date(timeIntervalSince1970: 3) })

        store.closeThread(id: thread.id)

        #expect(store.records.first?.status == .closed)
        #expect(store.records.first?.closedAt == Date(timeIntervalSince1970: 3))
        #expect(store.visibleThreads.isEmpty)
        #expect(repository.savedRecords.last?.first?.status == .closed)
    }
}

private final class RecordingThreadRepository: ThreadRepository {
    var records: [DevelopmentThread]
    var savedRecords: [[DevelopmentThread]] = []

    init(initialRecords: [DevelopmentThread] = []) {
        records = initialRecords
    }

    func load() throws -> [DevelopmentThread] {
        records
    }

    func save(_ records: [DevelopmentThread]) throws {
        self.records = records
        savedRecords.append(records)
    }
}

private final class RecordingMarkdownSync: ThreadMarkdownSyncing {
    var lastSyncedRecords: [DevelopmentThread]?

    func sync(records: [DevelopmentThread], generatedAt: Date) throws {
        lastSyncedRecords = records
    }
}
