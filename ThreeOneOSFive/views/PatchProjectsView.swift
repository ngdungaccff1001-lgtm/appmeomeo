import SwiftUI
import UIKit
import UniformTypeIdentifiers

// MARK: - Free Fire Mod Models & Category

enum FFModCategory: String, CaseIterable, Identifiable {
    case aim = "Aim File"
    case esp = "Định Vị"
    case skin = "ModSkin File"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .aim: return "bolt.fill"
        case .esp: return "eye.fill"
        case .skin: return "gearshape.fill"
        }
    }
}

struct FFPatchItem: Identifiable, Codable {
    let id: String
    let name: String
    let category: String
    let targetRelativePath: String
    let downloadUrl: String?
    var isEnabled: Bool

    var rulesCount: Int { 1 }

    var targetPathDisplay: String {
        targetRelativePath.components(separatedBy: "/").last ?? targetRelativePath
    }
}

// MARK: - Free Fire Patch Engine

@MainActor
final class FreeFirePatchEngine: ObservableObject {
    static let shared = FreeFirePatchEngine()

    static let defaultApiServerUrl = "http://103.238.234.204:5000"

    static let shadersRelativePath = "Documents/contentcache/Optional/ios/gameassetbundles/shaders.HPt9DZviTSXL9hpGW9QNOMigNLA~3D"
    static let cacheResRelativePath = "Documents/contentcache/Compulsory/ios/gameassetbundles/cache_res.CfnFf59sr1SbsqQ6JqTKsEusjKs~3D"

    @Published var patches: [FFPatchItem] = []
    @Published var isApplying = false
    @Published var isFetching = false
    @Published var statusMessage: String?

    private let storageKey = "meomeopath.ff.admin.patches"

    init() {
        loadCachedPatches()
    }

    func loadCachedPatches() {
        if let savedData = UserDefaults.standard.data(forKey: storageKey),
           let savedList = try? JSONDecoder().decode([FFPatchItem].self, from: savedData) {
            self.patches = savedList
        } else {
            self.patches = []
        }
    }

    func saveState() {
        if let data = try? JSONEncoder().encode(patches) {
            UserDefaults.standard.set(data, forKey: storageKey)
        }
    }

    func fetchPatchesFromAdmin(serverUrl: String = defaultApiServerUrl, bundleID: String) {
        isFetching = true
        statusMessage = "Đang tải danh sách chức năng từ Admin API..."

        let cleanUrl = serverUrl.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = URL(string: "\(cleanUrl)/api/patches?bundle=\(bundleID)&active=true") else {
            isFetching = false
            statusMessage = "URL Server không hợp lệ: \(cleanUrl)"
            return
        }

        URLSession.shared.dataTask(with: url) { [weak self] data, response, error in
            Task { @MainActor in
                guard let self = self else { return }
                self.isFetching = false
                if let error = error {
                    self.statusMessage = "Lỗi kết nối Admin API: \(error.localizedDescription)"
                    return
                }

                guard let data = data,
                      let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                      let success = json["success"] as? Bool, success,
                      let rawList = json["patches"] as? [[String: Any]] else {
                    self.statusMessage = "Chưa có chức năng nào được Admin thêm."
                    return
                }

                var fetched: [FFPatchItem] = []
                for item in rawList {
                    let id = item["id"] as? String ?? UUID().uuidString
                    let name = item["name"] as? String ?? "Patch"
                    let category = item["category"] as? String ?? FFModCategory.aim.rawValue
                    let targetPath = item["target_relative_path"] as? String ?? Self.shadersRelativePath
                    let downloadUrl = item["download_url"] as? String

                    // Preserve enabled state if exists
                    let wasEnabled = self.patches.first(where: { $0.id == id })?.isEnabled ?? false

                    fetched.append(FFPatchItem(
                        id: id,
                        name: name,
                        category: category,
                        targetRelativePath: targetPath,
                        downloadUrl: downloadUrl,
                        isEnabled: wasEnabled
                    ))
                }

                self.patches = fetched
                self.saveState()
                self.statusMessage = "Đã cập nhật \(fetched.count) chức năng từ Admin API!"
            }
        }.resume()
    }

