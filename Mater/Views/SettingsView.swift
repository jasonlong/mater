import SwiftUI

struct SettingsView: View {
    enum Tab: String, Hashable {
        case general
        case about

        var title: String {
            switch self {
            case .general: "General"
            case .about: "About"
            }
        }

        var systemImage: String {
            switch self {
            case .general: "gearshape"
            case .about: "info.circle"
            }
        }
    }

    @Bindable var preferences: AppPreferences
    @State private var selectedTab: Tab = .general

    var body: some View {
        VStack(spacing: 0) {
            SettingsTabBar(selection: $selectedTab)

            Divider()

            Group {
                switch selectedTab {
                case .general:
                    GeneralSettingsPane(preferences: preferences)
                case .about:
                    AboutSettingsPane()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .frame(width: 420, height: 420)
    }
}

private struct SettingsTabBar: View {
    @Binding var selection: SettingsView.Tab

    var body: some View {
        HStack(spacing: 12) {
            Spacer()

            ForEach([SettingsView.Tab.general, .about], id: \.self) { tab in
                SettingsTabItem(tab: tab, isSelected: selection == tab) {
                    withAnimation(.easeInOut(duration: 0.14)) {
                        selection = tab
                    }
                }
            }

            Spacer()
        }
        .padding(.horizontal, 18)
        .padding(.top, 12)
        .padding(.bottom, 10)
        .background(Color(nsColor: .windowBackgroundColor))
    }
}

private struct SettingsTabItem: View {
    let tab: SettingsView.Tab
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: tab.systemImage)
                    .font(.system(size: 18, weight: .medium))
                Text(tab.title)
                    .font(.system(size: 11.5, weight: .medium))
            }
            .frame(width: 80, height: 50)
            .contentShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .buttonStyle(SettingsTabButtonStyle(isSelected: isSelected))
        .focusEffectDisabled()
    }
}

private struct SettingsTabButtonStyle: ButtonStyle {
    let isSelected: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(isSelected ? Color.accentColor : Color.primary)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(backgroundColor(isPressed: configuration.isPressed))
            )
    }

    private func backgroundColor(isPressed: Bool) -> Color {
        if isPressed {
            return Color.accentColor.opacity(isSelected ? 0.20 : 0.08)
        }
        return isSelected ? Color.accentColor.opacity(0.14) : Color.clear
    }
}

private struct GeneralSettingsPane: View {
    @Bindable var preferences: AppPreferences

    private let workRange = 1...60
    private let breakRange = 1...30

    var body: some View {
        Form {
            Section("Timer") {
                Picker("Work duration", selection: $preferences.workMinutes) {
                    ForEach(Array(workRange), id: \.self) { min in
                        Text("\(min) min").tag(min)
                    }
                }

                Picker("Break duration", selection: $preferences.breakMinutes) {
                    ForEach(Array(breakRange), id: \.self) { min in
                        Text("\(min) min").tag(min)
                    }
                }
            }

            Section("Sound") {
                Toggle("Play sounds", isOn: $preferences.soundEnabled)
            }

            Section("Startup") {
                Toggle("Launch at login", isOn: $preferences.launchAtLogin)
            }
        }
        .formStyle(.grouped)
    }
}

private struct AboutSettingsPane: View {
    private var appVersion: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "–"
        #if DEBUG
        return "\(version)-dev"
        #else
        return version
        #endif
    }

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(spacing: 16) {
                Image(nsImage: NSApp.applicationIconImage)
                    .resizable()
                    .frame(width: 96, height: 96)

                VStack(spacing: 4) {
                    Text("Mater")
                        .font(.system(size: 20, weight: .semibold))

                    Text("v\(appVersion)")
                        .font(.system(size: 13, design: .monospaced))
                        .foregroundStyle(.secondary)
                }

                HStack(spacing: 6) {
                    Text("Made by [Jason Long](https://github.com/jasonlong)")
                    Text("·")
                    Text("[GitHub](https://github.com/jasonlong/mater)")
                }
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
                .tint(.primary)

                Text("Sound effects by [snd.dev](https://snd.dev)")
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)
                    .tint(.secondary)
            }
            .frame(maxWidth: .infinity)

            Spacer()
        }
    }
}
