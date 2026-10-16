namespace SalatTime.Core;

public sealed record AudioDevice(string Id, string Name);

/// <summary>Adhan playback on a chosen output device (WASAPI on Windows).</summary>
public interface IAudioService
{
    bool IsPlaying { get; }
    /// <summary>Raised on the UI thread when playback starts or stops.</summary>
    event Action? StateChanged;
    /// <summary>Raised on the UI thread when a recording plays to its end (not when stopped).</summary>
    event Action? Finished;
    IReadOnlyList<AudioDevice> OutputDevices();
    /// <summary>The device the adhan will use: the chosen one if connected, else the default output.</summary>
    AudioDevice? ResolveDevice(string deviceId);
    void Play(string? file, string deviceId, double appVolume);
    void Stop();
    /// <summary>That device's own volume (0–1), or null when it can't be read or set.</summary>
    float? DeviceVolume(string deviceId);
    void SetDeviceVolume(string deviceId, float volume);
    void SetAppVolume(double volume);
}

/// <summary>Desktop notifications (tray balloons, shown as Windows notifications).</summary>
public interface INotifier
{
    void Show(string title, string body);
}

public sealed class NullAudio : IAudioService
{
    public bool IsPlaying { get; private set; }
    public event Action? StateChanged;
    public event Action? Finished { add { } remove { } }
    public IReadOnlyList<AudioDevice> OutputDevices() => Array.Empty<AudioDevice>();
    public AudioDevice? ResolveDevice(string deviceId) => null;
    public void Play(string? file, string deviceId, double appVolume) { IsPlaying = true; StateChanged?.Invoke(); }
    public void Stop() { IsPlaying = false; StateChanged?.Invoke(); }
    public float? DeviceVolume(string deviceId) => null;
    public void SetDeviceVolume(string deviceId, float volume) { }
    public void SetAppVolume(double volume) { }
}

public sealed class NullNotifier : INotifier
{
    public void Show(string title, string body) => System.Diagnostics.Debug.WriteLine($"[notify] {title} — {body}");
}
