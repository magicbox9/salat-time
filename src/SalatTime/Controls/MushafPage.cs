using System.Globalization;
using Avalonia;
using Avalonia.Controls;
using Avalonia.Input;
using Avalonia.Media;
using SalatTime.Core;

namespace SalatTime.Controls;

/// <summary>
/// One Mushaf page drawn like the print: 15 lines, each verse's words placed
/// within the lines the corpus says it occupies, lines justified word by
/// word, surah banners and the basmala in the gaps the print leaves — the
/// same planning approach as the Mac reader.
/// </summary>
public sealed class MushafPage : Control
{
    public QuranEdition? Edition { get; set; }
    public int PageNumber { get; set; } = 1;
    public FontFamily ScriptFont { get; set; } = FontFamily.Default;
    public bool Night { get; set; }
    public (int Sura, int Ayah)? Highlight { get; set; }
    public event Action<Ayah>? AyahClicked;

    readonly List<(Rect Rect, Ayah Ayah)> _hit = new();

    // The page lays out its own right-to-left lines; never mirror the drawing.
    public MushafPage() => FlowDirection = FlowDirection.LeftToRight;

    sealed record Token(string Text, Ayah Ayah, int Lo, int Hi, double Width);

    sealed class Plan
    {
        public Dictionary<int, List<Token>> Lines = new();
        public Dictionary<int, string> Banners = new();
        public HashSet<int> Basmala = new();
        public int MaxLine = 15;
    }

    Plan? _plan;
    string _planKey = "";

    static Color Hex(uint argb) => Color.FromUInt32(argb);
    Color Paper => Night ? Hex(0xFF171A21) : Hex(0xFFFBF6E8);
    Color Ink => Night ? Hex(0xFFEAE4D6) : Hex(0xFF1E1912);
    Color Gold => Night ? Hex(0xFF8F7A52) : Hex(0xFFB38E52);

    protected override Size MeasureOverride(Size availableSize)
    {
        var w = double.IsInfinity(availableSize.Width) ? 520 : availableSize.Width;
        return new Size(w, w * 1.42);
    }

    protected override void OnPointerPressed(PointerPressedEventArgs e)
    {
        base.OnPointerPressed(e);
        var p = e.GetPosition(this);
        foreach (var (rect, ayah) in _hit)
            if (rect.Contains(p)) { AyahClicked?.Invoke(ayah); return; }
    }

    const double RefSize = 24;

    Typeface Face => new(ScriptFont);

    double Measure(string text, double size) =>
        new FormattedText(text, CultureInfo.InvariantCulture, FlowDirection.RightToLeft, Face, size, Brushes.Black).WidthIncludingTrailingWhitespace;

    Plan Build()
    {
        var key = $"{Edition?.Key}|{PageNumber}|{ScriptFont}";
        if (_plan is not null && key == _planKey) return _plan;
        var plan = new Plan();
        if (Edition is null) return plan;
        var verses = Edition.Page(PageNumber).ToList();
        var tokens = new List<Token>();
        var bodyLines = new SortedSet<int>();
        var previousEnd = 0;
        foreach (var v in verses)
        {
            var start = Math.Max(1, v.LineStart);
            var end = v.LineEnd >= start ? v.LineEnd : 15;
            for (int l = start; l <= end; l++) bodyLines.Add(l);
            if (v.Number == 1)
            {
                // The print leaves exactly the banner (and bismillah) lines empty above a surah.
                var gap = start - previousEnd - 1;
                if (gap >= 1) plan.Banners[start - gap] = v.SuraNameAr.Trim();
                if (gap >= 2 && !(v.Sura == 1 || v.Sura == 9)) plan.Basmala.Add(start - 1);
            }
            previousEnd = Math.Max(previousEnd, end);

            var words = v.Text.Split(' ', StringSplitOptions.RemoveEmptyEntries).ToList();
            // Keep the verse-end sign attached to its last word.
            if (words.Count >= 2 && words[^1].Length <= 2 && words[^1].All(c => c is >= 'ﭐ' and <= '﷿' or >= 'ﹰ' and <= '﻿' || char.IsDigit(c)))
            {
                words[^2] += " " + words[^1];
                words.RemoveAt(words.Count - 1);
            }
            for (int i = 0; i < words.Count; i++)
            {
                int lo, hi;
                if (start == end || words.Count == 1) { lo = hi = start; }
                else if (i == 0) { lo = hi = start; }
                else if (i == words.Count - 1) { lo = hi = end; }
                else { lo = start; hi = end; }
                tokens.Add(new Token(words[i], v, lo, hi, Measure(words[i], RefSize)));
            }
        }
        plan.MaxLine = Math.Max(15, previousEnd);

        // Distribute words over the body lines: fill each line to an even share,
        // never placing a word outside its verse's printed line window.
        var space = Measure(" ", RefSize);
        var lines = bodyLines.ToList();
        var total = tokens.Sum(t => t.Width + space);
        var target = lines.Count > 0 ? total / lines.Count : total;
        var li = 0;
        var used = 0.0;
        for (int i = 0; i < tokens.Count; i++)
        {
            var t = tokens[i];
            while (li < lines.Count - 1 && lines[li] < t.Lo) { li++; used = 0; }
            var remainingTokens = tokens.Count - i;
            var remainingLines = lines.Count - li;
            if (used > 0 && used + t.Width > target * 1.04 && li < lines.Count - 1 && lines[li + 1] <= t.Hi && remainingTokens >= remainingLines)
            {
                li++;
                used = 0;
            }
            var line = lines.Count == 0 ? t.Lo : lines[li];
            if (!plan.Lines.TryGetValue(line, out var list)) plan.Lines[line] = list = new();
            list.Add(t);
            used += t.Width + space;
        }
        _planKey = key;
        return _plan = plan;
    }

