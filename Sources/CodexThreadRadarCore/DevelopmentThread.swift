import Foundation

public struct DevelopmentThread: Identifiable, Codable, Equatable, Sendable {
    public var id: UUID
    public var title: String
    public var projectName: String
    public var goal: String
    public var nextAction: String
    public var status: ThreadStatus
    public var accountAlias: String?
    public var createdAt: Date
    public var updatedAt: Date
    public var closedAt: Date?

    public init(
        id: UUID = UUID(),
        title: String,
        projectName: String,
        goal: String,
        nextAction: String,
        status: ThreadStatus,
        accountAlias: String?,
        createdAt: Date,
        updatedAt: Date,
        closedAt: Date?
    ) {
        self.id = id
        self.title = title
        self.projectName = projectName
        self.goal = goal
        self.nextAction = nextAction
        self.status = status
        self.accountAlias = accountAlias
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.closedAt = closedAt
    }

    public var isCurrent: Bool {
        status != .closed
    }
}

public enum ThreadStatus: String, Codable, CaseIterable, Identifiable, Sendable {
    case active
    case quotaBlocked
    case waitingForConfirmation
    case needsReview
    case readyToClose
    case closed

    public var id: String {
        rawValue
    }

    public var label: String {
        switch self {
        case .active:
            "正在推进"
        case .quotaBlocked:
            "卡额度"
        case .waitingForConfirmation:
            "等我确认"
        case .needsReview:
            "待验收"
        case .readyToClose:
            "可收口"
        case .closed:
            "已收口"
        }
    }

    public var sortRank: Int {
        switch self {
        case .active:
            0
        case .quotaBlocked:
            1
        case .waitingForConfirmation:
            2
        case .needsReview:
            3
        case .readyToClose:
            4
        case .closed:
            5
        }
    }

    public static var currentDisplayOrder: [ThreadStatus] {
        [.active, .quotaBlocked, .waitingForConfirmation, .needsReview, .readyToClose]
    }
}
