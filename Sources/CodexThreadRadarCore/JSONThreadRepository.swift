import Foundation

public protocol ThreadRepository {
    func load() throws -> [DevelopmentThread]
    func save(_ records: [DevelopmentThread]) throws
}

public struct JSONThreadRepository: ThreadRepository {
    private let storageURL: URL
    private let fileManager: FileManager
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    public init(
        storageURL: URL? = nil,
        fileManager: FileManager = .default
    ) {
        self.storageURL = storageURL ?? JSONThreadRepository.defaultStorageURL(fileManager: fileManager)
        self.fileManager = fileManager

        encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]

        decoder = JSONDecoder()
    }

    public func load() throws -> [DevelopmentThread] {
        guard fileManager.fileExists(atPath: storageURL.path) else {
            return []
        }

        let data = try Data(contentsOf: storageURL)
        return try decoder.decode([DevelopmentThread].self, from: data)
    }

    public func save(_ records: [DevelopmentThread]) throws {
        let directoryURL = storageURL.deletingLastPathComponent()
        try fileManager.createDirectory(at: directoryURL, withIntermediateDirectories: true)

        let data = try encoder.encode(records)
        try data.write(to: storageURL, options: .atomic)
    }

    public static func defaultStorageURL(fileManager: FileManager = .default) -> URL {
        let baseURL = (try? fileManager.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )) ?? fileManager.homeDirectoryForCurrentUser

        return baseURL
            .appendingPathComponent("CodexThreadRadar", isDirectory: true)
            .appendingPathComponent("threads.json")
    }
}
