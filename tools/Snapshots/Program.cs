using System.Text.Json;
using Avalonia;
using Avalonia.Controls;
using Avalonia.Headless;
using Avalonia.Media.Imaging;
using Avalonia.Threading;
using SalatTime;
using SalatTime.Core;
using SalatTime.Platform;
using SalatTime.Views;

// Usage: Snapshots <output folder> <mosque.json> [filter]
// Renders the windows at 2x to PNG so the design can be checked on any machine.
var outDir = Path.GetFullPath(args.Length > 0 ? args[0] : "snapshots");
var mosquePath = args.Length > 1 ? args[1] : null;
var filter = args.Length > 2 ? args[2] : "";
Directory.CreateDirectory(outDir);
AppSettings.FolderOverride = Path.Combine(outDir, "_settings");
if (Directory.Exists(AppSettings.FolderOverride)) Directory.Delete(AppSettings.FolderOverride, true);

App.HeadlessMode = true;
SalatTime.Controls.AnimatedCanvas.Animate = false;
AppBuilder.Configure<App>()
    .UseSkia()
    .UseHeadless(new AvaloniaHeadlessPlatformOptions { UseHeadlessDrawing = false })
    .With(new Avalonia.Media.FontManagerOptions
    {
        FontFallbacks = new[] { new Avalonia.Media.FontFallback { FontFamily = new Avalonia.Media.FontFamily("avares://SalatTime/Assets/Fonts#Cairo") } },
    })
    .SetupWithoutStarting();

var app = App.Instance!;
var settings = new AppSettings { Language = "en", FirstRunDone = true };
settings.SetMode(0, AdhanMode.Notify);
settings.SetMode(4, AdhanMode.Off);
app.Boot(settings);
if (mosquePath is not null)
{
    var info = JsonSerializer.Deserialize<MosqueInfo>(File.ReadAllText(mosquePath), new JsonSerializerOptions { PropertyNameCaseInsensitive = true })!;
    app.State.ReplaceInfo(info);
}

var today = DateTime.Today;
DateTime At(int h, int m) => today.AddHours(h).AddMinutes(m);

void Configure(string lang, string appearance, DateTime now)
{
    Clock.Now = () => now;
    settings.Language = lang;
    settings.Appearance = appearance;
    Localizer.Shared.SetLanguage(lang);
    AppTheme.Apply(settings);
    Dispatcher.UIThread.RunJobs();
}

void Save(Control visual, string name, double scale = 2)
{
    Dispatcher.UIThread.RunJobs();
    var size = visual.Bounds.Size;
    var pixel = new PixelSize((int)Math.Ceiling(size.Width * scale), (int)Math.Ceiling(size.Height * scale));
    using var rtb = new RenderTargetBitmap(pixel, new Vector(96 * scale, 96 * scale));
    rtb.Render(visual);
    var path = Path.Combine(outDir, name + ".png");
    rtb.Save(path);
    Console.WriteLine($"{name}.png  {pixel.Width}x{pixel.Height}");
}

void Snap(string name, string lang, string appearance, DateTime now, Func<Window> make, Action<AppState>? before = null)
{
    if (filter.Length > 0 && !name.Contains(filter)) return;
    Configure(lang, appearance, now);
    before?.Invoke(app.State);
    var window = make();
    window.Show();
    Dispatcher.UIThread.RunJobs();
    AvaloniaHeadlessPlatform.ForceRenderTimerTick();
    Dispatcher.UIThread.RunJobs();
    if (name.StartsWith("pill"))
    {
        // Small borderless windows: use the headless frame capture.
        var frame = window.CaptureRenderedFrame();
        frame?.Save(Path.Combine(outDir, name + ".png"));
        Console.WriteLine($"{name}.png  (frame)");
    }
    else Save(window, name);
    window.Close();
    app.State.StopAdhan();
}

// ---- tray popup
Snap("popup-en-light", "en", "light", At(13, 20), () => new PopupWindow(app.State));
Snap("popup-en-dark-adhan", "en", "dark", At(13, 51), () => new PopupWindow(app.State), s => s.PlayAdhan(1));
Snap("popup-ar-light", "ar", "light", At(17, 5), () => new PopupWindow(app.State));
Snap("popup-ar-dark", "ar", "dark", At(21, 40), () => new PopupWindow(app.State));
Snap("popup-fr-light", "fr", "light", At(6, 30), () => new PopupWindow(app.State));

// ---- tray menu
Snap("traymenu-en-light", "en", "light", At(13, 20), () => new TrayMenuWindow(app.State));
Snap("traymenu-ar-dark", "ar", "dark", At(13, 20), () => new TrayMenuWindow(app.State), s => s.PlayAdhan(1));

// ---- countdown pill
Snap("pill-en-light", "en", "light", At(13, 20), () => new CountdownPill(app.State));
Snap("pill-en-iqama", "en", "dark", At(13, 36), () => new CountdownPill(app.State));

// ---- main window pages
foreach (var (page, mode) in new[] { ("prayer", 0), ("prayer", 1), ("prayer", 2), ("prayer", 3), ("adhkar", 0), ("adhkar", 1), ("quran", 0), ("quran", 1), ("settings", 0), ("settings", 1), ("settings", 2), ("settings", 3), ("settings", 4) })
{
    foreach (var (lang, look) in new[] { ("en", "light"), ("ar", "dark") })
    {
        Snap($"main-{page}{mode}-{lang}-{look}", lang, look, At(13, 20), () =>
        {
            var w = new MainWindow(app.State) { Width = 1120, Height = 760 };
            w.Navigate(page);
            w.SelectMode(mode);
            return w;
        });
    }
}

// ---- a dense Mushaf page and Warsh
Snap("quran-page50-en-light", "en", "light", At(13, 20), () =>
{
    settings.QuranEdition = "hafs"; settings.QuranPage = 50; settings.QuranSura = 3; settings.QuranAyah = 1; settings.QuranMode = 1;
    var w = new MainWindow(app.State) { Width = 1500, Height = 1000 };
    w.Navigate("quran");
    return w;
});
Snap("quran-warsh-ar-dark", "ar", "dark", At(13, 20), () =>
{
    settings.QuranEdition = "warsh"; settings.QuranPage = 50; settings.QuranMode = 1;
    var w = new MainWindow(app.State) { Width = 1120, Height = 900 };
    w.Navigate("quran");
    return w;
});
settings.QuranEdition = "hafs"; settings.QuranPage = 1; settings.QuranSura = 1; settings.QuranAyah = 1;

// ---- tray icons (scaled up 8x for inspection)
if (filter.Length == 0 || "trayicons".Contains(filter))
{
    var panel = new StackPanel { Orientation = Avalonia.Layout.Orientation.Horizontal, Spacing = 12, Background = Avalonia.Media.Brushes.Gray };
    foreach (var size in new[] { 16, 24, 32 })
    {
        foreach (var bmp in new[] { TrayIconArt.DrawAppIcon(size, AppTheme.Pair("green").Light), TrayIconArt.DrawNumber(size, 42, AppTheme.Pair("green").Light),
                     TrayIconArt.DrawNumber(size, 8, Avalonia.Media.Color.FromRgb(196, 43, 28)), TrayIconArt.DrawStop(size) })
        {
            panel.Children.Add(new Image { Source = bmp, Width = size * 4, Height = size * 4 });
        }
    }
    var host = new Window { Content = panel, SizeToContent = SizeToContent.WidthAndHeight };
    host.Show();
    Dispatcher.UIThread.RunJobs();
    Save(panel, "trayicons", 2);
    host.Close();
}
