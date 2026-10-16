using Avalonia;
using Avalonia.Controls;
using Avalonia.Controls.Primitives;
using Avalonia.Layout;
using Avalonia.Media;
using SalatTime.Controls;
using SalatTime.Core;

namespace SalatTime.Views.Pages;

/// <summary>
/// Prayer times: Overview (living sky, the five prayers, Sunnah guidance and
/// day landmarks), Timetable (7 days, Hijri or Gregorian month), Day path and
/// the 24-hour dial — the same four views as the Mac app.
/// </summary>
public sealed class PrayerPage : IPage
{
    readonly AppState _state;
    readonly ScrollViewer _scroll = new() { HorizontalScrollBarVisibility = ScrollBarVisibility.Disabled };
    readonly List<Action<DateTime>> _live = new();
    int _monthOffset;
    string _builtFor = "";

    public PrayerPage(AppState state)
    {
        _state = state;
        Mode = Math.Clamp(state.Settings.PrayerView, 0, 3);
    }

    static Localizer L => Localizer.Shared;
    AppSettings S => _state.Settings;

    public string Key => "prayer";
    public string Title => L.T("main.tab.prayer_times");
    public IReadOnlyList<string> Modes => new[] { L.T("feature:full.view.overview"), L.T("view:view.timetable"), L.T("view:view.daypath"), L.T("view:view.dial") };
    public int Mode { get; set; }
    public Control View => _scroll;

    public string Subtitle
    {
        get
        {
            var now = Clock.Now();
            var parts = new List<string> { _state.MosqueName };
            if (PrayerClock.Next(_state.Info, now) is var (i, at, _))
                parts.Add($"{L.T("feature:full.next_prayer")} {L.PrayerName(i)} {L.Time(PrayerDay.For(_state.Info, at).Adhan[i], S.Use12h)} · {L.Digits(TimeText.Countdown(at - now, true))}");
            return string.Join("  ·  ", parts);
        }
    }

    public void Refresh()
    {
        if (S.PrayerView != Mode) { S.PrayerView = Mode; S.Save(notify: false); }
        _live.Clear();
        _builtFor = Clock.Now().ToString("yyyy-MM-dd");
        if (!_state.Info.HasTimes)
        {
            _scroll.Content = Empty();
            return;
        }
        _scroll.Content = Mode switch
        {
            1 => Timetable(),
            2 => DayPath(),
            3 => Dial(),
            _ => Overview(),
        };
        Tick(Clock.Now());
    }

    public void Tick(DateTime now)
    {
        if (now.ToString("yyyy-MM-dd") != _builtFor) { Refresh(); return; }
        foreach (var update in _live) update(now);
    }

    Control Empty()
    {
        var panel = new StackPanel { Spacing = 12, Margin = new Thickness(32, 40), HorizontalAlignment = HorizontalAlignment.Center };
        panel.Children.Add(Ui.Icon("WeatherMoonRegular", 40, Ui.Res("TextTertiary")));
        panel.Children.Add(Ui.Text(_state.IsRefreshing ? L.T("win:loading") : L.T("win:no_times"), 15, FontWeight.Medium, "secondary"));
        var choose = new Button { Content = L.T("menu.choose"), HorizontalAlignment = HorizontalAlignment.Center, Padding = new Thickness(16, 7) };
        choose.Classes.Add("accent");
        choose.Click += (_, _) => App.Instance?.OpenMainWindow("settings:mosque");
        panel.Children.Add(choose);
        return panel;
    }

    // ================================================================== Overview

    Control Overview()
    {
        var root = new StackPanel { Spacing = 16, Margin = new Thickness(32, 6, 32, 32) };
        root.Children.Add(Hero());
        root.Children.Add(PrayerCards());

        var lower = new Grid { ColumnDefinitions = new ColumnDefinitions("3*,16,2*") };
        lower.Children.Add(SunnahCard());
        var landmarks = LandmarksCard();
        Grid.SetColumn(landmarks, 2);
        lower.Children.Add(landmarks);
        root.Children.Add(lower);
        return root;
    }

