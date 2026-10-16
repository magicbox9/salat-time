# Third-party notices — Salat Time for Windows

| Component | Use | License / terms |
|---|---|---|
| [Avalonia](https://github.com/AvaloniaUI/Avalonia) 11.3 | UI framework | MIT |
| [SkiaSharp](https://github.com/mono/SkiaSharp), HarfBuzzSharp | rendering (via Avalonia) | MIT |
| [NAudio](https://github.com/naudio/NAudio) 2.4 | WASAPI playback, device volume | MIT |
| [Microsoft.Web.WebView2](https://www.nuget.org/packages/Microsoft.Web.WebView2) | fallback page reading | Microsoft WebView2 SDK license |
| [Microsoft.Data.Sqlite](https://github.com/dotnet/efcore), SQLitePCLRaw, SQLite | reading the QuranEnc translations | MIT / Apache-2.0 / public domain |
| [Fluent UI System Icons](https://github.com/microsoft/fluentui-system-icons) | icons (`Assets/Icons.axaml`) | MIT, © Microsoft |
| [Cairo](https://github.com/google/fonts/tree/main/ofl/cairo) | Arabic/Urdu interface font (downloaded at build) | SIL Open Font License 1.1 |
| KFGQPC Hafs and Warsh Uthmanic Script fonts and corpora | Qur'an text and faces (`shared/QuranAssets/`) | King Fahd Glorious Qur'an Printing Complex terms; unchanged, hash-pinned |
| Amiri Quran, Harmattan | bundled Qur'an faces | SIL Open Font License 1.1 |
| [QuranEnc.com](https://quranenc.com) translations | translations of meanings (Hafs) | QuranEnc redistribution terms |
| Adhan recordings | 14 recordings from [assabile.com](https://www.assabile.com) (downloaded at build) | per source |
| Adhkar recitations | [hisnmuslim.com](https://www.hisnmuslim.com), [mp3quran.net](https://mp3quran.net) (downloaded at build) | per source |
| Verse recitations | [EveryAyah.com](https://everyayah.com), fetched when the user presses play | per source |
| Prayer times | [mawaqit.net](https://mawaqit.net), the user's chosen mosque | MAWAQIT terms |

Provenance and checksums for every Qur'an asset are recorded in `shared/QuranAssets/source-manifest.json`.
