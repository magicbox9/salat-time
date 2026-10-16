using System.Text.Json.Serialization;

namespace SalatTime.Core;

/// <summary>
/// A mosque's published schedule, as read from its MAWAQIT page. Mirrors the
/// Mac app's <c>MosqueInfo</c> so both apps cache the same shape.
/// </summary>
public sealed class MosqueInfo
{
    public string Name { get; set; } = "";
    public string Localisation { get; set; } = "";
    public string Phone { get; set; } = "";
    public string Site { get; set; } = "";
    /// <summary>Today's five adhan times (Fajr, Dhuhr, Asr, Maghrib, Isha) at fetch time.</summary>
    public List<string> Times { get; set; } = new();
    public string Shuruq { get; set; } = "";
    /// <summary>Five iqama values: offsets ("+10") or explicit times ("13:45").</summary>
    public List<string> Iqama { get; set; } = new();
    public string Jumua { get; set; } = "";
    public List<string>? JumuaTimes { get; set; }
    public string? Sunset { get; set; }
    public string Date { get; set; } = "";
    public string SourceUrl { get; set; } = "";
    /// <summary>calendar[month-1][day-1] = [fajr, shuruq, dhuhr, asr, maghrib, isha].</summary>
    public List<List<List<string>>>? Calendar { get; set; }
    /// <summary>iqamaCalendar[month-1][day-1] = five offsets or times.</summary>
    public List<List<List<string>>>? IqamaCalendar { get; set; }
    public double? Latitude { get; set; }
    public double? Longitude { get; set; }
    public int? HijriAdjustment { get; set; }
    public int? ImsakMinutes { get; set; }

    [JsonIgnore]
    public bool HasTimes => Times.Count >= 5;

    /// <summary>The published row for a date: [fajr, shuruq, dhuhr, asr, maghrib, isha], or null.</summary>
    public IReadOnlyList<string>? CalendarRow(DateTime date)
    {
        if (Calendar is null || Calendar.Count < date.Month) return null;
        var month = Calendar[date.Month - 1];
        if (month.Count < date.Day) return null;
        var row = month[date.Day - 1];
        return row.Count >= 6 && row.Take(6).All(t => TimeText.Minutes(t) is not null) ? row : null;
    }

    public IReadOnlyList<string>? IqamaRow(DateTime date)
    {
        if (IqamaCalendar is null || IqamaCalendar.Count < date.Month) return null;
        var month = IqamaCalendar[date.Month - 1];
        if (month.Count < date.Day) return null;
        var row = month[date.Day - 1];
        return row.Count >= 5 ? row : null;
    }
}

/// <summary>A mosque in search results or favourites.</summary>
public sealed class MosqueRef
{
    public string Name { get; set; } = "";
    public string City { get; set; } = "";
    public string Url { get; set; } = "";
    public string? Address { get; set; }
    public double? Lat { get; set; }
    public double? Lon { get; set; }

    [JsonIgnore]
    public string Subtitle => string.Join(" · ", new[] { City, Address ?? "" }.Where(s => !string.IsNullOrWhiteSpace(s)).Distinct());

    public bool SameMosque(MosqueRef other) => MosqueUrls.Normalize(Url) == MosqueUrls.Normalize(other.Url);
}

/// <summary>What happens at a prayer's adhan time.</summary>
public enum AdhanMode
{
    Off = 0,      // silent — no sound, no notification
    Notify = 1,   // notification only
    Adhan = 2,    // play the adhan + notification
}

public static class AdhanModeExtensions
{
    public static AdhanMode Next(this AdhanMode mode) => mode switch
    {
        AdhanMode.Off => AdhanMode.Notify,
        AdhanMode.Notify => AdhanMode.Adhan,
        _ => AdhanMode.Off,
    };
}

public enum HijriFormat { Off, Full, DayMonth, Month, Day }

public static class MosqueUrls
{
    public const string DefaultMosque = "https://mawaqit.net/fr/m/mosquee-el-houda-villefranche-sur-saone";

    public static string Normalize(string raw)
    {
        var trimmed = (raw ?? "").Trim();
        if (!Uri.TryCreate(trimmed, UriKind.Absolute, out var uri) || !uri.Host.Contains("mawaqit.net"))
            return trimmed;
        return "https://mawaqit.net" + uri.AbsolutePath;
    }

    public static bool IsValid(string raw)
    {
        var t = (raw ?? "").Trim();
        return Uri.TryCreate(t, UriKind.Absolute, out var uri) && uri.Host.Contains("mawaqit.net") && uri.AbsolutePath.Length > 1;
    }

    /// <summary>The full-site page (drops the mobile "/m/" segment), for "open in browser".</summary>
    public static string Desktop(string raw)
    {
        var n = Normalize(raw);
        var i = n.IndexOf("/m/", StringComparison.Ordinal);
        return i < 0 ? n : n.Remove(i, 2);
    }

    /// <summary>The mobile/embed page, which is lighter to load.</summary>
    public static string Mobile(string raw)
    {
        var n = Normalize(raw);
        if (!Uri.TryCreate(n, UriKind.Absolute, out var uri) || n.Contains("/m/")) return n;
        var segments = uri.AbsolutePath.Trim('/').Split('/');
        if (segments.Length == 2 && segments[0].Length == 2)
            return $"https://mawaqit.net/{segments[0]}/m/{segments[1]}";
        return n;
    }
}
