//
//  PatreonAuth.swift
//  EmGestPro
//
//  Drives the EmGestPro Ultra Patreon paywall: exchanges the OAuth
//  authorization code for a token, verifies the user has an *active* EAF
//  Ultra membership, and keeps the app unlocked for a grace period.
//
//  The web-based "Sign in with Patreon" step is performed by the paywall view
//  (which owns the `webAuthenticationSession` environment value); this type
//  handles everything after the code is returned, plus persistence and
//  background revalidation.
//

import Foundation

enum PatreonAuthError: LocalizedError {
    case notConfigured
    case missingCode
    case tokenExchangeFailed
    case unauthorized
    case notSubscribed
    case network(String)

    var errorDescription: String? {
        switch self {
        case .notConfigured:
            return "This build isn't set up yet. Add your Patreon Client ID and Client Secret to PatreonConfig.swift."
        case .missingCode:
            return "Patreon didn't return an authorization code."
        case .tokenExchangeFailed:
            return "Couldn't exchange the Patreon code for an access token."
        case .unauthorized:
            return "Your Patreon session has expired. Please sign in again."
        case .notSubscribed:
            return "You need an active EAF Ultra membership to use EmGestPro Ultra."
        case .network(let message):
            return message
        }
    }
}

@MainActor
final class PatreonAuth: ObservableObject {

    static let shared = PatreonAuth()

    @Published private(set) var isUnlocked: Bool
    @Published private(set) var subscriberName: String?
    @Published private(set) var subscriberTier: String?
    @Published private(set) var isVerifying = false

    private let defaults = UserDefaults.standard

    private enum Keys {
        static let accessToken = "patreon.accessToken"
        static let refreshToken = "patreon.refreshToken"
        static let subscriberName = "patreon.subscriberName"
        static let subscriberTier = "patreon.subscriberTier"
        static let unlockDate = "patreon.unlockDate"
    }

    private init() {
        // Restore a previously verified session within the grace window so
        // users aren't locked out just because they're offline.
        if let unlock = defaults.object(forKey: Keys.unlockDate) as? Date,
           Date().timeIntervalSince(unlock) < Double(PatreonConfig.sessionDays) * 86_400 {
            isUnlocked = true
        } else {
            isUnlocked = false
        }
        subscriberName = defaults.string(forKey: Keys.subscriberName)
        subscriberTier = defaults.string(forKey: Keys.subscriberTier)
    }

    // MARK: - Public API

    /// Completes the OAuth flow once the web auth session has returned a code.
    func completeAuthorization(withCode code: String) async throws {
        guard PatreonConfig.isConfigured else { throw PatreonAuthError.notConfigured }
        isVerifying = true
        defer { isVerifying = false }
        let token = try await exchangeCode(code)
        try await verifyAndUnlock(token)
    }

    /// Re-checks membership using the stored token. Locks the app if the
    /// member is no longer entitled to EAF Ultra; tolerates transient network
    /// failures so users aren't locked out while offline.
    func revalidateIfPossible() async {
        guard isUnlocked else { return }
        guard let token = defaults.string(forKey: Keys.accessToken), !token.isEmpty else { return }

        do {
            let info = try await fetchMembership(accessToken: token)
            if !isEntitled(info) {
                lockOut()
            }
        } catch PatreonAuthError.unauthorized {
            // Access token expired — try one refresh, then re-check.
            do {
                let fresh = try await refreshAccessToken()
                let info = try await fetchMembership(accessToken: fresh)
                if !isEntitled(info) {
                    lockOut()
                }
            } catch {
                // Keep the existing unlock on any refresh/network failure.
            }
        } catch {
            // Transient network / server error — keep the session.
        }
    }

    func signOut() {
        clearSession()
        isUnlocked = false
        subscriberName = nil
        subscriberTier = nil
    }

    // MARK: - OAuth token exchange

