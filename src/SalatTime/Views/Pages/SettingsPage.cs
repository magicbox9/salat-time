using Avalonia;
using Avalonia.Controls;
using Avalonia.Controls.Primitives;
using Avalonia.Input;
using Avalonia.Layout;
using Avalonia.Media;
using Avalonia.Threading;
using SalatTime.Core;

namespace SalatTime.Views.Pages;

/// <summary>
/// One Settings surface, like the Mac app, in five sections: General, Mosque,
/// Tray, Adhan and Adhkar. Rows follow the Windows 11 Settings layout.
/// </summary>
public sealed class SettingsPage : IPage
{
    readonly AppState _state;
    readonly ScrollViewer _scroll = new() { HorizontalScrollBarVisibility = ScrollBarVisibility.Disabled };
    CancellationTokenSource? _search;
    string _query = "";
    List<MosqueRef> _results = new();
    string _searchStatus = "";

    public SettingsPage(AppState state) => _state = state;

    static Localizer L => Localizer.Shared;
    AppSettings S => _state.Settings;

    public string Key => "settings";
    public string Title => L.T("settings.title");
    public string Subtitle => Mode switch
    {
        1 => L.T("settings.mosque.currently") + " · " + _state.MosqueName,
        2 => L.T("win:tray.help"),
        3 => L.T("feature:settings.prayer_modes.help"),
        4 => L.T("settings.adhkar.auto"),
        _ => L.T("win:settings.general.help"),
    };
    public IReadOnlyList<string> Modes => new[]
    {
        L.T("feature:settings.general"), L.T("settings.section.mosque"), L.T("win:tray"),
        L.T("settings.section.adhan"), L.T("settings.section.adhkar"),
    };
    public int Mode { get; set; }
    public Control View => _scroll;

    public void Open(string? detail)
    {
        Mode = detail switch { "mosque" => 1, "tray" => 2, "adhan" => 3, "adhkar" => 4, "general" => 0, _ => Mode };
    }

    public void Refresh()
    {
        var offset = _scroll.Offset;
        _scroll.Content = Mode switch
        {
            1 => MosqueSection(),
            2 => TraySection(),
            3 => AdhanSection(),
            4 => AdhkarSection(),
            _ => GeneralSection(),
        };
        _scroll.Offset = offset;
    }

    public void Tick(DateTime now) { }

    void Save()
    {
        S.Save();
    }

    // ================================================================== layout helpers

    static StackPanel Page() => new() { Spacing = 4, Margin = new Thickness(32, 6, 32, 32), MaxWidth = 980, HorizontalAlignment = HorizontalAlignment.Stretch };

    static Control Header(string text) =>
        new TextBlock { Text = text, FontSize = 14, FontWeight = FontWeight.SemiBold, Margin = new Thickness(2, 18, 0, 6) };

    /// <summary>A Windows 11 style settings card: icon, title, description, control at the end.</summary>
    static Control Row(string icon, string title, string? description, Control? control, Control? below = null)
    {
        var grid = new Grid { ColumnDefinitions = new ColumnDefinitions("Auto,*,Auto"), MinHeight = 44 };
        var pi = Ui.Icon(icon, 20);
        Ui.Bind(pi, PathIcon.ForegroundProperty, "TextSecondary");
        pi.Margin = new Thickness(0, 0, 16, 0);
        grid.Children.Add(pi);
        var texts = new StackPanel { VerticalAlignment = VerticalAlignment.Center, Spacing = 1 };
        texts.Children.Add(Ui.Text(title, 14));
        if (!string.IsNullOrEmpty(description))
        {
            var d = Ui.Text(description, 12, FontWeight.Normal, "secondary");
            d.TextWrapping = TextWrapping.Wrap;
            texts.Children.Add(d);
        }
        Grid.SetColumn(texts, 1);
        grid.Children.Add(texts);
        if (control is not null)
        {
            control.VerticalAlignment = VerticalAlignment.Center;
            control.Margin = new Thickness(16, 0, 0, 0);
            Grid.SetColumn(control, 2);
            grid.Children.Add(control);
        }
        Control content = grid;
        if (below is not null)
        {
            var stack = new StackPanel { Spacing = 12 };
            stack.Children.Add(grid);
            stack.Children.Add(below);
            content = stack;
        }
        var card = Ui.Card(content, new Thickness(18, 12));
        card.Margin = new Thickness(0, 0, 0, 4);
        return card;
    }

