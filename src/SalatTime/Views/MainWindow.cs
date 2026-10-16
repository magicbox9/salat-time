using Avalonia;
using Avalonia.Controls;
using Avalonia.Controls.Primitives;
using Avalonia.Layout;
using Avalonia.Media;
using SalatTime.Core;
using SalatTime.Views.Pages;

namespace SalatTime.Views;

/// <summary>A destination in the main window: Prayer times, Adhkar, Qur'an or Settings.</summary>
public interface IPage
{
    string Key { get; }
    string Title { get; }
    string Subtitle { get; }
    /// <summary>View modes shown as a segmented control in the header (empty = none).</summary>
    IReadOnlyList<string> Modes { get; }
    int Mode { get; set; }
    Control View { get; }
    void Refresh();
    void Tick(DateTime now);
    /// <summary>Handle a sub-destination such as "mosque" in "settings:mosque".</summary>
    void Open(string? detail) { }
}

/// <summary>
/// The full window: a sidebar (Prayer times, Adhkar, Qur'an, Settings at the
/// bottom) and one shared header with the page title, a live subtitle and the
/// page's view modes — the same structure as the Mac main window.
/// </summary>
public sealed class MainWindow : Window
{
    readonly AppState _state;
    readonly List<IPage> _pages = new();
    readonly Dictionary<string, Button> _navButtons = new();
    readonly ContentControl _host = new();
    readonly TextBlock _title = Ui.Text("", 26, FontWeight.SemiBold);
    readonly TextBlock _subtitle = new() { FontSize = 13, TextTrimming = TextTrimming.CharacterEllipsis, Classes = { "secondary" } };
    readonly StackPanel _modeBar = new() { Orientation = Orientation.Horizontal, Spacing = 2 };
    readonly Border _modeHost;
    readonly Grid _root = new();
    IPage? _current;

    public MainWindow(AppState state)
    {
        _state = state;
        Title = "Salat Time";
        Width = 1120;
        Height = 760;
        MinWidth = 820;
        MinHeight = 560;
        WindowStartupLocation = WindowStartupLocation.CenterScreen;
        ExtendClientAreaToDecorationsHint = true;
        ExtendClientAreaChromeHints = Avalonia.Platform.ExtendClientAreaChromeHints.PreferSystemChrome;
        ExtendClientAreaTitleBarHeightHint = 44;
        TransparencyLevelHint = new[] { WindowTransparencyLevel.Mica, WindowTransparencyLevel.AcrylicBlur, WindowTransparencyLevel.None };
        Background = Brushes.Transparent;
        try { Icon = new WindowIcon(Avalonia.Platform.AssetLoader.Open(new Uri("avares://SalatTime/Assets/icon.png"))); } catch { }

        _modeHost = new Border { Child = _modeBar, Padding = new Thickness(3), CornerRadius = new CornerRadius(8) };
        Ui.Bind(_modeHost, Border.BackgroundProperty, "CardBrush");

        _pages.Add(new PrayerPage(state));
        _pages.Add(new AdhkarPage(state));
        _pages.Add(new QuranPage(state));
        _pages.Add(new SettingsPage(state));

        Content = _root;
        Build();
        Opened += (_, _) => ApplySurface();
        _state.Ticked += OnTick;
        Closed += (_, _) => _state.Ticked -= OnTick;
        Navigate(state.Settings.LastPage ?? "prayer");
    }

    void ApplySurface()
    {
        // Mica shows through the sidebar; the content area gets a light layer.
        _root.Background = ActualTransparencyLevel == WindowTransparencyLevel.None ? Ui.Res("SurfaceBrush") : Brushes.Transparent;
    }

    void Build()
    {
        _root.Children.Clear();
        _root.ColumnDefinitions = new ColumnDefinitions("236,*");
        AppTheme.Localize(this);
        var l = Localizer.Shared;

        // ---- sidebar
        var sidebar = new Grid { RowDefinitions = new RowDefinitions("Auto,*,Auto"), Margin = new Thickness(10, 10, 6, 12) };
        var brand = new StackPanel { Orientation = Orientation.Horizontal, Spacing = 10, Margin = new Thickness(10, 4, 10, 18), IsHitTestVisible = false };
        var tile = new Border { Width = 28, Height = 28, CornerRadius = new CornerRadius(7), Child = Ui.Icon("WeatherMoonFilled", 16, Brushes.White) };
        Ui.Bind(tile, Border.BackgroundProperty, "HeaderDeepBrush");
        brand.Children.Add(tile);
        brand.Children.Add(Ui.Text("Salat Time", 14, FontWeight.SemiBold));
        sidebar.Children.Add(brand);

        var nav = new StackPanel { Spacing = 3 };
        _navButtons.Clear();
        nav.Children.Add(NavButton("prayer", "ClockRegular", l.T("main.tab.prayer_times")));
        nav.Children.Add(NavButton("adhkar", "BookRegular", l.T("adhkar.editor.title")));
        nav.Children.Add(NavButton("quran", "BookOpenRegular", l.T("feature:quran.tab")));
        Grid.SetRow(nav, 1);
        sidebar.Children.Add(nav);

        var bottom = new StackPanel { Spacing = 3 };
        bottom.Children.Add(NavButton("settings", "SettingsRegular", l.T("tooltip.settings")));
        Grid.SetRow(bottom, 2);
        sidebar.Children.Add(bottom);
        _root.Children.Add(sidebar);

        // ---- content: shared header + page
        var content = new Grid { RowDefinitions = new RowDefinitions("Auto,*") };
        var contentSurface = new Border
        {
            Child = content,
            CornerRadius = l.IsRtl ? new CornerRadius(0, 8, 0, 0) : new CornerRadius(8, 0, 0, 0),
            BorderThickness = l.IsRtl ? new Thickness(0, 1, 1, 0) : new Thickness(1, 1, 0, 0),
            Margin = new Thickness(0, 44, 0, 0),
            ClipToBounds = true,
        };
        Ui.Bind(contentSurface, Border.BackgroundProperty, "RaisedCardBrush");
        Ui.Bind(contentSurface, Border.BorderBrushProperty, "CardBorderBrush");
        Grid.SetColumn(contentSurface, 1);

        var header = new Grid { ColumnDefinitions = new ColumnDefinitions("*,Auto"), Margin = new Thickness(32, 22, 32, 10) };
        var titles = new StackPanel { Spacing = 2, Margin = new Thickness(0, 0, 16, 0) };
        titles.Children.Add(_title);
        titles.Children.Add(_subtitle);
        header.Children.Add(titles);
        _modeHost.VerticalAlignment = VerticalAlignment.Center;
        Grid.SetColumn(_modeHost, 1);
        header.Children.Add(_modeHost);
        content.Children.Add(header);
        Grid.SetRow(_host, 1);
        content.Children.Add(_host);
        _root.Children.Add(contentSurface);
    }