    public override void Render(DrawingContext ctx)
    {
        var b = new Rect(Bounds.Size);
        if (Edition is null || b.Width < 100) return;
        _hit.Clear();
        var plan = Build();

        // Paper and frame.
        ctx.DrawRectangle(new SolidColorBrush(Paper), new Pen(new SolidColorBrush(GoldA(0.35)), 1), new RoundedRect(b.Deflate(0.5), 10));
        var frame = b.Deflate(new Thickness(18, 34, 18, 34));
        ctx.DrawRectangle(null, new Pen(new SolidColorBrush(Gold), 1.6), new RoundedRect(frame, 4));
        ctx.DrawRectangle(null, new Pen(new SolidColorBrush(GoldA(0.6)), 0.8), new RoundedRect(frame.Deflate(4), 2));

        // Header: surah name (right) and juz (left); page number below.
        var first = Edition.Page(PageNumber).FirstOrDefault();
        if (first is not null)
        {
            var headerBrush = new SolidColorBrush(GoldA(0.85));
            var sura = Text(first.SuraNameAr.Trim(), 15, headerBrush, FlowDirection.RightToLeft);
            ctx.DrawText(sura, new Point(frame.Right - sura.Width - 6, 9));
            var juz = Text(Localizer.Shared.Digits($"{Localizer.Shared.T("win:quran.juz")} {first.Juz}"), 13, headerBrush, FlowDirection.LeftToRight, AppTheme.Font);
            ctx.DrawText(juz, new Point(frame.X + 6, 11));
        }
        var pageNo = Text(Localizer.Shared.Digits(PageNumber.ToString(CultureInfo.InvariantCulture)), 13, new SolidColorBrush(GoldA(0.85)), FlowDirection.LeftToRight, AppTheme.Font);
        var pc = new Point(b.Center.X, b.Bottom - 17);
        ctx.DrawEllipse(null, new Pen(new SolidColorBrush(Gold), 1), pc, 13, 11);
        ctx.DrawText(pageNo, new Point(pc.X - pageNo.Width / 2, pc.Y - pageNo.Height / 2));

        // Lines.
        var inner = frame.Deflate(new Thickness(16, 10, 16, 10));
        var lineCount = plan.MaxLine;
        var lineH = inner.Height / lineCount;
        var space = Measure(" ", RefSize);
        var widest = plan.Lines.Values.Select(l => l.Sum(t => t.Width) + space * Math.Max(0, l.Count - 1)).DefaultIfEmpty(1).Max();
        var size = Math.Min(RefSize * inner.Width / Math.Max(1, widest) * 0.985, lineH * 0.62);
        var scale = size / RefSize;
        var ink = new SolidColorBrush(Ink);
        var centered = PageNumber <= 2;

        foreach (var (line, label) in plan.Banners) DrawBanner(ctx, new Rect(inner.X, inner.Y + (line - 1) * lineH, inner.Width, lineH), label, size);
        foreach (var line in plan.Basmala)
        {
            var basmala = BasmalaText(Edition);
            var ft = Text(basmala, size * 0.95, ink, FlowDirection.RightToLeft);
            ctx.DrawText(ft, new Point(inner.Center.X - ft.Width / 2, inner.Y + (line - 1) * lineH + (lineH - ft.Height) / 2));
        }

        var lastBodyLine = plan.Lines.Keys.DefaultIfEmpty(0).Max();
        foreach (var (line, tokens) in plan.Lines.OrderBy(k => k.Key))
        {
            var y = inner.Y + (line - 1) * lineH;
            var widths = tokens.Select(t => t.Width * scale).ToList();
            var natural = widths.Sum() + space * scale * (tokens.Count - 1);
            // Justify full lines; a surah's or the page's short last line is centred.
            var nextIsBanner = plan.Banners.ContainsKey(line + 1) || plan.Basmala.Contains(line + 1);
            var justify = !centered && tokens.Count > 1 && !(natural < inner.Width * 0.8 && (line == lastBodyLine || nextIsBanner));
            var gap = justify ? (inner.Width - widths.Sum()) / (tokens.Count - 1) : space * scale;
            var x = justify ? inner.Right : inner.Center.X + natural / 2;
            for (int i = 0; i < tokens.Count; i++)
            {
                var t = tokens[i];
                var ft = Text(t.Text, size, ink, FlowDirection.RightToLeft);
                var rect = new Rect(x - widths[i], y, widths[i], lineH);
                if (Highlight is var (hs, ha) && t.Ayah.Sura == hs && t.Ayah.Number == ha)
                    ctx.DrawRectangle(new SolidColorBrush(Color.FromArgb(Night ? (byte)60 : (byte)45, Gold.R, Gold.G, Gold.B)), null, new RoundedRect(rect.Inflate(new Thickness(gap / 2, -lineH * 0.12)), 4));
                ctx.DrawText(ft, new Point(x - ft.WidthIncludingTrailingWhitespace, y + (lineH - ft.Height) / 2));
                _hit.Add((rect, t.Ayah));
                x -= widths[i] + gap;
            }
        }
    }

