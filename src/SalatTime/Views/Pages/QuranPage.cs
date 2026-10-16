using Avalonia;
using Avalonia.Controls;
using Avalonia.Controls.Primitives;
using Avalonia.Input;
using Avalonia.Layout;
using Avalonia.Media;
using SalatTime.Controls;
using SalatTime.Core;

namespace SalatTime.Views.Pages;

/// <summary>
/// The offline Qur'an reader: surah navigator with search and bookmarks, a
/// Mushaf view (two pages side by side on wide windows) and a verse view with
/// QuranEnc translations of meanings (Hafs), plus verse-by-verse recitation.
/// </summary>
public sealed class QuranPage : IPage
{
    readonly AppState _state;
    readonly Grid _root = new() { ColumnDefinitions = new ColumnDefinitions("270,*") };
    readonly ContentControl _nav = new();
    readonly ContentControl _reader = new();
    string _search = "";
    CancellationTokenSource? _recitation;
    (int Sura, int Ayah)? _playing;
    double _width, _height;

    public QuranPage(AppState state)
    {
        _state = state;
        _root.Margin = new Thickness(32, 6, 32, 24);
        _root.Children.Add(_nav);
        Grid.SetColumn(_reader, 1);
        _reader.Margin = new Thickness(20, 0, 0, 0);
        _root.Children.Add(_reader);
        _reader.SizeChanged += (_, e) =>
        {
            // Re-plan when the window crosses the one-page / two-page threshold.
            var before = (PagesShown, PageWidth);
            _width = e.NewSize.Width;
            _height = e.NewSize.Height;
            if (Mode == 1 && before != (PagesShown, PageWidth)) RenderReader();
        };
        _state.AdhkarAudio.Finished += OnVerseFinished;
    }

    static Localizer L => Localizer.Shared;
    AppSettings S => _state.Settings;
    QuranEdition? Edition => QuranEdition.Load(S.QuranEdition);
    bool IsHafs => S.QuranEdition != "warsh";

    public string Key => "quran";
    public string Title => L.T("feature:quran.tab");
    public string Subtitle
    {
        get
        {
            var ed = Edition;
            if (ed is null) return L.T("feature:quran.unavailable");
            var surah = ed.Surahs.FirstOrDefault(s => s.Number == S.QuranSura);
            var edition = IsHafs ? L.T("win:quran.hafs") : L.T("win:quran.warsh");
            return surah is null ? edition : $"{edition} · {surah.Number}. {surah.NameAr} · {L.Digits($"{L.T("win:quran.page")} {S.QuranPage}")}";
        }
    }
    public IReadOnlyList<string> Modes => new[] { L.T("win:quran.verses"), L.T("win:quran.mushaf") };
    public int Mode { get => S.QuranMode; set { S.QuranMode = value; S.Save(notify: false); } }
    public Control View => _root;

    public void Refresh()
    {
        RenderNav();
        RenderReader();
    }

    public void Tick(DateTime now) { }

    FontFamily ScriptFont => IsHafs
        ? new FontFamily("avares://SalatTime/Assets/QuranFonts/KFGQPC-Hafs#KFGQPC HAFS Uthmanic Script")
        : new FontFamily("avares://SalatTime/Assets/QuranFonts/KFGQPC-Warsh#KFGQPC Warsh Uthmanic Script");

    // ================================================================== navigator

    void RenderNav()
    {
        var ed = Edition;
        var panel = new DockPanel();
        var box = new TextBox { Watermark = L.T("feature:quran.search.placeholder"), Text = _search, Height = 34, VerticalContentAlignment = VerticalAlignment.Center, Margin = new Thickness(0, 0, 0, 8) };
        box.InnerLeftContent = new Border { Child = Ui.Icon("SearchRegular", 15, Ui.Res("TextSecondary")), Margin = new Thickness(10, 0, 4, 0) };
        DockPanel.SetDock(box, Dock.Top);
        panel.Children.Add(box);
        var list = new StackPanel { Spacing = 1 };
        void Fill()
        {
            list.Children.Clear();
            if (ed is null) return;
            var q = _search.Trim();
            if (q.Length > 0 && (q.Contains(':') || q.Any(c => c is >= '؀' and <= 'ۿ') && q.Length >= 3))
            {
                foreach (var a in ed.Search(q, 40)) list.Children.Add(SearchRow(ed, a));
                if (list.Children.Count > 0) return;
            }
            var folded = QuranEdition.Normalize(q);
            foreach (var s in ed.Surahs)
            {
                if (q.Length > 0 && !(s.Number.ToString() == q || QuranEdition.Normalize(s.NameAr).Contains(folded) || s.NameEn.Contains(q, StringComparison.OrdinalIgnoreCase)))
                    continue;
                list.Children.Add(SurahRow(s));
            }
        }
        box.TextChanged += (_, _) => { _search = box.Text ?? ""; Fill(); };
        Fill();

        var scroll = new ScrollViewer { Content = list, HorizontalScrollBarVisibility = ScrollBarVisibility.Disabled };
        var bookmarks = Bookmarks(ed);
        if (bookmarks is not null)
        {
            DockPanel.SetDock(bookmarks, Dock.Bottom);
            panel.Children.Add(bookmarks);
        }
        panel.Children.Add(Ui.Card(scroll, new Thickness(4)));
        _nav.Content = panel;
    }

