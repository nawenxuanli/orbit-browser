# Orbit

Orbit is an experimental desktop browser MVP with an original visual identity. It uses the Chromium engine bundled with Electron and is not affiliated with Brave, Vivaldi, or their publishers.

## Architecture

- **Main process:** owns browser windows, tab WebContentsViews, navigation, local JSON persistence, and website permission prompts.
- **Browser chrome:** a local HTML/CSS/JS interface with a narrowly scoped preload bridge. It receives only named UI events and sends validated command names over IPC.
- **Websites:** each tab has its own WebContentsView with Chromium's normal site isolation, context isolation, renderer sandbox, Node integration disabled, and web security enabled. Popups become tabs. Searches and bare hostnames use HTTPS; explicitly entered HTTP addresses are allowed. Text searches use DuckDuckGo.
- **Data:** bookmarks, recent visit history, notes, downloads, web panels, saved permission choices, and preferences are stored separately for each profile in Orbit's Electron user-data folder. Private windows use non-persistent Electron sessions and do not write those items to disk. No telemetry is sent.
- **Content blocking:** the optional blocker uses the open-source [Ghostery Adblocker](https://github.com/ghostery/adblocker) with its bundled ads and tracking filter rules. The rules are downloaded from the provider on first activation and cached locally; Orbit sends no browsing history or page data to fetch them. The blocker is disabled by default.

## Run locally

Install Node.js 22.13 or later, then run:

```sh
npm install
npm start
```

To create a ZIP for your current operating system:

```sh
npm run make
```

Electron Forge creates the current platform's ZIP under `out/make`. The same command can run on Windows, Linux, or macOS. The GitHub release workflow builds native packages for macOS Apple Silicon, macOS Intel, Windows x64, and Linux x64.

## Download for macOS

Download a package from the [GitHub Releases page](https://github.com/nawenxuanli/orbit-browser/releases):

- Apple Silicon (M-series): `Orbit-darwin-arm64-0.2.0.zip`.
- Intel: `Orbit-darwin-x64-0.2.0.zip`.
- Windows and Linux: choose the ZIP matching your system.

macOS release signing and notarization are enabled when the repository owner configures the Apple secrets listed below. Without those secrets, macOS builds are unsigned and macOS may warn or prevent opening them. Windows and Linux packages are preview ZIPs; Linux distributions may require system libraries. All builds remain experimental.

### Enable macOS signing and notarization

The repository owner must add these GitHub Actions secrets under **Settings → Secrets and variables → Actions**:

- `APPLE_SIGNING_IDENTITY`: the exact Developer ID Application certificate identity.
- `APPLE_CERTIFICATE_BASE64`: the base64-encoded `.p12` certificate export.
- `APPLE_CERTIFICATE_PASSWORD`: the password used to export that certificate.
- `APPLE_API_KEY_BASE64`: base64-encoded App Store Connect `.p8` API key.
- `APPLE_API_KEY_ID` and `APPLE_API_ISSUER`: the matching App Store Connect key identifiers.

Then publish a new `v*` tag. The release workflow imports the certificate, signs the app, requests notarization, and attaches native builds to a prerelease. These settings cannot sign the already-published 0.1.0 files retroactively. Signing is only confirmed when a release job succeeds and the resulting app passes Apple's Gatekeeper assessment on a clean Mac.

## Checks and security

Run `npm test` for local automated checks. GitHub Actions runs tests and a dependency audit on pushes and pull requests, plus scheduled CodeQL analysis. Run `npm start` to inspect browser features. Automated checks are not a security certification or an independent security audit.

## Current scope

Implemented: navigation and search, tabs with pinning and named groups, bookmarks, history with clear controls, downloads, local notes, four appearance themes, a hideable and reorderable toolbar, configurable shortcuts, per-request website permission prompts with optional remembered choices and a dashboard to review or clear them, separate profiles, private windows, and saved web panels that open in a side view. A web panel is an ordinary sandboxed Chromium view sharing the current profile's storage. Native build workflows are configured for macOS arm64 and x64, Windows x64, and Linux x64.

The optional blocker refreshes its Ghostery filter cache after seven days when the blocker is next activated. If refresh fails, it keeps the previous cached rules. It can still miss ads or trackers and does not include cosmetic page cleanup. Web panel sites depend on the network connection and site behavior. Orbit does not claim Brave/Vivaldi feature parity or privacy-audit certification. Browser extensions, cross-device sync, and a password manager are not implemented.

## Security notes

Electron and Chromium provide important isolation primitives, but Orbit has not had an independent security audit. Website permission requests are shown before access; the user can allow or deny once, or remember the choice for that site and permission in a regular profile. Private windows do not save those choices. Unhandled schemes are blocked. Automated checks do not prove security. See `SECURITY.md` for vulnerability reporting, and `THIRD_PARTY_NOTICES.md` for blocker attribution and license.
