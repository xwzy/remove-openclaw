import Foundation

struct OpenClawMUVariant: ClawVariant {
    let id = "openclawmu"
    let displayName = "OpenClawMU"
    let description = "多租户企业版 OpenClaw，支持租户隔离"
    let iconSystemName = "person.3"

    let cliBinaryNames = ["openclawmu"]
    let stateDirs = [".openclawmu", ".config/openclawmu"]

    var extraExplicitPaths: [String] {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        return [
            "\(home)/Library/Application Support/OpenClawMU",
        ]
    }
}
