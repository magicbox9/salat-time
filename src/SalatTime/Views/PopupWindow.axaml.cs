using Avalonia;
using Avalonia.Controls;
using Avalonia.Layout;
using Avalonia.Media;
using Avalonia.Threading;
using SalatTime.Core;

namespace SalatTime.Views;

/// <summary>
/// The compact prayer view opened from the tray icon — the Windows version of
/// the Mac menu-bar popover (same content, Windows 11 flyout styling).
/// </summary>
public partial class PopupWindow : Window
{
    readonly AppState _state;
    readonly List<PrayerRow> _rows = new();
    PixelPoint? _click;
    PixelRect? _icon;
    public DateTime LastHidden { get; private set; } = DateTime.MinValue;

    sealed record PrayerRow(Border Highlight, TextBlock Name, TextBlock Adhan, TextBlock Offset, TextBlock Iqama, Button Mode);

    public PopupWindow() : this(new AppState(new AppSettings(), new NullAudio(), new NullNotifier())) { }

    public PopupWindow(AppState state)
    {
        _state = state;
        InitializeComponent();
        AppTheme.Localize(this);
        BuildRows();

        ChooseMosqueButton.Click += (_, _) => App.Instance?.OpenMainWindow("settings:mosque");
        StopButton.Click += (_, _) => _state.StopAdhan();
        OpenAppButton.Click += (_, _) => App.Instance?.OpenMainWindow("prayer");
        QuranButton.Click += (_, _) => App.Instance?.OpenMainWindow("quran");
        AdhkarButton.Click += (_, _) => App.Instance?.OpenMainWindow("adhkar");
        SettingsButton.Click += (_, _) => App.Instance?.OpenMainWindow("settings");

        Deactivated += (_, _) => { if (IsVisible) { LastHidden = DateTime.UtcNow; Hide(); } };
        SizeChanged += (_, _) => { if (IsVisible) Reposition(); };
        Opened += (_, _) => ApplySurface();
        _state.Ticked += OnTick;
        Closed += (_, _) => _state.Ticked -= OnTick;
        Refresh();
    }

    void ApplySurface()
    {
        // Over acrylic/mica the surface is tinted, otherwise solid.
        Surface.Background = ActualTransparencyLevel == WindowTransparencyLevel.None
            ? Ui.Res("SurfaceBrush") : Ui.Res("SurfaceTintBrush");
    }

    void BuildRows()
    {
        var l = Localizer.Shared;
        for (int i = 0; i < 5; i++)
        {
            var grid = new Grid { ColumnDefinitions = new ColumnDefinitions("*,66,34,54,34"), Height = 34 };
            var highlight = new Border { CornerRadius = new CornerRadius(6), IsVisible = false };
            Ui.Bind(highlight, Border.BackgroundProperty, "AccentSoftBrush");
            Grid.SetColumnSpan(highlight, 5);
            grid.Children.Add(highlight);

            var name = Ui.Text(l.PrayerName(i), 13.5, FontWeight.Medium);
            name.Margin = new Thickness(10, 0, 0, 0);
            name.TextTrimming = TextTrimming.CharacterEllipsis;
            grid.Children.Add(name);

            var adhan = Ui.Text("--:--", 15, FontWeight.SemiBold, "digits");
            adhan.FlowDirection = FlowDirection.LeftToRight;
            Grid.SetColumn(adhan, 1);
            grid.Children.Add(adhan);

            var offset = Ui.Text("", 10.5, FontWeight.Medium, "accent digits");
            offset.FlowDirection = FlowDirection.LeftToRight;
            Grid.SetColumn(offset, 2);
            grid.Children.Add(offset);

            var iqama = Ui.Text("—", 12, FontWeight.Normal, "tertiary digits");
            iqama.FlowDirection = FlowDirection.LeftToRight;
            Grid.SetColumn(iqama, 3);
            grid.Children.Add(iqama);

            var index = i;
            var mode = new Button { Width = 30, Height = 30, HorizontalAlignment = HorizontalAlignment.Center };
            mode.Classes.Add("icon");
            mode.Click += (_, _) =>
            {
                var next = _state.Settings.ModeFor(index).Next();
                _state.Settings.SetMode(index, next);
                _state.Settings.Save();
            };
            Grid.SetColumn(mode, 4);
            grid.Children.Add(mode);

            Rows.Children.Add(grid);
            _rows.Add(new PrayerRow(highlight, name, adhan, offset, iqama, mode));
        }
    }