    /// <summary>
    /// The basmala shown above surahs: the publisher's own text in the
    /// riwayah's orthography, taken from the basmala inside 27:30 (Warsh does
    /// not number Al-Fatiha's basmala) — the same source as the Mac reader.
    /// </summary>
    public static string BasmalaText(QuranEdition edition)
    {
        if (edition.Find(27, 30)?.Text is not string verse) return "";
        var text = QuranEdition.StripAyahMarkers(verse);
        for (int i = 0; i + 2 < text.Length; i++)
            if (text[i] == '\u0628' && text[i + 1] == '\u0650' && text[i + 2] == '\u0633') return text[i..].Trim();
        return "";
    }

    void DrawBanner(DrawingContext ctx, Rect r, string name, double size)
    {
        var band = new Rect(r.X + r.Width * 0.08, r.Y + r.Height * 0.12, r.Width * 0.84, r.Height * 0.76);
        ctx.DrawRectangle(new SolidColorBrush(GoldA(0.12)), new Pen(new SolidColorBrush(Gold), 1.2), new RoundedRect(band, band.Height / 2));
        ctx.DrawRectangle(null, new Pen(new SolidColorBrush(GoldA(0.5)), 0.6), new RoundedRect(band.Deflate(3), band.Height / 2 - 3));
        var label = Text($"سُورَةُ {name}", size * 0.8, new SolidColorBrush(Ink), FlowDirection.RightToLeft, AppTheme.Cairo);
        ctx.DrawText(label, new Point(band.Center.X - label.Width / 2, band.Center.Y - label.Height / 2));
    }

    Color GoldA(double alpha) => Color.FromArgb((byte)(alpha * 255), Gold.R, Gold.G, Gold.B);

    FormattedText Text(string text, double size, IBrush brush, FlowDirection direction, FontFamily? family = null) =>
        new(text, CultureInfo.InvariantCulture, direction, family is null ? Face : new Typeface(family), size, brush);
}