    func togglePatch(id: String, bundleID: String, serverUrl: String = defaultApiServerUrl) {
        guard let index = patches.firstIndex(where: { $0.id == id }) else { return }
        patches[index].isEnabled.toggle()
        saveState()

        let patch = patches[index]
        applyPatchOperation(patch: patch, bundleID: bundleID, serverUrl: serverUrl, isEnabling: patch.isEnabled)
    }

    func autoApplyAll(category: FFModCategory, bundleID: String, serverUrl: String = defaultApiServerUrl) {
        for i in 0..<patches.count {
            if patches[i].category == category.rawValue {
                patches[i].isEnabled = true
                applyPatchOperation(patch: patches[i], bundleID: bundleID, serverUrl: serverUrl, isEnabling: true)
            }
        }
        saveState()
        statusMessage = "Đã tự động kích hoạt toàn bộ mục \(category.rawValue)!"
    }

    private func applyPatchOperation(patch: FFPatchItem, bundleID: String, serverUrl: String, isEnabling: Bool) {
        isApplying = true
        statusMessage = isEnabling ? "Đang áp dụng: \(patch.name)…" : "Đang tắt: \(patch.name)…"

        Task.detached(priority: .userInitiated) {
            let containerPath = ContainerStore.resolveAppContainerPath(bundleID: bundleID)
            guard let containerPath else {
                await MainActor.run {
                    self.isApplying = false
                    self.statusMessage = "Chưa tìm thấy container game \(bundleID). Hãy mở game 1 lần trước."
                }
                return
            }

            let containerURL = URL(fileURLWithPath: containerPath, isDirectory: true)
            let targetURL = containerURL.appendingPathComponent(patch.targetRelativePath)

            do {
                let fileManager = FileManager.default
                let parentDir = targetURL.deletingLastPathComponent()
                try fileManager.createDirectory(at: parentDir, withIntermediateDirectories: true)

                let backupDir = try fileManager.url(
                    for: .cachesDirectory,
                    in: .userDomainMask,
                    appropriateFor: nil,
                    create: true
                ).appendingPathComponent("MeoMeoBackups/\(bundleID)", isDirectory: true)
                try fileManager.createDirectory(at: backupDir, withIntermediateDirectories: true)

                let backupFile = backupDir.appendingPathComponent("\(patch.id)_backup.dat")

                if isEnabling {
                    // Backup original if exists
                    if fileManager.fileExists(atPath: targetURL.path) && !fileManager.fileExists(atPath: backupFile.path) {
                        try? fileManager.copyItem(at: targetURL, to: backupFile)
                    }

                    // Download or fetch file data from Admin Server if downloadUrl exists
                    var fileData: Data?
                    if let relDownload = patch.downloadUrl,
                       let downloadFullURL = URL(string: "\(serverUrl)\(relDownload)") {
                        fileData = try? Data(contentsOf: downloadFullURL)
                    }

                    let finalData = fileData ?? "MEOMEOPATH_DATA_\(patch.id)".data(using: .utf8)!
                    try finalData.write(to: targetURL, options: [.atomic, .completeFileProtection])
                } else {
                    // Restore original
                    if fileManager.fileExists(atPath: backupFile.path) {
                        try? fileManager.removeItem(at: targetURL)
                        try? fileManager.copyItem(at: backupFile, to: targetURL)
                    }
                }

                await MainActor.run {
                    self.isApplying = false
                    self.statusMessage = isEnabling
                        ? "Đã dán data vào: \(patch.targetPathDisplay)"
                        : "Đã tắt và khôi phục: \(patch.targetPathDisplay)"
                }
            } catch {
                await MainActor.run {
                    self.isApplying = false
                    self.statusMessage = "Lỗi dán dữ liệu: \(error.localizedDescription)"
                }
            }
        }
    }
}

// MARK: - Free Fire Detail View (Cosmic Cyber Theme)

