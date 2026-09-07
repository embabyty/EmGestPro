//
//  PatreonConfig.swift
//  EmGestPro
//
//  Configuration for the EmGestPro Ultra Patreon paywall.
//
//  Setup (one time, by the creator):
//    1. Create a Patreon v2 client at:
//       https://www.patreon.com/portal/registration/register-clients
//       (sign in with your creator account — EmAppleFlagship).
//    2. Add `https://embabyty.github.io/EmGestPro/patreon-callback.html`
//       to the client's allowed redirect URIs, and enable the v2 scopes:
//       `identity`, `identity[email]`, `identity.memberships`.
//    3. Put the Client ID and Client Secret into your local `.env` file
//       (`PATREON_CLIENT_ID` / `PATREON_CLIENT_SECRET`); the pre-build phase
//       injects them into the gitignored PatreonSecrets.swift.
//
//  IMPORTANT: never commit your real Client Secret to a public repository.
//  This repo ships with placeholder values (via scripts/generate_secrets.sh)
//  so the project still builds; fill in `.env` locally before distributing a
//  build.
//

import Foundation

enum PatreonConfig {
    /// The Patreon v2 OAuth client credentials. Read from the local .env file
    /// via the gitignored PatreonSecrets.swift (see scripts/generate_secrets.sh)
    /// so real secrets are never committed. Without .env values they fall back
    /// to placeholders and `isConfigured` is false.
    static var clientID: String { PatreonSecrets.clientID }
    static var clientSecret: String { PatreonSecrets.clientSecret }

    /// The custom URL scheme used to hand the OAuth redirect back to the app.
    /// Must be registered in Info.plist. Patreon only accepts http(s) redirect
    /// URIs, so the registered redirect URI (below) is the GitHub Pages bridge
    /// page `docs/patreon-callback.html`, which forwards the OAuth code to
    /// this scheme; the app's callback then arrives at `emgestpro://...`.
    static let redirectScheme = "emgestpro"
    static let redirectURI = "https://embabyty.github.io/EmGestPro/patreon-callback.html"

    static let authorizeURL = "https://www.patreon.com/oauth2/authorize"
    static let tokenURL = "https://www.patreon.com/api/oauth2/token"
    static let identityURL = "https://www.patreon.com/api/oauth2/v2/identity"

    /// The Patreon page patrons visit to subscribe / manage their pledge.
    static let campaignPageURL = "https://www.patreon.com/cw/EmAppleFlagship"

    /// The exact tier title required to unlock the app.
    static let ultraTierTitle = "EAF Ultra"

    /// The EmAppleFlagship campaign owner's Patreon email (from the local .env
    /// file, injected at build time into the gitignored PatreonSecrets.swift).
    /// When a signed-in user's email matches, EmGestPro Ultra unlocks
    /// automatically without requiring an active EAF Ultra membership. Empty
    /// means the creator auto-unlock is disabled.
    static var ownerEmail: String { PatreonSecrets.ownerEmail }

    /// OAuth scopes needed to read the user's identity, email and memberships.
    static let scopes = "identity identity.memberships identity[email]"

    /// How long a verified session stays unlocked without re-verifying.
    static let sessionDays: Int = 7

    /// Patreon requires a descriptive User-Agent header or requests may be
    /// dropped with a 403.
    static let userAgent = "EmGestPro Ultra"

    /// True once the placeholders have been replaced with real credentials.
    static var isConfigured: Bool {
        !clientID.contains("YOUR_") && !clientSecret.contains("YOUR_")
    }
}
