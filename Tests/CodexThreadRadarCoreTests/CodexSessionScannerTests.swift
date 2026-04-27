import Foundation
import Testing
@testable import CodexThreadRadarCore

struct CodexSessionScannerTests {
    @Test("scanner turns recent manual Codex sessions into thread drafts")
    func scansRecentManualSessions() throws {
        let fixture = try CodexSessionFixture()
        defer { fixture.remove() }

        let quotaID = "019dbd6c-c03f-7120-9d5e-6c9ce4e2d323"
        let doneID = "019dbd6f-fdb3-79b2-9c33-49fd301519de"
        let autoID = "019dbd71-8cf9-78b3-8253-a44dedf9b6e5"

        try fixture.writeIndexLines([
            SessionIndexFixtureLine(id: autoID, threadName: "个人日报--自动", updatedAt: "2026-04-24T03:03:48.83831Z"),
            SessionIndexFixtureLine(id: quotaID, threadName: "openclaw安装助手", updatedAt: "2026-04-24T02:59:02.282644Z"),
            SessionIndexFixtureLine(id: doneID, threadName: "codex开发线程监控器", updatedAt: "2026-04-24T03:04:23.15436Z"),
            SessionIndexFixtureLine(id: doneID, threadName: "codex线程监控器", updatedAt: "2026-04-24T04:41:34.020388Z"),
        ])

        try fixture.writeSession(
            id: quotaID,
            startedAt: "2026-04-24T10-58-34",
            cwd: "/Users/gd/Desktop/个人/个人--小开发",
            tailLines: [
                #"{"type":"event_msg","payload":{"type":"error","message":"You've hit your usage limit. To get more access now, try again later."}}"#,
            ]
        )
        try fixture.writeSession(
            id: doneID,
            startedAt: "2026-04-24T11-02-06",
            cwd: "/Users/gd/Desktop/个人/个人--小开发",
            tailLines: [
                #"{"type":"event_msg","payload":{"type":"task_complete"}}"#,
            ]
        )
        try fixture.writeSession(
            id: autoID,
            startedAt: "2026-04-24T11-03-48",
            cwd: "/Users/gd/Desktop/个人/日报",
            tailLines: []
        )

        let scanner = CodexSessionScanner(
            indexURL: fixture.indexURL,
            sessionsRootURL: fixture.sessionsRootURL,
            logsDatabaseURL: fixture.logsDatabaseURL,
            lookback: 60 * 60 * 24,
            maxSessions: 10,
            now: { Date(timeIntervalSince1970: 1_776_969_600) }
        )

        let drafts = try scanner.scan()

        #expect(drafts.map(\.title) == ["codex线程监控器", "openclaw安装助手"])
        #expect(drafts.map(\.projectName) == ["个人--小开发", "个人--小开发"])
        #expect(drafts.map(\.status) == [.needsReview, .quotaBlocked])
        #expect(drafts.first?.goal == "继续推进 codex线程监控器")
        #expect(drafts.last?.nextAction == "切换账号后回到这个线程，继续处理被额度中断的任务。")
    }

    @Test("scanner limits results to the newest manual sessions")
    func limitsToNewestManualSessions() throws {
        let fixture = try CodexSessionFixture()
        defer { fixture.remove() }

        try fixture.writeIndexLines([
            SessionIndexFixtureLine(id: "019dbd6c-c03f-7120-9d5e-6c9ce4e2d321", threadName: "线程 A", updatedAt: "2026-04-24T02:00:00Z"),
            SessionIndexFixtureLine(id: "019dbd6c-c03f-7120-9d5e-6c9ce4e2d322", threadName: "线程 B", updatedAt: "2026-04-24T03:00:00Z"),
            SessionIndexFixtureLine(id: "019dbd6c-c03f-7120-9d5e-6c9ce4e2d323", threadName: "线程 C", updatedAt: "2026-04-24T04:00:00Z"),
        ])

        for suffix in ["321", "322", "323"] {
            try fixture.writeSession(
                id: "019dbd6c-c03f-7120-9d5e-6c9ce4e2d\(suffix)",
                startedAt: "2026-04-24T11-00-00",
                cwd: "/tmp/Project\(suffix)",
                tailLines: []
            )
        }

        let scanner = CodexSessionScanner(
            indexURL: fixture.indexURL,
            sessionsRootURL: fixture.sessionsRootURL,
            logsDatabaseURL: fixture.logsDatabaseURL,
            lookback: 60 * 60 * 24,
            maxSessions: 2,
            now: { Date(timeIntervalSince1970: 1_776_969_600) }
        )

        let drafts = try scanner.scan()

        #expect(drafts.map(\.title) == ["线程 C", "线程 B"])
    }

