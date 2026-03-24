import Foundation

struct ClawboxVariant: ClawVariant {
    let id = "clawbox"
    let displayName = "Clawbox"
    let description = "Docker 容器化部署的 OpenClaw 方案"

    let cliBinaryNames = ["clawbox"]
    let stateDirs = [".clawbox"]

    nonisolated var extraExplicitPaths: [String] {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        return [
            "\(home)/Library/Application Support/Clawbox",
            "\(home)/Library/Caches/Clawbox",
        ]
    }
}
