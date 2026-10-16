using System.Globalization;
using System.Runtime.InteropServices;
using System.Runtime.Versioning;
using Avalonia;
using Avalonia.Media;
using Avalonia.Media.Imaging;
using Avalonia.Platform;
using SalatTime.Core;

namespace SalatTime.Platform;

public interface ITray : IDisposable
{
    /// <summary>Left click, with the click point in physical screen pixels.</summary>
    event Action<PixelPoint>? LeftClick;
    event Action? DoubleClick;
    event Action<PixelPoint>? RightClick;
    /// <summary>Click on the red stop icon shown while the adhan plays.</summary>
    event Action? StopClick;
    event Action? BalloonClick;
    /// <summary>Where the icon sits on screen (physical pixels), when Windows reports it.</summary>
    PixelRect? IconRect { get; }
    void Update(TrayStatus status);
    void SetStopIconVisible(bool visible);
}

/// <summary>
/// The notification-area (tray) icon, written directly against Shell_NotifyIcon
/// so we get exact click positions, double-clicks and a dynamic icon that shows
/// the minutes left — the Windows counterpart of the Mac menu-bar item.
/// Notifications use the same icon (balloons appear as Windows notifications).
/// </summary>
[SupportedOSPlatform("windows")]
public sealed class Win32Tray : ITray, INotifier
{
    const int MainId = 1, StopId = 2;
    const int CallbackMessage = 0x8000 + 1;   // WM_APP + 1

    public event Action<PixelPoint>? LeftClick;
    public event Action? DoubleClick;
    public event Action<PixelPoint>? RightClick;
    public event Action? StopClick;
    public event Action? BalloonClick;

    readonly WndProc _proc;
    readonly IntPtr _hwnd;
    readonly uint _taskbarCreated;
    IntPtr _icon, _stopIcon, _balloonIcon;
    string _iconKey = "";
    string _tooltip = "Salat Time";
    bool _added, _stopVisible, _disposed;
    DateTime _suppressSelectUntil = DateTime.MinValue;

    public static int DoubleClickMilliseconds => OperatingSystem.IsWindows() ? (int)GetDoubleClickTime() : 500;

    public Win32Tray()
    {
        _proc = WindowProc;
        var hInstance = GetModuleHandle(null);
        var wc = new WNDCLASSEX
        {
            cbSize = (uint)Marshal.SizeOf<WNDCLASSEX>(),
            lpfnWndProc = Marshal.GetFunctionPointerForDelegate(_proc),
            hInstance = hInstance,
            lpszClassName = "SalatTime.TrayWindow",
        };
        RegisterClassEx(ref wc);
        // A hidden top-level window (not message-only) so it also receives the
        // "TaskbarCreated" broadcast after Explorer restarts.
        _hwnd = CreateWindowEx(0, wc.lpszClassName, "Salat Time", 0, 0, 0, 0, 0, IntPtr.Zero, IntPtr.Zero, hInstance, IntPtr.Zero);
        _taskbarCreated = RegisterWindowMessage("TaskbarCreated");
        _stopIcon = TrayIconArt.Stop(IconSize);
        _balloonIcon = TrayIconArt.AppIcon(32, AppTheme.Pair("green").Light);
        Add();
    }

    static int IconSize => Math.Max(16, GetSystemMetricsForDpi(SM_CXSMICON, GetDpiForSystem()));

    // ------------------------------------------------------------------ icon

    void Add()
    {
        if (_icon == IntPtr.Zero) { _icon = TrayIconArt.AppIcon(IconSize, AppTheme.Pair("green").Light); }
        var data = Data(MainId, NIF_MESSAGE | NIF_ICON | NIF_TIP | NIF_SHOWTIP);
        data.hIcon = _icon;
        data.szTip = Clip(_tooltip, 127);
        _added = Shell_NotifyIcon(NIM_ADD, ref data);
        data.uTimeoutOrVersion = NOTIFYICON_VERSION_4;
        Shell_NotifyIcon(NIM_SETVERSION, ref data);
        if (_stopVisible) { _stopVisible = false; SetStopIconVisible(true); }
    }

    public void Update(TrayStatus status)
    {
        if (_disposed) return;
        var key = $"{status.Kind}|{(status.Kind == TrayIconKind.Idle ? 0 : status.Minutes)}|{status.Accent}|{IconSize}";
        var flags = NIF_TIP | NIF_SHOWTIP;
        if (key != _iconKey)
        {
            var old = _icon;
            _icon = status.Kind switch
            {
                TrayIconKind.Countdown => TrayIconArt.Number(IconSize, status.Minutes, status.Accent),
                TrayIconKind.Iqama => TrayIconArt.Number(IconSize, status.Minutes, Color.FromRgb(196, 43, 28)),
                _ => TrayIconArt.AppIcon(IconSize, status.Accent),
            };
            _iconKey = key;
            flags |= NIF_ICON;
            if (old != IntPtr.Zero) DestroyIconLater(old);
        }
        _tooltip = status.Tooltip;
        var data = Data(MainId, flags);
        data.hIcon = _icon;
        data.szTip = Clip(_tooltip, 127);
        if (!_added) Add(); else Shell_NotifyIcon(NIM_MODIFY, ref data);
    }

