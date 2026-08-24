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

enum FFContainerConstants {
    static let defaultShadersPath = "Documents/contentcache/Optional/ios/gameassetbundles/shaders.HPt9DZviTSXL9hpGW9QNOMigNLA~3D"
    static let defaultCacheResPath = "Documents/contentcache/Compulsory/ios/gameassetbundles/cache_res.CfnFf59sr1SbsqQ6JqTKsEusjKs~3D"
}

// MARK: - Key Authentication & HWID Engine (1, 3, 7, 30 Days & Auto-Clean on Expiry)

@MainActor
final class KeyAuthEngine: ObservableObject {
    static let shared = KeyAuthEngine()

    @Published var currentKey: String = ""
    @Published var isAuthenticated: Bool = false
    @Published var isVerifying: Bool = false
    @Published var errorMessage: String?
    @Published var remainingSeconds: Int = 0
    @Published var durationDays: Int = 0
    @Published var deviceLimit: Int = 1
    @Published var devicesUsed: Int = 1
    @Published var expiresAt: Double?
    @Published var emergencyLinkTitle: String?
    @Published var emergencyLinkURL: String?
    @Published var emergencyMessage: String?
    @Published var isEmergencyMode: Bool = false

    var hwid: String {
        if let saved = UserDefaults.standard.string(forKey: "meomeo_device_hwid"), !saved.isEmpty {
            return saved
        }
        let generated = UIDevice.current.identifierForVendor?.uuidString ?? UUID().uuidString
        UserDefaults.standard.set(generated, forKey: "meomeo_device_hwid")
        return generated
    }

    var deviceName: String {
        AppInfo.displayMachineName
    }

    var osVersion: String {
        AppInfo.osVersion
    }

    private var countdownTimer: Timer?
    private var healthCheckTask: Task<Void, Never>?

    init() {
        if let savedKey = UserDefaults.standard.string(forKey: "meomeo_saved_api_key"), !savedKey.isEmpty {
            self.currentKey = savedKey
            verifyKey(savedKey, silent: true)
        }
        startKeyHealthCheck()
    }

    deinit {
        healthCheckTask?.cancel()
        countdownTimer?.invalidate()
    }

