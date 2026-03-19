import Foundation
import Combine

@MainActor
final class OpenClawUninstallViewModel: ObservableObject {
    @Published private(set) var targets: [OpenClawCleanupTarget] = []
    @Published private(set) var isScanning = false
    @Published private(set) var isUninstalling = false
    @Published private(set) var lastResult: OpenClawCleanupResult?
    @Published private(set) var lastScannedAt: Date?
    @Published var errorMessage: String?

    private let service = OpenClawUninstallService()

    var hasScanned: Bool {
        lastScannedAt != nil
    }

    var totalTargetSize: Int64 {
        targets.reduce(0) { $0 + max($1.size, 0) }
    }

    func exportTargets(to rawURL: URL) throws -> URL {
        try OpenClawTargetsExporter.export(targets: targets, to: rawURL)
    }

    func scan() {
        guard !isScanning, !isUninstalling else { return }

        isScanning = true
        errorMessage = nil

        Task {
            let scannedTargets = await Task(priority: .userInitiated) {
                service.scanOpenClawTargets()
            }.value

            self.targets = scannedTargets
            self.lastScannedAt = Date()
            self.isScanning = false
        }
    }

    func uninstall(terminateRunningProcesses: Bool) {
        guard !isScanning, !isUninstalling else { return }

        isUninstalling = true
        errorMessage = nil

        let snapshot = targets

        Task {
            let result = await service.uninstallOpenClawCompletely(
                preferredTargets: snapshot,
                terminateRunningProcesses: terminateRunningProcesses
            )
            self.lastResult = result

            if result.failedCount > 0 {
                self.errorMessage = "有 \(result.failedCount) 项卸载失败，可能被占用或权限不足。"
            }

            let rescannedTargets = await Task(priority: .utility) {
                service.scanOpenClawTargets()
            }.value

            self.targets = rescannedTargets
            self.lastScannedAt = Date()
            self.isUninstalling = false
        }
    }

}
