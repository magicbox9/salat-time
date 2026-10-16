using System.Text.Json;
using System.Text.Json.Serialization;
using Avalonia.Platform;

namespace SalatTime.Core;

/// <summary>One dhikr from the bundled Hisn al-Muslim library (adhkar.json, shared with the Mac app).</summary>
public sealed class AdhkarItem
{
    [JsonPropertyName("arabic")] public string Arabic { get; set; } = "";
    [JsonPropertyName("count")] public int Count { get; set; } = 1;
    [JsonPropertyName("count_desc")] public string CountDescription { get; set; } = "";
    [JsonPropertyName("virtue")] public string Virtue { get; set; } = "";
    [JsonPropertyName("source")] public string Source { get; set; } = "";
    [JsonPropertyName("audio_file")] public string AudioFile { get; set; } = "";

    /// <summary>The recitation next to the executable (Audio\adhkar), if it was bundled.</summary>
    public string? AudioPath
    {
        get
        {
            if (AudioFile.Length == 0) return null;
            var path = Path.Combine(AppContext.BaseDirectory, "Audio", "adhkar", AudioFile);
            return File.Exists(path) ? path : null;
        }
    }
}

public static class AdhkarLibrary
{
    /// <summary>Categories in the Mac app's order.</summary>
    public static readonly string[] Categories =
    {
        "morning", "evening", "post_prayer", "sleep", "waking", "after_ablution", "entering_mosque", "leaving_mosque",
        "before_eating", "after_eating", "entering_home", "leaving_home", "distress", "forgiveness",
    };

    static Dictionary<string, List<AdhkarItem>>? _cache;

    public static Dictionary<string, List<AdhkarItem>> All
    {
        get
        {
            if (_cache is not null) return _cache;
            var result = new Dictionary<string, List<AdhkarItem>>();
            try
            {
                using var stream = AssetLoader.Open(new Uri("avares://SalatTime/Assets/adhkar.json"));
                using var doc = JsonDocument.Parse(stream);
                foreach (var prop in doc.RootElement.EnumerateObject())
                {
                    // Any array is a category; metadata such as "_meta" is skipped.
                    if (prop.Value.ValueKind != JsonValueKind.Array) continue;
                    result[prop.Name] = prop.Value.Deserialize<List<AdhkarItem>>() ?? new();
                }
            }
            catch (Exception ex) when (ex is IOException or JsonException or FileNotFoundException) { }
            return _cache = result;
        }
    }

    public static List<AdhkarItem> Items(string category) => All.TryGetValue(category, out var list) ? list : new();

    static readonly Dictionary<string, string[]> Names = new()
    {
        // post_prayer, sleep, waking, after_ablution, entering_mosque, leaving_mosque, before_eating, after_eating, entering_home, leaving_home, distress, forgiveness
        ["en"] = new[] { "After Prayer", "Before Sleep", "Upon Waking", "After Ablution", "Entering the Mosque", "Leaving the Mosque", "Before Eating", "After Eating", "Entering Home", "Leaving Home", "Distress and Worry", "Forgiveness and Repentance" },
        ["fr"] = new[] { "Après la prière", "Avant de dormir", "Au réveil", "Après les ablutions", "Entrée à la mosquée", "Sortie de la mosquée", "Avant de manger", "Après avoir mangé", "Entrée à la maison", "Sortie de la maison", "Détresse et souci", "Pardon et repentir" },
        ["es"] = new[] { "Después de la oración", "Antes de dormir", "Al despertar", "Después de la ablución", "Al entrar en la mezquita", "Al salir de la mezquita", "Antes de comer", "Después de comer", "Al entrar en casa", "Al salir de casa", "Angustia y preocupación", "Perdón y arrepentimiento" },
        ["ar"] = new[] { "أذكار بعد الصلاة", "أذكار النوم", "أذكار الاستيقاظ", "أذكار بعد الوضوء", "أذكار دخول المسجد", "أذكار الخروج من المسجد", "أذكار قبل الطعام", "أذكار بعد الطعام", "أذكار دخول المنزل", "أذكار الخروج من المنزل", "أذكار الكرب والهم", "أذكار الاستغفار والتوبة" },
        ["zh"] = new[] { "礼拜后", "睡前", "醒来时", "小净后", "进入清真寺", "离开清真寺", "用餐前", "用餐后", "进入家中", "离开家中", "忧虑与困苦", "求饶与悔过" },
        ["hi"] = new[] { "नमाज़ के बाद", "सोने से पहले", "जागने पर", "वुज़ू के बाद", "मस्जिद में प्रवेश", "मस्जिद से निकलना", "खाने से पहले", "खाने के बाद", "घर में प्रवेश", "घर से निकलना", "चिंता और परेशानी", "माफ़ी और तौबा" },
        ["bn"] = new[] { "নামাজের পরে", "ঘুমের আগে", "ঘুম থেকে জাগলে", "ওযুর পরে", "মসজিদে প্রবেশ", "মসজিদ থেকে বের হওয়া", "খাওয়ার আগে", "খাওয়ার পরে", "ঘরে প্রবেশ", "ঘর থেকে বের হওয়া", "দুশ্চিন্তা ও কষ্ট", "ক্ষমা ও তওবা" },
        ["ru"] = new[] { "После молитвы", "Перед сном", "После пробуждения", "После омовения", "Вход в мечеть", "Выход из мечети", "Перед едой", "После еды", "Вход в дом", "Выход из дома", "Тревога и печаль", "Прощение и покаяние" },
        ["pt"] = new[] { "Depois da oração", "Antes de dormir", "Ao acordar", "Depois da ablução", "Ao entrar na mesquita", "Ao sair da mesquita", "Antes de comer", "Depois de comer", "Ao entrar em casa", "Ao sair de casa", "Angústia e preocupação", "Perdão e arrependimento" },
        ["ur"] = new[] { "نماز کے بعد", "سونے سے پہلے", "جاگنے پر", "وضو کے بعد", "مسجد میں داخلہ", "مسجد سے نکلنا", "کھانے سے پہلے", "کھانے کے بعد", "گھر میں داخلہ", "گھر سے نکلنا", "پریشانی اور غم", "مغفرت اور توبہ" },
    };

    public static string Name(string category)
    {
        var l = Localizer.Shared;
        if (category == "morning") return l.T("adhkar.morning_title");
        if (category == "evening") return l.T("adhkar.evening_title");
        var index = Array.IndexOf(Categories, category) - 2;
        if (index < 0) return category;
        return (Names.TryGetValue(l.Code, out var names) ? names : Names["en"])[index];
    }

    public static string Icon(string category) => category switch
    {
        "morning" => "WeatherSunnyLowRegular",
        "evening" => "WeatherPartlyCloudyDayRegular",
        "post_prayer" => "CheckmarkRegular",
        "sleep" => "WeatherMoonRegular",
        "waking" => "WeatherSunnyRegular",
        "entering_mosque" or "leaving_mosque" => "BuildingRegular",
        "entering_home" or "leaving_home" => "HomeRegular",
        "before_eating" or "after_eating" => "HeartRegular",
        "distress" => "HeartRegular",
        "forgiveness" => "SparkleRegular",
        _ => "BookRegular",
    };

    public static bool IsArabic(string text) => text.Any(c => c is >= '؀' and <= 'ۿ');
}
