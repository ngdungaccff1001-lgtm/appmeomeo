import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.appLanguage) private var language
    @EnvironmentObject private var appState: AppState
    @AppStorage(AppLanguage.storageKey) private var languageCode = AppLanguage.vietnamese.rawValue
    @AppStorage("app.appearance") private var appearance = AppAppearance.system.rawValue

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack(spacing: 14) {
                        AppLogo(size: 38)

                        VStack(alignment: .leading, spacing: 3) {
                            Text("MeoMeoPath")
                                .font(.headline)
                                .fontWeight(.bold)
                            Text("Phiên bản \(appVersion) • APIMeoMeo")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                }

                Section("Theme / Chế độ hiển thị") {
                    Picker("Theme", selection: $appearance) {
                        ForEach(AppAppearance.allCases) { item in
                            Text(item.displayName).tag(item.rawValue)
                        }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                }

                Section("Ngôn ngữ / Language") {
                    Picker("Ngôn ngữ", selection: $languageCode) {
                        ForEach(AppLanguage.allCases) { option in
                            Text(option.displayName).tag(option.rawValue)
                        }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                }

                Section("Thông tin thiết bị") {
                    LabeledContent("Mẫu thiết bị", value: AppInfo.displayMachineName)
                    LabeledContent("Phiên bản iOS", value: "\(AppInfo.osVersion) (\(AppInfo.osBuild))")
                }

                Section("Hỗ trợ hệ điều hành") {
                    HStack {
                        Text("Trạng thái thiết bị")
                        Spacer()
                        Text("Hỗ trợ iOS 15 - 27")
                            .foregroundStyle(Color.green)
                            .fontWeight(.semibold)
                    }
                }
            }
            .tint(AppTheme.accent)
            .navigationTitle("Cài Đặt")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Xong") { dismiss() }
                        .fontWeight(.semibold)
                }
            }
        }
    }

    private var appVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "AppReleaseDisplayVersion") as? String
            ?? Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
            ?? "2.0.0"
    }
}