    static ToggleSwitch Toggle(bool value, Action<bool> changed)
    {
        var t = new ToggleSwitch { IsChecked = value, OnContent = "", OffContent = "", MinWidth = 0 };
        t.IsCheckedChanged += (_, _) => changed(t.IsChecked == true);
        return t;
    }

    static ComboBox Combo<T>(IEnumerable<(T Value, string Label)> items, T selected, Action<T> changed, double width = 240)
    {
        var list = items.ToList();
        var combo = new ComboBox { Width = width, ItemsSource = list.Select(i => i.Label).ToList() };
        combo.SelectedIndex = Math.Max(0, list.FindIndex(i => EqualityComparer<T>.Default.Equals(i.Value, selected)));
        combo.SelectionChanged += (_, _) =>
        {
            if (combo.SelectedIndex >= 0 && combo.SelectedIndex < list.Count) changed(list[combo.SelectedIndex].Value);
        };
        return combo;
    }

    Control Segmented(string[] labels, int selected, Action<int> picked)
    {
        var bar = new StackPanel { Orientation = Orientation.Horizontal, Spacing = 2 };
        var host = new Border { Child = bar, Padding = new Thickness(3), CornerRadius = new CornerRadius(8) };
        Ui.Bind(host, Border.BackgroundProperty, "CardBrush");
        for (int i = 0; i < labels.Length; i++)
        {
            var index = i;
            var b = new Button { Content = Ui.Text(labels[i], 12.5, i == selected ? FontWeight.SemiBold : FontWeight.Normal), Padding = new Thickness(12, 5), CornerRadius = new CornerRadius(6) };
            b.Classes.Add("row");
            if (i == selected) Ui.Bind(b, Button.BackgroundProperty, "RaisedCardBrush");
            b.Click += (_, _) => picked(index);
            bar.Children.Add(b);
        }
        return host;
    }

    // ================================================================== General

