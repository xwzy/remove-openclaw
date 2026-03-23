import Foundation

struct CoderClawVariant: ClawVariant {
    let id = "coderclaw"
    let displayName = "CoderClaw"
    let description = "面向开发者的编程 AI 助手"
    let iconSystemName = "chevron.left.forwardslash.chevron.right"

    let appNames = ["CoderClaw"]
    let bundleIdentifiers = [
        "ai.coderclaw.mac", "ai.coderclaw.gateway", "ai.coderclaw.node",
    ]
    let launchAgentLabels = ["ai.coderclaw.gateway", "ai.coderclaw.node"]
    let cliBinaryNames = ["coderclaw"]
    let stateDirs = [".coderclaw"]

    var extraExplicitPaths: [String] {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        return [
            "\(home)/Library/Application Support/CoderClaw",
            "\(home)/Library/Caches/CoderClaw",
            "\(home)/Library/Logs/CoderClaw",
        ]
    }
}