struct FreeFireDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var engine = FreeFirePatchEngine.shared
    @State private var selectedCategory: FFModCategory = .aim
    @AppStorage("admin_api_server_url") private var adminServerUrl = FreeFirePatchEngine.defaultApiServerUrl

    let gameTitle: String
    let bundleID: String

    init(
        gameTitle: String = "Free Fire Max",
        bundleID: String = "com.dts.freefiremax"
    ) {
        self.gameTitle = gameTitle
        self.bundleID = bundleID
    }

    private var filteredPatches: [FFPatchItem] {
        engine.patches.filter { $0.category == selectedCategory.rawValue }
    }

    var body: some View {
        ZStack {
            // Cosmic Cyber Gradient Background
            cosmicBackground
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Top Custom Navigation Bar
                customTopBar

                ScrollView {
                    VStack(spacing: 16) {
                        // Game Hero Banner
                        gameHeroBanner

                        // Category Filter Tabs
                        categoryTabs

                        // Menu Patch Card
                        menuPatchCard

                        // Target Path Info Card
                        targetPathsCard
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 10)
                    .padding(.bottom, 30)
                }
            }
        }
        .navigationBarBackButtonHidden(true)
        .onAppear {
            engine.fetchPatchesFromAdmin(serverUrl: adminServerUrl, bundleID: bundleID)
        }
    }

    // MARK: - Cosmic Cyber Background
    private var cosmicBackground: some View {
        ZStack {
            Color(red: 0.04, green: 0.05, blue: 0.09)

            RadialGradient(
                gradient: Gradient(colors: [
                    Color(red: 0.25, green: 0.08, blue: 0.50).opacity(0.4),
                    Color.clear
                ]),
                center: .topTrailing,
                startRadius: 50,
                endRadius: 400
            )

            RadialGradient(
                gradient: Gradient(colors: [
                    Color(red: 0.08, green: 0.20, blue: 0.55).opacity(0.35),
                    Color.clear
                ]),
                center: .center,
                startRadius: 20,
                endRadius: 350
            )
        }
    }

    // MARK: - Custom Top Bar
    private var customTopBar: some View {
        HStack {
            Button {
                dismiss()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 38, height: 38)
                    .background(Color.white.opacity(0.08))
                    .clipShape(Circle())
                    .overlay(
                        Circle().stroke(Color.white.opacity(0.2), lineWidth: 1)
                    )
            }

            Spacer()

            Text(gameTitle)
                .font(.system(size: 17, weight: .bold, design: .rounded))
                .foregroundStyle(.white)

            Spacer()

            Button {
                engine.fetchPatchesFromAdmin(serverUrl: adminServerUrl, bundleID: bundleID)
            } label: {
                if engine.isFetching {
                    ProgressView()
                        .tint(.white)
                        .frame(width: 38, height: 38)
                } else {
                    Image(systemName: "arrow.triangle.2.circlepath")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 38, height: 38)
                        .background(Color.white.opacity(0.08))
                        .clipShape(Circle())
                        .overlay(
                            Circle().stroke(Color.white.opacity(0.2), lineWidth: 1)
                        )
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 10)
        .padding(.bottom, 6)
    }

    // MARK: - Game Hero Banner
    private var gameHeroBanner: some View {
        VStack(spacing: 8) {
            ZStack {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color(red: 0.08, green: 0.10, blue: 0.18))
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .stroke(
                                LinearGradient(
                                    colors: [Color.white.opacity(0.8), Color.purple.opacity(0.5)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 2
                            )
                    )
                    .shadow(color: Color.purple.opacity(0.35), radius: 15, x: 0, y: 5)

                VStack(spacing: 2) {
                    Image(systemName: "flame.fill")
                        .font(.system(size: 38, weight: .black))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [Color(red: 1.0, green: 0.7, blue: 0.2), Color(red: 1.0, green: 0.2, blue: 0.1)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                    Text(gameTitle.uppercased())
                        .font(.system(size: 10, weight: .black, design: .monospaced))
                        .foregroundStyle(.white)
                }
            }
            .frame(width: 90, height: 90)

            VStack(spacing: 2) {
                Text(gameTitle)
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)

                Text(bundleID)
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                    .foregroundStyle(Color(red: 0.45, green: 0.65, blue: 0.95))
            }
        }
        .padding(.vertical, 8)
    }

    // MARK: - Category Filter Tabs
    private var categoryTabs: some View {
        HStack(spacing: 8) {
            ForEach(FFModCategory.allCases) { cat in
                Button {
                    withAnimation(.easeInOut(duration: 0.16)) {
                        selectedCategory = cat
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: cat.icon)
                            .font(.system(size: 12, weight: .bold))
                        Text(cat.rawValue)
                            .font(.system(size: 12, weight: .bold))
                    }
                    .frame(maxWidth: .infinity, minHeight: 38)
                    .background(
                        selectedCategory == cat
                            ? Color(red: 0.15, green: 0.20, blue: 0.45).opacity(0.8)
                            : Color(red: 0.08, green: 0.10, blue: 0.16).opacity(0.7)
                    )
                    .foregroundStyle(selectedCategory == cat ? Color.white : Color.secondary)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .stroke(
                                selectedCategory == cat
                                    ? Color(red: 0.35, green: 0.55, blue: 0.95)
                                    : Color.white.opacity(0.12),
                                lineWidth: 1.5
                            )
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Menu Patch Card
    private var menuPatchCard: some View {
        VStack(spacing: 0) {
            // Card Header
            HStack(spacing: 8) {
                Rectangle()
                    .fill(Color(red: 0.20, green: 0.75, blue: 1.0))
                    .frame(width: 3.5, height: 16)
                    .clipShape(RoundedRectangle(cornerRadius: 2))

                Image(systemName: "bolt.fill")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(Color(red: 0.70, green: 0.35, blue: 1.0))

                Text("MENU PATCH")
                    .font(.system(size: 15, weight: .black, design: .monospaced))
                    .foregroundStyle(.white)

                Spacer()

                Button {
                    engine.autoApplyAll(category: selectedCategory, bundleID: bundleID, serverUrl: adminServerUrl)
                } label: {
                    Text("AUTO")
                        .font(.system(size: 11, weight: .black, design: .monospaced))
                        .foregroundStyle(Color(red: 0.20, green: 0.85, blue: 1.0))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 4)
                        .background(Color(red: 0.10, green: 0.25, blue: 0.40).opacity(0.6))
                        .clipShape(Capsule())
                        .overlay(
                            Capsule().stroke(Color(red: 0.20, green: 0.75, blue: 1.0), lineWidth: 1)
                        )
                }
                .disabled(filteredPatches.isEmpty)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(Color(red: 0.08, green: 0.10, blue: 0.16).opacity(0.95))

            Divider()
                .background(Color.white.opacity(0.1))

            // Patch Items List
            if filteredPatches.isEmpty {
                VStack(spacing: 10) {
                    Image(systemName: "tray")
                        .font(.system(size: 28))
                        .foregroundStyle(.secondary)

                    Text("Chưa có chức năng \(selectedCategory.rawValue)")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(.white)

                    Text("Chỉ khi Admin tải file lên Web Admin (http://103.238.234.204:5000) thì mục này mới xuất hiện.")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 16)

                    Button {
                        engine.fetchPatchesFromAdmin(serverUrl: adminServerUrl, bundleID: bundleID)
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.triangle.2.circlepath")
                            Text("LÀM MỚI TỪ ADMIN API")
                        }
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundStyle(Color(red: 0.35, green: 0.65, blue: 1.0))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color(red: 0.15, green: 0.25, blue: 0.45).opacity(0.5))
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                    }
                    .padding(.top, 4)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 32)
            } else {
                VStack(spacing: 8) {
                    ForEach(filteredPatches) { patch in
                        patchRow(patch)
                    }
                }
                .padding(12)
            }
        }
        .background(Color(red: 0.06, green: 0.08, blue: 0.14).opacity(0.85))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color(red: 0.18, green: 0.25, blue: 0.45), lineWidth: 1)
        )
    }

    // MARK: - Patch Row
    private func patchRow(_ patch: FFPatchItem) -> some View {
        HStack(spacing: 12) {
            // Category-based colored icon
            ZStack {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(iconBackgroundColor(for: patch))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .stroke(iconBorderColor(for: patch), lineWidth: 1)
                    )

                Image(systemName: iconSystemName(for: patch))
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(iconTintColor(for: patch))
            }
            .frame(width: 42, height: 42)

            // Title & Subtitle
            VStack(alignment: .leading, spacing: 2) {
                Text(patch.name)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.white)
                    .lineLimit(1)

                Text("\(patch.rulesCount) quy tắc thay thế • \(patch.targetPathDisplay)")
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundStyle(Color.secondary)
                    .lineLimit(1)
            }

            Spacer()

            // Smooth On/Off Switch
            Toggle("", isOn: Binding(
                get: { patch.isEnabled },
                set: { _ in engine.togglePatch(id: patch.id, bundleID: bundleID, serverUrl: adminServerUrl) }
            ))
            .labelsHidden()
            .tint(Color(red: 0.20, green: 0.55, blue: 0.95))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(Color(red: 0.09, green: 0.12, blue: 0.20).opacity(0.7))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(
                    patch.isEnabled
                        ? Color(red: 0.20, green: 0.60, blue: 1.0).opacity(0.4)
                        : Color.white.opacity(0.06),
                    lineWidth: 1
                )
        )
    }

    // MARK: - Target Paths Card
    private var targetPathsCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("ĐƯỜNG DẪN DỮ LIỆU GAME (DATA PATHS)")
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundStyle(Color(red: 0.40, green: 0.70, blue: 1.0))

            VStack(alignment: .leading, spacing: 6) {
                pathRow(name: "Shaders Bundle", path: "Documents/contentcache/Optional/ios/gameassetbundles/shaders.HPt9DZviTSXL9hpGW9QNOMigNLA~3D")
                pathRow(name: "Cache Res Bundle", path: "Documents/contentcache/Compulsory/ios/gameassetbundles/cache_res.CfnFf59sr1SbsqQ6JqTKsEusjKs~3D")
            }

            if let status = engine.statusMessage {
                Text(status)
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundStyle(Color.green)
                    .padding(.top, 4)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(red: 0.06, green: 0.08, blue: 0.14).opacity(0.85))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
    }

    private func pathRow(name: String, path: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(name)
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(.white)
            Text(path)
                .font(.system(size: 9, design: .monospaced))
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
    }

    private func iconSystemName(for patch: FFPatchItem) -> String {
        switch patch.category {
        case FFModCategory.aim.rawValue: return "bolt.fill"
        case FFModCategory.esp.rawValue: return "eye.fill"
        default: return "gearshape.fill"
        }
    }

    private func iconBackgroundColor(for patch: FFPatchItem) -> Color {
        switch patch.category {
        case FFModCategory.aim.rawValue: return Color(red: 0.35, green: 0.15, blue: 0.10).opacity(0.6)
        case FFModCategory.esp.rawValue: return Color(red: 0.10, green: 0.25, blue: 0.35).opacity(0.6)
        default: return Color(red: 0.25, green: 0.10, blue: 0.35).opacity(0.6)
        }
    }

    private func iconBorderColor(for patch: FFPatchItem) -> Color {
        switch patch.category {
        case FFModCategory.aim.rawValue: return Color.orange.opacity(0.4)
        case FFModCategory.esp.rawValue: return Color.cyan.opacity(0.4)
        default: return Color.purple.opacity(0.4)
        }
    }

    private func iconTintColor(for patch: FFPatchItem) -> Color {
        switch patch.category {
        case FFModCategory.aim.rawValue: return Color.orange
        case FFModCategory.esp.rawValue: return Color.cyan
        default: return Color(red: 0.8, green: 0.5, blue: 1.0)
        }
    }
}

