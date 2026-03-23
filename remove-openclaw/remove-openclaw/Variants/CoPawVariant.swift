import Foundation

struct CoPawVariant: ClawVariant {
    let id = "copaw"
    let displayName = "CoPaw"
    let description = "阿里巴巴推出的 AI 助手客户端"
    let iconSystemName = "pawprint"

    let cliBinaryNames = ["copaw"]
    let stateDirs = [".copaw"]
}
