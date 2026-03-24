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
    @State private var hasAcknowledgedDeletionRisk = false
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
                .navigationSplitViewColumnWidth(min: 210, ideal: 236, max: 280)
        } detail: {
            detailView
        }
        .fontDesign(.default)
        .frame(minWidth: 780, minHeight: 520)
        .onAppear {
            configureWindowAppearance()
            if !viewModel.hasScanned {
                viewModel.scan()
            }
        }
        .onChange(of: viewModel.selectedVariantIDs) {
            resetDeletionAcknowledgement()
        }
        .onChange(of: viewModel.lastScannedAt) {
            resetDeletionAcknowledgement()
        }
        .onChange(of: terminateBeforeUninstall) {
            resetDeletionAcknowledgement()
        }
        .alert("请再次确认：即将真实清理这些文件", isPresented: $showUninstallConfirm) {
            Button("取消", role: .cancel) {}
            Button("确认卸载", role: .destructive) {
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
                        VStack(alignment: .leading, spacing: 3) {
                            Text("全部变体")
                                .font(AppTypography.sidebarTitle)
                                .foregroundStyle(sidebarPrimaryTextColor(isSelected: isSelected))
                            if viewModel.isScanning {
                                Text("扫描中 \(viewModel.scanProgressLabel)")
                                    .font(AppTypography.caption)
                                    .foregroundStyle(sidebarSecondaryTextColor(isSelected: isSelected, defaultColor: .blue))
                            } else if viewModel.hasScanned {
                                Text("检测到 \(viewModel.detectedResults.count)/\(viewModel.variantResults.count) 个")
                                    .font(AppTypography.caption)
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
        .environment(\.defaultMinListRowHeight, 36)
    }

    private func variantRow(_ result: ClawVariantScanResult) -> some View {
        NavigationLink(value: SidebarItem.variant(result.variant.id)) {
            let isSelected = isSidebarItemSelected(.variant(result.variant.id))
            HStack(spacing: 7) {
                Image(systemName: result.variant.iconSystemName)
                    .foregroundStyle(
                        sidebarIconColor(
                            isSelected: isSelected,
                            defaultColor: result.isDetected ? .orange : .secondary
                        )
                    )
                    .frame(width: 18)

                VStack(alignment: .leading, spacing: 2) {
                    Text(result.variant.displayName)
                        .font(AppTypography.sidebarTitle)
                        .foregroundStyle(sidebarPrimaryTextColor(isSelected: isSelected))
                    if result.isDetected {
                        Text("\(result.targets.count) 项 · \(fmt(result.totalSize))")
                            .font(AppTypography.caption)
                            .foregroundStyle(sidebarSecondaryTextColor(isSelected: isSelected, defaultColor: .orange))
                    } else {
                        Text("未检测到")
                            .font(AppTypography.caption)
                            .foregroundStyle(sidebarSecondaryTextColor(isSelected: isSelected, defaultColor: .secondary))
                    }
                }

                Spacer()

                if result.isDetected && viewModel.selectedVariantIDs.contains(result.variant.id) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(sidebarIconColor(isSelected: isSelected, defaultColor: .blue))
                        .font(AppTypography.caption)
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
        HStack(spacing: 12) {
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
        .frame(maxWidth: AppLayout.contentMaxWidth)
        .frame(maxWidth: .infinity)
        .padding(AppLayout.pagePadding)
    }

    private var overviewContent: some View {
        VStack(spacing: 0) {
            overviewToolbar
            Divider()

            if viewModel.isUninstalling {
                Spacer()
                VStack(spacing: 10) {
                    ProgressView()
                        .controlSize(.large)
                    Text("正在卸载选中的变体…")
                        .font(AppTypography.body)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            } else if !viewModel.hasScanned {
                initialScanView
            } else if viewModel.detectedResults.isEmpty && !viewModel.isScanning {
                emptyState
            } else {
                overviewScrollView
            }
        }
    }

    private var overviewToolbar: some View {
        HStack(spacing: 10) {
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
            .disabled(!canStartUninstall)
            .help(uninstallButtonHelpText)

            if let exportMessage {
                Label(exportMessage, systemImage: exportMessage.hasPrefix("导出失败") ? "xmark.circle.fill" : "checkmark.circle.fill")
                    .font(AppTypography.caption)
                    .foregroundStyle(exportMessage.hasPrefix("导出失败") ? .orange : .green)
                    .task(id: exportMessage) {
                        try? await Task.sleep(for: .seconds(4))
                        if !Task.isCancelled {
                            self.exportMessage = nil
                        }
                    }
            }
        }
        .frame(maxWidth: AppLayout.contentMaxWidth)
        .frame(maxWidth: .infinity)
        .controlSize(.small)
        .padding(.horizontal, AppLayout.pagePadding)
        .padding(.vertical, 6)
    }

    private var overviewScrollView: some View {
        ScrollView {
            VStack(spacing: AppLayout.sectionSpacing) {
                if viewModel.isScanning {
                    scanActivityView
                }

                supportedVariantsShowcaseCard

                if !viewModel.detectedResults.isEmpty {
                    detectedVariantsCard
                    uninstallSafetyCard
                }

                if let result = viewModel.lastResult {
                    resultSummaryCard(result)
                }

                settingsCard
            }
            .padding(AppLayout.pagePadding)
            .frame(maxWidth: AppLayout.contentMaxWidth)
            .frame(maxWidth: .infinity)
        }
    }

    private var detectedVariantsCard: some View {
        let detectedResults = viewModel.sortedResults.filter(\.isDetected)

        return SectionCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .center, spacing: 10) {
                    Text("检测到的变体")
                        .font(AppTypography.sectionTitle)

                    Spacer()

                    StatusBadge(
                        title: "\(detectedResults.count) 个",
                        systemImage: "checkmark.circle.fill",
                        tint: .orange
                    )
                }

                VStack(spacing: 0) {
                    ForEach(Array(detectedResults.enumerated()), id: \.element.id) { index, result in
                        overviewResultRow(result)

                        if index < detectedResults.count - 1 {
                            Divider()
                                .padding(.leading, 42)
                        }
                    }
                }
            }
        }
    }

    private func overviewResultRow(_ result: ClawVariantScanResult) -> some View {
        HStack(spacing: 8) {
            Button {
                viewModel.toggleVariant(result.variant.id)
            } label: {
                Image(systemName: viewModel.selectedVariantIDs.contains(result.variant.id)
                      ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(viewModel.selectedVariantIDs.contains(result.variant.id)
                                     ? .blue : .secondary)
                    .font(.system(size: 18, weight: .semibold))
            }
            .buttonStyle(.plain)
            .disabled(viewModel.isScanning)

            Button {
                selection = .variant(result.variant.id)
            } label: {
                HStack(spacing: 10) {
                    IconBox(systemImage: result.variant.iconSystemName, tint: .orange, size: 30)

                    VStack(alignment: .leading, spacing: 3) {
                        Text(result.variant.displayName)
                            .font(AppTypography.bodyStrong)
                        Text(result.variant.description)
                            .font(AppTypography.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 2) {
                        Text("\(result.targets.count) 项")
                            .font(AppTypography.bodyStrong)
                        Text(fmt(result.totalSize))
                            .font(AppTypography.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 8)
    }

    // MARK: - Variant Detail View

    private var initialScanView: some View {
        ScrollView {
            VStack(spacing: AppLayout.sectionSpacing) {
                scanActivityView
                supportedVariantsShowcaseCard
            }
            .padding(AppLayout.pagePadding)
            .frame(maxWidth: AppLayout.contentMaxWidth)
            .frame(maxWidth: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var scanActivityView: some View {
        VStack(spacing: AppLayout.sectionSpacing) {
            SectionCard {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(alignment: .top, spacing: 10) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("正在扫描 Claw 相关残留")
                                .font(AppTypography.sectionTitle)
                            Text(viewModel.scanStatusText)
                                .font(AppTypography.subtitle)
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

                    HStack(spacing: 10) {
                        Label("已完成 \(viewModel.scanCompletedCount) 个", systemImage: "checkmark.circle")
                            .font(AppTypography.caption)
                            .foregroundStyle(.secondary)

                        Label("已发现 \(viewModel.detectedResults.count) 个变体", systemImage: "app.badge")
                            .font(AppTypography.caption)
                            .foregroundStyle(.secondary)

                        Spacer()

                        Text("预计残留 \(fmt(viewModel.totalTargetSize))")
                            .font(AppTypography.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            SectionCard {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text("扫描日志")
                            .font(AppTypography.bodyStrong)
                        Spacer()
                        Text("最近 \(min(viewModel.scanLogEntries.count, 10)) 条")
                            .font(AppTypography.caption)
                            .foregroundStyle(.secondary)
                    }

                    if viewModel.scanLogEntries.isEmpty {
                        Text("准备开始扫描…")
                            .font(AppTypography.subtitle)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    } else {
                        VStack(alignment: .leading, spacing: 7) {
                            ForEach(Array(viewModel.scanLogEntries.suffix(10))) { entry in
                                HStack(alignment: .top, spacing: 10) {
                                    Text(entry.timestamp, format: .dateTime.hour().minute().second())
                                        .font(AppTypography.caption)
                                        .foregroundStyle(.tertiary)
                                        .frame(width: 68, alignment: .leading)

                                    Text(entry.message)
                                        .font(AppTypography.body)
                                        .foregroundStyle(.primary)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                }
                            }
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity)
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
                        .font(AppTypography.pageTitle)
                    Text("\(result.variant.displayName) 未发现任何相关文件")
                        .font(AppTypography.body)
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
                .environment(\.defaultMinListRowHeight, 44)
            }
        }
        .background(.background)
    }

    private func variantDetailHeader(_ result: ClawVariantScanResult) -> some View {
        HStack(spacing: 14) {
            IconBox(systemImage: result.variant.iconSystemName,
                    tint: result.isDetected ? .orange : .secondary, size: 42)

            VStack(alignment: .leading, spacing: 4) {
                Text(result.variant.displayName)
                    .font(AppTypography.pageTitle)
                Text(result.variant.description)
                    .font(AppTypography.subtitle)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if result.isDetected {
                VStack(alignment: .trailing, spacing: 4) {
                    Text("\(result.targets.count) 项待清理")
                        .font(AppTypography.bodyStrong)
                    Text(fmt(result.totalSize))
                        .font(AppTypography.caption)
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
        .padding(AppLayout.pagePadding)
    }

    // MARK: - Shared Sections

    private var uninstallSafetyCard: some View {
        SectionCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top, spacing: 10) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("删除前请确认")
                            .font(AppTypography.sectionTitle)
                        Text("这里执行的是真实清理，不是简单隐藏或取消勾选。")
                            .font(AppTypography.subtitle)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    StatusBadge(
                        title: hasAcknowledgedDeletionRisk ? "已确认" : "待确认",
                        systemImage: hasAcknowledgedDeletionRisk ? "checkmark.shield.fill" : "exclamationmark.triangle.fill",
                        tint: hasAcknowledgedDeletionRisk ? .green : .orange
                    )
                }

                NoticeRow(
                    message: "选中的文件和目录会被移入废纸篓，其中可能包含登录状态、本地配置、缓存、索引或下载资源。",
                    systemImage: "trash.slash.fill",
                    tint: .orange
                )

                NoticeRow(
                    message: "如果你不确定某个路径该不该删，请先点进变体查看明细，或者先导出清单留档再操作。",
                    systemImage: "doc.text.magnifyingglass",
                    tint: .blue
                )

                NoticeRow(
                    message: processWarningMessage,
                    systemImage: terminateBeforeUninstall ? "power.circle.fill" : "exclamationmark.triangle.fill",
                    tint: terminateBeforeUninstall ? .orange : .secondary
                )

                Divider()

                Toggle(isOn: $hasAcknowledgedDeletionRisk) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("我已核对待清理项，并清楚这会真正清理残留")
                            .font(AppTypography.bodyStrong)
                        Text(acknowledgementDetailText)
                            .font(AppTypography.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .toggleStyle(.switch)
                .disabled(viewModel.isScanning || viewModel.isUninstalling || viewModel.selectedDetectedCount == 0)

                if viewModel.selectedDetectedCount == 0 {
                    Text("先选中至少一个检测到的变体，才能确认并执行卸载。")
                        .font(AppTypography.caption)
                        .foregroundStyle(.secondary)
                } else if !hasAcknowledgedDeletionRisk {
                    Text("未勾选前，顶部“卸载选中”按钮会保持禁用。")
                        .font(AppTypography.caption)
                        .foregroundStyle(.orange)
                }
            }
        }
    }

    private var settingsCard: some View {
        SectionCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("卸载设置")
                    .font(AppTypography.sectionTitle)

                Toggle(isOn: $terminateBeforeUninstall) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("卸载前退出进程")
                            .font(AppTypography.bodyStrong)
                        Text("先结束 Claw 系列相关进程再清理文件")
                            .font(AppTypography.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .toggleStyle(.switch)
                .disabled(viewModel.isScanning || viewModel.isUninstalling)
            }
        }
    }

    private func resultSummaryCard(_ result: OpenClawCleanupResult) -> some View {
        SectionCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("上次卸载结果")
                    .font(AppTypography.sectionTitle)

                resultSummaryRows(result)
            }
        }
    }

    private func resultSummaryRows(_ result: OpenClawCleanupResult) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                ResultCountItem(label: "已退出", count: result.terminatedProcessCount, tint: .blue)
                ResultCountItem(label: "已清理", count: result.movedToTrashCount, tint: .green)
                ResultCountItem(label: "失败", count: result.failedCount, tint: result.failedCount > 0 ? .orange : .secondary)
            }

            if result.forceTerminatedProcessCount > 0 {
                Label("其中 \(result.forceTerminatedProcessCount) 个进程被强制退出", systemImage: "bolt.fill")
                    .font(AppTypography.caption)
                    .foregroundStyle(.orange)
            }

            Label("已移入废纸篓 \(fmt(result.movedToTrashSize))", systemImage: "trash.circle.fill")
                .font(AppTypography.caption)
                .foregroundStyle(.green)

            if !result.failedPaths.isEmpty {
                DisclosureGroup("失败路径") {
                    ForEach(result.failedPaths, id: \.self) { path in
                        Text(path)
                            .font(AppTypography.caption)
                            .foregroundStyle(.secondary)
                            .textSelection(.enabled)
                    }
                }
                .font(AppTypography.captionStrong)
            }
        }
    }

    private var emptyState: some View {
        ScrollView {
            VStack(spacing: AppLayout.sectionSpacing) {
                SectionCard {
                    VStack(spacing: 12) {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.system(size: 40))
                            .foregroundStyle(.green)

                        Text("没有发现残留")
                            .font(AppTypography.pageTitle)

                        Text("扫描未发现任何 Claw 变体相关文件，当前环境已经干净。")
                            .font(AppTypography.body)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: 360)
                    }
                    .frame(maxWidth: .infinity)
                }

                supportedVariantsShowcaseCard
            }
            .padding(AppLayout.pagePadding)
            .frame(maxWidth: AppLayout.contentMaxWidth)
            .frame(maxWidth: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var supportedVariantsShowcaseCard: some View {
        SectionCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top, spacing: 10) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("当前支持扫描的全部变体")
                            .font(AppTypography.sectionTitle)
                        Text("当前版本共覆盖 \(supportedVariantDisplayNames.count) 个变体，包含官方分支、第三方改名版和国产变体。")
                            .font(AppTypography.subtitle)
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
        LazyVGrid(columns: supportedVariantGridColumns, alignment: .leading, spacing: 6) {
            ForEach(supportedVariantDisplayNames, id: \.self) { name in
                Text(name)
                    .font(AppTypography.captionStrong)
                    .foregroundStyle(.primary)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 5)
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
        [GridItem(.adaptive(minimum: 108, maximum: 180), alignment: .leading)]
    }

    private var supportedVariantDisplayNames: [String] {
        ClawVariantRegistry.all.map(\.displayName).sorted()
    }

    private var canStartUninstall: Bool {
        !viewModel.isScanning &&
        !viewModel.isUninstalling &&
        viewModel.selectedDetectedCount > 0 &&
        hasAcknowledgedDeletionRisk
    }

    private var uninstallButtonHelpText: String {
        if viewModel.selectedDetectedCount == 0 {
            return "请先选择至少一个待清理变体。"
        }
        if !hasAcknowledgedDeletionRisk {
            return "请先在“删除前请确认”中勾选风险确认。"
        }
        return "将把选中的路径移入废纸篓。"
    }

    private var acknowledgementDetailText: String {
        "当前选中了 \(viewModel.selectedDetectedCount) 个变体，共 \(viewModel.selectedTargets.count) 项路径（\(fmt(viewModel.selectedTargetSize))）。"
    }

    private var processWarningMessage: String {
        if terminateBeforeUninstall {
            return "本次还会先尝试退出相关进程并卸载 LaunchAgent，运行中的会话或任务可能被中断。"
        }
        return "你已关闭“卸载前退出进程”，占用中的文件可能清理失败，确认这个风险可接受后再继续。"
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
        msg += "\n\n这些内容会被移入废纸篓，可能包含本地配置、缓存、登录状态或下载资源。"
        if terminateBeforeUninstall {
            msg += "\n\n卸载前会先退出运行中的相关进程并卸载 LaunchAgent，未保存的工作可能被打断。"
        } else {
            msg += "\n\n你已关闭自动退出进程，部分文件可能因仍被占用而删除失败。"
        }
        msg += "\n\n如果你还没核对路径，请先取消并返回详情页或导出清单检查。"
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

    private func resetDeletionAcknowledgement() {
        if hasAcknowledgedDeletionRisk {
            hasAcknowledgedDeletionRisk = false
        }
    }

    private func configureWindowAppearance() {
        DispatchQueue.main.async {
            guard let window = NSApp.keyWindow ?? NSApp.windows.first else { return }
            window.toolbarStyle = .unifiedCompact
            window.isMovableByWindowBackground = true
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
