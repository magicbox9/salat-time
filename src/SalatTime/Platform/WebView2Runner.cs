using System.Runtime.InteropServices;
using System.Runtime.Versioning;
using System.Text.Json;
using Avalonia.Threading;
using Microsoft.Web.WebView2.Core;
using SalatTime.Core;

namespace SalatTime.Platform;

/// <summary>
/// Loads a page in an invisible WebView2 (Edge) and runs a script in it — the
/// Windows counterpart of the Mac app's hidden WKWebView. Used only when the
/// plain HTTP read of a MAWAQIT page or search doesn't work.
/// </summary>
[SupportedOSPlatform("windows")]
public sealed class WebView2Runner : IWebPageRunner
{
    readonly SemaphoreSlim _gate = new(1, 1);
    CoreWebView2Environment? _env;
    IntPtr _host;
    bool _unavailable;

    public Task<WebPageResult> EvaluateAsync(string url, string script, TimeSpan settleDelay, CancellationToken ct) =>
        Dispatcher.UIThread.InvokeAsync(() => RunAsync(url, script, settleDelay, ct));

    async Task<WebPageResult> RunAsync(string url, string script, TimeSpan settleDelay, CancellationToken ct)
    {
        if (_unavailable) return default;
        await _gate.WaitAsync(ct);
        CoreWebView2Controller? controller = null;
        try
        {
            _env ??= await CoreWebView2Environment.CreateAsync(null, Path.Combine(AppSettings.Folder, "WebView2"));
            if (_host == IntPtr.Zero)
                _host = CreateWindowEx(0, "Static", "", WS_POPUP, 0, 0, 1024, 768, IntPtr.Zero, IntPtr.Zero, IntPtr.Zero, IntPtr.Zero);
            controller = await _env.CreateCoreWebView2ControllerAsync(_host);
            controller.IsVisible = false;
            var core = controller.CoreWebView2;
            core.Settings.AreDefaultScriptDialogsEnabled = false;
            core.Settings.IsStatusBarEnabled = false;

            var loaded = new TaskCompletionSource<bool>(TaskCreationOptions.RunContinuationsAsynchronously);
            core.NavigationCompleted += (_, e) => loaded.TrySetResult(e.IsSuccess);
            core.Navigate(url);
            using var timeout = CancellationTokenSource.CreateLinkedTokenSource(ct);
            timeout.CancelAfter(TimeSpan.FromSeconds(18));
            if (!await loaded.Task.WaitAsync(timeout.Token)) return default;
            if (settleDelay > TimeSpan.Zero) await Task.Delay(settleDelay, ct);

            var raw = await core.ExecuteScriptAsync(script);
            var json = raw is null or "null" ? null : JsonSerializer.Deserialize<string>(raw);
            return new WebPageResult(json, core.Source);
        }
        catch (WebView2RuntimeNotFoundException)
        {
            _unavailable = true;
            return default;
        }
        catch (Exception ex) when (ex is OperationCanceledException or COMException or InvalidOperationException or JsonException)
        {
            return default;
        }
        finally
        {
            controller?.Close();
            _gate.Release();
        }
    }

    const int WS_POPUP = unchecked((int)0x80000000);

    [DllImport("user32.dll", CharSet = CharSet.Unicode, SetLastError = true)]
    static extern IntPtr CreateWindowEx(int exStyle, string className, string windowName, int style, int x, int y, int w, int h,
        IntPtr parent, IntPtr menu, IntPtr instance, IntPtr param);
}
