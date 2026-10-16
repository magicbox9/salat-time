namespace SalatTime.Core;

/// <summary>"Sunnah of this moment" and the day's reminders — port of the Mac sunnahContext.</summary>
public static class Sunnah
{
    static Localizer L => Localizer.Shared;

    public static (string Now, (string Text, int Minute)? Next) Context(DayModel m, int minute, DateTime date, bool use12h)
    {
        int fajr = m.Times[0], dhuhr = m.Times[1], asr = m.Times[2], maghrib = m.Times[3], isha = m.Times[4];
        int duhaStart = m.Shuruq + 20, duhaEnd = dhuhr - 10;
        bool InLastThird(int v) => m.LastThird < m.Sunset ? v < fajr && v >= m.LastThird : v >= m.LastThird || v < fajr;

        string now;
        if (minute < fajr) now = L.T(InLastThird(minute) ? "living:ctx.lastthird" : "living:ctx.night");
        else if (minute < m.Shuruq - 5) now = L.T(minute < fajr + 30 ? "living:ctx.fajr" : "living:ctx.morning");
        else if (minute < duhaStart) now = L.T(minute < m.Shuruq + 15 ? "living:ctx.sunrise" : "living:ctx.morning");
        else if (minute < duhaEnd) now = L.F("living:ctx.duha", L.Time(TimeText.Clock(duhaEnd), use12h));
        else if (minute < dhuhr) now = L.T("living:ctx.zenith");
        else if (minute < asr) now = L.T("living:ctx.dhuhr");
        else if (minute < m.Sunset - 15) now = L.T("living:ctx.asr");
        else if (minute < maghrib) now = L.T("living:ctx.sunset");
        else if (minute < isha) now = L.T("living:ctx.maghrib");
        else now = L.T(InLastThird(minute) ? "living:ctx.lastthird" : "living:ctx.isha");

        var upcoming = new (int Minute, string Text)[]
        {
            (fajr, L.T("living:ctx.fajr")), (duhaStart, L.T("feature:nawafil.duha")),
            (dhuhr, L.T("living:ctx.dhuhr")), (maghrib, L.T("living:ctx.maghrib")),
            (isha, L.T("living:ctx.isha")), (m.LastThird, L.T("view:last.third")),
        };
        var later = upcoming.Where(u => u.Minute > minute).OrderBy(u => u.Minute).ToList();
        var next = later.Count > 0 ? later[0] : upcoming.OrderBy(u => u.Minute).Select(u => (Minute: u.Minute + 1440, u.Text)).First();
        return (now, (next.Text, next.Minute % 1440));
    }

    /// <summary>Reminders for the day: Friday, Monday/Thursday fasts, the White Days.</summary>
    public static List<(string Icon, string Text)> Reminders(DayModel m, int minute, DateTime date, int hijriAdjustment)
    {
        var list = new List<(string, string)>();
        var afterMaghrib = minute >= m.Times[3];
        if (date.DayOfWeek == DayOfWeek.Friday && !afterMaghrib) list.Add(("BookOpenRegular", L.T("living:fri")));

        // Monday and Thursday: today before Maghrib, tomorrow after it.
        var fastDay = afterMaghrib ? date.AddDays(1) : date;
        if (fastDay.DayOfWeek is DayOfWeek.Monday or DayOfWeek.Thursday)
        {
            var n = fastDay.DayOfWeek == DayOfWeek.Monday ? 1 : 4;
            list.Add(("LeafOneRegular", L.T(afterMaghrib ? $"living:fast.tomorrow.{n}" : $"living:fast.today.{n}")));
        }

        var h = Hijri.From(date, hijriAdjustment);
        if (h.Day is >= 13 and <= 15) list.Add(("WeatherMoonRegular", L.T("living:white.today")));
        else if (h.Day is >= 8 and < 13) list.Add(("WeatherMoonRegular", L.F("living:white.in", 13 - h.Day)));
        return list;
    }

    public static string MoonName(MoonPhase phase) => L.T($"living:moon.{(int)Math.Round(phase.Fraction * 8) % 8}");
}
