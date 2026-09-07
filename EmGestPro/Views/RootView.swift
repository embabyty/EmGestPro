import SwiftUI

struct RootView: View {
    @EnvironmentObject private var store: GestaltStore
    @ObservedObject private var respring = RespringHelper.shared
    @ObservedObject private var patreon = PatreonAuth.shared
    @AppStorage("hasAcceptedDisclaimer") private var hasAcceptedDisclaimer = false

    var body: some View {
        Group {
            switch DeviceCompatibility.currentStatus {
            case .supported:
                MainTabView()
            case .unsupported(let reason):
                UnsupportedView(reason: reason)
            }
        }
        .overlay {
            if respring.isRespringing {
                NeoSpringView()
            }
        }
        // The disclaimer only ever shows once the EAF Ultra gate is open, so
        // the paywall is always the outermost layer.
        .fullScreenCover(isPresented: .constant(!hasAcceptedDisclaimer && patreon.isUnlocked)) {
            DisclaimerView { hasAcceptedDisclaimer = true }
        }
        .fullScreenCover(isPresented: .constant(!patreon.isUnlocked)) {
            PatreonPaywallView()
        }
        .task {
            // Re-check the membership in the background; locks the app if the
            // EAF Ultra subscription has lapsed (offline failures are ignored).
            await patreon.revalidateIfPossible()
        }
    }
}

struct MainTabView: View {
    var body: some View {
        TabView {
            HomeView()
                .tabItem { Label("Tweaks", systemImage: "switch.2") }
            CustomizationView()
                .tabItem { Label("Customization", systemImage: "paintbrush.pointed") }
            SiriAISetupView()
                .tabItem { Label("Siri AI Setup", systemImage: "brain.head.profile") }
            SystemHubView()
                .tabItem { Label("Settings", systemImage: "gearshape") }
        }
    }
}
