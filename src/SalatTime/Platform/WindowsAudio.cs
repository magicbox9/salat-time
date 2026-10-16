using System.Runtime.InteropServices;
using System.Runtime.Versioning;
using Avalonia.Threading;
using NAudio.CoreAudioApi;
using NAudio.Wave;
using NAudio.Wave.SampleProviders;
using SalatTime.Core;

namespace SalatTime.Platform;

/// <summary>
/// Adhan playback through WASAPI on a chosen output device, so the adhan can
/// stay on the PC speakers while you wear headphones. The volume slider sets
/// that device's own volume (the system default output is left alone),
/// exactly like the Mac app.
/// </summary>
[SupportedOSPlatform("windows")]
public sealed class WindowsAudio : IAudioService
{
    WasapiOut? _output;
    WaveStream? _reader;
    VolumeSampleProvider? _volume;

    public bool IsPlaying => _output is { PlaybackState: PlaybackState.Playing };
    public event Action? StateChanged;
    public event Action? Finished;

    public IReadOnlyList<AudioDevice> OutputDevices()
    {
        try
        {
            using var e = new MMDeviceEnumerator();
            return e.EnumerateAudioEndPoints(DataFlow.Render, DeviceState.Active)
                .Select(d => new AudioDevice(d.ID, d.FriendlyName))
                .OrderBy(d => d.Name, StringComparer.CurrentCultureIgnoreCase)
                .ToList();
        }
        catch (COMException) { return Array.Empty<AudioDevice>(); }
    }

    MMDevice? Device(string deviceId)
    {
        try
        {
            var e = new MMDeviceEnumerator();
            if (!string.IsNullOrEmpty(deviceId))
            {
                try
                {
                    var d = e.GetDevice(deviceId);
                    if (d.State == DeviceState.Active) return d;
                }
                catch (COMException) { }
            }
            return e.GetDefaultAudioEndpoint(DataFlow.Render, Role.Multimedia);
        }
        catch (COMException) { return null; }
    }

    public AudioDevice? ResolveDevice(string deviceId) =>
        Device(deviceId) is { } d ? new AudioDevice(d.ID, d.FriendlyName) : null;

    public void Play(string? file, string deviceId, double appVolume)
    {
        Stop(raise: false);
        if (file is null || !File.Exists(file))
        {
            PlaySound("SystemNotification", IntPtr.Zero, SND_ALIAS | SND_ASYNC | SND_NODEFAULT);
            StateChanged?.Invoke();
            return;
        }
        try
        {
            var device = Device(deviceId);
            if (device is null) return;
            _reader = OpenReader(file);
            _volume = new VolumeSampleProvider(_reader.ToSampleProvider()) { Volume = (float)Math.Clamp(appVolume, 0, 1) };
            if (DeviceVolume(deviceId) is not null) _volume.Volume = 1f;   // the device slider sets the level
            _output = new WasapiOut(device, AudioClientShareMode.Shared, true, 200);
            _output.Init(_volume);
            var output = _output;
            output.PlaybackStopped += (_, _) => Dispatcher.UIThread.Post(() =>
            {
                if (!ReferenceEquals(output, _output)) return;   // stopped on purpose
                Stop();
                Finished?.Invoke();
            });
            _output.Play();
        }
        catch (Exception ex) when (ex is COMException or InvalidOperationException or IOException)
        {
            Stop(raise: false);
            PlaySound("SystemNotification", IntPtr.Zero, SND_ALIAS | SND_ASYNC | SND_NODEFAULT);
        }
        StateChanged?.Invoke();
    }

    static WaveStream OpenReader(string file)
    {
        try { return new MediaFoundationReader(file); }
        catch (COMException) { return new Mp3FileReaderBase(file, format => new AcmMp3FrameDecompressor(format)); }   // Windows "N" editions without Media Foundation
    }

    public void Stop() => Stop(raise: true);

    void Stop(bool raise)
    {
        var wasPlaying = _output is not null;
        try { _output?.Stop(); } catch { }
        _output?.Dispose();
        _reader?.Dispose();
        _output = null;
        _reader = null;
        _volume = null;
        if (raise && wasPlaying) StateChanged?.Invoke();
    }

    public float? DeviceVolume(string deviceId)
    {
        try { return Device(deviceId)?.AudioEndpointVolume.MasterVolumeLevelScalar; }
        catch (Exception ex) when (ex is COMException or NotSupportedException) { return null; }
    }

    public void SetDeviceVolume(string deviceId, float volume)
    {
        try
        {
            if (Device(deviceId)?.AudioEndpointVolume is not { } endpoint) return;
            endpoint.MasterVolumeLevelScalar = Math.Clamp(volume, 0f, 1f);
            if (volume > 0 && endpoint.Mute) endpoint.Mute = false;   // raising a muted speaker makes it audible
        }
        catch (Exception ex) when (ex is COMException or NotSupportedException) { }
    }

    public void SetAppVolume(double volume)
    {
        if (_volume is not null) _volume.Volume = (float)Math.Clamp(volume, 0, 1);
    }

    const uint SND_ASYNC = 0x1, SND_NODEFAULT = 0x2, SND_ALIAS = 0x10000;
    [DllImport("winmm.dll", CharSet = CharSet.Unicode)] static extern bool PlaySound(string sound, IntPtr module, uint flags);
}