    Control Hero()
    {
        var grid = new Grid { MinHeight = 248 };
        grid.Children.Add(new SkyHero { State = _state });

        var white = new SolidColorBrush(Colors.White);
        var soft = new SolidColorBrush(Color.FromArgb(205, 255, 255, 255));
        var info = new StackPanel { Margin = new Thickness(28, 22, 0, 18), VerticalAlignment = VerticalAlignment.Center, Spacing = 2, HorizontalAlignment = HorizontalAlignment.Left };
        var over = Ui.Text(L.T("label.next_prayer").ToUpper(L.Culture), 11.5, FontWeight.SemiBold);
        over.Foreground = soft;
        var name = Ui.Text("", 24, FontWeight.SemiBold);
        name.Foreground = white;
        var countdown = Ui.Text("", 56, FontWeight.Bold, "digits");
        countdown.Foreground = white;
        countdown.FlowDirection = FlowDirection.LeftToRight;
        countdown.HorizontalAlignment = HorizontalAlignment.Left;
        countdown.Margin = new Thickness(0, -6, 0, -4);
        var at = Ui.Text("", 14);
        at.Foreground = soft;
        var chips = new WrapPanel { Margin = new Thickness(0, 12, 0, 0) };
        info.MaxWidth = 560;
        info.Children.Add(over);
        info.Children.Add(name);
        info.Children.Add(countdown);
        info.Children.Add(at);
        info.Children.Add(chips);
        grid.Children.Add(info);

        var lastChips = "";
        _live.Add(now =>
        {
            var day = _state.Today;
            if (PrayerClock.Next(_state.Info, now) is var (i, when, _))
            {
                var d = PrayerDay.For(_state.Info, when);
                name.Text = L.PrayerName(i);
                countdown.Text = L.Digits(TimeText.Countdown(when - now, true));
                var line = L.Time(d.Adhan[i], S.Use12h);
                if (d.Iqama[i] is string iq) line += $"  ·  {L.T("col.iqama")} {L.Time(iq, S.Use12h)}";
                at.Text = line;
            }

            var items = new List<(string Icon, string Text, bool Alert)>();
            if (PrayerClock.AdhanWindow(_state.Info, now) is var (cur, iqama))
                items.Add(("TimerRegular", $"{L.PrayerName(cur)} · {L.T("col.iqama")} {L.Ltr(L.Digits(TimeText.Countdown(iqama - now)))}", true));
            else if (S.TravelMinutes > 0 && PrayerClock.Next(_state.Info, now) is var (ni, nat, _)
                     && PrayerDay.For(_state.Info, nat) is var nd && nd.IqamaAt(ni) is DateTime iqAt)
                items.Add(("PersonWalkingRegular", L.F("living:leave.by", L.Time(TimeText.Clock(DayModel.MinuteOf(iqAt.AddMinutes(-S.TravelMinutes))), S.Use12h)), false));
            items.Add(("CalendarRegular", Hijri.Format(now, HijriFormat.Full, _state.Info.HijriAdjustment ?? 0), false));
            var phase = MoonPhase.At(now);
            items.Add(("WeatherMoonRegular", $"{Sunnah.MoonName(phase)} · {L.F("living:moon.lit", (int)Math.Round(phase.Illumination * 100))}", false));
            if (_state.Info.Latitude is double lat && _state.Info.Longitude is double lon)
            {
                var b = Qibla.Bearing(lat, lon);
                items.Add(("CompassNorthwestRegular", $"{L.T("view:qibla")} {L.Ltr(L.Digits($"{Math.Round(b)}°"))} {L.T($"view:dir.{(int)Math.Round(b / 45) % 8}")}", false));
            }
            var key = string.Join("|", items.Select(x => x.Text));
            if (key == lastChips) return;
            lastChips = key;
            chips.Children.Clear();
            foreach (var (icon, text, alert) in items) chips.Children.Add(HeroChip(icon, text, alert));
        });
        return grid;
    }

