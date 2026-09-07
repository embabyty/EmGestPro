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
//    2. Add `emgestpro://patreon-callback` to the client's allowed
//       redirect URIs, and enable the v2 scopes:
//       `identity`, `identity[email]`, `identity.memberships`.
//    3. Paste the Client ID and Client Secret into `clientID` / `clientSecret`
//       below.
//
//  IMPORTANT: never commit your real Client Secret to a public repository.
//  This file ships with placeholder values so the project still builds; fill
//  them in locally before distributing a build.
//

import Foundation

enum PatreonConfig {
    // Fill these in with the values from your Patreon client.
    static let clientID = "YOUR_PATREON_CLIENT_ID"
    static let clientSecret = "YOUR_PATREON_CLIENT_SECRET"

    /// The custom URL scheme used to hand the OAuth redirect back to the app.
    /// Must be registered in Info.plist and match the client's redirect URI.
    static let redirectScheme = "emgestpro"
    static let redirectURI = "emgestpro://patreon-callback"

    static let authorizeURL = "https://www.patreon.com/oauth2/authorize"
    static let tokenURL = "https://www.patreon.com/api/oauth2/token"
    static let identityURL = "https://www.patreon.com/api/oauth2/v2/identity"

    /// The Patreon page patrons visit to subscribe / manage their pledge.
    static let campaignPageURL = "https://www.patreon.com/cw/EmAppleFlagship"

    /// The exact tier title required to unlock the app.
    static let ultraTierTitle = "EAF Ultra"

    /// OAuth scopes needed to read the user's identity and memberships.
    static let scopes = "identity identity.memberships"

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