    Control SurahRow(Surah s)
    {
        var selected = s.Number == S.QuranSura;
        var grid = new Grid { ColumnDefinitions = new ColumnDefinitions("34,*,Auto") };
        var num = new Border { Width = 28, Height = 28, CornerRadius = new CornerRadius(8), Child = Ui.Text(L.Digits(s.Number.ToString()), 11.5, FontWeight.SemiBold) };
        ((TextBlock)num.Child).HorizontalAlignment = HorizontalAlignment.Center;
        Ui.Bind(num, Border.BackgroundProperty, selected ? "AccentSoftBrush" : "CardBrush");
        grid.Children.Add(num);
        var names = new StackPanel { Margin = new Thickness(8, 0), Spacing = 0 };
        names.Children.Add(Ui.Text(L.IsRtl ? s.NameAr : s.NameEn, 13, selected ? FontWeight.SemiBold : FontWeight.Normal));
        names.Children.Add(Ui.Text(L.Digits(L.F("win:quran.ayahs", s.AyahCount)), 11, FontWeight.Normal, "tertiary"));
        Grid.SetColumn(names, 1);
        grid.Children.Add(names);
        var arabic = new TextBlock { Text = s.NameAr, FontFamily = AppTheme.Cairo, FontSize = 14, VerticalAlignment = VerticalAlignment.Center, FlowDirection = FlowDirection.RightToLeft };
        Ui.Bind(arabic, TextBlock.ForegroundProperty, selected ? "AccentBrush" : "TextSecondary");
        Grid.SetColumn(arabic, 2);
        if (!L.IsRtl) grid.Children.Add(arabic);
        var b = new Button { Content = grid, Padding = new Thickness(6, 5) };
        b.Classes.Add("row");
        b.Classes.Set("selected", selected);
        b.Click += (_, _) => Go(s.Number, 1);
        return b;
    }

    Control SearchRow(QuranEdition ed, Ayah a)
    {
        var stack = new StackPanel { Spacing = 2 };
        stack.Children.Add(Ui.Text(L.Digits($"{a.SuraNameAr.Trim()} {a.Sura}:{a.Number}"), 12, FontWeight.SemiBold, "accent"));
        var text = new TextBlock { Text = a.Plain ?? a.Text, FontFamily = AppTheme.Cairo, FontSize = 13, TextWrapping = TextWrapping.Wrap, MaxLines = 2, TextTrimming = TextTrimming.CharacterEllipsis, FlowDirection = FlowDirection.RightToLeft };
        stack.Children.Add(text);
        var b = new Button { Content = stack, Padding = new Thickness(8, 6) };
        b.Classes.Add("row");
        b.Click += (_, _) => Go(a.Sura, a.Number);
        return b;
    }

    Control? Bookmarks(QuranEdition? ed)
    {
        var marks = S.QuranBookmarks.Where(m => m.Edition == S.QuranEdition).ToList();
        var stack = new StackPanel { Spacing = 2 };
        stack.Children.Add(Ui.Text(L.T("feature:quran.bookmarks"), 12, FontWeight.SemiBold, "tertiary"));
        if (marks.Count == 0)
        {
            var empty = Ui.Text(L.T("feature:quran.bookmarks.empty"), 11.5, FontWeight.Normal, "tertiary");
            empty.TextWrapping = TextWrapping.Wrap;
            stack.Children.Add(empty);
        }
        foreach (var m in marks.TakeLast(6).Reverse())
        {
            var surah = ed?.Surahs.FirstOrDefault(s => s.Number == m.Sura);
            var row = new StackPanel { Orientation = Orientation.Horizontal, Spacing = 8 };
            row.Children.Add(Ui.Icon("StarFilled", 13, Ui.Res("AccentBrush")));
            row.Children.Add(Ui.Text(L.Digits($"{surah?.NameAr ?? ""} {m.Sura}:{m.Ayah}"), 12.5));
            var b = new Button { Content = row, Padding = new Thickness(6, 4) };
            b.Classes.Add("row");
            var mark = m;
            b.Click += (_, _) => Go(mark.Sura, mark.Ayah);
            stack.Children.Add(b);
        }
        var card = Ui.Card(stack, new Thickness(12, 10));
        card.Margin = new Thickness(0, 8, 0, 0);
        return card;
    }

