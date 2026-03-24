import SwiftUI
import AppKit
import UniformTypeIdentifiers

enum SidebarItem: Hashable {
    case overview
    case variant(String)
}

struct ContentView: View {
    @StateObject private var viewModel = OpenClawUninstallViewModel()
    @State private var selection: SidebarItem? = .overview
    @State private var showUninstallConfirm = false
    @State private var exportMessage: String?
    @AppStorage("terminateRunningProcessesBeforeUninstall")
    private var terminateBeforeUninstall = true

    private let byteFormatter: ByteCountFormatter = {
        let f = ByteCountFormatter()
        f.allowedUnits = [.useGB, .useMB, .useKB]
        f.countStyle = .file
        return f
    }()

    var body: some View {
        NavigationSplitView {
            sidebar
                .navigationSplitViewColumnWidth(min: 240, ideal: 280, max: 340)
        } detail: {
            detailView
        }
        .frame(minWidth: 820, minHeight: 560)
        .onAppear {
            if !viewModel.hasScanned {
                viewModel.scan()
            }
        }
        .alert("确认卸载选中的 Claw 变体", isPresented: $showUninstallConfirm) {
            Button("取消", role: .cancel) {}
            Button("卸载", role: .destructive) {
                viewModel.uninstall(terminateRunningProcesses: terminateBeforeUninstall)
            }
        } message: {
            Text(confirmMessage)
        }
    }

    // MARK: - Sidebar