    static Control HeroChip(string icon, string text, bool alert)
    {
        var row = new StackPanel { Orientation = Orientation.Horizontal, Spacing = 6 };
        row.Children.Add(Ui.Icon(icon, 13, Brushes.White));
        var t = Ui.Text(text, 12, FontWeight.Medium);
        t.Foreground = Brushes.White;
        row.Children.Add(t);
        return new Border
        {
            Child = row,
            Padding = new Thickness(10, 5),
            Margin = new Thickness(0, 0, 8, 8),
            CornerRadius = new CornerRadius(14),
            Background = alert ? new SolidColorBrush(Color.FromArgb(230, 196, 43, 28)) : new SolidColorBrush(Color.FromArgb(46, 255, 255, 255)),
            BorderBrush = new SolidColorBrush(Color.FromArgb(40, 255, 255, 255)),
            BorderThickness = new Thickness(1),
        };
    }

    Control PrayerCards()
    {
        var grid = new UniformGrid { Columns = 5 };
        var cards = new List<(Border Card, TextBlock Name, TextBlock Time, ProgressBar Bar, TextBlock State)>();
        var day = _state.Today;
        for (int i = 0; i < 5; i++)
        {
            var index = i;
            var stack = new StackPanel { Spacing = 4 };
            var top = new Grid { ColumnDefinitions = new ColumnDefinitions("*,Auto") };
            var name = Ui.Text(L.PrayerName(i), 14, FontWeight.SemiBold);
            top.Children.Add(name);
            var mode = ModeButton(i);
            Grid.SetColumn(mode, 1);
            top.Children.Add(mode);
            stack.Children.Add(top);
            var time = Ui.Text(L.Time(day.Adhan[i], S.Use12h), 26, FontWeight.SemiBold, "digits");
            time.FlowDirection = FlowDirection.LeftToRight;
            time.HorizontalAlignment = HorizontalAlignment.Left;
            stack.Children.Add(time);
            var iqText = day.Iqama[i] is string iq
                ? $"{L.T("col.iqama")} {L.Time(iq, S.Use12h)}" + (day.IqamaOffset(i) is int o && o != 0 ? $"  ·  {L.Ltr(L.Digits((o > 0 ? "+" : "") + o))}" : "")
                : L.T("col.iqama") + " —";
            stack.Children.Add(Ui.Text(iqText, 12, FontWeight.Normal, "secondary"));
            var bar = new ProgressBar { Minimum = 0, Maximum = 1, Height = 4, MinHeight = 4, Margin = new Thickness(0, 8, 0, 0), CornerRadius = new CornerRadius(2) };
            stack.Children.Add(bar);
            var state = Ui.Text("", 11, FontWeight.Medium, "tertiary");
            stack.Children.Add(state);
            var card = Ui.Card(stack, new Thickness(14, 12));
            card.Margin = new Thickness(i == 0 ? 0 : 6, 0, i == 4 ? 0 : 6, 0);
            grid.Children.Add(card);
            cards.Add((card, name, time, bar, state));
        }

        _live.Add(now =>
        {
            var model = DayModel.For(_state.Info, now);
            var next = PrayerClock.Next(_state.Info, now)?.Index ?? -1;
            var minute = now.Hour * 60 + now.Minute + now.Second / 60.0;
            var current = model?.Current((int)minute);
            for (int i = 0; i < 5; i++)
            {
                var (card, name, time, bar, state) = cards[i];
                var isNext = i == next;
                var isCurrent = current?.Index == i && !isNext;
                card.BorderBrush = isNext ? Ui.Res("AccentBrush") : Ui.Res("CardBorderBrush");
                card.BorderThickness = new Thickness(isNext ? 1.5 : 1);
                card.Background = isNext ? Ui.Res("AccentSoftBrush") : Ui.Res("CardBrush");
                name.Classes.Set("accent", isNext);
                time.Classes.Set("accent", isNext);
                if (isCurrent && current is { } c && model is not null)
                {
                    var start = c.Start < 0 ? c.Start + 1440 : c.Start;
                    var m = minute < start && c.Start < 0 ? minute + 1440 : minute;
                    bar.Value = Math.Clamp((m - c.Start) / Math.Max(1, c.End - c.Start), 0, 1);
                    bar.IsVisible = true;
                    state.Text = L.F("view:left", L.Digits(Duration(c.End - (int)minute)));
                }
                else if (isNext && PrayerClock.Next(_state.Info, now) is var (_, at, _))
                {
                    bar.IsVisible = false;
                    var left = at - now;
                    state.Text = L.F("living:in", left.TotalMinutes < 60
                        ? L.F("living:min", (int)Math.Ceiling(left.TotalMinutes))
                        : L.Digits(Duration((int)Math.Ceiling(left.TotalMinutes))));
                }
                else
                {
                    bar.IsVisible = false;
                    state.Text = "";
                }
            }
        });
        return grid;
    }

