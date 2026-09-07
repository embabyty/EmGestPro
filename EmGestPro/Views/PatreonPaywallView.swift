//
//  PatreonPaywallView.swift
//  EmGestPro
//
//  The EmGestPro Ultra gate. Presented full-screen on launch (and whenever the
//  EAF Ultra membership lapses) so the app can't be used without an active
//  subscription. The only way past it is a successful Patreon sign-in that
//  verifies the active EAF Ultra tier.
//

import SwiftUI
import AuthenticationServices

struct PatreonPaywallView: View {
    @Environment(\.webAuthenticationSession) private var webAuthenticationSession
    @ObservedObject private var auth = PatreonAuth.shared

    @State private var isBusy = false
    @State private var errorMessage: String?
    @State private var showError = false

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 18) {
                    header
                    featureList
                    if let name = auth.subscriberName, !name.isEmpty {
                        Text("Signed in as \(name)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.top, 48)
                .padding(.bottom, 20)
            }
            .scrollIndicators(.hidden)

            VStack(spacing: 12) {
                ActionButton(
                    title: "Sign in with Patreon",
                    systemImage: "person.crop.circle.badge.checkmark",
                    isBusy: isBusy,
                    action: { Task { await signIn() } }
                )

                Link(destination: URL(string: PatreonConfig.campaignPageURL)!) {
                    Text("Become an EAF Ultra member")
                        .font(.subheadline.weight(.medium))
                        .frame(maxWidth: .infinity)
                }
                .glassAction()
            }
            .padding(.bottom, 12)
        }
        .padding(Theme.pagePadding)
        .background(Color(uiColor: .systemGroupedBackground))
        .alert("EmGestPro Ultra", isPresented: $showError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "Something went wrong.")
        }
    }

    private var header: some View {
        VStack(spacing: 14) {
            AppMark(name: "Logo", size: 84)
            Text("EmGestPro Ultra")
                .font(.largeTitle.weight(.bold))
            Text("Unlock EmGestPro with your EAF Ultra membership")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.bottom, 8)
    }

    private var featureList: some View {
        VStack(alignment: .leading, spacing: 12) {
            feature("Infinity", "Unlimited access to every tweak and tool")
            feature("person.2.fill", "Support the continued development of EmGestPro")
            feature("sparkles", "Early access to new features and updates")
        }
        .padding(18)
        .liquidGlass()
    }

    private func feature(_ symbol: String, _ text: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: symbol)
                .font(.title3)
                .foregroundStyle(Theme.accent)
                .frame(width: 28)
            Text(text)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
    }

    // MARK: - Sign in

    private func signIn() async {
        guard PatreonConfig.isConfigured else {
            errorMessage = PatreonAuthError.notConfigured.errorDescription
            showError = true
            return
        }
        isBusy = true
        defer { isBusy = false }
        do {
            let authURL = try buildAuthorizeURL()
            let callback = try await webAuthenticationSession.authenticate(
                using: authURL,
                callbackURLScheme: PatreonConfig.redirectScheme
            )
            guard let code = URLComponents(string: callback.absoluteString)?
                    .queryItems?.first(where: { $0.name == "code" })?.value else {
                throw PatreonAuthError.missingCode
            }
            try await PatreonAuth.shared.completeAuthorization(withCode: code)
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            showError = true
        }
    }

    private func buildAuthorizeURL() throws -> URL {
        guard var components = URLComponents(string: PatreonConfig.authorizeURL) else {
            throw PatreonAuthError.network("Invalid Patreon authorize URL.")
        }
        components.queryItems = [
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "client_id", value: PatreonConfig.clientID),
            URLQueryItem(name: "redirect_uri", value: PatreonConfig.redirectURI),
            URLQueryItem(name: "scope", value: PatreonConfig.scopes),
            URLQueryItem(name: "state", value: UUID().uuidString)
        ]
        guard let url = components.url else {
            throw PatreonAuthError.network("Invalid Patreon authorize URL.")
        }
        return url
    }
}
