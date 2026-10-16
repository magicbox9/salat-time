using System.Globalization;

namespace SalatTime.Core;

/// <summary>
/// One day's schedule for the selected mosque. Uses the mosque's full-year
/// calendar for any date, so the times stay right after midnight even before
/// the next refresh; falls back to the times read at fetch.
/// </summary>
public sealed class PrayerDay
{
    public static readonly string[] Keys = { "fajr", "dhuhr", "asr", "maghrib", "isha" };

    public DateTime Date { get; }
    /// <summary>Five adhan times, "HH:mm".</summary>
    public string[] Adhan { get; }
    public string Shuruq { get; }
    /// <summary>Five iqama times (resolved), or null when the mosque gives none.</summary>
    public string?[] Iqama { get; }

    PrayerDay(DateTime date, string[] adhan, string shuruq, string?[] iqama)
    {
        Date = date.Date;
        Adhan = adhan;
        Shuruq = shuruq;
        Iqama = iqama;
    }

    public bool IsValid => Adhan.All(a => TimeText.Minutes(a) is not null);

    public static PrayerDay For(MosqueInfo info, DateTime date)
    {
        date = date.Date;
        var fetchedToday = info.Date == date.ToString("yyyy-MM-dd", CultureInfo.InvariantCulture);
        string[] adhan;
        string shuruq;
        if (!fetchedToday && info.CalendarRow(date) is { } row)
        {
            adhan = new[] { row[0], row[2], row[3], row[4], row[5] };
            shuruq = row[1];
        }
        else
        {
            adhan = Enumerable.Range(0, 5).Select(i => i < info.Times.Count ? info.Times[i] : "").ToArray();
            shuruq = info.Shuruq;
            if (shuruq.Length == 0 && info.CalendarRow(date) is { } r) shuruq = r[1];
        }

        IReadOnlyList<string> rawIqama = info.Iqama;
        if (!fetchedToday && info.IqamaRow(date) is { } iqRow) rawIqama = iqRow;
        var iqama = Enumerable.Range(0, 5)
            .Select(i => i < rawIqama.Count ? TimeText.ResolveIqama(rawIqama[i], adhan[i]) : null)
            .ToArray();
        return new PrayerDay(date, adhan, shuruq, iqama);
    }

    public DateTime? AdhanAt(int i) => TimeText.Minutes(Adhan[i]) is int m ? TimeText.At(Date, m) : null;

    public DateTime? IqamaAt(int i)
    {
        if (Iqama[i] is not string iq || TimeText.Minutes(iq) is not int m || AdhanAt(i) is not DateTime adhan) return null;
        var at = TimeText.At(Date, m);
        return at < adhan ? at.AddDays(1) : at;   // Isha iqama can roll past midnight
    }

    /// <summary>Minutes between adhan and iqama (the "+10" badge).</summary>
    public int? IqamaOffset(int i)
    {
        if (TimeText.Minutes(Adhan[i]) is not int a || Iqama[i] is not string iq || TimeText.Minutes(iq) is not int q) return null;
        var diff = q - a;
        if (diff < -720) diff += 1440;
        if (diff > 720) diff -= 1440;
        return diff;
    }
}

public static class PrayerClock
{
    /// <summary>The next adhan after <paramref name="now"/> (Fajr tomorrow after Isha).</summary>
    public static (int Index, DateTime At, bool Tomorrow)? Next(MosqueInfo info, DateTime now)
    {
        if (!info.HasTimes) return null;
        var today = PrayerDay.For(info, now);
        for (int i = 0; i < 5; i++)
            if (today.AdhanAt(i) is DateTime at && at > now) return (i, at, false);
        var tomorrow = PrayerDay.For(info, now.AddDays(1));
        return tomorrow.AdhanAt(0) is DateTime f ? (0, f, true) : null;
    }

    /// <summary>The prayer whose adhan → iqama window contains <paramref name="now"/>.</summary>
    public static (int Index, DateTime Iqama)? AdhanWindow(MosqueInfo info, DateTime now)
    {
        if (!info.HasTimes) return null;
        foreach (var day in new[] { PrayerDay.For(info, now), PrayerDay.For(info, now.AddDays(-1)) })
            for (int i = 0; i < 5; i++)
                if (day.AdhanAt(i) is DateTime adhan && day.IqamaAt(i) is DateTime iqama && now >= adhan && now < iqama)
                    return (i, iqama);
        return null;
    }

    /// <summary>The prayer time we are currently in (the last adhan that has passed), or -1 before Fajr.</summary>
    public static int Current(MosqueInfo info, DateTime now)
    {
        var today = PrayerDay.For(info, now);
        var current = -1;
        for (int i = 0; i < 5; i++)
            if (today.AdhanAt(i) is DateTime at && at <= now) current = i;
        return current;
    }
}
