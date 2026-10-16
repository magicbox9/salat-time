using Avalonia;
using Avalonia.Controls;
using Avalonia.Platform;

namespace SalatTime.Views;

/// <summary>
/// Places tray flyouts next to the taskbar, on the screen where the tray
/// icon was clicked — whichever edge the taskbar is on.
/// </summary>
public static class TrayPlacement
{
    public enum Edge { Bottom, Top, Left, Right }

    public static PixelPoint Place(Window window, PixelSize size, PixelPoint? click, PixelRect? icon, bool centerOnAnchor = true)
    {
        var screens = window.Screens;
        var anchor = icon is { } r ? r.Center : click ?? DefaultAnchor(screens);
        if (click is { } c && icon is { } ir && !ir.Contains(c)) anchor = c;   // icon in the overflow area
        var screen = screens.ScreenFromPoint(anchor) ?? screens.Primary ?? screens.All.FirstOrDefault();
        if (screen is null) return anchor;

        var wa = screen.WorkingArea;
        var margin = (int)Math.Round(12 * screen.Scaling);
        var edge = TaskbarEdge(screen);
        int x, y;
        switch (edge)
        {
            case Edge.Top:
                x = centerOnAnchor ? anchor.X - size.Width / 2 : anchor.X;
                y = wa.Y + margin;
                break;
            case Edge.Left:
                x = wa.X + margin;
                y = anchor.Y - size.Height / 2;
                break;
            case Edge.Right:
                x = wa.Right - margin - size.Width;
                y = anchor.Y - size.Height / 2;
                break;
            default:
                x = centerOnAnchor ? anchor.X - size.Width / 2 : anchor.X;
                y = wa.Bottom - margin - size.Height;
                break;
        }
        x = Math.Clamp(x, wa.X + margin, Math.Max(wa.X + margin, wa.Right - margin - size.Width));
        y = Math.Clamp(y, wa.Y + margin, Math.Max(wa.Y + margin, wa.Bottom - margin - size.Height));
        return new PixelPoint(x, y);
    }

    public static Edge TaskbarEdge(Screen screen)
    {
        var wa = screen.WorkingArea;
        var b = screen.Bounds;
        if (wa.Bottom < b.Bottom - 1) return Edge.Bottom;
        if (wa.Y > b.Y + 1) return Edge.Top;
        if (wa.X > b.X + 1) return Edge.Left;
        if (wa.Right < b.Right - 1) return Edge.Right;
        return Edge.Bottom;   // auto-hide taskbar
    }

    static PixelPoint DefaultAnchor(Screens screens)
    {
        var s = screens.Primary ?? screens.All.FirstOrDefault();
        return s is null ? new PixelPoint(0, 0) : new PixelPoint(s.WorkingArea.Right - 40, s.WorkingArea.Bottom - 1);
    }

    /// <summary>A window's current size in physical pixels.</summary>
    public static PixelSize PixelSizeOf(Window window)
    {
        var scale = window.DesktopScaling;
        var size = window.ClientSize;
        if (size.Width <= 0 || size.Height <= 0) size = window.DesiredSize;
        return new PixelSize((int)Math.Ceiling(size.Width * scale), (int)Math.Ceiling(size.Height * scale));
    }
}
