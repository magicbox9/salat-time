using System.Globalization;
using System.Text.Json;
using System.Text.Json.Serialization;

namespace SalatTime.Core;

/// <summary>
/// User preferences, stored as JSON in %APPDATA%\SalatTime\settings.json.
/// Defaults match the Mac app so both behave the same out of the box.
/// </summary>
public sealed class AppSettings
{
    // ---- mosque
    public string MosqueUrl { get; set; } = MosqueUrls.DefaultMosque;
    public List<MosqueRef> Favorites { get; set; } = new();
    public string UserCity { get; set; } = "";

    // ---- general
    public string Language { get; set; } = DefaultLanguage();
    public string Appearance { get; set; } = "system";      // system | light | dark
    public string Accent { get; set; } = "green";           // green | blue | purple | orange | red | teal
    public string TimeFormat { get; set; } = "24h";         // 24h | 12h
    public string ArabicDigits { get; set; } = "western";   // western | arabicIndic
    public bool OpenAtLogin { get; set; } = true;

    // ---- tray
    /// <summary>Show minutes-to-next-prayer inside the tray icon during the last hour.</summary>
    public bool TrayCountdownIcon { get; set; } = true;
    public HijriFormat TrayHijri { get; set; } = HijriFormat.Full;
    /// <summary>A small always-on-top countdown pill near the taskbar (off by default).</summary>
    public bool CountdownPill { get; set; }
    public double? CountdownPillX { get; set; }
    public double? CountdownPillY { get; set; }

    // ---- adhan
    public bool AdhanEnabled { get; set; } = true;
    public bool NotificationsEnabled { get; set; } = true;
    public int[] PrayerModes { get; set; } = { 2, 2, 2, 2, 2 };
    public string AdhanSound { get; set; } = "makkah_mulla";
    public string FajrAdhanSound { get; set; } = "";         // "" = same as the others
    public string AdhanDevice { get; set; } = "";            // "" = system default output
    public double AdhanVolume { get; set; } = 1.0;           // used when the device volume can't be set
    public int PreAdhanLeadMinutes { get; set; }             // 0 = off
    public int TravelMinutes { get; set; } = 10;              // "leave by" helper, 0 = off (Mac default 10)

    // ---- main window
    public int PrayerView { get; set; }                      // 0 overview, 1 timetable, 2 day path, 3 dial
    public int TimetableRange { get; set; } = 1;            // 0 = 7 days, 1 = Hijri month, 2 = Gregorian month
    public string? LastPage { get; set; }

    // ---- adhkar
    public bool AdhkarEnabled { get; set; } = true;
    public string AdhkarMorningAnchor { get; set; } = "shuruq";
    public string AdhkarEveningAnchor { get; set; } = "asr";
    public double AdhkarTextScale { get; set; } = 1.0;

    // ---- qur'an
    public string QuranEdition { get; set; } = "hafs";
    public int QuranSura { get; set; } = 1;
    public int QuranAyah { get; set; } = 1;
    public int QuranPage { get; set; } = 1;
    public int QuranMode { get; set; } = 1;                 // 0 verses, 1 mushaf
    public string QuranTranslation { get; set; } = "auto";  // auto | none | en | fr | ...
    public string QuranReciter { get; set; } = "Alafasy_128kbps";
    public double QuranTextScale { get; set; } = 1.0;
    public List<QuranBookmark> QuranBookmarks { get; set; } = new();

    // ---- bookkeeping (not shown in Settings)
    public string LastAdhanMarker { get; set; } = "";
    public string LastPreAdhanMarker { get; set; } = "";
    public string LastAdhkarMorning { get; set; } = "";
    public string LastAdhkarEvening { get; set; } = "";
    public bool FirstRunDone { get; set; }

    [JsonIgnore] public bool Use12h => TimeFormat == "12h";

    public AdhanMode ModeFor(int prayer) =>
        prayer is >= 0 and < 5 && PrayerModes.Length == 5 && Enum.IsDefined(typeof(AdhanMode), PrayerModes[prayer])
            ? (AdhanMode)PrayerModes[prayer] : AdhanMode.Adhan;

    public void SetMode(int prayer, AdhanMode mode)
    {
        if (PrayerModes.Length != 5) PrayerModes = new[] { 2, 2, 2, 2, 2 };
        PrayerModes[prayer] = (int)mode;
    }

    public static readonly string[] Languages = { "en", "fr", "es", "ar", "zh", "hi", "bn", "ru", "pt", "ur" };

    static string DefaultLanguage()
    {
        var code = CultureInfo.CurrentUICulture.TwoLetterISOLanguageName;
        return Languages.Contains(code) ? code : "en";
    }

    // ---------------------------------------------------------------- storage

    /// <summary>Tests and screenshots point this at a scratch folder.</summary>
    public static string? FolderOverride { get; set; }

    public static string Folder
    {
        get
        {
            if (FolderOverride is not null) { Directory.CreateDirectory(FolderOverride); return FolderOverride; }
            var root = Environment.GetFolderPath(Environment.SpecialFolder.ApplicationData);
            if (string.IsNullOrEmpty(root)) root = Path.GetTempPath();
            var dir = Path.Combine(root, "SalatTime");
            Directory.CreateDirectory(dir);
            return dir;
        }
    }

    static string FilePath => Path.Combine(Folder, "settings.json");

    internal static readonly JsonSerializerOptions Json = new()
    {
        WriteIndented = true,
        PropertyNamingPolicy = JsonNamingPolicy.CamelCase,
        Converters = { new JsonStringEnumConverter(JsonNamingPolicy.CamelCase) },
    };

    public static AppSettings Load()
    {
        try
        {
            if (File.Exists(FilePath))
                return JsonSerializer.Deserialize<AppSettings>(File.ReadAllText(FilePath), Json) ?? new AppSettings();
        }
        catch
        {
            // A damaged file must never stop the app; keep a copy for diagnosis.
            try { File.Copy(FilePath, FilePath + ".bad", true); } catch { }
        }
        return new AppSettings();
    }

    public event Action? Changed;

    /// <summary>Persist and notify listeners (UI refresh, tray, scheduler).</summary>
    public void Save(bool notify = true)
    {
        try
        {
            var tmp = FilePath + ".tmp";
            File.WriteAllText(tmp, JsonSerializer.Serialize(this, Json));
            File.Move(tmp, FilePath, true);
        }
        catch { }
        if (notify) Changed?.Invoke();
    }

    // ---------------------------------------------------------------- favourites

    public bool IsFavorite(string url) => Favorites.Any(f => MosqueUrls.Normalize(f.Url) == MosqueUrls.Normalize(url));

    public void ToggleFavorite(MosqueRef mosque)
    {
        var existing = Favorites.FirstOrDefault(f => f.SameMosque(mosque));
        if (existing is null) Favorites.Add(mosque); else Favorites.Remove(existing);
        Save();
    }
}
