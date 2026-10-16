using Avalonia.Media;

namespace SalatTime.Core;

/// <summary>
/// One day as minutes since midnight: prayer times, sunrise/sunset, night
/// divisions and approximate discouraged windows (port of the Mac PrayerDayModel).
/// </summary>
public sealed class DayModel
{
    public int[] Times { get; }      // fajr, dhuhr, asr, maghrib, isha
    public int Shuruq { get; }
    public int Sunset { get; }
    public int NextFajr { get; }     // tomorrow's Fajr, minutes of its own day
    public int Imsak { get; }
    public DateTime Date { get; }

    DayModel(DateTime date, int[] times, int shuruq, int sunset, int nextFajr, int imsak)
    {
        Date = date.Date;
        Times = times;
        Shuruq = shuruq;
        Sunset = sunset;
        NextFajr = nextFajr;
        Imsak = imsak;
    }

    public static DayModel? For(MosqueInfo info, DateTime date)
    {
        if (!info.HasTimes) return null;
        var day = PrayerDay.For(info, date);
        var times = day.Adhan.Select(TimeText.Minutes).ToArray();
        if (times.Any(t => t is null) || TimeText.Minutes(day.Shuruq) is not int shuruq) return null;
        var parsed = times.Select(t => t!.Value).ToArray();
        var sunset = TimeText.Minutes(info.Sunset) ?? parsed[3];
        var tomorrow = PrayerDay.For(info, date.AddDays(1));
        var nextFajr = TimeText.Minutes(tomorrow.Adhan[0]) ?? parsed[0];
        var imsakOffset = info.ImsakMinutes ?? 0;
        return new DayModel(date, parsed, shuruq, sunset, nextFajr, parsed[0] - (imsakOffset > 0 ? imsakOffset : 10));
    }

    public int DayLength => Sunset - Shuruq;
    public int NightLength => 1440 - Sunset + NextFajr;
    public int Midnight => (Sunset + NightLength / 2) % 1440;
    public int LastThird => (Sunset + NightLength * 2 / 3) % 1440;

    /// <summary>Approximate discouraged windows: after sunrise, before the zenith, before sunset.</summary>
    public (int Start, int End)[] Discouraged => new[] { (Shuruq, Shuruq + 15), (Times[1] - 10, Times[1]), (Sunset - 15, Sunset) };

    /// <summary>Obligatory prayer windows (start, end, prayer index); Isha runs to the next Fajr.</summary>
    public (int Start, int End, int Index)[] Windows => new[]
    {
        (Times[0], Shuruq, 0), (Times[1], Times[2], 1), (Times[2], Times[3], 2),
        (Times[3], Times[4], 3), (Times[4], 1440 + NextFajr, 4),
    };

    /// <summary>The window containing <paramref name="minute"/>; index null between sunrise and Dhuhr.</summary>
    public (int? Index, int Start, int End) Current(int minute)
    {
        if (minute < Times[0]) return (4, Times[4] - 1440, Times[0]);
        foreach (var w in Windows)
            if (minute >= w.Start && minute < w.End) return (w.Index, w.Start, w.End);
        return (null, Shuruq, Times[1]);
    }

    public static int MinuteOf(DateTime t) => t.Hour * 60 + t.Minute;
}

public static class Qibla
{
    /// <summary>Qibla bearing in degrees clockwise from true north.</summary>
    public static double Bearing(double latitude, double longitude)
    {
        const double kaabaLat = 21.422487 * Math.PI / 180, kaabaLon = 39.826206 * Math.PI / 180;
        var lat = latitude * Math.PI / 180;
        var lon = longitude * Math.PI / 180;
        var delta = kaabaLon - lon;
        var bearing = Math.Atan2(Math.Sin(delta), Math.Cos(lat) * Math.Tan(kaabaLat) - Math.Sin(lat) * Math.Cos(delta)) * 180 / Math.PI;
        return (bearing + 360) % 360;
    }

    public static string Compass(double bearing)
    {
        string[] points = { "N", "NE", "E", "SE", "S", "SW", "W", "NW" };
        return points[(int)Math.Round(bearing / 45) % 8];
    }
}