    Control GeneralSection()
    {
        var page = Page();
        page.Children.Add(Header(L.T("settings.section.language") + " · " + L.T("settings.section.appearance")));

        page.Children.Add(Row("LocalLanguageRegular", L.T("settings.section.language"), null,
            Combo(Localizer.Languages.Select(x => (x.Code, x.Native)), S.Language, code => { S.Language = code; Save(); })));

        page.Children.Add(Row("PaintBrushRegular", L.T("settings.section.appearance"), null,
            Segmented(new[] { L.T("settings.appearance.system"), L.T("settings.appearance.light"), L.T("settings.appearance.dark") },
                S.Appearance switch { "light" => 1, "dark" => 2, _ => 0 },
                i => { S.Appearance = i switch { 1 => "light", 2 => "dark", _ => "system" }; Save(); Refresh(); })));

        var swatches = new StackPanel { Orientation = Orientation.Horizontal, Spacing = 8 };
        foreach (var key in AppTheme.AccentOrder)
        {
            var (light, dark) = AppTheme.Pair(key);
            var selected = key == S.Accent;
            var dot = new Border
            {
                Width = 26, Height = 26, CornerRadius = new CornerRadius(13),
                Background = new SolidColorBrush(AppTheme.IsDark ? dark : light),
                BorderThickness = new Thickness(selected ? 3 : 0),
            };
            Ui.Bind(dot, Border.BorderBrushProperty, "TextPrimary");
            var b = new Button { Content = dot, Padding = new Thickness(2), Background = Brushes.Transparent, CornerRadius = new CornerRadius(16) };
            Ui.Tip(b, L.T($"menu.theme.accent.{key}"));
            var k = key;
            b.Click += (_, _) => { S.Accent = k; Save(); Refresh(); };
            swatches.Children.Add(b);
        }
        page.Children.Add(Row("SparkleRegular", L.T("settings.section.accent"), null, swatches));

        page.Children.Add(Header(L.T("settings.section.time_format")));
        page.Children.Add(Row("ClockRegular", L.T("settings.section.time_format"), L.Time("18:45", S.Use12h),
            Segmented(new[] { L.T("settings.time_format.24h"), L.T("settings.time_format.12h") }, S.Use12h ? 1 : 0,
                i => { S.TimeFormat = i == 1 ? "12h" : "24h"; Save(); Refresh(); })));
        if (S.Language == "ar")
        {
            page.Children.Add(Row("TextBulletListSquareRegular", L.T("feature:settings.numerals"), null,
                Segmented(new[] { L.T("feature:settings.numerals.western") + " 123", L.T("feature:settings.numerals.indic") + " ١٢٣" },
                    S.ArabicDigits == "arabicIndic" ? 1 : 0,
                    i => { S.ArabicDigits = i == 1 ? "arabicIndic" : "western"; Save(); Refresh(); })));
        }

        page.Children.Add(Header(L.T("settings.section.startup")));
        page.Children.Add(Row("PowerRegular", L.T("settings.startup.open_at_login"), L.T("win:startup.help"),
            Toggle(S.OpenAtLogin, v => { S.OpenAtLogin = v; Save(); })));

        page.Children.Add(Header(L.T("win:about")));
        var version = typeof(App).Assembly.GetName().Version?.ToString(3) ?? "1.0.0";
        page.Children.Add(Row("InfoRegular", $"Salat Time {version}", L.T("win:about.detail"), null));
        return page;
    }

    // ================================================================== Mosque

