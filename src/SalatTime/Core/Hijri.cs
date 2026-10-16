using System.Globalization;

namespace SalatTime.Core;

/// <summary>Umm al-Qura Hijri dates (the calendar the Mac app uses), with the mosque's day adjustment.</summary>
public static class Hijri
{
    static readonly UmAlQuraCalendar Calendar = new();

    static readonly Dictionary<string, string[]> MonthNames = new()
    {
        ["en"] = new[] { "Muharram", "Safar", "Rabiʻ I", "Rabiʻ II", "Jumada I", "Jumada II", "Rajab", "Shaʻban", "Ramadan", "Shawwal", "Dhuʻl-Qiʻdah", "Dhuʻl-Hijjah" },
        ["fr"] = new[] { "Mouharram", "Safar", "Rabiʻ al-awal", "Rabiʻ ath-thani", "Joumada al-oula", "Joumada ath-thania", "Rajab", "Chaʻban", "Ramadan", "Chawwal", "Dhou al-qiʻda", "Dhou al-hijja" },
        ["es"] = new[] { "muharram", "safar", "rabiʻ al-awwal", "rabiʻ al-thani", "yumada al-ula", "yumada al-thani", "rayab", "shaʻbán", "ramadán", "shawwal", "dhu al-qaʻda", "dhu al-hiyya" },
        ["ar"] = new[] { "محرم", "صفر", "ربيع الأول", "ربيع الآخر", "جمادى الأولى", "جمادى الآخرة", "رجب", "شعبان", "رمضان", "شوال", "ذو القعدة", "ذو الحجة" },
        ["zh"] = new[] { "穆哈兰姆月", "色法尔月", "赖比月 I", "赖比月 II", "主马达月 I", "主马达月 II", "赖哲卜月", "舍尔邦月", "赖买丹月", "闪瓦鲁月", "都尔喀尔德月", "都尔黑哲月" },
        ["hi"] = new[] { "मुहर्रम", "सफ़र", "रबी-उल-अव्वल", "रबी-उल-आख़िर", "जमादी-उल-अव्वल", "जमादी-उल-आख़िर", "रजब", "शाबान", "रमज़ान", "शव्वाल", "ज़िलक़ादा", "ज़िलहिज्जा" },
        ["bn"] = new[] { "মহররম", "সফর", "রবিউল আউয়াল", "রবিউস সানি", "জমাদিউল আউয়াল", "জমাদিউস সানি", "রজব", "শাবান", "রমজান", "শাওয়াল", "জিলকদ", "জিলহজ" },
        ["ru"] = new[] { "мухаррам", "сафар", "раби аль-авваль", "раби ас-сани", "джумада аль-уля", "джумада ас-сани", "раджаб", "шаабан", "рамадан", "шавваль", "зуль-каада", "зуль-хиджа" },
        ["pt"] = new[] { "Muharram", "Safar", "Rabiʻ I", "Rabiʻ II", "Jumada I", "Jumada II", "Rajab", "Shaʻban", "Ramadão", "Shawwal", "Dhuʻl-Qiʻdah", "Dhuʻl-Hijjah" },
        ["ur"] = new[] { "محرم", "صفر", "ربیع الاول", "ربیع الثانی", "جمادی الاول", "جمادی الثانی", "رجب", "شعبان", "رمضان", "شوال", "ذوالقعدہ", "ذوالحجہ" },
    };

    public readonly record struct HijriDate(int Day, int Month, int Year);

    public static HijriDate From(DateTime date, int adjustment = 0)
    {
        var d = date.Date.AddDays(adjustment);
        if (d < Calendar.MinSupportedDateTime || d > Calendar.MaxSupportedDateTime) d = DateTime.Today;
        return new HijriDate(Calendar.GetDayOfMonth(d), Calendar.GetMonth(d), Calendar.GetYear(d));
    }

    public static string MonthName(int month, string lang) =>
        (MonthNames.TryGetValue(lang, out var names) ? names : MonthNames["en"])[Math.Clamp(month, 1, 12) - 1];

    public static string Format(DateTime date, HijriFormat format, int adjustment = 0)
    {
        if (format == HijriFormat.Off) return "";
        var l = Localizer.Shared;
        var h = From(date, adjustment);
        var month = MonthName(h.Month, l.Code);
        var text = format switch
        {
            HijriFormat.Full => $"{h.Day} {month} {h.Year}",
            HijriFormat.DayMonth => $"{h.Day} {month}",
            HijriFormat.Month => month,
            HijriFormat.Day => h.Day.ToString(CultureInfo.InvariantCulture),
            _ => "",
        };
        return l.Digits(text);
    }

    /// <summary>Civil dates of the Hijri month that contains <paramref name="anchor"/> (+ offset months).</summary>
    public static List<DateTime> MonthDays(DateTime anchor, int monthOffset, int adjustment)
    {
        var shifted = anchor.Date.AddDays(adjustment);
        var start = Calendar.AddMonths(shifted, monthOffset);
        var first = start.AddDays(1 - Calendar.GetDayOfMonth(start));
        var count = Calendar.GetDaysInMonth(Calendar.GetYear(first), Calendar.GetMonth(first));
        return Enumerable.Range(0, count).Select(i => first.AddDays(i - adjustment)).ToList();
    }
}
