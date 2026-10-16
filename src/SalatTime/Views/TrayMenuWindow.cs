using Avalonia;
using Avalonia.Controls;
using Avalonia.Layout;
using Avalonia.Media;
using Avalonia.Threading;
using SalatTime.Core;

namespace SalatTime.Views;

/// <summary>
/// The right-click menu of the tray icon. A custom flyout rather than a native
/// menu so it can hold the adhan volume slider, like the Mac menu: it sets the
/// volume of the speaker the adhan plays on, without touching the system output.
/// </summary>
public sealed class TrayMenuWindow : Window
{
    readonly AppState _state;
    readonly Border _surface;
    readonly StackPanel _items = new() { Margin = new Thickness(4) };
    PixelPoint _click;
    PixelRect? _icon;

    public TrayMenuWindow(AppState state)
    {
        _state = state;
        Title = "Salat Time";
        Width = 292;
        SizeToContent = SizeToContent.Height;
        CanResize = false;
        ShowInTaskbar = false;
        Topmost = true;
        WindowStartupLocation = WindowStartupLocation.Manual;
        SystemDecorations = SystemDecorations.Full;
        ExtendClientAreaToDecorationsHint = true;
        ExtendClientAreaChromeHints = Avalonia.Platform.ExtendClientAreaChromeHints.NoChrome;
        ExtendClientAreaTitleBarHeightHint = 0;
        TransparencyLevelHint = new[] { WindowTransparencyLevel.AcrylicBlur, WindowTransparencyLevel.Mica, WindowTransparencyLevel.None };
        Background = Brushes.Transparent;
        _surface = new Border { Child = _items };
        Content = _surface;
        AppTheme.Localize(this);
        Build();
        Deactivated += (_, _) => Close();
        Opened += (_, _) =>
        {
            _surface.Background = ActualTransparencyLevel == WindowTransparencyLevel.None ? Ui.Res("SurfaceBrush") : Ui.Res("SurfaceTintBrush");
        };
        SizeChanged += (_, _) => Reposition();
        KeyDown += (_, e) => { if (e.Key == Avalonia.Input.Key.Escape) Close(); };
    }

    void Build()
    {
        var l = Localizer.Shared;
        var s = _state.Settings;

        var header = Ui.Text(_state.MosqueName, 12, FontWeight.SemiBold, "secondary");
        header.Margin = new Thickness(10, 8, 10, 6);
        header.TextTrimming = TextTrimming.CharacterEllipsis;
        _items.Children.Add(header);
        Separator();

        // Adhan controls, reachable without opening Settings (e.g. during a meeting).
        if (_state.IsAdhanPlaying)
            Item("StopFilled", l.T("tooltip.stop_adhan"), () => _state.StopAdhan(), danger: true);
        else
            Item("PlayRegular", l.T("tooltip.test_adhan"), () => _state.PlayAdhan(), keepOpen: true);
        _items.Children.Add(VolumeRow());
        Separator();

        Item("WindowRegular", l.T("menu.open"), () => App.Instance?.ShowPopup(_click));
        Item("ArrowSyncRegular", l.T("menu.refresh"), () => _ = _state.RefreshAsync());
        Item("LocationRegular", l.T("menu.choose"), () => App.Instance?.OpenMainWindow("settings:mosque"));
        Item("SettingsRegular", l.T("menu.settings"), () => App.Instance?.OpenMainWindow("settings"));
        Item("DesktopRegular", l.T("menu.main_window"), () => App.Instance?.OpenMainWindow("prayer"));

        if (s.Favorites.Count > 0)
        {
            Separator();
            var title = Ui.Text(l.T("menu.favorites"), 11, FontWeight.SemiBold, "tertiary");
            title.Margin = new Thickness(10, 4, 10, 2);
            _items.Children.Add(title);
            foreach (var fav in s.Favorites)
            {
                var current = MosqueUrls.Normalize(fav.Url) == MosqueUrls.Normalize(s.MosqueUrl);
                var label = fav.City.Length > 0 ? $"{fav.Name} — {fav.City}" : fav.Name;
                Item(current ? "CheckmarkRegular" : "StarRegular", label, () => _ = _state.SelectMosqueAsync(fav.Url));
            }
        }

        Separator();
        Item("PowerRegular", l.T("menu.quit"), () => App.Instance?.Shutdown());
    }

