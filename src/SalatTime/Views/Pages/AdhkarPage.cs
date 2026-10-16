using Avalonia;
using Avalonia.Controls;
using Avalonia.Controls.Primitives;
using Avalonia.Input;
using Avalonia.Layout;
using Avalonia.Media;
using SalatTime.Core;

namespace SalatTime.Views.Pages;

/// <summary>
/// Adhkar from Hisn al-Muslim (the library shared with the Mac app): the 14
/// categories, a reading view with tap counters and recitations, and a focus
/// view that shows one dhikr at a time with a large counter.
/// </summary>
public sealed class AdhkarPage : IPage
{
    readonly AppState _state;
    readonly Grid _root = new() { ColumnDefinitions = new ColumnDefinitions("250,*") };
    readonly ScrollViewer _list = new() { HorizontalScrollBarVisibility = ScrollBarVisibility.Disabled };
    readonly ContentControl _reader = new();
    string _category = "morning";
    int _focusIndex;
    readonly Dictionary<string, int[]> _counts = new();
    int _playing = -1;          // index being recited, -1 when silent
    bool _playAll;

    public AdhkarPage(AppState state)
    {
        _state = state;
        _root.Margin = new Thickness(32, 6, 32, 24);
        _root.Children.Add(_list);
        Grid.SetColumn(_reader, 1);
        _reader.Margin = new Thickness(20, 0, 0, 0);
        _root.Children.Add(_reader);
        _state.AdhkarAudio.Finished += OnRecitationFinished;
        _state.AdhkarAudio.StateChanged += () => { if (!_state.AdhkarAudio.IsPlaying && !_playAll) { _playing = -1; Render(); } };
    }

    static Localizer L => Localizer.Shared;
    AppSettings S => _state.Settings;

    public string Key => "adhkar";
    public string Title => L.T("adhkar.editor.title");
    public string Subtitle => $"{AdhkarLibrary.Name(_category)} · {L.F("win:adhkar.count", Items.Count)}";
    public IReadOnlyList<string> Modes => new[] { L.T("win:adhkar.reading"), L.T("win:adhkar.focus") };
    public int Mode { get; set; }
    public Control View => _root;

    List<AdhkarItem> Items => AdhkarLibrary.Items(_category);

    int[] Counts
    {
        get
        {
            if (!_counts.TryGetValue(_category, out var c) || c.Length != Items.Count) _counts[_category] = c = new int[Items.Count];
            return c;
        }
    }

    public void Open(string? detail)
    {
        if (detail is "morning" or "evening")
        {
            _category = detail;
            _focusIndex = 0;
            _counts.Remove(detail);
            // Scheduled opening: recite the collection when recordings are available.
            if (Items.Any(i => i.AudioPath is not null)) StartPlayAll();
        }
        else if (detail is not null && AdhkarLibrary.Categories.Contains(detail)) _category = detail;
    }

    public void Refresh()
    {
        BuildList();
        Render();
    }

    public void Tick(DateTime now) { }

    void BuildList()
    {
        var stack = new StackPanel { Spacing = 2 };
        foreach (var category in AdhkarLibrary.Categories)
        {
            var count = AdhkarLibrary.Items(category).Count;
            if (count == 0) continue;
            var selected = category == _category;
            var grid = new Grid { ColumnDefinitions = new ColumnDefinitions("Auto,*,Auto") };
            var icon = Ui.Icon(AdhkarLibrary.Icon(category), 16);
            Ui.Bind(icon, PathIcon.ForegroundProperty, selected ? "AccentBrush" : "TextSecondary");
            grid.Children.Add(icon);
            var name = Ui.Text(AdhkarLibrary.Name(category), 13, selected ? FontWeight.SemiBold : FontWeight.Normal);
            name.TextTrimming = TextTrimming.CharacterEllipsis;
            name.Margin = new Thickness(10, 0, 6, 0);
            Grid.SetColumn(name, 1);
            grid.Children.Add(name);
            var badge = Ui.Text(L.Digits(count.ToString()), 11.5, FontWeight.Normal, "tertiary");
            Grid.SetColumn(badge, 2);
            grid.Children.Add(badge);
            var button = new Button { Content = grid, Height = 36 };
            button.Classes.Add("row");
            button.Classes.Set("selected", selected);
            var c = category;
            button.Click += (_, _) =>
            {
                StopRecitation();
                _category = c;
                _focusIndex = 0;
                Refresh();
                if (App.Instance is { } app) app.RefreshMainHeader();
            };
            stack.Children.Add(button);
        }
        _list.Content = Ui.Card(stack, new Thickness(6));
    }