    private func exchangeCode(_ code: String) async throws -> Token {
        let params = [
            "code": code,
            "grant_type": "authorization_code",
            "client_id": PatreonConfig.clientID,
            "client_secret": PatreonConfig.clientSecret,
            "redirect_uri": PatreonConfig.redirectURI
        ]
        let (data, response) = try await postForm(params, to: PatreonConfig.tokenURL)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw PatreonAuthError.tokenExchangeFailed
        }
        return try JSONDecoder().decode(Token.self, from: data)
    }

    private func refreshAccessToken() async throws -> String {
        let refresh = defaults.string(forKey: Keys.refreshToken) ?? ""
        guard !refresh.isEmpty else { throw PatreonAuthError.unauthorized }
        let params = [
            "grant_type": "refresh_token",
            "refresh_token": refresh,
            "client_id": PatreonConfig.clientID,
            "client_secret": PatreonConfig.clientSecret
        ]
        let (data, response) = try await postForm(params, to: PatreonConfig.tokenURL)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw PatreonAuthError.unauthorized
        }
        let token = try JSONDecoder().decode(Token.self, from: data)
        defaults.set(token.accessToken, forKey: Keys.accessToken)
        if let newRefresh = token.refreshToken, !newRefresh.isEmpty {
            defaults.set(newRefresh, forKey: Keys.refreshToken)
        }
        return token.accessToken
    }

    // MARK: - Membership verification

    private func verifyAndUnlock(_ token: Token) async throws {
        let info = try await fetchMembership(accessToken: token.accessToken)
        guard isEntitled(info) else {
            throw PatreonAuthError.notSubscribed
        }
        defaults.set(token.accessToken, forKey: Keys.accessToken)
        if let refresh = token.refreshToken, !refresh.isEmpty {
            defaults.set(refresh, forKey: Keys.refreshToken)
        }
        defaults.set(info.fullName ?? "", forKey: Keys.subscriberName)
        defaults.set(info.tier ?? PatreonConfig.ultraTierTitle, forKey: Keys.subscriberTier)
        defaults.set(Date(), forKey: Keys.unlockDate)
        subscriberName = info.fullName
        subscriberTier = info.tier ?? PatreonConfig.ultraTierTitle
        isUnlocked = true
    }

    /// True when the signed-in account is entitled to EmGestPro Ultra: either
    /// it holds an active EAF Ultra membership, or it is the EmAppleFlagship
    /// campaign owner's account (creator auto-unlock from .env).
    private func isEntitled(_ info: MembershipInfo) -> Bool {
        if info.tier == PatreonConfig.ultraTierTitle { return true }
        let owner = PatreonConfig.ownerEmail.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !owner.isEmpty, let email = info.email else { return false }
        return email.trimmingCharacters(in: .whitespacesAndNewlines)
                .lowercased() == owner.lowercased()
    }

    private func fetchMembership(accessToken: String) async throws -> MembershipInfo {
        guard var components = URLComponents(string: PatreonConfig.identityURL) else {
            throw PatreonAuthError.network("Invalid Patreon identity URL.")
        }
        components.queryItems = [
            URLQueryItem(name: "include", value: "memberships,memberships.currently_entitled_tiers"),
            URLQueryItem(name: "fields[user]", value: "full_name,email"),
            URLQueryItem(name: "fields[member]", value: "patron_status"),
            URLQueryItem(name: "fields[tier]", value: "title")
        ]
        guard let url = components.url else {
            throw PatreonAuthError.network("Invalid Patreon identity URL.")
        }

        var request = URLRequest(url: url)
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue(PatreonConfig.userAgent, forHTTPHeaderField: "User-Agent")

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw PatreonAuthError.network("No response from Patreon.")
        }
        if http.statusCode == 401 {
            throw PatreonAuthError.unauthorized
        }
        guard http.statusCode == 200 else {
            throw PatreonAuthError.network("Patreon returned HTTP \(http.statusCode).")
        }

        let envelope = try JSONDecoder().decode(IdentityEnvelope.self, from: data)
        return evaluate(envelope)
    }

    /// Walks the JSON:API `included` array, looking for an *active* membership
    /// that is currently entitled to the EAF Ultra tier.
    private func evaluate(_ envelope: IdentityEnvelope) -> MembershipInfo {
        let included = envelope.included ?? []
        var info = MembershipInfo(tier: nil,
                                  fullName: envelope.data.attributes.full_name,
                                  email: envelope.data.attributes.email)

        var tierTitles: [String: String] = [:]
        for resource in included where resource.type == "tier" {
            if let title = resource.attributes?.title {
                tierTitles[resource.id] = title
            }
        }

        for member in included where member.type == "member" {
            guard member.attributes?.patron_status == "active_patron" else { continue }
            let tierIDs = member.relationships?.currently_entitled_tiers?.data?.compactMap(\.id) ?? []
            for id in tierIDs {
                if let title = tierTitles[id], title == PatreonConfig.ultraTierTitle {
                    info.tier = title
                    return info
                }
            }
        }
        return info
    }

    // MARK: - Helpers

    private func postForm(_ params: [String: String], to urlString: String) async throws -> (Data, URLResponse) {
        guard let url = URL(string: urlString) else {
            throw PatreonAuthError.network("Invalid Patreon URL.")
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.setValue(PatreonConfig.userAgent, forHTTPHeaderField: "User-Agent")
        request.httpBody = formBody(params).data(using: .utf8)
        return try await URLSession.shared.data(for: request)
    }

    private func formBody(_ params: [String: String]) -> String {
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-._~"))
        return params.map { key, value in
            let k = key.addingPercentEncoding(withAllowedCharacters: allowed) ?? key
            let v = value.addingPercentEncoding(withAllowedCharacters: allowed) ?? value
            return "\(k)=\(v)"
        }.joined(separator: "&")
    }

    private func lockOut() {
        clearSession()
        isUnlocked = false
        subscriberName = nil
        subscriberTier = nil
    }

    private func clearSession() {
        defaults.removeObject(forKey: Keys.accessToken)
        defaults.removeObject(forKey: Keys.refreshToken)
        defaults.removeObject(forKey: Keys.subscriberName)
        defaults.removeObject(forKey: Keys.subscriberTier)
        defaults.removeObject(forKey: Keys.unlockDate)
    }
}

// MARK: - Decoding models

private struct Token: Decodable {
    let accessToken: String
    let refreshToken: String?
    let expiresIn: Int?

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case refreshToken = "refresh_token"
        case expiresIn = "expires_in"
    }
}

private struct MembershipInfo {
    var tier: String?
    let fullName: String?
    let email: String?
}

private struct IdentityEnvelope: Decodable {
    let data: UserResource
    let included: [IncludedResource]?
}

private struct UserResource: Decodable {
    let attributes: UserAttributes
}

private struct UserAttributes: Decodable {
    let full_name: String?
    let email: String?
}

private struct IncludedResource: Decodable {
    let type: String
    let id: String
    let attributes: ResourceAttributes?
    let relationships: ResourceRelationships?
}

private struct ResourceAttributes: Decodable {
    let patron_status: String?
    let title: String?
}

private struct ResourceRelationships: Decodable {
    let campaign: SingleRelationship?
    let currently_entitled_tiers: ManyRelationship?
}

private struct SingleRelationship: Decodable {
    let data: RelationshipData?
}

private struct ManyRelationship: Decodable {
    let data: [RelationshipData]?
}

private struct RelationshipData: Decodable {
    let id: String?
    let type: String?
}
