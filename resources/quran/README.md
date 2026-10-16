# Qur'an assets — provenance

Copied **unchanged** from the Mac app (`mac_os/QuranAssets/`, branch `main`).
Every file still matches the SHA-256 recorded in `source-manifest.json`
(itself an unchanged copy); `tests/Feature/Content/QuranAssetsTest.php`
re-checks the hashes and fails if anything was edited.

| File | Source | SHA-256 |
|------|--------|---------|
| `Hafs/hafsData_v2-0.json` | KFGQPC Hafs Uthmanic Data v2.0 (update 13.0), King Fahd Glorious Qur'an Printing Complex — 6,236 ayat, 114 surahs | `d2960b32…c872ca` |
| `Hafs/read.me` | Publisher release notes for the data above | `d334f9ad…60cdb8` |
| `Translations/QuranEnc/english_rwwad_v1.0.19.sqlite` | QuranEnc.com — English Translation, Rowwad Translation Center, v1.0.19 | `77e2ede3…5fdee8` |
| `Translations/QuranEnc/french_rashid_v1.0.3.sqlite` | QuranEnc.com — French Translation, Rachid Maach, v1.0.3 | `1c8d1f66…ba87bf` |
| `Translations/QuranEnc/metadata-snapshot.json` | QuranEnc metadata and redistribution terms at retrieval | `8970f932…aaab49` |
| `../../public/fonts/quran/UthmanicHafs_V20.ttf` | KFGQPC HAFS Uthmanic Script font v2.0 (matches the data) | `27a0727e…d7be5a` |
| `../../public/fonts/quran/AmiriQuran.ttf` | Amiri Quran 1.003, Khaled Hosny / Alif Type, SIL OFL 1.1 (`AmiriQuran-OFL.txt`) — used for adhkar | `e2a47644…29455c` |

## Rules

- Never edit, regenerate or "fix" these files. `aya_text` is rendered exactly
  as published; its last glyph is the KFGQPC numbered ayah mark.
- The only derivative is the basmala heading: ayah 1:1 without its trailing
  no-break space and ayah mark (`QuranCorpus::basmala()`), the same allowance
  the Mac app makes. Copying an ayah also drops the mark, as the Mac app does.
- Translations are translations of the **meanings**, Hafs verse numbering only.
  QuranEnc's terms: no modification, name the publisher and QuranEnc.com, show
  the version. The reader shows title, version and a link to the source.
- Recitation audio (EveryAyah.com) is streamed by the browser only after the
  visitor presses play; the server never fetches it.
- Updating an asset means copying the new verified file from the Mac app,
  updating `source-manifest.json` and the hash pinned in
  `App\Services\Content\QuranCorpus` / `QuranTranslations` in the same commit.