    func startKeyHealthCheck() {
        healthCheckTask?.cancel()
        healthCheckTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 5_000_000_000)
                if Task.isCancelled { break }
                await MainActor.run {
                    self?.performPeriodicVerification()
                }
            }
        }
    }

    private func performPeriodicVerification() {
        guard !currentKey.isEmpty, isAuthenticated else { return }
        verifyKey(currentKey, silent: true)
    }

    func verifyKey(_ key: String, silent: Bool = false) {
        let trimmed = key.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard !trimmed.isEmpty else {
            errorMessage = "Vui lòng nhập API Key!"
            return
        }

        if !silent {
            isVerifying = true
            errorMessage = nil
        }

        let serverUrl = UserDefaults.standard.string(forKey: "admin_api_server_url") ?? FreeFirePatchEngine.defaultApiServerUrl
        guard let url = URL(string: "\(serverUrl)/api/key/verify") else {
            isVerifying = false
            errorMessage = "URL Server không hợp lệ!"
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 4.0

        let payload: [String: Any] = [
            "key": trimmed,
            "hwid": hwid,
            "device_name": deviceName,
            "os_version": osVersion
        ]

        guard let httpBody = try? JSONSerialization.data(withJSONObject: payload) else { return }
        request.httpBody = httpBody

        Task {
            do {
                let (data, response) = try await URLSession.shared.data(for: request)
                guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200,
                      let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                    self.handleInvalidKey(message: "Không thể kết nối đến máy chủ xác thực Key!", linkTitle: nil, linkUrl: nil)
                    return
                }

                let isValid = json["valid"] as? Bool ?? false
                let msg = json["message"] as? String
                let linkTitle = json["link_title"] as? String
                let linkUrl = json["link_url"] as? String

                if isValid {
                    self.currentKey = trimmed
                    self.isAuthenticated = true
                    self.isVerifying = false
                    self.errorMessage = nil
                    self.isEmergencyMode = false
                    self.remainingSeconds = json["remaining_seconds"] as? Int ?? 0
                    self.durationDays = json["duration_days"] as? Int ?? 1
                    self.expiresAt = json["expires_at"] as? Double
                    self.deviceLimit = json["device_limit"] as? Int ?? 1
                    self.devicesUsed = json["devices_used"] as? Int ?? 1
                    self.emergencyLinkTitle = linkTitle
                    self.emergencyLinkURL = linkUrl

                    UserDefaults.standard.set(trimmed, forKey: "meomeo_saved_api_key")
                    self.startCountdown()
                } else {
                    // Khi server bật Kill Switch (server_online = false)
                    let errorType = json["error_type"] as? String ?? ""
                    let serverMsg = json["message"] as? String

                    if errorType == "server_offline" {
                        self.isEmergencyMode = true
                        self.emergencyMessage = serverMsg ?? "Hệ thống đang tạm dừng."
                        self.emergencyLinkTitle = linkTitle
                        self.emergencyLinkURL = linkUrl
                        // Xóa key để bắt buộc nhập lại khi server trở lại
                        UserDefaults.standard.removeObject(forKey: "meomeo_saved_api_key")
                        FreeFirePatchEngine.shared.cleanAllPatches()
                    } else {
                        self.handleInvalidKey(message: serverMsg ?? "Key không hợp lệ hoặc đã hết hạn!", linkTitle: linkTitle, linkUrl: linkUrl)
                    }
                }
            } catch {
                self.handleInvalidKey(message: "Máy chủ Offline. Chức năng đã tự động khóa để bảo vệ!", linkTitle: nil, linkUrl: nil)
            }
        }
    }

    private func handleInvalidKey(message: String, linkTitle: String?, linkUrl: String?) {
        self.isVerifying = false
        self.isAuthenticated = false
        self.isEmergencyMode = false
        self.errorMessage = message
        self.emergencyLinkTitle = linkTitle
        self.emergencyLinkURL = linkUrl

        UserDefaults.standard.removeObject(forKey: "meomeo_saved_api_key")
        FreeFirePatchEngine.shared.cleanAllPatches()
    }

    func logout() {
        self.isAuthenticated = false
        self.isEmergencyMode = false
        self.currentKey = ""
        self.errorMessage = nil
        UserDefaults.standard.removeObject(forKey: "meomeo_saved_api_key")
        FreeFirePatchEngine.shared.cleanAllPatches()
    }

    private func startCountdown() {
        countdownTimer?.invalidate()
        countdownTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            if self.remainingSeconds > 0 {
                self.remainingSeconds -= 1
            } else if self.isAuthenticated {
                self.handleInvalidKey(message: "Key đã hết hạn sử dụng!", linkTitle: self.emergencyLinkTitle, linkUrl: self.emergencyLinkURL)
            }
        }
    }

    var formattedRemainingTime: String {
        if remainingSeconds <= 0 { return "Đã hết hạn" }
        let days = remainingSeconds / 86400
        let hours = (remainingSeconds % 86400) / 3600
        let minutes = (remainingSeconds % 3600) / 60
        let seconds = remainingSeconds % 60

        if days > 0 {
            return "\(days) ngày \(hours)h \(minutes)p"
        } else if hours > 0 {
            return "\(hours) giờ \(minutes)p \(seconds)s"
        } else {
            return "\(minutes)p \(seconds)s"
        }
    }
}

// MARK: - Authentic Free Fire Game Artwork Icon View

struct GameAsyncIconView: View {
    let bundleID: String
    let size: CGFloat