/// <summary>The moon's phase from the mean synodic month.</summary>
public readonly record struct MoonPhase(double Age)
{
    public const double SynodicMonth = 29.530588853;

    public static MoonPhase At(DateTime local)
    {
        const double reference = 947_182_440.0;   // 2000-01-06 18:14 UTC new moon
        var days = (new DateTimeOffset(local).ToUnixTimeSeconds() - reference) / 86_400;
        var age = days % SynodicMonth;
        if (age < 0) age += SynodicMonth;
        return new MoonPhase(age);
    }

    public double Fraction => Age / SynodicMonth;
    public double Illumination => (1 - Math.Cos(2 * Math.PI * Fraction)) / 2;
    public bool Waxing => Fraction < 0.5;
}

/// <summary>Sky colours through the day, keyed to the mosque's times (same keyframes as the Mac app).</summary>
public static class LivingSky
{
    public readonly record struct Pair(Color Top, Color Horizon);

    static Color C(double r, double g, double b) => Color.FromRgb((byte)(r * 255), (byte)(g * 255), (byte)(b * 255));

    public static readonly Pair Night = new(C(0.035, 0.05, 0.14), C(0.09, 0.11, 0.24));
    static readonly Pair Dawn = new(C(0.13, 0.17, 0.36), C(0.72, 0.42, 0.50));
    static readonly Pair Sunrise = new(C(0.30, 0.50, 0.80), C(0.98, 0.70, 0.42));
    static readonly Pair Day = new(C(0.16, 0.47, 0.82), C(0.62, 0.80, 0.96));
    static readonly Pair Golden = new(C(0.28, 0.43, 0.74), C(0.98, 0.74, 0.44));
    static readonly Pair SunsetPair = new(C(0.22, 0.22, 0.48), C(0.95, 0.47, 0.33));
    static readonly Pair Dusk = new(C(0.08, 0.10, 0.27), C(0.42, 0.26, 0.44));

    static List<(double Minute, Pair Colors)> Keyframes(DayModel m)
    {
        double fajr = m.Times[0], rise = m.Shuruq, set = m.Sunset, isha = m.Times[4];
        var raw = new (double, Pair)[]
        {
            (0, Night), (fajr - 15, Night), ((fajr + rise) / 2, Dawn), (rise, Sunrise),
            (rise + 60, Day), (set - 75, Day), (set - 25, Golden), (set, SunsetPair),
            ((set + isha) / 2, Dusk), (isha + 15, Night), (1440, Night),
        };
        var result = new List<(double, Pair)>();
        foreach (var f in raw)
            if (result.Count == 0 || f.Item1 > result[^1].Item1) result.Add(f);
        return result;
    }

    public static Pair At(double minute, DayModel m)
    {
        var value = ((minute % 1440) + 1440) % 1440;
        var frames = Keyframes(m);
        for (int i = 1; i < frames.Count; i++)
        {
            if (value > frames[i].Minute) continue;
            var a = frames[i - 1];
            var b = frames[i];
            var t = (value - a.Minute) / Math.Max(1, b.Minute - a.Minute);
            var eased = t * t * (3 - 2 * t);
            return new Pair(Blend(a.Colors.Top, b.Colors.Top, eased), Blend(a.Colors.Horizon, b.Colors.Horizon, eased));
        }
        return Night;
    }

    /// <summary>0 = full day, 1 = night.</summary>
    public static double Darkness(double minute, DayModel m)
    {
        var c = At(minute, m).Top;
        var luminance = (0.2126 * c.R + 0.7152 * c.G + 0.0722 * c.B) / 255.0;
        return Math.Clamp(1 - (luminance - 0.05) / 0.35, 0, 1);
    }

    public static Color Blend(Color a, Color b, double t) => Color.FromArgb(
        (byte)(a.A + (b.A - a.A) * t), (byte)(a.R + (b.R - a.R) * t), (byte)(a.G + (b.G - a.G) * t), (byte)(a.B + (b.B - a.B) * t));
}