    void DestroyIconLater(IntPtr icon)
    {
        // Explorer may still be drawing the previous icon; release it a moment later.
        Avalonia.Threading.DispatcherTimer.RunOnce(() => DestroyIcon(icon), TimeSpan.FromSeconds(2));
    }

    public void SetStopIconVisible(bool visible)
    {
        if (visible == _stopVisible || _disposed) return;
        _stopVisible = visible;
        var data = Data(StopId, NIF_MESSAGE | NIF_ICON | NIF_TIP | NIF_SHOWTIP);
        data.hIcon = _stopIcon;
        data.szTip = Clip(Localizer.Shared.T("menubar.stop_adhan"), 127);
        if (visible)
        {
            Shell_NotifyIcon(NIM_ADD, ref data);
            data.uTimeoutOrVersion = NOTIFYICON_VERSION_4;
            Shell_NotifyIcon(NIM_SETVERSION, ref data);
        }
        else Shell_NotifyIcon(NIM_DELETE, ref data);
    }

    public PixelRect? IconRect
    {
        get
        {
            var id = new NOTIFYICONIDENTIFIER { cbSize = Marshal.SizeOf<NOTIFYICONIDENTIFIER>(), hWnd = _hwnd, uID = MainId };
            if (Shell_NotifyIconGetRect(ref id, out var r) != 0) return null;
            return new PixelRect(r.Left, r.Top, Math.Max(1, r.Right - r.Left), Math.Max(1, r.Bottom - r.Top));
        }
    }

    // ------------------------------------------------------------------ notifications

    public void Show(string title, string body)
    {
        if (_disposed) return;
        var data = Data(MainId, NIF_INFO);
        data.szInfoTitle = Clip(title, 63);
        data.szInfo = Clip(string.IsNullOrEmpty(body) ? " " : body, 255);
        data.dwInfoFlags = NIIF_USER | NIIF_LARGE_ICON | NIIF_NOSOUND;
        data.hBalloonIcon = _balloonIcon;
        Shell_NotifyIcon(NIM_MODIFY, ref data);
    }

    // ------------------------------------------------------------------ messages

    IntPtr WindowProc(IntPtr hWnd, uint msg, IntPtr wParam, IntPtr lParam)
    {
        if (msg == _taskbarCreated && _taskbarCreated != 0)
        {
            _added = false;
            Add();
            return IntPtr.Zero;
        }
        if (msg == CallbackMessage)
        {
            var evt = (int)(lParam.ToInt64() & 0xFFFF);
            var iconId = (int)((lParam.ToInt64() >> 16) & 0xFFFF);
            var x = (short)(wParam.ToInt64() & 0xFFFF);
            var y = (short)((wParam.ToInt64() >> 16) & 0xFFFF);
            var point = new PixelPoint(x, y);
            if (iconId == StopId)
            {
                if (evt is NIN_SELECT or NIN_KEYSELECT or WM_CONTEXTMENU) StopClick?.Invoke();
                return IntPtr.Zero;
            }
            switch (evt)
            {
                case NIN_SELECT:
                case NIN_KEYSELECT:
                    if (DateTime.UtcNow < _suppressSelectUntil) break;
                    LeftClick?.Invoke(point);
                    break;
                case WM_LBUTTONDBLCLK:
                    // The second click's NIN_SELECT follows; don't let it reopen the popup.
                    _suppressSelectUntil = DateTime.UtcNow.AddMilliseconds(DoubleClickMilliseconds);
                    DoubleClick?.Invoke();
                    break;
                case WM_CONTEXTMENU:
                    RightClick?.Invoke(point);
                    break;
                case NIN_BALLOONUSERCLICK:
                    BalloonClick?.Invoke();
                    break;
            }
            return IntPtr.Zero;
        }
        return DefWindowProc(hWnd, msg, wParam, lParam);
    }

    NOTIFYICONDATA Data(int id, int flags) => new()
    {
        cbSize = Marshal.SizeOf<NOTIFYICONDATA>(),
        hWnd = _hwnd,
        uID = id,
        uFlags = flags,
        uCallbackMessage = CallbackMessage,
        szTip = "",
        szInfo = "",
        szInfoTitle = "",
    };

