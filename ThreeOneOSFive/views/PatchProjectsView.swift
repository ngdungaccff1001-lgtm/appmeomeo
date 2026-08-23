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

// MARK: - Free Fire Patch Engine (Strict Separation & Reliable Restoration)

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
    @Published var currentBundleID: String = ""

    private func storageKey(for bundleID: String) -> String {
        "meomeopath.admin.patches.\(bundleID)"
    }

    func loadCachedPatches(bundleID: String) {
        currentBundleID = bundleID
        let key = storageKey(for: bundleID)
        if let savedData = UserDefaults.standard.data(forKey: key),
           let savedList = try? JSONDecoder().decode([FFPatchItem].self, from: savedData) {
            self.patches = savedList
        } else {
            // ONLY Admin-added items! No fake/dummy presets.
            self.patches = []
        }
    }

    func saveState(for bundleID: String) {
        let key = storageKey(for: bundleID)
        if let data = try? JSONEncoder().encode(patches) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }

    func fetchPatchesFromAdmin(serverUrl: String, bundleID: String) {
        currentBundleID = bundleID
        isFetching = true
        statusMessage = "Đang tải danh sách từ Admin API..."

        let cleanUrl = serverUrl.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = URL(string: "\(cleanUrl)/api/patches?bundle=\(bundleID)&active=true") else {
            isFetching = false
            isOfflineMode = true
            statusMessage = "Đang dùng danh sách đã lưu an toàn."
            return
        }

        Task {
            do {
                let (data, _) = try await URLSession.shared.data(from: url)
                guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                      let success = json["success"] as? Bool, success,
                      let rawList = json["patches"] as? [[String: Any]] else {
                    self.isFetching = false
                    self.isOfflineMode = false
                    self.statusMessage = "Chưa có file patch nào từ Admin."
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
                self.saveState(for: bundleID)
                self.statusMessage = "Đã đồng bộ \(fetched.count) chức năng từ Admin!"
            } catch {
                self.isFetching = false
                self.isOfflineMode = true
                self.statusMessage = "Admin API tạm ngắt kết nối. Đang dùng dữ liệu ngoại tuyến!"
            }
        }
    }

    func togglePatch(id: String, bundleID: String, serverUrl: String) {
        guard let index = patches.firstIndex(where: { $0.id == id }) else { return }
        patches[index].isEnabled.toggle()
        saveState(for: bundleID)

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
        saveState(for: bundleID)
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

            // 2. Persistent Backup Directory & Package Cache
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

                    // Giải mã gói .3105
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

                            if fileManager.fileExists(atPath: targetURL.path) {
                                try? fileManager.removeItem(at: targetURL)
                            }
                            try rule.replacementData.write(to: targetURL, options: [.atomic, .completeFileProtection])
                        }
                    } else {
                        // Fallback dán dữ liệu vào shaders / cache_res
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

                    // Lưu manifest
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

                            if fileManager.fileExists(atPath: targetURL.path) {
                                try? fileManager.removeItem(at: targetURL)
                            }

                            if entry.existedBefore && fileManager.fileExists(atPath: backupFileURL.path) {
                                try fileManager.copyItem(at: backupFileURL, to: targetURL)
                            }
                        }

                        try? fileManager.removeItem(at: backupDir)
                    } else {
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

// MARK: - Free Fire Detail View (Only Admin Patches)

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

    private var isFFM: Bool {
        bundleID.contains("max")
    }

    private var filteredPatches: [FFPatchItem] {
        engine.patches.filter { $0.category == selectedCategory.rawValue }
    }

    var body: some View {
        ZStack {
            AppTheme.pageBackground
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Header Bar
                topNavBar

                ScrollView {
                    VStack(spacing: 14) {
                        // Game Hero Banner
                        gameHeroBanner

                        // Category Filter Tabs
                        categoryTabs

                        // Menu Patch Card
                        menuPatchCard

                        // Status Feedback Card
                        if let status = engine.statusMessage {
                            statusCard(status)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 10)
                    .padding(.bottom, 24)
                }
            }
        }
        .navigationBarBackButtonHidden(true)
        .onAppear {
            engine.loadCachedPatches(bundleID: bundleID)
            engine.fetchPatchesFromAdmin(serverUrl: adminServerUrl, bundleID: bundleID)
        }
    }

    // MARK: - Top Nav Bar
    private var topNavBar: some View {
        HStack {
            Button {
                dismiss()
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 15, weight: .bold))
                    Text("Quay Lại")
                        .font(.system(size: 15, weight: .medium))
                }
                .foregroundStyle(AppTheme.accent)
            }

            Spacer()

            Text(gameTitle)
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundStyle(.primary)

            Spacer()

            Button {
                engine.fetchPatchesFromAdmin(serverUrl: adminServerUrl, bundleID: bundleID)
            } label: {
                if engine.isFetching {
                    ProgressView()
                } else {
                    Image(systemName: "arrow.triangle.2.circlepath")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(AppTheme.accent)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color(uiColor: .secondarySystemBackground))
    }

    // MARK: - Game Hero Banner
    private var gameHeroBanner: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(isFFM ? Color.red.opacity(0.18) : Color.orange.opacity(0.18))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(isFFM ? Color.red.opacity(0.4) : Color.orange.opacity(0.4), lineWidth: 1)
                    )

                Image(systemName: isFFM ? "bolt.fill" : "flame.fill")
                    .font(.system(size: 26, weight: .black))
                    .foregroundStyle(isFFM ? Color.red : Color.orange)
            }
            .frame(width: 52, height: 52)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(gameTitle)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(.primary)

                    Text(isFFM ? "FFM" : "FFT")
                        .font(.system(size: 9, weight: .black, design: .monospaced))
                        .foregroundStyle(isFFM ? Color.red : Color.orange)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background((isFFM ? Color.red : Color.orange).opacity(0.15))
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                }

                Text(bundleID)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: AppTheme.cardCornerRadius, style: .continuous)
                .fill(AppTheme.cardBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: AppTheme.cardCornerRadius, style: .continuous)
                        .stroke(AppTheme.cardBorder, lineWidth: 1)
                )
        )
    }

    // MARK: - Category Filter Tabs
    private var categoryTabs: some View {
        HStack(spacing: 6) {
            ForEach(FFModCategory.allCases) { cat in
                Button {
                    withAnimation(.easeInOut(duration: 0.15)) {
                        selectedCategory = cat
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: cat.icon)
                            .font(.system(size: 11, weight: .bold))
                        Text(cat.rawValue)
                            .font(.system(size: 12, weight: .bold))
                    }
                    .frame(maxWidth: .infinity, minHeight: 36)
                    .background(
                        selectedCategory == cat ? AppTheme.accent : AppTheme.cardBackground
                    )
                    .foregroundStyle(selectedCategory == cat ? Color.white : Color.primary)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(selectedCategory == cat ? Color.clear : AppTheme.cardBorder, lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Menu Patch Card (Only Admin-Added Items)
    private var menuPatchCard: some View {
        VStack(spacing: 0) {
            HStack {
                Text("DANH SÁCH CHỨC NĂNG")
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundStyle(.secondary)

                Spacer()

                Button {
                    engine.autoApplyAll(category: selectedCategory, bundleID: bundleID, serverUrl: adminServerUrl)
                } label: {
                    Text("BẬT TẤT CẢ")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundStyle(AppTheme.accent)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(AppTheme.accent.opacity(0.12))
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                }
                .disabled(filteredPatches.isEmpty)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)

            Divider()

            if filteredPatches.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "tray")
                        .font(.system(size: 26))
                        .foregroundStyle(.secondary)

                    Text("Chưa có file nào trong mục \(selectedCategory.rawValue)")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(.primary)

                    Text("Chỉ khi Admin tải file lên máy chủ thì mục này mới xuất hiện.")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.vertical, 28)
                .frame(maxWidth: .infinity)
            } else {
                VStack(spacing: 0) {
                    ForEach(filteredPatches) { patch in
                        patchRow(patch)
                        if patch.id != filteredPatches.last?.id {
                            Divider().padding(.leading, 14)
                        }
                    }
                }
            }
        }
        .background(
            RoundedRectangle(cornerRadius: AppTheme.cardCornerRadius, style: .continuous)
                .fill(AppTheme.cardBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: AppTheme.cardCornerRadius, style: .continuous)
                        .stroke(AppTheme.cardBorder, lineWidth: 1)
                )
        )
    }

    private func patchRow(_ patch: FFPatchItem) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "bolt.fill")
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(AppTheme.accent)

            VStack(alignment: .leading, spacing: 2) {
                Text(patch.name)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.primary)

                Text(patch.isEnabled ? "Đang bật • Tự động dán container" : "Chưa kích hoạt")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(patch.isEnabled ? Color.green : Color.secondary)
            }

            Spacer()

            Toggle("", isOn: Binding(
                get: { patch.isEnabled },
                set: { _ in engine.togglePatch(id: patch.id, bundleID: bundleID, serverUrl: adminServerUrl) }
            ))
            .labelsHidden()
            .tint(AppTheme.accent)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    // MARK: - Status Feedback Card
    private func statusCard(_ status: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: engine.isOfflineMode ? "wifi.slash" : "checkmark.circle.fill")
                .foregroundStyle(engine.isOfflineMode ? Color.orange : Color.green)
            Text(status)
                .font(.system(size: 12, weight: .medium, design: .monospaced))
                .foregroundStyle(.primary)
            Spacer()
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(uiColor: .secondarySystemBackground))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(engine.isOfflineMode ? Color.orange.opacity(0.3) : Color.green.opacity(0.3), lineWidth: 1)
                )
        )
    }
}