    void Render()
    {
        _reader.Content = Mode == 1 ? Focus() : Reading();
    }

    // ------------------------------------------------------------------ toolbar

    Control Toolbar()
    {
        var bar = new Grid { ColumnDefinitions = new ColumnDefinitions("*,Auto"), Margin = new Thickness(0, 0, 0, 12) };
        var title = new StackPanel { Spacing = 0 };
        title.Children.Add(Ui.Text(AdhkarLibrary.Name(_category), 20, FontWeight.SemiBold));
        var done = Counts.Select((c, i) => c >= Math.Max(1, Items[i].Count)).Count(x => x);
        title.Children.Add(Ui.Text(L.Digits($"{done} / {Items.Count}"), 12.5, FontWeight.Normal, "secondary"));
        bar.Children.Add(title);

        var tools = new StackPanel { Orientation = Orientation.Horizontal, Spacing = 4, VerticalAlignment = VerticalAlignment.Center };
        var hasAudio = Items.Any(i => i.AudioPath is not null);
        if (hasAudio)
        {
            var playAll = new Button { Padding = new Thickness(12, 6) };
            var row = new StackPanel { Orientation = Orientation.Horizontal, Spacing = 6 };
            row.Children.Add(Ui.Icon(_playAll ? "StopFilled" : "PlayFilled", 14));
            row.Children.Add(Ui.Text(L.T(_playAll ? "adhkar.stop" : "win:adhkar.play_all"), 13));
            playAll.Content = row;
            playAll.Click += (_, _) => { if (_playAll) StopRecitation(); else StartPlayAll(); Render(); };
            tools.Children.Add(playAll);
        }
        tools.Children.Add(Ui.IconButton("ArrowClockwiseRegular", L.T("win:adhkar.reset"), () => { _counts.Remove(_category); _focusIndex = 0; Render(); }));
        tools.Children.Add(TextSizeButton("−", -0.1));
        tools.Children.Add(TextSizeButton("+", 0.1));
        Grid.SetColumn(tools, 1);
        bar.Children.Add(tools);
        return bar;
    }

    Button TextSizeButton(string label, double step)
    {
        var b = new Button { Content = Ui.Text(label == "+" ? "A+" : "A−", 13, FontWeight.SemiBold), Width = 40, Height = 34 };
        b.Classes.Add("icon");
        Ui.Tip(b, L.T(step > 0 ? "feature:popup.text.larger" : "feature:popup.text.smaller"));
        b.Click += (_, _) =>
        {
            S.AdhkarTextScale = Math.Clamp(S.AdhkarTextScale + step, 0.7, 1.8);
            S.Save(notify: false);
            Render();
        };
        return b;
    }

    // ------------------------------------------------------------------ reading

    Control Reading()
    {
        var page = new DockPanel();
        var toolbar = Toolbar();
        DockPanel.SetDock(toolbar, Dock.Top);
        page.Children.Add(toolbar);
        var stack = new StackPanel { Spacing = 12 };
        var items = Items;
        if (items.Count == 0) stack.Children.Add(Ui.Text(L.T("feature:popup.adhkar.empty"), 13, FontWeight.Normal, "secondary"));
        for (int i = 0; i < items.Count; i++) stack.Children.Add(DhikrCard(i, items[i]));
        page.Children.Add(new ScrollViewer { Content = stack, HorizontalScrollBarVisibility = ScrollBarVisibility.Disabled });
        return page;
    }

