using System.Runtime.Versioning;
using Microsoft.Win32;

namespace SalatTime.Platform;

/// <summary>"Open at login": the per-user Run key, so no administrator rights are needed.</summary>
[SupportedOSPlatform("windows")]
public static class StartupRegistration
{
    const string RunKey = @"Software\Microsoft\Windows\CurrentVersion\Run";
    const string ValueName = "SalatTime";

    public static void Sync(bool enabled)
    {
        try
        {
            using var key = Registry.CurrentUser.OpenSubKey(RunKey, writable: true) ?? Registry.CurrentUser.CreateSubKey(RunKey);
            var exe = Environment.ProcessPath;
            if (enabled && !string.IsNullOrEmpty(exe))
            {
                var command = $"\"{exe}\" --background";
                if (key.GetValue(ValueName) as string != command) key.SetValue(ValueName, command);
            }
            else if (!enabled && key.GetValue(ValueName) is not null)
            {
                key.DeleteValue(ValueName, throwOnMissingValue: false);
            }
        }
        catch (Exception ex) when (ex is UnauthorizedAccessException or System.Security.SecurityException or IOException) { }
    }
}
