namespace SalatTime.Core;

public sealed record AdhanOption(string Id, string Name, string FileName);

/// <summary>The 14 curated recordings the Mac app bundles (sourced from Assabile), plus a short chime.</summary>
public static class AdhanCatalog
{
    public static readonly AdhanOption[] All =
    {
        new("makkah_mulla", "Makkah — Sheikh Ali Ibn Ahmed Mala", "adhan_makkah_mulla.mp3"),
        new("madinah", "Madinah — Masjid an-Nabawi", "adhan_madinah.mp3"),
        new("aqsa", "Al-Aqsa — Naji Qazzaz", "adhan_aqsa.mp3"),
        new("dossari", "Yasser Al-Dossari", "adhan_dossari.mp3"),
        new("zahrani", "Mansour Al-Zahrani", "adhan_zahrani.mp3"),
        new("obaid", "Nasser Al-Obaid", "adhan_obaid.mp3"),
        new("majali", "Hamza Al-Majali", "adhan_majali.mp3"),
        new("yamani", "Wadi' Hammadi Al-Yamani", "adhan_yamani.mp3"),
        new("kabbara", "Mohammed Salahuddin Kabbara", "adhan_kabbara.mp3"),
        new("kourdi", "Ahmed Al-Kourdi", "adhan_kourdi.mp3"),
        new("feqy", "Mohamed Abdel-Basset Al-Feqy", "adhan_feqy.mp3"),
        new("damradach", "Mohammed Al-Damradach", "adhan_damradach.mp3"),
        new("kreiny", "Mohammed Al-Kreiny Al-Malouki", "adhan_kreiny.mp3"),
        new("jazairi", "Rabih Ibn Darah Al-Jazairi", "adhan_jazairi.mp3"),
        new("chime", "System sound", ""),
    };

    public static AdhanOption Find(string? id) => All.FirstOrDefault(a => a.Id == id) ?? All[0];

    /// <summary>Folder holding the recordings (next to SalatTime.exe).</summary>
    public static string AudioFolder => Path.Combine(AppContext.BaseDirectory, "Audio");

    public static string? FileFor(AdhanOption option)
    {
        if (option.FileName.Length == 0) return null;
        var path = Path.Combine(AudioFolder, option.FileName);
        if (File.Exists(path)) return path;
        // A user-supplied fallback, like the Mac app's ~/Music/adhan.mp3.
        var music = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.MyMusic), "adhan.mp3");
        return File.Exists(music) ? music : null;
    }
}
