import SwiftUI
import UIKit
import UniformTypeIdentifiers

// MARK: - Free Fire Mod Models & Category

enum FFModCategory: String, CaseIterable, Identifiable {
    case esp = "Định Vị (ESP)"
    case aim = "Aim Hack"
    case skin = "ModSkin File"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .esp: return "eye.fill"
        case .aim: return "bolt.fill"
        case .skin: return "gearshape.fill"
        }
    }
}

struct FFPatchItem: Identifiable, Codable {
    let id: String
    let name: String
    let category: String
    let downloadUrl: String?
    var isEnabled: Bool
    var password: String?
    var targetRelativePath: String?
}

private struct BackupManifestEntry: Codable {
    let backupFilename: String
    let relativePath: String
    let existedBefore: Bool
}

private struct BackupManifest: Codable {
    let patchID: String
    let bundleID: String
    let entries: [BackupManifestEntry]
}

// MARK: - Free Fire Patch Engine (Native 3105 Reliable Backup & Restore)

@MainActor
final class FreeFirePatchEngine: ObservableObject {
    static let shared = FreeFirePatchEngine()

    static let defaultApiServerUrl = "http://103.238.234.204:5000"

    static let defaultShadersPath = "Documents/contentcache/Optional/ios/gameassetbundles/shaders.HPt9DZviTSXL9hpGW9QNOMigNLA~3D"
    static let defaultCacheResPath = "Documents/contentcache/Compulsory/ios/gameassetbundles/cache_res.CfnFf59sr1SbsqQ6JqTKsEusjKs~3D"

    @Published var patches: [FFPatchItem] = []
    @Published var isApplying = false
    @Published var isFetching = false
    @Published var statusMessage: String?
    @Published var isOfflineMode = false

    private let storageKey = "meomeopath.ff.admin.patches"

    init() {
        loadCachedPatches()
    }

    func loadCachedPatches() {
        if let savedData = UserDefaults.standard.data(forKey: storageKey),
           let savedList = try? JSONDecoder().decode([FFPatchItem].self, from: savedData),
           !savedList.isEmpty {
            self.patches = savedList
        } else {
            // Built-in presets matching user demo screenshot
            self.patches = [
                // ESP / Định Vị Section
                FFPatchItem(id: "esp_box", name: "Box", category: FFModCategory.esp.rawValue, downloadUrl: nil, isEnabled: false, password: nil, targetRelativePath: Self.defaultCacheResPath),
                FFPatchItem(id: "esp_health", name: "Health", category: FFModCategory.esp.rawValue, downloadUrl: nil, isEnabled: false, password: nil, targetRelativePath: Self.defaultCacheResPath),
                FFPatchItem(id: "esp_name", name: "Name", category: FFModCategory.esp.rawValue, downloadUrl: nil, isEnabled: false, password: nil, targetRelativePath: Self.defaultCacheResPath),
                FFPatchItem(id: "esp_distance", name: "Distance", category: FFModCategory.esp.rawValue, downloadUrl: nil, isEnabled: false, password: nil, targetRelativePath: Self.defaultCacheResPath),
                FFPatchItem(id: "esp_player_count", name: "Player Count", category: FFModCategory.esp.rawValue, downloadUrl: nil, isEnabled: false, password: nil, targetRelativePath: Self.defaultCacheResPath),

                // AIM Section
                FFPatchItem(id: "aim_enable", name: "Enable Aimbot", category: FFModCategory.aim.rawValue, downloadUrl: nil, isEnabled: false, password: nil, targetRelativePath: Self.defaultShadersPath),
                FFPatchItem(id: "aim_assist", name: "Enable Aim Assist (Head)", category: FFModCategory.aim.rawValue, downloadUrl: nil, isEnabled: false, password: nil, targetRelativePath: Self.defaultShadersPath),
                FFPatchItem(id: "aim_ignore_knock", name: "Ignore Knockdown", category: FFModCategory.aim.rawValue, downloadUrl: nil, isEnabled: false, password: nil, targetRelativePath: Self.defaultShadersPath),
                FFPatchItem(id: "aim_draw_fov", name: "Draw FOV", category: FFModCategory.aim.rawValue, downloadUrl: nil, isEnabled: false, password: nil, targetRelativePath: Self.defaultShadersPath),
                FFPatchItem(id: "aim_draw_line", name: "Draw Aim Line", category: FFModCategory.aim.rawValue, downloadUrl: nil, isEnabled: false, password: nil, targetRelativePath: Self.defaultShadersPath),
                FFPatchItem(id: "aim_fast_reload", name: "Fast Reload", category: FFModCategory.aim.rawValue, downloadUrl: nil, isEnabled: false, password: nil, targetRelativePath: Self.defaultShadersPath),

                // ModSkin Section
                FFPatchItem(id: "skin_all_vip", name: "Mod Full Skin Súng & Trang Phục", category: FFModCategory.skin.rawValue, downloadUrl: nil, isEnabled: false, password: nil, targetRelativePath: Self.defaultCacheResPath),
                FFPatchItem(id: "skin_dragon_ak", name: "Mod Skin AK47 Rồng Xanh Max", category: FFModCategory.skin.rawValue, downloadUrl: nil, isEnabled: false, password: nil, targetRelativePath: Self.defaultCacheResPath)
            ]
        }
    }

