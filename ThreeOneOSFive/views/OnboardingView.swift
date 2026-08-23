import SwiftUI

private enum OnboardingStep: Int, CaseIterable {
    case language = 0, welcome, versions, install

    var next: OnboardingStep? { Self(rawValue: rawValue + 1) }
    var prev: OnboardingStep? { Self(rawValue: rawValue - 1) }
}

struct OnboardingView: View {
    @AppStorage(AppLanguage.storageKey) private var languageCode = AppLanguage.english.rawValue
    @State private var step: OnboardingStep = .language
    var onComplete: () -> Void

    private var language: AppLanguage { AppLanguage(rawValue: languageCode) ?? .english }

    var body: some View {
        ZStack {
            AppTheme.pageBackground
                .ignoresSafeArea()

            VStack(spacing: 0) {
                header
                pageContent
                controls
            }
        }
        .tint(AppTheme.accent)
        .animation(.easeInOut(duration: 0.2), value: step)
        .animation(.easeInOut(duration: 0.2), value: languageCode)
    }

    private var header: some View {
        VStack(spacing: 8) {
            HStack(spacing: 4) {
                ForEach(OnboardingStep.allCases, id: \.rawValue) { s in
                    Rectangle()
                        .fill(s.rawValue <= step.rawValue ? AppTheme.accent : Color.secondary.opacity(0.2))
                        .frame(height: 3)
                        .frame(maxWidth: s == step ? 30 : 16)
                }
            }
            .padding(.horizontal, AppTheme.pageInset)
            .padding(.top, 16)

            Text(language.text("onboarding.step", "\(step.rawValue + 1)", "\(OnboardingStep.allCases.count)").uppercased())
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private var pageContent: some View {
        ZStack {
            ForEach(OnboardingStep.allCases, id: \.rawValue) { s in
                if s == step {
                    page(for: s)
                        .id("page-\(s.rawValue)-\(languageCode)")
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @ViewBuilder
    private func page(for s: OnboardingStep) -> some View {
        switch s {
        case .language: languagePage
        case .welcome: welcomePage
        case .versions: versionsPage
        case .install: installPage
        }
    }

    private var languagePage: some View {
        VStack(spacing: 16) {
            Spacer(minLength: 8)
            AppLogo(size: 54)

            VStack(spacing: 4) {
                Text(language.text("onboarding.language_title"))
                    .font(.system(size: 18, weight: .bold))
                    .multilineTextAlignment(.center)
                Text(language.text("onboarding.language_subtitle"))
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            VStack(spacing: 8) {
                ForEach(AppLanguage.allCases) { option in
                    Button {
                        languageCode = option.rawValue
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 1) {
                                Text(option.displayName)
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundStyle(.primary)
                                Text(option.rawValue == "en" ? "English" : option.rawValue == "vi" ? "Tiếng Việt" : "简体中文")
                                    .font(.system(size: 11))
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            if languageCode == option.rawValue {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(AppTheme.accent)
                                    .font(.system(size: 13, weight: .bold))
                            }
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: AppTheme.cardCornerRadius, style: .continuous)
                                .fill(Color(uiColor: .secondarySystemBackground))
                                .overlay(
                                    RoundedRectangle(cornerRadius: AppTheme.cardCornerRadius, style: .continuous)
                                        .stroke(languageCode == option.rawValue ? AppTheme.accent : AppTheme.cardBorder, lineWidth: 1)
                                )
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
            Spacer(minLength: 8)
        }
    }

    private var welcomePage: some View {
        VStack(spacing: 16) {
            Spacer(minLength: 8)

            ZStack {
                Rectangle()
                    .fill(AppTheme.accent.opacity(0.12))
                    .overlay(
                        Rectangle().stroke(AppTheme.accent.opacity(0.35), lineWidth: 1)
                    )
                    .frame(width: 56, height: 56)
                Image(systemName: "terminal")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(AppTheme.accent)
            }

            VStack(spacing: 6) {
                Text(language.text("onboarding.welcome_title"))
                    .font(.system(size: 18, weight: .bold))
                    .multilineTextAlignment(.center)
                Text(language.text("onboarding.welcome_message"))
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 20)
            }

            Text(language.text("onboarding.welcome_badge").uppercased())
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundStyle(AppTheme.accent)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(
                    Rectangle()
                        .fill(AppTheme.accent.opacity(0.12))
                        .overlay(
                            Rectangle().stroke(AppTheme.accent.opacity(0.3), lineWidth: 1)
                        )
                )

            Spacer(minLength: 8)
        }
    }

    private var versionsPage: some View {
        VStack(spacing: 12) {
            Spacer(minLength: 6)

            VStack(spacing: 3) {
                Text(language.text("onboarding.versions_title"))
                    .font(.system(size: 16, weight: .bold))
                    .multilineTextAlignment(.center)
                Text(language.text("onboarding.versions_subtitle"))
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 16)
            }

            VStack(alignment: .leading, spacing: 6) {
                versionRow(icon: "checkmark", title: "iOS 17", value: ExploitSupportPolicy.verifiedIOS17Range, color: .green)
                versionRow(icon: "checkmark", title: "iOS 18", value: ExploitSupportPolicy.verifiedIOS18Range, color: .green)
                versionRow(icon: "checkmark", title: "iOS 26", value: ExploitSupportPolicy.verifiedIOS26Range, color: .green)

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Image(systemName: "checkmark").font(.system(size: 11, weight: .bold)).foregroundStyle(.green)
                        Text("iOS 27.0").font(.system(size: 12, weight: .bold, design: .monospaced))
                        Spacer()
                        Text(language.text("onboarding.beta")).font(.system(size: 10, weight: .bold, design: .monospaced)).foregroundStyle(.secondary)
                    }
                    ForEach(ExploitSupportPolicy.verifiedIOS27Builds, id: \.build) { v in
                        HStack {
                            Text("Beta \(v.beta)" + (v.publicBeta.map { " / Public \($0)" } ?? ""))
                                .font(.system(size: 11)).foregroundStyle(.secondary)
                            Spacer()
                            Text(v.build).font(.system(size: 11, design: .monospaced)).foregroundStyle(.secondary)
                        }
                        .padding(.leading, 18)
                    }
                }
                .padding(10)
                .background(
                    RoundedRectangle(cornerRadius: AppTheme.cardCornerRadius, style: .continuous)
                        .fill(Color(uiColor: .secondarySystemBackground))
                        .overlay(
                            RoundedRectangle(cornerRadius: AppTheme.cardCornerRadius, style: .continuous)
                                .stroke(AppTheme.cardBorder, lineWidth: 1)
                        )
                )
            }
            .padding(.horizontal, 16)

            Text(language.text("onboarding.versions_footer", AppInfo.osVersion, AppInfo.osBuild))
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 16)

            Spacer(minLength: 6)
        }
    }

    private var installPage: some View {
        VStack(spacing: 12) {
            Spacer(minLength: 6)

            VStack(spacing: 3) {
                Text(language.text("onboarding.install_title"))
                    .font(.system(size: 16, weight: .bold))
                    .multilineTextAlignment(.center)
                Text(language.text("onboarding.install_message"))
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 16)
            }

            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: "checkmark")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(.green)
                        .padding(.top, 2)
                    Text(language.text("onboarding.install_ok"))
                        .font(.system(size: 12))
                        .foregroundStyle(.primary)
                }
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: AppTheme.cardCornerRadius, style: .continuous)
                        .fill(Color(uiColor: .secondarySystemBackground))
                        .overlay(
                            RoundedRectangle(cornerRadius: AppTheme.cardCornerRadius, style: .continuous)
                                .stroke(Color.green.opacity(0.3), lineWidth: 1)
                        )
                )

                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(.red)
                        .padding(.top, 2)
                    Text(language.text("onboarding.install_bad"))
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: AppTheme.cardCornerRadius, style: .continuous)
                        .fill(Color(uiColor: .secondarySystemBackground))
                        .overlay(
                            RoundedRectangle(cornerRadius: AppTheme.cardCornerRadius, style: .continuous)
                                .stroke(Color.red.opacity(0.2), lineWidth: 1)
                        )
                )
            }
            .padding(.horizontal, 16)

            Text(language.text("onboarding.install_footer"))
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 16)

            Spacer(minLength: 6)
        }
    }

    private func versionRow(icon: String, title: String, value: String, color: Color) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(color)
            Text(title)
                .font(.system(size: 13, weight: .bold, design: .monospaced))
            Spacer()
            Text(value)
                .font(.system(size: 12, design: .monospaced))
                .foregroundStyle(.secondary)
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: AppTheme.cardCornerRadius, style: .continuous)
                .fill(Color(uiColor: .secondarySystemBackground))
                .overlay(
                    RoundedRectangle(cornerRadius: AppTheme.cardCornerRadius, style: .continuous)
                        .stroke(AppTheme.cardBorder, lineWidth: 1)
                )
        )
    }

    private var controls: some View {
        VStack(spacing: 8) {
            HStack(spacing: 10) {
                if step != .language {
                    Button {
                        if let prev = step.prev { step = prev }
                    } label: {
                        Text(language.text("common.back").uppercased())
                            .font(.system(size: 12, weight: .bold, design: .monospaced))
                            .frame(maxWidth: .infinity, minHeight: 38)
                            .background(Color(uiColor: .secondarySystemBackground))
                            .foregroundStyle(.primary)
                            .overlay(
                                Rectangle().stroke(AppTheme.cardBorder, lineWidth: 1)
                            )
                    }
                    .buttonStyle(.plain)
                }

                Button {
                    if let next = step.next {
                        step = next
                    } else {
                        onComplete()
                    }
                } label: {
                    Text(language.text(step == .install ? "common.finish" : "common.next").uppercased())
                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                        .frame(maxWidth: .infinity, minHeight: 38)
                        .background(AppTheme.accent)
                        .foregroundStyle(.white)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)

            if step == .language {
                Text(language.text("onboarding.language_hint"))
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 12)
        .background(Color(uiColor: .secondarySystemBackground))
        .overlay(
            Rectangle().stroke(AppTheme.cardBorder, lineWidth: 1)
        )
    }
}

enum OnboardingStore {
    static let completedVersionKey = "onboarding.completedVersion"
    static let completedFingerprintKey = "onboarding.completedFingerprint"

    static var currentVersion: String {
        let v = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0"
        let b = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "0"
        return "\(v) (\(b))"
    }

    static var bundleToken: String {
        if let exe = Bundle.main.executablePath,
           let attrs = try? FileManager.default.attributesOfItem(atPath: exe),
           let date = attrs[.modificationDate] as? Date {
            return String(Int(date.timeIntervalSince1970))
        }
        if let attrs = try? FileManager.default.attributesOfItem(atPath: Bundle.main.bundlePath),
           let date = (attrs[.creationDate] as? Date) ?? (attrs[.modificationDate] as? Date) {
            return String(Int(date.timeIntervalSince1970))
        }
        return "0"
    }

    static var currentFingerprint: String { "\(currentVersion)#\(bundleToken)" }

    static var completedVersion: String? {
        UserDefaults.standard.string(forKey: completedVersionKey)
    }

    static var completedFingerprint: String? {
        UserDefaults.standard.string(forKey: completedFingerprintKey)
    }

    static func shouldShow() -> Bool {
#if targetEnvironment(simulator)
        if ProcessInfo.processInfo.arguments.contains("--skip-onboarding") { return false }
        if ProcessInfo.processInfo.arguments.contains("--reset-onboarding") { return true }
#endif
        let fp = currentFingerprint
        if let stored = completedFingerprint, !stored.isEmpty {
            return stored != fp
        }
        if let completed = completedVersion, !completed.isEmpty {
            if completed == currentVersion {
                UserDefaults.standard.set(fp, forKey: completedFingerprintKey)
                return false
            }
            return true
        }
        return true
    }

    static func markCompleted() {
        UserDefaults.standard.set(currentVersion, forKey: completedVersionKey)
        UserDefaults.standard.set(currentFingerprint, forKey: completedFingerprintKey)
    }
}