    Button ModeButton(int prayer)
    {
        var button = new Button { Width = 28, Height = 28 };
        button.Classes.Add("icon");
        void Apply()
        {
            var mode = S.ModeFor(prayer);
            var (icon, brush, tip) = mode switch
            {
                AdhanMode.Off => ("AlertOffRegular", "TextTertiary", L.T("win:mode.off")),
                AdhanMode.Notify => ("AlertRegular", "TextSecondary", L.T("win:mode.notify")),
                _ => ("Speaker2Filled", "AccentBrush", L.T("win:mode.adhan")),
            };
            var pi = Ui.Icon(icon, 16);
            Ui.Bind(pi, PathIcon.ForegroundProperty, brush);
            button.Content = pi;
            Ui.Tip(button, tip);
        }
        Apply();
        button.Click += (_, _) =>
        {
            S.SetMode(prayer, S.ModeFor(prayer).Next());
            S.Save();
            Apply();
        };
        return button;
    }

    static string Duration(int minutes)
    {
        var v = Math.Max(0, minutes);
        return $"{v / 60}:{v % 60:00}";
    }

    Control SunnahCard()
    {
        var stack = new StackPanel { Spacing = 10 };
        stack.Children.Add(Ui.Text(L.T("living:sunnah.now"), 15, FontWeight.SemiBold));
        var nowText = Ui.Text("", 14);
        nowText.TextWrapping = TextWrapping.Wrap;
        stack.Children.Add(nowText);
        var upNext = Ui.Text("", 12.5, FontWeight.Normal, "secondary");
        upNext.TextWrapping = TextWrapping.Wrap;
        stack.Children.Add(upNext);
        var reminders = new StackPanel { Spacing = 6 };
        stack.Children.Add(reminders);
        stack.Children.Add(Ui.Divider(new Thickness(0, 4)));

        // Voluntary prayers with their windows for today.
        var model = DayModel.For(_state.Info, Clock.Now());
        if (model is not null)
        {
            stack.Children.Add(Ui.Text(L.T("feature:full.nawafil"), 13, FontWeight.SemiBold, "secondary"));
            var duha = $"{L.Time(TimeText.Clock(model.Shuruq + 20), S.Use12h)} – {L.Time(TimeText.Clock(model.Times[1] - 10), S.Use12h)}";
            var qiyam = $"{L.Time(TimeText.Clock(model.LastThird), S.Use12h)} – {L.Time(TimeText.Clock(model.NextFajr), S.Use12h)}";
            stack.Children.Add(Nawafil("ClockRegular", L.T("feature:nawafil.rawatib"), L.T("feature:nawafil.rawatib.count"), L.T("feature:nawafil.rawatib.window")));
            stack.Children.Add(Nawafil("WeatherSunnyRegular", L.T("feature:nawafil.duha"), L.T("feature:nawafil.duha.count"), duha + "  ·  " + L.T("feature:nawafil.duha.best")));
            stack.Children.Add(Nawafil("WeatherMoonRegular", L.T("feature:nawafil.qiyam"), L.T("feature:nawafil.qiyam.count"), qiyam + "  ·  " + L.T("feature:nawafil.qiyam.best")));
            stack.Children.Add(Nawafil("StarRegular", L.T("feature:nawafil.witr"), L.T("feature:nawafil.witr.count"), L.T("feature:nawafil.witr.best")));
            var note = Ui.Text(L.T("feature:full.guidance"), 11.5, FontWeight.Normal, "tertiary");
            note.TextWrapping = TextWrapping.Wrap;
            stack.Children.Add(note);
        }

        var last = "";
        _live.Add(now =>
        {
            var m = DayModel.For(_state.Info, now);
            if (m is null) return;
            var minute = now.Hour * 60 + now.Minute;
            var (text, next) = Sunnah.Context(m, minute, now, S.Use12h);
            var key = text + next;
            if (key == last) return;
            last = key;
            nowText.Text = text;
            upNext.Text = next is var (t, at) ? L.F("living:up.next", t, L.Time(TimeText.Clock(at), S.Use12h)) : "";
            reminders.Children.Clear();
            foreach (var (icon, line) in Sunnah.Reminders(m, minute, now, _state.Info.HijriAdjustment ?? 0))
            {
                var row = new StackPanel { Orientation = Orientation.Horizontal, Spacing = 8 };
                row.Children.Add(Ui.Icon(icon, 15, Ui.Res("AccentBrush")));
                var tb = Ui.Text(line, 12.5, FontWeight.Medium, "accent");
                tb.TextWrapping = TextWrapping.Wrap;
                row.Children.Add(tb);
                reminders.Children.Add(row);
            }
        });
        return Ui.Card(stack, new Thickness(18, 16));
    }

