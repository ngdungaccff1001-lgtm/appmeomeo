import SwiftUI
import UIKit

struct ContentView: View {
    @Environment(\.appLanguage) private var language
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @EnvironmentObject private var patchDraftCoordinator: PatchDraftCoordinator
    @State private var tabNavigation: AppTabNavigationState
    @AppStorage(FeatureVisibility.cleanerStorageKey) private var cleanerEnabled = true
    @AppStorage(FeatureVisibility.wallpapersStorageKey) private var wallpapersEnabled = true

    init() {
#if targetEnvironment(simulator)
        let arguments = ProcessInfo.processInfo.arguments
        let initialTab: Int
        if arguments.contains("--simulate-files-tab") {
            initialTab = 1
        } else if arguments.contains("--simulate-patch-tab") {
            initialTab = 2
        } else if arguments.contains("--simulate-cleaner-tab") {
            initialTab = 3
        } else if arguments.contains("--simulate-wallpaper-tab") {
            initialTab = 4
        } else {
            initialTab = 0
        }
        _tabNavigation = State(initialValue: AppTabNavigationState(selectedTab: initialTab))
#else
        _tabNavigation = State(initialValue: AppTabNavigationState())
#endif
    }

    var body: some View {
        Group {
            if horizontalSizeClass == .regular {
                regularLayout
            } else {
                compactLayout
            }
        }
        .tint(AppTheme.accent)
        .imageScale(.small)
        .onChange(of: patchDraftCoordinator.request?.id) { requestID in
            if requestID != nil { tabNavigation.select(AppSection.patches.rawValue) }
        }
        .onChange(of: patchDraftCoordinator.importRequest?.id) { requestID in
            if requestID != nil { tabNavigation.select(AppSection.patches.rawValue) }
        }
        .onChange(of: cleanerEnabled) { _ in
            tabNavigation.reconcileSelection(with: featureVisibility)
        }
        .onChange(of: wallpapersEnabled) { _ in
            tabNavigation.reconcileSelection(with: featureVisibility)
        }
        .onAppear {
            tabNavigation.reconcileSelection(with: featureVisibility)
        }
    }

    private var compactLayout: some View {
        TabView(selection: tabSelection) {
            ForEach(featureVisibility.visibleSections) { section in
                sectionContent(section)
                    .tabItem {
                        CompactTabLabel(
                            title: language.text(section.titleKey),
                            systemImage: section.systemImage
                        )
                    }
                    .tag(section.rawValue)
            }
        }
    }

    private var regularLayout: some View {
        NavigationSplitView {
            List {
                ForEach(featureVisibility.visibleSections) { section in
                    Button {
                        withAnimation(.easeInOut(duration: 0.18)) {
                            tabNavigation.select(section.rawValue)
                        }
                    } label: {
                        Label(language.text(section.titleKey), systemImage: section.systemImage)
                            .fontWeight(section.rawValue == tabNavigation.selectedTab ? .semibold : .regular)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .listRowBackground(
                        section.rawValue == tabNavigation.selectedTab
                            ? AppTheme.accent.opacity(0.14)
                            : Color.clear
                    )
                    .accessibilityAddTraits(
                        section.rawValue == tabNavigation.selectedTab ? .isSelected : []
                    )
                }
            }
            .navigationTitle("3105")
            .navigationSplitViewColumnWidth(min: 210, ideal: 240, max: 300)
        } detail: {
            sectionContent(selectedVisibleSection)
                .id(selectedVisibleSection.rawValue)
        }
        .navigationSplitViewStyle(.balanced)
    }

    @ViewBuilder
    private func sectionContent(_ section: AppSection) -> some View {
        switch section {
        case .home:
            DashboardView(
                cleanerEnabled: $cleanerEnabled,
                wallpapersEnabled: $wallpapersEnabled,
                wallpapersSupported: wallpapersSupported,
                onSelectSection: { targetSection in
                    withAnimation(.spring(response: 0.32, dampingFraction: 0.8)) {
                        tabNavigation.select(targetSection.rawValue)
                    }
                }
            )
        case .files:
            AppDataBrowserView(
                tabSession: filesTabSession
            )
        case .patches:
            PatchProjectsView()
        case .cleaner:
            CleanerView()
        case .wallpapers:
            WallpaperLabView()
        }
    }

    private var tabSelection: Binding<Int> {
        Binding(
            get: { tabNavigation.selectedTab },
            set: { tabNavigation.select($0) }
        )
    }

    private var filesTabSession: Binding<FilesTabSession> {
        Binding(
            get: { tabNavigation.filesTabs },
            set: { tabNavigation.setFilesTabs($0) }
        )
    }

    private var featureVisibility: FeatureVisibility {
        FeatureVisibility(
            cleanerEnabled: cleanerEnabled,
            wallpapersEnabled: wallpapersEnabled,
            wallpapersSupported: wallpapersSupported
        )
    }

    private var wallpapersSupported: Bool {
        WallpaperFeatureSupportPolicy.isSupported(major: AppInfo.versionTuple.major)
    }

    private var selectedVisibleSection: AppSection {
        guard let section = AppSection(rawValue: tabNavigation.selectedTab),
              featureVisibility.isVisible(section) else {
            return .home
        }
        return section
    }
}

private struct CompactTabLabel: View {
    let title: String
    let systemImage: String

