import SwiftUI
import UIKit

struct ContentView: View {
    @Environment(\.appLanguage) private var language
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @EnvironmentObject private var patchDraftCoordinator: PatchDraftCoordinator
    @State private var tabNavigation: AppTabNavigationState
    @State private var isSidebarOpen = false
    @AppStorage("app.appearance") private var appearance = AppAppearance.system.rawValue

    init() {
#if targetEnvironment(simulator)
        let arguments = ProcessInfo.processInfo.arguments
        let initialTab: Int
        if arguments.contains("--simulate-files-tab") {
            initialTab = 1
        } else if arguments.contains("--simulate-patch-tab") {
            initialTab = 2
        } else {
            initialTab = 0
        }
        _tabNavigation = State(initialValue: AppTabNavigationState(selectedTab: initialTab))
#else
        _tabNavigation = State(initialValue: AppTabNavigationState())
#endif
    }

    var body: some View {
        ZStack(alignment: .leading) {
            // Main Content Area (Full screen, NO Bottom TabBar)
            mainContent
                .tint(AppTheme.accent)
                .imageScale(.small)
                .disabled(isSidebarOpen)

            // Dimmed Overlay when Sidebar is active
            if isSidebarOpen {
                Color.black.opacity(0.5)
                    .ignoresSafeArea()
                    .onTapGesture {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            isSidebarOpen = false
                        }
                    }
                    .transition(.opacity)
                    .zIndex(10)
            }

            // Collapsible Sidebar Drawer Navigation
            if isSidebarOpen {
                sidebarDrawer
                    .transition(.move(edge: .leading))
                    .zIndex(11)
            }
        }
        .onChange(of: patchDraftCoordinator.request?.id) { requestID in
            if requestID != nil { tabNavigation.select(AppSection.patches.rawValue) }
        }
        .onChange(of: patchDraftCoordinator.importRequest?.id) { requestID in
            if requestID != nil { tabNavigation.select(AppSection.patches.rawValue) }
        }
    }

    // MARK: - Main Content View (Without bottom tab bar)
    @ViewBuilder
    private var mainContent: some View {
        sectionContent(selectedVisibleSection)
            .id(selectedVisibleSection.rawValue)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Collapsible Sidebar Drawer
    private var sidebarDrawer: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack(spacing: 10) {
                AppLogo(size: 34)
                VStack(alignment: .leading, spacing: 1) {
                    Text("MeoMeoPath")
                        .font(.system(size: 16, weight: .bold, design: .monospaced))
                    Text("PAYLOAD MEOMEO.APP")
                        .font(.system(size: 8, weight: .bold, design: .monospaced))
                        .foregroundStyle(AppTheme.accent)
                }
                Spacer()
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        isSidebarOpen = false
                    }
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(.secondary)
                        .frame(width: 30, height: 30)
                        .background(Color(uiColor: .tertiarySystemFill), in: Rectangle())
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 50)
            .padding(.bottom, 16)
            .background(Color(uiColor: .secondarySystemBackground))

            Divider()

            // Appearance Switcher
            VStack(alignment: .leading, spacing: 8) {
                Text("GIAO DIỆN / THEME")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 16)
                    .padding(.top, 14)

                HStack(spacing: 6) {
                    ForEach(AppAppearance.allCases) { item in
                        Button {
                            withAnimation(.easeInOut(duration: 0.15)) {
                                appearance = item.rawValue
                            }
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: item.iconName)
                                    .font(.system(size: 11, weight: .bold))
                                Text(item.displayName)
                                    .font(.system(size: 11, weight: .bold))
                            }
                            .frame(maxWidth: .infinity, minHeight: 32)
                            .background(
                                appearance == item.rawValue
                                    ? AppTheme.accent
                                    : Color(uiColor: .tertiarySystemFill)
                            )
                            .foregroundStyle(appearance == item.rawValue ? Color.white : Color.primary)
                            .overlay(
                                Rectangle()
                                    .stroke(appearance == item.rawValue ? Color.clear : AppTheme.cardBorder, lineWidth: 1)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 16)
            }

            Divider()
                .padding(.top, 14)

            // Sidebar Navigation Items
            ScrollView {
                VStack(alignment: .leading, spacing: 4) {
                    Text("ĐIỀU HƯỚNG / MODULES")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 16)
                        .padding(.top, 12)
                        .padding(.bottom, 4)

                    ForEach(featureVisibility.visibleSections) { section in
                        Button {
                            withAnimation(.easeInOut(duration: 0.18)) {
                                tabNavigation.select(section.rawValue)
                                isSidebarOpen = false
                            }
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: section.systemImage)
                                    .font(.system(size: 15, weight: .bold))
                                    .frame(width: 24)
                                    .foregroundStyle(
                                        section.rawValue == tabNavigation.selectedTab
                                            ? AppTheme.accent
                                            : Color.secondary
                                    )

                                Text(section == .patches ? "Function" : language.text(section.titleKey))
                                    .font(.system(size: 14, weight: section.rawValue == tabNavigation.selectedTab ? .bold : .medium))
                                    .foregroundStyle(
                                        section.rawValue == tabNavigation.selectedTab
                                            ? Color.primary
                                            : Color.secondary
                                    )

                                Spacer()

                                if section.rawValue == tabNavigation.selectedTab {
                                    Rectangle()
                                        .fill(AppTheme.accent)
                                        .frame(width: 3, height: 18)
                                }
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .background(
                                section.rawValue == tabNavigation.selectedTab
                                    ? AppTheme.accent.opacity(0.12)
                                    : Color.clear
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.bottom, 20)
            }

            Divider()

            // Footer
            HStack {
                Text("\(AppInfo.displayMachineName) • iOS \(AppInfo.osVersion)")
                    .font(.system(size: 11, weight: .regular, design: .monospaced))
                    .foregroundStyle(.secondary)
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color(uiColor: .secondarySystemBackground))
        }
        .frame(width: 280)
        .frame(maxHeight: .infinity)
        .background(Color(uiColor: .systemBackground))
        .overlay(
            Rectangle()
                .stroke(AppTheme.cardBorder, lineWidth: 1)
        )
        .ignoresSafeArea()
    }

    @ViewBuilder
    private func sectionContent(_ section: AppSection) -> some View {
        switch section {
        case .home:
            DashboardView(
                onToggleSidebar: {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        isSidebarOpen.toggle()
                    }
                },
                onSelectSection: { targetSection in
                    withAnimation(.easeInOut(duration: 0.18)) {
                        tabNavigation.select(targetSection.rawValue)
                    }
                }
            )
        case .files:
            AppDataBrowserView(
                tabSession: filesTabSession,
                onToggleSidebar: {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        isSidebarOpen.toggle()
                    }
                }
            )
        case .patches:
            PatchProjectsView(
                onToggleSidebar: {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        isSidebarOpen.toggle()
                    }
                }
            )
        }
    }

    private var filesTabSession: Binding<FilesTabSession> {
        Binding(
            get: { tabNavigation.filesTabs },
            set: { tabNavigation.setFilesTabs($0) }
        )
    }

    private var featureVisibility: FeatureVisibility {
        FeatureVisibility()
    }

    private var selectedVisibleSection: AppSection {
        guard let section = AppSection(rawValue: tabNavigation.selectedTab) else {
            return .home
        }
        return section
    }
}

