using Avalonia;
using Avalonia.Controls;
using Avalonia.Controls.ApplicationLifetimes;
using Avalonia.Markup.Xaml;
using Avalonia.Platform;
using Avalonia.Threading;
using SalatTime.Core;
using SalatTime.Platform;
using SalatTime.Views;

namespace SalatTime;

public partial class App : Application
{
    public static App? Instance { get; private set; }
    public AppState State { get; private set; } = null!;
    public AppSettings Settings => State.Settings;
    public ITray? Tray { get; private set; }

    PopupWindow? _popup;
    TrayMenuWindow? _trayMenu;
    MainWindow? _main;
    CountdownPill? _pill;
    DispatcherTimer? _timer;
    IClassicDesktopStyleApplicationLifetime? _desktop;

    public override void Initialize()
    {
        Instance = this;
        AvaloniaXamlLoader.Load(this);
    }

    /// <summary>Set by the screenshot tool: build the state but start no tray, timer or windows.</summary>
    public static bool HeadlessMode { get; set; }

    public override void OnFrameworkInitializationCompleted()
    {
        if (!HeadlessMode) Boot(AppSettings.Load());
        base.OnFrameworkInitializationCompleted();
    }

    /// <summary>Load strings and theme, create the platform services and the app state.</summary>
    public void Boot(AppSettings settings, IAudioService? audioOverride = null)
    {
        using (var strings = AssetLoader.Open(new Uri("avares://SalatTime/Assets/strings.json")))
            Localizer.Shared.Load(strings);
        Localizer.Shared.SetLanguage(settings.Language);
        Localizer.Shared.ArabicIndicDigits = settings.ArabicDigits == "arabicIndic";
        _appliedLanguage = settings.Language;
        _appliedLook = $"{settings.Appearance}|{settings.Accent}";
        AppTheme.Apply(settings);

        IAudioService audio = audioOverride ?? new NullAudio();
        IAudioService adhkarAudio = new NullAudio();
        INotifier notifier = new NullNotifier();
        if (OperatingSystem.IsWindows() && !HeadlessMode)
        {
            audio = new WindowsAudio();
            adhkarAudio = new WindowsAudio();
            var tray = new Win32Tray();
            Tray = tray;
            notifier = tray;
            MawaqitClient.WebFallback = new WebView2Runner();
            StartupRegistration.Sync(settings.OpenAtLogin);
        }
        State = new AppState(settings, audio, notifier, adhkarAudio);
        settings.Changed += OnSettingsChanged;
        if (HeadlessMode) return;

        State.InfoChanged += () => Dispatcher.UIThread.Post(RefreshAll);
        State.AdhanStateChanged += () => Dispatcher.UIThread.Post(OnAdhanStateChanged);
        State.AdhkarDue += kind => Dispatcher.UIThread.Post(() => OpenMainWindow("adhkar:" + kind));

        if (Tray is not null)
        {
            Tray.LeftClick += OnTrayLeftClick;
            Tray.DoubleClick += OnTrayDoubleClick;
            Tray.RightClick += point => ShowTrayMenu(point);
            Tray.StopClick += () => State.StopAdhan();
            Tray.BalloonClick += () => OpenMainWindow(null);
        }

        if (ApplicationLifetime is IClassicDesktopStyleApplicationLifetime desktop)
        {
            _desktop = desktop;
            desktop.ShutdownRequested += (_, _) => Shutdown();
        }

        _timer = new DispatcherTimer(TimeSpan.FromSeconds(1), DispatcherPriority.Normal, (_, _) => State.Tick(Clock.Now()));
        _timer.Start();
        State.Tick(Clock.Now());
        UpdateTray(Clock.Now());
        State.Ticked += UpdateTray;
        if (settings.CountdownPill) ShowPill(true);

        if (!Program.StartedInBackground)
        {
            // No tray outside Windows (development): open the main window instead.
            if (Tray is null || !settings.FirstRunDone) OpenMainWindow(settings.FirstRunDone ? null : "settings:mosque");
            else Dispatcher.UIThread.Post(() => ShowPopup(null), DispatcherPriority.Background);
        }
        if (!settings.FirstRunDone) { settings.FirstRunDone = true; settings.Save(notify: false); }
    }

    // ------------------------------------------------------------------ tray clicks

    DateTime _lastLeftClick = DateTime.MinValue;
    IDisposable? _pendingClick;

