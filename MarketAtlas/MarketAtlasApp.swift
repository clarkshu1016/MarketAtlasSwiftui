import GoogleSignIn
import SwiftUI

@main
struct MarketAtlasApp: App {
    // Each bundle ID (Release / Debug "MarketAtlas Dev") has its own iOS OAuth client in Google Cloud;
    // GOOGLE_REVERSED_CLIENT_ID in the build settings holds the matching URL scheme.
    #if DEBUG
    private let googleClientID = "79484742801-0ntmf1iq3lkjgci4kj17i30lfpcj6dhr.apps.googleusercontent.com"
    #else
    private let googleClientID = "79484742801-eteenr1ve7lprp09ffk5afhdhqu6j5dm.apps.googleusercontent.com"
    #endif

    @State private var entitlements = EntitlementManager()
    @State private var ai = AIAvailability()

    init() {
        GIDSignIn.sharedInstance.configuration = GIDConfiguration(clientID: googleClientID)
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(entitlements)
                .environment(ai)
                .task { await entitlements.start() }
                .task { await ai.start() }
                .onOpenURL { GIDSignIn.sharedInstance.handle($0) }
                #if DEBUG
                .pulseFloatingBubble()
                #endif
        }
    }
}