    Control MosqueSection()
    {
        var page = Page();
        var info = _state.Info;

        // Current mosque.
        var current = new StackPanel { Spacing = 4 };
        current.Children.Add(Ui.Text(L.T("settings.mosque.currently").ToUpper(L.Culture), 11, FontWeight.SemiBold, "tertiary"));
        current.Children.Add(Ui.Text(_state.MosqueName, 18, FontWeight.SemiBold));
        if (info.Localisation.Length > 0) current.Children.Add(Ui.Text(info.Localisation, 13, FontWeight.Normal, "secondary"));
        var status = _state.IsRefreshing ? L.T("win:loading")
            : _state.LastError is not null ? L.T("win:refresh_failed")
            : _state.LastRefresh is DateTime when ? L.F("win:updated", L.Time(when.ToString("HH:mm"), S.Use12h))
            : info.Date.Length > 0 ? L.F("win:updated", info.Date) : "";
        if (status.Length > 0) current.Children.Add(Ui.Text(status, 12, FontWeight.Normal, _state.LastError is null ? "tertiary" : "secondary"));
        var actions = new WrapPanel { Margin = new Thickness(0, 10, 0, 0) };
        var refresh = ActionButton("ArrowSyncRegular", L.T("menu.refresh"), async () => { await _state.RefreshAsync(); Refresh(); });
        actions.Children.Add(refresh);
        actions.Children.Add(ActionButton("OpenRegular", L.T("win:open_in_browser"), () => OpenUrl(MosqueUrls.Desktop(S.MosqueUrl))));
        var isFav = S.IsFavorite(S.MosqueUrl);
        actions.Children.Add(ActionButton(isFav ? "StarFilled" : "StarRegular", L.T(isFav ? "win:favorite.remove" : "win:favorite.add"), () =>
        {
            S.ToggleFavorite(new MosqueRef { Name = _state.MosqueName, City = info.Localisation, Url = S.MosqueUrl });
            Refresh();
        }));
        current.Children.Add(actions);
        page.Children.Add(Ui.Card(current, new Thickness(20, 16)));

        // Search.
        page.Children.Add(Header(L.T("settings.mosque.change")));
        var box = new TextBox { Watermark = L.T("win:search.placeholder"), Text = _query, Height = 36, VerticalContentAlignment = VerticalAlignment.Center };
        box.InnerLeftContent = new Border { Child = Ui.Icon("SearchRegular", 16, Ui.Res("TextSecondary")), Margin = new Thickness(10, 0, 4, 0) };
        var results = new StackPanel { Spacing = 2 };
        var statusText = Ui.Text(_searchStatus, 12, FontWeight.Normal, "secondary");
        void RenderResults()
        {
            results.Children.Clear();
            statusText.Text = _searchStatus;
            foreach (var r in _results.Take(40)) results.Children.Add(MosqueRow(r));
        }
        box.TextChanged += (_, _) =>
        {
            _query = box.Text ?? "";
            _search?.Cancel();
            var cts = _search = new CancellationTokenSource();
            if (_query.Trim().Length < 2) { _results.Clear(); _searchStatus = ""; RenderResults(); return; }
            _searchStatus = L.T("win:search.searching");
            statusText.Text = _searchStatus;
            DispatcherTimer.RunOnce(async () =>
            {
                if (cts.IsCancellationRequested) return;
                var found = await MawaqitClient.SearchAsync(_query, cts.Token);
                if (cts.IsCancellationRequested) return;
                _results = found;
                _searchStatus = found.Count == 0 ? L.T("win:search.none") : L.F("win:search.count", found.Count);
                RenderResults();
            }, TimeSpan.FromMilliseconds(450));
        };
        var searchCard = new StackPanel { Spacing = 10 };
        searchCard.Children.Add(box);
        searchCard.Children.Add(statusText);
        searchCard.Children.Add(results);
        page.Children.Add(Ui.Card(searchCard, new Thickness(16, 14)));
        RenderResults();

        // Paste a link.
        var url = new TextBox { Watermark = "https://mawaqit.net/fr/…", Height = 34, VerticalContentAlignment = VerticalAlignment.Center };
        var use = new Button { Content = L.T("win:use"), Padding = new Thickness(16, 6), Margin = new Thickness(8, 0, 0, 0) };
        use.Classes.Add("accent");
        var urlRow = new Grid { ColumnDefinitions = new ColumnDefinitions("*,Auto") };
        urlRow.Children.Add(url);
        Grid.SetColumn(use, 1);
        urlRow.Children.Add(use);
        var urlStatus = Ui.Text("", 12, FontWeight.Normal, "secondary");
        use.Click += async (_, _) =>
        {
            var text = (url.Text ?? "").Trim();
            if (!MosqueUrls.IsValid(text)) { urlStatus.Text = L.T("win:paste.invalid"); return; }
            urlStatus.Text = L.T("win:loading");
            var ok = await _state.SelectMosqueAsync(text);
            urlStatus.Text = ok ? "" : L.T("win:refresh_failed");
            if (ok) Refresh();
        };
        page.Children.Add(Row("OpenRegular", L.T("win:paste_url"), L.T("win:paste_url.help"), null,
            new StackPanel { Spacing = 6, Children = { urlRow, urlStatus } }));

        // Favorites.
        page.Children.Add(Header(L.T("menu.favorites")));
        if (S.Favorites.Count == 0)
            page.Children.Add(Ui.Card(Ui.Text(L.T("picker:favorites.empty"), 13, FontWeight.Normal, "secondary"), new Thickness(18, 14)));
        else
        {
            var favs = new StackPanel { Spacing = 2 };
            foreach (var f in S.Favorites) favs.Children.Add(MosqueRow(f));
            page.Children.Add(Ui.Card(favs, new Thickness(8)));
        }
        return page;
    }

