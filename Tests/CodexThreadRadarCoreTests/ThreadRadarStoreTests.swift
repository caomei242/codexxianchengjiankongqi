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

    @Test("refreshing from Codex sessions replaces current records and keeps closed history")
    func refreshFromCodexSessionsReplacesCurrentRecords() {
        let active = DevelopmentThread(
            id: UUID(uuidString: "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa")!,
            title: "旧线程",
            projectName: "旧项目",
            goal: "旧目标",
            nextAction: "旧动作",
            status: .active,
            accountAlias: nil,
            createdAt: Date(timeIntervalSince1970: 1),
            updatedAt: Date(timeIntervalSince1970: 2),
            closedAt: nil
        )
        let closed = DevelopmentThread(
            id: UUID(uuidString: "bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb")!,
            title: "已收口线程",
            projectName: "历史项目",
            goal: "历史目标",
            nextAction: "不用处理",
            status: .closed,
            accountAlias: nil,
            createdAt: Date(timeIntervalSince1970: 3),
            updatedAt: Date(timeIntervalSince1970: 4),
            closedAt: Date(timeIntervalSince1970: 5)
        )
        let repository = RecordingThreadRepository(initialRecords: [active, closed])
        let markdownSync = RecordingMarkdownSync()
        let now = Date(timeIntervalSince1970: 99)
        let store = ThreadRadarStore(
            repository: repository,
            markdownSync: markdownSync,
            now: { now }
        )
        let scanner = StubCodexSessionScanner(drafts: [
            DevelopmentThreadDraft(
                title: "codex线程监控器",
                projectName: "个人--小开发",
                goal: "继续推进 codex线程监控器",
                nextAction: "回到线程确认最后结果，决定收口或继续。",
                status: .needsReview
            ),
        ])

        let refreshedCount = store.refreshFromCodexSessions(scanner: scanner)

        #expect(refreshedCount == 1)
        #expect(store.records.map(\.title) == ["已收口线程", "codex线程监控器"])
        #expect(store.records.last?.createdAt == now)
        #expect(store.records.last?.updatedAt == now)
        #expect(repository.savedRecords.last?.map(\.title) == ["已收口线程", "codex线程监控器"])
        #expect(markdownSync.lastSyncedRecords?.map(\.title) == ["已收口线程", "codex线程监控器"])
    }

    @Test("refreshing with no Codex sessions keeps the current records")
    func refreshFromCodexSessionsWithNoResultsKeepsCurrentRecords() {
        let active = DevelopmentThread(
            id: UUID(uuidString: "cccccccc-cccc-cccc-cccc-cccccccccccc")!,
            title: "正在推进的线程",
            projectName: "当前项目",
            goal: "当前目标",
            nextAction: "当前下一步",
            status: .active,
            accountAlias: nil,
            createdAt: Date(timeIntervalSince1970: 6),
            updatedAt: Date(timeIntervalSince1970: 7),
            closedAt: nil
        )
        let repository = RecordingThreadRepository(initialRecords: [active])
        let store = ThreadRadarStore(repository: repository, markdownSync: nil, now: { Date(timeIntervalSince1970: 99) })
        let scanner = StubCodexSessionScanner(drafts: [])

        let refreshedCount = store.refreshFromCodexSessions(scanner: scanner)

        #expect(refreshedCount == 0)
        #expect(store.records.map(\.title) == ["正在推进的线程"])
        #expect(store.errorMessage == "没有扫描到当前 Codex 线程。")
        #expect(repository.savedRecords.isEmpty)
    }

    @Test("refreshing keeps scanner order in visible threads")
    func refreshFromCodexSessionsKeepsScannerOrder() {
        let repository = RecordingThreadRepository()
        let now = Date(timeIntervalSince1970: 99)
        let store = ThreadRadarStore(repository: repository, markdownSync: nil, now: { now })
        let scanner = StubCodexSessionScanner(drafts: [
            DevelopmentThreadDraft(title: "B 线程", projectName: "项目", goal: "目标", nextAction: "下一步", status: .active),
            DevelopmentThreadDraft(title: "A 线程", projectName: "项目", goal: "目标", nextAction: "下一步", status: .active),
        ])

        store.refreshFromCodexSessions(scanner: scanner)

        #expect(store.visibleThreads.map(\.title) == ["B 线程", "A 线程"])
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

private struct StubCodexSessionScanner: CodexSessionScanning {
    let drafts: [DevelopmentThreadDraft]

    func scan() throws -> [DevelopmentThreadDraft] {
        drafts
    }
}