    /// <summary>Update everything that depends on the schedule or settings.</summary>
    public void Refresh()
    {
        var l = Localizer.Shared;
        var s = _state.Settings;
        var info = _state.Info;
        MosqueName.Text = _state.MosqueName;
        var address = info.Localisation;
        if (info.Phone.Length > 0) address += (address.Length > 0 ? " · " : "") + info.Phone;
        MosqueAddress.Text = address;
        MosqueAddress.IsVisible = address.Length > 0;
        Ui.Tip(ChooseMosqueButton, l.T("menu.choose"));

        NextLabel.Text = l.T("label.next_prayer").ToUpper(l.Culture);
        ColPrayer.Text = l.T("col.prayer").ToUpper(l.Culture);
        ColAdhan.Text = l.T("col.adhan").ToUpper(l.Culture);
        ColIqama.Text = l.T("col.iqama").ToUpper(l.Culture);
        PlayingTitle.Text = l.T("win:adhan.playing");
        PlayingHint.Text = l.T("win:tray.double_click_stop");
        StopLabel.Text = l.T("win:stop");

        Ui.Tip(OpenAppButton, "Salat Time");
        Ui.Tip(QuranButton, l.T("feature:quran.tab"));
        Ui.Tip(AdhkarButton, l.T("adhkar.editor.title"));
        Ui.Tip(SettingsButton, l.T("tooltip.settings"));

        var today = _state.Today;
        for (int i = 0; i < 5; i++)
        {
            var row = _rows[i];
            row.Name.Text = l.PrayerName(i);
            row.Adhan.Text = info.HasTimes ? l.Time(today.Adhan[i], s.Use12h) : "--:--";
            var off = today.IqamaOffset(i);
            row.Offset.Text = off is int o && o != 0 ? l.Digits((o > 0 ? "+" : "") + o) : "";
            row.Iqama.Text = today.Iqama[i] is string iq ? l.Time(iq, s.Use12h) : "—";
            ApplyMode(row.Mode, s.ModeFor(i));
        }

        var jumua = info.JumuaTimes is { Count: > 1 } many
            ? string.Join(" · ", many.Select(t => l.Time(t, s.Use12h)))
            : info.Jumua.Length > 0 ? l.Time(info.Jumua, s.Use12h) : "—";
        Jumua.Text = $"{l.T("label.jumua")} · {jumua}";
        Shuruq.Text = $"{l.T("prayer.shuruq")} · {(today.Shuruq.Length > 0 ? l.Time(today.Shuruq, s.Use12h) : "—")}";
        UpdateLive(Clock.Now());
    }

    void ApplyMode(Button button, AdhanMode mode)
    {
        var l = Localizer.Shared;
        var (icon, brush, tip) = mode switch
        {
            AdhanMode.Off => ("AlertOffRegular", "TextTertiary", l.T("win:mode.off")),
            AdhanMode.Notify => ("AlertRegular", "TextSecondary", l.T("win:mode.notify")),
            _ => ("Speaker2Filled", "AccentBrush", l.T("win:mode.adhan")),
        };
        var pi = Ui.Icon(icon, 17);
        Ui.Bind(pi, PathIcon.ForegroundProperty, brush);
        button.Content = pi;
        Ui.Tip(button, tip);
    }

    void OnTick(DateTime now)
    {
        if (IsVisible) UpdateLive(now);
    }

    void UpdateLive(DateTime now)
    {
        var l = Localizer.Shared;
        var s = _state.Settings;
        var info = _state.Info;
        HijriDate.Text = Hijri.Format(now, HijriFormat.Full, info.HijriAdjustment ?? 0);
        GregorianDate.Text = l.GregorianDate(now);

        PlayingBanner.IsVisible = _state.IsAdhanPlaying;

        var next = PrayerClock.Next(info, now);
        if (next is var (index, at, _))
        {
            var day = PrayerDay.For(info, at);
            Countdown.Text = l.Digits(TimeText.Countdown(at - now, alwaysHours: true));
            NextAt.Text = $"{l.PrayerName(index)}  ·  {l.Time(day.Adhan[index], s.Use12h)}";
        }
        else
        {
            Countdown.Text = "--:--:--";
            NextAt.Text = _state.IsRefreshing ? l.T("win:loading") : l.T("win:no_times");
        }

        if (PrayerClock.AdhanWindow(info, now) is var (current, iqama))
        {
            IqamaChip.IsVisible = true;
            IqamaChipText.Text = $"{l.PrayerName(current)} · {l.T("col.iqama")} {l.Ltr(l.Digits(TimeText.Countdown(iqama - now)))}";
        }
        else IqamaChip.IsVisible = false;

        // Emphasize the next prayer's row, like the Mac popover.
        var highlighted = next?.Index ?? -1;
        for (int i = 0; i < 5; i++)
        {
            var row = _rows[i];
            var isNext = i == highlighted;
            row.Highlight.IsVisible = isNext;
            row.Adhan.FontSize = isNext ? 18 : 15;
            row.Adhan.FontWeight = isNext ? FontWeight.Bold : FontWeight.SemiBold;
            row.Name.Classes.Set("accent", isNext);
            row.Adhan.Classes.Set("accent", isNext);
        }
    }

    // ------------------------------------------------------------------ placement

    public void ShowNear(PixelPoint? click, PixelRect? icon)
    {
        // A click on the tray icon right after the popup lost focus is a "close" click.
        if ((DateTime.UtcNow - LastHidden).TotalMilliseconds < 350) return;
        _click = click;
        _icon = icon;
        Refresh();
        Opacity = 0;
        if (!IsVisible) Show();
        Reposition();
        Activate();
        Dispatcher.UIThread.Post(() => { Reposition(); Opacity = 1; }, DispatcherPriority.Loaded);
    }

    void Reposition()
    {
        var size = TrayPlacement.PixelSizeOf(this);
        Position = TrayPlacement.Place(this, size, _click, _icon);
    }
}
