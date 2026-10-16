using Avalonia;
using Avalonia.Controls;
using Avalonia.Media;
using Avalonia.Threading;
using SalatTime.Core;

namespace SalatTime.Controls;

/// <summary>A drawn control that animates gently (sun glow, twinkling stars) while it is on screen.</summary>
public abstract class AnimatedCanvas : Control
{
    static readonly DateTime Start = DateTime.UtcNow;
    DispatcherTimer? _timer;
    /// <summary>Seconds since app start (frozen in screenshots).</summary>
    protected double Time => Animate ? (DateTime.UtcNow - Start).TotalSeconds : 0;
    public static bool Animate { get; set; } = true;
    protected virtual TimeSpan FrameInterval => TimeSpan.FromMilliseconds(66);

    // Drawings carry their own text and geometry; never mirror them in Arabic/Urdu.
    protected AnimatedCanvas() => FlowDirection = Avalonia.Media.FlowDirection.LeftToRight;

    protected override void OnAttachedToVisualTree(VisualTreeAttachmentEventArgs e)
    {
        base.OnAttachedToVisualTree(e);
        if (!Animate) return;
        _timer = new DispatcherTimer(FrameInterval, DispatcherPriority.Render, (_, _) => InvalidateVisual());
        _timer.Start();
    }

    protected override void OnDetachedFromVisualTree(VisualTreeAttachmentEventArgs e)
    {
        base.OnDetachedFromVisualTree(e);
        _timer?.Stop();
        _timer = null;
    }
}

/// <summary>
/// The Overview hero: the sky of the moment, the sun's path from sunrise to
/// sunset with the prayers marked on it, the sun (or the moon in its phase)
/// where it is now, and stars after dark.
/// </summary>
public sealed class SkyHero : AnimatedCanvas
{
    public AppState? State { get; set; }
    public double CornerRadius { get; set; } = 12;

    public override void Render(DrawingContext ctx)
    {
        var bounds = new Rect(Bounds.Size);
        if (State is null || bounds.Width < 10) return;
        var now = Clock.Now();
        var model = DayModel.For(State.Info, now);
        var minute = now.Hour * 60 + now.Minute + now.Second / 60.0;
        var pair = model is null ? LivingSky.Night : LivingSky.At(minute, model);
        using var clip = ctx.PushClip(new RoundedRect(bounds, CornerRadius));
        SkyPainter.FillSky(ctx, bounds, pair, CornerRadius);
        if (model is null) return;

        var darkness = LivingSky.Darkness(minute, model);
        SkyPainter.Stars(ctx, new Rect(0, 0, bounds.Width, bounds.Height * 0.7), 70, 4.2, Time, darkness * 0.9);

        // The sun's path: a half ellipse from sunrise (left) to sunset (right), on the right half of the hero.
        var arcX = Localizer.Shared.IsRtl ? bounds.Width * 0.06 : bounds.Width * 0.46;
        var arc = new Rect(arcX, bounds.Height * 0.22, bounds.Width * 0.48, bounds.Height * 0.62);
        var horizonY = arc.Bottom;
        var path = new StreamGeometry();
        using (var g = path.Open())
        {
            for (int i = 0; i <= 64; i++)
            {
                var p = ArcPoint(arc, i / 64.0);
                if (i == 0) g.BeginFigure(p, false); else g.LineTo(p);
            }
            g.EndFigure(false);
        }
        var light = darkness < 0.5;
        var ink = light ? Color.FromArgb(150, 255, 255, 255) : Color.FromArgb(110, 255, 255, 255);
        ctx.DrawGeometry(null, new Pen(new SolidColorBrush(ink), 1.4, new DashStyle(new double[] { 2, 3 }, 0)), path);
        ctx.DrawLine(new Pen(new SolidColorBrush(Color.FromArgb(70, 255, 255, 255)), 1), new Point(arc.X - 18, horizonY), new Point(arc.Right + 18, horizonY));

        // Prayer marks that fall in daylight (Dhuhr, Asr) plus sunrise and Maghrib at the ends.
        var labels = new (int Minute, string Text)[]
        {
            (model.Shuruq, Localizer.Shared.T("prayer.shuruq")),
            (model.Times[1], Localizer.Shared.PrayerName(1)),
            (model.Times[2], Localizer.Shared.PrayerName(2)),
            (model.Times[3], Localizer.Shared.PrayerName(3)),
        };
        foreach (var (m, text) in labels)
        {
            var f = (m - model.Shuruq) / (double)Math.Max(1, model.Sunset - model.Shuruq);
            if (f < -0.02 || f > 1.02) continue;
            var p = ArcPoint(arc, Math.Clamp(f, 0, 1));
            ctx.DrawEllipse(new SolidColorBrush(Color.FromArgb(220, 255, 255, 255)), null, p, 3, 3);
            var ft = SkyPainter.Label(text, 11, new SolidColorBrush(Color.FromArgb(220, 255, 255, 255)), FontWeight.Medium);
            // Ends sit under the horizon; Dhuhr and Asr go inside the arc so the sun never covers them.
            var atEnd = f is < 0.08 or > 0.92;
            ctx.DrawText(ft, new Point(p.X - ft.Width / 2, atEnd ? horizonY + 6 : p.Y + 9));
        }

        // Sun by day, moon by night (along a lower, flatter night arc).
        var dayFraction = (minute - model.Shuruq) / Math.Max(1, model.Sunset - model.Shuruq);
        if (dayFraction is >= 0 and <= 1)
        {
            SkyPainter.Sun(ctx, ArcPoint(arc, dayFraction), Math.Max(9, bounds.Height * 0.055), Time);
        }
        else
        {
            var nightStart = model.Sunset;
            var nightMinute = minute >= nightStart ? minute - nightStart : minute + 1440 - nightStart;
            var nf = Math.Clamp(nightMinute / Math.Max(1, model.NightLength), 0, 1);
            var nightArc = new Rect(arc.X, arc.Y + arc.Height * 0.1, arc.Width, arc.Height * 0.85);
            var lat = State.Info.Latitude ?? 45;
            SkyPainter.Moon(ctx, ArcPoint(nightArc, nf), Math.Max(10, bounds.Height * 0.06), MoonPhase.At(Clock.Now()), lat < 0, Time);
        }
    }

    /// <summary>Point on the half ellipse: 0 = left end (horizon), 0.5 = top, 1 = right end.</summary>
    static Point ArcPoint(Rect r, double f)
    {
        var angle = Math.PI * (1 - f);
        return new Point(r.Center.X + Math.Cos(angle) * r.Width / 2, r.Bottom - Math.Sin(angle) * r.Height);
    }
}
