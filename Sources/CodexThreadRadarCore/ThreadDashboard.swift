import Foundation

public struct ThreadRadarSummary: Equatable, Sendable {
    public let currentCount: Int
    public let quotaBlockedCount: Int
    public let needsReviewCount: Int
    public let waitingForConfirmationCount: Int
    public let readyToCloseCount: Int

    public init(records: [DevelopmentThread]) {
        let current = records.filter(\.isCurrent)
        currentCount = current.count
        quotaBlockedCount = current.filter { $0.status == .quotaBlocked }.count
        needsReviewCount = current.filter { $0.status == .needsReview }.count
        waitingForConfirmationCount = current.filter { $0.status == .waitingForConfirmation }.count
        readyToCloseCount = current.filter { $0.status == .readyToClose }.count
    }
}

public enum ThreadStatusFilter: String, CaseIterable, Identifiable, Sendable {
    case all
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
        case .all:
            "全部"
        case .active:
            ThreadStatus.active.label
        case .quotaBlocked:
            "卡住"
        case .waitingForConfirmation:
            ThreadStatus.waitingForConfirmation.label
        case .needsReview:
            ThreadStatus.needsReview.label
        case .readyToClose:
            "收口"
        case .closed:
            ThreadStatus.closed.label
        }
    }

    public func visibleThreads(from records: [DevelopmentThread]) -> [DevelopmentThread] {
        records
            .filter(matches)
            .sorted { lhs, rhs in
                if lhs.updatedAt != rhs.updatedAt {
                    return lhs.updatedAt > rhs.updatedAt
                }

                return lhs.title.localizedStandardCompare(rhs.title) == .orderedAscending
            }
    }

    private func matches(_ record: DevelopmentThread) -> Bool {
        switch self {
        case .all:
            record.isCurrent
        case .active:
            record.status == .active
        case .quotaBlocked:
            record.status == .quotaBlocked
        case .waitingForConfirmation:
            record.status == .waitingForConfirmation
        case .needsReview:
            record.status == .needsReview
        case .readyToClose:
            record.status == .readyToClose
        case .closed:
            record.status == .closed
        }
    }
}
