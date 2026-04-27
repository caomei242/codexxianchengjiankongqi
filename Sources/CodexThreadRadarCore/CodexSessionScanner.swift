import Foundation

public protocol CodexSessionScanning {
    func scan() throws -> [DevelopmentThreadDraft]
}

public struct CodexSessionScanner: CodexSessionScanning {
    private let indexURL: URL
    private let sessionsRootURL: URL
    private let lookback: TimeInterval
    private let maxSessions: Int
    private let now: () -> Date

    public init(
        indexURL: URL = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".codex")
            .appendingPathComponent("session_index.jsonl"),
        sessionsRootURL: URL = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".codex")
            .appendingPathComponent("sessions", isDirectory: true),
        lookback: TimeInterval = 60 * 60 * 24 * 4,
        maxSessions: Int = 8,
        now: @escaping () -> Date = Date.init
    ) {
        self.indexURL = indexURL
        self.sessionsRootURL = sessionsRootURL
        self.lookback = lookback
        self.maxSessions = max(1, maxSessions)
        self.now = now
    }

    public func scan() throws -> [DevelopmentThreadDraft] {
        let entries = try recentManualEntries()
        let sessionFiles = sessionFilesByID(for: Set(entries.map(\.id)))

        return entries.map { entry in
            let sessionURL = sessionFiles[entry.id]
            let cwd = sessionURL.flatMap(readWorkingDirectory)
            let tail = sessionURL.flatMap(readTail) ?? ""
            let status = status(fromTail: tail)

            return DevelopmentThreadDraft(
                title: entry.threadName,
                projectName: projectName(from: cwd),
                goal: "继续推进 \(entry.threadName)",
                nextAction: nextAction(for: status),
                status: status,
                accountAlias: ""
            )
        }
    }

    private func recentManualEntries() throws -> [SessionIndexEntry] {
        guard FileManager.default.fileExists(atPath: indexURL.path) else {
            return []
        }

        let body = try String(contentsOf: indexURL, encoding: .utf8)
        let cutoff = now().addingTimeInterval(-lookback)
        var latestByID: [String: SessionIndexEntry] = [:]

        for line in body.split(whereSeparator: \.isNewline) {
            guard let data = String(line).data(using: .utf8),
                  let rawEntry = try? JSONDecoder().decode(RawSessionIndexEntry.self, from: data),
                  let updatedAt = Self.parseDate(rawEntry.updatedAt)
            else {
                continue
            }

            let threadName = rawEntry.threadName.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !threadName.isEmpty,
                  !isAutomationThreadName(threadName),
                  updatedAt >= cutoff
            else {
                continue
            }

            let entry = SessionIndexEntry(
                id: rawEntry.id,
                threadName: threadName,
                updatedAt: updatedAt
            )

            if let existing = latestByID[entry.id], existing.updatedAt >= entry.updatedAt {
                continue
            }

            latestByID[entry.id] = entry
        }

        return latestByID.values
            .sorted { lhs, rhs in
                if lhs.updatedAt != rhs.updatedAt {
                    return lhs.updatedAt > rhs.updatedAt
                }

                return lhs.threadName.localizedStandardCompare(rhs.threadName) == .orderedAscending
            }
            .prefix(maxSessions)
            .map { $0 }
    }

    private func sessionFilesByID(for ids: Set<String>) -> [String: URL] {
        guard !ids.isEmpty,
              let enumerator = FileManager.default.enumerator(
                at: sessionsRootURL,
                includingPropertiesForKeys: [.isRegularFileKey],
                options: [.skipsHiddenFiles]
              )
        else {
            return [:]
        }

        var remainingIDs = ids
        var files: [String: URL] = [:]

        for case let url as URL in enumerator {
            guard url.pathExtension == "jsonl" else {
                continue
            }

            let fileName = url.lastPathComponent
            for id in remainingIDs where fileName.contains(id) {
                files[id] = url
                remainingIDs.remove(id)
                break
            }

            if remainingIDs.isEmpty {
                break
            }
        }

        return files
    }

    private func readWorkingDirectory(from sessionURL: URL) -> String? {
        guard let handle = try? FileHandle(forReadingFrom: sessionURL) else {
            return nil
        }
        defer { try? handle.close() }

        guard let data = try? handle.read(upToCount: 64 * 1024),
              let body = String(data: data, encoding: .utf8)
        else {
            return nil
        }

        for line in body.split(whereSeparator: \.isNewline) {
            guard line.contains(#""session_meta""#),
                  let data = String(line).data(using: .utf8),
                  let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let payload = object["payload"] as? [String: Any],
                  let cwd = payload["cwd"] as? String
            else {
                continue
            }

            let trimmed = cwd.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? nil : trimmed
        }

        return nil
    }

    private func readTail(from sessionURL: URL) -> String? {
        guard let handle = try? FileHandle(forReadingFrom: sessionURL) else {
            return nil
        }
        defer { try? handle.close() }

        guard let size = try? handle.seekToEnd() else {
            return nil
        }

        let tailSize: UInt64 = 256 * 1024
        let offset = size > tailSize ? size - tailSize : 0
        try? handle.seek(toOffset: offset)

        guard let data = try? handle.readToEnd(),
              let body = String(data: data, encoding: .utf8)
        else {
            return nil
        }

        return body
    }

    private func status(fromTail tail: String) -> ThreadStatus {
        var sawCompletion = false

        for line in tail.split(whereSeparator: \.isNewline).reversed() {
            let lowercased = line.lowercased()

            if isActiveEvent(line: lowercased) {
                return .active
            }

            if isQuotaError(line: lowercased) {
                return .quotaBlocked
            }

            if isCompletionEvent(line: lowercased) {
                sawCompletion = true
            }
        }

        if sawCompletion {
            return .needsReview
        }

        return .active
    }

    private func isActiveEvent(line: String) -> Bool {
        line.contains(#""function_call""#) ||
            line.contains(#""agent_message""#) ||
            line.contains(#""user_message""#)
    }

    private func isQuotaError(line: String) -> Bool {
        line.contains(#""type":"error""#) &&
            (line.contains("usage_limit_exceeded") ||
                line.contains("hit your usage limit") ||
                line.contains("usage limit") ||
                line.contains("rate_limit"))
    }

    private func isCompletionEvent(line: String) -> Bool {
        line.contains(#""task_complete""#) ||
            line.contains(#""final_answer""#)
    }

    private func projectName(from cwd: String?) -> String {
        guard let cwd,
              let lastComponent = cwd.split(separator: "/").last
        else {
            return "Codex"
        }

        let projectName = String(lastComponent).trimmingCharacters(in: .whitespacesAndNewlines)
        return projectName.isEmpty ? "Codex" : projectName
    }

    private func nextAction(for status: ThreadStatus) -> String {
        switch status {
        case .quotaBlocked:
            "切换账号后回到这个线程，继续处理被额度中断的任务。"
        case .needsReview:
            "回到线程确认最后结果，决定收口或继续。"
        case .waitingForConfirmation:
            "回到线程补充确认信息，让任务继续推进。"
        case .readyToClose:
            "检查交付结果，确认后收口归档。"
        case .closed:
            "已收口，无需继续处理。"
        case .active:
            "回到线程查看当前输出，并继续推进。"
        }
    }

    private func isAutomationThreadName(_ threadName: String) -> Bool {
        if threadName.localizedCaseInsensitiveContains("--自动") {
            return true
        }

        let recurringWorkflowMarkers = [
            "每日同步",
            "日报",
            "周报",
            "采集",
        ]

        return recurringWorkflowMarkers.contains { marker in
            threadName.localizedCaseInsensitiveContains(marker)
        }
    }

    private static func parseDate(_ rawValue: String) -> Date? {
        let fractionalFormatter = ISO8601DateFormatter()
        fractionalFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = fractionalFormatter.date(from: rawValue) {
            return date
        }

        let plainFormatter = ISO8601DateFormatter()
        plainFormatter.formatOptions = [.withInternetDateTime]
        return plainFormatter.date(from: rawValue)
    }
}

private struct RawSessionIndexEntry: Decodable {
    let id: String
    let threadName: String
    let updatedAt: String

    private enum CodingKeys: String, CodingKey {
        case id
        case threadName = "thread_name"
        case updatedAt = "updated_at"
    }
}

private struct SessionIndexEntry {
    let id: String
    let threadName: String
    let updatedAt: Date
}
