using Avalonia;
using Avalonia.Controls;
using Avalonia.Controls.Primitives;
using Avalonia.Layout;
using Avalonia.Media;
using SalatTime.Core;

namespace SalatTime.Views;

/// <summary>Small builders for controls created in code.</summary>
public static class Ui
{
    public static TextBlock Text(string text, double size = 13, FontWeight weight = FontWeight.Normal, string? classes = null)
    {
        var t = new TextBlock { Text = text, FontSize = size, FontWeight = weight, VerticalAlignment = VerticalAlignment.Center };
        if (classes is not null) foreach (var c in classes.Split(' ', StringSplitOptions.RemoveEmptyEntries)) t.Classes.Add(c);
        return t;
    }

    public static PathIcon Icon(string name, double size = 16, IBrush? brush = null)
    {
        var icon = new PathIcon { Data = AppTheme.Icon(name), Width = size, Height = size };
        if (brush is not null) icon.Foreground = brush;
        return icon;
    }

    public static Button IconButton(string icon, string tip, Action onClick, double size = 34, double iconSize = 16)
    {
        var b = new Button { Width = size, Height = size, Content = Icon(icon, iconSize) };
        b.Classes.Add("icon");
        Tip(b, tip);
        b.Click += (_, _) => onClick();
        return b;
    }

    public static T Tip<T>(T control, string tip) where T : Control
    {
        ToolTip.SetTip(control, tip);
        ToolTip.SetShowDelay(control, 250);
        return control;
    }

    public static Border Card(Control child, Thickness? padding = null)
    {
        var b = new Border { Child = child, Padding = padding ?? new Thickness(16) };
        b.Classes.Add("card");
        return b;
    }

    public static Border Divider(Thickness? margin = null)
    {
        var b = new Border { Margin = margin ?? new Thickness(0) };
        b.Classes.Add("divider");
        return b;
    }

    public static IBrush Res(string key) => AppTheme.Brush(key);

    public static void Bind(Control c, AvaloniaProperty property, string resourceKey) =>
        c[!property] = new Avalonia.Markup.Xaml.MarkupExtensions.DynamicResourceExtension(resourceKey);
}
