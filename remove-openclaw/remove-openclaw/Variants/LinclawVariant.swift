import Foundation

struct LinclawVariant: ClawVariant {
    let id = "linclaw"
    let displayName = "Linclaw"
    let description = "七牛云推出，支持 9 个渠道接入的企业版"
    let iconSystemName = "building.2"

    let stateDirs = [".openclaw/linclaw", ".config/linclaw"]

    var extraExplicitPaths: [String] {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        return [
            "\(home)/Library/Application Support/Linclaw",
        ]
    }
}
