import Foundation

public enum ThreadResumePromptFormatter {
    public static func prompt(for thread: DevelopmentThread) -> String {
        var lines = [
            "继续线程：\(thread.title)",
            "项目：\(thread.projectName)",
            "目标：\(thread.goal)",
            "当前状态：\(thread.status.label)",
        ]

        if let accountAlias = normalizedOptional(thread.accountAlias) {
            lines.append("关联账号：\(accountAlias)")
        }

        lines.append("下一步：\(thread.nextAction)")
        return lines.joined(separator: "\n")
    }

    private static func normalizedOptional(_ value: String?) -> String? {
        guard let value else {
            return nil
        }

        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