    void Go(int sura, int ayah)
    {
        var ed = Edition;
        if (ed?.Find(sura, ayah) is not { } a) return;
        S.QuranSura = sura;
        S.QuranAyah = ayah;
        S.QuranPage = a.Page;
        S.Save(notify: false);
        Refresh();
        App.Instance?.RefreshMainHeader();
    }

    // ================================================================== reader

    void RenderReader()
    {
        var ed = Edition;
        if (ed is null)
        {
            var msg = Ui.Text(L.T("feature:quran.unavailable") + (QuranEdition.LastError is string e ? $" ({e})" : ""), 14, FontWeight.Normal, "secondary");
            msg.TextWrapping = TextWrapping.Wrap;
            _reader.Content = Ui.Card(msg);
            return;
        }
        var dock = new DockPanel();
        var toolbar = Toolbar(ed);
        DockPanel.SetDock(toolbar, Dock.Top);
        dock.Children.Add(toolbar);
        dock.Children.Add(Mode == 1 ? Mushaf(ed) : Verses(ed));
        _reader.Content = dock;
    }

    Control Toolbar(QuranEdition ed)
    {
        var bar = new WrapPanel { Margin = new Thickness(0, 0, 0, 12) };
        // Edition.
        var editions = new StackPanel { Orientation = Orientation.Horizontal, Spacing = 2 };
        var host = new Border { Child = editions, Padding = new Thickness(3), CornerRadius = new CornerRadius(8), Margin = new Thickness(0, 0, 8, 6) };
        Ui.Bind(host, Border.BackgroundProperty, "CardBrush");
        foreach (var (key, label) in new[] { ("hafs", L.T("win:quran.hafs")), ("warsh", L.T("win:quran.warsh")) })
        {
            var selected = S.QuranEdition == key;
            var b = new Button { Content = Ui.Text(label, 12.5, selected ? FontWeight.SemiBold : FontWeight.Normal), Padding = new Thickness(12, 5), CornerRadius = new CornerRadius(6) };
            b.Classes.Add("row");
            if (selected) Ui.Bind(b, Button.BackgroundProperty, "RaisedCardBrush");
            var k = key;
            b.Click += (_, _) =>
            {
                StopRecitation();
                var current = (S.QuranSura, S.QuranAyah);
                S.QuranEdition = k;
                // Warsh verse boundaries differ; keep the surah, clamp the verse.
                var next = Edition;
                if (next is not null)
                {
                    var target = next.Find(current.QuranSura, current.QuranAyah) ?? next.Surah(current.QuranSura).FirstOrDefault() ?? next.Ayahs[0];
                    S.QuranSura = target.Sura; S.QuranAyah = target.Number; S.QuranPage = target.Page;
                }
                S.Save(notify: false);
                Refresh();
            };
            editions.Children.Add(b);
        }
        bar.Children.Add(host);

        // Translation (Hafs only; Warsh verse boundaries differ from the translations').
        if (Mode == 0 && IsHafs)
        {
            var items = new List<(string, string)> { ("none", L.T("win:quran.no_translation")) };
            items.AddRange(QuranTranslation.All.Select(t => (t.Key, t.Title)));
            var current = TranslationKey;
            var combo = new ComboBox { Width = 250, ItemsSource = items.Select(i => i.Item2).ToList(), SelectedIndex = Math.Max(0, items.FindIndex(i => i.Item1 == current)), Margin = new Thickness(0, 0, 8, 6) };
            combo.SelectionChanged += (_, _) =>
            {
                if (combo.SelectedIndex < 0) return;
                S.QuranTranslation = items[combo.SelectedIndex].Item1;
                S.Save(notify: false);
                RenderReader();
            };
            bar.Children.Add(combo);
        }

        // Recitation (Hafs only).
        if (IsHafs)
        {
            var reciters = QuranReciter.All;
            var combo = new ComboBox { Width = 220, ItemsSource = reciters.Select(r => r.Name).ToList(), Margin = new Thickness(0, 0, 4, 6) };
            combo.SelectedIndex = Math.Max(0, Array.FindIndex(reciters, r => r.Id == S.QuranReciter));
            combo.SelectionChanged += (_, _) => { if (combo.SelectedIndex >= 0) { S.QuranReciter = reciters[combo.SelectedIndex].Id; S.Save(notify: false); } };
            bar.Children.Add(combo);
            var playing = _playing is not null;
            var play = new Button { Padding = new Thickness(12, 6), Margin = new Thickness(0, 0, 8, 6) };
            var row = new StackPanel { Orientation = Orientation.Horizontal, Spacing = 6 };
            row.Children.Add(Ui.Icon(playing ? "StopFilled" : "PlayFilled", 14));
            row.Children.Add(Ui.Text(L.T(playing ? "adhkar.stop" : "win:quran.recite"), 13));
            play.Content = row;
            Ui.Tip(play, L.T("win:quran.recite.help"));
            play.Click += (_, _) => { if (_playing is not null) StopRecitation(); else StartRecitation(S.QuranSura, S.QuranAyah); RenderReader(); };
            bar.Children.Add(play);
        }

        // Pages / bookmark / size.
        if (Mode == 1)
        {
            bar.Children.Add(Ui.IconButton(L.IsRtl ? "ChevronRightRegular" : "ChevronLeftRegular", L.T("win:quran.previous_page"), () => TurnPage(-PagesShown)));
            var page = Ui.Text(L.Digits($"{L.T("win:quran.page")} {S.QuranPage} / {ed.PageCount}"), 13, FontWeight.Medium, "secondary");
            page.Margin = new Thickness(6, 0);
            bar.Children.Add(page);
            bar.Children.Add(Ui.IconButton(L.IsRtl ? "ChevronLeftRegular" : "ChevronRightRegular", L.T("win:quran.next_page"), () => TurnPage(PagesShown)));
        }
        var marked = S.QuranBookmarks.Any(m => m.Edition == S.QuranEdition && m.Sura == S.QuranSura && m.Ayah == S.QuranAyah);
        bar.Children.Add(Ui.IconButton(marked ? "StarFilled" : "StarRegular", L.T(marked ? "feature:quran.bookmark.remove" : "feature:quran.bookmark.add"), () =>
        {
            var existing = S.QuranBookmarks.FirstOrDefault(m => m.Edition == S.QuranEdition && m.Sura == S.QuranSura && m.Ayah == S.QuranAyah);
            if (existing is null) S.QuranBookmarks.Add(new QuranBookmark { Edition = S.QuranEdition, Sura = S.QuranSura, Ayah = S.QuranAyah });
            else S.QuranBookmarks.Remove(existing);
            S.Save(notify: false);
            Refresh();
        }));
        if (Mode == 0)
        {
            foreach (var (label, step) in new[] { ("A−", -0.1), ("A+", 0.1) })
            {
                var b = new Button { Content = Ui.Text(label, 13, FontWeight.SemiBold), Width = 40, Height = 34 };
                b.Classes.Add("icon");
                b.Click += (_, _) => { S.QuranTextScale = Math.Clamp(S.QuranTextScale + step, 0.7, 2.0); S.Save(notify: false); RenderReader(); };
                bar.Children.Add(b);
            }
        }
        return bar;
    }

