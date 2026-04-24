import CodexThreadRadarCore
import SwiftUI

struct ThreadRow: View {
    let thread: DevelopmentThread
    let onEdit: () -> Void
    let onCopy: () -> Void
    let onClose: () -> Void
    let onStatusChange: (ThreadStatus) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 10) {
                statusDot

                VStack(alignment: .leading, spacing: 5) {
                    HStack(spacing: 8) {
                        Text(thread.title)
                            .font(.headline)
                            .lineLimit(1)

                        StatusBadge(status: thread.status)
                    }

                    Text(thread.goal)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }

                Spacer(minLength: 12)

                Menu {
                    ForEach(ThreadStatus.currentDisplayOrder) { status in
                        Button(status.label) {
                            onStatusChange(status)
                        }
                    }
                } label: {
                    Image(systemName: "slider.horizontal.3")
                }
                .menuStyle(.button)
                .buttonStyle(.borderless)
                .help("更新状态")

                Button(action: onCopy) {
                    Image(systemName: "doc.on.doc")
                }
                .buttonStyle(.borderless)
                .help("复制续接提示")

                Button(action: onEdit) {
                    Image(systemName: "pencil")
                }
                .buttonStyle(.borderless)
                .help("编辑")

                Button(action: onClose) {
                    Image(systemName: "tray.and.arrow.down")
                }
                .buttonStyle(.borderless)
                .help("收口")
            }

            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Label(thread.projectName, systemImage: "folder")
                if let accountAlias = thread.accountAlias, !accountAlias.isEmpty {
                    Label(accountAlias, systemImage: "person.crop.circle")
                }
                Spacer()
                Text(thread.updatedAt.formatted(date: .omitted, time: .shortened))
            }
            .font(.caption)
            .foregroundStyle(.secondary)

            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text("下一步")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Text(thread.nextAction)
                    .font(.callout.weight(.medium))
                    .lineLimit(2)
            }
        }
        .padding(14)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(Color.secondary.opacity(0.14))
        )
    }

    private var statusDot: some View {
        Circle()
            .fill(color(for: thread.status))
            .frame(width: 10, height: 10)
            .padding(.top, 6)
    }
}

struct CompactThreadRow: View {
    let thread: DevelopmentThread
    let onEdit: () -> Void
    let onCopy: () -> Void
    let onClose: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Circle()
                    .fill(color(for: thread.status))
                    .frame(width: 8, height: 8)

                Text(thread.title)
                    .font(.callout.weight(.semibold))
                    .lineLimit(1)

                Spacer()

                StatusBadge(status: thread.status)
            }

            Text(thread.nextAction)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(2)

            HStack {
                Text(thread.projectName)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                Spacer()

                Button(action: onCopy) {
                    Image(systemName: "doc.on.doc")
                }
                .buttonStyle(.borderless)
                .help("复制续接提示")

                Button(action: onEdit) {
                    Image(systemName: "pencil")
                }
                .buttonStyle(.borderless)
                .help("编辑")

                Button(action: onClose) {
                    Image(systemName: "tray.and.arrow.down")
                }
                .buttonStyle(.borderless)
                .help("收口")
            }
        }
        .padding(10)
        .background(.quaternary, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

struct StatusBadge: View {
    let status: ThreadStatus

    var body: some View {
        Text(status.label)
            .font(.caption.weight(.semibold))
            .foregroundStyle(color(for: status))
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(color(for: status).opacity(0.12), in: RoundedRectangle(cornerRadius: 7, style: .continuous))
    }
}

func color(for status: ThreadStatus) -> Color {
    switch status {
    case .active:
        .blue
    case .quotaBlocked:
        .orange
    case .waitingForConfirmation:
        .purple
    case .needsReview:
        .green
    case .readyToClose:
        .teal
    case .closed:
        .secondary
    }
}
