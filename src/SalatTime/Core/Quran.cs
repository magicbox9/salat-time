using System.Security.Cryptography;
using System.Text.Json;
using System.Text.Json.Serialization;
using Microsoft.Data.Sqlite;

namespace SalatTime.Core;

/// <summary>One verse of the King Fahd Complex corpus (fields as published).</summary>
public sealed class Ayah
{
    [JsonPropertyName("id")] public int Id { get; set; }
    [JsonPropertyName("jozz")] public int Juz { get; set; }
    /// <summary>The page the verse starts on (Warsh gives "85-86" for the few verses that span two pages).</summary>
    [JsonPropertyName("page")] [JsonConverter(typeof(PageStartConverter))] public int Page { get; set; }
    [JsonPropertyName("sura_no")] public int Sura { get; set; }
    [JsonPropertyName("sura_name_en")] public string SuraNameEn { get; set; } = "";
    [JsonPropertyName("sura_name_ar")] public string SuraNameAr { get; set; } = "";
    [JsonPropertyName("line_start")] public int LineStart { get; set; }
    [JsonPropertyName("line_end")] public int LineEnd { get; set; }
    [JsonPropertyName("aya_no")] public int Number { get; set; }
    [JsonPropertyName("aya_text")] public string Text { get; set; } = "";
    [JsonPropertyName("aya_text_emlaey")] public string? Plain { get; set; }
}

/// <summary>Reads 12, "12" or "85-86" (start page).</summary>
public sealed class PageStartConverter : JsonConverter<int>
{
    public override int Read(ref Utf8JsonReader reader, Type typeToConvert, JsonSerializerOptions options)
    {
        if (reader.TokenType == JsonTokenType.Number) return reader.GetInt32();
        var text = reader.GetString() ?? "";
        var first = text.Split('-', '–')[0].Trim();
        return int.TryParse(first, out var page) ? page : 1;
    }

    public override void Write(Utf8JsonWriter writer, int value, JsonSerializerOptions options) => writer.WriteNumberValue(value);
}

public sealed record Surah(int Number, string NameAr, string NameEn, int AyahCount, int FirstPage, int Juz);

/// <summary>
/// The offline Qur'an: the unchanged KFGQPC Hafs and Warsh corpora shipped
/// with the app (never fetched at runtime). Each corpus is checked against the
/// SHA-256 in source-manifest.json before it is shown — the reader fails
/// closed rather than display unverified text, as on the Mac.
/// </summary>
public sealed class QuranEdition
{
    public string Key { get; }
    public IReadOnlyList<Ayah> Ayahs { get; }
    public IReadOnlyList<Surah> Surahs { get; }
    public int PageCount { get; }
    readonly Dictionary<(int, int), Ayah> _byKey;
    readonly ILookup<int, Ayah> _byPage;

    QuranEdition(string key, List<Ayah> ayahs)
    {
        Key = key;
        Ayahs = ayahs;
        _byKey = ayahs.ToDictionary(a => (a.Sura, a.Number));
        _byPage = ayahs.ToLookup(a => a.Page);
        PageCount = ayahs.Max(a => a.Page);
        Surahs = ayahs.GroupBy(a => a.Sura).OrderBy(g => g.Key)
            .Select(g => new Surah(g.Key, g.First().SuraNameAr.Trim(), g.First().SuraNameEn.Trim(), g.Count(), g.Min(a => a.Page), g.First().Juz))
            .ToList();
    }

    public Ayah? Find(int sura, int ayah) => _byKey.TryGetValue((sura, ayah), out var a) ? a : null;
    public IEnumerable<Ayah> Page(int page) => _byPage[page].OrderBy(a => a.Id);
    public IEnumerable<Ayah> Surah(int sura) => Ayahs.Where(a => a.Sura == sura);

    // ------------------------------------------------------------------ loading

