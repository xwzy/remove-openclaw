import Foundation

struct RemoteClawVariant: ClawVariant {
    let id = "remoteclaw"
    let displayName = "RemoteClaw"
    let description = "远程部署 OpenClaw，支持 SSH 和云端运行"
    let iconSystemName = "cloud"

    let appNames = ["RemoteClaw"]
    let bundleIdentifiers = [
        "org.remoteclaw.mac", "org.remoteclaw.gateway", "org.remoteclaw.node",
    ]
    let launchAgentLabels = ["org.remoteclaw.gateway", "org.remoteclaw.node"]
    let cliBinaryNames = ["remoteclaw"]
    let stateDirs = [".remoteclaw"]

    nonisolated var extraExplicitPaths: [String] {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        var paths = [
            "\(home)/Library/Application Support/RemoteClaw",
            "\(home)/Library/Caches/RemoteClaw",
            "\(home)/Library/Logs/RemoteClaw",
            "/tmp/remoteclaw",
        ]
        let shimDirs = [
            "\(home)/.volta/bin",
            "\(home)/.asdf/shims",
            "\(home)/.bun/bin",
            "\(home)/.npm-global/bin",
        ]
        for dir in shimDirs {
            paths.append("\(dir)/remoteclaw")
        }
        return paths
    }
}
