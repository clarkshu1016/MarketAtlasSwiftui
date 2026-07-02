import GoogleSignIn
import SwiftUI

@main
struct MarketAtlasApp: App {
    private let googleClientID = "79484742801-eteenr1ve7lprp09ffk5afhdhqu6j5dm.apps.googleusercontent.com"

    init() {
        GIDSignIn.sharedInstance.configuration = GIDConfiguration(clientID: googleClientID)
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .onOpenURL { GIDSignIn.sharedInstance.handle($0) }
        }
    }
}