    private var isFFM: Bool {
        bundleID.contains("max")
    }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.22, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: isFFM
                            ? [Color(red: 0.12, green: 0.02, blue: 0.05), Color(red: 0.28, green: 0.04, blue: 0.08), Color(red: 0.08, green: 0.01, blue: 0.03)]
                            : [Color(red: 0.14, green: 0.06, blue: 0.01), Color(red: 0.32, green: 0.12, blue: 0.02), Color(red: 0.09, green: 0.03, blue: 0.01)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: size * 0.22, style: .continuous)
                        .stroke(
                            LinearGradient(
                                colors: isFFM
                                    ? [Color(red: 1.00, green: 0.35, blue: 0.45), Color(red: 0.60, green: 0.05, blue: 0.15)]
                                    : [Color(red: 1.00, green: 0.70, blue: 0.20), Color(red: 0.85, green: 0.30, blue: 0.05)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1.5
                        )
                )
                .shadow(color: (isFFM ? Color.red : Color.orange).opacity(0.4), radius: 8, x: 0, y: 3)

            ZStack {
                Circle()
                    .stroke(
                        isFFM ? Color.red.opacity(0.3) : Color.orange.opacity(0.3),
                        lineWidth: 1
                    )
                    .frame(width: size * 0.72, height: size * 0.72)

                Rectangle()
                    .fill(isFFM ? Color.red.opacity(0.4) : Color.orange.opacity(0.4))
                    .frame(width: size * 0.82, height: 1)

                Rectangle()
                    .fill(isFFM ? Color.red.opacity(0.4) : Color.orange.opacity(0.4))
                    .frame(width: 1, height: size * 0.82)
            }

            VStack(spacing: 0) {
                Image(systemName: isFFM ? "bolt.shield.fill" : "flame.circle.fill")
                    .font(.system(size: size * 0.32, weight: .black))
                    .foregroundStyle(
                        LinearGradient(
                            colors: isFFM
                                ? [Color.white, Color(red: 1.0, green: 0.3, blue: 0.4)]
                                : [Color.white, Color(red: 1.0, green: 0.7, blue: 0.2)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )

                Text(isFFM ? "FREE FIRE" : "FREE FIRE")
                    .font(.system(size: size * 0.13, weight: .black, design: .monospaced))
                    .foregroundStyle(.white)
                    .tracking(0.5)

                Text(isFFM ? "★ MAX ★" : "★ TH ★")
                    .font(.system(size: size * 0.11, weight: .heavy, design: .rounded))
                    .foregroundStyle(isFFM ? Color(red: 1.0, green: 0.4, blue: 0.5) : Color(red: 1.0, green: 0.8, blue: 0.3))
                    .padding(.horizontal, 4)
                    .padding(.vertical, 0.5)
                    .background(Color.black.opacity(0.6))
                    .clipShape(Capsule())
            }
        }
        .frame(width: size, height: size)
    }
}

// MARK: - Free Fire Patch Engine (5s Healthcheck & Clean When Offline)

@MainActor
final class FreeFirePatchEngine: ObservableObject {
    static let shared = FreeFirePatchEngine()

    static let defaultApiServerUrl = "http://103.238.234.204:5000"

    @Published var patches: [FFPatchItem] = []
    @Published var isApplying = false
    @Published var isFetching = false
    @Published var statusMessage: String?
    @Published var isOfflineMode = false
    @Published var currentBundleID: String = ""

    private var pollingTask: Task<Void, Never>?

    init() {
        start5sHealthCheck()
    }

    deinit {
        pollingTask?.cancel()
    }