    Control DhikrCard(int index, AdhkarItem item)
    {
        var target = Math.Max(1, item.Count);
        var count = Counts[index];
        var complete = count >= target;
        var stack = new StackPanel { Spacing = 10 };

        var head = new Grid { ColumnDefinitions = new ColumnDefinitions("Auto,*,Auto,Auto") };
        var number = new Border { Width = 28, Height = 28, CornerRadius = new CornerRadius(14), Child = Ui.Text(L.Digits((index + 1).ToString()), 12, FontWeight.SemiBold) };
        ((TextBlock)number.Child).HorizontalAlignment = HorizontalAlignment.Center;
        Ui.Bind(number, Border.BackgroundProperty, complete ? "AccentSoftBrush" : "CardBrush");
        head.Children.Add(number);
        var countText = item.CountDescription.Length > 0 ? item.CountDescription : L.F("adhkar.editor.count_times", target);
        var countLabel = Ui.Text(countText, 12.5, FontWeight.Medium, "secondary");
        countLabel.Margin = new Thickness(10, 0);
        Grid.SetColumn(countLabel, 1);
        head.Children.Add(countLabel);
        if (item.AudioPath is not null)
        {
            var isPlaying = _playing == index;
            var play = Ui.IconButton(isPlaying ? "StopFilled" : "PlayRegular", L.T(isPlaying ? "adhkar.stop" : "adhkar.play"), () =>
            {
                if (isPlaying) StopRecitation(); else PlayItem(index, all: false);
                Render();
            }, 32, 15);
            Grid.SetColumn(play, 2);
            head.Children.Add(play);
        }
        var counter = CounterButton(index, target, small: true);
        Grid.SetColumn(counter, 3);
        head.Children.Add(counter);
        stack.Children.Add(head);

        stack.Children.Add(ArabicText(item.Arabic, 22));
        if (item.Virtue.Length > 0)
        {
            var virtue = Ui.Text(item.Virtue, 12.5, FontWeight.Normal, "secondary");
            virtue.TextWrapping = TextWrapping.Wrap;
            virtue.FlowDirection = AdhkarLibrary.IsArabic(item.Virtue) ? FlowDirection.RightToLeft : FlowDirection.LeftToRight;
            stack.Children.Add(virtue);
        }
        if (item.Source.Length > 0)
        {
            var source = Ui.Text(item.Source, 11.5, FontWeight.Normal, "tertiary");
            source.TextWrapping = TextWrapping.Wrap;
            source.FlowDirection = AdhkarLibrary.IsArabic(item.Source) ? FlowDirection.RightToLeft : FlowDirection.LeftToRight;
            stack.Children.Add(source);
        }
        var card = Ui.Card(stack, new Thickness(18, 14));
        if (_playing == index) { card.BorderBrush = Ui.Res("AccentBrush"); card.BorderThickness = new Thickness(1.5); }
        card.Opacity = complete ? 0.62 : 1;
        return card;
    }

    TextBlock ArabicText(string text, double size)
    {
        var t = new TextBlock
        {
            Text = text,
            FontSize = size * S.AdhkarTextScale,
            LineHeight = size * S.AdhkarTextScale * 1.75,
            TextWrapping = TextWrapping.Wrap,
            FlowDirection = FlowDirection.RightToLeft,
            TextAlignment = TextAlignment.Right,
            FontFamily = ArabicFace,
        };
        return t;
    }

    /// <summary>A Naskh face for adhkar text (built into Windows), Cairo otherwise.</summary>
    static readonly FontFamily ArabicFace = OperatingSystem.IsWindows()
        ? new FontFamily("Sakkal Majalla, Traditional Arabic, Segoe UI")
        : AppTheme.Cairo;

    Control CounterButton(int index, int target, bool small)
    {
        var count = Counts[index];
        var complete = count >= target;
        var label = complete ? (Control)Ui.Icon("CheckmarkRegular", small ? 15 : 34) : Ui.Text(L.Digits($"{count}/{target}"), small ? 12.5 : 30, FontWeight.SemiBold, "digits");
        if (label is TextBlock tb) tb.FlowDirection = FlowDirection.LeftToRight;
        var button = new Button
        {
            Content = label,
            MinWidth = small ? 56 : 150,
            Height = small ? 32 : 150,
            CornerRadius = new CornerRadius(small ? 16 : 75),
            HorizontalContentAlignment = HorizontalAlignment.Center,
            VerticalContentAlignment = VerticalAlignment.Center,
        };
        if (complete) button.Classes.Add("accent");
        Ui.Tip(button, L.T("win:adhkar.tap"));
        button.Click += (_, _) => Count(index);
        return button;
    }

    void Count(int index)
    {
        var target = Math.Max(1, Items[index].Count);
        var counts = Counts;
        if (counts[index] >= target) counts[index] = 0;   // tapping a finished dhikr starts it again
        else counts[index]++;
        if (Mode == 1 && counts[index] >= target && _focusIndex < Items.Count - 1) _focusIndex++;
        Render();
    }

    // ------------------------------------------------------------------ focus

