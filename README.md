# Orbit

Orbit is an experimental desktop browser MVP with an original visual identity. It uses the Chromium engine bundled with Electron and is not affiliated with Brave, Vivaldi, or their publishers.

**Prebuilt downloads:** Windows x64 and Linux x64 only. macOS downloads have been withdrawn because the previous Mac packages were unsigned, not notarized, and macOS blocked them. Do not use older Mac downloads. Orbit will offer Mac downloads again only after signed and notarized builds are available.

## Architecture

- **Main process:** owns browser windows, tab WebContentsViews, navigation, local JSON persistence, and website permission prompts.
- **Browser chrome:** a local HTML/CSS/JS interface with a narrowly scoped preload bridge. It receives named UI events and sends validated command names over IPC.
- **Websites:** each tab has its own WebContentsView with Chromium site isolation, context isolation, renderer sandbox, Node integration disabled, and web security enabled. Popups become tabs. Searches and bare hostnames use HTTPS; explicitly entered HTTP addresses are allowed. Text searches use DuckDuckGo.
- **Data:** bookmarks, recent visit history, notes, downloads, web panels, saved permission choices, and preferences are stored per profile in Orbit's Electron user-data folder. Private windows use non-persistent Electron sessions. No telemetry is sent.
- **Content blocking:** the optional blocker uses the open-source [Ghostery Adblocker](https://github.com/ghostery/adblocker). It downloads third-party filter rules when enabled, caches them locally, and sends no browsing history or page data to fetch them. The blocker is disabled by default.

## Run locally

Install Node.js 22.13 or later, then run npm install followed by npm start. To create a ZIP for your current operating system, run npm run make. Electron Forge places it under out/make. Local builds depend on Electron Forge and the current OS. The GitHub release workflow publishes Windows x64 and Linux x64 packages only.

## Downloads

Download the Windows x64 or Linux x64 ZIP from the [GitHub Releases page](https://github.com/nawenxuanli/orbit-browser/releases). Linux distributions may require system libraries. All builds are experimental previews.

### macOS downloads withdrawn

The previous Mac ZIPs were unsigned and not notarized, and macOS rejected them as damaged. They have been removed. Orbit does not currently provide a supported macOS download.

## Checks and security

Run npm test for local automated checks. GitHub Actions runs tests and a dependency audit on pushes and pull requests, plus scheduled CodeQL analysis. Automated checks are not a security certification or independent security audit.

## Current scope

Implemented features include navigation and search, tabs with pinning and named groups, bookmarks, history with clear controls, downloads, local notes, four appearance themes, a hideable and reorderable toolbar, configurable shortcuts, website permission prompts and a privacy dashboard, separate profiles, private windows, and saved web panels in a side view. Browser extensions, cross-device sync, and a password manager are not implemented. Orbit does not claim Brave or Vivaldi feature parity or privacy-audit certification.

The optional blocker refreshes its Ghostery filter cache after seven days when next activated. If refresh fails, it keeps the previous cached rules. It can miss ads or trackers and does not include cosmetic page cleanup. Web panels depend on network access and site behavior.

## Security notes

Electron and Chromium provide important isolation primitives, but Orbit has not had an independent security audit. Website permission requests are shown before access; users can allow or deny once, or remember the choice for that site and permission in a regular profile. Private windows do not save those choices. Unhandled schemes are blocked. See SECURITY.md for vulnerability reporting and THIRD_PARTY_NOTICES.md for blocker attribution and license.
