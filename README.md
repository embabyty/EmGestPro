# EmGestPro

### On-Device MobileGestalt Editor for iOS

**EmGestPro** is an on-device MobileGestalt editor that lets you modify supported system values directly from your iPhone — no PC required.

> ⚠️ **Experimental:** Many features in EmGestPro are still untested across all devices and iOS versions. Things may not work as expected. Please report bugs, issues, and compatibility results in our [Discord](https://discord.gg/Wt8dj8E8ZN).

## Features

* 📱 Runs entirely on iPhone — no PC required
* 🛠️ MobileGestalt editing, sorted into Device, Display, System, Liquid Glass, iPad and Intelligence
* 📲 Device spoofing
* 🧠 **Siri AI Setup** — Apple Intelligence and Siri AI on supported iOS 27 builds, fully reversible
* 🖼️ PosterBoard support, with an in-app **Nugget-Wallpapers** gallery
* 🛡️ **Portable backups** — export your recovery point to Files/AirDrop and import it back
* 🍬 Eight alternate app icons
* 🎨 Accent colour picker

## Requirements

**iOS 26.0 or newer.** Tweaks and Siri AI Setup additionally require **iOS 27** — see the table below.

## Compatibility

| iOS Version | MobileGestalt Editing | Customization |
| ----------- | --------------------- | ----------- |
| iOS 18.x and earlier | ❌ Unsupported | ❌ Unsupported |
| iOS 26.0 – 26.6 | ❌ Unsupported | ✅ Supported |
| iOS 27.0 Beta 1 – Beta 4 | ✅ Supported | ✅ Supported |
| Later versions | ❌ Patched | ❌ Unsupported |

> **Note:** On iOS 26, the exploit does not provide the access required for MobileGestalt editing, so tweaks are unavailable. PosterBoard may still work, but compatibility has not been fully verified.

> **Siri AI Setup is beta.** It can cause instability, boot loops, or require a device restore, and the **Siri AI** mode in particular is the least reliable feature in EmGestPro — it may have no effect at all. Every key it touches is saved first, so its changes can be reverted. Back up before using it.

## EmGestPro Ultra (Patreon)

Access to EmGestPro is gated behind the **EmGestPro Ultra** subscription. The app
starts on a paywall and can only be unlocked by signing in with Patreon and
having an **active EAF Ultra membership** on the
[EmAppleFlagship campaign](https://www.patreon.com/cw/EmAppleFlagship).

### How it works

1. On launch, a full-screen paywall blocks the app.
2. Tapping **Sign in with Patreon** opens Patreon's OAuth flow.
3. The app exchanges the code for a token and checks the user's memberships.
4. Only an **active patron entitled to the `EAF Ultra` tier** is let in.
5. Non-members are directed to the Patreon page to subscribe.
6. Sessions stay unlocked for 7 days, then re-verify in the background.

### Setting up your Patreon credentials (creator)

The paywall ships with placeholder credentials in
[`EmGestPro/App/PatreonConfig.swift`](EmGestPro/App/PatreonConfig.swift). To make
the login work:

1. Create a **Patreon v2 client** at
   [https://www.patreon.com/portal/registration/register-clients](https://www.patreon.com/portal/registration/register-clients)
   while signed in with your creator account.
2. Add `https://embabyty.github.io/EmGestPro/patreon-callback.html` as a
   redirect URI. Patreon only accepts http(s) URIs, so this is a small
   GitHub Pages page ([`docs/patreon-callback.html`](docs/patreon-callback.html))
   that forwards the OAuth code to the app's `emgestpro://` scheme. It needs
   **GitHub Pages** enabled on the repo: **Settings → Pages → Deploy from a
   branch → `master` → `/docs`**.
3. Enable the v2 scopes: `identity`, `identity[email]` and `identity.memberships`.
4. Paste your **Client ID** and **Client Secret** into `PatreonConfig.swift`.
5. Set `ultraTierTitle` to the exact name of your EAF Ultra tier (default `EAF Ultra`).

> ⚠️ **Never commit your real Client Secret.** `PatreonConfig.swift` is tracked
> with placeholders so the project still builds; fill in your own values locally
> before distributing a build.

### Creator auto-unlock (owner bypass)

As the **EmAppleFlagship campaign owner** you can make the app unlock
automatically for your own Patreon account, without needing an active pledge
on the EAF Ultra tier:

1. Create a `.env` file in the repo root (gitignored) with your creator email:
   ```bash
   PATREON_OWNER_EMAIL=you@example.com
   ```
2. The **"Generate Patreon Secrets"** pre-build phase turns that into the
   gitignored [`EmGestPro/App/PatreonSecrets.swift`](EmGestPro/App/PatreonSecrets.swift)
   every time you build. You can also run it manually:
   ```bash
   scripts/generate_secrets.sh
   ```
3. Sign in with Patreon using that account — the app unlocks immediately, no
   membership check, and stays unlocked on revalidation.

Details:

- The email is compiled into the app at build time, so it only affects builds
  made on a machine (or CI run) that had the `.env` present. If the file is
  missing or the key is empty, the bypass is disabled.
- Builds through GitHub Actions don't see your local `.env`. To unlock
  CI-built IPAs too, set a **`PATREON_OWNER_EMAIL` repository secret** — the
  workflow injects it automatically.
- The check requires the `identity[email]` scope, which is already requested
  by `PatreonConfig.scopes`.

### Regenerating the project

New source files are picked up by XcodeGen, so regenerate the project after
pulling changes:

```bash
xcodegen generate
```

## Building the IPA

A GitHub Actions workflow ([`.github/workflows/build-ipa.yml`](.github/workflows/build-ipa.yml))
builds EmGestPro into a downloadable `.ipa` so you can grab it straight from the
repo.

- **Triggers:** it runs on push to `emgestpro`/`main`, on tags (`v*`), and
  manually from the **Actions** tab.
- **Download:** open **Actions → "Build IPA" → the latest run → Artifacts** to
  download `EmGestPro-ipa`. When you push a tag like `v1.3.0`, the `.ipa` and a
  SHA-256 checksum are also attached to the corresponding **Release**.
- **Unsigned:** the IPA is built with `CODE_SIGNING_ALLOWED=NO`, so it's unsigned
  and ready for TrollStore / sideloading. To build a *signed* IPA instead, add
  your certificate and provisioning profile as repo secrets and drop that flag
  in the workflow.
- **Requires Xcode 26:** the app uses iOS 26 SwiftUI APIs, so the runner must
  provide the iOS 26 SDK. The workflow auto-selects the newest Xcode installed
  on the runner.

## Discord

Need help, want to report a bug, or want to share your results?

**Join the [EmGestPro Discord](https://discord.gg/Wt8dj8E8ZN).**

## Privacy Policy

See [PRIVACY.md](PRIVACY.md) for details on how EmGestPro handles your data.

## Terms of Service

See [TERMS.md](TERMS.md) for the terms governing your use of EmGestPro.

## Credits

EmGestPro is built on the research and proof of concept from the following projects:

- **0xjohnnydev** — MobileHouseArrest-PoC
  https://github.com/0xjohnnydev/MobileHouseArrest-PoC

- **forcequitOS** — bad_query research and implementation
  https://github.com/forcequitOS/bad_query

- **leminlimez** — Pocket Poster
  https://github.com/leminlimez

- **rooootdev** — NeoSpring
  https://github.com/rooootdev

Huge thanks to everyone above for making this project possible, and to the Discord team keeping the place running.

## Licence

EmGestPro is licensed under the **GNU General Public License v3.0**. See [LICENSE](LICENSE).

## Disclaimer

EmGestPro is provided for **research and educational purposes**. Modifying system configuration can cause unexpected behavior. Use it at your own risk. See [DISCLAIMER.md](DISCLAIMER.md) for the full text.
