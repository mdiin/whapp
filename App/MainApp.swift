import AppCore
import SwiftUI

// The app target is a thin shell: everything else is in the AppCore package.
@main
struct MainApp: App {
    var body: some Scene {
        WindowGroup {
            AppRoot { AppConfig(infoDictionary: Bundle.main.infoDictionary ?? [:]) }
        }
    }
}
