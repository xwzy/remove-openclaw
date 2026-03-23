import Foundation
import Combine

@MainActor
final class OpenClawUninstallViewModel: ObservableObject {
    @Published private(set) var variantResults: [ClawVariantScanResult] = []
    @Published private(set) var isScanning = false
    @Published private(set) var isUninstalling = false
    @Published private(set) var lastResult: OpenClawCleanupResult?
    @Published private(set) var lastScannedAt: Date?
    @Published var errorMessage: String?
    @Published var selectedVariantIDs: Set<String> = []

    private let service = OpenClawUninstallService()

    var hasScanned: Bool { lastScannedAt != nil }

    var detectedResults: [ClawVariantScanResult] {
        variantResults.filter { $0.isDetected }
    }

    var notDetectedResults: [ClawVariantScanResult] {
        variantResults.filter { !$0.isDetected }
    }

    var sortedResults: [ClawVariantScanResult] {
        variantResults.sorted { lhs, rhs in
            if lhs.isDetected != rhs.isDetected { return lhs.isDetected }
            if lhs.totalSize != rhs.totalSize { return lhs.totalSize > rhs.totalSize }
            return lhs.variant.displayName < rhs.variant.displayName
        }
    }

    var targets: [OpenClawCleanupTarget] {
        variantResults.flatMap { $0.targets }
    }

    var selectedTargets: [OpenClawCleanupTarget] {
        variantResults
            .filter { selectedVariantIDs.contains($0.variant.id) }
            .flatMap { $0.targets }
    }

    var selectedResults: [ClawVariantScanResult] {
        variantResults.filter { selectedVariantIDs.contains($0.variant.id) && $0.isDetected }
    }

    var totalTargetSize: Int64 {
        targets.reduce(0) { $0 + max($1.size, 0) }
    }

    var selectedTargetSize: Int64 {
        selectedTargets.reduce(0) { $0 + max($1.size, 0) }
    }

    var selectedDetectedCount: Int {
        detectedResults.filter { selectedVariantIDs.contains($0.id) }.count
    }

    var allDetectedSelected: Bool {
        !detectedResults.isEmpty && detectedResults.allSatisfy { selectedVariantIDs.contains($0.id) }
    }

    func selectAllDetected() {
        for r in detectedResults {
            selectedVariantIDs.insert(r.id)
        }
    }

    func deselectAll() {
        selectedVariantIDs.removeAll()
    }

    func toggleVariant(_ id: String) {
        if selectedVariantIDs.contains(id) {
            selectedVariantIDs.remove(id)
        } else {
            selectedVariantIDs.insert(id)
        }
    }

    func targetsForVariant(_ id: String) -> [OpenClawCleanupTarget] {
        variantResults.first(where: { $0.id == id })?.targets ?? []
    }

    func exportTargets(to rawURL: URL) throws -> URL {
        try OpenClawTargetsExporter.export(targets: selectedTargets.isEmpty ? targets : selectedTargets, to: rawURL)
    }

    func scan() {
        guard !isScanning, !isUninstalling else { return }

        isScanning = true
        errorMessage = nil

        Task {
            let results = await Task(priority: .userInitiated) {
                service.scanAllVariants()
            }.value

            self.variantResults = results
            self.lastScannedAt = Date()
            self.isScanning = false

            for r in results where r.isDetected {
                self.selectedVariantIDs.insert(r.id)
            }
        }
    }

    func uninstall(terminateRunningProcesses: Bool) {
        guard !isScanning, !isUninstalling else { return }

        isUninstalling = true
        errorMessage = nil

        let toUninstall = selectedResults

        Task {
            let result = await service.uninstallSelectedVariants(
                toUninstall,
                terminateRunningProcesses: terminateRunningProcesses
            )
            self.lastResult = result

            if result.failedCount > 0 {
                self.errorMessage = "有 \(result.failedCount) 项卸载失败，可能被占用或权限不足。"
            }

            let rescannedResults = await Task(priority: .utility) {
                service.scanAllVariants()
            }.value

            self.variantResults = rescannedResults
            self.lastScannedAt = Date()
            self.isUninstalling = false

            self.selectedVariantIDs = Set(rescannedResults.filter { $0.isDetected }.map { $0.id })
        }
    }
}
