import CodexThreadRadarCore
import SwiftUI

enum ThreadEditorMode: Identifiable {
    case create
    case edit(DevelopmentThread)

    var id: String {
        switch self {
        case .create:
            "create"
        case let .edit(thread):
            thread.id.uuidString
        }
    }

    var title: String {
        switch self {
        case .create:
            "捕获当前线程"
        case .edit:
            "更新线程"
        }
    }
}

struct ThreadEditorSheet: View {
    let mode: ThreadEditorMode
    @Bindable var store: ThreadRadarStore
    @Environment(\.dismiss) private var dismiss
    @State private var draft: DevelopmentThreadDraft

    init(mode: ThreadEditorMode, store: ThreadRadarStore) {
        self.mode = mode
        self.store = store

        switch mode {
        case .create:
            _draft = State(initialValue: DevelopmentThreadDraft(projectName: "个人--小开发"))
        case let .edit(thread):
            _draft = State(initialValue: DevelopmentThreadDraft(thread: thread))
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text(mode.title)
                .font(.title2.weight(.semibold))

            Form {
                TextField("线程名，例如 openclaw 安装助手", text: $draft.title)
                TextField("项目名", text: $draft.projectName)
                TextField("目标", text: $draft.goal, axis: .vertical)
                    .lineLimit(2...3)
                TextField("下一步", text: $draft.nextAction, axis: .vertical)
                    .lineLimit(2...3)

                Picker("状态", selection: $draft.status) {
                    ForEach(ThreadStatus.currentDisplayOrder) { status in
                        Text(status.label).tag(status)
                    }
                }
                .pickerStyle(.segmented)

                TextField("关联账号别名（可选，不做账号管理）", text: $draft.accountAlias)
            }
            .formStyle(.grouped)

            HStack {
                Label("核心是写清楚下一步，切号回来能直接续上。", systemImage: "lightbulb")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Spacer()

                Button("取消") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)

                Button(primaryButtonTitle) {
                    save()
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
                .disabled(!draft.canSave)
            }
        }
        .padding(22)
        .frame(width: 560)
    }

    private var primaryButtonTitle: String {
        switch mode {
        case .create:
            "捕获"
        case .edit:
            "更新"
        }
    }

    private func save() {
        switch mode {
        case .create:
            store.createThread(from: draft)
        case let .edit(thread):
            store.updateThread(id: thread.id, from: draft)
        }

        if store.errorMessage == nil {
            dismiss()
        }
    }
}
