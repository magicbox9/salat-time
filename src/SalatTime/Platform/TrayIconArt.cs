using System.Globalization;
using System.Runtime.InteropServices;
using Avalonia;
using Avalonia.Media;
using Avalonia.Media.Imaging;
using Avalonia.Platform;

namespace SalatTime.Platform;

/// <summary>
/// Draws the tray icons: a small accent tile with the crescent (idle), with the
/// minutes left (last hour before the adhan), red during adhan → iqama, and a
/// red stop button while the adhan plays.
/// </summary>
public static class TrayIconArt
{
    // ------------------------------------------------------------------ drawings (cross-platform)

    public static RenderTargetBitmap DrawAppIcon(int size, Color accent) => Draw(size, ctx =>
    {
        var s = (double)size;
        DrawTile(ctx, s, accent);
        // Crescent: a disc with an offset disc removed, plus a small star.
        var r = s * 0.30;
        var c = new Point(s * 0.46, s * 0.52);
        var outer = new EllipseGeometry(new Rect(c.X - r, c.Y - r, r * 2, r * 2));
        var inner = new EllipseGeometry(new Rect(c.X - r * 0.55, c.Y - r * 1.12, r * 1.95, r * 1.95));
        var crescent = new CombinedGeometry(GeometryCombineMode.Exclude, outer, inner);
        ctx.DrawGeometry(Brushes.White, null, crescent);
        DrawStar(ctx, new Point(s * 0.70, s * 0.36), s * 0.11);
    });

    public static RenderTargetBitmap DrawNumber(int size, int minutes, Color background) => Draw(size, ctx =>
    {
        var s = (double)size;
        DrawTile(ctx, s, background);
        var text = Math.Clamp(minutes, 0, 99).ToString(CultureInfo.InvariantCulture);
        var em = s * (text.Length > 1 ? 0.66 : 0.74);
        var typeface = new Typeface(new FontFamily("Segoe UI Variable Display, Segoe UI, Arial"), FontStyle.Normal, FontWeight.Bold);
        var ft = new FormattedText(text, CultureInfo.InvariantCulture, FlowDirection.LeftToRight, typeface, em, Brushes.White);
        // Tighten two digits so they stay readable at 16 px.
        if (text.Length > 1) ft.SetFontWeight(FontWeight.SemiBold);
        ctx.DrawText(ft, new Point((s - ft.Width) / 2, (s - ft.Height) / 2 - s * 0.02));
    });

    public static RenderTargetBitmap DrawStop(int size) => Draw(size, ctx =>
    {
        var s = (double)size;
        ctx.DrawEllipse(new SolidColorBrush(Color.FromRgb(196, 43, 28)), null, new Point(s / 2, s / 2), s * 0.47, s * 0.47);
        var q = s * 0.30;
        ctx.DrawRectangle(Brushes.White, null, new RoundedRect(new Rect((s - q) / 2, (s - q) / 2, q, q), s * 0.05));
    });

    static void DrawTile(DrawingContext ctx, double s, Color color)
    {
        var top = Color.FromRgb((byte)Math.Min(255, color.R + 18), (byte)Math.Min(255, color.G + 18), (byte)Math.Min(255, color.B + 18));
        var brush = new LinearGradientBrush
        {
            StartPoint = new RelativePoint(0, 0, RelativeUnit.Relative),
            EndPoint = new RelativePoint(0, 1, RelativeUnit.Relative),
            GradientStops = { new GradientStop(top, 0), new GradientStop(color, 1) },
        };
        ctx.DrawRectangle(brush, null, new RoundedRect(new Rect(0.5, 0.5, s - 1, s - 1), s * 0.22));
    }