    string TranslationKey => S.QuranTranslation == "auto" ? (QuranTranslation.ForLanguage(L.Code)?.Key ?? (L.Code == "ar" ? "none" : "en")) : S.QuranTranslation;

    /// <summary>A page fits the reader's height (between 420 and 640 wide); two fit side by side on wide windows.</summary>
    double PageWidth => Math.Clamp(((_height > 0 ? _height : 760) - 70) / 1.42, 420, 640);
    int PagesShown => _width >= PageWidth * 2 + 12 ? 2 : 1;

    void TurnPage(int delta)
    {
        var ed = Edition;
        if (ed is null) return;
        var page = Math.Clamp(S.QuranPage + delta, 1, ed.PageCount);
        S.QuranPage = page;
        var first = ed.Page(page).FirstOrDefault();
        if (first is not null) { S.QuranSura = first.Sura; S.QuranAyah = first.Number; }
        S.Save(notify: false);
        RenderReader();
        RenderNav();
        App.Instance?.RefreshMainHeader();
    }

    // ------------------------------------------------------------------ mushaf

    Control Mushaf(QuranEdition ed)
    {
        var night = AppTheme.IsDark;
        MushafPage PageView(int number)
        {
            var view = new MushafPage { Edition = ed, PageNumber = number, ScriptFont = ScriptFont, Night = night, Width = PageWidth, Highlight = _playing ?? (S.QuranSura, S.QuranAyah) };
            view.AyahClicked += a =>
            {
                S.QuranSura = a.Sura; S.QuranAyah = a.Number; S.QuranPage = a.Page;
                S.Save(notify: false);
                if (_playing is not null) StartRecitation(a.Sura, a.Number);
                RenderReader();
                App.Instance?.RefreshMainHeader();
            };
            return view;
        }

        var host = new Grid();
        if (PagesShown == 2)
        {
            // Two-page spread: the odd page on the right, like a printed Mushaf.
            var right = S.QuranPage % 2 == 1 ? S.QuranPage : S.QuranPage - 1;
            var left = right + 1;
            var spread = new Grid { ColumnDefinitions = new ColumnDefinitions("*,12,*"), FlowDirection = FlowDirection.LeftToRight, HorizontalAlignment = HorizontalAlignment.Center };
            if (left <= ed.PageCount) spread.Children.Add(PageView(left));
            var r = PageView(Math.Max(1, right));
            Grid.SetColumn(r, 2);
            spread.Children.Add(r);
            host.Children.Add(spread);
        }
        else host.Children.Add(PageView(S.QuranPage));
        host.KeyDown += (_, e) =>
        {
            if (e.Key == Avalonia.Input.Key.Left) TurnPage(+PagesShown);   // Arabic page order: left goes forward
            if (e.Key == Avalonia.Input.Key.Right) TurnPage(-PagesShown);
        };
        return new ScrollViewer { Content = host, HorizontalScrollBarVisibility = ScrollBarVisibility.Disabled };
    }

