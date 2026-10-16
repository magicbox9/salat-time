using Avalonia;
using Avalonia.Controls;
using Avalonia.Media;
using Avalonia.Styling;
using Avalonia.Themes.Fluent;

namespace SalatTime.Core;

/// <summary>Appearance (light/dark/system), accent colour and the interface font.</summary>
public static class AppTheme
{
    /// <summary>Same six accents as the Mac app: (light-mode shade, dark-mode shade).</summary>
    public static readonly Dictionary<string, (Color Light, Color Dark)> Accents = new()
    {
        ["green"] = (Color.FromRgb(22, 101, 52), Color.FromRgb(102, 219, 140)),
        ["blue"] = (Color.FromRgb(20, 89, 184), Color.FromRgb(102, 173, 255)),
        ["purple"] = (Color.FromRgb(102, 33, 140), Color.FromRgb(186, 138, 255)),
        ["orange"] = (Color.FromRgb(209, 107, 23), Color.FromRgb(255, 181, 89)),
        ["red"] = (Color.FromRgb(184, 43, 43), Color.FromRgb(255, 115, 115)),
        ["teal"] = (Color.FromRgb(18, 133, 133), Color.FromRgb(77, 217, 217)),
    };

    public static readonly string[] AccentOrder = { "green", "blue", "purple", "orange", "red", "teal" };

    public static (Color Light, Color Dark) Pair(string key) => Accents.TryGetValue(key, out var p) ? p : Accents["green"];

    public static void Apply(AppSettings settings)
    {
        var app = Application.Current;
        if (app is null) return;
        app.RequestedThemeVariant = settings.Appearance switch
        {
            "light" => ThemeVariant.Light,
            "dark" => ThemeVariant.Dark,
            _ => ThemeVariant.Default,
        };

        var (light, dark) = Pair(settings.Accent);
        Set(app, ThemeVariant.Light, "AccentBrush", light);
        Set(app, ThemeVariant.Light, "AccentSoftBrush", WithAlpha(light, 0.14));
        Set(app, ThemeVariant.Light, "AccentForegroundBrush", Colors.White);
        Set(app, ThemeVariant.Dark, "AccentBrush", dark);
        Set(app, ThemeVariant.Dark, "AccentSoftBrush", WithAlpha(dark, 0.22));
        Set(app, ThemeVariant.Dark, "AccentForegroundBrush", Darken(dark, 0.82));
        app.Resources["HeaderBrush"] = new SolidColorBrush(light);
        app.Resources["HeaderDeepBrush"] = new LinearGradientBrush
        {
            StartPoint = new RelativePoint(0, 0, RelativeUnit.Relative),
            EndPoint = new RelativePoint(1, 1, RelativeUnit.Relative),
            GradientStops = { new GradientStop(Lighten(light, 0.08), 0), new GradientStop(Darken(light, 0.18), 1) },
        };

        // Native controls (toggles, sliders, selection) follow the chosen accent.
        if (app.Styles.OfType<FluentTheme>().FirstOrDefault() is { } fluent)
        {
            fluent.Palettes[ThemeVariant.Light] = new ColorPaletteResources { Accent = light };
            fluent.Palettes[ThemeVariant.Dark] = new ColorPaletteResources { Accent = dark };
        }
    }

    static void Set(Application app, ThemeVariant variant, string key, Color color)
    {
        if (app.Resources.ThemeDictionaries.TryGetValue(variant, out var dict) && dict is ResourceDictionary rd)
            rd[key] = new SolidColorBrush(color);
    }

    public static Color WithAlpha(Color c, double a) => Color.FromArgb((byte)Math.Round(a * 255), c.R, c.G, c.B);

    public static Color Darken(Color c, double amount) =>
        Color.FromRgb((byte)(c.R * (1 - amount)), (byte)(c.G * (1 - amount)), (byte)(c.B * (1 - amount)));

    public static Color Lighten(Color c, double amount) =>
        Color.FromRgb((byte)(c.R + (255 - c.R) * amount), (byte)(c.G + (255 - c.G) * amount), (byte)(c.B + (255 - c.B) * amount));

    public static bool IsDark => Application.Current?.ActualThemeVariant == ThemeVariant.Dark;

    public static Color AccentNow(AppSettings s) => IsDark ? Pair(s.Accent).Dark : Pair(s.Accent).Light;

    // ---------------------------------------------------------------- fonts

    public static readonly FontFamily Cairo = new("avares://SalatTime/Assets/Fonts#Cairo");
    public static readonly FontFamily Ui = new("Segoe UI Variable Text, Segoe UI, Inter, Helvetica Neue, Arial");
    public static readonly FontFamily UiDisplay = new("Segoe UI Variable Display, Segoe UI, Inter, Helvetica Neue, Arial");

    /// <summary>Interface font for the current language (Cairo for Arabic and Urdu, like the Mac app).</summary>
    public static FontFamily Font => Localizer.Shared.UsesCairo ? Cairo : Ui;
    public static FontFamily DisplayFont => Localizer.Shared.UsesCairo ? Cairo : UiDisplay;

    /// <summary>Apply language direction and font to a window.</summary>
    public static void Localize(Control root)
    {
        root.FlowDirection = Localizer.Shared.IsRtl ? FlowDirection.RightToLeft : FlowDirection.LeftToRight;
        if (root is Avalonia.Controls.Primitives.TemplatedControl tc) tc.FontFamily = Font;
    }

    public static IBrush Brush(string key) =>
        Application.Current?.FindResource(Application.Current.ActualThemeVariant, key) as IBrush ?? Brushes.Transparent;

    public static bool HasIcon(string name) => Application.Current?.TryFindResource("Icon." + name, out _) == true;

    public static Geometry Icon(string name) =>
        Application.Current?.FindResource("Icon." + name) as Geometry ?? new StreamGeometry();
}