    @Test("scanner excludes recurring automation sessions that are not marked with auto suffix")
    func excludesRecurringAutomationNamesWithoutSuffix() throws {
        let fixture = try CodexSessionFixture()
        defer { fixture.remove() }

        let dailySyncID = "019dbd6c-c03f-7120-9d5e-6c9ce4e2d331"
        let developmentID = "019dbd6c-c03f-7120-9d5e-6c9ce4e2d332"
        try fixture.writeIndexLines([
            SessionIndexFixtureLine(id: dailySyncID, threadName: "副业每日同步", updatedAt: "2026-04-24T04:00:00Z"),
            SessionIndexFixtureLine(id: developmentID, threadName: "自动转点数器", updatedAt: "2026-04-24T04:30:00Z"),
        ])

        try fixture.writeSession(
            id: dailySyncID,
            startedAt: "2026-04-24T12-00-00",
            cwd: "/Users/gd/Desktop/副业每日同步",
            tailLines: []
        )
        try fixture.writeSession(
            id: developmentID,
            startedAt: "2026-04-24T12-30-00",
            cwd: "/Users/gd/Desktop/个人/个人--小开发",
            tailLines: []
        )

        let scanner = CodexSessionScanner(
            indexURL: fixture.indexURL,
            sessionsRootURL: fixture.sessionsRootURL,
            logsDatabaseURL: fixture.logsDatabaseURL,
            lookback: 60 * 60 * 24,
            maxSessions: 10,
            now: { Date(timeIntervalSince1970: 1_776_969_600) }
        )

        let drafts = try scanner.scan()

        #expect(drafts.map(\.title) == ["自动转点数器"])
    }

    @Test("scanner treats a quota error as stale after later activity")
    func ignoresStaleQuotaErrorAfterLaterActivity() throws {
        let fixture = try CodexSessionFixture()
        defer { fixture.remove() }

        let id = "019dbd6c-c03f-7120-9d5e-6c9ce4e2d341"
        try fixture.writeIndexLines([
            SessionIndexFixtureLine(id: id, threadName: "codex线程监控器", updatedAt: "2026-04-24T04:30:00Z"),
        ])
        try fixture.writeSession(
            id: id,
            startedAt: "2026-04-24T12-30-00",
            cwd: "/Users/gd/Desktop/个人/个人--小开发",
            tailLines: [
                #"{"type":"event_msg","payload":{"type":"error","message":"You've hit your usage limit.","codex_error_info":"usage_limit_exceeded"}}"#,
                #"{"type":"event_msg","payload":{"type":"task_complete"}}"#,
                #"{"type":"event_msg","payload":{"type":"agent_message","message":"继续处理当前功能"}}"#,
                #"{"type":"response_item","payload":{"type":"function_call","name":"exec_command"}}"#,
            ]
        )

        let scanner = CodexSessionScanner(
            indexURL: fixture.indexURL,
            sessionsRootURL: fixture.sessionsRootURL,
            logsDatabaseURL: fixture.logsDatabaseURL,
            lookback: 60 * 60 * 24,
            maxSessions: 10,
            now: { Date(timeIntervalSince1970: 1_776_969_600) }
        )

        let drafts = try scanner.scan()

        #expect(drafts.first?.status == .active)
    }

