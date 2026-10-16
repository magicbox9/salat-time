using Avalonia;
using Avalonia.Media;
using SalatTime.Core;

namespace SalatTime.Controls;

/// <summary>
/// The 24-hour dial: noon at the top, midnight at the bottom. The ring takes
/// the sky's colour through the day; prayers sit on it, the five prayer
/// windows run inside it, and a hand with the sun or moon points at now.
/// </summary>
public sealed class DialControl : AnimatedCanvas
{
    public AppState? State { get; set; }

    public override void Render(DrawingContext ctx)
    {
        var b = new Rect(Bounds.Size);
        if (State is null || b.Width < 100) return;
        var now = Clock.Now();
        var m = DayModel.For(State.Info, now);
        if (m is null) return;
        var l = Localizer.Shared;
        var s = State.Settings;
        var day = State.Today;
        var accentLight = AppTheme.Pair(s.Accent);
        var accent = AppTheme.IsDark ? accentLight.Dark : accentLight.Light;
        var text = AppTheme.Brush("TextPrimary");
        var secondary = AppTheme.Brush("TextSecondary");

        var radius = Math.Min(b.Width, b.Height) / 2 - 58;
        var center = new Point(b.Width / 2, b.Height / 2);
        const double ring = 26;
        // minute → angle: 0:00 at the bottom, 12:00 at the top, clockwise.
        double Angle(double minute) => Math.PI / 2 + minute / 1440.0 * 2 * Math.PI;
        Point On(double minute, double r) => new(center.X + Math.Cos(Angle(minute)) * r, center.Y + Math.Sin(Angle(minute)) * r);

        // Sky ring.
        const int segments = 288;
        for (int i = 0; i < segments; i++)
        {
            var m0 = i * 1440.0 / segments;
            var pair = LivingSky.At(m0 + 2.5, m);
            var color = LivingSky.Blend(pair.Top, pair.Horizon, 0.45);
            var g = Arc(center, radius, Angle(m0), Angle(m0 + 1440.0 / segments + 0.8));
            ctx.DrawGeometry(null, new Pen(new SolidColorBrush(color), ring, lineCap: PenLineCap.Flat), g);
        }

        // Prayer windows inside the ring.
        var inner = radius - ring / 2 - 12;
        foreach (var (start, end, index) in m.Windows)
        {
            var alpha = index == PrayerClock.Current(State.Info, now) ? 230 : 110;
            var g = Arc(center, inner, Angle(start), Angle(end - 2));
            ctx.DrawGeometry(null, new Pen(new SolidColorBrush(Color.FromArgb((byte)alpha, accent.R, accent.G, accent.B)), 6, lineCap: PenLineCap.Round), g);
        }
        // Discouraged moments as small red marks.
        foreach (var (st, en) in m.Discouraged)
            ctx.DrawGeometry(null, new Pen(new SolidColorBrush(Color.FromArgb(170, 220, 60, 50)), 4, lineCap: PenLineCap.Round), Arc(center, inner - 10, Angle(st), Angle(en)));

        // Hour labels outside the ring.
        for (int h = 0; h < 24; h += 3)
        {
            var p = On(h * 60, radius + ring / 2 + 14);
            var ft = SkyPainter.Label(l.Digits($"{h:00}"), 11, secondary);
            ctx.DrawText(ft, new Point(p.X - ft.Width / 2, p.Y - ft.Height / 2));
        }

        // Prayers on the ring with labels further out.
        var marks = new (double Minute, string Name, string Time, bool Main)[]
        {
            (m.Times[0], l.PrayerName(0), day.Adhan[0], true), (m.Shuruq, l.T("prayer.shuruq"), day.Shuruq, false),
            (m.Times[1], l.PrayerName(1), day.Adhan[1], true), (m.Times[2], l.PrayerName(2), day.Adhan[2], true),
            (m.Times[3], l.PrayerName(3), day.Adhan[3], true), (m.Times[4], l.PrayerName(4), day.Adhan[4], true),
        };
        foreach (var (minute, name, time, main) in marks)
        {
            var p = On(minute, radius);
            ctx.DrawEllipse(Brushes.White, new Pen(new SolidColorBrush(accent), main ? 3 : 1.5), p, main ? 6 : 4, main ? 6 : 4);
            var lp = On(minute, radius + ring / 2 + 40);
            var nameText = SkyPainter.Label(name, 12.5, main ? text : secondary, FontWeight.SemiBold);
            var timeText = SkyPainter.Label(l.Time(time, s.Use12h), 11.5, secondary);
            var w = Math.Max(nameText.Width, timeText.Width);
            ctx.DrawText(nameText, new Point(lp.X - nameText.Width / 2, lp.Y - 16));
            ctx.DrawText(timeText, new Point(lp.X - timeText.Width / 2, lp.Y + 1));
        }

        // Hand to now, with the sun or the moon at its tip.
        var nowMinute = now.Hour * 60 + now.Minute + now.Second / 60.0;
        var tip = On(nowMinute, radius);
        ctx.DrawLine(new Pen(new SolidColorBrush(Color.FromArgb(160, accent.R, accent.G, accent.B)), 2, lineCap: PenLineCap.Round), center, On(nowMinute, radius - ring / 2 - 4));
        ctx.DrawEllipse(new SolidColorBrush(accent), null, center, 5, 5);
        if (nowMinute >= m.Shuruq && nowMinute <= m.Sunset) SkyPainter.Sun(ctx, tip, 12, Time);
        else SkyPainter.Moon(ctx, tip, 12, MoonPhase.At(now), (State.Info.Latitude ?? 45) < 0, Time);

        // Centre: next prayer and countdown.
        if (PrayerClock.Next(State.Info, now) is var (ni, at, _))
        {
            var over = SkyPainter.Label(l.T("label.next_prayer").ToUpper(l.Culture), 11, secondary, FontWeight.SemiBold);
            var name = SkyPainter.Label(l.PrayerName(ni), 20, text, FontWeight.SemiBold);
            var count = SkyPainter.Label(l.Digits(TimeText.Countdown(at - now, true)), 34, new SolidColorBrush(accent), FontWeight.Bold);
            var when = SkyPainter.Label(l.Time(PrayerDay.For(State.Info, at).Adhan[ni], s.Use12h), 13, secondary);
            var y = center.Y - 52;
            ctx.DrawText(over, new Point(center.X - over.Width / 2, y));
            ctx.DrawText(name, new Point(center.X - name.Width / 2, y + 16));
            ctx.DrawText(count, new Point(center.X - count.Width / 2, y + 42));
            ctx.DrawText(when, new Point(center.X - when.Width / 2, y + 86));
        }
    }

    static Geometry Arc(Point c, double r, double a0, double a1)
    {
        var g = new StreamGeometry();
        using var ctx = g.Open();
        var start = new Point(c.X + Math.Cos(a0) * r, c.Y + Math.Sin(a0) * r);
        var end = new Point(c.X + Math.Cos(a1) * r, c.Y + Math.Sin(a1) * r);
        ctx.BeginFigure(start, false);
        var sweep = a1 - a0;
        if (sweep < 0) sweep += 2 * Math.PI;
        ctx.ArcTo(end, new Size(r, r), 0, sweep > Math.PI, SweepDirection.Clockwise);
        ctx.EndFigure(false);
        return g;
    }
}