    static Control Nawafil(string icon, string title, string count, string detail)
    {
        var grid = new Grid { ColumnDefinitions = new ColumnDefinitions("Auto,*") };
        var pi = Ui.Icon(icon, 16, Ui.Res("AccentBrush"));
        pi.VerticalAlignment = VerticalAlignment.Top;
        pi.Margin = new Thickness(0, 2, 0, 0);
        grid.Children.Add(pi);
        var text = new StackPanel { Margin = new Thickness(10, 0, 0, 0), Spacing = 1 };
        var head = new StackPanel { Orientation = Orientation.Horizontal, Spacing = 8 };
        head.Children.Add(Ui.Text(title, 13, FontWeight.SemiBold));
        head.Children.Add(Ui.Text(count, 12, FontWeight.Normal, "tertiary"));
        text.Children.Add(head);
        var d = Ui.Text(detail, 12, FontWeight.Normal, "secondary");
        d.TextWrapping = TextWrapping.Wrap;
        text.Children.Add(d);
        Grid.SetColumn(text, 1);
        grid.Children.Add(text);
        return grid;
    }

    Control LandmarksCard()
    {
        var stack = new StackPanel { Spacing = 0 };
        stack.Children.Add(new Border { Child = Ui.Text(L.T("feature:full.landmarks"), 15, FontWeight.SemiBold), Margin = new Thickness(0, 0, 0, 8) });
        var model = DayModel.For(_state.Info, Clock.Now());
        if (model is null) return Ui.Card(stack);
        var rows = new List<(string Icon, string Label, string Value)>
        {
            ("WeatherSunnyLowRegular", L.T("feature:full.landmark.sunrise"), L.Time(TimeText.Clock(model.Shuruq), S.Use12h)),
            ("WeatherSunnyHighRegular", L.PrayerName(1), L.Time(TimeText.Clock(model.Times[1]), S.Use12h)),
            ("WeatherPartlyCloudyDayRegular", L.T("feature:full.landmark.sunset"), L.Time(TimeText.Clock(model.Sunset), S.Use12h)),
            ("WeatherSunnyRegular", L.T("view:day.length"), L.Digits(Duration(model.DayLength))),
            ("WeatherMoonRegular", L.T("view:night.length"), L.Digits(Duration(model.NightLength))),
            ("ClockRegular", L.T("view:midnight"), L.Time(TimeText.Clock(model.Midnight), S.Use12h)),
            ("StarRegular", L.T("view:last.third"), L.Time(TimeText.Clock(model.LastThird), S.Use12h)),
            ("HourglassRegular", L.T("view:imsak"), L.Time(TimeText.Clock(model.Imsak), S.Use12h)),
        };
        if (_state.Info.JumuaTimes is { Count: > 0 } jumua)
            rows.Insert(2, ("PeopleRegular", L.T("feature:full.landmark.friday"), string.Join(" · ", jumua.Select(j => L.Time(j, S.Use12h)))));
        foreach (var (icon, label, value) in rows)
        {
            var grid = new Grid { ColumnDefinitions = new ColumnDefinitions("Auto,*,Auto"), Height = 34 };
            grid.Children.Add(Ui.Icon(AppTheme.HasIcon(icon) ? icon : "ClockRegular", 15, Ui.Res("TextSecondary")));
            var l = Ui.Text(label, 13);
            l.Margin = new Thickness(10, 0, 0, 0);
            Grid.SetColumn(l, 1);
            grid.Children.Add(l);
            var v = Ui.Text(value, 13, FontWeight.SemiBold, "digits");
            v.FlowDirection = FlowDirection.LeftToRight;
            Grid.SetColumn(v, 2);
            grid.Children.Add(v);
            stack.Children.Add(grid);
        }
        var note = Ui.Text(L.T("view:forbidden.note"), 11.5, FontWeight.Normal, "tertiary");
        note.TextWrapping = TextWrapping.Wrap;
        note.Margin = new Thickness(0, 8, 0, 0);
        stack.Children.Add(note);
        return Ui.Card(stack, new Thickness(18, 16));
    }

