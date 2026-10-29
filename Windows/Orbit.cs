using System.IO;
using System.Text.Json;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Input;
using System.Windows.Media;
using Microsoft.Web.WebView2.Core;
using Microsoft.Web.WebView2.Wpf;
using Microsoft.Win32;
using System.Windows.Media.Imaging;

namespace Orbit;
public record SavedLink(string Title, string Url);
public record SavedTab(string Url, string Group);
public class State {
 public List<SavedLink> Bookmarks { get; set; } = new();
 public List<SavedLink> History { get; set; } = new();
 public List<SavedTab> Tabs { get; set; } = new();
 public List<string> Groups { get; set; } = new() { "Personal", "Work" };
 public string Engine { get; set; } = "DuckDuckGo";
 public bool Ads { get; set; } = true;
 public bool Trackers { get; set; } = true;
 public string Theme { get; set; } = "Dark";
 public string Accent { get; set; } = "Ocean";
}
public class BrowserTab {
 public string Title = "New tab";
 public string Url = "";
 public string Group = "Personal";
 public WebView2 Web = new();
 public bool Ready;
 public bool Closed;
 public override string ToString() => Title;
}
public static class Program {
 [STAThread] public static void Main(string[] args) {
  if (args.Contains("--self-test")) {
   var ok = Browser.Address("hello world", "DuckDuckGo").StartsWith("https://duckduckgo.com/?q=")
    && Browser.Address("example.com", "Bing") == "https://example.com"
    && Browser.Matches("sub.doubleclick.net", "doubleclick.net")
    && !Browser.Matches("notdoubleclick.net", "doubleclick.net")
    && Browser.Address("javascript:alert(1)", "DuckDuckGo").StartsWith("https://duckduckgo.com/");
   Environment.Exit(ok ? 0 : 1); return;
  }
  Browser.SmokeMode = args.Contains("--smoke-test");
  if(Browser.SmokeMode) Browser.SmokeOutput=args[Array.IndexOf(args,"--smoke-test")+1];
  var app = new Application(); app.Run(new Browser());
 }
}
public class Browser : Window {
 public static bool SmokeMode;
 public static string SmokeOutput = "";
 int blockedRequests;
 static string? smokeRoot;
 static string Root => SmokeMode ? (smokeRoot ??= Path.Combine(Path.GetTempPath(), "OrbitBrowser-Smoke-"+Guid.NewGuid().ToString("N"))) : Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData), "OrbitBrowser");
 static string StateFile => Path.Combine(Root, "state.json");
 static readonly string[] AdDomains = { "doubleclick.net", "googlesyndication.com", "googleadservices.com", "adnxs.com", "adsrvr.org", "amazon-adsystem.com", "taboola.com", "outbrain.com" };
 static readonly string[] TrackerDomains = { "google-analytics.com", "analytics.google.com", "hotjar.com", "clarity.ms", "segment.io", "segment.com", "mixpanel.com", "scorecardresearch.com", "connect.facebook.net" };
 readonly State state;
 readonly List<BrowserTab> tabs = new();
 BrowserTab? selected;
 CoreWebView2Environment? environment;
 readonly Grid layout = new();
 readonly StackPanel sidebar = new() { Margin = new Thickness(14) };
 readonly StackPanel tabRows = new();
 readonly Grid pages = new();
 readonly TextBox address = new() { MinWidth = 180, FontSize = 14, VerticalContentAlignment = VerticalAlignment.Center, Margin = new Thickness(7), Padding = new Thickness(12, 8, 12, 8) };
 readonly TextBlock status = new() { FontSize = 11, Margin = new Thickness(16, 4, 16, 6) };
 readonly List<Window> ownedPanels = new();
 bool ready;
 public Browser() {
  Directory.CreateDirectory(Root);
  try { state = JsonSerializer.Deserialize<State>(File.ReadAllText(StateFile)) ?? new State(); }
  catch { state = new State(); }
  if (state.Groups.Count == 0) state.Groups.Add("Personal");
  Title = "Orbit Browser"; Width = 1200; Height = 800; MinWidth = 900; MinHeight = 600;
  WindowStartupLocation = WindowStartupLocation.CenterScreen;
  layout.ColumnDefinitions.Add(new ColumnDefinition { Width = new GridLength(235) });
  layout.ColumnDefinitions.Add(new ColumnDefinition());
  Content = layout;
  var rail = new DockPanel(); Grid.SetColumn(rail,0); layout.Children.Add(rail);
  sidebar.Children.Add(new TextBlock { Text = "≋  orbit", FontSize = 28, FontWeight = FontWeights.SemiBold, Margin = new Thickness(8, 18, 8, 24) });
  sidebar.Children.Add(Button("＋ New tab", () => NewTab()));
  sidebar.Children.Add(new ScrollViewer { Content = tabRows, VerticalScrollBarVisibility = ScrollBarVisibility.Auto, MaxHeight = 350 });
  sidebar.Children.Add(Button("＋ Create group", CreateGroup));
  sidebar.Children.Add(Button("Bookmarks", () => Links(false)));
  sidebar.Children.Add(Button("History", () => Links(true)));
  sidebar.Children.Add(Button("Media controls", Media));
  sidebar.Children.Add(Button("Privacy", Privacy));
  sidebar.Children.Add(Button("Customize", Settings));
  rail.Children.Add(sidebar);
  var main = new DockPanel(); Grid.SetColumn(main,1); layout.Children.Add(main);
  var bar = new DockPanel { LastChildFill = true, Margin = new Thickness(6) };
  DockPanel.SetDock(bar,Dock.Top); main.Children.Add(bar);
  bar.Children.Add(Button("☰", () => { layout.ColumnDefinitions[0].Width = layout.ColumnDefinitions[0].Width.Value == 0 ? new GridLength(235) : new GridLength(0); }));
  bar.Children.Add(Button("‹", () => { if(selected?.Web.CanGoBack == true) selected.Web.GoBack(); }));
  bar.Children.Add(Button("›", () => { if(selected?.Web.CanGoForward == true) selected.Web.GoForward(); }));
  bar.Children.Add(Button("↻", () => selected?.Web.Reload()));
  var star = Button("☆", Bookmark); DockPanel.SetDock(star,Dock.Right); bar.Children.Add(star);
  address.KeyDown += (_,e) => { if(e.Key == Key.Enter) Navigate(address.Text); };
  bar.Children.Add(address);
  DockPanel.SetDock(status,Dock.Bottom); main.Children.Add(status); main.Children.Add(pages);
  ApplyTheme();
  PreviewKeyDown += (_,e) => { if (Keyboard.Modifiers == ModifierKeys.Control) {
   if(e.Key == Key.L) { address.Focus(); address.SelectAll(); e.Handled=true; }
   if(e.Key == Key.T) { NewTab(); e.Handled=true; }
   if(e.Key == Key.W && selected != null) { CloseTab(selected); e.Handled=true; }
  }};
  Closing += (_,_) => { Save(); foreach(var t in tabs) { t.Closed=true; t.Web.Dispose(); } };
  Loaded += async (_,_) => {
   try {
    environment = await CoreWebView2Environment.CreateAsync(null,Path.Combine(Root,"WebView2")); ready=true;
    if(SmokeMode) { await SmokeTest(); return; }
    var restore = state.Tabs.ToArray();
    if(restore.Length == 0) NewTab(); else foreach(var t in restore) NewTab(t.Url, t.Group);
   } catch(Exception ex) { if(SmokeMode) { Directory.CreateDirectory(SmokeOutput); File.WriteAllText(Path.Combine(SmokeOutput,"failure.txt"),ex.ToString()); Environment.Exit(1); } MessageBox.Show(this,"Orbit could not start its browser engine. Install or update Microsoft Edge WebView2 Runtime, then reopen Orbit.\n\n"+ex.Message,"Browser engine unavailable"); }
  };
 }
 static Button Button(string label, Action action) {
  var b = new Button { Content=label, Padding=new Thickness(10,8,10,8), Margin=new Thickness(3), HorizontalContentAlignment=HorizontalAlignment.Left };
  b.Click += (_,_) => action(); return b;
 }
 static TextBlock Text(string text, int size=14) => new() { Text=text, FontSize=size, TextWrapping=TextWrapping.Wrap, Margin=new Thickness(5,8,5,8) };
 Brush Accent => new SolidColorBrush(state.Accent == "Forest" ? Color.FromRgb(76,181,135) : state.Accent == "Lavender" ? Color.FromRgb(167,139,250) : Color.FromRgb(66,196,222));
 void ApplyTheme() {
  bool dark = state.Theme == "Dark";
  Background = new SolidColorBrush(dark ? Color.FromRgb(26,29,33) : Color.FromRgb(247,249,250));
  Foreground = dark ? Brushes.WhiteSmoke : Brushes.Black;
  address.Background = dark ? new SolidColorBrush(Color.FromRgb(39,43,49)) : Brushes.White;
  address.Foreground=Foreground; address.CaretBrush=Accent; status.Foreground=Accent;
  sidebar.Background = Background;
  foreach (var button in sidebar.Children.OfType<Button>()) { button.Background=Background; button.Foreground=Foreground; button.BorderBrush=Brushes.Transparent; }
  RefreshTabs();
 }
 void Save() {
  state.Tabs=tabs.Where(t=>!t.Closed).Select(t=>new SavedTab(t.Url,t.Group)).ToList();
  try { var temp=StateFile+".tmp"; File.WriteAllText(temp,JsonSerializer.Serialize(state)); File.Move(temp,StateFile,true); }
  catch(Exception ex) { status.Text="Could not save browsing settings: "+ex.Message; }
 }
 public static bool Matches(string host,string domain) => host.Equals(domain,StringComparison.OrdinalIgnoreCase) || host.EndsWith("."+domain,StringComparison.OrdinalIgnoreCase);
 public static string Address(string input,string engine) {
  var text=input.Trim();
  if(Uri.TryCreate(text,UriKind.Absolute,out var direct) && (direct.Scheme=="https" || direct.Scheme=="http")) return direct.AbsoluteUri;
  if(!text.Any(char.IsWhiteSpace) && !text.Contains(':') && text.Contains('.') && Uri.TryCreate("https://"+text,UriKind.Absolute,out _)) return "https://"+text;
  return (engine=="Google" ? "https://www.google.com/search?q=" : engine=="Bing" ? "https://www.bing.com/search?q=" : "https://duckduckgo.com/?q=")+Uri.EscapeDataString(text);
 }
 void Navigate(string input) { if(!string.IsNullOrWhiteSpace(input) && selected?.Ready==true) { selected.Web.Visibility=Visibility.Visible; selected.Web.CoreWebView2.Navigate(Address(input,state.Engine)); } }
 async void NewTab(string url="",string group="Personal") {
  if(!ready) return;
  if(!state.Groups.Contains(group)) state.Groups.Add(group);
  var t=new BrowserTab { Group=group }; tabs.Add(t); pages.Children.Add(t.Web); Select(t); RefreshTabs();
  try {
   await t.Web.EnsureCoreWebView2Async(environment);
   if(t.Closed) return;
   t.Ready=true; var core=t.Web.CoreWebView2;
   core.Settings.IsStatusBarEnabled=true;
   core.AddWebResourceRequestedFilter("*",CoreWebView2WebResourceContext.All);
   core.WebResourceRequested += (_,e) => {
    if(Uri.TryCreate(e.Request.Uri,UriKind.Absolute,out var uri) && ((state.Ads && AdDomains.Any(d=>Matches(uri.Host,d))) || (state.Trackers && TrackerDomains.Any(d=>Matches(uri.Host,d)))))
     { blockedRequests++; e.Response=environment!.CreateWebResourceResponse(new MemoryStream(Array.Empty<byte>()),403,"Blocked by Orbit","Content-Type: text/plain"); }
   };
   core.NavigationStarting += (_,e) => {
    if(!Uri.TryCreate(e.Uri,UriKind.Absolute,out var uri) || !(uri.Scheme=="https" || uri.Scheme=="http" || e.Uri=="about:blank")) { e.Cancel=true; return; }
    if(selected==t) status.Text="Loading…";
   };
   core.SourceChanged += (_,_) => { if(core.Source.StartsWith("http")) { t.Url=core.Source; if(selected==t && !address.IsKeyboardFocused) address.Text=t.Url; } };
   core.DocumentTitleChanged += (_,_) => { t.Title=string.IsNullOrWhiteSpace(core.DocumentTitle)?"Untitled":core.DocumentTitle; RefreshTabs(); };
   core.NavigationCompleted += (_,e) => {
    if(t.Closed) return;
    if(e.IsSuccess && t.Url.StartsWith("http")) { state.History.Insert(0,new SavedLink(t.Title,t.Url)); state.History=state.History.Take(1000).ToList(); }
    if(selected==t) status.Text=e.IsSuccess ? "Known-domain protection: ads "+(state.Ads?"on":"off")+", trackers "+(state.Trackers?"on":"off") : "Page could not load: "+e.WebErrorStatus;
    Save();
   };
   core.NewWindowRequested += (_,e) => { e.Handled=true; NewTab(e.Uri,t.Group); };
   core.PermissionRequested += (_,e) => { e.State=CoreWebView2PermissionState.Deny; e.Handled=true; };
   core.DownloadStarting += (_,e) => {
    var save=new SaveFileDialog { FileName=Path.GetFileName(e.ResultFilePath), Title="Save download" };
    if(save.ShowDialog(this)==true) { e.ResultFilePath=save.FileName; e.Handled=true; } else e.Cancel=true;
   };
   if(!string.IsNullOrEmpty(url)) { t.Url=Address(url,state.Engine); core.Navigate(t.Url); } else Home(t);
  } catch(Exception ex) { status.Text="Tab could not start: "+ex.Message; }
 }
 async Task SmokeTest() {
  Directory.CreateDirectory(SmokeOutput);
  Width=1440;Height=900;UpdateLayout();
  NewTab();
  var t=selected!;
  for(int i=0;i<200&&!t.Ready;i++) await Task.Delay(100);
  if(!t.Ready) throw new Exception("WebView2 initialization timed out");
  async Task Load(string url) {
   var done=new TaskCompletionSource<bool>();
   void Completed(object? sender,CoreWebView2NavigationCompletedEventArgs e) { done.TrySetResult(e.IsSuccess); }
   t.Web.CoreWebView2.NavigationCompleted+=Completed;
   try { t.Web.CoreWebView2.Navigate(url); var completed=await Task.WhenAny(done.Task,Task.Delay(30000)); if(completed!=done.Task)throw new Exception("Navigation timeout: "+url); }
   finally { t.Web.CoreWebView2.NavigationCompleted-=Completed; }
  }
  await Task.Delay(1000);
  await Load("https://example.com");
  if(!t.Web.CoreWebView2.DocumentTitle.Contains("Example Domain"))throw new Exception("HTTPS navigation failed");
  await Load("https://doubleclick.net/orbit-smoke-test");
  if(blockedRequests==0)throw new Exception("Ad-domain blocking failed");
  var screenshotReady=new TaskCompletionSource<bool>();
  void HomeLoaded(object? sender,CoreWebView2NavigationCompletedEventArgs e) { screenshotReady.TrySetResult(e.IsSuccess); }
  t.Web.CoreWebView2.NavigationCompleted+=HomeLoaded;Home(t);
  await Task.WhenAny(screenshotReady.Task,Task.Delay(10000));t.Web.CoreWebView2.NavigationCompleted-=HomeLoaded;
  await Task.Delay(500);
  using var preview=new MemoryStream();
  await t.Web.CoreWebView2.CapturePreviewAsync(CoreWebView2CapturePreviewImageFormat.Png,preview);
  preview.Position=0;var webImage=new BitmapImage();webImage.BeginInit();webImage.CacheOption=BitmapCacheOption.OnLoad;webImage.StreamSource=preview;webImage.EndInit();
  var chrome=new RenderTargetBitmap((int)ActualWidth,(int)ActualHeight,96,96,PixelFormats.Pbgra32);chrome.Render(this);
  var visual=new DrawingVisual();using(var dc=visual.RenderOpen()) { dc.DrawImage(chrome,new Rect(0,0,ActualWidth,ActualHeight));var point=t.Web.TranslatePoint(new Point(0,0),this);dc.DrawImage(webImage,new Rect(point.X,point.Y,t.Web.ActualWidth,t.Web.ActualHeight)); }
  var result=new RenderTargetBitmap((int)ActualWidth,(int)ActualHeight,96,96,PixelFormats.Pbgra32);result.Render(visual);
  var png=new PngBitmapEncoder();png.Frames.Add(BitmapFrame.Create(result));using(var file=File.Create(Path.Combine(SmokeOutput,"Orbit-Windows.png")))png.Save(file);
  File.WriteAllText(Path.Combine(SmokeOutput,"smoke-test.txt"),"PASS: WebView2 initializes; ordinary HTTPS page loads; known ad domain blocked; app screenshot captured.");
  Application.Current.Shutdown(0);
 }
 void Home(BrowserTab t) {
  t.Url="";t.Title="New tab";
  t.Web.NavigateToString("<!doctype html><html><head><meta name='color-scheme' content='dark light'><title>New tab</title><style>body{font:16px Segoe UI,sans-serif;background:#1b2026;color:#eef4f6;margin:0}main{max-width:650px;margin:16vh auto;padding:40px}small{color:#42c4de;letter-spacing:4px}h1{font:64px Georgia;letter-spacing:-2px}p{color:#b1bac1}a{display:inline-block;padding:20px;color:#65d8ed;background:#252e38;margin:8px;border-radius:12px;text-decoration:none}</style></head><body><main><small>A LITTLE SPACE TO EXPLORE</small><h1>Less noise.<br>More possibility.</h1><p>Search or enter a website in the address bar above.</p><a href='https://wikipedia.org'>Wikipedia</a><a href='https://youtube.com'>YouTube</a><a href='https://open.spotify.com'>Spotify</a><p>Made for a calmer corner of the internet.</p></main></body></html>");
  RefreshTabs();
 }
 void Select(BrowserTab t) {
  selected=t; foreach(var x in tabs) x.Web.Visibility=x==t?Visibility.Visible:Visibility.Collapsed;
  address.Text=t.Url; Title=t.Title+" — Orbit Browser"; RefreshTabs();
 }
 void CloseTab(BrowserTab t) {
  t.Closed=true; pages.Children.Remove(t.Web); t.Web.Dispose(); tabs.Remove(t);
  if(selected==t) { selected=null; if(tabs.Count>0) Select(tabs[^1]); else NewTab(); } RefreshTabs(); Save();
 }
 void RefreshTabs() {
  tabRows.Children.Clear();
  foreach(var group in state.Groups) {
   tabRows.Children.Add(new TextBlock { Text=group.ToUpperInvariant(),FontSize=10,Foreground=Accent,Margin=new Thickness(8,18,8,5) });
   foreach(var t in tabs.Where(t=>t.Group==group)) {
    var row=new DockPanel(); var close=Button("×",()=>CloseTab(t)); DockPanel.SetDock(close,Dock.Right);row.Children.Add(close);
    var item=Button(t.Title,()=>Select(t));item.ToolTip=t.Url;
    item.Foreground=Foreground;item.Background=t==selected?Accent:Background;
    item.BorderBrush=Brushes.Transparent;
    var menu=new ContextMenu();
    foreach(var g in state.Groups) { var m=new MenuItem { Header="Move to "+g };m.Click+=(_,_)=>{t.Group=g;RefreshTabs();Save();};menu.Items.Add(m); }
    item.ContextMenu=menu;row.Children.Add(item);tabRows.Children.Add(row);
   }
  }
 }
 void Bookmark() { if(selected==null || string.IsNullOrEmpty(selected.Url)) return; var old=state.Bookmarks.FirstOrDefault(x=>x.Url==selected.Url); if(old!=null) state.Bookmarks.Remove(old);else state.Bookmarks.Add(new SavedLink(selected.Title,selected.Url));Save();status.Text=old==null?"Bookmark saved":"Bookmark removed"; }
 Window Panel(string title,StackPanel content) {
  var w=new Window { Title=title+" — Orbit",Owner=this,Width=550,Height=480,WindowStartupLocation=WindowStartupLocation.CenterOwner,Content=new ScrollViewer { Content=content,VerticalScrollBarVisibility=ScrollBarVisibility.Auto },Background=Background,Foreground=Foreground };
  content.Margin=new Thickness(24);ownedPanels.Add(w);w.Closed+=(_,_)=>ownedPanels.Remove(w);w.Show();return w;
 }
 void CreateGroup() {
  var body=new StackPanel();body.Children.Add(Text("Create a tab group",24));var name=new TextBox { Margin=new Thickness(5),Padding=new Thickness(8) };body.Children.Add(name);
  Window? w=null;body.Children.Add(Button("Create",()=>{var g=name.Text.Trim();if(g.Length>0&&!state.Groups.Contains(g)){state.Groups.Add(g);RefreshTabs();Save();w?.Close();}}));w=Panel("New group",body);
 }
 void Links(bool history) {
  var body=new StackPanel(); body.Children.Add(Text(history?"History":"Bookmarks",24));Window? panel=null;
  if(history) body.Children.Add(Button("Clear browsing history…",async ()=> {
   if(MessageBox.Show(this,"Clear visit history and close all tabs? Cookies and bookmarks will stay.","Clear history",MessageBoxButton.YesNo)!=MessageBoxResult.Yes)return;
   if(selected?.Ready==true) await selected.Web.CoreWebView2.Profile.ClearBrowsingDataAsync(CoreWebView2BrowsingDataKinds.BrowsingHistory);
   foreach(var t in tabs.ToArray()){t.Closed=true;t.Web.Dispose();}tabs.Clear();pages.Children.Clear();state.History.Clear();NewTab();Save();panel?.Close();
  }));
  foreach(var link in (history?state.History:state.Bookmarks).ToArray()) {
   var row=new DockPanel(); if(!history){var remove=Button("Remove",()=>{state.Bookmarks.Remove(link);Save();panel?.Close();Links(false);});DockPanel.SetDock(remove,Dock.Right);row.Children.Add(remove);}
   var b=Button(link.Title,()=>{NewTab(link.Url);panel?.Close();});b.ToolTip=link.Url;row.Children.Add(b);body.Children.Add(row);
  }
  panel=Panel(history?"History":"Bookmarks",body);
 }
 void Media() {
  var body=new StackPanel();body.Children.Add(Text("Media controls",24));body.Children.Add(Text("Controls standard audio and video in the selected tab. Cross-origin embeds and protected players may not respond."));
  foreach(var pair in new[]{("Play / pause","if(m.paused){m.play().catch(()=>{})}else{m.pause()}"),("Back 10 seconds","m.currentTime=Math.max(0,m.currentTime-10)"),("Forward 10 seconds","if(Number.isFinite(m.duration)){m.currentTime=Math.min(m.duration,m.currentTime+10)}"),("Mute / unmute","m.muted=!m.muted")})
   body.Children.Add(Button(pair.Item1,async ()=>{if(selected?.Ready==true)try{await selected.Web.ExecuteScriptAsync("document.querySelectorAll('video,audio').forEach(m=>{"+pair.Item2+"});");}catch{status.Text="This player could not be controlled.";}}));
  Panel("Media",body);
 }
 void Privacy() {
  var body=new StackPanel();body.Children.Add(Text("Privacy",24));
  var ads=new CheckBox { Content="Block known ad domains",IsChecked=state.Ads,Margin=new Thickness(5,10,5,10) };
  var trackers=new CheckBox { Content="Block known tracker domains",IsChecked=state.Trackers,Margin=new Thickness(5,10,5,10) };
  body.Children.Add(ads);body.Children.Add(trackers);
  void Updated(){state.Ads=ads.IsChecked==true;state.Trackers=trackers.IsChecked==true;Save();status.Text="Protection settings updated for future requests. Reload a page to apply fully.";}
  ads.Checked+=(_,_)=>Updated();ads.Unchecked+=(_,_)=>Updated();trackers.Checked+=(_,_)=>Updated();trackers.Unchecked+=(_,_)=>Updated();
  body.Children.Add(Text("Uses a small static list of 17 ad and tracker domains. It does not block every ad or tracker and does not provide anonymity."));
  body.Children.Add(Button("Clear cookies and website data…",async ()=>{if(selected?.Ready==true&&MessageBox.Show(this,"Delete all stored website data? This signs you out of websites.","Clear website data",MessageBoxButton.YesNo)==MessageBoxResult.Yes){await selected.Web.CoreWebView2.Profile.ClearBrowsingDataAsync(CoreWebView2BrowsingDataKinds.AllProfile);status.Text="Website data cleared.";}}));
  body.Children.Add(Text("Camera, microphone, location, notifications, and other website permissions are denied in this preview."));Panel("Privacy",body);
 }
 void Settings() {
  var body=new StackPanel();body.Children.Add(Text("Make it yours",24));
  void Choice(string name,string[] choices,string value,Action<string> set){body.Children.Add(Text(name));var c=new ComboBox { ItemsSource=choices,SelectedItem=value,Margin=new Thickness(5),Padding=new Thickness(7) };c.SelectionChanged+=(_,_)=>{if(c.SelectedItem is string s){set(s);ApplyTheme();Save();}};body.Children.Add(c);}
  Choice("Search engine",new[]{"DuckDuckGo","Google","Bing"},state.Engine,s=>state.Engine=s);
  Choice("Appearance",new[]{"Dark","Light"},state.Theme,s=>state.Theme=s);
  Choice("Accent",new[]{"Ocean","Forest","Lavender"},state.Accent,s=>state.Accent=s);Panel("Customize",body);
 }
}
