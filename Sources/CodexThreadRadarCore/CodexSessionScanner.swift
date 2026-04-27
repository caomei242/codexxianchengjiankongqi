import Foundation

public protocol CodexSessionScanning {
    func scan() throws -> [DevelopmentThreadDraft]
}

public struct CodexSessionScanner: CodexSessionScanning {
    private let indexURL: URL
    private let sessionsRootURL: URL
    private let logsDatabaseURL: URL
    private let lookback: TimeInterval
    private let activityWindow: TimeInterval
    private let maxSessions: Int
    private let now: () -> Date

    public init(
        indexURL: URL = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".codex")
            .appendingPathComponent("session_index.jsonl"),
        sessionsRootURL: URL = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".codex")
            .appendingPathComponent("sessions", isDirectory: true),
        logsDatabaseURL: URL = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".codex")
            .appendingPathComponent("logs_2.sqlite"),
        lookback: TimeInterval = 60 * 60 * 24 * 4,
        activityWindow: TimeInterval = 60 * 60 * 36,
        maxSessions: Int = 8,
        now: @escaping () -> Date = Date.init
    ) {
        self.indexURL = indexURL
        self.sessionsRootURL = sessionsRootURL
        self.logsDatabaseURL = logsDatabaseURL
        self.lookback = lookback
        self.activityWindow = activityWindow
        self.maxSessions = max(1, maxSessions)
        self.now = now
    }

    public func scan() throws -> [DevelopmentThreadDraft] {
        let metadataByID = try sessionMetadataByID()
        let activities = try recentThreadActivities(metadataByID: metadataByID)
        let sessionFiles = sessionFilesByID(for: Set(activities.map(\.id)))

        return activities.map { activity in
            let sessionURL = sessionFiles[activity.id]
            let cwd = sessionURL.flatMap(readWorkingDirectory)
            let tail = sessionURL.flatMap(readTail) ?? ""
            let status = status(for: activity, tail: tail)

            return DevelopmentThreadDraft(
                title: activity.threadName,
                projectName: projectName(from: cwd),
                goal: "继续推进 \(activity.threadName)",
                nextAction: nextAction(for: status),
                status: status,
                accountAlias: "",
                observedAt: activity.latestActivityAt
            )
        }
    }

    private func sessionMetadataByID() throws -> [String: SessionIndexEntry] {
        guard FileManager.default.fileExists(atPath: indexURL.path) else {
            return [:]
        }

        let body = try String(contentsOf: indexURL, encoding: .utf8)
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
                  !isAutomationThreadName(threadName)
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

        return latestByID
    }

    private func recentThreadActivities(metadataByID: [String: SessionIndexEntry]) throws -> [SessionActivity] {
        if let activities = try recentSubmittedActivities(metadataByID: metadataByID),
           !activities.isEmpty {
            return activities
        }

        return recentManualEntries(metadataByID: metadataByID).map { entry in
            SessionActivity(
                id: entry.id,
                threadName: entry.threadName,
                latestActivityAt: entry.updatedAt,
                latestState: .submitted,
                source: .fallbackIndex
            )
        }
    }

    private func recentSubmittedActivities(
        metadataByID: [String: SessionIndexEntry]
    ) throws -> [SessionActivity]? {
        guard FileManager.default.fileExists(atPath: logsDatabaseURL.path) else {
            return nil
        }

        let cutoffSeconds = Int(now().addingTimeInterval(-activityWindow).timeIntervalSince1970)
        let sql = """
        SELECT
            thread_id,
            MAX(CASE
                WHEN feedback_log_body LIKE '%submission_dispatch%'
                 AND feedback_log_body NOT LIKE '%op.dispatch.shutdown%'
                THEN ts * 1000000000 + ts_nanos
            END) AS latest_submission_key,
            MAX(CASE
                WHEN feedback_log_body LIKE '%phase: Some(FinalAnswer)%'
                  OR feedback_log_body LIKE '%"task_complete"%'
                  OR feedback_log_body LIKE '%"final_answer"%'
                THEN ts * 1000000000 + ts_nanos
            END) AS latest_completion_key
        FROM logs
        WHERE thread_id <> ''
          AND ts >= \(cutoffSeconds)
          AND feedback_log_body IS NOT NULL
          AND (
            feedback_log_body LIKE '%submission_dispatch%'
            OR feedback_log_body LIKE '%phase: Some(FinalAnswer)%'
            OR feedback_log_body LIKE '%"task_complete"%'
            OR feedback_log_body LIKE '%"final_answer"%'
          )
        GROUP BY thread_id
        HAVING latest_submission_key IS NOT NULL
        ORDER BY latest_submission_key DESC;
        """

        let rows = try runSQLiteJSONQuery(sql)

        return rows
            .sorted { lhs, rhs in
                if lhs.latestSubmissionKey != rhs.latestSubmissionKey {
                    return lhs.latestSubmissionKey > rhs.latestSubmissionKey
                }

                return lhs.threadID.localizedStandardCompare(rhs.threadID) == .orderedAscending
            }
            .compactMap { row in
                guard let metadata = metadataByID[row.threadID],
                      let latestActivityAt = row.latestActivityAt
                else {
                    return nil
                }

                return SessionActivity(
                    id: row.threadID,
                    threadName: metadata.threadName,
                    latestActivityAt: latestActivityAt,
                    latestState: row.latestState,
                    source: .submittedRecently
                )
            }
            .prefix(maxSessions)
            .map { $0 }
    }

    private func recentManualEntries(metadataByID: [String: SessionIndexEntry]) -> [SessionIndexEntry] {
        let cutoff = now().addingTimeInterval(-lookback)

        return metadataByID.values
            .filter { $0.updatedAt >= cutoff }
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

    private func status(for activity: SessionActivity, tail: String) -> ThreadStatus {
        let tailStatus = statusFromRecentTail(tail)

        if activity.source == .submittedRecently,
           tailStatus == .quotaBlocked {
            return .quotaBlocked
        }

        if activity.source == .submittedRecently {
            switch activity.latestState {
            case .completed:
                return .needsReview
            case .submitted:
                if tailStatus == .needsReview {
                    return .active
                }
                return tailStatus
            }
        }

        return tailStatus
    }

    private func statusFromRecentTail(_ tail: String) -> ThreadStatus {
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

    private func runSQLiteJSONQuery(_ sql: String) throws -> [SQLiteSubmissionRow] {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/sqlite3")
        process.arguments = ["-json", logsDatabaseURL.path, sql]

        let stdout = Pipe()
        let stderr = Pipe()
        process.standardOutput = stdout
        process.standardError = stderr

        try process.run()
        process.waitUntilExit()

        let outputData = stdout.fileHandleForReading.readDataToEndOfFile()
        let errorData = stderr.fileHandleForReading.readDataToEndOfFile()

        guard process.terminationStatus == 0 else {
            let stderrText = String(data: errorData, encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines) ?? "unknown sqlite error"
            throw CodexSessionScannerError.logQueryFailed(stderrText)
        }

        if outputData.isEmpty {
            return []
        }

        return try JSONDecoder().decode([SQLiteSubmissionRow].self, from: outputData)
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

public enum CodexSessionScannerError: LocalizedError {
    case logQueryFailed(String)

    public var errorDescription: String? {
        switch self {
        case .logQueryFailed(let message):
            "无法读取 Codex 本地日志：\(message)"
        }
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

private struct SessionActivity {
    let id: String
    let threadName: String
    let latestActivityAt: Date
    let latestState: ActivityState
    let source: ActivitySource
}

private enum ActivitySource {
    case submittedRecently
    case fallbackIndex
}

private enum ActivityState {
    case submitted
    case completed
}

private struct SQLiteSubmissionRow: Decodable {
    let threadID: String
    let latestSubmissionKey: Int64
    let latestCompletionKey: Int64?

    private enum CodingKeys: String, CodingKey {
        case threadID = "thread_id"
        case latestSubmissionKey = "latest_submission_key"
        case latestCompletionKey = "latest_completion_key"
    }

    var latestActivityAt: Date? {
        let key = max(latestSubmissionKey, latestCompletionKey ?? 0)
        guard key > 0 else {
            return nil
        }

        let seconds = TimeInterval(key / 1_000_000_000)
        let nanos = TimeInterval(key % 1_000_000_000) / 1_000_000_000
        return Date(timeIntervalSince1970: seconds + nanos)
    }

    var latestState: ActivityState {
        guard let latestCompletionKey, latestCompletionKey >= latestSubmissionKey else {
            return .submitted
        }

        return .completed
    }
}
