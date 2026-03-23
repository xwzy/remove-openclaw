import Foundation

struct QClawVariant: ClawVariant {
    let id = "qclaw"
    let displayName = "QClaw"
    let description = "腾讯出品，微信生态深度整合的 AI 助手"
    let iconSystemName = "message"

    let appNames = ["QClaw"]
    let bundleIdentifiers = ["com.tencent.qclaw"]
    let cliBinaryNames = ["qclaw"]
    let stateDirs = [".qclaw", ".config/qclaw"]

    var extraExplicitPaths: [String] {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        return [
            "\(home)/Library/Application Support/QClaw",
            "\(home)/Library/Caches/QClaw",
            "\(home)/Library/Caches/com.tencent.qclaw",
            "\(home)/Library/Logs/QClaw",
        ]
    }
}