    @Test("scanner prefers recently submitted threads and ignores resume-only sessions")
    func prefersRecentlySubmittedThreadsFromLogs() throws {
        let fixture = try CodexSessionFixture()
        defer { fixture.remove() }

        let currentA = "019dbd6f-fdb3-79b2-9c33-49fd301519de"
        let currentB = "019dc989-8f4e-7052-8d4b-dad444e1d0df"
        let resumeOnly = "019d8f4c-360c-7341-801f-e430069d10cd"
        let quotaOld = "019dbd6c-c03f-7120-9d5e-6c9ce4e2d323"

        try fixture.writeIndexLines([
            SessionIndexFixtureLine(id: currentA, threadName: "codex线程监控器", updatedAt: "2026-04-24T04:41:34Z"),
            SessionIndexFixtureLine(id: currentB, threadName: "录入助手", updatedAt: "2026-04-26T11:25:53Z"),
            SessionIndexFixtureLine(id: resumeOnly, threadName: "个人日志助手", updatedAt: "2026-04-27T12:30:49Z"),
            SessionIndexFixtureLine(id: quotaOld, threadName: "openclaw安装助手", updatedAt: "2026-04-24T02:59:02Z"),
        ])

        try fixture.writeSession(
            id: currentA,
            startedAt: "2026-04-24T11-02-06",
            cwd: "/Users/gd/Desktop/个人/个人--小开发",
            tailLines: [
                #"{"type":"event_msg","payload":{"type":"agent_message","message":"继续处理当前功能"}}"#,
            ]
        )
        try fixture.writeSession(
            id: currentB,
            startedAt: "2026-04-26T10-20-00",
            cwd: "/Users/gd/Desktop/主业--草莓客户管理系统",
            tailLines: [
                #"{"type":"event_msg","payload":{"type":"task_complete"}}"#,
            ]
        )
        try fixture.writeSession(
            id: resumeOnly,
            startedAt: "2026-04-27T11-30-00",
            cwd: "/Users/gd/Desktop/个人/个人日志",
            tailLines: []
        )
        try fixture.writeSession(
            id: quotaOld,
            startedAt: "2026-04-24T10-58-34",
            cwd: "/Users/gd/Desktop/个人/个人--小开发",
            tailLines: [
                #"{"type":"event_msg","payload":{"type":"error","message":"You've hit your usage limit. To get more access now, try again later."}}"#,
            ]
        )

        try fixture.createLogsDatabase()
        try fixture.insertLog(
            threadID: currentA,
            timestamp: 1_777_255_760,
            body: #"session_loop{thread_id=019dbd6f-fdb3-79b2-9c33-49fd301519de}:submission_dispatch{otel.name="op.dispatch.user_input_with_turn_context"}"#
        )
        try fixture.insertLog(
            threadID: currentB,
            timestamp: 1_777_248_160,
            body: #"session_loop{thread_id=019dc989-8f4e-7052-8d4b-dad444e1d0df}:submission_dispatch{otel.name="op.dispatch.user_input_with_turn_context"}"#
        )
        try fixture.insertLog(
            threadID: currentB,
            timestamp: 1_777_248_180,
            body: #"session_loop{thread_id=019dc989-8f4e-7052-8d4b-dad444e1d0df}: Output item item=Message { role: "assistant", content: [], end_turn: None, phase: Some(FinalAnswer) }"#
        )
        try fixture.insertLog(
            threadID: resumeOnly,
            timestamp: 1_777_254_649,
            body: #"app_server.request{otel.name="thread/resume" rpc.method="thread/resume"}"#
        )
        try fixture.insertLog(
            threadID: quotaOld,
            timestamp: 1_777_000_000,
            body: #"session_loop{thread_id=019dbd6c-c03f-7120-9d5e-6c9ce4e2d323}:submission_dispatch{otel.name="op.dispatch.user_input_with_turn_context"}"#
        )

        let scanner = CodexSessionScanner(
            indexURL: fixture.indexURL,
            sessionsRootURL: fixture.sessionsRootURL,
            logsDatabaseURL: fixture.logsDatabaseURL,
            activityWindow: 60 * 60 * 36,
            maxSessions: 10,
            now: { Date(timeIntervalSince1970: 1_777_257_600) }
        )

        let drafts = try scanner.scan()

        #expect(drafts.map(\.title) == ["codex线程监控器", "录入助手"])
        #expect(drafts.map(\.projectName) == ["个人--小开发", "主业--草莓客户管理系统"])
        #expect(drafts.map(\.status) == [.active, .needsReview])
    }

    @Test("scanner marks a recently completed thread as needs review from Codex logs")
    func marksRecentlyCompletedThreadFromLogs() throws {
        let fixture = try CodexSessionFixture()
        defer { fixture.remove() }

        let completedID = "019dccc9-a5ea-7a20-9720-bd39a0169b76"
        try fixture.writeIndexLines([
            SessionIndexFixtureLine(id: completedID, threadName: "录入助手", updatedAt: "2026-04-27T10:36:50Z"),
        ])
        try fixture.writeSession(
            id: completedID,
            startedAt: "2026-04-27T10-20-00",
            cwd: "/Users/gd/Desktop/主业--草莓客户管理系统",
            tailLines: [
                #"{"type":"event_msg","payload":{"type":"agent_message","message":"这里还是旧尾巴"}}"#,
            ]
        )

        try fixture.createLogsDatabase()
        try fixture.insertLog(
            threadID: completedID,
            timestamp: 1_777_257_600,
            body: #"session_loop{thread_id=019dccc9-a5ea-7a20-9720-bd39a0169b76}:submission_dispatch{otel.name="op.dispatch.user_input_with_turn_context" submission.id="turn-1"}"#
        )
        try fixture.insertLog(
            threadID: completedID,
            timestamp: 1_777_257_620,
            body: #"session_loop{thread_id=019dccc9-a5ea-7a20-9720-bd39a0169b76}: Output item item=Message { role: "assistant", content: [], end_turn: None, phase: Some(FinalAnswer) }"#
        )

        let scanner = CodexSessionScanner(
            indexURL: fixture.indexURL,
            sessionsRootURL: fixture.sessionsRootURL,
            logsDatabaseURL: fixture.logsDatabaseURL,
            activityWindow: 60 * 60 * 36,
            maxSessions: 10,
            now: { Date(timeIntervalSince1970: 1_777_257_700) }
        )

        let drafts = try scanner.scan()

        #expect(drafts.first?.status == .needsReview)
    }
}

