import SwiftUI

// MARK: - Brand & Seller Token Dynamic Store

@MainActor
final class BrandConfigStore: ObservableObject {
    static let shared = BrandConfigStore()

    @AppStorage("seller_brand_token") var sellerToken: String = ""
    @Published var appName: String = "MeoMeoPath"
    @Published var welcomeTitle: String = "CHÀO MỪNG ĐẾN APIMEOMEO"
    @Published var welcomeSubtitle: String = "Hệ thống Mod & Patch Tối Ưu Game Free Fire Chuyên Nghiệp"
    @Published var telegramURL: String = "https://t.me/ioscrackvn"
    @Published var telegramTitle: String = "LIÊN HỆ TELEGRAM"
    @Published var isLoading: Bool = false
    @Published var isCustomBranded: Bool = false

    init() {
        fetchBrandConfig()
    }

    func fetchBrandConfig(token: String? = nil) {
        let activeToken = (token ?? sellerToken).trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        let serverUrl = UserDefaults.standard.string(forKey: "admin_api_server_url") ?? FreeFirePatchEngine.defaultApiServerUrl

        guard let url = URL(string: "\(serverUrl)/api/brand?token=\(activeToken)") else { return }

        isLoading = true

        Task {
            do {
                let (data, response) = try await URLSession.shared.data(from: url)
                guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200,
                      let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                    self.isLoading = false
                    return
                }

                let success = json["success"] as? Bool ?? false
                self.appName = json["app_name"] as? String ?? "MeoMeoPath"
                self.welcomeTitle = json["welcome_title"] as? String ?? "CHÀO MỪNG ĐẾN APIMEOMEO"
                self.welcomeSubtitle = json["welcome_subtitle"] as? String ?? "Hệ thống Mod & Patch Tối Ưu Game Free Fire Chuyên Nghiệp"
                self.telegramURL = json["telegram_url"] as? String ?? "https://t.me/ioscrackvn"
                self.telegramTitle = json["telegram_title"] as? String ?? "LIÊN HỆ TELEGRAM"
                self.isCustomBranded = success
                self.isLoading = false
            } catch {
                self.isLoading = false
            }
        }
    }

    func applyToken(_ newToken: String) {
        let clean = newToken.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        self.sellerToken = clean
        fetchBrandConfig(token: clean)
    }

    func resetToDefault() {
        self.sellerToken = ""
        self.appName = "MeoMeoPath"
        self.welcomeTitle = "CHÀO MỪNG ĐẾN APIMEOMEO"
        self.welcomeSubtitle = "Hệ thống Mod & Patch Tối Ưu Game Free Fire Chuyên Nghiệp"
        self.telegramURL = "https://t.me/ioscrackvn"
        self.telegramTitle = "LIÊN HỆ TELEGRAM"
        self.isCustomBranded = false
        fetchBrandConfig(token: "")
    }
}
