import Foundation
import Testing
@testable import CodexThreadRadarCore

struct ThreadMarkdownRendererTests {
    @Test("current thread markdown excludes closed records and keeps next actions visible")
    func rendersCurrentThreadsOnly() {
        let active = DevelopmentThread(
            id: UUID(uuidString: "33333333-3333-3333-3333-333333333333")!,
            title: "桌面文件隐藏器",
            projectName: "个人--小开发",
            goal: "做一个当下开发线程雷达",
            nextAction: "补菜单栏快捷捕获入口",
            status: .active,
            accountAlias: nil,
            createdAt: Date(timeIntervalSince1970: 1),
            updatedAt: Date(timeIntervalSince1970: 1_800),
            closedAt: nil
        )
        let closed = DevelopmentThread(
            id: UUID(uuidString: "44444444-4444-4444-4444-444444444444")!,
            title: "历史旧线程",
            projectName: "个人--小开发",
            goal: "不应该出现在当前面板",
            nextAction: "无",
            status: .closed,
            accountAlias: nil,
            createdAt: Date(timeIntervalSince1970: 1),
            updatedAt: Date(timeIntervalSince1970: 2),
            closedAt: Date(timeIntervalSince1970: 3)
        )

        let markdown = ThreadMarkdownRenderer.renderCurrentThreads(
            records: [closed, active],
            generatedAt: Date(timeIntervalSince1970: 3_600)
        )

        #expect(markdown.contains("# 当下开发线程"))
        #expect(markdown.contains("当前 1 条开发线程"))
        #expect(markdown.contains("## 正在推进"))
        #expect(markdown.contains("- 下一步：补菜单栏快捷捕获入口"))
        #expect(!markdown.contains("历史旧线程"))
    }
}