private struct CodexSessionFixture {
    let rootURL: URL
    let indexURL: URL
    let sessionsRootURL: URL
    let logsDatabaseURL: URL

    init() throws {
        rootURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("CodexSessionScannerTests-\(UUID().uuidString)", isDirectory: true)
        indexURL = rootURL.appendingPathComponent("session_index.jsonl")
        sessionsRootURL = rootURL.appendingPathComponent("sessions", isDirectory: true)
        logsDatabaseURL = rootURL.appendingPathComponent("logs_2.sqlite")
        try FileManager.default.createDirectory(at: sessionsRootURL, withIntermediateDirectories: true)
    }

    func remove() {
        try? FileManager.default.removeItem(at: rootURL)
    }

    func writeIndexLines(_ lines: [SessionIndexFixtureLine]) throws {
        let body = lines.map(\.json).joined(separator: "\n") + "\n"
        guard let data = body.data(using: .utf8) else {
            return
        }
        try data.write(to: indexURL)
    }

    func writeSession(id: String, startedAt: String, cwd: String, tailLines: [String]) throws {
        let dayURL = sessionsRootURL
            .appendingPathComponent("2026", isDirectory: true)
            .appendingPathComponent("04", isDirectory: true)
            .appendingPathComponent("24", isDirectory: true)
        try FileManager.default.createDirectory(at: dayURL, withIntermediateDirectories: true)

        let sessionURL = dayURL.appendingPathComponent("rollout-\(startedAt)-\(id).jsonl")
        var lines = [
            #"{"type":"session_meta","payload":{"id":"\#(id)","cwd":"\#(cwd)"}}"#,
        ]
        lines.append(contentsOf: tailLines)
        let body = lines.joined(separator: "\n") + "\n"
        guard let data = body.data(using: .utf8) else {
            return
        }
        try data.write(to: sessionURL)
    }

    func createLogsDatabase() throws {
        try runSQLite(
            """
            CREATE TABLE logs (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                ts INTEGER NOT NULL,
                ts_nanos INTEGER NOT NULL,
                level TEXT NOT NULL,
                target TEXT NOT NULL,
                feedback_log_body TEXT,
                module_path TEXT,
                file TEXT,
                line INTEGER,
                thread_id TEXT,
                process_uuid TEXT,
                estimated_bytes INTEGER NOT NULL DEFAULT 0
            );
            """
        )
    }

    func insertLog(threadID: String, timestamp: Int, body: String, nanos: Int = 0) throws {
        let escapedBody = body.replacingOccurrences(of: "'", with: "''")
        let escapedThreadID = threadID.replacingOccurrences(of: "'", with: "''")
        try runSQLite(
            """
            INSERT INTO logs (
                ts,
                ts_nanos,
                level,
                target,
                feedback_log_body,
                module_path,
                file,
                line,
                thread_id,
                process_uuid,
                estimated_bytes
            ) VALUES (
                \(timestamp),
                \(nanos),
                'INFO',
                'log',
                '\(escapedBody)',
                '',
                '',
                0,
                '\(escapedThreadID)',
                'test-process',
                0
            );
            """
        )
    }

    private func runSQLite(_ sql: String) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/sqlite3")
        process.arguments = [logsDatabaseURL.path, sql]

        let stderr = Pipe()
        process.standardError = stderr

        try process.run()
        process.waitUntilExit()

        guard process.terminationStatus == 0 else {
            let errorData = stderr.fileHandleForReading.readDataToEndOfFile()
            let errorText = String(data: errorData, encoding: .utf8) ?? "sqlite test command failed"
            throw FixtureError.sqlite(errorText)
        }
    }
}

private struct SessionIndexFixtureLine {
    let id: String
    let threadName: String
    let updatedAt: String

    var json: String {
        #"{"id":"\#(id)","thread_name":"\#(threadName)","updated_at":"\#(updatedAt)"}"#
    }
}

private enum FixtureError: Error {
    case sqlite(String)
}