    Control VolumeRow()
    {
        var l = Localizer.Shared;
        var s = _state.Settings;
        var audio = _state.Audio;
        var device = audio.ResolveDevice(s.AdhanDevice);
        var deviceVolume = audio.DeviceVolume(s.AdhanDevice);

        var title = Ui.Text(l.T("menu.adhan_volume") + (device is null ? "" : " · " + device.Name), 11.5, FontWeight.Normal, "secondary");
        title.TextTrimming = TextTrimming.CharacterEllipsis;
        var percent = Ui.Text("", 11.5, FontWeight.Normal, "secondary digits");
        percent.MinWidth = 38;
        percent.TextAlignment = TextAlignment.Right;
        var slider = new Slider
        {
            Minimum = 0, Maximum = 1, Value = deviceVolume ?? s.AdhanVolume,
            VerticalAlignment = VerticalAlignment.Center, Margin = new Thickness(6, -6, 6, -6),
        };
        void ShowPercent() => percent.Text = l.Digits($"{Math.Round(slider.Value * 100)}%");
        ShowPercent();
        slider.PropertyChanged += (_, e) =>
        {
            if (e.Property != Slider.ValueProperty) return;
            var v = (float)slider.Value;
            if (deviceVolume is not null) audio.SetDeviceVolume(s.AdhanDevice, v);
            else
            {
                s.AdhanVolume = v;
                audio.SetAppVolume(v);
                s.Save(notify: false);
            }
            ShowPercent();
        };

        var row = new Grid { ColumnDefinitions = new ColumnDefinitions("Auto,*,Auto,Auto"), Margin = new Thickness(8, 0, 8, 4) };
        var low = Ui.Icon("Speaker0Regular", 15);
        Ui.Bind(low, PathIcon.ForegroundProperty, "TextSecondary");
        var high = Ui.Icon("Speaker2Regular", 15);
        Ui.Bind(high, PathIcon.ForegroundProperty, "TextSecondary");
        row.Children.Add(low);
        Grid.SetColumn(slider, 1); row.Children.Add(slider);
        Grid.SetColumn(high, 2); row.Children.Add(high);
        Grid.SetColumn(percent, 3); row.Children.Add(percent);

        var panel = new StackPanel { Spacing = 2, Margin = new Thickness(4, 4, 4, 2) };
        title.Margin = new Thickness(8, 2, 8, 0);
        panel.Children.Add(title);
        panel.Children.Add(row);
        return panel;
    }

    void Item(string icon, string text, Action action, bool danger = false, bool keepOpen = false)
    {
        var grid = new Grid { ColumnDefinitions = new ColumnDefinitions("Auto,*") };
        var pi = Ui.Icon(icon, 16);
        Ui.Bind(pi, PathIcon.ForegroundProperty, danger ? "DangerBrush" : "TextSecondary");
        grid.Children.Add(pi);
        var label = Ui.Text(text, 13);
        label.Margin = new Thickness(12, 0, 0, 0);
        label.TextTrimming = TextTrimming.CharacterEllipsis;
        if (danger) Ui.Bind(label, TextBlock.ForegroundProperty, "DangerBrush");
        Grid.SetColumn(label, 1);
        grid.Children.Add(label);
        var button = new Button { Content = grid };
        button.Classes.Add("row");
        button.Click += (_, _) =>
        {
            if (!keepOpen) Close();
            action();
            if (keepOpen) { _items.Children.Clear(); Build(); }
        };
        _items.Children.Add(button);
    }

    void Separator() => _items.Children.Add(Ui.Divider(new Thickness(8, 4)));

    public void ShowAt(PixelPoint click, PixelRect? icon)
    {
        _click = click;
        _icon = icon;
        Opacity = 0;
        Show();
        Reposition();
        Activate();
        Dispatcher.UIThread.Post(() => { Reposition(); Opacity = 1; }, DispatcherPriority.Loaded);
    }

    void Reposition()
    {
        if (!IsVisible) return;
        Position = TrayPlacement.Place(this, TrayPlacement.PixelSizeOf(this), _click, null, centerOnAnchor: false);
    }
}