    // ================================================================== Timetable

    Control Timetable()
    {
        var root = new StackPanel { Spacing = 14, Margin = new Thickness(32, 6, 32, 32) };
        var info = _state.Info;
        var now = Clock.Now();
        var adjust = info.HijriAdjustment ?? 0;
        var range = Math.Clamp(S.TimetableRange, 0, 2);

        List<DateTime> dates;
        string title, subtitle;
        var greg = L.Culture;
        switch (range)
        {
            case 1:
                dates = Hijri.MonthDays(now, _monthOffset, adjust);
                var h = Hijri.From(dates[0], adjust);
                title = L.Digits($"{Hijri.MonthName(h.Month, L.Code)} {h.Year}");
                subtitle = $"{L.GregorianDate(dates[0], "d MMMM")} – {L.GregorianDate(dates[^1], "d MMMM yyyy")}";
                break;
            case 2:
                var first = new DateTime(now.Year, now.Month, 1).AddMonths(_monthOffset);
                dates = Enumerable.Range(0, DateTime.DaysInMonth(first.Year, first.Month)).Select(d => first.AddDays(d)).ToList();
                title = L.GregorianDate(first, "MMMM yyyy");
                var h1 = Hijri.From(dates[0], adjust);
                var h2 = Hijri.From(dates[^1], adjust);
                subtitle = L.Digits(h1.Month == h2.Month ? $"{Hijri.MonthName(h1.Month, L.Code)} {h1.Year}"
                    : $"{Hijri.MonthName(h1.Month, L.Code)} – {Hijri.MonthName(h2.Month, L.Code)} {h2.Year}");
                break;
            default:
                dates = Enumerable.Range(0, 7).Select(d => now.Date.AddDays(d)).ToList();
                title = $"{L.GregorianDate(dates[0], "d MMMM")} – {L.GregorianDate(dates[^1], "d MMMM")}";
                subtitle = Hijri.Format(dates[0], HijriFormat.DayMonth, adjust) + " – " + Hijri.Format(dates[^1], HijriFormat.Full, adjust);
                break;
        }

        // Controls: range + month steps.
        var bar = new Grid { ColumnDefinitions = new ColumnDefinitions("*,Auto") };
        var titles = new StackPanel { Spacing = 0 };
        titles.Children.Add(Ui.Text(title, 18, FontWeight.SemiBold));
        titles.Children.Add(Ui.Text(subtitle, 12.5, FontWeight.Normal, "secondary"));
        bar.Children.Add(titles);
        var controls = new StackPanel { Orientation = Orientation.Horizontal, Spacing = 6, VerticalAlignment = VerticalAlignment.Center };
        if (range != 0)
        {
            controls.Children.Add(Ui.IconButton(L.IsRtl ? "ChevronRightRegular" : "ChevronLeftRegular", L.T("view:previous.month"), () => { _monthOffset--; Refresh(); }));
            var todayBtn = new Button { Content = L.T("view:today"), Padding = new Thickness(12, 5) };
            todayBtn.Click += (_, _) => { _monthOffset = 0; Refresh(); };
            controls.Children.Add(todayBtn);
            controls.Children.Add(Ui.IconButton(L.IsRtl ? "ChevronLeftRegular" : "ChevronRightRegular", L.T("view:next.month"), () => { _monthOffset++; Refresh(); }));
        }
        var seg = new StackPanel { Orientation = Orientation.Horizontal, Spacing = 2, Margin = new Thickness(10, 0, 0, 0) };
        var segHost = new Border { Child = seg, Padding = new Thickness(3), CornerRadius = new CornerRadius(8) };
        Ui.Bind(segHost, Border.BackgroundProperty, "CardBrush");
        string[] labels = { L.T("view:range.week"), L.T("view:range.hijri"), L.T("view:range.gregorian") };
        for (int r = 0; r < 3; r++)
        {
            var rr = r;
            var b = new Button { Content = Ui.Text(labels[r], 12.5, r == range ? FontWeight.SemiBold : FontWeight.Normal), Padding = new Thickness(10, 4), CornerRadius = new CornerRadius(6) };
            b.Classes.Add("row");
            if (r == range) Ui.Bind(b, Button.BackgroundProperty, "RaisedCardBrush");
            b.Click += (_, _) => { S.TimetableRange = rr; S.Save(notify: false); _monthOffset = 0; Refresh(); };
            seg.Children.Add(b);
        }
        controls.Children.Add(segHost);
        Grid.SetColumn(controls, 1);
        bar.Children.Add(controls);
        root.Children.Add(bar);

        if (info.Calendar is null && range != 0)
        {
            root.Children.Add(Ui.Text(L.T("view:no.calendar"), 13, FontWeight.Normal, "secondary"));
        }

        // The table.
        const string cols = "2.2*,1.3*,*,*,*,*,*,*";
        var table = new StackPanel();
        var head = new Grid { ColumnDefinitions = new ColumnDefinitions(cols), Margin = new Thickness(12, 0, 12, 6) };
        string[] heads = { L.T("view:day"), "", L.PrayerName(0), L.T("prayer.shuruq"), L.PrayerName(1), L.PrayerName(2), L.PrayerName(3), L.PrayerName(4) };
        for (int c = 0; c < heads.Length; c++)
        {
            var t = Ui.Text(heads[c].ToUpper(L.Culture), 11, FontWeight.SemiBold, "tertiary");
            Grid.SetColumn(t, c);
            head.Children.Add(t);
        }
        table.Children.Add(head);
        foreach (var date in dates)
        {
            var row = new Grid { ColumnDefinitions = new ColumnDefinitions(cols), Height = 36, Margin = new Thickness(12, 0) };
            var bg = new Border { CornerRadius = new CornerRadius(6), Margin = new Thickness(-12, 1) };
            Grid.SetColumnSpan(bg, 8);
            row.Children.Add(bg);
            var isToday = date.Date == now.Date;
            var isPast = date.Date < now.Date;
            if (isToday) Ui.Bind(bg, Border.BackgroundProperty, "AccentSoftBrush");
            else if (date.DayOfWeek == DayOfWeek.Friday) Ui.Bind(bg, Border.BackgroundProperty, "CardBrush");
            var day = PrayerDay.For(info, date);
            var dayLabel = Ui.Text(L.GregorianDate(date, "ddd d MMM"), 13, isToday ? FontWeight.SemiBold : FontWeight.Normal, isToday ? "accent" : null);
            row.Children.Add(dayLabel);
            var hijri = Ui.Text(Hijri.Format(date, HijriFormat.DayMonth, adjust), 12, FontWeight.Normal, "secondary");
            Grid.SetColumn(hijri, 1);
            row.Children.Add(hijri);
            var values = new[] { day.Adhan[0], day.Shuruq, day.Adhan[1], day.Adhan[2], day.Adhan[3], day.Adhan[4] };
            for (int c = 0; c < values.Length; c++)
            {
                var t = Ui.Text(L.Time(values[c], S.Use12h), 13.5, isToday ? FontWeight.SemiBold : FontWeight.Normal, c == 1 ? "secondary digits" : "digits");
                t.FlowDirection = FlowDirection.LeftToRight;
                t.HorizontalAlignment = HorizontalAlignment.Left;
                Grid.SetColumn(t, c + 2);
                row.Children.Add(t);
            }
            row.Opacity = isPast ? 0.5 : 1;
            table.Children.Add(row);
        }
        root.Children.Add(Ui.Card(table, new Thickness(0, 12)));
        return root;
    }

