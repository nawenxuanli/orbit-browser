# Orbit 0.3 — a fresh start for Mac

Orbit has been rebuilt from scratch as a native Mac browser using SwiftUI and Apple's WebKit. This replaces the earlier Electron implementation on the main branch. It began as the Cove prototype and is now the new Orbit.

The previous implementation is retained in Git history and its existing tags. The new version targets macOS only; earlier Windows and Linux builds do not describe this version.

## Open Orbit

Build locally using the instructions below, or download the development artifact from a successful [Native macOS build](https://github.com/nawenxuanli/orbit-browser/actions/workflows/checks.yml) run (GitHub sign-in may be required). Unzip the artifact, then unzip Orbit-macOS-development.zip and open Orbit.app. You can drag the app into Applications if you want to keep it there.

This update does not publish a new GitHub Release. Earlier releases remain withdrawn.

Requires macOS 13 Ventura or later. Includes Apple silicon and Intel binaries. The Apple silicon build was launched and checked on this Mac; the Intel build was compiled but has not been run on an Intel Mac.

This is a locally built development app with an ad hoc signature, not an Apple-notarized release. A downloaded copy may be blocked by macOS security checks. No developer account or signing credentials were used.

## Included

- Search or enter an address in the toolbar; DuckDuckGo is the default, with Google and Bing available in Customize.
- Collapsible sidebar with tabs and named groups. Use Create group; use the plus beside a group to open a tab there. Right-click a tab to move it between groups.
- Tabs and groups restore on launch. Search/address focus: Command-L. New tab: Command-T while the sidebar is visible.
- Bookmark the current page with the bookmark icon; open or remove saved bookmarks in Bookmarks.
- History lists the last 1,000 completed page visits. Clearing history also closes the current tabs and opens a fresh tab, removing their back/forward lists. Cookies are cleared separately in Privacy.
- Privacy controls for known ad domains and known tracker domains. Changes reload open pages. Website data clearing signs you out of sites.
- Media controls for play/pause, mute, and skipping ten seconds in the selected tab.
- System, light, and dark appearance, plus Ocean, Forest, and Lavender accents.

## Privacy and compatibility limits

The blocker is a small static list of 17 domains, not a comprehensive or automatically updated filtering system. It cannot block all advertising or tracking, including many first-party and video ads. Orbit does not claim anonymity. Websites and your chosen search provider receive normal browsing requests. History, bookmarks, settings, and saved tab addresses are stored locally in macOS preferences; WebKit manages cookies and website storage.

Media controls operate on standard audio and video elements in the selected page. Cross-origin embedded players, protected streaming services, and other Mac apps may not respond. Spotify and YouTube shortcuts open their websites; support for a particular streaming service has not been verified.

This first version has no extension marketplace, password manager, sync, download manager, automatic updates, or default-browser registration. External app URL schemes are not launched. Camera/microphone workflows and complex websites have not been comprehensively tested. Use an established browser for workflows that this build does not yet support.

## Validation

- The renamed Orbit app compiled for both arm64 and x86_64.
- The universal app launched on Apple silicon and loaded an HTTPS webpage.
- Bookmark saving, restored tabs, creating a group, customization choices, and privacy controls were checked in the app.
- All 17 blocking rules compiled. An engine-level check confirmed that a known ad domain was blocked and an ordinary HTTPS page still loaded with the rules enabled.
- Local code-signature verification passed before packaging.
- Media controls and clearing data are implemented but have not been tested against a broad set of websites.

## Build from source

Requires Xcode and its command-line tools on macOS. From the repository folder:

```sh
bash Source/build.sh
open Orbit.app
```

Source/Orbit.swift contains the application. Source/Info.plist and Source/MakeIcon.swift contain its bundle information and icon generator. With a current Xcode installation, run Source/build.sh in Terminal to rebuild the universal application locally.

WebKit content blocking reference: https://developer.apple.com/documentation/webkit/wkcontentruleliststore
