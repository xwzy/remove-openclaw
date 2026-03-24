import Foundation

struct HiClawVariant: ClawVariant {
    let id = "hiclaw"
    let displayName = "HiClaw"
    let description = "阿里巴巴推出的 AI 助手平台"

    let appNames = ["HiClaw"]
    let bundleIdentifiers = ["com.alibaba.hiclaw"]
    let cliBinaryNames = ["hiclaw"]
    let stateDirs = [".hiclaw", ".config/hiclaw"]

    nonisolated var extraExplicitPaths: [String] {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        return [
            "\(home)/Library/Application Support/HiClaw",
            "\(home)/Library/Caches/HiClaw",
            "\(home)/Library/Caches/com.alibaba.hiclaw",
        ]
    }
}
