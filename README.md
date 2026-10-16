# Salat Time for Windows

The Windows version of Salat Time: the same prayer times from your MAWAQIT
mosque, the adhan on the speaker you choose, adhkar and the offline Qur'an.
It is written in C# with [Avalonia](https://avaloniaui.net).

This branch (`windows-app`) holds only the Windows app. The Mac app is on `main`,
and the two share no code. The few files taken from the Mac app (icon, adhkar
library, verified Qur'an assets and the UI translations) are copied into this
project; see [shared/README.md](shared/README.md).

Requires Windows 10 or 11, on x64 or ARM. Installing needs no administrator rights.

## What's in it

**Tray icon** (the Windows counterpart of the menu-bar item)
- The icon shows the minutes left during the last hour before a prayer. It turns red between the adhan and the iqama.
- Hovering shows the next prayer, its time, the countdown and the Hijri date.
- Click to open the prayer popup.
- **Double-click while the adhan plays** to stop it. A red stop icon also appears in the tray during the adhan.
- Right-click for the menu:
  - test or stop the adhan
  - an **adhan volume slider for the speaker the adhan plays on** (only that speaker's volume changes)
  - refresh, choose mosque, settings, the main window, favourites, quit
- Optional floating countdown pill, which can be dragged anywhere.

**Popup:** the same layout as the Mac popover.
- The mosque, the next-prayer countdown, and the five prayers with adhan, iqama and offset.
- A per-prayer toggle: off, notification only, or adhan.
- Jumu'ah, Shuruq, and the Hijri and Gregorian dates.
- Shortcuts to the app, the Qur'an, the adhkar and settings.

**Prayer Times**
- **Overview**: the living sky with the sun's path, the sun or the real moon phase, and stars.
  - Chips for the countdown, "leave by", the Hijri date, the moon and the Qibla.
  - The five prayers, the Sunnah of this moment, the Nawafil windows and the day's landmarks.
- **Timetable**: 7 days, a Hijri month or a Gregorian month.
- **Day path** and the **24-hour dial**.

**Adhkar:** the 14 Hisn al-Muslim collections, with:
- reading and focus views
- tap counters
- recitations (play one, or play all)
- automatic opening of the morning and evening adhkar

**Qur'an:** the unchanged King Fahd Complex corpora (Hafs and Warsh), checked against `shared/QuranAssets/source-manifest.json` before display.
- A real **Mushaf page** view: 15 lines, justified, with surah banners. Two pages side by side on wide windows.
- A verse view with the seven QuranEnc translations of meanings (Hafs).
- Search, or type `2:255` to jump.
- Bookmarks.
- Verse-by-verse recitation from EveryAyah.com, downloaded only when you press play.

**Settings**
- **General**: language (10, including Arabic and Urdu right-to-left), appearance, the six accent colours, 12/24-hour time, Arabic numerals, open at login.
- **Mosque**: search, paste a link, favourites.
- **Tray**: the tray options above.
- **Adhan**: per-prayer modes, the recording (with a separate Fajr recording if you want), output speaker, volume, the heads-up before each prayer, and travel time.
- **Adhkar**: when the morning and evening adhkar open.

**Notifications** use the tray icon, so they appear in the Windows notification centre and respect Do Not Disturb.

### Not ported yet
- Audio Studio (trimming the adhan)
- editing your own adhkar collections
- Qur'an word meanings and memorization tools
- the macOS widgets
- the "nearby mosques" list from your location (search by city works)

## Install

Run `SalatTime-<version>-setup-x64.exe`, or `-setup-arm64.exe` on an ARM PC. It installs to
`%LOCALAPPDATA%\Programs\Salat Time` and adds a Start menu entry. The builds are not
code-signed yet, so the first time Windows shows *"Windows protected your PC"*:
click **More info → Run anyway**.

The `.zip` builds are portable: unzip anywhere and run `SalatTime.exe`.

Settings, the cached schedule and downloaded recitations are kept in
`%APPDATA%\SalatTime`. Uninstalling keeps them.

Tip: drag the tray icon from the hidden icons (`^`) onto the taskbar so it stays visible.

## Build (from macOS or Linux)

```bash
# once: the .NET 10 SDK (no admin needed) and, for installers, NSIS
curl -sSL https://dot.net/v1/dotnet-install.sh | bash -s -- --channel 10.0
brew install makensis

./build.sh            # → dist/: x64 + arm64 zips and setup.exe
./build.sh --x64      # x64 only
```

`build.sh` follows the Mac build's rules:
- It fetches the 14 adhans and the adhkar recitations from the same sources, reusing a built Mac app in `../Salat Time Source` when there is one.
- It fetches the Cairo font.
- It refreshes `strings.json` from the Mac app when that checkout is present, and otherwise uses the committed copy.
- It **fails if any Qur'an file doesn't match its SHA-256** in the manifest.

The Mac checkout's location can be changed with `SALAT_MAC_SOURCE=/path ./build.sh`.

## Working on both apps

The Mac app and the Windows app are two branches of the same GitHub repository,
checked out side by side:

```
Salat Time/
  Salat Time Source/      Mac app      → branch main
  Salat Time Windows/     Windows app  → branch windows-app
```

Commit and push from each folder as usual; they never touch each other's files.
To set this up on another Mac:

```bash
git clone git@github.com:magicbox9/salat-time.git "Salat Time Source"
cd "Salat Time Source" && git worktree add "../Salat Time Windows" windows-app
```

## Development

```
build.sh                      package for Windows
installer/SalatTime.nsi       per-user installer (NSIS)
shared/                       files copied from the Mac app (never edit; see shared/README.md)
src/SalatTime/
  Core/        schedule, MAWAQIT reading, settings, scheduler, Hijri, Qur'an, adhkar
  Platform/    Windows only: tray icon (Shell_NotifyIcon), WASAPI audio, WebView2, Run key
  Views/       popup, tray menu, countdown pill, main window and its pages
  Controls/    living sky, day path, dial, Mushaf page
tools/
  sync_from_mac.sh            refresh shared/ and the strings from a Mac checkout
  extract_strings.py          builds Assets/strings.json from the Mac app's main.swift + build.sh
  windows_strings.json        text that exists only on Windows (all 10 languages)
  Snapshots/                  renders every screen to PNG, without a display
```

Screens can be checked on any OS without Windows:

```bash
cd tools/Snapshots
dotnet run -- /tmp/snaps "<a cached mosque.json>"      # optional third argument filters by name
```

The app reads the schedule the same way as the Mac app: the mosque's MAWAQIT page
embeds a `confData` object with the full year. If plain HTTP can't read a page,
an invisible WebView2 runs the Mac app's extraction script instead.
