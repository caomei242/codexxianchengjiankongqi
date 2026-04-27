import Foundation

public struct ThreadProjectSection: Equatable, Sendable {
    public let projectName: String
    public let threads: [DevelopmentThread]
    public let latestUpdatedAt: Date

    public init(projectName: String, threads: [DevelopmentThread], latestUpdatedAt: Date) {
        self.projectName = projectName
        self.threads = threads
        self.latestUpdatedAt = latestUpdatedAt
    }

    public static func makeSections(from threads: [DevelopmentThread]) -> [ThreadProjectSection] {
        let grouped = Dictionary(grouping: threads, by: \.projectName)

        return grouped.map { projectName, groupedThreads in
            let sortedThreads = groupedThreads.sorted { lhs, rhs in
                if lhs.updatedAt != rhs.updatedAt {
                    return lhs.updatedAt > rhs.updatedAt
                }

                return lhs.title.localizedStandardCompare(rhs.title) == .orderedAscending
            }

            return ThreadProjectSection(
                projectName: projectName,
                threads: sortedThreads,
                latestUpdatedAt: sortedThreads.first?.updatedAt ?? .distantPast
            )
        }
        .sorted { lhs, rhs in
            if lhs.latestUpdatedAt != rhs.latestUpdatedAt {
                return lhs.latestUpdatedAt > rhs.latestUpdatedAt
            }

            return lhs.projectName.localizedStandardCompare(rhs.projectName) == .orderedAscending
        }
    }
}
