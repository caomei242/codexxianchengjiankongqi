import Foundation
import Testing
@testable import CodexThreadRadarCore

struct ThreadProjectSectionsTests {
    @Test("project sections group visible threads by project and keep latest-first ordering")
    func groupsThreadsByProject() {
        let records = [
            makeThread(title: "开发助手", projectName: "项目 B", updatedAt: Date(timeIntervalSince1970: 220)),
            makeThread(title: "录入助手", projectName: "项目 A", updatedAt: Date(timeIntervalSince1970: 300)),
            makeThread(title: "自动转点数器", projectName: "项目 B", updatedAt: Date(timeIntervalSince1970: 280)),
            makeThread(title: "旧线程", projectName: "项目 C", status: .closed, updatedAt: Date(timeIntervalSince1970: 400), closedAt: Date(timeIntervalSince1970: 401)),
            makeThread(title: "发票助手", projectName: "项目 A", updatedAt: Date(timeIntervalSince1970: 120)),
        ]

        let sections = ThreadProjectSection.makeSections(
            from: ThreadStatusFilter.all.visibleThreads(from: records)
        )

        #expect(sections.map(\.projectName) == ["项目 A", "项目 B"])
        #expect(sections[0].threads.map(\.title) == ["录入助手", "发票助手"])
        #expect(sections[1].threads.map(\.title) == ["自动转点数器", "开发助手"])
    }
}

private func makeThread(
    title: String,
    projectName: String,
    status: ThreadStatus = .active,
    updatedAt: Date,
    closedAt: Date? = nil
) -> DevelopmentThread {
    DevelopmentThread(
        id: UUID(),
        title: title,
        projectName: projectName,
        goal: "继续推进 \(title)",
        nextAction: "继续下一步",
        status: status,
        accountAlias: nil,
        createdAt: Date(timeIntervalSince1970: 1),
        updatedAt: updatedAt,
        closedAt: closedAt
    )
}
