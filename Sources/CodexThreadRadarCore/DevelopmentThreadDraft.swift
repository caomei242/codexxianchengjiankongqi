import Foundation

public struct DevelopmentThreadDraft: Equatable, Sendable {
    public var title: String
    public var projectName: String
    public var goal: String
    public var nextAction: String
    public var status: ThreadStatus
    public var accountAlias: String
    public var observedAt: Date?

    public init(
        title: String = "",
        projectName: String = "",
        goal: String = "",
        nextAction: String = "",
        status: ThreadStatus = .active,
        accountAlias: String = "",
        observedAt: Date? = nil
    ) {
        self.title = title
        self.projectName = projectName
        self.goal = goal
        self.nextAction = nextAction
        self.status = status
        self.accountAlias = accountAlias
        self.observedAt = observedAt
    }

    public init(thread: DevelopmentThread) {
        title = thread.title
        projectName = thread.projectName
        goal = thread.goal
        nextAction = thread.nextAction
        status = thread.status
        accountAlias = thread.accountAlias ?? ""
    }

    public var canSave: Bool {
        !normalizedTitle.isEmpty &&
            !normalizedProjectName.isEmpty &&
            !normalizedGoal.isEmpty &&
            !normalizedNextAction.isEmpty
    }

    public func makeThread(id: UUID = UUID(), now: Date) -> DevelopmentThread {
        let timestamp = observedAt ?? now
        return DevelopmentThread(
            id: id,
            title: normalizedTitle,
            projectName: normalizedProjectName,
            goal: normalizedGoal,
            nextAction: normalizedNextAction,
            status: status,
            accountAlias: normalizedAccountAlias,
            createdAt: timestamp,
            updatedAt: timestamp,
            closedAt: status == .closed ? timestamp : nil
        )
    }

    public func updating(_ thread: DevelopmentThread, now: Date) -> DevelopmentThread {
        let timestamp = observedAt ?? now
        return DevelopmentThread(
            id: thread.id,
            title: normalizedTitle,
            projectName: normalizedProjectName,
            goal: normalizedGoal,
            nextAction: normalizedNextAction,
            status: status,
            accountAlias: normalizedAccountAlias,
            createdAt: thread.createdAt,
            updatedAt: timestamp,
            closedAt: status == .closed ? (thread.closedAt ?? timestamp) : nil
        )
    }

    private var normalizedTitle: String {
        title.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var normalizedProjectName: String {
        projectName.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var normalizedGoal: String {
        goal.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var normalizedNextAction: String {
        nextAction.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var normalizedAccountAlias: String? {
        let trimmed = accountAlias.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
