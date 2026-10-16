using Avalonia;
using Avalonia.Media;

namespace SalatTime;

static class Program
{
    const string InstanceMutexName = "Local\\SalatTime.Instance";
    const string ActivateEventName = "Local\\SalatTime.Activate";

    internal static bool StartedInBackground { get; private set; }
    static Mutex? _instanceMutex;

    [STAThread]
    public static void Main(string[] args)
    {
        StartedInBackground = args.Contains("--background");

        // One copy at a time: a second launch asks the running one to show itself.
        _instanceMutex = new Mutex(true, InstanceMutexName, out var isFirst);
        if (!isFirst)
        {
            try { EventWaitHandle.OpenExisting(ActivateEventName).Set(); } catch { }
            return;
        }
        var activate = new EventWaitHandle(false, EventResetMode.AutoReset, ActivateEventName);
        var listener = new Thread(() =>
        {
            while (activate.WaitOne())
                App.Instance?.ActivateFromSecondLaunch();
        }) { IsBackground = true, Name = "SalatTime.Activate" };
        listener.Start();

        BuildAvaloniaApp().StartWithClassicDesktopLifetime(args, Avalonia.Controls.ShutdownMode.OnExplicitShutdown);
        GC.KeepAlive(_instanceMutex);
    }

    public static AppBuilder BuildAvaloniaApp()
    {
        var builder = AppBuilder.Configure<App>().UsePlatformDetect().LogToTrace();
        // Arabic-script text (mosque names, adhkar) always has a face, whatever the UI font.
        var cairo = new FontFallback { FontFamily = new FontFamily("avares://SalatTime/Assets/Fonts#Cairo") };
        if (!OperatingSystem.IsWindows())
            builder = builder.With(new FontManagerOptions { FontFallbacks = new[] { cairo } });
        if (OperatingSystem.IsWindows())
        {
            builder = builder
                .With(new FontManagerOptions
                {
                    DefaultFamilyName = "Segoe UI Variable Text",
                    FontFallbacks = new[]
                    {
                        new FontFallback { FontFamily = new FontFamily("Segoe UI") },
                        cairo,
                    },
                })
                .With(new Win32PlatformOptions
                {
                    CompositionMode = new[] { Win32CompositionMode.WinUIComposition, Win32CompositionMode.RedirectionSurface },
                });
        }
        return builder;
    }
}
