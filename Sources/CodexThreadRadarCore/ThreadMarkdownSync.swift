import Foundation

public protocol ThreadMarkdownSyncing {
    func sync(records: [DevelopmentThread], generatedAt: Date) throws
}

public struct ThreadMarkdownSync: ThreadMarkdownSyncing {
    private let directoryURL: URL
    private let fileManager: FileManager

    public init(
        directoryURL: URL? = nil,
        fileManager: FileManager = .default
    ) {
        self.directoryURL = directoryURL ?? ThreadMarkdownSync.defaultDirectoryURL(fileManager: fileManager)
        self.fileManager = fileManager
    }

    public func sync(records: [DevelopmentThread], generatedAt: Date) throws {
        try fileManager.createDirectory(at: directoryURL, withIntermediateDirectories: true)

        let currentURL = directoryURL.appendingPathComponent("当前开发线程.md")
        let currentMarkdown = ThreadMarkdownRenderer.renderCurrentThreads(
            records: records,
            generatedAt: generatedAt
        )
        try currentMarkdown.write(to: currentURL, atomically: true, encoding: .utf8)
    }

    public static func defaultDirectoryURL(fileManager: FileManager = .default) -> URL {
        fileManager.homeDirectoryForCurrentUser
            .appendingPathComponent("Library", isDirectory: true)
            .appendingPathComponent("Mobile Documents", isDirectory: true)
            .appendingPathComponent("iCloud~md~obsidian", isDirectory: true)
            .appendingPathComponent("Documents", isDirectory: true)
            .appendingPathComponent("个人日志", isDirectory: true)
            .appendingPathComponent("线程手册", isDirectory: true)
            .appendingPathComponent("Codex线程工作台", isDirectory: true)
    }
}
