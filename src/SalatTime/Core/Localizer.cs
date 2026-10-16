using System.Globalization;
using System.Text;
using System.Text.Json;
using System.Text.RegularExpressions;

namespace SalatTime.Core;

/// <summary>
/// UI strings for the ten languages. <c>strings.json</c> is generated from the
/// Mac app's translations (windows/tools/extract_strings.py), so both apps
/// use the same wording. Keys from the Mac Swift tables are namespaced, e.g.
/// <c>feature:full.next_prayer</c> or <c>view:today</c>.
/// </summary>
public sealed class Localizer
{
    public static Localizer Shared { get; } = new();

    Dictionary<string, Dictionary<string, string>> _tables = new();
    public string Code { get; private set; } = "en";
    public bool ArabicIndicDigits { get; set; }

    public static readonly (string Code, string Native)[] Languages =
    {
        ("en", "English"), ("fr", "Français"), ("es", "Español"), ("ar", "العربية"), ("zh", "中文"),
        ("hi", "हिन्दी"), ("bn", "বাংলা"), ("ru", "Русский"), ("pt", "Português"), ("ur", "اردو"),
    };

    public bool IsRtl => Code is "ar" or "ur";
    /// <summary>Arabic-script languages use the bundled Cairo face, like the Mac app.</summary>
    public bool UsesCairo => Code is "ar" or "ur";

    public void Load(Stream json)
    {
        _tables = JsonSerializer.Deserialize<Dictionary<string, Dictionary<string, string>>>(json) ?? new();
    }

    public void SetLanguage(string code) => Code = _tables.ContainsKey(code) || code == "en" ? code : "en";

    public CultureInfo Culture
    {
        get
        {
            var name = Code switch { "zh" => "zh-Hans", "pt" => "pt-PT", _ => Code };
            try
            {
                var c = (CultureInfo)CultureInfo.GetCultureInfo(name).Clone();
                // Always show Gregorian dates here; Hijri is formatted separately.
                if (c.DateTimeFormat.Calendar is not GregorianCalendar)
                    c.DateTimeFormat.Calendar = new GregorianCalendar();
                return c;
            }
            catch (CultureNotFoundException) { return CultureInfo.InvariantCulture; }
        }
    }

    /// <summary>Translated text, falling back to English, then to the key itself.</summary>
    public string T(string key)
    {
        if (_tables.TryGetValue(Code, out var table) && table.TryGetValue(key, out var v)) return Digits(v);
        if (_tables.TryGetValue("en", out var en) && en.TryGetValue(key, out var e)) return Digits(e);
        return key;
    }

    public bool Has(string key) => _tables.TryGetValue("en", out var en) && en.ContainsKey(key);

    /// <summary>Format a Mac-style template ("%@ in %d min", "%1$@") with .NET arguments.</summary>
    public string F(string key, params object[] args) => Format(T(key), args);

    public string Format(string template, params object[] args)
    {
        int next = 0;
        var result = Regex.Replace(template, @"%(?:(\d+)\$)?(@|d|ld|lld|s|\.\d*f|f)", m =>
        {
            var index = m.Groups[1].Success ? int.Parse(m.Groups[1].Value, CultureInfo.InvariantCulture) - 1 : next++;
            if (index < 0 || index >= args.Length) return "";
            var spec = m.Groups[2].Value;
            if (spec.EndsWith('f') && args[index] is IFormattable f)
            {
                var decimals = spec.Length > 1 && int.TryParse(spec.Trim('.', 'f'), out var d) ? d : 1;
                return f.ToString("F" + decimals, CultureInfo.InvariantCulture);
            }
            return Convert.ToString(args[index], CultureInfo.InvariantCulture) ?? "";
        });
        return Digits(result.Replace("%%", "%"));
    }

    /// <summary>Apply the Arabic numeral preference (Arabic interface only).</summary>
    public string Digits(string text)
    {
        if (Code != "ar") return text;
        const string western = "0123456789", indic = "٠١٢٣٤٥٦٧٨٩";
        var (from, to) = ArabicIndicDigits ? (western, indic) : (indic, western);
        var sb = new StringBuilder(text.Length);
        foreach (var c in text)
        {
            var i = from.IndexOf(c);
            sb.Append(i >= 0 ? to[i] : c);
        }
        return sb.ToString();
    }

    public string PrayerName(int index) => index switch
    {
        0 => T("prayer.fajr"),
        1 => T("prayer.dhuhr"),
        2 => T("prayer.asr"),
        3 => T("prayer.maghrib"),
        4 => T("prayer.isha"),
        _ => "",
    };

    /// <summary>Time in the user's 12/24-hour style with localized digits.</summary>
    public string Time(string? hhmm, bool use12h) => Digits(TimeText.Display(hhmm, use12h));

    /// <summary>Wrap a run of digits so it stays left-to-right inside Arabic text.</summary>
    public string Ltr(string s) => IsRtl ? "‎" + s + "‎" : s;

    public string GregorianDate(DateTime date, string pattern = "ddd d MMM yyyy") =>
        Digits(date.ToString(pattern, Culture));
}
