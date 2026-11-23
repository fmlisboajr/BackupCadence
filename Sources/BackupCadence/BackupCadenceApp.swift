import SwiftUI

@main
struct BackupCadenceApp: App {
    @State private var model = AppModel()

    var body: some Scene {
        MenuBarExtra {
            MenuContent(model: model)
        } label: {
            Image(systemName: model.iconName)
        }

        Window("Preferences", id: "preferences") {
            PreferencesView(model: model)
        }
        .windowResizability(.contentSize)
    }
}