    Button NavButton(string key, string icon, string label)
    {
        var row = new StackPanel { Orientation = Orientation.Horizontal, Spacing = 12 };
        var pi = Ui.Icon(icon, 18);
        Ui.Bind(pi, PathIcon.ForegroundProperty, "TextSecondary");
        row.Children.Add(pi);
        row.Children.Add(Ui.Text(label, 13.5));
        var indicator = new Border { Width = 3, Height = 16, CornerRadius = new CornerRadius(2), HorizontalAlignment = HorizontalAlignment.Left, IsVisible = false };
        Ui.Bind(indicator, Border.BackgroundProperty, "AccentBrush");
        var grid = new Grid();
        grid.Children.Add(indicator);
        row.Margin = new Thickness(10, 0, 0, 0);
        grid.Children.Add(row);
        var button = new Button { Content = grid, Height = 38, Padding = new Thickness(4, 0) };
        button.Classes.Add("row");
        button.Tag = indicator;
        button.Click += (_, _) => Navigate(key);
        _navButtons[key] = button;
        return button;
    }

    /// <summary>Show a page: "prayer", "adhkar", "quran", "settings", optionally with ":detail".</summary>
    public void Navigate(string target)
    {
        var parts = target.Split(':', 2);
        var page = _pages.FirstOrDefault(p => p.Key == parts[0]) ?? _pages[0];
        _current = page;
        foreach (var (key, button) in _navButtons)
        {
            var selected = key == page.Key;
            button.Classes.Set("selected", selected);
            if (button.Tag is Border indicator) indicator.IsVisible = selected;
        }
        _host.Content = page.View;
        page.Open(parts.Length > 1 ? parts[1] : null);
        page.Refresh();
        UpdateHeader();
        if (page.Key != "settings")
        {
            _state.Settings.LastPage = page.Key;
            _state.Settings.Save(notify: false);
        }
    }

    /// <summary>Update the title, subtitle and view modes without rebuilding the page.</summary>
    public void RefreshHeader() => UpdateHeader();

    /// <summary>Switch the current page's view mode (header segmented control).</summary>
    public void SelectMode(int mode)
    {
        if (_current is null || mode < 0 || mode >= Math.Max(1, _current.Modes.Count)) return;
        _current.Mode = mode;
        _current.Refresh();
        UpdateHeader();
    }

    void UpdateHeader()
    {
        if (_current is null) return;
        _title.Text = _current.Title;
        _subtitle.Text = _current.Subtitle;
        _modeBar.Children.Clear();
        _modeHost.IsVisible = _current.Modes.Count > 0;
        for (int i = 0; i < _current.Modes.Count; i++)
        {
            var index = i;
            var selected = i == _current.Mode;
            var b = new Button { Content = Ui.Text(_current.Modes[i], 12.5, selected ? FontWeight.SemiBold : FontWeight.Normal), Padding = new Thickness(12, 5), CornerRadius = new CornerRadius(6) };
            b.Classes.Add("row");
            if (selected) Ui.Bind(b, Button.BackgroundProperty, "RaisedCardBrush");
            b.Click += (_, _) => { _current.Mode = index; _current.Refresh(); UpdateHeader(); };
            _modeBar.Children.Add(b);
        }
    }

    void OnTick(DateTime now)
    {
        if (!IsVisible || _current is null) return;
        _current.Tick(now);
        _subtitle.Text = _current.Subtitle;
    }

    public void Refresh()
    {
        _current?.Refresh();
        UpdateHeader();
    }

    public void Relocalize()
    {
        var key = _current?.Key ?? "prayer";
        _pages.Clear();
        _pages.Add(new PrayerPage(_state));
        _pages.Add(new AdhkarPage(_state));
        _pages.Add(new QuranPage(_state));
        _pages.Add(new SettingsPage(_state));
        Build();
        Navigate(key);
    }
}
