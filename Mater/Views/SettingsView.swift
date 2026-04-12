import SwiftUI

struct SettingsView: View {
    @Bindable var preferences: AppPreferences

    private let workRange = 1...60
    private let breakRange = 1...30

    var body: some View {
        Form {
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
        .formStyle(.grouped)
        .frame(width: 280)
        .fixedSize(horizontal: false, vertical: true)
        .padding()
    }
}
