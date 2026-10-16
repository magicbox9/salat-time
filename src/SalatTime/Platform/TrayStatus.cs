using Avalonia.Media;
using SalatTime.Core;

namespace SalatTime.Platform;

public enum TrayIconKind
{
    /// <summary>The crescent icon.</summary>
    Idle,
    /// <summary>Minutes to the next adhan, inside the last hour.</summary>
    Countdown,
    /// <summary>Red: minutes left between the adhan and the iqama.</summary>
    Iqama,
}

/// <summary>
/// What the tray shows right now — the Windows counterpart of the Mac
/// menu-bar title: the icon (crescent, minutes, or red iqama countdown) and
/// the hover text with the next prayer, its time, the countdown and the Hijri date.
/// </summary>
public sealed record TrayStatus(TrayIconKind Kind, int Minutes, string Tooltip, Color Accent, bool AdhanPlaying)
{
    public static TrayStatus Compute(AppState state, DateTime now)
    {
        var s = state.Settings;
        var l = Localizer.Shared;
        var accent = AppTheme.Pair(s.Accent).Light;
        var hijri = Hijri.Format(now, s.TrayHijri, state.Info.HijriAdjustment ?? 0);
        var lines = new List<string> { state.MosqueName };

        if (!state.Info.HasTimes)
        {
            if (hijri.Length > 0) lines.Add(hijri);
            return new TrayStatus(TrayIconKind.Idle, 0, string.Join("\n", lines), accent, state.IsAdhanPlaying);
        }

        if (PrayerClock.AdhanWindow(state.Info, now) is var (index, iqama))
        {
            var left = iqama - now;
            lines.Add($"{l.PrayerName(index)} {l.Time(state.Today.Adhan[index], s.Use12h)}  ·  {l.T("col.iqama")} {l.Digits(TimeText.Countdown(left))}");
            if (hijri.Length > 0) lines.Add(hijri);
            if (state.IsAdhanPlaying) lines.Add(l.T("win:tray.double_click_stop"));
            return new TrayStatus(TrayIconKind.Iqama, (int)Math.Ceiling(left.TotalMinutes), string.Join("\n", lines), accent, state.IsAdhanPlaying);
        }

        if (PrayerClock.Next(state.Info, now) is var (next, at, _))
        {
            var diff = at - now;
            var day = PrayerDay.For(state.Info, at);
            lines.Add($"{l.PrayerName(next)} {l.Time(day.Adhan[next], s.Use12h)}  ·  {l.Digits(TimeText.Countdown(diff))}");
            if (hijri.Length > 0) lines.Add(hijri);
            if (state.IsAdhanPlaying) lines.Add(l.T("win:tray.double_click_stop"));
            var soon = s.TrayCountdownIcon && diff.TotalMinutes < 60;
            return new TrayStatus(soon ? TrayIconKind.Countdown : TrayIconKind.Idle,
                (int)Math.Ceiling(diff.TotalMinutes), string.Join("\n", lines), accent, state.IsAdhanPlaying);
        }

        return new TrayStatus(TrayIconKind.Idle, 0, string.Join("\n", lines), accent, state.IsAdhanPlaying);
    }
}
