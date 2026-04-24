import Foundation
import Testing
@testable import CodexThreadRadarCore

struct ThreadDashboardTests {
    @Test("summary counts only unfinished current development threads")
    func summaryCountsOnlyCurrentThreads() {
        let records = [
            makeThread(title: "openclaw 安装助手", status: .quotaBlocked),
            makeThread(title: "桌面文件隐藏器", status: .active),
            makeThread(title: "网店发票填写器", status: .needsReview),
            makeThread(title: "已完成旧线程", status: .closed, closedAt: Date(timeIntervalSince1970: 400)),
        ]

        let summary = ThreadRadarSummary(records: records)

        #expect(summary.currentCount == 3)
        #expect(summary.quotaBlockedCount == 1)
        #expect(summary.needsReviewCount == 1)
    }

    @Test("status filter excludes closed threads from the all-current view")
    func filterExcludesClosedThreads() {
        let records = [
            makeThread(title: "openclaw 安装助手", status: .quotaBlocked, updatedAt: Date(timeIntervalSince1970: 100)),
            makeThread(title: "桌面文件隐藏器", status: .active, updatedAt: Date(timeIntervalSince1970: 200)),
            makeThread(title: "旧线程", status: .closed, updatedAt: Date(timeIntervalSince1970: 300), closedAt: Date(timeIntervalSince1970: 400)),
        ]

        #expect(ThreadStatusFilter.all.visibleThreads(from: records).map(\.title) == [
            "桌面文件隐藏器",
            "openclaw 安装助手",
        ])
        #expect(ThreadStatusFilter.quotaBlocked.visibleThreads(from: records).map(\.title) == [
            "openclaw 安装助手",
        ])
    }
}

private func makeThread(
    title: String,
    status: ThreadStatus,
    updatedAt: Date = Date(timeIntervalSince1970: 100),
    closedAt: Date? = nil
) -> DevelopmentThread {
    DevelopmentThread(
        id: UUID(),
        title: title,
        projectName: "个人--小开发",
        goal: "保持当下开发上下文",
        nextAction: "继续下一步",
        status: status,
        accountAlias: nil,
        createdAt: Date(timeIntervalSince1970: 1),
        updatedAt: updatedAt,
        closedAt: closedAt
    )
}
