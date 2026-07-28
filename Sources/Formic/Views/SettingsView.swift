import SwiftUI

struct SettingsView: View {
    @AppStorage("openLastDocumentAtLaunch") private var openLastDocumentAtLaunch = false
    @AppStorage("rememberVisualSignatures") private var rememberVisualSignatures = true

    var body: some View {
        TabView {
            Form {
                Toggle("Reopen the last document at launch", isOn: $openLastDocumentAtLaunch)
            }
            .formStyle(.grouped)
            .tabItem {
                Label("General", systemImage: "gearshape")
            }

            Form {
                Toggle("Remember visual signatures on this Mac", isOn: $rememberVisualSignatures)
                Text("Formic keeps document processing local by default.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .formStyle(.grouped)
            .tabItem {
                Label("Privacy", systemImage: "hand.raised")
            }
        }
        .padding()
        .frame(width: 480, height: 300)
    }
}