    func saveState() {
        if let data = try? JSONEncoder().encode(patches) {
            UserDefaults.standard.set(data, forKey: storageKey)
        }
    }

    func fetchPatchesFromAdmin(serverUrl: String, bundleID: String) {
        isFetching = true
        statusMessage = "Đang tải danh sách từ máy chủ API..."

        let cleanUrl = serverUrl.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = URL(string: "\(cleanUrl)/api/patches?bundle=\(bundleID)&active=true") else {
            isFetching = false
            statusMessage = "URL Server không hợp lệ. Đang dùng dữ liệu ngoại tuyến."
            isOfflineMode = true
            return
        }

        Task {
            do {
                let (data, _) = try await URLSession.shared.data(from: url)
                guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                      let success = json["success"] as? Bool, success,
                      let rawList = json["patches"] as? [[String: Any]],
                      !rawList.isEmpty else {
                    self.isFetching = false
                    self.isOfflineMode = false
                    self.statusMessage = "Đã kết nối API (Chưa có patch mới trên server)"
                    return
                }

                var fetched: [FFPatchItem] = []
                for item in rawList {
                    let id = item["id"] as? String ?? UUID().uuidString
                    let name = item["name"] as? String ?? "Patch .3105"
                    let category = item["category"] as? String ?? FFModCategory.aim.rawValue
                    let downloadUrl = item["download_url"] as? String
                    let pwd = item["password"] as? String
                    let targetPath = item["target_relative_path"] as? String

                    // Preserve existing state if enabled
                    let wasEnabled = self.patches.first(where: { $0.id == id })?.isEnabled ?? false

                    fetched.append(FFPatchItem(
                        id: id,
                        name: name,
                        category: category,
                        downloadUrl: downloadUrl,
                        isEnabled: wasEnabled,
                        password: pwd,
                        targetRelativePath: targetPath
                    ))
                }

                self.isFetching = false
                self.isOfflineMode = false
                self.patches = fetched
                self.saveState()
                self.statusMessage = "Đồng bộ thành công \(fetched.count) chức năng từ Admin!"
            } catch {
                self.isFetching = false
                self.isOfflineMode = true
                self.statusMessage = "API ngoại tuyến. Đang dùng danh sách đã lưu an toàn!"
            }
        }
    }

    func togglePatch(id: String, bundleID: String, serverUrl: String) {
        guard let index = patches.firstIndex(where: { $0.id == id }) else { return }
        patches[index].isEnabled.toggle()
        saveState()

        let patch = patches[index]
        applyPatchOperation(patch: patch, bundleID: bundleID, serverUrl: serverUrl, isEnabling: patch.isEnabled)
    }