    func start5sHealthCheck() {
        pollingTask?.cancel()
        pollingTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 5_000_000_000)
                if Task.isCancelled { break }
                await MainActor.run {
                    self?.performPeriodicCheck()
                }
            }
        }
    }

    private func performPeriodicCheck() {
        guard !currentBundleID.isEmpty else { return }
        let serverUrl = UserDefaults.standard.string(forKey: "admin_api_server_url") ?? Self.defaultApiServerUrl
        fetchPatchesFromAdmin(serverUrl: serverUrl, bundleID: currentBundleID, silent: true)
    }

    func fetchPatchesFromAdmin(serverUrl: String, bundleID: String, silent: Bool = false) {
        currentBundleID = bundleID
        if !silent {
            isFetching = true
            statusMessage = "Đang kiểm tra kết nối API..."
        }

        let cleanUrl = serverUrl.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = URL(string: "\(cleanUrl)/api/patches?bundle=\(bundleID)&active=true") else {
            isFetching = false
            isOfflineMode = true
            patches = []
            statusMessage = "URL Server không hợp lệ. Đã ẩn chức năng để tránh lỗi!"
            return
        }

        var request = URLRequest(url: url)
        request.timeoutInterval = 3.5

        Task {
            do {
                let (data, response) = try await URLSession.shared.data(for: request)
                guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200,
                      let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                      let success = json["success"] as? Bool, success,
                      let rawList = json["patches"] as? [[String: Any]] else {
                    self.isFetching = false
                    self.isOfflineMode = true
                    self.patches = []
                    self.statusMessage = "Máy chủ phản hồi lỗi. Đã tạm ẩn chức năng để an toàn!"
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
                self.statusMessage = "API Online • \(fetched.count) chức năng sẵn sàng!"
            } catch {
                self.isFetching = false
                self.isOfflineMode = true
                self.patches = []
                self.statusMessage = "Máy chủ API Offline. Đã tự động dọn dẹp để bảo vệ game!"
            }
        }
    }

    func togglePatch(id: String, bundleID: String, serverUrl: String) {
        guard let index = patches.firstIndex(where: { $0.id == id }) else { return }
        patches[index].isEnabled.toggle()

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
        statusMessage = "Đã tự động kích hoạt toàn bộ mục \(category.rawValue)!"
    }

    func cleanAllPatches() {
        let fileManager = FileManager.default
        let bundles = ["com.dts.freefireth", "com.dts.freefiremax"]

        for bundleID in bundles {
            guard let containerPath = ContainerStore.resolveAppContainerPath(bundleID: bundleID) else { continue }
            let containerURL = URL(fileURLWithPath: containerPath, isDirectory: true)

            guard let cacheBase = try? fileManager.url(for: .cachesDirectory, in: .userDomainMask, appropriateFor: nil, create: true) else { continue }
            let backupBaseDir = cacheBase.appendingPathComponent("MeoMeoBackups/\(bundleID)", isDirectory: true)

            if let patchDirs = try? fileManager.contentsOfDirectory(at: backupBaseDir, includingPropertiesForKeys: nil) {
                for patchDir in patchDirs {
                    let manifestURL = patchDir.appendingPathComponent("manifest.json")
                    if let data = try? Data(contentsOf: manifestURL),
                       let manifest = try? JSONDecoder().decode(BackupManifest.self, from: data) {
                        for entry in manifest.entries {
                            let targetURL = containerURL.appendingPathComponent(entry.relativePath)
                            let backupFileURL = patchDir.appendingPathComponent(entry.backupFilename)
                            if fileManager.fileExists(atPath: targetURL.path) {
                                try? fileManager.removeItem(at: targetURL)
                            }
                            if entry.existedBefore && fileManager.fileExists(atPath: backupFileURL.path) {
                                try? fileManager.copyItem(at: backupFileURL, to: targetURL)
                            }
                        }
                    }
                    try? fileManager.removeItem(at: patchDir)
                }
            }
        }

        self.patches = []
        self.statusMessage = "Đã dọn dẹp và khôi phục toàn bộ file gốc!"
    }

    private func applyPatchOperation(patch: FFPatchItem, bundleID: String, serverUrl: String, isEnabling: Bool) {
        isApplying = true
        statusMessage = isEnabling ? "Đang áp dụng: \(patch.name)…" : "Đang khôi phục gốc: \(patch.name)…"

        Task.detached(priority: .userInitiated) {
            let fileManager = FileManager.default

            guard let containerPath = ContainerStore.resolveAppContainerPath(bundleID: bundleID) else {
                await MainActor.run {
                    self.isApplying = false
                    self.statusMessage = "Chưa tìm thấy container game \(bundleID). Hãy mở game 1 lần trước."
                }
                return
            }

            let containerURL = URL(fileURLWithPath: containerPath, isDirectory: true)

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
                        let relPath = patch.targetRelativePath ?? FFContainerConstants.defaultShadersPath
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

                    let manifest = BackupManifest(patchID: patch.id, bundleID: bundleID, entries: entriesToRecord)
                    if let manifestData = try? JSONEncoder().encode(manifest) {
                        try manifestData.write(to: manifestURL, options: .atomic)
                    }

                    await MainActor.run {
                        self.isApplying = false
                        self.statusMessage = "Đã kích hoạt: \(patch.name)"
                    }
                } else {
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
                        let fallbackPaths = [FFContainerConstants.defaultShadersPath, FFContainerConstants.defaultCacheResPath]
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

// MARK: - Free Fire Detail View (5s Check & Clean Offline)

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
                topNavBar

                ScrollView {
                    VStack(spacing: 14) {
                        gameHeroBanner

                        categoryTabs

                        menuPatchCard

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

            HStack(spacing: 4) {
                Circle()
                    .fill(engine.isOfflineMode ? Color.red : Color.green)
                    .frame(width: 7, height: 7)
                Text(engine.isOfflineMode ? "OFF" : "LIVE")
                    .font(.system(size: 9, weight: .black, design: .monospaced))
                    .foregroundStyle(engine.isOfflineMode ? Color.red : Color.green)
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(Color(uiColor: .tertiarySystemFill))
            .clipShape(Capsule())
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color(uiColor: .secondarySystemBackground))
    }

    // MARK: - Game Hero Banner With High-Res Art
    private var gameHeroBanner: some View {
        HStack(spacing: 14) {
            GameAsyncIconView(bundleID: bundleID, size: 56)

            VStack(alignment: .leading, spacing: 3) {
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

    // MARK: - Menu Patch Card (Auto-clean when Offline)
    private var menuPatchCard: some View {
        VStack(spacing: 0) {
            HStack {
                Text("DANH SÁCH CHỨC NĂNG")
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundStyle(.secondary)

                Spacer()

                if !filteredPatches.isEmpty {
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
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)

            Divider()

            if engine.isOfflineMode {
                VStack(spacing: 8) {
                    Image(systemName: "wifi.slash")
                        .font(.system(size: 28))
                        .foregroundStyle(.red)

                    Text("MÁY CHỦ API OFFLINE")
                        .font(.system(size: 13, weight: .bold, design: .monospaced))
                        .foregroundStyle(.red)

                    Text("Đã tự động ẩn chức năng để tránh lỗi game.\nKhi server online trở lại, chức năng sẽ tự động hiện lên.")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.vertical, 28)
                .frame(maxWidth: .infinity)
            } else if filteredPatches.isEmpty {
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
                .foregroundStyle(engine.isOfflineMode ? Color.red : Color.green)
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
                        .stroke(engine.isOfflineMode ? Color.red.opacity(0.3) : Color.green.opacity(0.3), lineWidth: 1)
                )
        )
    }
}

// MARK: - Key Login View (Khi chưa nhập Key hoặc Key Hết Hạn)

struct KeyLoginView: View {
    @StateObject private var keyEngine = KeyAuthEngine.shared
    @State private var inputKey: String = ""

    var body: some View {
        VStack(spacing: 16) {
            // Header (Không icon chìa khoá, giao diện tinh gọn chuẩn VIP)
            VStack(spacing: 4) {
                Text("KÍCH HOẠT \(BrandConfigStore.shared.appName.uppercased())")
                    .font(.system(size: 16, weight: .black, design: .monospaced))
                    .foregroundStyle(.primary)

                Text("Nhập mã API Key (12H / 1 / 3 / 7 / 30 Ngày) để mở khóa chức năng")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.top, 4)

            Divider()

            // Input Field
            VStack(alignment: .leading, spacing: 6) {
                Text("MÃ KEY BẢN QUYỀN")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundStyle(.secondary)

                HStack(spacing: 8) {
                    TextField("MEOMEO-XXXX-XXXX...", text: $inputKey)
                        .textInputAutocapitalization(.characters)
                        .autocorrectionDisabled()
                        .font(.system(size: 13, weight: .bold, design: .monospaced))
                        .padding(10)
                        .background(Color(uiColor: .tertiarySystemFill))
                        .clipShape(RoundedRectangle(cornerRadius: 6))

                    Button {
                        if let clip = UIPasteboard.general.string {
                            inputKey = clip.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
                        }
                    } label: {
                        Text("DÁN")
                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                            .foregroundStyle(AppTheme.accent)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 10)
                            .background(AppTheme.accent.opacity(0.15))
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                    }
                }
            }

            // Error Banner (Nếu có)
            if let err = keyEngine.errorMessage {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.red)
                    Text(err)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.red)
                    Spacer()
                }
                .padding(10)
                .background(Color.red.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 6))
            }

            // Nút Kích Hoạt Key
            Button {
                keyEngine.verifyKey(inputKey)
            } label: {
                HStack(spacing: 8) {
                    if keyEngine.isVerifying {
                        ProgressView().tint(.white)
                    } else {
                        Text("XÁC NHẬN KÍCH HOẠT")
                    }
                }
                .font(.system(size: 13, weight: .black, design: .monospaced))
                .frame(maxWidth: .infinity, minHeight: 44)
                .background(AppTheme.accent)
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .shadow(color: AppTheme.accent.opacity(0.3), radius: 8, x: 0, y: 3)
            }
            .disabled(keyEngine.isVerifying || inputKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

            // Nút Vàng: Lấy Key Miễn Phí 12H Vượt Link
            Button {
                let serverUrl = UserDefaults.standard.string(forKey: "admin_api_server_url") ?? FreeFirePatchEngine.defaultApiServerUrl
                if let url = URL(string: "\(serverUrl)/getkey?hwid=\(keyEngine.hwid)") {
                    UIApplication.shared.open(url)
                }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "bolt.circle.fill")
                    Text("LẤY KEY MIỄN PHÍ (12H)")
                }
                .font(.system(size: 12, weight: .bold, design: .monospaced))
                .frame(maxWidth: .infinity, minHeight: 38)
                .background(
                    LinearGradient(
                        colors: [Color(red: 0.95, green: 0.75, blue: 0.10), Color(red: 0.85, green: 0.50, blue: 0.05)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .foregroundStyle(.black)
                .clipShape(RoundedRectangle(cornerRadius: 6))
            }
            .buttonStyle(.plain)

            Divider()

            // HWID & Device Info Box
            VStack(spacing: 4) {
                HStack {
                    Text("Thiết Bị:")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text("\(keyEngine.deviceName) • iOS \(keyEngine.osVersion)")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundStyle(.primary)
                }

                HStack {
                    Text("Mã HWID:")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(keyEngine.hwid)
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
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
}

// MARK: - License & Device Info Card (Khi Đã Kích Hoạt Key Thành Công)

struct KeyInfoCardView: View {
    @StateObject private var keyEngine = KeyAuthEngine.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                HStack(spacing: 6) {
                    Circle().fill(Color.green).frame(width: 7, height: 7)
                    Text("KEY BẢN QUYỀN ĐANG HOẠT ĐỘNG")
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundStyle(Color.green)
                }

                Spacer()

                Button {
                    keyEngine.logout()
                } label: {
                    Text("ĐĂNG XUẤT")
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .foregroundStyle(.red)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.red.opacity(0.12))
                        .clipShape(RoundedRectangle(cornerRadius: 3))
                }
            }

            Divider()

            VStack(spacing: 6) {
                infoRow(label: "Mã Key:", value: keyEngine.currentKey)
                infoRow(label: "Thời Hạn Còn Lại:", value: keyEngine.formattedRemainingTime, highlight: true)
                infoRow(label: "Giới Hạn Thiết Bị:", value: "\(keyEngine.devicesUsed)/\(keyEngine.deviceLimit) máy (Khóa HWID)")
                infoRow(label: "Mã HWID:", value: String(keyEngine.hwid.prefix(16)) + "...")
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: AppTheme.cardCornerRadius, style: .continuous)
                .fill(AppTheme.cardBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: AppTheme.cardCornerRadius, style: .continuous)
                        .stroke(Color.green.opacity(0.3), lineWidth: 1)
                )
        )
    }

    private func infoRow(label: String, value: String, highlight: Bool = false) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundStyle(highlight ? AppTheme.accent : .primary)
        }
    }
}

// MARK: - Main Patch Projects View (Function Hub)

struct PatchProjectsView: View {
    @Environment(\.appLanguage) private var language
    @StateObject private var keyEngine = KeyAuthEngine.shared
    var onToggleSidebar: (() -> Void)? = nil

    init(onToggleSidebar: (() -> Void)? = nil) {
        self.onToggleSidebar = onToggleSidebar
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 14) {
                    if keyEngine.isAuthenticated {
                        // Key Information Card
                        KeyInfoCardView()

                        // Free Fire Game Cards
                        freeFireHubSection
                    } else {
                        // Key Activation Required Form
                        KeyLoginView()
                    }
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

    // MARK: - Free Fire Game Injection Hub With Real Image Artwork
    private var freeFireHubSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("DANH SÁCH GAME HỖ TRỢ")
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundStyle(AppTheme.accent)

                Spacer()

                Text("LIVE API • 5S AUTO SYNC")
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundStyle(Color.green)
            }

            VStack(spacing: 12) {
                // Free Fire Standard (FFT)
                gameCard(
                    title: "Free Fire Standard (FFT)",
                    bundleID: "com.dts.freefireth",
                    badgeText: "FFT",
                    badgeColor: Color(red: 1.00, green: 0.50, blue: 0.10)
                )

                // Free Fire MAX (FFM)
                gameCard(
                    title: "Free Fire MAX (FFM)",
                    bundleID: "com.dts.freefiremax",
                    badgeText: "FFM",
                    badgeColor: Color(red: 1.00, green: 0.20, blue: 0.30)
                )
            }
        }
    }

    private func gameCard(
        title: String,
        bundleID: String,
        badgeText: String,
        badgeColor: Color
    ) -> some View {
        NavigationLink(destination: FreeFireDetailView(gameTitle: title, bundleID: bundleID)) {
            HStack(spacing: 14) {
                GameAsyncIconView(bundleID: bundleID, size: 50)

                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text(title)
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(.primary)

                        Text(badgeText)
                            .font(.system(size: 9, weight: .black, design: .monospaced))
                            .foregroundStyle(badgeColor)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1.5)
                            .background(badgeColor.opacity(0.15))
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
        .buttonStyle(.plain)
    }
}