    Control Focus()
    {
        var page = new DockPanel();
        var toolbar = Toolbar();
        DockPanel.SetDock(toolbar, Dock.Top);
        page.Children.Add(toolbar);
        var items = Items;
        if (items.Count == 0) return page;
        _focusIndex = Math.Clamp(_focusIndex, 0, items.Count - 1);
        var item = items[_focusIndex];
        var target = Math.Max(1, item.Count);

        var nav = new Grid { ColumnDefinitions = new ColumnDefinitions("Auto,*,Auto"), Margin = new Thickness(0, 12, 0, 0) };
        var prev = Ui.IconButton(L.IsRtl ? "ChevronRightRegular" : "ChevronLeftRegular", L.T("adhkar.prev"), () => { _focusIndex = Math.Max(0, _focusIndex - 1); Render(); }, 40, 18);
        prev.IsEnabled = _focusIndex > 0;
        nav.Children.Add(prev);
        var dots = new StackPanel { Orientation = Orientation.Horizontal, Spacing = 5, HorizontalAlignment = HorizontalAlignment.Center, VerticalAlignment = VerticalAlignment.Center };
        for (int i = 0; i < items.Count; i++)
        {
            var finished = Counts[i] >= Math.Max(1, items[i].Count);
            var dot = new Border { Width = i == _focusIndex ? 18 : 7, Height = 7, CornerRadius = new CornerRadius(4) };
            Ui.Bind(dot, Border.BackgroundProperty, i == _focusIndex || finished ? "AccentBrush" : "DividerBrush");
            if (finished && i != _focusIndex) dot.Opacity = 0.5;
            dots.Children.Add(dot);
        }
        Grid.SetColumn(dots, 1);
        nav.Children.Add(dots);
        var next = Ui.IconButton(L.IsRtl ? "ChevronLeftRegular" : "ChevronRightRegular", L.T("adhkar.next"), () => { _focusIndex = Math.Min(items.Count - 1, _focusIndex + 1); Render(); }, 40, 18);
        next.IsEnabled = _focusIndex < items.Count - 1;
        Grid.SetColumn(next, 2);
        nav.Children.Add(next);
        DockPanel.SetDock(nav, Dock.Bottom);
        page.Children.Add(nav);

        var body = new Grid { RowDefinitions = new RowDefinitions("*,Auto") };
        var text = new StackPanel { Spacing = 14, VerticalAlignment = VerticalAlignment.Center };
        text.Children.Add(ArabicText(item.Arabic, 30));
        if (item.Virtue.Length > 0)
        {
            var virtue = Ui.Text(item.Virtue, 13.5, FontWeight.Normal, "secondary");
            virtue.TextWrapping = TextWrapping.Wrap;
            virtue.FlowDirection = AdhkarLibrary.IsArabic(item.Virtue) ? FlowDirection.RightToLeft : FlowDirection.LeftToRight;
            text.Children.Add(virtue);
        }
        body.Children.Add(new ScrollViewer { Content = text, HorizontalScrollBarVisibility = ScrollBarVisibility.Disabled });
        var controls = new StackPanel { Orientation = Orientation.Horizontal, Spacing = 16, HorizontalAlignment = HorizontalAlignment.Center, Margin = new Thickness(0, 18, 0, 0) };
        controls.Children.Add(CounterButton(_focusIndex, target, small: false));
        if (item.AudioPath is not null)
        {
            var isPlaying = _playing == _focusIndex;
            var play = Ui.IconButton(isPlaying ? "StopFilled" : "PlayFilled", L.T(isPlaying ? "adhkar.stop" : "adhkar.play"), () =>
            {
                if (isPlaying) StopRecitation(); else PlayItem(_focusIndex, all: false);
                Render();
            }, 56, 22);
            play.VerticalAlignment = VerticalAlignment.Center;
            play.CornerRadius = new CornerRadius(28);
            controls.Children.Add(play);
        }
        Grid.SetRow(controls, 1);
        body.Children.Add(controls);
        page.Children.Add(Ui.Card(body, new Thickness(28, 24)));
        return page;
    }

    // ------------------------------------------------------------------ recitation

    void StartPlayAll()
    {
        var first = Items.FindIndex(i => i.AudioPath is not null);
        if (first < 0) return;
        _playAll = true;
        PlayItem(first, all: true);
    }

    void PlayItem(int index, bool all)
    {
        _playAll = all;
        _playing = index;
        if (Mode == 1) _focusIndex = index;
        _state.AdhkarAudio.Play(Items[index].AudioPath, "", 1.0);
    }

    void StopRecitation()
    {
        _playAll = false;
        _playing = -1;
        _state.AdhkarAudio.Stop();
    }

    void OnRecitationFinished()
    {
        if (_playing >= 0 && _playing < Items.Count)
        {
            var counts = Counts;
            counts[_playing] = Math.Max(counts[_playing], Math.Max(1, Items[_playing].Count));
        }
        if (_playAll)
        {
            var next = Items.FindIndex(_playing + 1, i => i.AudioPath is not null);
            if (next >= 0) { PlayItem(next, all: true); Render(); return; }
        }
        _playAll = false;
        _playing = -1;
        Render();
    }
}