    // ------------------------------------------------------------------ verses

    Control Verses(QuranEdition ed)
    {
        var surah = ed.Surahs.FirstOrDefault(s => s.Number == S.QuranSura) ?? ed.Surahs[0];
        var translation = IsHafs && TranslationKey != "none" ? QuranTranslation.All.FirstOrDefault(t => t.Key == TranslationKey) : null;
        var rows = translation?.Load();
        var stack = new StackPanel { Spacing = 10 };

        var header = new StackPanel { Spacing = 4, HorizontalAlignment = HorizontalAlignment.Center, Margin = new Thickness(0, 4, 0, 6) };
        header.Children.Add(new TextBlock { Text = $"سُورَةُ {surah.NameAr}", FontFamily = AppTheme.Cairo, FontSize = 26, FontWeight = FontWeight.SemiBold, HorizontalAlignment = HorizontalAlignment.Center });
        header.Children.Add(Ui.Text(L.Digits($"{surah.Number}. {surah.NameEn} · {L.F("win:quran.ayahs", surah.AyahCount)}"), 12.5, FontWeight.Normal, "secondary"));
        if (surah.Number != 1 && surah.Number != 9)
        {
            header.Children.Add(new TextBlock { Text = MushafPage.BasmalaText(ed), FontFamily = ScriptFont, FontSize = 26 * S.QuranTextScale, HorizontalAlignment = HorizontalAlignment.Center, FlowDirection = FlowDirection.RightToLeft, Margin = new Thickness(0, 8, 0, 0) });
        }
        stack.Children.Add(header);
        if (translation is not null && rows is not null)
        {
            var credit = Ui.Text(translation.Title + " · QuranEnc.com", 11.5, FontWeight.Normal, "tertiary");
            credit.HorizontalAlignment = HorizontalAlignment.Center;
            stack.Children.Add(credit);
        }

        Control? selected = null;
        foreach (var a in ed.Surah(surah.Number))
        {
            var isSelected = a.Number == S.QuranAyah;
            var isPlaying = _playing is var (ps, pa) && ps == a.Sura && pa == a.Number;
            var verse = new StackPanel { Spacing = 8 };
            var head = new Grid { ColumnDefinitions = new ColumnDefinitions("Auto,*,Auto") };
            var chip = new Border { Padding = new Thickness(8, 2), CornerRadius = new CornerRadius(10), Child = Ui.Text(L.Digits($"{a.Sura}:{a.Number}"), 11.5, FontWeight.SemiBold) };
            Ui.Bind(chip, Border.BackgroundProperty, isSelected || isPlaying ? "AccentSoftBrush" : "CardBrush");
            head.Children.Add(chip);
            var meta = Ui.Text(L.Digits($"{L.T("win:quran.page")} {a.Page} · {L.T("win:quran.juz")} {a.Juz}"), 11, FontWeight.Normal, "tertiary");
            meta.Margin = new Thickness(10, 0);
            Grid.SetColumn(meta, 1);
            head.Children.Add(meta);
            if (IsHafs)
            {
                var ayah = a;
                var play = Ui.IconButton(isPlaying ? "StopFilled" : "PlayRegular", L.T(isPlaying ? "adhkar.stop" : "win:quran.recite"), () =>
                {
                    if (isPlaying) StopRecitation(); else StartRecitation(ayah.Sura, ayah.Number);
                    RenderReader();
                }, 30, 14);
                Grid.SetColumn(play, 2);
                head.Children.Add(play);
            }
            verse.Children.Add(head);
            verse.Children.Add(new TextBlock
            {
                Text = a.Text,
                FontFamily = ScriptFont,
                FontSize = 27 * S.QuranTextScale,
                LineHeight = 27 * S.QuranTextScale * 1.9,
                TextWrapping = TextWrapping.Wrap,
                FlowDirection = FlowDirection.RightToLeft,
                TextAlignment = TextAlignment.Right,
            });
            if (rows is not null && rows.TryGetValue((a.Sura, a.Number), out var meaning) && meaning.Length > 0)
            {
                var t = Ui.Text(meaning, 13.5 * Math.Max(1, S.QuranTextScale * 0.9), FontWeight.Normal, "secondary");
                t.TextWrapping = TextWrapping.Wrap;
                t.FlowDirection = translation!.Language == "ur" ? FlowDirection.RightToLeft : FlowDirection.LeftToRight;
                verse.Children.Add(t);
            }
            var card = Ui.Card(verse, new Thickness(18, 12));
            if (isPlaying) { card.BorderBrush = Ui.Res("AccentBrush"); card.BorderThickness = new Thickness(1.5); }
            var target = a;
            card.PointerPressed += (_, _) =>
            {
                S.QuranAyah = target.Number; S.QuranPage = target.Page;
                S.Save(notify: false);
                App.Instance?.RefreshMainHeader();
            };
            stack.Children.Add(card);
            if (isSelected || isPlaying) selected = card;
        }
        var scroll = new ScrollViewer { Content = stack, HorizontalScrollBarVisibility = ScrollBarVisibility.Disabled };
        if (selected is not null && (S.QuranAyah > 1 || _playing is not null))
            Avalonia.Threading.Dispatcher.UIThread.Post(() => selected.BringIntoView(), Avalonia.Threading.DispatcherPriority.Loaded);
        return scroll;
    }