private extension AppSection {
    var titleKey: String {
        switch self {
        case .home: return "tab.home"
        case .files: return "tab.files"
        case .patches: return "tab.patches"
        }
    }

    var systemImage: String {
        switch self {
        case .home: return "terminal"
        case .files: return "folder"
        case .patches: return "bolt.shield.fill"
        }
    }
}

// MARK: - Sharp Industrial Dashboard (MeoMeoPath Red Edition)
private struct DashboardView: View {
    @Environment(\.appLanguage) private var language
    @EnvironmentObject private var appState: AppState
    @State private var showSettings = false
    @State private var showLogs = false
    @AppStorage("app.appearance") private var appearance = AppAppearance.system.rawValue
    let onToggleSidebar: () -> Void
    let onSelectSection: (AppSection) -> Void

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.1.1"
    }

    private let quickActionColumns = [
        GridItem(.flexible(), spacing: 10),
        GridItem(.flexible(), spacing: 10)
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 14) {
                    // Cyber HUD Scanner Animation Effect
                    AppCyberPulseScanner()

                    // Hero Inspector Card
                    heroInspectorCard

                    // Quick Actions
                    quickActionsGrid

                    // Appearance Switcher
                    appearanceSection

                    // System Hub
                    systemHubSection
                }
                .padding(.horizontal, AppTheme.pageInset)
                .padding(.top, 10)
                .padding(.bottom, 26)
            }
            .background(AppTheme.pageBackground.ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .tint(AppTheme.accent)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: onToggleSidebar) {
                        HStack(spacing: 6) {
                            Image(systemName: "line.3.horizontal")
                                .font(.system(size: 15, weight: .bold))
                                .frame(width: 32, height: 32)
                                .background(Color(uiColor: .secondarySystemFill))
                                .overlay(
                                    Rectangle().stroke(AppTheme.cardBorder, lineWidth: 1)
                                )

                            Text("MeoMeoPath")
                                .font(.system(size: 16, weight: .bold, design: .monospaced))
                                .foregroundStyle(.primary)
                        }
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack(spacing: 6) {
                        Button { showLogs = true } label: {
                            Image(systemName: "apple.terminal")
                                .font(.system(size: 13, weight: .bold))
                                .frame(width: 32, height: 32)
                                .background(Color(uiColor: .secondarySystemFill))
                                .overlay(
                                    Rectangle().stroke(AppTheme.cardBorder, lineWidth: 1)
                                )
                        }
                        .accessibilityLabel(language.text("accessibility.open_logs"))

                        Button { showSettings = true } label: {
                            Image(systemName: "gearshape.fill")
                                .font(.system(size: 13, weight: .bold))
                                .frame(width: 32, height: 32)
                                .background(Color(uiColor: .secondarySystemFill))
                                .overlay(
                                    Rectangle().stroke(AppTheme.cardBorder, lineWidth: 1)
                                )
                        }
                        .accessibilityLabel(language.text("accessibility.open_settings"))
                    }
                }
            }
            .sheet(isPresented: $showSettings) { SettingsView() }
            .sheet(isPresented: $showLogs) { LogView() }
        }
    }

    // MARK: - Sharp Hero Inspector Card
    private var heroInspectorCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center, spacing: 10) {
                ZStack {
                    Rectangle()
                        .fill(AppTheme.accent.opacity(0.15))
                        .overlay(
                            Rectangle().stroke(AppTheme.accent.opacity(0.4), lineWidth: 1)
                        )
                    Image(systemName: "cpu")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(AppTheme.accent)
                }
                .frame(width: 36, height: 36)

                VStack(alignment: .leading, spacing: 2) {
                    Text(AppInfo.hardwareDisplayName.uppercased())
                        .font(.system(size: 15, weight: .bold, design: .monospaced))
                        .foregroundStyle(.primary)

                    Text("\(AppInfo.displayMachineName) • iOS \(AppInfo.osVersion) (\(AppInfo.osBuild))")
                        .font(.system(size: 12, weight: .regular, design: .monospaced))
                        .foregroundStyle(.secondary)
                }

                Spacer()
            }

            Divider()

            // Status Badges Row
            HStack(spacing: 6) {
                if appState.isSupported {
                    AppStatusBadge(
                        title: language.text("settings.supported"),
                        systemImage: "checkmark",
                        type: .success
                    )
                } else {
                    AppStatusBadge(
                        title: language.text("settings.unsupported"),
                        systemImage: "xmark",
                        type: .error
                    )
                }

                if appState.kernelExploitApplicable && AppInfo.versionTuple.major < 26 {
                    if appState.kernelExploitRunning {
                        AppStatusBadge(
                            title: language.text("dashboard.kernel_running"),
                            type: .running
                        )
                    } else if appState.exploitStatus.isSuccess {
                        AppStatusBadge(
                            title: language.text("dashboard.kernel_active"),
                            systemImage: "bolt.fill",
                            type: .success
                        )
                    } else {
                        AppStatusBadge(
                            title: language.text("dashboard.kernel_inactive"),
                            systemImage: "bolt.slash",
                            type: .neutral
                        )
                    }
                }

                Spacer()

                Text("ENTERPRISE")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(Color(uiColor: .tertiarySystemFill))
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: AppTheme.cardCornerRadius, style: .continuous)
                .fill(AppTheme.cardBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: AppTheme.cardCornerRadius, style: .continuous)
                        .stroke(AppTheme.cardBorder, lineWidth: 1)
                )
        )
    }

    // MARK: - Quick Actions Grid (Tệp & Function / Free Fire)
    private var quickActionsGrid: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("THAO TÁC / QUICK ACTIONS")
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundStyle(.secondary)

            LazyVGrid(columns: quickActionColumns, spacing: 8) {
                AppQuickActionCard(
                    title: language.text("tab.files"),
                    subtitle: language.text("dashboard.quick_files_desc"),
                    systemImage: "folder",
                    tint: AppTheme.filesTint,
                    action: { onSelectSection(.files) }
                )

                AppQuickActionCard(
                    title: "Function",
                    subtitle: "Payload & Free Fire Patch Hub",
                    systemImage: "bolt.shield.fill",
                    tint: AppTheme.patchesTint,
                    action: { onSelectSection(.patches) }
                )
            }
        }
    }

    // MARK: - Appearance Selector Section
    private var appearanceSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("CHẾ ĐỘ HIỂN THỊ / THEME")
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundStyle(.secondary)

            HStack(spacing: 6) {
                ForEach(AppAppearance.allCases) { item in
                    Button {
                        withAnimation(.easeInOut(duration: 0.15)) {
                            appearance = item.rawValue
                        }
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: item.iconName)
                                .font(.system(size: 12, weight: .bold))
                            Text(item.displayName)
                                .font(.system(size: 12, weight: .bold))
                        }
                        .frame(maxWidth: .infinity, minHeight: 34)
                        .background(
                            appearance == item.rawValue
                                ? AppTheme.accent
                                : AppTheme.cardBackground
                        )
                        .foregroundStyle(appearance == item.rawValue ? Color.white : Color.primary)
                        .overlay(
                            Rectangle()
                                .stroke(appearance == item.rawValue ? Color.clear : AppTheme.cardBorder, lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: - System Hub Section
    private var systemHubSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("HỆ THỐNG / LOGS & SETTINGS")
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundStyle(.secondary)

            VStack(spacing: 6) {
                Button {
                    showLogs = true
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "apple.terminal")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(.primary)

                        VStack(alignment: .leading, spacing: 1) {
                            Text(language.text("log.title"))
                                .font(.system(size: 13, weight: .bold))
                                .foregroundStyle(.primary)
                            Text(language.text("dashboard.system_logs_desc"))
                                .font(.system(size: 11))
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        Image(systemName: "chevron.right")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(.tertiary)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: AppTheme.cardCornerRadius, style: .continuous)
                            .fill(AppTheme.cardBackground)
                            .overlay(
                                RoundedRectangle(cornerRadius: AppTheme.cardCornerRadius, style: .continuous)
                                    .stroke(AppTheme.cardBorder, lineWidth: 1)
                            )
                    )
                }
                .buttonStyle(AppScaleButtonStyle())

                Button {
                    showSettings = true
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "gearshape.fill")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(.primary)

                        VStack(alignment: .leading, spacing: 1) {
                            Text(language.text("settings.title"))
                                .font(.system(size: 13, weight: .bold))
                                .foregroundStyle(.primary)
                            Text(language.text("dashboard.system_settings_desc"))
                                .font(.system(size: 11))
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        Image(systemName: "chevron.right")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(.tertiary)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: AppTheme.cardCornerRadius, style: .continuous)
                            .fill(AppTheme.cardBackground)
                            .overlay(
                                RoundedRectangle(cornerRadius: AppTheme.cardCornerRadius, style: .continuous)
                                    .stroke(AppTheme.cardBorder, lineWidth: 1)
                            )
                    )
                }
                .buttonStyle(AppScaleButtonStyle())
            }
        }
    }
}