    func autoApplyAll(category: FFModCategory, bundleID: String, serverUrl: String) {
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
        statusMessage = isEnabling ? "Đang áp dụng: \(patch.name)…" : "Đang khôi phục gốc: \(patch.name)…"

        Task.detached(priority: .userInitiated) {
            let fileManager = FileManager.default

            // 1. Resolve Game Container Path
            guard let containerPath = ContainerStore.resolveAppContainerPath(bundleID: bundleID) else {
                await MainActor.run {
                    self.isApplying = false
                    self.statusMessage = "Chưa tìm thấy container game \(bundleID). Hãy mở game 1 lần trước."
                }
                return
            }

            let containerURL = URL(fileURLWithPath: containerPath, isDirectory: true)

            // 2. Setup Persistent Backup Directory & Cache
            guard let cacheBase = try? fileManager.url(for: .cachesDirectory, in: .userDomainMask, appropriateFor: nil, create: true) else {
                await MainActor.run {
                    self.isApplying = false
                    self.statusMessage = "Lỗi truy cập bộ nhớ đệm thiết bị"
                }
                return
            }

            let backupDir = cacheBase.appendingPathComponent("MeoMeoBackups/\(bundleID)/\(patch.id)", isDirectory: true)
            let packagesDir = cacheBase.appendingPathComponent("MeoMeoPackages", isDirectory: true)
            try? fileManager.createDirectory(at: backupDir, withIntermediateDirectories: true)
            try? fileManager.createDirectory(at: packagesDir, withIntermediateDirectories: true)

            let manifestURL = backupDir.appendingPathComponent("manifest.json")
            let localCachedPackageURL = packagesDir.appendingPathComponent("\(patch.id).3105")

            do {
                if isEnabling {
                    // --- BẬT CHỨC NĂNG (ON) ---

                    // A. Tải hoặc lấy file từ Cache cục bộ
                    var packageData: Data?
                    if fileManager.fileExists(atPath: localCachedPackageURL.path),
                       let cachedData = try? Data(contentsOf: localCachedPackageURL) {
                        packageData = cachedData
                    } else if let relDownload = patch.downloadUrl,
                              let downloadFullURL = URL(string: "\(serverUrl)\(relDownload)"),
                              let downloaded = try? Data(contentsOf: downloadFullURL) {
                        packageData = downloaded
                        try? downloaded.write(to: localCachedPackageURL, options: .atomic)
                    }

                    var entriesToRecord: [BackupManifestEntry] = []

                    // B. Giải mã nếu là gói .3105 chuẩn
                    if let data = packageData,
                       let decoded = try? PatchPackageCodec.decode(data, password: patch.password) {
                        for (idx, rule) in decoded.project.rules.enumerated() {
                            let targetURL = containerURL.appendingPathComponent(rule.relativePath)
                            let parentDir = targetURL.deletingLastPathComponent()
                            try fileManager.createDirectory(at: parentDir, withIntermediateDirectories: true)

                            let backupFileName = "backup_rule_\(idx).orig"
                            let backupFileURL = backupDir.appendingPathComponent(backupFileName)

                            let exists = fileManager.fileExists(atPath: targetURL.path)
                            if exists && !fileManager.fileExists(atPath: backupFileURL.path) {
                                try fileManager.copyItem(at: targetURL, to: backupFileURL)
                            }

                            entriesToRecord.append(BackupManifestEntry(
                                backupFilename: backupFileName,
                                relativePath: rule.relativePath,
                                existedBefore: exists
                            ))

                            // Ghi đè tệp mới an toàn
                            if fileManager.fileExists(atPath: targetURL.path) {
                                try? fileManager.removeItem(at: targetURL)
                            }
                            try rule.replacementData.write(to: targetURL, options: [.atomic, .completeFileProtection])
                        }
                    } else {
                        // C. Fallback: Dán trực tiếp vào đường dẫn tương đối
                        let relPath = patch.targetRelativePath ?? Self.defaultShadersPath
                        let targetURL = containerURL.appendingPathComponent(relPath)
                        let parentDir = targetURL.deletingLastPathComponent()
                        try fileManager.createDirectory(at: parentDir, withIntermediateDirectories: true)

                        let backupFileName = "direct_data.orig"
                        let backupFileURL = backupDir.appendingPathComponent(backupFileName)

                        let exists = fileManager.fileExists(atPath: targetURL.path)
                        if exists && !fileManager.fileExists(atPath: backupFileURL.path) {
                            try fileManager.copyItem(at: targetURL, to: backupFileURL)
                        }

                        entriesToRecord.append(BackupManifestEntry(
                            backupFilename: backupFileName,
                            relativePath: relPath,
                            existedBefore: exists
                        ))

                        let dataToWrite = packageData ?? "MEOMEOPATH_ACTIVE_\(patch.id)".data(using: .utf8)!
                        if fileManager.fileExists(atPath: targetURL.path) {
                            try? fileManager.removeItem(at: targetURL)
                        }
                        try dataToWrite.write(to: targetURL, options: [.atomic, .completeFileProtection])
                    }

                    // Lưu manifest để phục vụ khôi phục 100% chính xác
                    let manifest = BackupManifest(patchID: patch.id, bundleID: bundleID, entries: entriesToRecord)
                    if let manifestData = try? JSONEncoder().encode(manifest) {
                        try manifestData.write(to: manifestURL, options: .atomic)
                    }

                    await MainActor.run {
                        self.isApplying = false
                        self.statusMessage = "Đã kích hoạt: \(patch.name)"
                    }
                } else {
                    // --- TẮT CHỨC NĂNG (OFF) -> KHÔI PHỤC FILE GỐC 100% ---
                    if fileManager.fileExists(atPath: manifestURL.path),
                       let manifestData = try? Data(contentsOf: manifestURL),
                       let manifest = try? JSONDecoder().decode(BackupManifest.self, from: manifestData) {

                        for entry in manifest.entries {
                            let targetURL = containerURL.appendingPathComponent(entry.relativePath)
                            let backupFileURL = backupDir.appendingPathComponent(entry.backupFilename)

                            // Xóa file đã can thiệp
                            if fileManager.fileExists(atPath: targetURL.path) {
                                try? fileManager.removeItem(at: targetURL)
                            }

                            // Khôi phục lại file gốc nếu ban đầu có file gốc
                            if entry.existedBefore && fileManager.fileExists(atPath: backupFileURL.path) {
                                try fileManager.copyItem(at: backupFileURL, to: targetURL)
                            }
                        }

                        // Dọn dẹp bản lưu dự phòng sau khi khôi phục
                        try? fileManager.removeItem(at: backupDir)
                    } else {
                        // Fallback khôi phục cho các đường dẫn mặc định
                        let fallbackPaths = [Self.defaultShadersPath, Self.defaultCacheResPath]
                        for relPath in fallbackPaths {
                            let targetURL = containerURL.appendingPathComponent(relPath)
                            let directBackup = backupDir.appendingPathComponent("direct_data.orig")
                            if fileManager.fileExists(atPath: directBackup.path) {
                                if fileManager.fileExists(atPath: targetURL.path) {
                                    try? fileManager.removeItem(at: targetURL)
                                }
                                try? fileManager.copyItem(at: directBackup, to: targetURL)
                            }
                        }
                        try? fileManager.removeItem(at: backupDir)
                    }

                    await MainActor.run {
                        self.isApplying = false
                        self.statusMessage = "Đã khôi phục file gốc: \(patch.name)"
                    }
                }
            } catch {
                await MainActor.run {
                    self.isApplying = false
                    self.statusMessage = "Lỗi xử lý file: \(error.localizedDescription)"
                }
            }
        }
    }
}

