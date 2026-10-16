using Avalonia;
using Avalonia.Controls;
using Avalonia.Input;
using Avalonia.Layout;
using Avalonia.Media;
using SalatTime.Core;

namespace SalatTime.Views;

/// <summary>
/// Optional always-on-top countdown, the closest Windows equivalent of the Mac
/// menu-bar text: "Dhuhr 13:45 · 42:15", red between the adhan and the iqama.
/// Drag it anywhere; click to open the popup, right-click for the menu.
/// </summary>
public sealed class CountdownPill : Window
{
    readonly AppState _state;
    readonly Border _pill;
    readonly TextBlock _name, _time, _countdown;
    readonly PathIcon _icon;
    PixelPoint _pressScreen;
    bool _dragging;

    public CountdownPill(AppState state)
    {
        _state = state;
        Title = "Salat Time";
        SizeToContent = SizeToContent.Width;
        Height = 52;
        CanResize = false;
        ShowInTaskbar = false;
        Topmost = true;
        SystemDecorations = SystemDecorations.None;
        TransparencyLevelHint = new[] { WindowTransparencyLevel.Transparent };
        Background = Brushes.Transparent;
        WindowStartupLocation = WindowStartupLocation.Manual;

        _icon = Ui.Icon("WeatherMoonFilled", 14);
        _name = Ui.Text("", 12.5, FontWeight.SemiBold);
        _time = Ui.Text("", 12.5, FontWeight.Normal, "secondary digits");
        _countdown = Ui.Text("", 12.5, FontWeight.SemiBold, "digits");
        foreach (var t in new[] { _time, _countdown }) t.FlowDirection = FlowDirection.LeftToRight;
        var row = new StackPanel { Orientation = Orientation.Horizontal, Spacing = 7, VerticalAlignment = VerticalAlignment.Center };
        row.Children.Add(_icon);
        row.Children.Add(_name);
        row.Children.Add(_time);
        row.Children.Add(_countdown);
        _pill = new Border
        {
            Child = row,
            Padding = new Thickness(14, 0),
            Height = 34,
            CornerRadius = new CornerRadius(17),
            BorderThickness = new Thickness(1),
            Margin = new Thickness(8, 9),
            VerticalAlignment = VerticalAlignment.Center,
            BoxShadow = BoxShadows.Parse("0 2 10 0 #40000000"),
        };
        Content = _pill;
        AppTheme.Localize(this);

        PointerPressed += OnPressed;
        PointerMoved += OnMoved;
        PointerReleased += OnReleased;
        Opened += (_, _) => PlaceInitially();
        _state.Ticked += Update;
        Closed += (_, _) => _state.Ticked -= Update;
        Update(Clock.Now());
    }

    public void Relocalize()
    {
        AppTheme.Localize(this);
        Update(Clock.Now());
    }

    void Update(DateTime now)
    {
        var l = Localizer.Shared;
        var s = _state.Settings;
        var info = _state.Info;
        var red = false;
        if (PrayerClock.AdhanWindow(info, now) is var (current, iqama))
        {
            red = true;
            _name.Text = l.PrayerName(current);
            _time.Text = l.T("col.iqama");
            _countdown.Text = l.Digits(TimeText.Countdown(iqama - now));
        }
        else if (PrayerClock.Next(info, now) is var (next, at, _))
        {
            _name.Text = l.PrayerName(next);
            _time.Text = l.Time(PrayerDay.For(info, at).Adhan[next], s.Use12h);
            _countdown.Text = l.Digits(TimeText.Countdown(at - now));
        }
        else
        {
            _name.Text = "Salat Time";
            _time.Text = _countdown.Text = "";
        }
        _pill.Background = red ? new SolidColorBrush(Color.FromRgb(196, 43, 28)) : Ui.Res("SurfaceBrush");
        _pill.BorderBrush = red ? Brushes.Transparent : Ui.Res("CardBorderBrush");
        var fg = red ? Brushes.White : Ui.Res("TextPrimary");
        _name.Foreground = fg;
        _countdown.Foreground = red ? Brushes.White : Ui.Res("AccentBrush");
        _time.Foreground = red ? new SolidColorBrush(Color.FromArgb(220, 255, 255, 255)) : Ui.Res("TextSecondary");
        _icon.Foreground = red ? Brushes.White : Ui.Res("AccentBrush");
    }

    void PlaceInitially()
    {
        var s = _state.Settings;
        if (s.CountdownPillX is double x && s.CountdownPillY is double y)
        {
            var p = new PixelPoint((int)x, (int)y);
            if (Screens.ScreenFromPoint(p) is not null) { Position = p; return; }
        }
        var screen = Screens.Primary ?? Screens.All.FirstOrDefault();
        if (screen is null) return;
        var size = TrayPlacement.PixelSizeOf(this);
        var wa = screen.WorkingArea;
        Position = new PixelPoint(wa.Right - size.Width - (int)(16 * screen.Scaling), wa.Bottom - size.Height - (int)(16 * screen.Scaling));
    }

    void OnPressed(object? sender, PointerPressedEventArgs e)
    {
        var point = e.GetCurrentPoint(this);
        _pressScreen = this.PointToScreen(e.GetPosition(this));
        _dragging = false;
        if (point.Properties.IsRightButtonPressed)
        {
            App.Instance?.ShowTrayMenu(_pressScreen);
            e.Handled = true;
        }
    }

    void OnMoved(object? sender, PointerEventArgs e)
    {
        if (!e.GetCurrentPoint(this).Properties.IsLeftButtonPressed || _dragging) return;
        var now = this.PointToScreen(e.GetPosition(this));
        if (Math.Abs(now.X - _pressScreen.X) + Math.Abs(now.Y - _pressScreen.Y) < 6) return;
        _dragging = true;
        BeginMoveDrag(new PointerPressedEventArgs(this, e.Pointer, this, e.GetPosition(this), e.Timestamp,
            e.GetCurrentPoint(this).Properties, e.KeyModifiers));
        _state.Settings.CountdownPillX = Position.X;
        _state.Settings.CountdownPillY = Position.Y;
        _state.Settings.Save(notify: false);
    }

    void OnReleased(object? sender, PointerReleasedEventArgs e)
    {
        if (e.InitialPressMouseButton == MouseButton.Left && !_dragging)
            App.Instance?.TogglePopup(_pressScreen);
        _dragging = false;
    }
}
