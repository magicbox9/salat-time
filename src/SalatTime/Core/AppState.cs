using System.Globalization;
using System.Text.Json;

namespace SalatTime.Core;

/// <summary>
/// The app's live state: settings, the selected mosque's schedule, and the
/// once-a-second scheduler that fires the adhan, heads-up and notifications
/// exactly like the Mac app (same per-prayer modes and once-a-day markers).
/// </summary>
public sealed class AppState
{
    public AppSettings Settings { get; }
    public MosqueInfo Info { get; private set; } = new();
    public IAudioService Audio { get; }
    /// <summary>A second player so adhkar recitation never cuts the adhan off (default output).</summary>
    public IAudioService AdhkarAudio { get; }
    public INotifier Notifier { get; }
    public bool IsRefreshing { get; private set; }
    public DateTime? LastRefresh { get; private set; }
    public string? LastError { get; private set; }

    public event Action? InfoChanged;
    public event Action<DateTime>? Ticked;
    public event Action? AdhanStateChanged;
    /// <summary>An adhkar collection is due (anchor "shuruq", "asr", ...).</summary>
    public event Action<string>? AdhkarDue;

    public AppState(AppSettings settings, IAudioService audio, INotifier notifier, IAudioService? adhkarAudio = null)
    {
        Settings = settings;
        Audio = audio;
        AdhkarAudio = adhkarAudio ?? new NullAudio();
        Notifier = notifier;
        Audio.StateChanged += () => AdhanStateChanged?.Invoke();
        LoadCache();
    }

    public bool IsAdhanPlaying => Audio.IsPlaying;
    public PrayerDay Today => PrayerDay.For(Info, Clock.Now());

    // ------------------------------------------------------------------ cache

    static string CachePath => Path.Combine(AppSettings.Folder, "mosque.json");

    void LoadCache()
    {
        try
        {
            if (File.Exists(CachePath))
                Info = JsonSerializer.Deserialize<MosqueInfo>(File.ReadAllText(CachePath), AppSettings.Json) ?? new();
        }
        catch { Info = new(); }
    }

    void SaveCache()
    {
        try { File.WriteAllText(CachePath, JsonSerializer.Serialize(Info, AppSettings.Json)); } catch { }
    }

    /// <summary>Use a schedule directly (screenshots, imported caches).</summary>
    public void ReplaceInfo(MosqueInfo info)
    {
        Info = info;
        InfoChanged?.Invoke();
    }

    // ------------------------------------------------------------------ refresh

    public async Task<bool> RefreshAsync()
    {
        if (IsRefreshing) return false;
        IsRefreshing = true;
        InfoChanged?.Invoke();
        try
        {
            var next = await MawaqitClient.FetchMosqueAsync(Settings.MosqueUrl);
            if (next is { HasTimes: true })
            {
                if (string.IsNullOrWhiteSpace(next.Name)) next.Name = Info.Name;
                Info = next;
                LastRefresh = Clock.Now();
                LastError = null;
                SaveCache();
                return true;
            }
            LastError = "fetch";
            return false;
        }
        finally
        {
            IsRefreshing = false;
            InfoChanged?.Invoke();
        }
    }

    /// <summary>Switch to another mosque and load its schedule.</summary>
    public async Task<bool> SelectMosqueAsync(string url)
    {
        Settings.MosqueUrl = MosqueUrls.Normalize(url);
        Settings.Save();
        var previous = Info;
        Info = new MosqueInfo { Name = previous.Name };
        var ok = await RefreshAsync();
        if (!ok) { Info = previous; InfoChanged?.Invoke(); }
        return ok;
    }

    // ------------------------------------------------------------------ tick

    DateTime _lastRefreshAttempt = DateTime.MinValue;
    string _lastDay = "";

    /// <summary>Called once a second by the UI timer.</summary>
    public void Tick(DateTime now)
    {
        var day = now.ToString("yyyy-MM-dd", CultureInfo.InvariantCulture);
        // Refresh every 30 minutes, and right after midnight.
        if ((now - _lastRefreshAttempt).TotalMinutes >= 30 || (_lastDay.Length > 0 && _lastDay != day))
        {
            _lastRefreshAttempt = now;
            _ = RefreshAsync();
        }
        _lastDay = day;

        if (Info.HasTimes)
        {
            CheckAdhkar(now);
            CheckAdhan(now);
        }
        Ticked?.Invoke(now);
    }

