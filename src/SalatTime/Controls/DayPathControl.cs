using Avalonia;
using Avalonia.Media;
using SalatTime.Core;

namespace SalatTime.Controls;

/// <summary>
/// The day as one landscape: the sky's colour hour by hour, the sun's path
/// above the horizon (and the moon's below), the prayers, iqamas, the
/// discouraged moments and the last third of the night, with "now" marked.
/// </summary>
public sealed class DayPathControl : AnimatedCanvas
{
    public AppState? State { get; set; }

    public override void Render(DrawingContext ctx)
    {
        var b = new Rect(Bounds.Size);
        if (State is null || b.Width < 50) return;
        var now = Clock.Now();
        var m = DayModel.For(State.Info, now);
        if (m is null) return;
        var l = Localizer.Shared;
        var use12h = State.Settings.Use12h;
        var day = State.Today;

        const double padX = 28;
        var skyTop = 0.0;
        var horizon = b.Height * 0.60;
        var labelsTop = b.Height * 0.66;
        double X(double minute) => padX + (b.Width - 2 * padX) * (minute / 1440.0);

        // Sky: vertical strips coloured by the time of day.
        var step = 6.0;
        for (double x = 0; x < b.Width; x += step)
        {
            var minute = Math.Clamp((x - padX) / (b.Width - 2 * padX) * 1440, 0, 1440);
            var pair = LivingSky.At(minute, m);
            var brush = new LinearGradientBrush
            {
                StartPoint = new RelativePoint(0, 0, RelativeUnit.Relative),
                EndPoint = new RelativePoint(0, 1, RelativeUnit.Relative),
                GradientStops = { new GradientStop(pair.Top, 0), new GradientStop(pair.Horizon, 1) },
            };
            ctx.DrawRectangle(brush, null, new Rect(x, skyTop, step + 0.6, horizon - skyTop));
            var ground = LivingSky.Blend(pair.Horizon, Color.FromRgb(12, 14, 26), 0.82);
            ctx.DrawRectangle(new SolidColorBrush(ground), null, new Rect(x, horizon, step + 0.6, b.Height - horizon));
        }
        SkyPainter.Stars(ctx, new Rect(0, 0, X(m.Times[0]), horizon * 0.85), 40, 2.1, Time, 0.85);
        SkyPainter.Stars(ctx, new Rect(X(m.Times[4]), 0, b.Width - X(m.Times[4]), horizon * 0.85), 40, 7.7, Time, 0.85);

        var white = Color.FromArgb(235, 255, 255, 255);
        var faint = Color.FromArgb(120, 255, 255, 255);

        // Last third of the night (wraps past midnight) and discouraged windows.
        var thirdBrush = new SolidColorBrush(Color.FromArgb(70, 120, 140, 255));
        // The night's last third ends at Fajr; it starts after midnight, or before it in short nights.
        var thirdStart = m.LastThird < m.Times[0] ? m.LastThird : 0;
        ctx.DrawRectangle(thirdBrush, null, new Rect(X(thirdStart), 0, X(m.Times[0]) - X(thirdStart), horizon));
        if (m.LastThird > m.Times[0]) ctx.DrawRectangle(thirdBrush, null, new Rect(X(m.LastThird), 0, X(1440) - X(m.LastThird), horizon));
        foreach (var (s, e) in m.Discouraged)
            ctx.DrawRectangle(new SolidColorBrush(Color.FromArgb(80, 220, 60, 50)), null, new Rect(X(s), horizon - 10, Math.Max(2, X(e) - X(s)), 10));

        // Sun path: a sine bump between sunrise and sunset; dotted below the horizon at night.
        var amp = horizon * 0.78;
        double SunY(double minute)
        {
            var f = (minute - m.Shuruq) / Math.Max(1, m.DayLength);
            if (f is >= 0 and <= 1) return horizon - Math.Sin(Math.PI * f) * amp;
            var night = minute > m.Sunset ? minute - m.Sunset : minute + 1440 - m.Sunset;
            var nf = Math.Clamp(night / Math.Max(1, m.NightLength), 0, 1);
            return horizon + Math.Sin(Math.PI * nf) * (b.Height - horizon) * 0.35;
        }
        var dayPath = new StreamGeometry();
        using (var g = dayPath.Open())
        {
            for (int i = 0; i <= 80; i++)
            {
                var minute = m.Shuruq + m.DayLength * i / 80.0;
                var p = new Point(X(minute), SunY(minute));
                if (i == 0) g.BeginFigure(p, false); else g.LineTo(p);
            }
            g.EndFigure(false);
        }
        ctx.DrawGeometry(null, new Pen(new SolidColorBrush(Color.FromArgb(170, 255, 236, 190)), 1.6, new DashStyle(new double[] { 3, 3 }, 0)), dayPath);
        ctx.DrawLine(new Pen(new SolidColorBrush(Color.FromArgb(90, 255, 255, 255)), 1), new Point(0, horizon), new Point(b.Width, horizon));

        // Prayers: a mark on the horizon, label and time underneath; iqama as a small dot.
        var marks = new List<(double Minute, string Name, string Time, string? Iqama)>
        {
            (m.Times[0], l.PrayerName(0), day.Adhan[0], day.Iqama[0]),
            (m.Shuruq, l.T("prayer.shuruq"), day.Shuruq, null),
            (m.Times[1], l.PrayerName(1), day.Adhan[1], day.Iqama[1]),
            (m.Times[2], l.PrayerName(2), day.Adhan[2], day.Iqama[2]),
            (m.Times[3], l.PrayerName(3), day.Adhan[3], day.Iqama[3]),
            (m.Times[4], l.PrayerName(4), day.Adhan[4], day.Iqama[4]),
        };
        var accent = AppTheme.Pair(State.Settings.Accent).Dark;
        var lastLabelRight = double.MinValue;
        var row = 0;
        foreach (var (minute, name, time, iqama) in marks)
        {
            var x = X(minute);
            var isShuruq = name == l.T("prayer.shuruq");
            ctx.DrawLine(new Pen(new SolidColorBrush(isShuruq ? faint : Color.FromArgb(200, accent.R, accent.G, accent.B)), isShuruq ? 1 : 2), new Point(x, horizon - 14), new Point(x, labelsTop - 4));
            ctx.DrawEllipse(new SolidColorBrush(isShuruq ? faint : accent), null, new Point(x, horizon), isShuruq ? 3 : 5, isShuruq ? 3 : 5);
            if (iqama is not null && TimeText.Minutes(iqama) is int iq)
                ctx.DrawEllipse(new SolidColorBrush(faint), null, new Point(X(iq), horizon), 2.5, 2.5);

            var nameText = SkyPainter.Label(name, 13, new SolidColorBrush(white), FontWeight.SemiBold);
            var timeText = SkyPainter.Label(l.Time(time, use12h), 12, new SolidColorBrush(faint));
            var w = Math.Max(nameText.Width, timeText.Width);
            row = x - w / 2 < lastLabelRight + 6 ? 1 - row : 0;
            var y = labelsTop + row * 38;
            var lx = Math.Clamp(x - w / 2, 4, b.Width - w - 4);
            ctx.DrawText(nameText, new Point(lx + (w - nameText.Width) / 2, y));
            ctx.DrawText(timeText, new Point(lx + (w - timeText.Width) / 2, y + 17));
            lastLabelRight = lx + w;
        }

        // Hour ticks.
        for (int h = 0; h <= 24; h += 3)
        {
            var x = X(h * 60);
            var ft = SkyPainter.Label(l.Digits($"{h % 24:00}"), 10.5, new SolidColorBrush(Color.FromArgb(110, 255, 255, 255)));
            ctx.DrawText(ft, new Point(Math.Clamp(x - ft.Width / 2, 2, b.Width - ft.Width - 2), b.Height - ft.Height - 6));
        }

        // Now: a vertical line with the sun (day) or moon (night).
        var nowMinute = now.Hour * 60 + now.Minute + now.Second / 60.0;
        var nx = X(nowMinute);
        ctx.DrawLine(new Pen(new SolidColorBrush(Color.FromArgb(150, 255, 255, 255)), 1, new DashStyle(new double[] { 2, 2 }, 0)), new Point(nx, 0), new Point(nx, b.Height - 22));
        var body = new Point(nx, SunY(nowMinute));
        if (nowMinute >= m.Shuruq && nowMinute <= m.Sunset) SkyPainter.Sun(ctx, body, 11, Time);
        else SkyPainter.Moon(ctx, new Point(nx, Math.Min(body.Y, horizon - 30)), 11, MoonPhase.At(now), (State.Info.Latitude ?? 45) < 0, Time);
        var nowLabel = SkyPainter.Label(l.F("view:now", l.Time(TimeText.Clock((int)nowMinute), use12h)), 11.5, new SolidColorBrush(white), FontWeight.SemiBold);
        ctx.DrawText(nowLabel, new Point(Math.Clamp(nx + 8, 4, b.Width - nowLabel.Width - 4), 10));
    }
}
