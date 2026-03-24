import Foundation

struct TinyClawVariant: ClawVariant {
    let id = "tinyclaw"
    let displayName = "TinyClaw / TinyAGI"
    let description = "轻量级 AI 代理，支持自动任务执行"
    let iconSystemName = "ant"

    let cliBinaryNames = ["tinyclaw", "tinyagi"]
    let stateDirs = [
        ".tinyclaw", ".tinyagi", ".config/tinyclaw",
    ]

    nonisolated var extraExplicitPaths: [String] {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        return [
            "\(home)/tinyagi-workspace",
            "\(home)/Library/Application Support/TinyClaw",
            "\(home)/Library/Caches/TinyClaw",
        ]
    }
}