    static readonly Dictionary<string, QuranEdition?> Cache = new();
    public static string? LastError { get; private set; }

    public static QuranEdition? Load(string key)
    {
        if (Cache.TryGetValue(key, out var cached)) return cached;
        QuranEdition? edition = null;
        var relative = key == "warsh" ? "Warsh/warshData_v2-1.json" : "Hafs/hafsData_v2-0.json";
        try
        {
            var path = QuranFiles.Resolve(relative);
            if (path is null) LastError = "missing";
            else if (!QuranFiles.Verify(relative, path)) LastError = "integrity";
            else
            {
                var ayahs = JsonSerializer.Deserialize<List<Ayah>>(File.ReadAllBytes(path)) ?? new();
                // Same checks as the Mac reader: exact verse count, all 114 surahs, no empty text.
                var expected = key == "warsh" ? 6214 : 6236;
                var valid = ayahs.Count == expected && ayahs.Select(a => a.Sura).Distinct().Count() == 114 && ayahs.All(a => a.Text.Length > 0);
                edition = valid ? new QuranEdition(key, ayahs) : null;
                if (edition is null) LastError = "corpus";
            }
        }
        catch (Exception ex) when (ex is IOException or JsonException or UnauthorizedAccessException)
        {
            LastError = ex.Message;
        }
        Cache[key] = edition;
        return edition;
    }

    /// <summary>Find verses: "2:255" jumps; otherwise searches the plain (imla'i) text or a surah name.</summary>
    public List<Ayah> Search(string query, int limit = 60)
    {
        var q = query.Trim();
        if (q.Length == 0) return new();
        var parts = q.Split(':', ' ', '.');
        if (parts.Length == 2 && int.TryParse(parts[0], out var s) && int.TryParse(parts[1], out var n))
            return Find(s, n) is { } a ? new() { a } : new();
        var needle = Normalize(q);
        return Ayahs.Where(a => Normalize(a.Plain ?? a.Text).Contains(needle, StringComparison.Ordinal)).Take(limit).ToList();
    }

    /// <summary>The verse text without the KFGQPC presentation-form verse-end signs (rendering derivative only).</summary>
    public static string StripAyahMarkers(string text) =>
        new string(text.Where(c => !(c is >= '\uFB50' and <= '\uFDFF' or >= '\uFE70' and <= '\uFEFF')).ToArray()).TrimEnd(' ', '\u00A0');

    /// <summary>Arabic search folding: no diacritics, unified alef/ya/ta marbuta.</summary>
    public static string Normalize(string text)
    {
        var sb = new System.Text.StringBuilder(text.Length);
        foreach (var c in text)
        {
            if (c is >= 'ً' and <= 'ٟ' or 'ٰ' or >= 'ۖ' and <= 'ۭ' or 'ـ') continue;
            sb.Append(c switch
            {
                'أ' or 'إ' or 'آ' or 'ٱ' => 'ا',
                'ى' => 'ي',
                'ة' => 'ه',
                _ => char.ToLowerInvariant(c),
            });
        }
        return sb.ToString();
    }
}

/// <summary>Locates the bundled Qur'an files and checks them against the manifest.</summary>
public static class QuranFiles
{
    static Dictionary<string, string>? _hashes;
    static readonly Dictionary<string, bool> Verified = new();

    /// <summary>Quran\ next to the executable; during development, shared/QuranAssets in this project.</summary>
    public static string? Resolve(string relative)
    {
        var bundled = Path.Combine(AppContext.BaseDirectory, "Quran", relative);
        if (File.Exists(bundled)) return bundled;
        var dir = new DirectoryInfo(AppContext.BaseDirectory);
        for (int i = 0; i < 8 && dir is not null; i++, dir = dir.Parent)
        {
            foreach (var candidate in new[] { Path.Combine(dir.FullName, "shared", "QuranAssets", relative), Path.Combine(dir.FullName, "QuranAssets", relative) })
                if (File.Exists(candidate)) return candidate;
        }
        return null;
    }

