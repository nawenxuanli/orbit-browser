# Orbit

Orbit is an experimental desktop browser MVP with an original visual identity. It uses the Chromium engine bundled with Electron and is not affiliated with Brave, Vivaldi, or their publishers.

## Architecture

- **Main process:** owns browser windows, tab WebContentsViews, navigation, local JSON persistence, and website permission prompts.
- **Browser chrome:** a local HTML/CSS/JS interface with a narrowly scoped preload bridge. It receives only named UI events and sends validated command names over IPC.
- **Websites:** each tab has its own WebContentsView with Chromium's normal site isolation, context isolation, renderer sandbox, Node integration disabled, and web security enabled. Popups become tabs. Searches and bare hostnames use HTTPS; explicitly entered HTTP addresses are allowed. Text searches use DuckDuckGo.
- **Data:** bookmarks, recent visit history, notes, downloads, web panels, saved permission choices, and preferences are stored separately for each profile in Orbit's Electron user-data folder. Private windows use non-persistent Electron sessions and do not write those items to disk. No telemetry is sent.
- **Content blocking:** the optional blocker uses the open-source [Ghostery Adblocker](https://github.com/ghostery/adblocker) with its bundled ads and tracking filter rules. The rules are downloaded from the provider on first activation and cached locally; Orbit sends no browsing history or page data to fetch them. The blocker is disabled by default.

## Run on macOS

Install Node.js 20 or later, then run:

```sh
npm install
npm start
```

To create a macOS ZIP distribution artifact:

```sh
npm run make
```

Electron Forge creates a ZIP artifact under `out/make`. Signing and notarization require an Apple developer identity and are not configured here. The app is not yet signed or notarized for Gatekeeper distribution.

## Download for macOS

Download the ZIP matching your Mac from the [GitHub Releases page](https://github.com/nawenxuanli/orbit-browser/releases):

- Apple Silicon (M-series): `Orbit-darwin-arm64-0.1.0.zip`.
- Intel: `Orbit-darwin-x64-0.1.0.zip`.

These builds are unsigned and not notarized. macOS may warn or prevent opening them. They are preview builds and are not ready for general public distribution. Windows and Linux builds are not provided.

## Tests

Run `npm test` for the repository's automated checks. Run `npm start` to inspect navigation, tabs, bookmarks, history, settings, downloads, notes, profiles, and permission prompts. `npm run make` creates the macOS ZIP package.

## Current scope

Implemented: navigation and search, tabs with pinning and named groups, bookmarks, history with clear controls, downloads, local notes, four appearance themes, a hideable and reorderable toolbar, configurable shortcuts, per-request website permission prompts with optional remembered choices and a dashboard to review or clear them, separate profiles, private windows, and saved web panels that open in a side view. A web panel is an ordinary sandboxed Chromium view sharing the current profile's storage. Package and automated checks are provided for macOS arm64.

The blocker relies on Ghostery's ad and tracking lists; it does not promise to block every ad or tracker, and it does not include cosmetic page cleanup. Web panel sites still depend on the network connection and site behavior. Orbit does not claim Brave/Vivaldi feature parity or privacy-audit certification. Browser extensions, cross-device sync, and a password manager are outside this MVP.

## Security notes

Electron and Chromium provide important isolation primitives, but Orbit has not had an independent security audit. Website permission requests are shown before access; the user can allow or deny once, or remember the choice for that site and permission in a regular profile. Private windows do not save those choices. Unhandled schemes are blocked. Keep Electron dependencies current and review Electron's security guidance before release. See `THIRD_PARTY_NOTICES.md` for blocker attribution and license.