    @ViewBuilder
    var body: some View {
        if let image = UIImage(
            systemName: systemImage,
            withConfiguration: UIImage.SymbolConfiguration(pointSize: 17, weight: .medium)
        )?.withRenderingMode(.alwaysTemplate) {
            Image(uiImage: image)
        } else {
            Image(systemName: systemImage)
                .font(.system(size: 17, weight: .medium))
        }
        Text(title)
    }
}

private extension AppSection {
    var titleKey: String {
        switch self {
        case .home: return "tab.home"
        case .files: return "tab.files"
        case .patches: return "tab.patches"
        case .cleaner: return "tab.cleaner"
        case .wallpapers: return "tab.wallpapers"
        }
    }

    var systemImage: String {
        switch self {
        case .home: return "house.fill"
        case .files: return "folder.fill"
        case .patches: return "shippingbox.fill"
        case .cleaner: return "sparkles"
        case .wallpapers: return "photo.on.rectangle.angled"
        }
    }
}

// MARK: - Redesigned Modern Dashboard
private struct DashboardView: View {
    @Environment(\.appLanguage) private var language
    @EnvironmentObject private var appState: AppState
    @State private var showSettings = false
    @State private var showLogs = false
    @Binding var cleanerEnabled: Bool
    @Binding var wallpapersEnabled: Bool
    let wallpapersSupported: Bool
    let onSelectSection: (AppSection) -> Void

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.1"
    }