// MARK: - Main Patch Projects View (Clean Function Hub)

struct PatchProjectsView: View {
    @Environment(\.appLanguage) private var language
    @StateObject private var engine = FreeFirePatchEngine.shared
    @AppStorage("ff_th_enabled") private var freeFireEnabled = false
    @AppStorage("ff_max_enabled") private var freeFireMaxEnabled = false
    @AppStorage("admin_api_server_url") private var adminServerUrl = FreeFirePatchEngine.defaultApiServerUrl

    var onToggleSidebar: (() -> Void)? = nil

    init(onToggleSidebar: (() -> Void)? = nil) {
        self.onToggleSidebar = onToggleSidebar
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 14) {
                    // Free Fire / Free Fire MAX Injection Cards
                    freeFireHubSection
                }
                .padding(.horizontal, AppTheme.pageInset)
                .padding(.top, 14)
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
            }
        }
    }

    // MARK: - Free Fire Game Injection Hub (FFM & FFT ONLY)
    private var freeFireHubSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("DANH SÁCH GAME HỖ TRỢ")
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundStyle(AppTheme.accent)

                Spacer()

                Text("CHỈ NẠP TỆP ADMIN")
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundStyle(.secondary)
            }

            VStack(spacing: 10) {
                // Free Fire Standard (FFT)
                gameCard(
                    title: "Free Fire Standard (FFT)",
                    bundleID: "com.dts.freefireth",
                    badgeText: "FFT",
                    icon: "flame.fill",
                    color: Color(red: 1.00, green: 0.42, blue: 0.15)
                )

                // Free Fire MAX (FFM)
                gameCard(
                    title: "Free Fire MAX (FFM)",
                    bundleID: "com.dts.freefiremax",
                    badgeText: "FFM",
                    icon: "bolt.fill",
                    color: Color(red: 1.00, green: 0.18, blue: 0.25)
                )
            }
        }
    }

    private func gameCard(
        title: String,
        bundleID: String,
        badgeText: String,
        icon: String,
        color: Color
    ) -> some View {
        NavigationLink(destination: FreeFireDetailView(gameTitle: title, bundleID: bundleID)) {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(color.opacity(0.18))
                        .overlay(
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .stroke(color.opacity(0.4), lineWidth: 1)
                        )
                    Image(systemName: icon)
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(color)
                }
                .frame(width: 44, height: 44)

                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text(title)
                            .font(.system(size: 15, weight: .bold))
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
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.secondary)
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: AppTheme.cardCornerRadius, style: .continuous)
                    .fill(AppTheme.cardBackground)
                    .overlay(
                        RoundedRectangle(cornerRadius: AppTheme.cardCornerRadius, style: .continuous)
                            .stroke(AppTheme.cardBorder, lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
    }
}