    static void DrawStar(DrawingContext ctx, Point c, double r)
    {
        var g = new StreamGeometry();
        using (var g2 = g.Open())
        {
            for (int i = 0; i < 8; i++)
            {
                var a = Math.PI / 4 * i - Math.PI / 2;
                var rr = i % 2 == 0 ? r : r * 0.38;
                var p = new Point(c.X + Math.Cos(a) * rr, c.Y + Math.Sin(a) * rr);
                if (i == 0) g2.BeginFigure(p, true); else g2.LineTo(p);
            }
            g2.EndFigure(true);
        }
        ctx.DrawGeometry(Brushes.White, null, g);
    }

    static RenderTargetBitmap Draw(int size, Action<DrawingContext> paint)
    {
        var rtb = new RenderTargetBitmap(new PixelSize(size, size), new Vector(96, 96));
        using (var ctx = rtb.CreateDrawingContext()) paint(ctx);
        return rtb;
    }

    // ------------------------------------------------------------------ HICON (Windows)

    public static IntPtr AppIcon(int size, Color accent) => ToHIcon(DrawAppIcon(size, accent));
    public static IntPtr Number(int size, int minutes, Color background) => ToHIcon(DrawNumber(size, minutes, background));
    public static IntPtr Stop(int size) => ToHIcon(DrawStop(size));

    static IntPtr ToHIcon(RenderTargetBitmap bitmap)
    {
        using (bitmap)
        {
            var w = bitmap.PixelSize.Width;
            var h = bitmap.PixelSize.Height;
            var stride = w * 4;
            var pixels = new byte[stride * h];
            var handle = GCHandle.Alloc(pixels, GCHandleType.Pinned);
            try { bitmap.CopyPixels(new PixelRect(0, 0, w, h), handle.AddrOfPinnedObject(), pixels.Length, stride); }
            finally { handle.Free(); }

            // Skia renders premultiplied BGRA; icons expect straight alpha.
            for (int i = 0; i < pixels.Length; i += 4)
            {
                var a = pixels[i + 3];
                if (a is 0 or 255) continue;
                pixels[i] = (byte)Math.Min(255, pixels[i] * 255 / a);
                pixels[i + 1] = (byte)Math.Min(255, pixels[i + 1] * 255 / a);
                pixels[i + 2] = (byte)Math.Min(255, pixels[i + 2] * 255 / a);
            }

            var bmi = new BITMAPINFO
            {
                biSize = 40,   // sizeof(BITMAPINFOHEADER)
                biWidth = w,
                biHeight = -h,   // top-down
                biPlanes = 1,
                biBitCount = 32,
            };
            var color = CreateDIBSection(IntPtr.Zero, ref bmi, 0, out var bits, IntPtr.Zero, 0);
            Marshal.Copy(pixels, 0, bits, pixels.Length);
            var mask = CreateBitmap(w, h, 1, 1, IntPtr.Zero);
            var info = new ICONINFO { fIcon = true, hbmColor = color, hbmMask = mask };
            var icon = CreateIconIndirect(ref info);
            DeleteObject(color);
            DeleteObject(mask);
            return icon;
        }
    }

    [StructLayout(LayoutKind.Sequential)]
    struct BITMAPINFO
    {
        public int biSize, biWidth, biHeight; public short biPlanes, biBitCount; public int biCompression, biSizeImage,
            biXPelsPerMeter, biYPelsPerMeter, biClrUsed, biClrImportant; public int bmiColors;
    }

    [StructLayout(LayoutKind.Sequential)]
    struct ICONINFO { [MarshalAs(UnmanagedType.Bool)] public bool fIcon; public int xHotspot, yHotspot; public IntPtr hbmMask, hbmColor; }

    [DllImport("gdi32.dll")] static extern IntPtr CreateDIBSection(IntPtr hdc, ref BITMAPINFO bmi, uint usage, out IntPtr bits, IntPtr section, uint offset);
    [DllImport("gdi32.dll")] static extern IntPtr CreateBitmap(int w, int h, uint planes, uint bitCount, IntPtr bits);
    [DllImport("gdi32.dll")] static extern bool DeleteObject(IntPtr obj);
    [DllImport("user32.dll")] static extern IntPtr CreateIconIndirect(ref ICONINFO info);
}
