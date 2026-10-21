# Microsoft Store submission preparation

Status: preparation only. No package has been built or tested on Windows from this Mac. The Store workflow is manual and requires the app identity assigned in Partner Center. Nothing here submits Orbit or accepts Partner Center terms.

## Packaging assessment

Orbit is an Electron desktop app. Electron Forge's `@electron-forge/maker-msix` can create a Store-targeted `.msix` on Windows 10/11 with the Windows SDK. This project has an opt-in `make:store` target and a manual Windows workflow that runs the Node tests, builds an x64 MSIX, and attempts the Windows App Certification Kit (WACK). The package identity and publisher must come from Orbit's reserved Partner Center name; placeholders are deliberately not used. The maker is experimental, and a successful build or WACK run is not Microsoft approval.

The Mac cannot create or validate the Windows package. The exact output after a successful Windows run is under `out/make/**/*.msix`; GitHub Actions retains it and the WACK report as the `Orbit-MSIX-and-WACK` workflow artifact.

## Partner Center checklist

1. With a parent or guardian's help, create or use a Microsoft Store developer account and complete identity verification directly with Microsoft. Do not send identity materials to Orbit or Codex.
2. Reserve the app name **Orbit** in Partner Center. Copy the assigned Package/Identity Name and Publisher identity into repository Actions variables named `ORBIT_STORE_PACKAGE_ID` and `ORBIT_STORE_PUBLISHER`.
3. Run **Build and validate Orbit MSIX** from GitHub Actions. Review the produced MSIX and WACK report, then test installation, launch, navigation, permissions, private windows, downloads, and uninstall on supported Windows versions. Fix any WACK failures before proceeding.
4. Start a new app submission in Partner Center. Complete pricing/availability, app properties and category, age ratings questionnaire, packages, store listing, support and privacy links, and certification notes. Save as a draft for review.
5. Verify the package identity matches the reserved app name and every listing claim matches the submitted build. Submit for certification only after the account owner reviews and explicitly approves submission. Microsoft decides certification and publication.

Microsoft individual developer registration may require identity verification. If the publisher is a minor, have a parent/guardian lead or supervise account setup, identity verification, and binding publisher agreements; Microsoft must confirm who can legally own the account. The parent/guardian should complete any verification directly in Microsoft's official flow, not provide credentials or identity documents to the project.

## Listing draft (English, United States)

**Name:** Orbit

**Short description:** An experimental desktop browser with flexible tabs, bookmarks, profiles, and optional content blocking.

**Description:**

Orbit is an experimental desktop web browser built with Electron and Chromium. Organize browsing with tabs, pinned tabs, tab groups, bookmarks, separate profiles, and private windows. Orbit also includes local browsing history, download controls, notes, a side panel for bookmarks and saved web panels, appearance themes, configurable shortcuts, and a rearrangeable toolbar.

Orbit asks before granting supported website permissions and lets you review saved choices. Optional ad and tracker filtering is off by default. When enabled, Orbit downloads Ghostery filter rules; filtering may miss ads or trackers. Search text entered in the address bar is sent to DuckDuckGo. Websites you visit receive the requests needed to display their pages.

Bookmarks, history, notes, downloads list, settings, profiles, and saved permission choices are kept locally in Orbit's user-data folder. Private windows use non-persistent browser sessions and do not save these Orbit items. Orbit does not send usage telemetry. Orbit has not received an independent security audit. Browser extensions, cross-device sync, and a password manager are not included. See the privacy policy and support links for details.

**Suggested category:** Productivity (or Utilities & tools if that is the closest category offered in Partner Center). Confirm the available category choices in the actual submission form.

**Screenshots:** Capture genuine images from the final Windows build, without fabricated data or feature mockups. At least one is required in the Windows app listing; prepare four 1280×720 PNGs if Partner Center accepts that format for this listing:

1. Main browser window showing tabs, address bar, bookmarks bar, and a normal web page.
2. Privacy dashboard showing the actual blocker-off state and permission controls.
3. Side panel showing bookmarks, notes, and saved web panels.
4. Settings or history/downloads view showing themes and toolbar controls.

Re-check Partner Center's current image dimensions and quantity before upload.

**Age-rating questionnaire draft:** Answer from the live questionnaire and final app, not from this suggested text alone. Orbit is a general-purpose browser that can open arbitrary public websites, including adult, violent, or user-generated material. There is no built-in social network, chat, or Orbit-hosted user publishing feature. Because Orbit provides open web access, answer questions about unrestricted web access and third-party/user-generated content truthfully as **Yes** where applicable. Its rating cannot be safely assigned in advance; use Microsoft's questionnaire result and review it with a parent/guardian.

**Support:** `https://github.com/nawenxuanli/orbit-browser/issues` for general support. Security reports: use the repository's private vulnerability reporting link described in `SECURITY.md`. A dedicated support email has not been provided and should not be invented.

## Privacy policy draft

This draft should be reviewed by the publisher and hosted at a stable public HTTPS URL before entering it in Partner Center.

### Orbit Privacy Notice

Orbit is an experimental desktop browser. Orbit does not send usage telemetry and does not operate an account or synchronization service.

Orbit stores bookmarks, browsing history, notes, download-list details, profile names, settings, and remembered website-permission choices in files in the local Orbit user-data folder. Orbit's private windows use non-persistent browser sessions and do not save these Orbit items. Files downloaded by a user are saved to the selected download location. Anyone or any software with access to this computer account or its files may be able to access locally stored Orbit data.

Regular profiles also use persistent Chromium website storage, which can include cookies and site data created by websites. This site storage is kept separately for each Orbit profile. Private windows use a non-persistent Electron session for website storage.

When a user searches from the address bar, Orbit sends the search text to DuckDuckGo to return results. When a user visits a website, that site and the network services involved in connecting to it receive the information needed to provide the requested page. Orbit displays prompts for supported website permissions; a user may allow or deny a request and, in a regular profile, may choose to remember that choice for the site.

The optional content blocker is off by default. When enabled, Orbit downloads Ghostery-based ad and tracking filter rules from the rules provider and caches them locally. Orbit does not send browsing history or page contents to fetch those rules. Filtering may be incomplete.

Orbit does not currently provide a cloud account, cross-device sync, a password manager, or a telemetry service. This notice describes the current Orbit build; changes to the app or its providers may require this notice to be updated. For support, use the GitHub issues link above. For security reports, use the private reporting route in `SECURITY.md`.

## Items to confirm before publishing

- Confirm the app identity/publisher in Partner Center and set the two GitHub Actions variables.
- Review the publisher name, category, age-rating answers, support route, and privacy notice with the account owner/guardian.
- Host the privacy notice on a stable HTTPS page and provide its public URL.
- Generate and visually review real screenshots from the Store candidate Windows build.
- Run and review the Windows workflow and WACK report on Windows; test install and runtime behavior manually.
- Review current Store package, policy, listing, and legal requirements in Partner Center.
- The build workflow does not submit packages or accept legal terms. Submission requires the publisher's explicit action.
