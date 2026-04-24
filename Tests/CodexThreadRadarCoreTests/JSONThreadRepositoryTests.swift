import Foundation
import Testing
@testable import CodexThreadRadarCore

struct JSONThreadRepositoryTests {
    @Test("json repository saves and loads development threads")
    func savesAndLoadsThreads() throws {
        try withTemporaryDirectory { directoryURL in
            let storageURL = directoryURL.appendingPathComponent("threads.json")
            let repository = JSONThreadRepository(storageURL: storageURL)
            let thread = DevelopmentThread(
                id: UUID(uuidString: "55555555-5555-5555-5555-555555555555")!,
                title: "数据包转化器",
                projectName: "个人--小开发",
                goal: "跑一次导入样例测试",
                nextAction: "执行样例并检查输出",
                status: .active,
                accountAlias: "主账号",
                createdAt: Date(timeIntervalSince1970: 1_000),
                updatedAt: Date(timeIntervalSince1970: 2_000),
                closedAt: nil
            )

            try repository.save([thread])
            let loaded = try repository.load()

            #expect(loaded == [thread])
        }
    }
}

private func withTemporaryDirectory(_ body: (URL) throws -> Void) throws {
    let directoryURL = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString, isDirectory: true)

    try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)

    defer {
        try? FileManager.default.removeItem(at: directoryURL)
    }

    try body(directoryURL)
}