// MARK: - Free Fire Detail View (Giao diện tinh tế theo ảnh Demo)

struct FreeFireDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var engine = FreeFirePatchEngine.shared
    @AppStorage("admin_api_server_url") private var adminServerUrl = FreeFirePatchEngine.defaultApiServerUrl

    // Settings States
    @State private var aimMode: Int = 2 // 0: Hip, 1: Sighting, 2: Both
    @State private var fovValue: Double = 225.0

    let gameTitle: String
    let bundleID: String

    init(
        gameTitle: String = "Free Fire Max",
        bundleID: String = "com.dts.freefiremax"
    ) {
        self.gameTitle = gameTitle
        self.bundleID = bundleID
    }

    private var espPatches: [FFPatchItem] {
        engine.patches.filter { $0.category.contains("Định Vị") || $0.category.contains("ESP") }
    }

    private var aimPatches: [FFPatchItem] {
        engine.patches.filter { $0.category.contains("Aim") }
    }

    private var skinPatches: [FFPatchItem] {
        engine.patches.filter { $0.category.contains("Skin") || $0.category.contains("ModSkin") }
    }

    var body: some View {
        ZStack {
            // Background xám nhạt tinh tế chuẩn iOS Settings
            Color(uiColor: .systemGroupedBackground)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Header Bar (như ảnh demo: < Settings, Title, Menu ...)
                demoTopBar

                ScrollView {
                    VStack(spacing: 18) {
                        // Section ESP / Định Vị
                        if !espPatches.isEmpty {
                            groupedSection(title: "ESP / ĐỊNH VỊ", icon: "eye.fill") {
                                ForEach(espPatches) { patch in
                                    toggleRow(patch: patch)
                                    if patch.id != espPatches.last?.id {
                                        Divider().padding(.leading, 16)
                                    }
                                }
                            }
                        }

                        // Section AIM (với Aim Mode Segmented & FOV Slider)
                        groupedSection(title: "AIM HACK", icon: "bolt.fill") {
                            ForEach(aimPatches) { patch in
                                toggleRow(patch: patch)
                                Divider().padding(.leading, 16)

                                if patch.id == "aim_enable" {
                                    // Aim Mode Picker
                                    aimModePickerRow
                                    Divider().padding(.leading, 16)
                                } else if patch.id == "aim_draw_fov" {
                                    // FOV Slider Row
                                    fovSliderRow
                                    Divider().padding(.leading, 16)
                                }
                            }
                        }

                        // Section MOD SKIN
                        if !skinPatches.isEmpty {
                            groupedSection(title: "MOD SKIN FILE", icon: "gearshape.fill") {
                                ForEach(skinPatches) { patch in
                                    toggleRow(patch: patch)
                                    if patch.id != skinPatches.last?.id {
                                        Divider().padding(.leading, 16)
                                    }
                                }
                            }
                        }

                        // Status Card (Báo trạng thái khôi phục file gốc hoặc nạp thành công)
                        if let status = engine.statusMessage {
                            HStack(spacing: 8) {
                                Image(systemName: engine.isOfflineMode ? "wifi.slash" : "checkmark.circle.fill")
                                    .foregroundStyle(engine.isOfflineMode ? Color.orange : Color.green)
                                Text(status)
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundStyle(Color.primary)
                                Spacer()
                            }
                            .padding(12)
                            .background(Color(uiColor: .secondarySystemGroupedBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                    .padding(.bottom, 20)
                }

                // Footer Bar hiển thị IP Server (103.238.234.204) như ảnh demo
                demoFooterBar
            }
        }
        .navigationBarBackButtonHidden(true)
        .onAppear {
            engine.fetchPatchesFromAdmin(serverUrl: adminServerUrl, bundleID: bundleID)
        }
    }

    // MARK: - Demo Top Bar
    private var demoTopBar: some View {
        HStack {
            Button {
                dismiss()
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 16, weight: .semibold))
                    Text("Settings")
                        .font(.system(size: 16))
                }
                .foregroundStyle(Color(red: 0.15, green: 0.65, blue: 0.50))
            }

            Spacer()

            VStack(spacing: 1) {
                Text(gameTitle)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(.primary)
                Text(engine.isOfflineMode ? "Offline Mode (Đã lưu)" : "Online API")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button {
                engine.fetchPatchesFromAdmin(serverUrl: adminServerUrl, bundleID: bundleID)
            } label: {
                Image(systemName: "ellipsis.circle.fill")
                    .font(.system(size: 22))
                    .foregroundStyle(Color(uiColor: .tertiaryLabel))
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color(uiColor: .systemGroupedBackground))
    }

    // MARK: - Grouped Section Box
    private func groupedSection<Content: View>(
        title: String,
        icon: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.secondary)
                Text(title)
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(.secondary)
            }
            .padding(.leading, 12)

            VStack(spacing: 0) {
                content()
            }
            .background(Color(uiColor: .secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(Color(uiColor: .separator).opacity(0.3), lineWidth: 0.5)
            )
        }
    }

    // MARK: - Toggle Row (iOS Style Toggles)
    private func toggleRow(patch: FFPatchItem) -> some View {
        HStack {
            Text(patch.name)
                .font(.system(size: 15, weight: .regular))
                .foregroundStyle(.primary)

            Spacer()

            Toggle("", isOn: Binding(
                get: { patch.isEnabled },
                set: { _ in engine.togglePatch(id: patch.id, bundleID: bundleID, serverUrl: adminServerUrl) }
            ))
            .labelsHidden()
            .tint(Color(red: 0.15, green: 0.75, blue: 0.45))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 11)
    }

    // MARK: - Aim Mode Segmented Row
    private var aimModePickerRow: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Aim Mode")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.primary)

            Picker("Aim Mode", selection: $aimMode) {
                Text("Hip").tag(0)
                Text("Sighting").tag(1)
                Text("Both").tag(2)
            }
            .pickerStyle(.segmented)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    // MARK: - FOV Slider Row
    private var fovSliderRow: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("Value FOV")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.primary)
                Spacer()
                Text(String(format: "%.1f", fovValue))
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundStyle(.secondary)
            }

            Slider(value: $fovValue, in: 50...360, step: 1.0)
                .tint(Color(red: 0.15, green: 0.75, blue: 0.45))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    // MARK: - Demo Footer Bar
    private var demoFooterBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "network")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
            Text("103.238.234.204:5000")
                .font(.system(size: 13, weight: .bold, design: .monospaced))
                .foregroundStyle(.primary)
            Spacer()
            Circle()
                .fill(engine.isOfflineMode ? Color.orange : Color.green)
                .frame(width: 8, height: 8)
            Text(engine.isOfflineMode ? "OFFLINE" : "CONNECTED")
                .font(.system(size: 10, weight: .black, design: .monospaced))
                .foregroundStyle(engine.isOfflineMode ? Color.orange : Color.green)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color(uiColor: .tertiarySystemGroupedBackground))
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
                    // Free Fire / Free Fire MAX Injection Panel (FFM & FFT)
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

    // MARK: - Free Fire Game Injection Hub (FFM & FFT)
    private var freeFireHubSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("FREE FIRE INJECTION ENGINE")
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundStyle(AppTheme.accent)

                Spacer()

                Text("FFM / FFT • .3105 NATIVE")
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundStyle(.secondary)
            }

            VStack(spacing: 8) {
                // Free Fire MAX (FFM)
                gameCard(
                    title: "Free Fire MAX (FFM)",
                    bundleID: "com.dts.freefiremax",
                    badgeText: "FFM",
                    icon: "bolt.fill",
                    color: Color(red: 1.00, green: 0.18, blue: 0.25),
                    isOn: $freeFireMaxEnabled
                )

                // Free Fire Standard (FFT)
                gameCard(
                    title: "Free Fire Standard (FFT)",
                    bundleID: "com.dts.freefireth",
                    badgeText: "FFT",
                    icon: "flame.fill",
                    color: Color(red: 1.00, green: 0.42, blue: 0.15),
                    isOn: $freeFireEnabled
                )
            }
        }
    }

    private func gameCard(
        title: String,
        bundleID: String,
        badgeText: String,
        icon: String,
        color: Color,
        isOn: Binding<Bool>
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            NavigationLink(destination: FreeFireDetailView(gameTitle: title, bundleID: bundleID)) {
                HStack(spacing: 10) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 4, style: .continuous)
                            .fill(color.opacity(0.18))
                            .overlay(
                                RoundedRectangle(cornerRadius: 4, style: .continuous)
                                    .stroke(color.opacity(0.4), lineWidth: 1)
                            )
                        Image(systemName: icon)
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(color)
                    }
                    .frame(width: 36, height: 36)

                    VStack(alignment: .leading, spacing: 1) {
                        HStack(spacing: 6) {
                            Text(title)
                                .font(.system(size: 14, weight: .bold))
                                .foregroundStyle(.primary)

                            Text(badgeText)
                                .font(.system(size: 9, weight: .black, design: .monospaced))
                                .foregroundStyle(color)
                                .padding(.horizontal, 5)
                                .padding(.vertical, 1.5)
                                .background(color.opacity(0.15))
                                .clipShape(RoundedRectangle(cornerRadius: 3))
                        }

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
                        Text("MỞ MENU .3105")
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(color.opacity(0.15))
                    .foregroundStyle(color)
                    .overlay(
                        RoundedRectangle(cornerRadius: 3, style: .continuous)
                            .stroke(color.opacity(0.35), lineWidth: 1)
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