    Control MosqueRow(MosqueRef mosque)
    {
        var isCurrent = MosqueUrls.Normalize(mosque.Url) == MosqueUrls.Normalize(S.MosqueUrl);
        var grid = new Grid { ColumnDefinitions = new ColumnDefinitions("Auto,*,Auto,Auto") };
        var icon = Ui.Icon(isCurrent ? "CheckmarkRegular" : "LocationRegular", 18);
        Ui.Bind(icon, PathIcon.ForegroundProperty, isCurrent ? "AccentBrush" : "TextSecondary");
        grid.Children.Add(icon);
        var texts = new StackPanel { Margin = new Thickness(12, 0), Spacing = 1, VerticalAlignment = VerticalAlignment.Center };
        var name = Ui.Text(mosque.Name, 13.5, FontWeight.SemiBold);
        name.TextTrimming = TextTrimming.CharacterEllipsis;
        texts.Children.Add(name);
        if (mosque.Subtitle.Length > 0)
        {
            var sub = Ui.Text(mosque.Subtitle, 12, FontWeight.Normal, "secondary");
            sub.TextTrimming = TextTrimming.CharacterEllipsis;
            texts.Children.Add(sub);
        }
        Grid.SetColumn(texts, 1);
        grid.Children.Add(texts);
        var fav = S.IsFavorite(mosque.Url);
        var star = Ui.IconButton(fav ? "StarFilled" : "StarRegular", L.T(fav ? "win:favorite.remove" : "win:favorite.add"), () => { S.ToggleFavorite(mosque); Refresh(); }, 32, 16);
        Grid.SetColumn(star, 2);
        grid.Children.Add(star);
        var use = new Button { Content = L.T(isCurrent ? "win:current" : "win:use"), Padding = new Thickness(14, 5), IsEnabled = !isCurrent, Margin = new Thickness(6, 0, 0, 0) };
        if (!isCurrent) use.Classes.Add("accent");
        use.Click += async (_, _) =>
        {
            use.IsEnabled = false;
            use.Content = L.T("win:loading");
            var ok = await _state.SelectMosqueAsync(mosque.Url);
            if (!ok) { use.Content = L.T("win:refresh_failed"); use.IsEnabled = true; return; }
            Refresh();
        };
        Grid.SetColumn(use, 3);
        grid.Children.Add(use);
        return new Border { Child = grid, Padding = new Thickness(10, 8), CornerRadius = new CornerRadius(6) };
    }

    static Button ActionButton(string icon, string text, Action onClick)
    {
        var row = new StackPanel { Orientation = Orientation.Horizontal, Spacing = 8 };
        row.Children.Add(Ui.Icon(icon, 15));
        row.Children.Add(Ui.Text(text, 13));
        var b = new Button { Content = row, Padding = new Thickness(12, 6), Margin = new Thickness(0, 0, 8, 6) };
        b.Click += (_, _) => onClick();
        return b;
    }

    static Button ActionButton(string icon, string text, Func<Task> onClick)
    {
        var b = ActionButton(icon, text, () => { });
        b.Click += async (_, _) => { b.IsEnabled = false; try { await onClick(); } finally { b.IsEnabled = true; } };
        return b;
    }

    internal static void OpenUrl(string url)
    {
        try { System.Diagnostics.Process.Start(new System.Diagnostics.ProcessStartInfo(url) { UseShellExecute = true }); } catch { }
    }

    // ================================================================== Tray

    Control TraySection()
    {
        var page = Page();
        page.Children.Add(Header(L.T("win:tray")));
        page.Children.Add(Row("TimerRegular", L.T("win:tray.countdown_icon"), L.T("win:tray.countdown_icon.help"),
            Toggle(S.TrayCountdownIcon, v => { S.TrayCountdownIcon = v; Save(); })));
        var hijri = new[] { HijriFormat.Off, HijriFormat.Full, HijriFormat.DayMonth, HijriFormat.Month, HijriFormat.Day };
        string HijriLabel(HijriFormat f) => L.T("settings.bar.hijri.format." + (f == HijriFormat.DayMonth ? "daymonth" : f.ToString().ToLowerInvariant()));
        page.Children.Add(Row("CalendarRegular", L.T("win:tray.hijri"), null,
            Combo(hijri.Select(f => (f, HijriLabel(f))), S.TrayHijri, f => { S.TrayHijri = f; Save(); }, 280)));
        page.Children.Add(Row("DesktopRegular", L.T("win:tray.pill"), L.T("win:tray.pill.help"),
            Toggle(S.CountdownPill, v => { S.CountdownPill = v; Save(); })));

        page.Children.Add(Header(L.T("win:tray.clicks")));
        var tips = new StackPanel { Spacing = 8 };
        foreach (var key in new[] { "win:tray.tip.click", "win:tray.tip.double", "win:tray.tip.right", "win:tray.tip.pin" })
        {
            var row = new StackPanel { Orientation = Orientation.Horizontal, Spacing = 10 };
            row.Children.Add(Ui.Icon("CheckmarkRegular", 14, Ui.Res("AccentBrush")));
            var t = Ui.Text(L.T(key), 13);
            t.TextWrapping = TextWrapping.Wrap;
            row.Children.Add(t);
            tips.Children.Add(row);
        }
        page.Children.Add(Ui.Card(tips, new Thickness(18, 14)));
        return page;
    }

