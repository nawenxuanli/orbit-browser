import SwiftUI
import WebKit
import AppKit

struct Link: Codable, Identifiable { var id = UUID(); var title: String; var url: String }
struct SavedTab: Codable { var url: String; var group: String }
final class Tab: NSObject, ObservableObject, Identifiable, WKNavigationDelegate, WKUIDelegate {
    let id = UUID()
    @Published var title = "New tab"
    @Published var url = ""
    @Published var loading = false
    @Published var error = ""
    @Published var group: String
    let web: WKWebView
    weak var owner: Browser?
    init(group: String = "Personal") {
        self.group = group
        let config = WKWebViewConfiguration()
        config.preferences.javaScriptCanOpenWindowsAutomatically = false
        web = WKWebView(frame: .zero, configuration: config)
        super.init()
        web.navigationDelegate = self; web.uiDelegate = self
        web.allowsBackForwardNavigationGestures = true
    }
    func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) { loading = true; error = ""; owner?.objectWillChange.send() }
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        loading = false; title = webView.title ?? "Untitled"; url = webView.url?.absoluteString ?? ""
        owner?.record(self)
    }
    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError err: Error) { loading = false; if (err as NSError).code != NSURLErrorCancelled { error = err.localizedDescription } }
    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError err: Error) { loading = false; error = err.localizedDescription }
    func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration, for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
        if let url = navigationAction.request.url { owner?.newTab(url.absoluteString) }; return nil
    }
    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        guard let target = navigationAction.request.url, let scheme = target.scheme else { decisionHandler(.cancel); return }
        decisionHandler(["https", "http", "about"].contains(scheme) ? .allow : .cancel)
    }
}
final class Browser: ObservableObject {
    @Published var tabs: [Tab] = []
    @Published var selected: UUID?
    @Published var bookmarks: [Link] = []
    @Published var history: [Link] = []
    @Published var groups: [String] = ["Personal", "Work"]
    @Published var sidebar = true
    @Published var panel: String?
    @Published var ads = true { didSet { defaults.set(ads, forKey: "ads"); applyRules() } }
    @Published var trackers = true { didSet { defaults.set(trackers, forKey: "trackers"); applyRules() } }
    @Published var engine = "DuckDuckGo" { didSet { defaults.set(engine, forKey: "engine") } }
    @Published var appearance = "System" { didSet { defaults.set(appearance, forKey: "appearance") } }
    @Published var accent = "Ocean" { didSet { defaults.set(accent, forKey: "accent") } }
    @Published var rulesReady = false
    @Published var blockerError = ""
    let defaults = UserDefaults.standard
    var rules: [String: WKContentRuleList] = [:]
    var current: Tab? { tabs.first { $0.id == selected } }
    var color: Color { accent == "Forest" ? .green : accent == "Lavender" ? .purple : .cyan }
    init() {
        bookmarks = decode("bookmarks") ?? []
        history = decode("history") ?? []
        groups = decode("groups") ?? ["Personal", "Work"]
        engine = defaults.string(forKey: "engine") ?? "DuckDuckGo"
        appearance = defaults.string(forKey: "appearance") ?? "System"
        accent = defaults.string(forKey: "accent") ?? "Ocean"
        ads = defaults.object(forKey: "ads") as? Bool ?? true
        trackers = defaults.object(forKey: "trackers") as? Bool ?? true
        compileRules()
    }
    func decode<T: Decodable>(_ key: String) -> T? { guard let data = defaults.data(forKey: key) else { return nil }; return try? JSONDecoder().decode(T.self, from: data) }
    func save<T: Encodable>(_ value: T, _ key: String) { if let data = try? JSONEncoder().encode(value) { defaults.set(data, forKey: key) } }
    func persist() { save(tabs.map { SavedTab(url: $0.url, group: $0.group) }, "tabs"); save(groups, "groups") }
    func newTab(_ address: String = "", group: String = "Personal") {
        let tab = Tab(group: group); tab.owner = self; tabs.append(tab); selected = tab.id
        configure(tab)
        if !address.isEmpty { navigate(address, tab: tab) }; persist()
    }
    func close(_ tab: Tab) { tab.web.stopLoading(); tabs.removeAll { $0.id == tab.id }; if selected == tab.id { selected = tabs.last?.id }; if tabs.isEmpty { newTab() }; persist() }
    func navigate(_ input: String, tab: Tab? = nil) {
        guard let tab = tab ?? current, rulesReady else { return }
        let text = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        var target: URL?
        if text.hasPrefix("https://") || text.hasPrefix("http://") { target = URL(string: text) }
        else if !text.contains(" ") && (text.contains(".") || text.hasPrefix("localhost")) { target = URL(string: "https://" + text) }
        else {
            let base = engine == "Google" ? "https://www.google.com/search" : engine == "Bing" ? "https://www.bing.com/search" : "https://duckduckgo.com/"
            var components = URLComponents(string: base)!; components.queryItems = [URLQueryItem(name: "q", value: text)]; target = components.url
        }
        if let target = target { tab.url = target.absoluteString; tab.web.load(URLRequest(url: target)); persist() }
    }
    func record(_ tab: Tab) { history.insert(Link(title: tab.title, url: tab.url), at: 0); history = Array(history.prefix(1000)); save(history, "history"); persist() }
    func bookmark() { guard let t = current, !t.url.isEmpty else { return }; if bookmarks.contains(where: { $0.url == t.url }) { bookmarks.removeAll { $0.url == t.url } } else { bookmarks.append(Link(title: t.title, url: t.url)) }; save(bookmarks, "bookmarks") }
    func clearHistory() { history = []; save(history, "history"); for tab in tabs { tab.web.stopLoading() }; tabs = []; newTab(); persist() }
    func clearWebsiteData() { WKWebsiteDataStore.default().removeData(ofTypes: WKWebsiteDataStore.allWebsiteDataTypes(), modifiedSince: .distantPast) {} }
    func compileRules() {
        let lists = ["ads": ["doubleclick.net", "googlesyndication.com", "googleadservices.com", "adnxs.com", "adsrvr.org", "amazon-adsystem.com", "taboola.com", "outbrain.com"], "trackers": ["google-analytics.com", "analytics.google.com", "hotjar.com", "clarity.ms", "segment.io", "segment.com", "mixpanel.com", "scorecardresearch.com", "connect.facebook.net"]]
        let pending = DispatchGroup()
        for (name, domains) in lists {
            pending.enter()
            let entries: [[String: Any]] = domains.map { domain in ["trigger": ["url-filter": "^https?://([^/]+\\.)?" + NSRegularExpression.escapedPattern(for: domain) + "[/:]"], "action": ["type": "block"]] }
            let data = try! JSONSerialization.data(withJSONObject: entries)
            WKContentRuleListStore.default().compileContentRuleList(forIdentifier: "orbit-" + name, encodedContentRuleList: String(data: data, encoding: .utf8)!) { list, err in
                if let list = list { self.rules[name] = list }; if let err = err { self.blockerError = err.localizedDescription }; pending.leave()
            }
        }
        pending.notify(queue: .main) {
            self.rulesReady = true
            let restored: [SavedTab] = self.decode("tabs") ?? []
            if restored.isEmpty { self.newTab() } else { for item in restored { self.newTab(item.url, group: item.group) } }
        }
    }
    func configure(_ tab: Tab) { let controller = tab.web.configuration.userContentController; controller.removeAllContentRuleLists(); if ads, let rule = rules["ads"] { controller.add(rule) }; if trackers, let rule = rules["trackers"] { controller.add(rule) } }
    func applyRules() { for tab in tabs { configure(tab); if !tab.url.isEmpty { tab.web.reload() } } }
    func media(_ action: String) {
        let script = "document.querySelectorAll('video,audio').forEach(m=>{\(action)});"
        current?.web.evaluateJavaScript(script, completionHandler: nil)
    }
}
struct WebContent: NSViewRepresentable { @ObservedObject var tab: Tab; func makeNSView(context: Context) -> WKWebView { tab.web }; func updateNSView(_ nsView: WKWebView, context: Context) {} }
struct TabRow: View {
    @ObservedObject var tab: Tab; @ObservedObject var browser: Browser
    var body: some View {
        HStack(spacing: 9) {
            Image(systemName: tab.url.isEmpty ? "sparkle" : "globe").foregroundStyle(browser.color)
            Text(tab.title).lineLimit(1).font(.system(size: 13))
            Spacer(minLength: 0)
            if tab.loading { ProgressView().controlSize(.mini) }
            Button { browser.close(tab) } label: { Image(systemName: "xmark").font(.system(size: 9)) }.buttonStyle(.plain).help("Close tab")
        }.padding(10).background(browser.selected == tab.id ? browser.color.opacity(0.15) : .clear, in: RoundedRectangle(cornerRadius: 9))
        .contentShape(Rectangle()).onTapGesture { browser.selected = tab.id }
        .contextMenu { Menu("Move to group") { ForEach(browser.groups, id: \.self) { group in Button(group) { tab.group = group; browser.persist(); browser.objectWillChange.send() } } }; Button("Close tab") { browser.close(tab) } }
    }
}
struct BrowserView: View {
    @StateObject var browser = Browser()
    @State var address = ""
    @State var groupName = ""
    @State var creatingGroup = false
    @State var clearData = false
    @FocusState var addressFocused: Bool
    var body: some View {
        HStack(spacing: 0) {
            if browser.sidebar { sidebar.frame(width: 236); Divider() }
            VStack(spacing: 0) {
                toolbar.padding(.horizontal, 18).padding(.vertical, 12)
                Divider()
                if let tab = browser.current { Page(tab: tab, browser: browser) } else { ProgressView("Preparing privacy protection…").frame(maxWidth: .infinity, maxHeight: .infinity) }
            }
        }
        .frame(minWidth: 860, minHeight: 580)
        .background(Color(nsColor: .windowBackgroundColor))
        .tint(browser.color)
        .preferredColorScheme(browser.appearance == "Dark" ? .dark : browser.appearance == "Light" ? .light : nil)
        .onChange(of: browser.selected) { _ in address = browser.current?.url ?? "" }
        .onChange(of: browser.current?.url) { value in if !addressFocused { address = value ?? "" } }
        .onReceive(NotificationCenter.default.publisher(for: .init("OrbitFocus"))) { _ in addressFocused = true }
        .sheet(item: Binding(get: { browser.panel.map { PanelID(id: $0) } }, set: { browser.panel = $0?.id })) { item in panel(item.id) }
        .alert("New tab group", isPresented: $creatingGroup) { TextField("Group name", text: $groupName); Button("Create") { let name = groupName.trimmingCharacters(in: .whitespaces); if !name.isEmpty && !browser.groups.contains(name) { browser.groups.append(name); browser.persist() }; groupName = "" }; Button("Cancel", role: .cancel) {} }
    }
    var sidebar: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack { Image(systemName: "water.waves").font(.title2).foregroundStyle(browser.color); Text("orbit").font(.system(size: 26, weight: .semibold, design: .rounded)); Spacer(); Text("BROWSER").font(.system(size: 8, weight: .bold)).tracking(2).foregroundStyle(.secondary) }.padding(.top, 16)
            Button { browser.newTab() } label: { Label("New tab", systemImage: "plus").frame(maxWidth: .infinity, alignment: .leading).padding(8) }.keyboardShortcut("t").buttonStyle(.bordered)
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    ForEach(browser.groups, id: \.self) { group in
                        VStack(alignment: .leading, spacing: 4) {
                            HStack { Text(group.uppercased()).font(.system(size: 10, weight: .semibold)).tracking(1.5).foregroundStyle(.secondary); Spacer(); Button { browser.newTab(group: group) } label: { Image(systemName: "plus").font(.caption) }.buttonStyle(.plain) }
                            ForEach(browser.tabs.filter { $0.group == group }) { tab in TabRow(tab: tab, browser: browser) }
                        }
                    }
                    Button { creatingGroup = true } label: { Label("Create group", systemImage: "folder.badge.plus").font(.caption) }.buttonStyle(.plain).foregroundStyle(.secondary)
                }
            }
            Divider()
            sidebarButton("Bookmarks", "bookmark", "Bookmarks")
            sidebarButton("History", "clock", "History")
            sidebarButton("Media controls", "play.rectangle", "Media")
            sidebarButton("Customize", "slider.horizontal.3", "Settings")
            HStack(spacing: 7) { Image(systemName: "shield.lefthalf.filled"); Text(!browser.blockerError.isEmpty ? "Protection failed to load" : browser.ads && browser.trackers ? "Privacy protection on" : "Custom privacy settings").font(.system(size: 11)) }.foregroundStyle(browser.color).padding(.vertical, 8)
        }.padding(16).background(Color(nsColor: .controlBackgroundColor).opacity(0.55))
    }
    func sidebarButton(_ title: String, _ icon: String, _ panel: String) -> some View { Button { browser.panel = panel } label: { Label(title, systemImage: icon).font(.system(size: 13)).frame(maxWidth: .infinity, alignment: .leading) }.buttonStyle(.plain) }
    var toolbar: some View {
        HStack(spacing: 14) {
            Button { browser.sidebar.toggle() } label: { Image(systemName: "sidebar.left") }.help("Toggle sidebar")
            Button { browser.current?.web.goBack() } label: { Image(systemName: "chevron.left") }.help("Back")
            Button { browser.current?.web.goForward() } label: { Image(systemName: "chevron.right") }.help("Forward")
            Button { if browser.current?.loading == true { browser.current?.web.stopLoading() } else { browser.current?.web.reload() } } label: { Image(systemName: browser.current?.loading == true ? "xmark" : "arrow.clockwise") }
            HStack { Image(systemName: "magnifyingglass").foregroundStyle(.secondary); TextField("Search or enter a website", text: $address).textFieldStyle(.plain).focused($addressFocused).onSubmit { browser.navigate(address); addressFocused = false }; if browser.current?.loading == true { ProgressView().controlSize(.small) } }.padding(10).background(.primary.opacity(0.045), in: RoundedRectangle(cornerRadius: 10))
            Button { browser.bookmark() } label: { Image(systemName: browser.bookmarks.contains(where: { $0.url == browser.current?.url }) ? "bookmark.fill" : "bookmark") }.help("Bookmark this tab")
            Button { browser.panel = "Privacy" } label: { Image(systemName: "shield.lefthalf.filled").foregroundStyle(browser.color) }.help("Privacy controls")
        }.buttonStyle(.plain)
    }
    func panel(_ name: String) -> some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack { Text(name).font(.title2.bold()); Spacer(); Button("Done") { browser.panel = nil }.keyboardShortcut(.cancelAction) }
            if name == "Settings" {
                Text("Make room for your kind of browsing.").foregroundStyle(.secondary)
                Picker("Search engine", selection: $browser.engine) { ForEach(["DuckDuckGo", "Google", "Bing"], id: \.self) { Text($0) } }
                Picker("Appearance", selection: $browser.appearance) { ForEach(["System", "Light", "Dark"], id: \.self) { Text($0) } }
                Picker("Accent", selection: $browser.accent) { ForEach(["Ocean", "Forest", "Lavender"], id: \.self) { Text($0) } }
            } else if name == "Privacy" {
                Toggle("Block known ad domains", isOn: $browser.ads)
                Toggle("Block known tracker domains", isOn: $browser.trackers)
                Text("Uses a small built-in domain list. Protection is limited and does not block every ad or tracker. Changes reload open pages.").font(.callout).foregroundStyle(.secondary)
                if !browser.blockerError.isEmpty { Text(browser.blockerError).foregroundStyle(.red) }
                Button("Clear cookies and website data…") { clearData = true }
                Text("This signs you out of websites.").font(.caption).foregroundStyle(.secondary)
            } else if name == "Media" {
                Text("Control audio and video in the selected tab.").foregroundStyle(.secondary)
                HStack { Button("Back 10s") { browser.media("m.currentTime=Math.max(0,m.currentTime-10)") }; Button("Play / pause") { browser.media("if(m.paused){m.play().catch(()=>{})}else{m.pause()}") }; Button("Forward 10s") { browser.media("if(Number.isFinite(m.duration)){m.currentTime=Math.min(m.duration,m.currentTime+10)}") }; Button("Mute / unmute") { browser.media("m.muted=!m.muted") } }
                Text("Works with standard players in the page. Embedded cross-origin players, DRM services, and other apps may not respond.").font(.caption).foregroundStyle(.secondary)
            } else {
                if name == "History" { Button("Clear browsing history…", role: .destructive) { clearData = true } }
                let links = name == "Bookmarks" ? browser.bookmarks : browser.history
                if links.isEmpty { Text(name == "Bookmarks" ? "Save a page with the bookmark button beside the address bar." : "Pages you visit will appear here.").foregroundStyle(.secondary) }
                ScrollView { LazyVStack(alignment: .leading, spacing: 14) { ForEach(links) { link in HStack { Button { browser.newTab(link.url); browser.panel = nil } label: { VStack(alignment: .leading) { Text(link.title).lineLimit(1); Text(link.url).font(.caption).foregroundStyle(.secondary).lineLimit(1) } }.buttonStyle(.plain); Spacer(); if name == "Bookmarks" { Button { browser.bookmarks.removeAll { $0.id == link.id }; browser.save(browser.bookmarks, "bookmarks") } label: { Image(systemName: "trash") }.buttonStyle(.plain) } } } } }.frame(minHeight: 200)
            }
        }.padding(28).frame(width: 530)
        .confirmationDialog(name == "History" ? "Clear history and reset open tabs?" : "Clear all cookies and website data?", isPresented: $clearData) { Button("Clear", role: .destructive) { if name == "History" { browser.clearHistory() } else { browser.clearWebsiteData() } }; Button("Cancel", role: .cancel) {} }
    }
}
struct PanelID: Identifiable { let id: String }
struct Page: View {
    @ObservedObject var tab: Tab
    @ObservedObject var browser: Browser
    @State var search = ""
    var body: some View {
        ZStack {
            if tab.url.isEmpty {
                VStack(alignment: .leading, spacing: 24) {
                    HStack(spacing: 8) { Image(systemName: "water.waves"); Text("A LITTLE SPACE TO EXPLORE").font(.system(size: 10, weight: .semibold)).tracking(3) }.foregroundStyle(browser.color)
                    Text("Less noise.\nMore possibility.").font(.system(size: 54, weight: .medium, design: .serif)).tracking(-2)
                    Text("Your corner of the internet. Make yourself at home.").font(.system(size: 15)).foregroundStyle(.secondary)
                    HStack { Image(systemName: "magnifyingglass").foregroundStyle(browser.color); TextField("Search with \(browser.engine)", text: $search).textFieldStyle(.plain).onSubmit { browser.navigate(search, tab: tab) }; Button { browser.navigate(search, tab: tab) } label: { Image(systemName: "arrow.right") }.buttonStyle(.plain) }.padding(18).background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 14)).overlay(RoundedRectangle(cornerRadius: 14).stroke(.primary.opacity(0.08)))
                    HStack(spacing: 14) { shortcut("Wikipedia", "book", "https://wikipedia.org"); shortcut("YouTube", "play.rectangle", "https://youtube.com"); shortcut("Spotify", "music.note", "https://open.spotify.com") }
                    HStack { Image(systemName: "shield.lefthalf.filled"); Text("Thoughtfully simple. Yours to explore.") }.font(.caption).foregroundStyle(.secondary).padding(.top, 36)
                    if !tab.error.isEmpty { Text(tab.error).font(.caption).foregroundStyle(.secondary) }
                }.frame(maxWidth: 590).padding(40).frame(maxWidth: .infinity, maxHeight: .infinity).background(browser.color.opacity(0.025))
            } else { WebContent(tab: tab).id(tab.id) }
            if !tab.error.isEmpty && !tab.url.isEmpty { VStack(spacing: 12) { Text("This page couldn’t load").font(.title2); Text(tab.error).foregroundStyle(.secondary); Button("Try again") { tab.web.reload() }; Button("Open a new tab") { browser.newTab() } }.padding(28).background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16)) }
        }
    }
    func shortcut(_ title: String, _ icon: String, _ url: String) -> some View { Button { browser.navigate(url, tab: tab) } label: { VStack(spacing: 10) { Image(systemName: icon).font(.title3).foregroundStyle(browser.color); Text(title).font(.caption) }.frame(maxWidth: .infinity).padding(.vertical, 18).background(.primary.opacity(0.035), in: RoundedRectangle(cornerRadius: 12)) }.buttonStyle(.plain) }
}
@main struct OrbitApp: App {
    var body: some Scene {
        WindowGroup { BrowserView() }.windowStyle(.hiddenTitleBar).defaultSize(width: 1200, height: 800)
        .commands { CommandGroup(replacing: .newItem) { Button("Focus address bar") { NotificationCenter.default.post(name: .init("OrbitFocus"), object: nil) }.keyboardShortcut("l") } }
    }
}
