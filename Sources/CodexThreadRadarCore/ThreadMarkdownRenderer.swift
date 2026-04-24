import Foundation

public enum ThreadMarkdownRenderer {
    public static func renderCurrentThreads(
        records: [DevelopmentThread],
        generatedAt: Date
    ) -> String {
        let current = ThreadStatusFilter.all.visibleThreads(from: records)
        let summary = ThreadRadarSummary(records: records)
        var lines: [String] = [
            "# 当下开发线程",
            "",
            "生成时间：\(format(generatedAt))",
            "",
            "> 当前 \(summary.currentCount) 条开发线程，\(summary.quotaBlockedCount) 条卡额度，\(summary.needsReviewCount) 条待验收。",
            "",
        ]

        if current.isEmpty {
            lines.append("暂无未收口开发线程。")
            return lines.joined(separator: "\n") + "\n"
        }

        for status in ThreadStatus.currentDisplayOrder {
            let statusRecords = current.filter { $0.status == status }
            guard !statusRecords.isEmpty else {
                continue
            }

            lines.append("## \(status.label)")
            lines.append("")

            for record in statusRecords {
                lines.append("### \(record.title)")
                lines.append("- 项目：\(record.projectName)")
                lines.append("- 目标：\(record.goal)")
                lines.append("- 下一步：\(record.nextAction)")
                if let accountAlias = normalizedOptional(record.accountAlias) {
                    lines.append("- 关联账号：\(accountAlias)")
                }
                lines.append("- 最近更新：\(format(record.updatedAt))")
                lines.append("")
            }
        }

        return lines.joined(separator: "\n") + "\n"
    }

    private static func normalizedOptional(_ value: String?) -> String? {
        guard let value else {
            return nil
        }

        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private static func format(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        return formatter.string(from: date)
    }
}