    static Dictionary<string, string> Hashes()
    {
        if (_hashes is not null) return _hashes;
        var result = new Dictionary<string, string>(StringComparer.OrdinalIgnoreCase);
        if (Resolve("source-manifest.json") is string manifest)
        {
            using var doc = JsonDocument.Parse(File.ReadAllBytes(manifest));
            void Walk(JsonElement e)
            {
                if (e.ValueKind == JsonValueKind.Object)
                {
                    if (e.TryGetProperty("sha256", out var h) && (e.TryGetProperty("path", out var p) || e.TryGetProperty("file", out p)))
                        result[p.GetString() ?? ""] = h.GetString() ?? "";
                    foreach (var prop in e.EnumerateObject()) Walk(prop.Value);
                }
                else if (e.ValueKind == JsonValueKind.Array)
                    foreach (var item in e.EnumerateArray()) Walk(item);
            }
            Walk(doc.RootElement);
        }
        return _hashes = result;
    }

    public static bool Verify(string relative, string path)
    {
        if (Verified.TryGetValue(path, out var ok)) return ok;
        var expected = Hashes().TryGetValue(relative, out var h) ? h : null;
        if (expected is null) return Verified[path] = false;
        using var stream = File.OpenRead(path);
        var actual = Convert.ToHexString(SHA256.HashData(stream));
        return Verified[path] = string.Equals(actual, expected, StringComparison.OrdinalIgnoreCase);
    }
}

/// <summary>QuranEnc translations of meanings (verbatim SQLite snapshots, Hafs numbering only).</summary>
public sealed record QuranTranslation(string Key, string Language, string Title, string File)
{
    public static readonly QuranTranslation[] All =
    {
        new("en", "en", "English — Rowwad Translation Center", "Translations/QuranEnc/english_rwwad_v1.0.19.sqlite"),
        new("fr", "fr", "Français — Rashid Maash", "Translations/QuranEnc/french_rashid_v1.0.3.sqlite"),
        new("es", "es", "Español — Isa García", "Translations/QuranEnc/spanish_garcia_v1.0.2.sqlite"),
        new("pt", "pt", "Português — Helmi Nasr", "Translations/QuranEnc/portuguese_nasr_v1.4.1.sqlite"),
        new("zh", "zh", "中文 — 穆罕默德·苏莱曼", "Translations/QuranEnc/chinese_suliman_v1.0.8.sqlite"),
        new("ur", "ur", "اردو — محمد جوناگڑھی", "Translations/QuranEnc/urdu_junagarhi_v1.1.3.sqlite"),
        new("hi", "hi", "हिन्दी — अज़ीज़ुल हक़ उमरी", "Translations/QuranEnc/hindi_omari_v1.1.5.sqlite"),
    };

    public static QuranTranslation? ForLanguage(string code) => All.FirstOrDefault(t => t.Language == code);

    static readonly Dictionary<string, Dictionary<(int, int), string>?> Cache = new();

    /// <summary>All verses of the translation, or null when the file is missing or fails verification.</summary>
    public Dictionary<(int, int), string>? Load()
    {
        if (Cache.TryGetValue(Key, out var cached)) return cached;
        Dictionary<(int, int), string>? rows = null;
        try
        {
            if (QuranFiles.Resolve(File) is string path && QuranFiles.Verify(File, path))
            {
                rows = new();
                using var connection = new SqliteConnection(new SqliteConnectionStringBuilder { DataSource = path, Mode = SqliteOpenMode.ReadOnly }.ToString());
                connection.Open();
                using var cmd = connection.CreateCommand();
                cmd.CommandText = "SELECT sura, aya, translation FROM translations";
                using var reader = cmd.ExecuteReader();
                while (reader.Read()) rows[(reader.GetInt32(0), reader.GetInt32(1))] = reader.IsDBNull(2) ? "" : reader.GetString(2);
            }
        }
        catch (Exception ex) when (ex is SqliteException or IOException or InvalidOperationException) { rows = null; }
        Cache[Key] = rows;
        return rows;
    }
}

