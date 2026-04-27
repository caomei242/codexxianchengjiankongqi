import AppKit
import CodexThreadRadarCore
import SwiftUI

struct ContentView: View {
    @Bindable var store: ThreadRadarStore
    @State private var editorMode: ThreadEditorMode?
    @State private var selectedThreadID: DevelopmentThread.ID?

    var body: some View {
        NavigationSplitView {
            sidebar
        } detail: {
            detail
        }
        .sheet(item: $editorMode) { mode in
            ThreadEditorSheet(mode: mode, store: store)
        }
        .onReceive(NotificationCenter.default.publisher(for: .showCreateThreadSheet)) { _ in
            editorMode = .create
        }
    }

    private var sidebar: some View {
        VStack(spacing: 0) {
            summaryHeader
                .padding(.horizontal, 16)
                .padding(.vertical, 14)

            List(selection: $store.selectedFilter) {
                ForEach(ThreadStatusFilter.allCases.filter { $0 != .closed }) { filter in
                    Label(filter.label, systemImage: systemImage(for: filter))
                        .tag(filter)
                }
            }
            .listStyle(.sidebar)
        }
        .frame(minWidth: 220)
    }

    private var summaryHeader: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("codex线程监控器")
                .font(.headline)

            Text("只看未收口的开发线程和下一步。")
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack(spacing: 8) {
                SummaryPill(title: "\(store.summary.currentCount)", subtitle: "当前")
                SummaryPill(title: "\(store.summary.quotaBlockedCount)", subtitle: "卡额度")
                SummaryPill(title: "\(store.summary.needsReviewCount)", subtitle: "待验收")
            }
        }
    }

    private var detail: some View {
        VStack(spacing: 0) {
            toolbar

            if store.visibleThreads.isEmpty {
                emptyState
            } else {
                ScrollView {
                    LazyVStack(spacing: 10) {
                        ForEach(store.visibleThreads) { thread in
                            ThreadRow(
                                thread: thread,
                                onEdit: { editorMode = .edit(thread) },
                                onCopy: { copyResumePrompt(for: thread) },
                                onClose: { store.closeThread(id: thread.id) },
                                onStatusChange: { store.updateStatus(id: thread.id, status: $0) }
                            )
                        }
                    }
                    .padding(18)
                }
            }
        }
        .navigationTitle(store.selectedFilter.label)
    }

    private var toolbar: some View {
        VStack(spacing: 12) {
            HStack(spacing: 10) {
                TextField("搜索线程、项目、目标或下一步", text: $store.searchText)
                    .textFieldStyle(.roundedBorder)

                Button {
                    store.refreshFromCodexSessions()
                } label: {
                    Label("记录当前线程状态", systemImage: "arrow.clockwise.circle.fill")
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut("t", modifiers: [.command, .shift])

                Button {
                    editorMode = .create
                } label: {
                    Image(systemName: "plus")
                }
                .buttonStyle(.bordered)
                .help("手动新增线程")
            }

            HStack {
                Label("⌘⇧T 记录 · ⌘⇧R 复制首条续接", systemImage: "keyboard")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Spacer()

                if let errorMessage = store.errorMessage {
                    Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }
        }
        .padding(18)
        .background(.bar)
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "dot.radiowaves.left.and.right")
                .font(.system(size: 42, weight: .semibold))
                .foregroundStyle(.secondary)

            Text("没有未收口线程")
                .font(.title3.weight(.semibold))

            Text("点击记录后，会从本机 Codex 会话生成当前开发线程列表。")
                .font(.callout)
                .foregroundStyle(.secondary)

            Button {
                store.refreshFromCodexSessions()
            } label: {
                Label("记录当前线程状态", systemImage: "arrow.clockwise.circle.fill")
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func copyResumePrompt(for thread: DevelopmentThread) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(store.resumePrompt(for: thread), forType: .string)
    }

    private func systemImage(for filter: ThreadStatusFilter) -> String {
        switch filter {
        case .all:
            "square.stack.3d.up"
        case .active:
            "play.circle.fill"
        case .quotaBlocked:
            "exclamationmark.octagon.fill"
        case .waitingForConfirmation:
            "person.crop.circle.badge.questionmark"
        case .needsReview:
            "checkmark.seal.fill"
        case .readyToClose:
            "tray.and.arrow.down.fill"
        case .closed:
            "archivebox.fill"
        }
    }
}

private struct SummaryPill: View {
    let title: String
    let subtitle: String

    var body: some View {
        VStack(spacing: 2) {
            Text(title)
                .font(.headline)
            Text(subtitle)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 7)
        .background(.quaternary, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}
