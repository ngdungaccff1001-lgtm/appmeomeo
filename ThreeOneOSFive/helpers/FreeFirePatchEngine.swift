import Foundation
import UIKit

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
