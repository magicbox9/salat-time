using System.Globalization;

namespace SalatTime.Core;

/// <summary>"HH:mm" parsing and display helpers (MAWAQIT always publishes 24-hour times).</summary>
public static class TimeText
{
    /// <summary>"HH:mm" → minutes since midnight (hours up to 47 allowed for after-midnight Isha).</summary>
    public static int? Minutes(string? hhmm)
    {
        if (string.IsNullOrWhiteSpace(hhmm)) return null;
        var parts = hhmm.Trim().Split(':');
        if (parts.Length != 2) return null;
        if (!int.TryParse(parts[0], NumberStyles.None, CultureInfo.InvariantCulture, out var h)) return null;
        if (!int.TryParse(parts[1], NumberStyles.None, CultureInfo.InvariantCulture, out var m)) return null;
        if (h < 0 || h >= 48 || m < 0 || m >= 60) return null;
        return h * 60 + m;
    }

    /// <summary>Minutes since midnight (wrapping) → "HH:mm".</summary>
    public static string Clock(int minutes)
    {
        var v = ((minutes % 1440) + 1440) % 1440;
        return $"{v / 60:00}:{v % 60:00}";
    }

    public static string AddMinutes(string hhmm, int minutes) =>
        Minutes(hhmm) is int m ? Clock(m + minutes) : hhmm;

    /// <summary>Resolve an iqama value ("+10", "-5" or "HH:mm") against its adhan.</summary>
    public static string? ResolveIqama(string? raw, string adhan)
    {
        var value = (raw ?? "").Trim();
        if (value.Length == 0) return null;
        if (value[0] == '+' || value[0] == '-')
        {
            if (!int.TryParse(value, NumberStyles.AllowLeadingSign, CultureInfo.InvariantCulture, out var offset)) return null;
            return Minutes(adhan) is int a ? Clock(a + offset) : null;
        }
        return Minutes(value) is null ? null : value;
    }

    /// <summary>Format a raw "HH:mm" for display in 12- or 24-hour style.</summary>
    public static string Display(string? hhmm, bool use12h)
    {
        if (Minutes(hhmm) is not int m) return string.IsNullOrEmpty(hhmm) ? "--:--" : hhmm!;
        m %= 1440;
        int h = m / 60, mm = m % 60;
        if (!use12h) return $"{h:00}:{mm:00}";
        var period = h >= 12 ? "PM" : "AM";
        var h12 = h % 12 == 0 ? 12 : h % 12;
        return $"{h12}:{mm:00} {period}";
    }

    /// <summary>The time of day at minute <paramref name="minutes"/> on <paramref name="day"/>.</summary>
    public static DateTime At(DateTime day, int minutes) => day.Date.AddMinutes(minutes);

    public static string Countdown(TimeSpan span, bool alwaysHours = false)
    {
        var s = Math.Max(0, (int)Math.Floor(span.TotalSeconds));
        int h = s / 3600, m = s % 3600 / 60, sec = s % 60;
        return alwaysHours || h > 0 ? $"{h:00}:{m:00}:{sec:00}" : $"{m:00}:{sec:00}";
    }
}