    // ================================================================== Adhan

    Control AdhanSection()
    {
        var page = Page();
        page.Children.Add(Header(L.T("settings.section.adhan")));
        page.Children.Add(Row("Speaker2Regular", L.T("settings.adhan.play"), null, Toggle(S.AdhanEnabled, v => { S.AdhanEnabled = v; Save(); })));
        page.Children.Add(Row("AlertRegular", L.T("settings.notif.show"), L.T("win:notifications.help"), Toggle(S.NotificationsEnabled, v => { S.NotificationsEnabled = v; Save(); })));

        // Each prayer: off / notification / adhan.
        var modes = new StackPanel { Spacing = 6 };
        for (int i = 0; i < 5; i++)
        {
            var prayer = i;
            var row = new Grid { ColumnDefinitions = new ColumnDefinitions("*,Auto") };
            row.Children.Add(Ui.Text(L.PrayerName(i), 13.5, FontWeight.Medium));
            var seg = Segmented(new[] { L.T("settings.notif.headsup.off"), L.T("win:mode.notify.short"), L.T("col.adhan") }, (int)S.ModeFor(i),
                m => { S.SetMode(prayer, (AdhanMode)m); Save(); Refresh(); });
            Grid.SetColumn(seg, 1);
            row.Children.Add(seg);
            modes.Children.Add(row);
        }
        page.Children.Add(Row("AlertRegular", L.T("feature:settings.prayer_modes"), L.T("feature:settings.prayer_modes.help"), null, modes));

        page.Children.Add(Header(L.T("settings.adhan.sound")));
        var playing = _state.IsAdhanPlaying;
        var test = new Button { Content = L.T(playing ? "win:stop" : "win:test"), Padding = new Thickness(14, 6), Margin = new Thickness(8, 0, 0, 0) };
        test.Click += (_, _) => { _state.ToggleTestAdhan(); Refresh(); };
        var soundRow = new StackPanel { Orientation = Orientation.Horizontal };
        soundRow.Children.Add(Combo(AdhanCatalog.All.Select(a => (a.Id, a.FileName.Length == 0 ? L.T("win:chime") : a.Name)), S.AdhanSound, id => { S.AdhanSound = id; Save(); }, 300));
        soundRow.Children.Add(test);
        page.Children.Add(Row("MusicNote2Regular", L.T("settings.adhan.sound"), L.T("win:sound.help"), soundRow));
        var fajrItems = new List<(string, string)> { ("", L.T("win:same_as_others")) };
        fajrItems.AddRange(AdhanCatalog.All.Select(a => (a.Id, a.FileName.Length == 0 ? L.T("win:chime") : a.Name)));
        page.Children.Add(Row("WeatherMoonRegular", L.T("win:fajr_sound"), L.T("win:fajr_sound.help"),
            Combo(fajrItems, S.FajrAdhanSound, id => { S.FajrAdhanSound = id; Save(); }, 300)));

        // Output device and its volume.
        var devices = new List<(string, string)> { ("", L.T("settings.adhan.output.default")) };
        devices.AddRange(_state.Audio.OutputDevices().Select(d => (d.Id, d.Name)));
        page.Children.Add(Row("Speaker2Regular", L.T("settings.adhan.output"), L.T("win:output.help"),
            Combo(devices, S.AdhanDevice, id => { S.AdhanDevice = id; Save(); Refresh(); }, 300)));
        var deviceVolume = _state.Audio.DeviceVolume(S.AdhanDevice);
        var slider = new Slider { Minimum = 0, Maximum = 1, Value = deviceVolume ?? S.AdhanVolume, Width = 260 };
        var percent = Ui.Text(L.Digits($"{Math.Round(slider.Value * 100)}%"), 13, FontWeight.Normal, "secondary digits");
        percent.MinWidth = 44;
        percent.TextAlignment = TextAlignment.Right;
        slider.PropertyChanged += (_, e) =>
        {
            if (e.Property != Slider.ValueProperty) return;
            if (deviceVolume is not null) _state.Audio.SetDeviceVolume(S.AdhanDevice, (float)slider.Value);
            else { S.AdhanVolume = slider.Value; _state.Audio.SetAppVolume(slider.Value); S.Save(notify: false); }
            percent.Text = L.Digits($"{Math.Round(slider.Value * 100)}%");
        };
        var volume = new StackPanel { Orientation = Orientation.Horizontal, Spacing = 8 };
        volume.Children.Add(slider);
        volume.Children.Add(percent);
        var deviceName = _state.Audio.ResolveDevice(S.AdhanDevice)?.Name;
        page.Children.Add(Row("Speaker0Regular", L.T("menu.adhan_volume") + (deviceName is null ? "" : " · " + deviceName),
            L.T(deviceVolume is null ? "win:volume.app_help" : "win:volume.device_help"), volume));

        page.Children.Add(Header(L.T("settings.section.notifications")));
        var leads = AppSettingsExtras.LeadOptions.Select(m => (m, m == 0 ? L.T("settings.notif.headsup.off") : L.F("settings.notif.headsup.minutes", m)));
        page.Children.Add(Row("TimerRegular", L.T("settings.notif.headsup"), L.T("win:headsup.help"),
            Combo(leads, S.PreAdhanLeadMinutes, m => { S.PreAdhanLeadMinutes = m; Save(); }, 200)));
        var travel = AppSettingsExtras.TravelOptions.Select(m => (m, m == 0 ? L.T("living:off") : L.F("living:min", m)));
        page.Children.Add(Row("PersonWalkingRegular", L.T("living:travel.time"), L.T("win:travel.help"),
            Combo(travel, S.TravelMinutes, m => { S.TravelMinutes = m; Save(); }, 200)));
        return page;
    }

