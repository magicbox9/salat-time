using Avalonia;
using Avalonia.Media;
using SalatTime.Core;

namespace SalatTime.Controls;

/// <summary>Draws the living sky: gradient, sun with glow and rays, the moon in its real phase, stars.</summary>
public static class SkyPainter
{
    static Color C(double r, double g, double b, double a = 1) => Color.FromArgb((byte)(a * 255), (byte)(r * 255), (byte)(g * 255), (byte)(b * 255));

    public static void FillSky(DrawingContext ctx, Rect rect, LivingSky.Pair pair, double radius = 0)
    {
        var brush = new LinearGradientBrush
        {
            StartPoint = new RelativePoint(0, 0, RelativeUnit.Relative),
            EndPoint = new RelativePoint(0, 1, RelativeUnit.Relative),
            GradientStops =
            {
                new GradientStop(pair.Top, 0),
                new GradientStop(LivingSky.Blend(pair.Top, pair.Horizon, 0.5), 0.55),
                new GradientStop(pair.Horizon, 1),
            },
        };
        ctx.DrawRectangle(brush, null, new RoundedRect(rect, radius));
    }

    /// <summary>Soft radial glow drawn as stacked translucent discs (no shader needed).</summary>
    public static void Glow(DrawingContext ctx, Point center, double radius, Color color, double alpha)
    {
        const int steps = 10;
        for (int i = steps; i >= 1; i--)
        {
            var t = i / (double)steps;
            var a = alpha * (1 - t) * (1 - t) * 0.5;
            ctx.DrawEllipse(new SolidColorBrush(Color.FromArgb((byte)(a * 255), color.R, color.G, color.B)), null, center, radius * t, radius * t);
        }
    }

    public static void Sun(DrawingContext ctx, Point center, double r, double time, double alpha = 1)
    {
        var pulse = 1 + 0.07 * Math.Sin(time * 1.3);
        Glow(ctx, center, r * 3.4 * pulse, C(1.0, 0.82, 0.45), 0.95 * alpha);
        const int rays = 14;
        for (int i = 0; i < rays; i++)
        {
            var angle = time * 0.12 + i * 2 * Math.PI / rays;
            var isLong = i % 2 == 0;
            var inner = r * 1.35;
            var outer = r * (isLong ? 2.15 : 1.75) * pulse;
            var pen = new Pen(new SolidColorBrush(C(1.0, 0.85, 0.5, (isLong ? 0.55 : 0.35) * alpha)), isLong ? 1.6 : 1.1, lineCap: PenLineCap.Round);
            ctx.DrawLine(pen, new Point(center.X + Math.Cos(angle) * inner, center.Y + Math.Sin(angle) * inner),
                              new Point(center.X + Math.Cos(angle) * outer, center.Y + Math.Sin(angle) * outer));
        }
        var core = new RadialGradientBrush
        {
            GradientOrigin = new RelativePoint(0.35, 0.3, RelativeUnit.Relative),
            Center = new RelativePoint(0.4, 0.35, RelativeUnit.Relative),
            GradientStops = { new GradientStop(C(1.0, 0.98, 0.88, alpha), 0), new GradientStop(C(1.0, 0.80, 0.38, alpha), 1) },
        };
        ctx.DrawEllipse(core, null, center, r, r);
    }

    public static void Moon(DrawingContext ctx, Point center, double r, MoonPhase phase, bool southern = false, double time = 0)
    {
        Glow(ctx, center, r * (2.7 + 0.12 * Math.Sin(time * 0.9)), Colors.White, 0.5 * (0.3 + phase.Illumination));
        ctx.DrawEllipse(new SolidColorBrush(C(0.20, 0.22, 0.32, 0.8)), null, center, r, r);

        var theta = 2 * Math.PI * phase.Fraction;
        var a = r * Math.Cos(theta);
        var litOnRight = phase.Waxing ^ southern;
        var side = litOnRight ? 1 : -1;
        var lit = new StreamGeometry();
        using (var g = lit.Open())
        {
            const int steps = 48;
            for (int s = 0; s <= steps; s++)   // lit limb, top → bottom
            {
                var psi = s / (double)steps * Math.PI;
                var p = new Point(center.X + side * r * Math.Sin(psi), center.Y - r * Math.Cos(psi));
                if (s == 0) g.BeginFigure(p, true); else g.LineTo(p);
            }
            for (int s = steps; s >= 0; s--)   // terminator, bottom → top
            {
                var psi = s / (double)steps * Math.PI;
                g.LineTo(new Point(center.X + side * a * Math.Sin(psi), center.Y - r * Math.Cos(psi)));
            }
            g.EndFigure(true);
        }
        using (ctx.PushGeometryClip(lit))
        {
            var face = new LinearGradientBrush
            {
                StartPoint = new RelativePoint(litOnRight ? 1 : 0, 0.5, RelativeUnit.Relative),
                EndPoint = new RelativePoint(litOnRight ? 0 : 1, 0.5, RelativeUnit.Relative),
                GradientStops = { new GradientStop(C(0.99, 0.97, 0.90), 0), new GradientStop(C(0.86, 0.83, 0.74), 1) },
            };
            ctx.DrawEllipse(face, null, center, r, r);
            var maria = new SolidColorBrush(C(0.55, 0.53, 0.48, 0.22));
            foreach (var (dx, dy, s) in new[] { (-0.25, -0.2, 0.28), (0.18, 0.12, 0.22), (-0.05, 0.38, 0.16), (0.35, -0.3, 0.14), (-0.4, 0.2, 0.12) })
                ctx.DrawEllipse(maria, null, new Point(center.X + dx * r, center.Y + dy * r), s * r, s * r);
        }
    }

    public static void Stars(DrawingContext ctx, Rect rect, int count, double seed, double time, double alpha, Func<Point, bool>? avoid = null)
    {
        if (alpha <= 0.02) return;
        static double Hash(double v) { var x = Math.Sin(v) * 43_758.5453; return x - Math.Floor(x); }
        for (int i = 0; i < count; i++)
        {
            var p = new Point(rect.X + Hash(i * 12.9898 + seed) * rect.Width, rect.Y + Hash(i * 78.233 + seed) * rect.Height);
            if (avoid?.Invoke(p) == true) continue;
            var size = 0.6 + Hash(i * 3.7 + seed) * 1.3;
            var twinkle = 0.55 + 0.45 * Math.Sin(time * (0.7 + Hash(i + seed) * 1.6) + i);
            ctx.DrawEllipse(new SolidColorBrush(Color.FromArgb((byte)(255 * alpha * (0.35 + 0.65 * twinkle)), 255, 255, 255)), null, p, size / 2, size / 2);
        }
    }

    public static FormattedText Label(string text, double size, IBrush brush, FontWeight weight = FontWeight.Normal) =>
        new(text, Localizer.Shared.Culture, FlowDirection.LeftToRight,
            new Typeface(AppTheme.Font, FontStyle.Normal, weight), size, brush);
}
