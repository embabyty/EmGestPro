import Foundation

/// Direct launchd daemon management.
///
/// Edits `/private/var/db/com.apple.xpc.launchd/disabled.plist` through the
/// bad_query sandbox extension — the same mechanism Nugget uses to disable
/// OTAd. Existing entries are merged so unrelated disabled services are
/// preserved, and the file is written in place (keeps uid/gid) with a
/// read-back verification like the rest of the app.
enum LaunchDaemonsError: LocalizedError {
    case badPlist
    case writeFailed
    case writeVerificationFailed

    var errorDescription: String? {
        switch self {
        case .badPlist:
            return "The launchd disabled.plist could not be parsed."
        case .writeFailed:
            return "The write to disabled.plist failed."
        case .writeVerificationFailed:
            return "The write to disabled.plist did not verify."
        }
    }
}

enum LaunchDaemonsManager {
    /// launchd's disabled-services registry (dict of label -> bool).
    static let disabledPlistPath = "/private/var/db/com.apple.xpc.launchd/disabled.plist"

    /// LaunchDaemons labels for the OTA update pipeline (Nugget's OTAd set).
    static let otaDaemons = [
        "com.apple.mobile.softwareupdated",
        "com.apple.OTATaskingAgent",
        "com.apple.softwareupdateservicesd",
        "com.apple.mobile.NRDUpdated"
    ]

    /// Adds (`blocked: true`) or removes (`blocked: false`) the OTA daemons
    /// from launchd's disabled.plist. Requires an active bad_query sandbox
    /// extension for the path; callers should surface failures as warnings
    /// rather than hard errors, since the write depends on the exploit route.
    static func setOTABlocked(_ blocked: Bool) throws {
        let url = URL(fileURLWithPath: disabledPlistPath)
        let handle = try BadQuery.consume(path: disabledPlistPath, create: true)
        defer { handle.release() }

        var plist: [String: Any] = [:]
        if let data = try? Data(contentsOf: url), !data.isEmpty {
            guard let parsed = try? PropertyListSerialization.propertyList(
                from: data, format: nil) as? [String: Any] else {
                throw LaunchDaemonsError.badPlist
            }
            plist = parsed
        }

        for service in otaDaemons {
            if blocked {
                plist[service] = true
            } else {
                plist.removeValue(forKey: service)
            }
        }

        let newData = try PropertyListSerialization.data(
            fromPropertyList: plist, format: .binary, options: 0)

        do {
            try newData.write(to: url, options: []) // in place: keeps uid/gid
        } catch {
            throw LaunchDaemonsError.writeFailed
        }

        guard let readback = try? Data(contentsOf: url), readback == newData else {
            throw LaunchDaemonsError.writeVerificationFailed
        }
    }
}