/// <summary>A reciter on EveryAyah.com (verse-by-verse MP3s, Hafs numbering).</summary>
public sealed record QuranReciter(string Id, string Arabic, string Latin)
{
    public static readonly QuranReciter[] All =
    {
        new("Alafasy_128kbps", "مشاري راشد العفاسي", "Mishary Rashid Alafasy"),
        new("Abdul_Basit_Murattal_192kbps", "عبد الباسط عبد الصمد (مرتّل)", "Abdul Basit (Murattal)"),
        new("Husary_128kbps", "محمود خليل الحصري", "Mahmoud Khalil Al-Husary"),
        new("Minshawy_Murattal_128kbps", "محمد صديق المنشاوي (مرتّل)", "Mohamed Siddiq Al-Minshawi (Murattal)"),
        new("Abdurrahmaan_As-Sudais_192kbps", "عبد الرحمن السديس", "Abdurrahman As-Sudais"),
        new("Saood_ash-Shuraym_128kbps", "سعود الشريم", "Saud Ash-Shuraim"),
        new("MaherAlMuaiqly128kbps", "ماهر المعيقلي", "Maher Al-Muaiqly"),
        new("Yasser_Ad-Dussary_128kbps", "ياسر الدوسري", "Yasser Al-Dosari"),
        new("Ghamadi_40kbps", "سعد الغامدي", "Saad Al-Ghamdi"),
        new("Hudhaify_128kbps", "علي الحذيفي", "Ali Al-Hudhaify"),
        new("Muhammad_Ayyoub_128kbps", "محمد أيوب", "Muhammad Ayyub"),
        new("Nasser_Alqatami_128kbps", "ناصر القطامي", "Nasser Al-Qatami"),
    };

    public string Name => Localizer.Shared.IsRtl ? Arabic : Latin;
}

/// <summary>
/// Recitation audio — the one runtime download the project allows: verse MP3s
/// are fetched only after the user presses play (current verse first, a few
/// ahead), kept under %APPDATA%\SalatTime\QuranAudio and replayed offline.
/// </summary>
public static class QuranAudioCache
{
    static readonly HttpClient Http = new() { Timeout = TimeSpan.FromSeconds(30) };

    public static string FileName(int sura, int ayah) => $"{sura:000}{ayah:000}.mp3";

    public static string LocalPath(QuranReciter reciter, int sura, int ayah)
    {
        var dir = Path.Combine(AppSettings.Folder, "QuranAudio", reciter.Id);
        Directory.CreateDirectory(dir);
        return Path.Combine(dir, FileName(sura, ayah));
    }

    public static async Task<string?> EnsureAsync(QuranReciter reciter, int sura, int ayah, CancellationToken ct)
    {
        var path = LocalPath(reciter, sura, ayah);
        if (File.Exists(path) && new FileInfo(path).Length > 1024) return path;
        try
        {
            var bytes = await Http.GetByteArrayAsync($"https://everyayah.com/data/{reciter.Id}/{FileName(sura, ayah)}", ct);
            if (bytes.Length < 1024) return null;
            var tmp = path + ".part";
            await File.WriteAllBytesAsync(tmp, bytes, ct);
            File.Move(tmp, path, true);
            return path;
        }
        catch (Exception ex) when (ex is HttpRequestException or TaskCanceledException or IOException) { return null; }
    }
}

/// <summary>A saved place: edition, surah and verse only (never Qur'an text).</summary>
public sealed class QuranBookmark
{
    public string Edition { get; set; } = "hafs";
    public int Sura { get; set; }
    public int Ayah { get; set; }
    public DateTime Created { get; set; } = DateTime.Now;
}