    private var sidebar: some View {
        List(selection: $selection) {
            Section("总览") {
                NavigationLink(value: SidebarItem.overview) {
                    let isSelected = isSidebarItemSelected(.overview)
                    Label {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("全部变体")
                                .font(.body.weight(.medium))
                                .foregroundStyle(sidebarPrimaryTextColor(isSelected: isSelected))
                            if viewModel.isScanning {
                                Text("扫描中 \(viewModel.scanProgressLabel)")
                                    .font(.caption)
                                    .foregroundStyle(sidebarSecondaryTextColor(isSelected: isSelected, defaultColor: .blue))
                            } else if viewModel.hasScanned {
                                Text("检测到 \(viewModel.detectedResults.count)/\(viewModel.variantResults.count) 个")
                                    .font(.caption)
                                    .foregroundStyle(sidebarSecondaryTextColor(isSelected: isSelected, defaultColor: .secondary))
                            }
                        }
                    } icon: {
                        Image(systemName: "square.grid.2x2")
                            .foregroundStyle(sidebarIconColor(isSelected: isSelected, defaultColor: .blue))
                    }
                }
            }

            if !viewModel.detectedResults.isEmpty {
                Section("已检测到 (\(viewModel.detectedResults.count))") {
                    ForEach(viewModel.sortedResults.filter({ $0.isDetected }), id: \.id) { result in
                        variantRow(result)
                    }
                }
            }

            if !viewModel.notDetectedResults.isEmpty {
                Section("未检测到 (\(viewModel.notDetectedResults.count))") {
                    ForEach(viewModel.sortedResults.filter({ !$0.isDetected }), id: \.id) { result in
                        variantRow(result)
                    }
                }
            }
        }
        .listStyle(.sidebar)
    }

    private func variantRow(_ result: ClawVariantScanResult) -> some View {
        NavigationLink(value: SidebarItem.variant(result.variant.id)) {
            let isSelected = isSidebarItemSelected(.variant(result.variant.id))
            HStack(spacing: 8) {
                Image(systemName: result.variant.iconSystemName)
                    .foregroundStyle(
                        sidebarIconColor(
                            isSelected: isSelected,
                            defaultColor: result.isDetected ? .orange : .secondary
                        )
                    )
                    .frame(width: 20)

                VStack(alignment: .leading, spacing: 2) {
                    Text(result.variant.displayName)
                        .font(.body.weight(.medium))
                        .foregroundStyle(sidebarPrimaryTextColor(isSelected: isSelected))
                    if result.isDetected {
                        Text("\(result.targets.count) 项 · \(fmt(result.totalSize))")
                            .font(.caption)
                            .foregroundStyle(sidebarSecondaryTextColor(isSelected: isSelected, defaultColor: .orange))
                    } else {
                        Text("未检测到")
                            .font(.caption)
                            .foregroundStyle(sidebarSecondaryTextColor(isSelected: isSelected, defaultColor: .secondary))
                    }
                }

                Spacer()

                if result.isDetected && viewModel.selectedVariantIDs.contains(result.variant.id) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(sidebarIconColor(isSelected: isSelected, defaultColor: .blue))
                        .font(.caption)
                }
            }
        }
    }

    private func isSidebarItemSelected(_ item: SidebarItem) -> Bool {
        selection == item
    }

    private func sidebarPrimaryTextColor(isSelected: Bool) -> Color {
        isSelected ? .white : .primary
    }

    private func sidebarSecondaryTextColor(isSelected: Bool, defaultColor: Color) -> Color {
        isSelected ? .white : defaultColor
    }

    private func sidebarIconColor(isSelected: Bool, defaultColor: Color) -> Color {
        isSelected ? .white : defaultColor
    }

    // MARK: - Detail View

    @ViewBuilder
    private var detailView: some View {
        switch selection {
        case .overview, .none:
            overviewView
        case .variant(let id):
            if let result = viewModel.variantResults.first(where: { $0.variant.id == id }) {
                variantDetailView(result)
            } else {
                Text("未找到变体信息")
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Overview

    private var overviewView: some View {
        VStack(spacing: 0) {
            overviewStatsBar
            Divider()
            overviewContent
        }
        .background(.background)
    }

    private var overviewStatsBar: some View {
        HStack(spacing: 16) {
            StatItem(
                label: "已检测变体",
                value: "\(viewModel.detectedResults.count)",
                systemImage: "app.badge",
                tint: viewModel.detectedResults.isEmpty ? .green : .orange
            )
            StatItem(
                label: "已选中",
                value: "\(viewModel.selectedDetectedCount)",
                systemImage: "checkmark.circle",
                tint: .blue
            )
            StatItem(
                label: "预计释放",
                value: fmt(viewModel.selectedTargetSize),
                systemImage: "externaldrive",
                tint: .blue
            )
            StatItem(
                label: "最近扫描",
                value: viewModel.isScanning ? viewModel.scanProgressLabel : lastScanTimeShort,
                systemImage: "clock",
                tint: .teal,
                footnote: viewModel.isScanning ? viewModel.scanStatusText : lastScanDateLong
            )
        }
        .padding(16)
    }

    private var overviewContent: some View {
        VStack(spacing: 0) {
            overviewToolbar
            Divider()

            if viewModel.isUninstalling {
                Spacer()
                VStack(spacing: 12) {
                    ProgressView()
                        .controlSize(.large)
                    Text("正在卸载选中的变体…")
                        .font(.body)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            } else if !viewModel.hasScanned {
                initialScanView
            } else if viewModel.detectedResults.isEmpty && !viewModel.isScanning {
                emptyState
            } else {
                VStack(spacing: 0) {
                    if viewModel.isScanning {
                        scanActivityView
                        Divider()
                    }
                    overviewList
                }
            }
        }
    }

    private var overviewToolbar: some View {
        HStack(spacing: 12) {
            Button {
                viewModel.scan()
            } label: {
                Label(viewModel.hasScanned ? "重新扫描" : "开始扫描", systemImage: "arrow.clockwise")
            }
            .disabled(viewModel.isScanning || viewModel.isUninstalling)

            Divider().frame(height: 20)

            Button {
                if viewModel.allDetectedSelected {
                    viewModel.deselectAll()
                } else {
                    viewModel.selectAllDetected()
                }
            } label: {
                Label(
                    viewModel.allDetectedSelected ? "取消全选" : "全部选中",
                    systemImage: viewModel.allDetectedSelected ? "xmark.circle" : "checkmark.circle"
                )
            }
            .disabled(viewModel.isScanning || viewModel.detectedResults.isEmpty || viewModel.isUninstalling)

            Spacer()

            Button {
                exportTargetsList()
            } label: {
                Label("导出清单", systemImage: "square.and.arrow.up")
            }
            .disabled(viewModel.isScanning || viewModel.isUninstalling || viewModel.targets.isEmpty)

            Button(role: .destructive) {
                showUninstallConfirm = true
            } label: {
                Label("卸载选中 (\(viewModel.selectedDetectedCount))", systemImage: "trash")
            }
            .disabled(viewModel.isScanning || viewModel.isUninstalling || viewModel.selectedDetectedCount == 0)

            if let exportMessage {
                Label(exportMessage, systemImage: exportMessage.hasPrefix("导出失败") ? "xmark.circle.fill" : "checkmark.circle.fill")
                    .font(.caption)
                    .foregroundStyle(exportMessage.hasPrefix("导出失败") ? .orange : .green)
                    .task(id: exportMessage) {
                        try? await Task.sleep(for: .seconds(4))
                        if !Task.isCancelled {
                            self.exportMessage = nil
                        }
                    }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    private var overviewList: some View {
        List {
            Section("支持扫描的全部变体 (\(supportedVariantDisplayNames.count))") {
                VStack(alignment: .leading, spacing: 12) {
                    Text("当前版本已覆盖官方分支、第三方改名版和国产变体，支持扫描名单一眼看全。")
                        .font(.callout)
                        .foregroundStyle(.secondary)

                    supportedVariantChipGrid
                }
                .padding(.vertical, 4)
            }

            ForEach(viewModel.sortedResults.filter({ $0.isDetected }), id: \.id) { result in
                HStack(spacing: 12) {
                    Button {
                        viewModel.toggleVariant(result.variant.id)
                    } label: {
                        Image(systemName: viewModel.selectedVariantIDs.contains(result.variant.id)
                              ? "checkmark.circle.fill" : "circle")
                            .foregroundStyle(viewModel.selectedVariantIDs.contains(result.variant.id)
                                             ? .blue : .secondary)
                            .font(.title3)
                    }
                    .buttonStyle(.plain)
                    .disabled(viewModel.isScanning)

                    Button {
                        selection = .variant(result.variant.id)
                    } label: {
                        HStack(spacing: 12) {
                            IconBox(systemImage: result.variant.iconSystemName, tint: .orange, size: 34)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(result.variant.displayName)
                                    .font(.body.weight(.medium))
                                Text(result.variant.description)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }

                            Spacer()

                            VStack(alignment: .trailing, spacing: 2) {
                                Text("\(result.targets.count) 项")
                                    .font(.callout.weight(.semibold).monospacedDigit())
                                Text(fmt(result.totalSize))
                                    .font(.caption.monospacedDigit())
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
                .padding(.vertical, 4)
            }

            if let result = viewModel.lastResult {
                Section("上次卸载结果") {
                    resultSummaryRows(result)
                }
            }

            settingsSection
        }
        .listStyle(.inset(alternatesRowBackgrounds: true))
    }

    // MARK: - Variant Detail View

    private var initialScanView: some View {
        ScrollView {
            VStack(spacing: 0) {
                scanActivityView
                supportedVariantsShowcaseCard
                    .padding(.horizontal, 16)
                    .padding(.bottom, 16)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var scanActivityView: some View {
        VStack(spacing: 16) {
            SectionCard {
                VStack(alignment: .leading, spacing: 14) {
                    HStack(alignment: .top, spacing: 12) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("正在扫描 Claw 相关残留")
                                .font(.title3.weight(.semibold))
                            Text(viewModel.scanStatusText)
                                .font(.callout)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        StatusBadge(
                            title: viewModel.scanProgressLabel,
                            systemImage: "waveform.path.ecg",
                            tint: .blue
                        )
                    }

                    if viewModel.scanTotalCount > 0 {
                        ProgressView(value: Double(viewModel.scanCompletedCount), total: Double(viewModel.scanTotalCount))
                            .tint(.blue)
                    } else {
                        ProgressView()
                            .tint(.blue)
                    }

                    HStack(spacing: 12) {
                        Label("已完成 \(viewModel.scanCompletedCount) 个", systemImage: "checkmark.circle")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        Label("已发现 \(viewModel.detectedResults.count) 个变体", systemImage: "app.badge")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        Spacer()

                        Text("预计残留 \(fmt(viewModel.totalTargetSize))")
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                }
            }

            SectionCard {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text("扫描日志")
                            .font(.headline)
                        Spacer()
                        Text("最近 \(min(viewModel.scanLogEntries.count, 10)) 条")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    if viewModel.scanLogEntries.isEmpty {
                        Text("准备开始扫描…")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    } else {
                        VStack(alignment: .leading, spacing: 8) {
                            ForEach(Array(viewModel.scanLogEntries.suffix(10))) { entry in
                                HStack(alignment: .top, spacing: 10) {
                                    Text(entry.timestamp, format: .dateTime.hour().minute().second())
                                        .font(.caption.monospacedDigit())
                                        .foregroundStyle(.tertiary)
                                        .frame(width: 72, alignment: .leading)

                                    Text(entry.message)
                                        .font(.callout)
                                        .foregroundStyle(.primary)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                }
                            }
                        }
                    }
                }
            }
        }
        .padding(16)
    }

    private func variantDetailView(_ result: ClawVariantScanResult) -> some View {
        VStack(spacing: 0) {
            variantDetailHeader(result)
            Divider()

            if result.targets.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 40))
                        .foregroundStyle(.green)
                    Text("未检测到残留")
                        .font(.title2.weight(.semibold))
                    Text("\(result.variant.displayName) 未发现任何相关文件")
                        .font(.body)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(result.targets) { target in
                    let url = URL(fileURLWithPath: target.path)
                    let name = url.lastPathComponent.isEmpty ? target.path : url.lastPathComponent
                    Group {
                        if target.isDirectory {
                            Button {
                                openTargetInFinder(target)
                            } label: {
                                TargetFileRow(
                                    name: name,
                                    path: target.path,
                                    size: fmt(target.size),
                                    isDirectory: true,
                                    showsOpenIndicator: true
                                )
                            }
                            .buttonStyle(.plain)
                            .contentShape(Rectangle())
                            .help("在 Finder 中打开目录")
                        } else {
                            TargetFileRow(
                                name: name,
                                path: target.path,
                                size: fmt(target.size),
                                isDirectory: false
                            )
                        }
                    }
                }
                .listStyle(.inset(alternatesRowBackgrounds: true))
            }
        }
        .background(.background)
    }

    private func variantDetailHeader(_ result: ClawVariantScanResult) -> some View {
        HStack(spacing: 16) {
            IconBox(systemImage: result.variant.iconSystemName,
                    tint: result.isDetected ? .orange : .secondary, size: 44)

            VStack(alignment: .leading, spacing: 4) {
                Text(result.variant.displayName)
                    .font(.title2.weight(.bold))
                Text(result.variant.description)
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if result.isDetected {
                VStack(alignment: .trailing, spacing: 4) {
                    Text("\(result.targets.count) 项待清理")
                        .font(.callout.weight(.semibold))
                    Text(fmt(result.totalSize))
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                }

                Button {
                    viewModel.toggleVariant(result.variant.id)
                } label: {
                    Label(
                        viewModel.selectedVariantIDs.contains(result.variant.id) ? "已选中" : "选中",
                        systemImage: viewModel.selectedVariantIDs.contains(result.variant.id)
                            ? "checkmark.circle.fill" : "circle"
                    )
                }
                .buttonStyle(.bordered)
                .disabled(viewModel.isScanning)
            } else {
                StatusBadge(title: "无残留", systemImage: "checkmark.circle", tint: .green)
            }
        }
        .padding(16)
    }

    // MARK: - Shared Sections

    private var settingsSection: some View {
        Section("设置") {
            Toggle(isOn: $terminateBeforeUninstall) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("卸载前退出进程")
                        .font(.body)
                    Text("先结束 Claw 系列相关进程再清理文件")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .toggleStyle(.switch)
            .disabled(viewModel.isScanning || viewModel.isUninstalling)
        }
    }

    private func resultSummaryRows(_ result: OpenClawCleanupResult) -> some View {
        Group {
            HStack(spacing: 12) {
                ResultCountItem(label: "已退出", count: result.terminatedProcessCount, tint: .blue)
                ResultCountItem(label: "已清理", count: result.movedToTrashCount, tint: .green)
                ResultCountItem(label: "失败", count: result.failedCount, tint: result.failedCount > 0 ? .orange : .secondary)
            }

            if result.forceTerminatedProcessCount > 0 {
                Label("其中 \(result.forceTerminatedProcessCount) 个进程被强制退出", systemImage: "bolt.fill")
                    .font(.caption)
                    .foregroundStyle(.orange)
            }

            Label("已移入废纸篓 \(fmt(result.movedToTrashSize))", systemImage: "trash.circle.fill")
                .font(.caption)
                .foregroundStyle(.green)

            if !result.failedPaths.isEmpty {
                DisclosureGroup("失败路径") {
                    ForEach(result.failedPaths, id: \.self) { path in
                        Text(path)
                            .font(.caption.monospaced())
                            .foregroundStyle(.secondary)
                            .textSelection(.enabled)
                    }
                }
                .font(.caption.weight(.medium))
            }
        }
    }

    private var emptyState: some View {
        ScrollView {
            VStack(spacing: 16) {
                SectionCard {
                    VStack(spacing: 12) {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.system(size: 40))
                            .foregroundStyle(.green)

                        Text("没有发现残留")
                            .font(.title2.weight(.semibold))

                        Text("扫描未发现任何 Claw 变体相关文件，当前环境已经干净。")
                            .font(.body)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: 360)
                    }
                    .frame(maxWidth: .infinity)
                }

                supportedVariantsShowcaseCard
            }
            .padding(16)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var supportedVariantsShowcaseCard: some View {
        SectionCard {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top, spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("当前支持扫描的全部变体")
                            .font(.title3.weight(.semibold))
                        Text("当前版本共覆盖 \(supportedVariantDisplayNames.count) 个变体，包含官方分支、第三方改名版和国产变体。")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    StatusBadge(title: "\(supportedVariantDisplayNames.count) 个", systemImage: "sparkles", tint: .blue)
                }

                supportedVariantChipGrid
            }
        }
    }

    private var supportedVariantChipGrid: some View {
        LazyVGrid(columns: supportedVariantGridColumns, alignment: .leading, spacing: 8) {
            ForEach(supportedVariantDisplayNames, id: \.self) { name in
                Text(name)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.primary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(.blue.opacity(0.08), in: Capsule())
                    .overlay(
                        Capsule()
                            .stroke(.blue.opacity(0.14), lineWidth: 0.5)
                    )
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    // MARK: - Computed Properties

    private var supportedVariantGridColumns: [GridItem] {
        [GridItem(.adaptive(minimum: 96, maximum: 180), alignment: .leading)]
    }

    private var supportedVariantDisplayNames: [String] {
        ClawVariantRegistry.all.map(\.displayName).sorted()
    }

    private var lastScanTimeShort: String {
        guard let d = viewModel.lastScannedAt else { return "扫描中…" }
        return d.formatted(date: .omitted, time: .shortened)
    }

    private var lastScanDateLong: String? {
        guard let d = viewModel.lastScannedAt else { return nil }
        return d.formatted(date: .abbreviated, time: .omitted)
    }

    private var confirmMessage: String {
        let count = viewModel.selectedDetectedCount
        var msg = "将卸载 \(count) 个变体，共 \(viewModel.selectedTargets.count) 项文件（\(fmt(viewModel.selectedTargetSize))）。"
        if terminateBeforeUninstall {
            msg += "\n\n卸载前会先退出运行中的相关进程并卸载 LaunchAgent。"
        } else {
            msg += "\n\n未开启自动退出进程，部分文件可能删除失败。"
        }
        return msg
    }

    private func fmt(_ size: Int64) -> String {
        byteFormatter.string(fromByteCount: size)
    }

    private func openTargetInFinder(_ target: OpenClawCleanupTarget) {
        let url = URL(fileURLWithPath: target.path)
        if target.isDirectory {
            NSWorkspace.shared.open(url)
        } else {
            NSWorkspace.shared.activateFileViewerSelecting([url])
        }
    }

    // MARK: - Export

    private func exportTargetsList() {
        let panel = NSSavePanel()
        panel.title = "导出 Claw 系列待清理清单"
        panel.message = "支持 .txt 或 .json 格式"
        panel.nameFieldStringValue = "claw-cleanup-targets.txt"
        panel.allowedContentTypes = [.plainText, .json]
        panel.canCreateDirectories = true
        panel.isExtensionHidden = false

        guard panel.runModal() == .OK, let url = panel.url else { return }

        do {
            let exported = try viewModel.exportTargets(to: url)
            exportMessage = "已导出：\(exported.path)"
        } catch {
            exportMessage = "导出失败：\(error.localizedDescription)"
        }
    }
}

#Preview {
    ContentView()
}
