import Foundation
import Testing
@testable import CodexThreadRadarCore

struct ThreadResumePromptFormatterTests {
    @Test("resume prompt includes only the current development thread context")
    func promptIncludesCurrentThreadContext() {
        let thread = DevelopmentThread(
            id: UUID(uuidString: "11111111-1111-1111-1111-111111111111")!,
            title: "openclaw 安装助手",
            projectName: "个人--小开发",
            goal: "把 openclaw 在这台电脑装好并验证启动",
            nextAction: "切到备用账号后继续安装并跑启动验证",
            status: .quotaBlocked,
            accountAlias: "备用账号 A",
            createdAt: Date(timeIntervalSince1970: 10),
            updatedAt: Date(timeIntervalSince1970: 20),
            closedAt: nil
        )

        let prompt = ThreadResumePromptFormatter.prompt(for: thread)

        #expect(prompt == """
        继续线程：openclaw 安装助手
        项目：个人--小开发
        目标：把 openclaw 在这台电脑装好并验证启动
        当前状态：卡额度
        关联账号：备用账号 A
        下一步：切到备用账号后继续安装并跑启动验证
        """)
    }

    @Test("resume prompt omits account line when no account alias is set")
    func promptOmitsEmptyAccountAlias() {
        let thread = DevelopmentThread(
            id: UUID(uuidString: "22222222-2222-2222-2222-222222222222")!,
            title: "桌面文件隐藏器",
            projectName: "个人--小开发",
            goal: "新增线程雷达小工具",
            nextAction: "补菜单栏快捷捕获入口",
            status: .active,
            accountAlias: nil,
            createdAt: Date(timeIntervalSince1970: 10),
            updatedAt: Date(timeIntervalSince1970: 20),
            closedAt: nil
        )

        let prompt = ThreadResumePromptFormatter.prompt(for: thread)

        #expect(!prompt.contains("关联账号"))
        #expect(prompt.contains("当前状态：正在推进"))
    }
}
