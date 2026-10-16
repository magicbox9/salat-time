# shared/

Read-only copies of files that come from the Mac app (the repository's `main`
branch). The Windows project keeps its own copies so the two apps share no code:
a change on one branch can never break the other.

| File | From the Mac app | Notes |
|---|---|---|
| `icon.png` | `icon.png` | App icon source |
| `adhkar.json` | `adhkar.json` | Hisn al-Muslim library |
| `QuranAssets/` | `QuranAssets/` | Unchanged and hash-pinned (see `source-manifest.json`). The two audit PDFs are left out because the Windows reader doesn't display them. |

Never edit these files by hand. To pick up a newer version from the Mac app, run:

```bash
tools/sync_from_mac.sh ../mac_os
```

It copies these files and refreshes `src/SalatTime/Assets/strings.json`. `build.sh`
then re-checks every Qur'an file against its SHA-256.