    static string Clip(string s, int max) => s.Length <= max ? s : s[..(max - 1)] + "…";

    public void Dispose()
    {
        if (_disposed) return;
        _disposed = true;
        var data = Data(MainId, 0);
        Shell_NotifyIcon(NIM_DELETE, ref data);
        if (_stopVisible) { var stop = Data(StopId, 0); Shell_NotifyIcon(NIM_DELETE, ref stop); }
        foreach (var icon in new[] { _icon, _stopIcon, _balloonIcon }) if (icon != IntPtr.Zero) DestroyIcon(icon);
        DestroyWindow(_hwnd);
    }

    // ------------------------------------------------------------------ interop

    const int NIM_ADD = 0, NIM_MODIFY = 1, NIM_DELETE = 2, NIM_SETVERSION = 4;
    const int NIF_MESSAGE = 0x1, NIF_ICON = 0x2, NIF_TIP = 0x4, NIF_INFO = 0x10, NIF_SHOWTIP = 0x80;
    const int NIIF_USER = 0x4, NIIF_NOSOUND = 0x10, NIIF_LARGE_ICON = 0x20;
    const int NOTIFYICON_VERSION_4 = 4;
    const int NIN_SELECT = 0x400, NIN_KEYSELECT = 0x401, NIN_BALLOONUSERCLICK = 0x405;
    const int WM_CONTEXTMENU = 0x7B, WM_LBUTTONDBLCLK = 0x203;
    const int SM_CXSMICON = 49;

    delegate IntPtr WndProc(IntPtr hWnd, uint msg, IntPtr wParam, IntPtr lParam);

    [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Unicode)]
    struct WNDCLASSEX
    {
        public uint cbSize; public uint style; public IntPtr lpfnWndProc; public int cbClsExtra; public int cbWndExtra;
        public IntPtr hInstance; public IntPtr hIcon; public IntPtr hCursor; public IntPtr hbrBackground;
        public string? lpszMenuName; public string lpszClassName; public IntPtr hIconSm;
    }

    [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Unicode)]
    struct NOTIFYICONDATA
    {
        public int cbSize; public IntPtr hWnd; public int uID; public int uFlags; public int uCallbackMessage; public IntPtr hIcon;
        [MarshalAs(UnmanagedType.ByValTStr, SizeConst = 128)] public string szTip;
        public int dwState; public int dwStateMask;
        [MarshalAs(UnmanagedType.ByValTStr, SizeConst = 256)] public string szInfo;
        public int uTimeoutOrVersion;
        [MarshalAs(UnmanagedType.ByValTStr, SizeConst = 64)] public string szInfoTitle;
        public int dwInfoFlags; public Guid guidItem; public IntPtr hBalloonIcon;
    }

    [StructLayout(LayoutKind.Sequential)]
    struct NOTIFYICONIDENTIFIER { public int cbSize; public IntPtr hWnd; public int uID; public Guid guidItem; }

    [StructLayout(LayoutKind.Sequential)]
    struct RECT { public int Left, Top, Right, Bottom; }

    [DllImport("user32.dll", CharSet = CharSet.Unicode, SetLastError = true)] static extern ushort RegisterClassEx(ref WNDCLASSEX wc);
    [DllImport("user32.dll", CharSet = CharSet.Unicode, SetLastError = true)]
    static extern IntPtr CreateWindowEx(int exStyle, string className, string windowName, int style, int x, int y, int w, int h,
        IntPtr parent, IntPtr menu, IntPtr instance, IntPtr param);
    [DllImport("user32.dll")] static extern IntPtr DefWindowProc(IntPtr hWnd, uint msg, IntPtr wParam, IntPtr lParam);
    [DllImport("user32.dll")] static extern bool DestroyWindow(IntPtr hWnd);
    [DllImport("user32.dll", CharSet = CharSet.Unicode)] static extern uint RegisterWindowMessage(string name);
    [DllImport("user32.dll")] static extern uint GetDoubleClickTime();
    [DllImport("user32.dll")] static extern int GetSystemMetricsForDpi(int index, uint dpi);
    [DllImport("user32.dll")] static extern uint GetDpiForSystem();
    [DllImport("user32.dll")] internal static extern bool DestroyIcon(IntPtr icon);
    [DllImport("kernel32.dll", CharSet = CharSet.Unicode)] static extern IntPtr GetModuleHandle(string? name);
    [DllImport("shell32.dll", CharSet = CharSet.Unicode)] static extern bool Shell_NotifyIcon(int message, ref NOTIFYICONDATA data);
    [DllImport("shell32.dll")] static extern int Shell_NotifyIconGetRect(ref NOTIFYICONIDENTIFIER id, out RECT rect);
}