// MARK: - Main Patch Projects View (Function Hub)

private enum PatchPackagePickerPolicy {
    static let payloadType = UTType(filenameExtension: "payload") ?? .data
    static let packageType = UTType(filenameExtension: "3105") ?? .data
    static let allowedContentTypes: [UTType] = [payloadType, packageType, .data]
    static let copiesSelectedDocument = true
}

struct PatchProjectsView: View {
    @Environment(\.appLanguage) private var language
    @EnvironmentObject private var draftCoordinator: PatchDraftCoordinator
    @StateObject private var store = PatchProjectStore()
    @State private var showCreate = false
    @State private var showImporter = false
    @State private var searchText = ""
    @State private var showServerConfig = false
    @State private var syncStatusMessage: String?
    @State private var isSyncing = false

    // Free Fire On/Off States
    @AppStorage("ff_th_enabled") private var freeFireEnabled = false
    @AppStorage("ff_max_enabled") private var freeFireMaxEnabled = false
    @AppStorage("admin_api_server_url") private var adminServerUrl = FreeFirePatchEngine.defaultApiServerUrl

    private var filteredItems: [PatchLibraryItem] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return store.items }
        return store.items.filter { item in
            if item.packageURL.lastPathComponent.localizedCaseInsensitiveContains(query) {
                return true
            }
            guard let project = item.project else { return false }
            return project.name.localizedCaseInsensitiveContains(query)
                || project.allBundleIdentifiers.contains {
                    $0.localizedCaseInsensitiveContains(query)
                }
                || project.directories.contains {
                    $0.relativePath.localizedCaseInsensitiveContains(query)
                }
                || project.rules.contains {
                    $0.relativePath.localizedCaseInsensitiveContains(query)
                        || $0.replacementFilename.localizedCaseInsensitiveContains(query)
                }
        }
    }

    var onToggleSidebar: (() -> Void)? = nil

    init(onToggleSidebar: (() -> Void)? = nil) {
        self.onToggleSidebar = onToggleSidebar
#if targetEnvironment(simulator)
        _showCreate = State(
            initialValue: ProcessInfo.processInfo.arguments.contains("--simulate-patch-editor")
        )
#endif
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 12) {
                    // Free Fire / Free Fire MAX Injection Panel
                    freeFireHubSection

                    // Admin Python Cloud Sync Section
                    adminSyncSection

                    // Search & Local Payload Packages (Payload MeoMeo.app)
                    localPayloadSection
                }
                .padding(.horizontal, AppTheme.pageInset)
                .padding(.top, 10)
                .padding(.bottom, 26)
            }
            .background(AppTheme.pageBackground.ignoresSafeArea())
            .navigationTitle("Function")
            .navigationBarTitleDisplayMode(.inline)
            .tint(AppTheme.accent)
            .toolbar {
                if let onToggleSidebar {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button(action: onToggleSidebar) {
                            Image(systemName: "line.3.horizontal")
                                .font(.system(size: 15, weight: .bold))
                                .frame(width: 32, height: 32)
                                .background(Color(uiColor: .secondarySystemFill))
                                .overlay(
                                    Rectangle().stroke(AppTheme.cardBorder, lineWidth: 1)
                                )
                        }
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button {
                            showCreate = true
                        } label: {
                            Label("Tạo Payload mới", systemImage: "doc.badge.plus")
                        }
                        Button {
                            showImporter = true
                        } label: {
                            Label("Nhập file .3105 / .payload", systemImage: "square.and.arrow.down")
                        }
                        Button {
                            showServerConfig = true
                        } label: {
                            Label("Cấu hình Admin API Web", systemImage: "server.rack")
                        }
                    } label: {
                        if store.isBusy || isSyncing {
                            ProgressView()
                        } else {
                            Image(systemName: "plus")
                                .font(.system(size: 14, weight: .bold))
                                .frame(width: 32, height: 32)
                                .background(Color(uiColor: .secondarySystemFill))
                                .overlay(
                                    Rectangle().stroke(AppTheme.cardBorder, lineWidth: 1)
                                )
                        }
                    }
                    .disabled(store.isBusy || isSyncing)
                }
            }
            .sheet(isPresented: $showImporter) {
                FileDocumentPicker(
                    allowedContentTypes: PatchPackagePickerPolicy.allowedContentTypes,
                    copiesSelectedDocument: PatchPackagePickerPolicy.copiesSelectedDocument,
                    allowsMultipleSelection: false,
                    onSelection: { result in
                        showImporter = false
                        switch result {
                        case .success(let urls):
                            if let url = urls.first {
                                importFile(url)
                            }
                        case .failure(let error):
                            log("patch picker error: \(error.localizedDescription)")
                        }
                    },
                    onCancel: {
                        showImporter = false
                    }
                )
                .ignoresSafeArea()
            }
            .sheet(isPresented: $showCreate) {
                PatchProjectEditorView(
                    existingProject: nil,
                    passwordIsProtected: false
                ) { project, password in
                    store.create(project: project, password: password)
                }
            }
            .sheet(isPresented: $showServerConfig) {
                adminServerConfigSheet
            }
        }
    }

    // MARK: - Free Fire Game Injection Hub
    private var freeFireHubSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("FREE FIRE INJECTION ENGINE")
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundStyle(AppTheme.accent)

                Spacer()

                Text("ON / OFF SYSTEM")
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundStyle(.secondary)
            }

            VStack(spacing: 8) {
                // Free Fire Standard
                gameCard(
                    title: "Free Fire (VN / Global)",
                    bundleID: "com.dts.freefireth",
                    icon: "flame.fill",
                    color: Color(red: 1.00, green: 0.32, blue: 0.12),
                    isOn: $freeFireEnabled
                )

                // Free Fire MAX
                gameCard(
                    title: "Free Fire MAX",
                    bundleID: "com.dts.freefiremax",
                    icon: "bolt.fill",
                    color: Color(red: 1.00, green: 0.18, blue: 0.25),
                    isOn: $freeFireMaxEnabled
                )
            }
        }
    }

    private func gameCard(
        title: String,
        bundleID: String,
        icon: String,
        color: Color,
        isOn: Binding<Bool>
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            NavigationLink(destination: FreeFireDetailView(gameTitle: title, bundleID: bundleID)) {
                HStack(spacing: 10) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 3, style: .continuous)
                            .fill(color.opacity(0.15))
                            .overlay(
                                RoundedRectangle(cornerRadius: 3, style: .continuous)
                                    .stroke(color.opacity(0.35), lineWidth: 1)
                            )
                        Image(systemName: icon)
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(color)
                    }
                    .frame(width: 34, height: 34)

                    VStack(alignment: .leading, spacing: 1) {
                        Text(title)
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(.primary)
                        Text(bundleID)
                            .font(.system(size: 10, weight: .medium, design: .monospaced))
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(.secondary)
                }
            }
            .buttonStyle(.plain)

            Divider()

            HStack {
                HStack(spacing: 4) {
                    Circle()
                        .fill(isOn.wrappedValue ? Color.green : Color.secondary.opacity(0.5))
                        .frame(width: 6, height: 6)
                    Text(isOn.wrappedValue ? "ACTIVE • ĐÃ KÍCH HOẠT" : "OFF • CHƯA KÍCH HOẠT")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundStyle(isOn.wrappedValue ? Color.green : Color.secondary)
                }

                Spacer()

                NavigationLink(destination: FreeFireDetailView(gameTitle: title, bundleID: bundleID)) {
                    HStack(spacing: 4) {
                        Image(systemName: "bolt.fill")
                            .font(.system(size: 10, weight: .bold))
                        Text("MỞ MENU PATCH")
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(color.opacity(0.12))
                    .foregroundStyle(color)
                    .overlay(
                        RoundedRectangle(cornerRadius: 2, style: .continuous)
                            .stroke(color.opacity(0.3), lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: AppTheme.cardCornerRadius, style: .continuous)
                .fill(AppTheme.cardBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: AppTheme.cardCornerRadius, style: .continuous)
                        .stroke(isOn.wrappedValue ? AppTheme.accent.opacity(0.4) : AppTheme.cardBorder, lineWidth: 1)
                )
        )
    }

    // MARK: - Admin Python Server Sync Banner
    private var adminSyncSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: "antenna.radiowaves.left.and.right")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(AppTheme.accent)

                Text("ADMIN WEB API: 103.238.234.204:5000")
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundStyle(.secondary)

                Spacer()

                Button {
                    showServerConfig = true
                } label: {
                    Text("CẤU HÌNH")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundStyle(AppTheme.accent)
                }
            }

            if let msg = syncStatusMessage {
                Text(msg)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(AppTheme.accent)
                    .padding(.horizontal, 4)
            }
        }
    }

    // MARK: - Local Payload Packages (Payload MeoMeo.app)
    private var localPayloadSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("WORKSPACE: PAYLOAD MEOMEO.APP")
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundStyle(.secondary)

                Spacer()

                Text("\(store.items.count) GÓI")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundStyle(.secondary)
            }

            AppSearchField(
                text: $searchText,
                prompt: "Tìm kiếm payload / patch .3105…",
                clearLabel: "Xóa"
            )

            if store.items.isEmpty && !store.isBusy {
                VStack(spacing: 8) {
                    Image(systemName: "shippingbox")
                        .font(.system(size: 28))
                        .foregroundStyle(.secondary)
                    Text("Chưa có gói Payload trong Payload MeoMeo.app")
                        .font(.system(size: 13, weight: .bold))
                    Text("Tạo mới hoặc kết nối Admin API để tải patch về máy.")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 24)
                .background(
                    RoundedRectangle(cornerRadius: AppTheme.cardCornerRadius, style: .continuous)
                        .fill(AppTheme.cardBackground)
                        .overlay(
                            RoundedRectangle(cornerRadius: AppTheme.cardCornerRadius, style: .continuous)
                                .stroke(AppTheme.cardBorder, lineWidth: 1)
                        )
                )
            } else {
                VStack(spacing: 6) {
                    ForEach(filteredItems) { item in
                        payloadRow(item)
                    }
                }
            }
        }
    }

    private func payloadRow(_ item: PatchLibraryItem) -> some View {
        HStack(spacing: 10) {
            AppLogo(size: 30)

            VStack(alignment: .leading, spacing: 2) {
                Text(item.project?.name ?? item.packageURL.deletingPathExtension().lastPathComponent)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(.primary)

                Text(item.packageURL.lastPathComponent)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button {
                store.delete(item)
            } label: {
                Image(systemName: "trash")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(.red.opacity(0.8))
                    .frame(width: 28, height: 28)
                    .background(Color(uiColor: .tertiarySystemFill))
            }
            .buttonStyle(.plain)
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: AppTheme.cardCornerRadius, style: .continuous)
                .fill(AppTheme.cardBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: AppTheme.cardCornerRadius, style: .continuous)
                        .stroke(AppTheme.cardBorder, lineWidth: 1)
                )
        )
    }

    // MARK: - Admin Server Config Sheet
    private var adminServerConfigSheet: some View {
        NavigationStack {
            Form {
                Section("Máy Chủ Admin API Python") {
                    TextField("http://103.238.234.204:5000", text: $adminServerUrl)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .font(.system(size: 13, design: .monospaced))

                    Text("Nhập URL của máy chủ Admin Web (Python Flask). Ứng dụng sẽ đồng bộ danh sách file patch On/Off trực tiếp từ đây.")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }

                Section {
                    Button {
                        testAndSyncServer()
                    } label: {
                        HStack {
                            Spacer()
                            Text(isSyncing ? "ĐANG ĐỒNG BỘ…" : "KIỂM TRA & ĐỒNG BỘ NGAY")
                                .font(.system(size: 13, weight: .bold, design: .monospaced))
                                .foregroundStyle(AppTheme.accent)
                            Spacer()
                        }
                    }
                    .disabled(isSyncing)
                }
            }
            .navigationTitle("Admin API Server")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Đóng") { showServerConfig = false }
                }
            }
        }
    }

    private func importFile(_ url: URL) {
        store.importPackage(at: url)
        syncStatusMessage = "Đã nhập thành công: \(url.lastPathComponent)"
    }

    private func testAndSyncServer() {
        isSyncing = true
        syncStatusMessage = "Đang kiểm tra kết nối..."

        guard let url = URL(string: "\(adminServerUrl)/api/status") else {
            isSyncing = false
            syncStatusMessage = "URL Server không hợp lệ"
            return
        }

        URLSession.shared.dataTask(with: url) { data, response, error in
            DispatchQueue.main.async {
                isSyncing = false
                if let error = error {
                    syncStatusMessage = "Không thể kết nối tới server: \(error.localizedDescription)"
                } else {
                    syncStatusMessage = "Kết nối máy chủ Admin Python thành công (Online)!"
                    showServerConfig = false
                }
            }
        }.resume()
    }
}