    private let quickActionColumns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    heroDeviceCard
                    quickActionsGrid
                    featureManagementSection
                    systemHubSection
                }
                .padding(.horizontal, AppTheme.pageInset)
                .padding(.top, 10)
                .padding(.bottom, 32)
            }
            .background(AppTheme.pageBackground.ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .tint(AppTheme.accent)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    HStack(spacing: 8) {
                        AppLogo(size: 28)
                        Text("3105")
                            .font(.system(size: 18, weight: .bold, design: .rounded))
                        Text("v\(appVersion)")
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                            .foregroundStyle(AppTheme.accent)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 3)
                            .background(
                                Capsule()
                                    .fill(AppTheme.accent.opacity(0.14))
                            )
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack(spacing: 8) {
                        Button { showLogs = true } label: {
                            ZStack {
                                Circle()
                                    .fill(Color(uiColor: .secondarySystemFill))
                                    .frame(width: 32, height: 32)
                                Image(systemName: "apple.terminal")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(.primary)
                            }
                        }
                        .accessibilityLabel(language.text("accessibility.open_logs"))

                        Button { showSettings = true } label: {
                            ZStack {
                                Circle()
                                    .fill(Color(uiColor: .secondarySystemFill))
                                    .frame(width: 32, height: 32)
                                Image(systemName: "gearshape.fill")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(.primary)
                            }
                        }
                        .accessibilityLabel(language.text("accessibility.open_settings"))
                    }
                }
            }
            .sheet(isPresented: $showSettings) { SettingsView() }
            .sheet(isPresented: $showLogs) { LogView() }
        }
    }

    // MARK: - Hero Device Card
    private var heroDeviceCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(AppTheme.accentGradient)
                        .shadow(color: AppTheme.accent.opacity(0.3), radius: 8, x: 0, y: 3)

                    Image(systemName: UIDevice.current.userInterfaceIdiom == .pad ? "ipad.gen2" : "iphone.gen3")
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundStyle(.white)
                }
                .frame(width: 48, height: 48)

                VStack(alignment: .leading, spacing: 3) {
                    Text(AppInfo.hardwareDisplayName)
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(.primary)

                    Text("\(AppInfo.displayMachineName) • iOS \(AppInfo.osVersion) (\(AppInfo.osBuild))")
                        .font(.system(size: 13, weight: .regular, design: .monospaced))
                        .foregroundStyle(.secondary)
                }

                Spacer()
            }

            Divider()
                .opacity(0.6)

            HStack(spacing: 8) {
                // Compatibility Status
                if appState.isSupported {
                    AppStatusBadge(
                        title: language.text("settings.supported"),
                        systemImage: "checkmark.circle.fill",
                        type: .success
                    )
                } else {
                    AppStatusBadge(
                        title: language.text("settings.unsupported"),
                        systemImage: "exclamationmark.triangle.fill",
                        type: .error
                    )
                }

                // Kernel Exploit Status (if applicable)
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
                            systemImage: "bolt.slash.fill",
                            type: .neutral
                        )
                    }
                }

                Spacer()
            }

            // Enterprise signing footnote
            HStack(spacing: 6) {
                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(AppTheme.accent)
                Text(language.text("dashboard.enterprise_badge"))
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
            }
            .padding(.top, 2)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: AppTheme.cardCornerRadius, style: .continuous)
                .fill(AppTheme.cardBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: AppTheme.cardCornerRadius, style: .continuous)
                        .stroke(AppTheme.cardBorder, lineWidth: 1)
                )
                .shadow(color: Color.black.opacity(0.04), radius: 10, x: 0, y: 3)
        )
    }

    // MARK: - Quick Actions Grid
    private var quickActionsGrid: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(language.text("dashboard.quick_actions"))
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 4)

            LazyVGrid(columns: quickActionColumns, spacing: 12) {
                // App Data Browser
                AppQuickActionCard(
                    title: language.text("tab.files"),
                    subtitle: language.text("dashboard.quick_files_desc"),
                    systemImage: "folder.fill",
                    gradient: AppTheme.filesGradient,
                    action: { onSelectSection(.files) }
                )

                // Patch Workspace
                AppQuickActionCard(
                    title: language.text("tab.patches"),
                    subtitle: language.text("dashboard.quick_patches_desc"),
                    systemImage: "shippingbox.fill",
                    gradient: AppTheme.patchesGradient,
                    action: { onSelectSection(.patches) }
                )

                // Limited Cleaner
                AppQuickActionCard(
                    title: language.text("tab.cleaner"),
                    subtitle: language.text("dashboard.quick_cleaner_desc"),
                    systemImage: "sparkles",
                    gradient: AppTheme.cleanerGradient,
                    action: {
                        if !cleanerEnabled { cleanerEnabled = true }
                        onSelectSection(.cleaner)
                    }
                )

                // Wallpaper Lab
                if wallpapersSupported {
                    AppQuickActionCard(
                        title: language.text("tab.wallpapers"),
                        subtitle: language.text("dashboard.quick_wallpapers_desc"),
                        systemImage: "photo.on.rectangle.angled",
                        gradient: AppTheme.wallpapersGradient,
                        action: {
                            if !wallpapersEnabled { wallpapersEnabled = true }
                            onSelectSection(.wallpapers)
                        }
                    )
                }
            }
        }
    }

    // MARK: - Feature Management Section
    private var featureManagementSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(language.text("dashboard.features"))
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.secondary)
                Spacer()
            }
            .padding(.horizontal, 4)

            VStack(spacing: 8) {
                AppFeatureToggleCard(
                    title: language.text("tab.cleaner"),
                    subtitle: language.text("dashboard.quick_cleaner_desc"),
                    systemImage: "sparkles",
                    gradient: AppTheme.cleanerGradient,
                    isOn: $cleanerEnabled
                )

                if wallpapersSupported {
                    AppFeatureToggleCard(
                        title: language.text("tab.wallpapers"),
                        subtitle: language.text("dashboard.quick_wallpapers_desc"),
                        systemImage: "photo.on.rectangle.angled",
                        gradient: AppTheme.wallpapersGradient,
                        isOn: $wallpapersEnabled
                    )
                }
            }

            Text(language.text("dashboard.features_footer"))
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 6)
                .padding(.top, 2)
        }
    }

    // MARK: - System Overview & Hub
    private var systemHubSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(language.text("dashboard.system_overview"))
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 4)

            VStack(spacing: 8) {
                // Logs row
                Button {
                    showLogs = true
                } label: {
                    HStack(spacing: 14) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(Color.secondary.opacity(0.14))
                            Image(systemName: "apple.terminal")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(.primary)
                        }
                        .frame(width: 36, height: 36)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(language.text("log.title"))
                                .font(.system(size: 15, weight: .medium))
                                .foregroundStyle(.primary)

                            Text(language.text("dashboard.system_logs_desc"))
                                .font(.system(size: 12))
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        Image(systemName: "chevron.right")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(.tertiary)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(AppTheme.cardBackground)
                            .overlay(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .stroke(AppTheme.cardBorder, lineWidth: 1)
                            )
                    )
                }
                .buttonStyle(AppScaleButtonStyle())

                // Settings row
                Button {
                    showSettings = true
                } label: {
                    HStack(spacing: 14) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(Color.secondary.opacity(0.14))
                            Image(systemName: "gearshape.fill")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(.primary)
                        }
                        .frame(width: 36, height: 36)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(language.text("settings.title"))
                                .font(.system(size: 15, weight: .medium))
                                .foregroundStyle(.primary)

                            Text(language.text("dashboard.system_settings_desc"))
                                .font(.system(size: 12))
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        Image(systemName: "chevron.right")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(.tertiary)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(AppTheme.cardBackground)
                            .overlay(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .stroke(AppTheme.cardBorder, lineWidth: 1)
                            )
                    )
                }
                .buttonStyle(AppScaleButtonStyle())
            }
        }
    }
}