    // ------------------------------------------------------------------ recitation

    QuranReciter Reciter => QuranReciter.All.FirstOrDefault(r => r.Id == S.QuranReciter) ?? QuranReciter.All[0];

    async void StartRecitation(int sura, int ayah)
    {
        if (!IsHafs) return;
        _recitation?.Cancel();
        var cts = _recitation = new CancellationTokenSource();
        _playing = (sura, ayah);
        S.QuranSura = sura; S.QuranAyah = ayah;
        if (Edition?.Find(sura, ayah) is { } a) S.QuranPage = a.Page;
        RenderReader();
        var path = await QuranAudioCache.EnsureAsync(Reciter, sura, ayah, cts.Token);
        if (cts.IsCancellationRequested) return;
        if (path is null) { _playing = null; RenderReader(); return; }
        _state.AdhkarAudio.Play(path, "", 1.0);
        // Fetch a few verses ahead so playback stays continuous.
        var ed = Edition;
        _ = Task.Run(async () =>
        {
            for (int i = 1; i <= 3 && ed?.Find(sura, ayah + i) is not null; i++)
                await QuranAudioCache.EnsureAsync(Reciter, sura, ayah + i, cts.Token);
        });
    }

    void StopRecitation()
    {
        _recitation?.Cancel();
        if (_playing is not null) _state.AdhkarAudio.Stop();
        _playing = null;
    }

    void OnVerseFinished()
    {
        if (_playing is not var (sura, ayah)) return;
        var ed = Edition;
        var next = ed?.Find(sura, ayah + 1);
        if (next is null) { _playing = null; RenderReader(); return; }
        StartRecitation(next.Sura, next.Number);
    }
}
