import AppKit
import CodexThreadRadarCore
import SwiftUI

struct RadarMenuView: View {
    @Bindable var store: ThreadRadarStore
    @Environment(\.openWindow) private var openWindow
    @State private var editorMode: ThreadEditorMode?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            filterBar

            Divider()

            if store.visibleThreads.isEmpty {
                compactEmptyState
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 12) {
                        ForEach(store.visibleProjectSections, id: \.projectName) { section in
                            VStack(alignment: .leading, spacing: 8) {
                                HStack(spacing: 8) {
                                    Label(section.projectName, systemImage: "folder.fill")
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(.secondary)
                                        .lineLimit(1)

                                    Text("\(section.threads.count)")
                                        .font(.caption2.weight(.semibold))
                                        .foregroundStyle(.secondary)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 3)
                                        .background(.quaternary, in: Capsule())
                                }

                                LazyVStack(spacing: 8) {
                                    ForEach(section.threads) { thread in
                                        CompactThreadRow(
                                            thread: thread,
                                            onEdit: { editorMode = .edit(thread) },
                                            onCopy: { copyResumePrompt(for: thread) },
                                            onClose: { store.closeThread(id: thread.id) }
                                        )
                                    }
                                }
                            }
                        }
                    }
                    .padding(12)
                }
            }

            Divider()
            footer
        }
        .sheet(item: $editorMode) { mode in
            ThreadEditorSheet(mode: mode, store: store)
        }
        .onReceive(NotificationCenter.default.publisher(for: .showCreateThreadSheet)) { _ in
            editorMode = .create
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("codex线程监控器")
                        .font(.headline)
                    Text("当前 \(store.summary.currentCount) 条开发线程")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Button {
                    store.refreshFromCodexSessions()
                } label: {
                    Image(systemName: "arrow.clockwise.circle.fill")
                }
                .buttonStyle(.borderedProminent)
                .help("记录当前线程状态")

                Button {
                    editorMode = .create
                } label: {
                    Image(systemName: "plus")
                }
                .buttonStyle(.bordered)
                .help("手动新增线程")
            }

            HStack(spacing: 8) {
                Badge(text: "\(store.summary.quotaBlockedCount) 条卡额度", color: .orange)
                Badge(text: "\(store.summary.needsReviewCount) 条待验收", color: .green)
            }
        }
        .padding(14)
    }

    private var filterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(ThreadStatusFilter.allCases.filter { $0 != .closed }) { filter in
                    Button(filter.label) {
                        store.selectedFilter = filter
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .tint(store.selectedFilter == filter ? .blue : .secondary)
                }
            }
            .padding(.horizontal, 14)
            .padding(.bottom, 12)
        }
    }

    private var compactEmptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "checkmark.circle")
                .font(.system(size: 32))
                .foregroundStyle(.secondary)
            Text("当前没有未收口线程")
                .font(.callout.weight(.semibold))
            Button("记录当前线程状态") {
                store.refreshFromCodexSessions()
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(32)
    }

    private var footer: some View {
            HStack {
            Label("⌘⇧T 记录 · ⌘⇧R 复制首条", systemImage: "keyboard")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Spacer()

                Button("打开工作台") {
                    openWindow(id: "main")
                    NSApp.activate(ignoringOtherApps: true)
                }
                .buttonStyle(.plain)

                Button("退出") {
                    NSApp.terminate(nil)
                }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
        }
        .padding(12)
    }

    private func copyResumePrompt(for thread: DevelopmentThread) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(store.resumePrompt(for: thread), forType: .string)
    }
}

private struct Badge: View {
    let text: String
    let color: Color

    var body: some View {
        Text(text)
            .font(.caption.weight(.semibold))
            .foregroundStyle(color)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(color.opacity(0.12), in: RoundedRectangle(cornerRadius: 7, style: .continuous))
    }
}