    void CheckAdhan(DateTime now)
    {
        var today = Today;
        var todayKey = now.ToString("yyyy-MM-dd", CultureInfo.InvariantCulture);
        var lead = Math.Max(0, Settings.PreAdhanLeadMinutes);
        var l = Localizer.Shared;
        var changed = false;

        for (int i = 0; i < 5; i++)
        {
            if (today.AdhanAt(i) is not DateTime when) continue;
            var dt = (now - when).TotalSeconds;

            // Heads-up, N minutes before (once per prayer per day).
            if (lead > 0 && Settings.NotificationsEnabled)
            {
                var pre = $"{todayKey}#{i}:pre";
                var last = Settings.LastPreAdhanMarker;
                var done = last == pre || (string.CompareOrdinal(last, pre) > 0 && last.StartsWith(todayKey, StringComparison.Ordinal));
                if (!done && dt >= -lead * 60 && dt < -lead * 60 + 60)
                {
                    if (Settings.ModeFor(i) != AdhanMode.Off)
                        Notifier.Show(l.F("settings.notif.headsup.title", l.PrayerName(i), lead),
                                      $"{MosqueName} · {l.Time(today.Adhan[i], Settings.Use12h)}");
                    Settings.LastPreAdhanMarker = pre;
                    changed = true;
                }
            }

            // The adhan itself.
            var marker = $"{todayKey}#{i}";
            var lastKey = Settings.LastAdhanMarker;
            if (lastKey == marker) continue;
            if (string.CompareOrdinal(lastKey, marker) > 0 && lastKey.StartsWith(todayKey, StringComparison.Ordinal)) continue;
            if (dt >= 0 && dt < 60)
            {
                switch (Settings.ModeFor(i))
                {
                    case AdhanMode.Notify:
                        if (Settings.NotificationsEnabled) NotifyPrayer(i, today.Adhan[i]);
                        break;
                    case AdhanMode.Adhan:
                        if (Settings.AdhanEnabled) PlayAdhan(i);
                        if (Settings.NotificationsEnabled) NotifyPrayer(i, today.Adhan[i]);
                        break;
                }
                Settings.LastAdhanMarker = marker;
                changed = true;
                break;
            }
        }
        if (changed) Settings.Save(notify: false);
    }

    void NotifyPrayer(int i, string time)
    {
        var l = Localizer.Shared;
        Notifier.Show($"{l.PrayerName(i)} · {l.Time(time, Settings.Use12h)}", MosqueName);
    }

    public string MosqueName => string.IsNullOrWhiteSpace(Info.Name) ? Localizer.Shared.T("mosque.default") : Info.Name.Replace("  ", " ");

    // ------------------------------------------------------------------ adhan audio

    /// <summary>Play the adhan (Fajr may use its own recording). <paramref name="prayer"/> null = test.</summary>
    public void PlayAdhan(int? prayer = null)
    {
        var id = prayer == 0 && Settings.FajrAdhanSound.Length > 0 ? Settings.FajrAdhanSound : Settings.AdhanSound;
        var file = AdhanCatalog.FileFor(AdhanCatalog.Find(id));
        Audio.Play(file, Settings.AdhanDevice, Settings.AdhanVolume);
    }

    public void StopAdhan() => Audio.Stop();

    public void ToggleTestAdhan()
    {
        if (Audio.IsPlaying) StopAdhan(); else PlayAdhan();
    }

    // ------------------------------------------------------------------ adhkar

    void CheckAdhkar(DateTime now)
    {
        if (!Settings.AdhkarEnabled) return;
        var today = Today;
        var key = now.ToString("yyyy-MM-dd", CultureInfo.InvariantCulture);
        Check(Settings.AdhkarMorningAnchor, Settings.LastAdhkarMorning, v => Settings.LastAdhkarMorning = v, "morning");
        Check(Settings.AdhkarEveningAnchor, Settings.LastAdhkarEvening, v => Settings.LastAdhkarEvening = v, "evening");

        void Check(string anchor, string last, Action<string> set, string kind)
        {
            if (last == key) return;
            var time = anchor switch
            {
                "shuruq" => today.Shuruq,
                "fajr" => today.Adhan[0],
                "asr" => today.Adhan[2],
                "maghrib" => today.Adhan[3],
                "isha" => today.Adhan[4],
                _ => null,
            };
            if (TimeText.Minutes(time) is not int m) return;
            var dt = (now - TimeText.At(now, m)).TotalSeconds;
            if (dt >= 0 && dt < 60)
            {
                set(key);
                Settings.Save(notify: false);
                AdhkarDue?.Invoke(kind);
            }
        }
    }
}