    // ================================================================== Adhkar

    Control AdhkarSection()
    {
        var page = Page();
        page.Children.Add(Header(L.T("settings.section.adhkar")));
        page.Children.Add(Row("BookRegular", L.T("settings.adhkar.auto"), L.T("win:adhkar.auto.help"),
            Toggle(S.AdhkarEnabled, v => { S.AdhkarEnabled = v; Save(); })));
        page.Children.Add(Row("WeatherSunnyLowRegular", L.T("win:adhkar.morning"), null,
            Combo(new[] { ("shuruq", L.T("prayer.shuruq")), ("fajr", L.PrayerName(0)) }, S.AdhkarMorningAnchor, v => { S.AdhkarMorningAnchor = v; Save(); }, 200)));
        page.Children.Add(Row("WeatherMoonRegular", L.T("win:adhkar.evening"), null,
            Combo(new[] { ("asr", L.PrayerName(2)), ("maghrib", L.PrayerName(3)) }, S.AdhkarEveningAnchor, v => { S.AdhkarEveningAnchor = v; Save(); }, 200)));
        return page;
    }
}

public static class AppSettingsExtras
{
    public static readonly int[] LeadOptions = { 0, 5, 10, 15, 20, 30, 45, 60 };
    public static readonly int[] TravelOptions = { 0, 5, 10, 15, 20, 30, 45 };
}
