import Foundation
import Observation

@MainActor
@Observable
public final class ThreadRadarStore {
    public var records: [DevelopmentThread]
    public var selectedFilter: ThreadStatusFilter = .all
    public var searchText = ""
    public var errorMessage: String?

    private let repository: any ThreadRepository
    private let markdownSync: (any ThreadMarkdownSyncing)?
    private let now: () -> Date

    public init(
        repository: any ThreadRepository = JSONThreadRepository(),
        markdownSync: (any ThreadMarkdownSyncing)? = ThreadMarkdownSync(),
        now: @escaping () -> Date = Date.init
    ) {
        self.repository = repository
        self.markdownSync = markdownSync
        self.now = now

        do {
            records = try repository.load()
            errorMessage = nil
        } catch {
            records = []
            errorMessage = "无法读取线程记录：\(error.localizedDescription)"
        }
    }

    public var summary: ThreadRadarSummary {
        ThreadRadarSummary(records: records)
    }

    public var visibleThreads: [DevelopmentThread] {
        let filtered = selectedFilter.visibleThreads(from: records)
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !query.isEmpty else {
            return filtered
        }

        return filtered.filter { record in
            record.title.localizedCaseInsensitiveContains(query) ||
                record.projectName.localizedCaseInsensitiveContains(query) ||
                record.goal.localizedCaseInsensitiveContains(query) ||
                record.nextAction.localizedCaseInsensitiveContains(query)
        }
    }

    public var firstVisibleThread: DevelopmentThread? {
        visibleThreads.first
    }

    public func createThread(from draft: DevelopmentThreadDraft) {
        guard draft.canSave else {
            errorMessage = "线程标题、项目、目标和下一步都不能为空。"
            return
        }

        let timestamp = now()
        records.append(draft.makeThread(now: timestamp))
        persist(generatedAt: timestamp)
    }

    @discardableResult
    public func refreshFromCodexSessions(
        scanner: any CodexSessionScanning = CodexSessionScanner()
    ) -> Int {
        do {
            let timestamp = now()
            let scannedThreads = try scanner.scan()
                .filter(\.canSave)
                .enumerated()
                .map { offset, draft in
                    let orderedTimestamp = timestamp.addingTimeInterval(-Double(offset))
                    return draft.makeThread(now: orderedTimestamp)
                }

            guard !scannedThreads.isEmpty else {
                errorMessage = "没有扫描到当前 Codex 线程。"
                return 0
            }

            let closedThreads = records.filter { $0.status == .closed }

            records = closedThreads + scannedThreads
            persist(generatedAt: timestamp)

            return scannedThreads.count
        } catch {
            errorMessage = "无法扫描 Codex 线程：\(error.localizedDescription)"
            return 0
        }
    }

    public func updateThread(id: UUID, from draft: DevelopmentThreadDraft) {
        guard draft.canSave else {
            errorMessage = "线程标题、项目、目标和下一步都不能为空。"
            return
        }

        guard let index = records.firstIndex(where: { $0.id == id }) else {
            errorMessage = "找不到要更新的线程。"
            return
        }

        let timestamp = now()
        records[index] = draft.updating(records[index], now: timestamp)
        persist(generatedAt: timestamp)
    }

    public func updateStatus(id: UUID, status: ThreadStatus) {
        guard let index = records.firstIndex(where: { $0.id == id }) else {
            errorMessage = "找不到要更新状态的线程。"
            return
        }

        let timestamp = now()
        records[index].status = status
        records[index].updatedAt = timestamp
        records[index].closedAt = status == .closed ? (records[index].closedAt ?? timestamp) : nil
        persist(generatedAt: timestamp)
    }

    public func closeThread(id: UUID) {
        updateStatus(id: id, status: .closed)
    }

    public func resumePrompt(for thread: DevelopmentThread) -> String {
        ThreadResumePromptFormatter.prompt(for: thread)
    }

    private func persist(generatedAt: Date) {
        do {
            try repository.save(records)
            try markdownSync?.sync(records: records, generatedAt: generatedAt)
            errorMessage = nil
        } catch {
            errorMessage = "无法保存线程记录：\(error.localizedDescription)"
        }
    }
}
