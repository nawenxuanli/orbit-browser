# Orbit Browser for Windows 0.3

Native Windows companion to Orbit for Mac, built with WPF, .NET 8, and Microsoft Edge WebView2. Requires Windows 10 version 2004 or later, x64, and the Microsoft Edge WebView2 Runtime.

## Features

Search with DuckDuckGo, Google, or Bing; organize tabs into named groups; save bookmarks; review or clear history; toggle a limited domain blocker; control standard page audio/video; change appearance and accent; and save downloads using a file picker. Tabs, groups, bookmarks, history, and preferences persist locally.

This preview denies website permissions, including camera, microphone, location, and notifications. It does not include extensions, sync, a password manager, private windows, or default-browser registration. Protected streaming and embedded media players may not support the media controls. Blocking uses the same small 17-domain list as the Mac app and cannot block every ad or tracker. The start page retains its dark appearance when the window theme is light.

## Build

On Windows with the .NET 8 SDK and Windows 10/11 SDK installed:

```powershell
./Windows/Build.ps1 -SmokeTest
```

The build compiles the app, tests address handling and hostname boundaries, exercises WebView2 with real HTTPS navigation and ad-domain blocking, captures the running app, and packages an unsigned MSIX for submission to Microsoft Store. Output is in `Windows/out/`. The Store identity in `Package.appxmanifest` comes from the reserved Orbit Browser product in Partner Center.

The GitHub `Windows Store package` workflow performs this on a Windows runner and uploads the MSIX, runtime smoke-test report, and screenshot as artifacts. An unsigned MSIX is for Store submission, not direct installation on customer PCs. Microsoft re-signs certified packages. The script does not publish or submit anything automatically.

## Local data

Data is stored in `%LOCALAPPDATA%/OrbitBrowser`. Browsing history is limited to the latest 1,000 completed visits. Clearing history resets tabs; clearing website data signs you out. The smoke test uses a separate temporary profile. See [PRIVACY.md](PRIVACY.md).

## Store preparation

Store ID: `9MWDXBTQNK1L`. A reserved draft is not a published product. Certification, listing details, screenshots, privacy policy, age ratings, and any required account checks must be completed in Partner Center before availability can be claimed.