    // ================================================================== Day path and dial

    Control DayPath()
    {
        var root = new StackPanel { Spacing = 16, Margin = new Thickness(32, 6, 32, 32) };
        var path = new DayPathControl { State = _state, Height = 380 };
        root.Children.Add(new Border { Child = path, CornerRadius = new CornerRadius(12), ClipToBounds = true });
        root.Children.Add(LegendRow());
        return root;
    }

    Control Dial()
    {
        var root = new Grid { ColumnDefinitions = new ColumnDefinitions("*,24,320"), Margin = new Thickness(32, 6, 32, 32) };
        var dial = new DialControl { State = _state, Height = 520, MaxWidth = 560 };
        root.Children.Add(dial);
        var side = new StackPanel { Spacing = 16 };
        side.Children.Add(LandmarksCard());
        Grid.SetColumn(side, 2);
        root.Children.Add(side);
        return root;
    }

    Control LegendRow()
    {
        var row = new WrapPanel();
        void Item(IBrush brush, string text)
        {
            var sp = new StackPanel { Orientation = Orientation.Horizontal, Spacing = 6, Margin = new Thickness(0, 0, 18, 6) };
            sp.Children.Add(new Border { Width = 12, Height = 12, CornerRadius = new CornerRadius(3), Background = brush });
            sp.Children.Add(Ui.Text(text, 12, FontWeight.Normal, "secondary"));
            row.Children.Add(sp);
        }
        Item(Ui.Res("AccentBrush"), L.T("col.adhan"));
        Item(new SolidColorBrush(Color.FromArgb(150, 255, 255, 255)), L.T("view:iqama.legend"));
        Item(new SolidColorBrush(Color.FromArgb(120, 196, 43, 28)), L.T("view:forbidden"));
        Item(new SolidColorBrush(Color.FromArgb(120, 120, 140, 255)), L.T("view:last.third"));
        return row;
    }
}