    void OnTrayLeftClick(PixelPoint point)
    {
        // While the adhan plays a double-click silences it (e.g. in a meeting);
        // a single click waits out the double-click time before opening the popup.
        if (!State.IsAdhanPlaying) { TogglePopup(point); return; }
        var now = DateTime.UtcNow;
        var interval = TimeSpan.FromMilliseconds(Win32Tray.DoubleClickMilliseconds);
        if (now - _lastLeftClick <= interval) { OnTrayDoubleClick(); return; }
        _lastLeftClick = now;
        _pendingClick?.Dispose();
        _pendingClick = DispatcherTimer.RunOnce(() => { _pendingClick = null; TogglePopup(point); }, interval);
    }

    void OnTrayDoubleClick()
    {
        _pendingClick?.Dispose();
        _pendingClick = null;
        _lastLeftClick = DateTime.MinValue;
        if (State.IsAdhanPlaying)
        {
            _popup?.Hide();
            State.StopAdhan();
        }
    }

    // ------------------------------------------------------------------ windows

    public void TogglePopup(PixelPoint? point)
    {
        if (_popup is { IsVisible: true }) { _popup.Hide(); return; }
        ShowPopup(point);
    }

    public void ShowPopup(PixelPoint? point)
    {
        _trayMenu?.Hide();
        _popup ??= new PopupWindow(State);
        _popup.ShowNear(point, Tray?.IconRect);
    }

    public void ShowTrayMenu(PixelPoint point)
    {
        _popup?.Hide();
        _trayMenu?.Close();
        _trayMenu = new TrayMenuWindow(State);
        _trayMenu.ShowAt(point, Tray?.IconRect);
    }

    /// <summary>Open the main window, optionally on a page: "prayer", "adhkar", "quran", "settings:adhan", ...</summary>
    public void OpenMainWindow(string? page)
    {
        _popup?.Hide();
        _trayMenu?.Hide();
        if (_main is null)
        {
            _main = new MainWindow(State);
            _main.Closed += (_, _) => _main = null;
        }
        if (page is not null) _main.Navigate(page);
        _main.Show();
        if (_main.WindowState == WindowState.Minimized) _main.WindowState = WindowState.Normal;
        _main.Activate();
    }

    public void RefreshMainHeader() => _main?.RefreshHeader();

    public void ActivateFromSecondLaunch() => Dispatcher.UIThread.Post(() => OpenMainWindow(null));

    public void ShowPill(bool show)
    {
        if (show)
        {
            _pill ??= new CountdownPill(State);
            _pill.Show();
        }
        else
        {
            _pill?.Close();
            _pill = null;
        }
    }

    // ------------------------------------------------------------------ state

    string _appliedLanguage = "";
    string _appliedLook = "";

    void OnSettingsChanged()
    {
        var s = Settings;
        Localizer.Shared.ArabicIndicDigits = s.ArabicDigits == "arabicIndic";
        var look = $"{s.Appearance}|{s.Accent}";
        if (look != _appliedLook) { _appliedLook = look; AppTheme.Apply(s); }
        if (s.Language != _appliedLanguage)
        {
            _appliedLanguage = s.Language;
            Localizer.Shared.SetLanguage(s.Language);
            _popup?.Close(); _popup = null;
            _trayMenu?.Close(); _trayMenu = null;
            _main?.Relocalize();
            _pill?.Relocalize();
        }
        if (OperatingSystem.IsWindows()) StartupRegistration.Sync(s.OpenAtLogin);
        if (s.CountdownPill != (_pill is not null)) ShowPill(s.CountdownPill);
        RefreshAll();
    }

    void RefreshAll()
    {
        _popup?.Refresh();
        _main?.Refresh();
        UpdateTray(Clock.Now());
    }

    void OnAdhanStateChanged()
    {
        Tray?.SetStopIconVisible(State.IsAdhanPlaying);
        _popup?.Refresh();
        _main?.Refresh();
        UpdateTray(Clock.Now());
    }

    void UpdateTray(DateTime now)
    {
        if (Tray is null) return;
        Tray.Update(TrayStatus.Compute(State, now));
    }

    bool _shuttingDown;

    public void Shutdown()
    {
        if (_shuttingDown) return;
        _shuttingDown = true;
        _timer?.Stop();
        State.StopAdhan();
        Tray?.Dispose();
        Tray = null;
        _desktop?.Shutdown();
    }
}
