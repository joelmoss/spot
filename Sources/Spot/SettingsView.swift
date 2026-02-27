import SwiftUI

struct SettingsView: View {
    @AppStorage("showControls") private var showControls = true

    var body: some View {
        Form {
            Toggle("Show track controls", isOn: $showControls)
        }
        .formStyle(.grouped)
        .frame(width: 280)
        .fixedSize()
    }
}
