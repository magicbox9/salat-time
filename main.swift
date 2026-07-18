import Cocoa
import CoreText
import WebKit
import PDFKit
import AVFoundation
import CoreAudio
import CoreLocation
import UserNotifications
import ServiceManagement
import UniformTypeIdentifiers
import SQLite3

// ============================================================================
// MARK: Constants
// ============================================================================
let kDefaultMosqueURL    = "https://mawaqit.net/fr/m/mosquee-el-houda-villefranche-sur-saone"
let prayerLabels         = ["Fajr", "Dhuhr", "Asr", "Maghrib", "Isha"]
let kInfoKey             = "mosqueInfoJSON_v2"
let kLastAdhanKey        = "lastAdhanPrayed"
let kAdhanEnabled        = "adhanEnabled"
let kAppearanceKey       = "appearancePref"
let kCurrentMosqueKey    = "currentMosqueURL"
let kFavoritesKey        = "favoriteMosquesJSON"
let kAdhanSoundKey       = "adhanSoundID"
let kNotificationsKey    = "notificationsEnabled"
let kLanguageKey         = "appLanguage"
let kPerPrayerAdhanMode  = "perPrayerAdhanMode"   // [String: Int] keyed "0".."4"
let kTimeFormat          = "timeFormat"           // "12h" or "24h"
/// Numerals used while the Arabic interface is active. Western/Latin digits
/// are the default, matching the rest of the app; users can opt into the
/// Arabic-Indic forms traditionally called "Indian numerals" in Arabic UI.
let kArabicDigitStyle    = "arabicDigitStyle"     // "western" | "arabicIndic"
let kBarShowIcon         = "barShowIcon"          // Bool
let kBarShowTime         = "barShowTime"          // Bool — show scheduled "Dhuhr 13:45"
let kBarShowCountdown    = "barShowCountdown"     // Bool — show live countdown "00:42:15"
let kBarShowHijri        = "barShowHijri"         // Bool (hijri date) — legacy, kept for migration
let kBarHijriFormat      = "barHijriFormat"       // "off"|"full"|"daymonth"|"month"|"day"
let kOpenAtLogin         = "openAtLogin"          // Bool — launch at macOS login
let kAccentPref          = "accentPref"           // "green"|"blue"|"purple"|"orange"|"red"|"teal"
let kMaterialPref        = "materialPref"         // "opaque" | "glass"
let kAdhanAudioDevice    = "adhanAudioDeviceUID"  // CoreAudio device UID, "" = system default
let kUserCity            = "userCity"             // Manual city override for the Nearby tab
/// Minutes before each prayer that a heads-up notification should fire.
/// 0 = feature off. Valid values: {0, 5, 10, 15, 20, 30, 45, 60}.
let kPreAdhanLeadMinutes = "preAdhanLeadMinutes"
/// Last processed pre-adhan marker ("YYYY-MM-DD#i:pre") — same idempotency
/// scheme as kLastAdhanKey so we don't double-fire.
let kLastPreAdhanKey     = "lastPreAdhanPrepped"
/// Options surfaced in the Settings dropdown for the pre-adhan heads-up.
let kPreAdhanOptions: [Int] = [0, 5, 10, 15, 20, 30, 45, 60]

// --- Adhkar (morning/evening remembrances) ---
/// Master on/off for adhkar auto-recitation.
let kAdhkarEnabled       = "adhkarEnabled"          // Bool (default true)
/// Which prayer the morning adhkar should follow. "shuruq" (default) or "fajr".
let kAdhkarMorningAnchor = "adhkarMorningAnchor"    // "shuruq" | "fajr"
/// Which prayer the evening adhkar should follow. "asr" (default) or "maghrib".
let kAdhkarEveningAnchor = "adhkarEveningAnchor"    // "asr" | "maghrib"
/// Idempotency markers so each set fires once per day. Format "YYYY-MM-DD".
let kLastAdhkarMorning   = "lastAdhkarMorning"
let kLastAdhkarEvening   = "lastAdhkarEvening"
/// Persisted user adhkar library (array of AdhkarCollection) as JSON Data.
let kAdhkarLibraryKey    = "adhkarLibraryJSON_v1"
/// One-time v2→v3 migration marker so we seed default collections only once.
let kAdhkarMigrated      = "adhkarLibraryMigrated"
/// One-time v3.7 migration that gives bundled collections a stable category
/// identity. Display names can then follow the app language without relying
/// on the mutable, previously Arabic-only `name` field.
let kAdhkarIdentityMigrated = "adhkarCollectionIdentity_v37"
/// Adhkar playback volume (0.0–1.0). Default 1.0.
let kAdhkarVolume        = "adhkarVolume"
/// CoreAudio device UID for adhkar audio output ("" = system default).
/// Mirrors kAdhanAudioDevice so adhkar can be routed to a different speaker.
let kAdhkarAudioDevice   = "adhkarAudioDeviceUID"
/// Extra wait after an Adhan finishes before a queued Adhkar collection
/// begins. This is applied only when both were scheduled for the same time.
let kAdhkarAfterAdhanDelay = "adhkarAfterAdhanDelayMinutes"
let kAdhkarAfterAdhanOptions = [0, 2, 5, 10, 15]

/// Full prayer dashboard presentation preferences. Keeping these independent
/// from language makes switching Arabic/LTR locales preserve the user's view.
let kPrayerDashboardMode   = "prayerDashboardMode"      // 0...3
let kPrayerNawafilMode     = "prayerNawafilMode"        // 0 hide, 1 integrated, 2 separate
let kPrayerShowCountdown   = "prayerShowCountdown"      // Bool — full dashboard, default true

/// Stable Settings destinations. Using a type instead of integer literals
/// keeps popup and dashboard shortcuts correct as new sections are added.
enum SettingsSection: Int, CaseIterable {
    case general = 0
    case mosque
    case menuBar
    case adhan
    case adhkar
}

// --- Offline Qur'an reader -------------------------------------------------
// Canonical KFGQPC corpora and audit pages are immutable bundled resources.
// UserDefaults stores only edition/verse locators and never Qur'an content.
let kQuranEditionKey             = "quranEdition" // "hafs" | "warsh"
let kQuranBookmarksKey           = "quranBookmarksJSON_v2"
let kQuranLegacyBookmarksKey     = "quranBookmarksJSON_v1"
let kQuranLegacyBookmarksBackup  = "quranBookmarksJSON_v1_backup"
let kQuranUnsupportedBookmarks   = "quranBookmarksJSON_v1_unsupported"
let kQuranBookmarkMigrationDone  = "quranBookmarksMigration_v2"
let kQuranLastHafsPage           = "quranLastHafsPage"
let kQuranLastWarshPage          = "quranLastWarshPage"
let kQuranViewMode               = "quranOfflineViewMode"
let kQuranSidebarVisible         = "quranOfflineSidebarVisible"
let kQuranReaderSurah            = "quranReaderSurah"
let kQuranReaderAyah             = "quranReaderAyah"
let kQuranReaderPalette          = "quranReaderPalette"
let kQuranReaderLayout           = "quranReaderLayout"
let kQuranReaderTextScale        = "quranReaderTextScale"
let kQuranTranslationVisible     = "quranTranslationVisible"
let kQuranTranslationKey         = "quranTranslationKey"

let kAppVersion          = "3.19.0"

// ============================================================================
// MARK: Theme palette
// ============================================================================
/// Accent-color palette — one (light-mode, dark-mode) pair per theme. Each
/// shade was tuned so the appearance-adaptive `NSColor.appAccent` maintains
/// ~4.5:1 contrast against the rows' background in both modes.
let kAccentPalette: [String: (light: NSColor, dark: NSColor)] = [
    "green":  (NSColor(red: 0.086, green: 0.396, blue: 0.204, alpha: 1.0),
               NSColor(red: 0.40,  green: 0.86,  blue: 0.55,  alpha: 1.0)),
    "blue":   (NSColor(red: 0.08,  green: 0.35,  blue: 0.72,  alpha: 1.0),
               NSColor(red: 0.40,  green: 0.68,  blue: 1.0,   alpha: 1.0)),
    "purple": (NSColor(red: 0.40,  green: 0.13,  blue: 0.55,  alpha: 1.0),
               NSColor(red: 0.73,  green: 0.54,  blue: 1.0,   alpha: 1.0)),
    "orange": (NSColor(red: 0.82,  green: 0.42,  blue: 0.09,  alpha: 1.0),
               NSColor(red: 1.0,   green: 0.71,  blue: 0.35,  alpha: 1.0)),
    "red":    (NSColor(red: 0.72,  green: 0.17,  blue: 0.17,  alpha: 1.0),
               NSColor(red: 1.0,   green: 0.45,  blue: 0.45,  alpha: 1.0)),
    "teal":   (NSColor(red: 0.07,  green: 0.52,  blue: 0.52,  alpha: 1.0),
               NSColor(red: 0.30,  green: 0.85,  blue: 0.85,  alpha: 1.0)),
]
/// Stable ordering for the theme menu.
let kAccentOrder = ["green","blue","purple","orange","red","teal"]

/// Read the current accent preference, falling back to green.
func currentAccentKey() -> String {
    let k = UserDefaults.standard.string(forKey: kAccentPref) ?? "green"
    return kAccentPalette[k] != nil ? k : "green"
}

/// Return the (light, dark) pair for the currently-selected accent.
func currentAccentPair() -> (light: NSColor, dark: NSColor) {
    return kAccentPalette[currentAccentKey()] ?? kAccentPalette["green"]!
}

/// Return true when the user asked for the translucent "Liquid Glass"
/// material. Defaults to opaque so existing installs keep their look.
func isGlassMaterial() -> Bool {
    return (UserDefaults.standard.string(forKey: kMaterialPref) ?? "opaque") == "glass"
}

/// Human-readable label for each accent key (localised via translation
/// keys `menu.theme.accent.<key>`). Exposed globally so both AppDelegate's
/// quick menu and SettingsView's Appearance tab can share the same strings.
func accentLocalizedName(_ key: String) -> String {
    return t("menu.theme.accent.\(key)")
}

/// Build a small filled circle NSImage in the accent's light-mode shade —
/// used as both the NSMenuItem swatch in the quick theme menu and as a
/// fallback rendering in SettingsView.
func accentSwatchImage(_ key: String, size sz: CGFloat = 14) -> NSImage? {
    guard let pair = kAccentPalette[key] else { return nil }
    let size = NSSize(width: sz, height: sz)
    let img = NSImage(size: size, flipped: false) { _ in
        pair.light.setFill()
        let pad: CGFloat = 1
        let rect = NSRect(x: pad, y: pad, width: sz - pad*2, height: sz - pad*2)
        NSBezierPath(ovalIn: rect).fill()
        NSColor.black.withAlphaComponent(0.15).setStroke()
        let path = NSBezierPath(ovalIn: rect)
        path.lineWidth = 0.5
        path.stroke()
        return true
    }
    img.isTemplate = false
    return img
}

// ============================================================================
// MARK: Per-prayer adhan mode
// ============================================================================
/// What should happen when this prayer's adhan time arrives.
enum AdhanMode: Int, CaseIterable {
    case off    = 0   // silent — no sound, no notification
    case notify = 1   // banner/notification only (no audio)
    case adhan  = 2   // play the chosen adhan audio + banner

    /// Cycle to the next mode (off → notify → adhan → off …).
    var next: AdhanMode {
        switch self {
        case .off:    return .notify
        case .notify: return .adhan
        case .adhan:  return .off
        }
    }

    /// SF Symbol representing this mode in the row button.
    var symbolName: String {
        switch self {
        case .off:    return "bell.slash.fill"
        case .notify: return "bell.fill"
        case .adhan:  return "speaker.wave.2.fill"
        }
    }
}

/// Read the saved mode for prayer index 0..4 (fajr..isha). Defaults to `.adhan`
/// so existing users keep hearing every adhan until they opt out.
func adhanModeForPrayer(_ idx: Int) -> AdhanMode {
    let dict = UserDefaults.standard.dictionary(forKey: kPerPrayerAdhanMode) as? [String: Int] ?? [:]
    if let v = dict[String(idx)], let m = AdhanMode(rawValue: v) { return m }
    return .adhan
}

/// Persist the mode for prayer index 0..4.
func setAdhanMode(_ mode: AdhanMode, forPrayer idx: Int) {
    var dict = UserDefaults.standard.dictionary(forKey: kPerPrayerAdhanMode) as? [String: Int] ?? [:]
    dict[String(idx)] = mode.rawValue
    UserDefaults.standard.set(dict, forKey: kPerPrayerAdhanMode)
}

// ============================================================================
// MARK: Time-format + Hijri helpers
// ============================================================================
/// Whether the UI should display times in 12-hour (AM/PM) format.
/// Defaults to false (24h) so existing users see no change.
func is12HourFormat() -> Bool {
    (UserDefaults.standard.string(forKey: kTimeFormat) ?? "24h") == "12h"
}

enum ArabicDigitStyle: String {
    case western
    case arabicIndic
}

func currentArabicDigitStyle() -> ArabicDigitStyle {
    ArabicDigitStyle(rawValue: UserDefaults.standard.string(forKey: kArabicDigitStyle)
                     ?? ArabicDigitStyle.western.rawValue) ?? .western
}

/// Apply the Arabic-interface numeral preference to both generated numbers
/// and translated copy. Existing Arabic translations contain a mixture of
/// 0-9 and ٠-٩, so normalizing in both directions is intentional.
func applyingArabicDigitPreference(_ text: String, languageCode: String) -> String {
    guard languageCode == "ar" else { return text }
    let western = Array("0123456789")
    let indic = Array("٠١٢٣٤٥٦٧٨٩")
    let source = currentArabicDigitStyle() == .arabicIndic ? western : indic
    let target = currentArabicDigitStyle() == .arabicIndic ? indic : western
    let mapping = Dictionary(uniqueKeysWithValues: zip(source, target))
    return String(text.map { mapping[$0] ?? $0 })
}

func localizedInterfaceDigits(_ text: String) -> String {
    let code = UserDefaults.standard.string(forKey: kLanguageKey) ?? "en"
    return applyingArabicDigitPreference(text, languageCode: code)
}

/// DateFormatter needs an explicit ICU numbering-system override; plain
/// Arabic locales may inherit a different digit style from macOS Region.
func preferredInterfaceLocale() -> Locale {
    let code = UserDefaults.standard.string(forKey: kLanguageKey) ?? "en"
    guard code == "ar" else { return Locale(identifier: code) }
    let system = currentArabicDigitStyle() == .arabicIndic ? "arab" : "latn"
    return Locale(identifier: "ar@numbers=\(system)")
}

/// Convert a raw "HH:MM" string (always 24h from mawaqit) into the display
/// format the user chose in Settings. Returns the input unchanged when the
/// string doesn't parse — no silent loss of data for edge cases like "—".
func displayTime(_ hhmm: String) -> String {
    guard !hhmm.isEmpty else { return hhmm }
    let parts = hhmm.split(separator: ":")
    guard parts.count == 2, let h = Int(parts[0]), let m = Int(parts[1]) else {
        return hhmm
    }
    if !is12HourFormat() {
        return localizedInterfaceDigits(String(format: "%02d:%02d", h, m))
    }
    let period = h >= 12 ? "PM" : "AM"
    var h12 = h % 12
    if h12 == 0 { h12 = 12 }
    return localizedInterfaceDigits(String(format: "%d:%02d %@", h12, m, period))
}

/// Hijri format keys recognised in the menu-bar settings. "off" suppresses
/// the Hijri strip entirely; the other four pick which chunks of the date
/// are rendered.
enum HijriFormat: String {
    case off       = "off"
    case full      = "full"       // "15 Shawwāl 1447"
    case dayMonth  = "daymonth"   // "15 Shawwāl"
    case month     = "month"      // "Shawwāl"
    case day       = "day"        // "15"
}

/// Stable order used by the menu-bar Hijri-format popup.
let kHijriFormatOrder: [HijriFormat] = [.off, .full, .dayMonth, .month, .day]

/// Resolve the user's Hijri-format preference. Migrates from the legacy
/// `kBarShowHijri` bool: if the new key isn't set, an existing `true`
/// becomes `.full`, an existing `false` becomes `.off`.
func currentHijriFormat() -> HijriFormat {
    if let raw = UserDefaults.standard.string(forKey: kBarHijriFormat),
       let f = HijriFormat(rawValue: raw) {
        return f
    }
    // Back-compat path.
    if UserDefaults.standard.object(forKey: kBarShowHijri) != nil {
        return UserDefaults.standard.bool(forKey: kBarShowHijri) ? .full : .off
    }
    return .off
}

/// Returns a Hijri-calendar date string for today, formatted per
/// `HijriFormat`. Uses the Umm al-Qurā variant which is the default on
/// most Muslim-majority systems; switch to `.islamicCivil` if you prefer
/// the tabular calendar.
///
/// Examples in English:
///   • .full      → "15 Shawwāl 1447"
///   • .dayMonth  → "15 Shawwāl"
///   • .month     → "Shawwāl"
///   • .day       → "15"
///   • .off       → ""   (caller should usually skip the call when off)
func hijriString(for date: Date = Date(),
                 format: HijriFormat = .full) -> String {
    if format == .off { return "" }
    var cal = Calendar(identifier: .islamicUmmAlQura)
    cal.locale = preferredInterfaceLocale()
    let fmt = DateFormatter()
    fmt.calendar = cal
    fmt.locale = preferredInterfaceLocale()
    switch format {
    case .full:     fmt.dateFormat = "d MMMM yyyy"
    case .dayMonth: fmt.dateFormat = "d MMMM"
    case .month:    fmt.dateFormat = "MMMM"
    case .day:      fmt.dateFormat = "d"
    case .off:      return ""
    }
    return fmt.string(from: date)
}

// ============================================================================
// MARK: Login-item helpers (Open at login)
// ============================================================================
/// Whether the app is currently registered to launch at macOS login.
/// On macOS 13+ we use `SMAppService.mainApp` (modern, sandbox-friendly).
/// On older systems we fall back to the deprecated `SMLoginItemSetEnabled`.
func isOpenAtLoginEnabled() -> Bool {
    if #available(macOS 13.0, *) {
        return SMAppService.mainApp.status == .enabled
    }
    // Pre-13 fallback: trust whatever the user saved.
    return UserDefaults.standard.bool(forKey: kOpenAtLogin)
}

/// Register or unregister the app as a login item.
/// Returns `true` on success, `false` if the system refused (e.g. Gatekeeper
/// flagged the build or the user denied the request). Always updates the
/// persisted `kOpenAtLogin` preference so the UI reflects reality.
@discardableResult
func setOpenAtLogin(_ enabled: Bool) -> Bool {
    if #available(macOS 13.0, *) {
        do {
            if enabled {
                if SMAppService.mainApp.status != .enabled {
                    try SMAppService.mainApp.register()
                }
            } else {
                if SMAppService.mainApp.status == .enabled {
                    try SMAppService.mainApp.unregister()
                }
            }
            UserDefaults.standard.set(enabled, forKey: kOpenAtLogin)
            return true
        } catch {
            NSLog("setOpenAtLogin error: \(error.localizedDescription)")
            // Keep UserDefaults in sync with reality.
            UserDefaults.standard.set(SMAppService.mainApp.status == .enabled,
                                      forKey: kOpenAtLogin)
            return false
        }
    } else {
        // macOS 11–12 fallback. Users on modern macOS are the 99% path.
        UserDefaults.standard.set(enabled, forKey: kOpenAtLogin)
        return true
    }
}

// ============================================================================
// MARK: Adhan catalog
// ============================================================================
struct AdhanOption {
    let id: String
    let name: String
    let fileName: String   // empty => use system Glass sound
}

// Curated selection of 14 adhan recordings sourced from Assabile — each option
// is labeled either by the mosque or by the muezzin ("moadin") whose voice is
// on the recording. Ordered with the two Haramain recordings (Makkah, Madinah)
// and Al-Aqsa at the top, followed by the other reciters.
let adhanCatalog: [AdhanOption] = [
    AdhanOption(id: "makkah_mulla",
                name: "Makkah — Sheikh Ali Ibn Ahmed Mala",
                fileName: "adhan_makkah_mulla.mp3"),
    AdhanOption(id: "madinah",
                name: "Madinah — Masjid an-Nabawi",
                fileName: "adhan_madinah.mp3"),
    AdhanOption(id: "aqsa",
                name: "Al-Aqsa — Naji Qazzaz",
                fileName: "adhan_aqsa.mp3"),
    AdhanOption(id: "dossari",
                name: "Yasser Al-Dossari",
                fileName: "adhan_dossari.mp3"),
    AdhanOption(id: "zahrani",
                name: "Mansour Al-Zahrani",
                fileName: "adhan_zahrani.mp3"),
    AdhanOption(id: "obaid",
                name: "Nasser Al-Obaid",
                fileName: "adhan_obaid.mp3"),
    AdhanOption(id: "majali",
                name: "Hamza Al-Majali",
                fileName: "adhan_majali.mp3"),
    AdhanOption(id: "yamani",
                name: "Wadi' Hammadi Al-Yamani",
                fileName: "adhan_yamani.mp3"),
    AdhanOption(id: "kabbara",
                name: "Mohammed Salahuddin Kabbara",
                fileName: "adhan_kabbara.mp3"),
    AdhanOption(id: "kourdi",
                name: "Ahmed Al-Kourdi",
                fileName: "adhan_kourdi.mp3"),
    AdhanOption(id: "feqy",
                name: "Mohamed Abdel-Basset Al-Feqy",
                fileName: "adhan_feqy.mp3"),
    AdhanOption(id: "damradach",
                name: "Mohammed Al-Damradach",
                fileName: "adhan_damradach.mp3"),
    AdhanOption(id: "kreiny",
                name: "Mohammed Al-Kreiny Al-Malouki",
                fileName: "adhan_kreiny.mp3"),
    AdhanOption(id: "jazairi",
                name: "Rabih Ibn Darah Al-Jazairi",
                fileName: "adhan_jazairi.mp3"),
    AdhanOption(id: "glass",
                name: "System sound (Glass)",
                fileName: ""),
]

func currentAdhanOption() -> AdhanOption {
    // Migrate legacy ids that no longer exist in the catalog to a sensible
    // replacement in the new Assabile-based catalog so existing users don't
    // end up with an empty Settings popup after upgrading.
    let legacyAliases: [String: String] = [
        "makkah":   "makkah_mulla",  // old Makkah recording → new Makkah (Sheikh Ali Mulla)
        "madina":   "madinah",       // old alias for Madinah
        "alafasy":  "makkah_mulla",  // Mishary Alafasy not in new set → fall back to Makkah
        "qatami":   "makkah_mulla",  // Nasser Al-Qatami not in new set → Makkah
        "basit":    "makkah_mulla",  // Abdul Basit not in new set → Makkah
        "refaat":   "feqy",          // Mohamed Refaat (Egypt) → Al-Feqy (closest Egyptian reciter)
        "minshawi": "makkah_mulla",  // Al-Minshawi not in new set → Makkah
        "short":    "aqsa",          // old "Short adhan" → Al-Aqsa (similar feel)
        "classic":  "makkah_mulla",  // generic "Classic" → Makkah
    ]
    let raw = UserDefaults.standard.string(forKey: kAdhanSoundKey) ?? "makkah_mulla"
    let id = legacyAliases[raw] ?? raw
    return adhanCatalog.first(where: { $0.id == id }) ?? adhanCatalog[0]
}
func setCurrentAdhan(_ id: String) {
    UserDefaults.standard.set(id, forKey: kAdhanSoundKey)
}

// ============================================================================
// MARK: Models & URL helpers
// ============================================================================
struct MosqueInfo: Codable {
    var name: String = "Mosque"
    var localisation: String = ""
    var phone: String = ""
    var site: String = ""
    var times: [String] = []
    var shuruq: String = ""
    var iqama: [String] = []
    var jumua: String = ""
    /// All Friday services when the source publishes more than one. The
    /// legacy single value stays for backwards-compatible cached JSON.
    var jumuaTimes: [String]? = nil
    /// Explicit sunset from the mosque source when available. Maghrib is
    /// shown as a clearly identified fallback when this value is absent.
    var sunset: String? = nil
    var date: String = ""
    var sourceURL: String = ""
}

struct MosqueRef: Codable, Equatable {
    var name: String
    var city: String
    var url: String
    // Optional street address (kept separate from `city` so the UI can show
    // "name → city → address" on three lines in a card layout). Optional so
    // previously-saved favourites (which had no `address`) still decode.
    var address: String? = nil
    // Coordinates from the Mawaqit API — used to sort the Nearby list by
    // actual distance from the user. Optional because not every search
    // result includes them.
    var lat: Double? = nil
    var lon: Double? = nil
    static func == (a: MosqueRef, b: MosqueRef) -> Bool {
        return normalizeMosqueURL(a.url) == normalizeMosqueURL(b.url)
    }
}

struct QuranBookmark: Codable {
    var id: UUID = UUID()
    var title: String
    var url: String
    var edition: String
    var createdAt: Date = Date()
}

func normalizeMosqueURL(_ raw: String) -> String {
    let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
    guard let comps = URLComponents(string: trimmed),
          let host  = comps.host,
          host.contains("mawaqit.net") else { return trimmed }
    var c = URLComponents()
    c.scheme = "https"
    c.host   = "mawaqit.net"
    c.path   = comps.path
    return c.url?.absoluteString ?? trimmed
}
func isValidMawaqitURL(_ s: String) -> Bool {
    let t = s.trimmingCharacters(in: .whitespacesAndNewlines)
    guard let comps = URLComponents(string: t), let host = comps.host else { return false }
    return host.contains("mawaqit.net") && comps.path.contains("/m/")
}

/// Convert a Mawaqit mosque URL to its **desktop** form (the one served when
/// you open the page in a regular browser).
///
/// Mawaqit serves two variants of every mosque page:
///   • Mobile / embed: `https://mawaqit.net/fr/m/<slug>` (what the API
///     returns — strips the site chrome, used inside WebViews)
///   • Desktop:        `https://mawaqit.net/fr/<slug>` (full site with
///     navigation, mosque info, donations, etc.)
///
/// We strip the `/m/` segment from the path so clicking the "open" button
/// from within the app lands the user on the proper desktop page. Non-
/// Mawaqit URLs are returned unchanged.
func desktopMawaqitURL(_ raw: String) -> String {
    let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
    guard var comps = URLComponents(string: trimmed),
          let host  = comps.host,
          host.contains("mawaqit.net") else { return trimmed }
    // Replace "/m/" with "/" the first time it appears in the path. Works
    // for "/fr/m/slug" → "/fr/slug" and also locale-less "/m/slug" → "/slug".
    var p = comps.path
    if let range = p.range(of: "/m/") {
        p.replaceSubrange(range, with: "/")
        comps.path = p
    }
    return comps.url?.absoluteString ?? trimmed
}

func loadFavorites() -> [MosqueRef] {
    guard let data = UserDefaults.standard.data(forKey: kFavoritesKey),
          let arr  = try? JSONDecoder().decode([MosqueRef].self, from: data) else { return [] }
    return arr
}
func saveFavorites(_ favs: [MosqueRef]) {
    if let data = try? JSONEncoder().encode(favs) {
        UserDefaults.standard.set(data, forKey: kFavoritesKey)
    }
}
@discardableResult
func addFavorite(_ m: MosqueRef) -> Bool {
    var favs = loadFavorites()
    if favs.contains(m) { return false }
    favs.append(m)
    saveFavorites(favs)
    return true
}
func removeFavorite(url: String) {
    var favs = loadFavorites()
    let norm = normalizeMosqueURL(url)
    favs.removeAll { normalizeMosqueURL($0.url) == norm }
    saveFavorites(favs)
}

func currentMosqueURL() -> String {
    let v = UserDefaults.standard.string(forKey: kCurrentMosqueKey) ?? ""
    return v.isEmpty ? kDefaultMosqueURL : v
}
func setCurrentMosque(_ url: String) {
    UserDefaults.standard.set(normalizeMosqueURL(url), forKey: kCurrentMosqueKey)
}

/// User's home city for the Nearby tab — either typed in manually or seeded
/// via reverse-geocoding their current location. Stored in UserDefaults so
/// it survives relaunches and the mosque-picker can pre-fill the field.
func userCity() -> String {
    (UserDefaults.standard.string(forKey: kUserCity) ?? "")
        .trimmingCharacters(in: .whitespacesAndNewlines)
}
func setUserCity(_ city: String) {
    let clean = city.trimmingCharacters(in: .whitespacesAndNewlines)
    UserDefaults.standard.set(clean, forKey: kUserCity)
}

func loadAppIcon() -> NSImage? {
    if let url = Bundle.main.url(forResource: "icon", withExtension: "png"),
       let img = NSImage(contentsOf: url) { return img }
    if let url = Bundle.main.url(forResource: "AppIcon", withExtension: "icns"),
       let img = NSImage(contentsOf: url) { return img }
    return NSApp.applicationIconImage
}

// ============================================================================
// MARK: Audio output devices
// ============================================================================
/// A selectable audio output device — UID is the stable CoreAudio identifier
/// persisted in UserDefaults; name is what the user sees in the popup.
struct AudioOutputDevice {
    let uid: String
    let name: String
}

/// Enumerate system audio output devices (built-in, USB, AirPods, HDMI, etc.)
/// via CoreAudio. Used by the Settings "Sound output" popup so the user can
/// route the adhan to a specific speaker regardless of the system-default
/// output (e.g. keep playing the adhan on the built-in speakers even when
/// headphones are connected and selected as the default).
func listAudioOutputDevices() -> [AudioOutputDevice] {
    var result: [AudioOutputDevice] = []

    var addr = AudioObjectPropertyAddress(
        mSelector: kAudioHardwarePropertyDevices,
        mScope:    kAudioObjectPropertyScopeGlobal,
        mElement:  kAudioObjectPropertyElementMain)

    var dataSize: UInt32 = 0
    guard AudioObjectGetPropertyDataSize(
            UInt32(kAudioObjectSystemObject), &addr, 0, nil, &dataSize) == noErr,
          dataSize > 0 else { return result }

    let count = Int(dataSize) / MemoryLayout<AudioDeviceID>.size
    var devices = [AudioDeviceID](repeating: 0, count: count)

    guard AudioObjectGetPropertyData(
            UInt32(kAudioObjectSystemObject), &addr, 0, nil, &dataSize, &devices) == noErr
    else { return result }

    for dev in devices {
        // Skip devices that have no output streams — those are input-only.
        var outAddr = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyStreamConfiguration,
            mScope:    kAudioDevicePropertyScopeOutput,
            mElement:  kAudioObjectPropertyElementMain)
        var bufSize: UInt32 = 0
        guard AudioObjectGetPropertyDataSize(dev, &outAddr, 0, nil, &bufSize) == noErr,
              bufSize > 0 else { continue }
        let bufList = UnsafeMutablePointer<AudioBufferList>.allocate(capacity: Int(bufSize))
        defer { bufList.deallocate() }
        guard AudioObjectGetPropertyData(dev, &outAddr, 0, nil, &bufSize, bufList) == noErr
        else { continue }
        let abl = UnsafeMutableAudioBufferListPointer(bufList)
        let outChannels = abl.reduce(0) { $0 + Int($1.mNumberChannels) }
        if outChannels == 0 { continue }

        // Fetch the UID (stable across reboots) and the human-readable name.
        func fetchString(selector: AudioObjectPropertySelector) -> String? {
            var a = AudioObjectPropertyAddress(
                mSelector: selector,
                mScope:    kAudioObjectPropertyScopeGlobal,
                mElement:  kAudioObjectPropertyElementMain)
            var sz = UInt32(MemoryLayout<CFString>.size)
            var cf: Unmanaged<CFString>?
            guard AudioObjectGetPropertyData(dev, &a, 0, nil, &sz, &cf) == noErr,
                  let s = cf?.takeRetainedValue() else { return nil }
            return s as String
        }

        guard let uid = fetchString(selector: kAudioDevicePropertyDeviceUID) else { continue }
        let name = fetchString(selector: kAudioObjectPropertyName) ?? uid
        result.append(AudioOutputDevice(uid: uid, name: name))
    }

    // Stable, case-insensitive sort so the popup order doesn't shuffle per
    // call (CoreAudio does not guarantee insertion order).
    result.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    return result
}

// ============================================================================
// MARK: Adhkar (morning / evening) — model + playback session
// ============================================================================
// Adhkar are the daily remembrances from Hisn al-Muslim. We bundle 25 morning
// and 23 evening items, each with its own recitation MP3. The session plays
// them in order; when each item's audio finishes, the panel advances to the
// next item and shows its Arabic text — so the text on screen always matches
// the audio being recited (per-dhikr sync, the authentic model).
//
// Audio is stored under Resources/adhkar_audio/<id>.mp3; metadata in adhkar.json.

/// One dhikr entry as loaded from `adhkar.json`.
struct AdhkarItem: Codable {
    /// Optional because the expanded v3.1 categories (from the full Hisn
    /// al-Muslim) don't carry an id. Morning/evening (curated) do.
    let id:          Int?
    /// 0 = both morning & evening, 1 = morning only, 2 = evening only.
    /// Optional for the same reason as `id`.
    let type:        Int?
    let arabic:      String
    /// Recommended repetitions (1, 3, 7, 10, 33, 100…). The audio is a single
    /// recitation; for `count ≤ 3` we loop the audio that many times (matches
    /// the authentic practice for the three Quls). For higher counts the audio
    /// plays once and the recommended count is shown for the user to complete.
    let count:       Int
    let count_desc:  String
    let virtue:      String
    let source:      String
    let audio_file:  String
}

/// Which set to recite. Morning adhkar are recited after Fajr / around sunrise;
/// evening adhkar after Asr / around Maghrib.
/// Which set to recite. v3.1 expanded from morning/evening to the full
/// daily-use catalog from Hisn al-Muslim (sleep, waking, post-prayer, etc.).
enum AdhkarSet: String, CaseIterable {
    case morning, evening
    case postPrayer = "post_prayer"
    case sleep
    case waking
    case afterAblution = "after_ablution"
    case enteringMosque = "entering_mosque"
    case leavingMosque = "leaving_mosque"
    case beforeEating = "before_eating"
    case afterEating = "after_eating"
    case enteringHome = "entering_home"
    case leavingHome = "leaving_home"
    case distress
    case forgiveness

    /// Localized Arabic display name for this set.
    var arabicName: String {
        switch self {
        case .morning:        return "أذكار الصباح"
        case .evening:        return "أذكار المساء"
        case .postPrayer:     return "أذكار بعد الصلاة"
        case .sleep:          return "أذكار النوم"
        case .waking:         return "أذكار الاستيقاظ"
        case .afterAblution:  return "أذكار بعد الوضوء"
        case .enteringMosque: return "أذكار دخول المسجد"
        case .leavingMosque:  return "أذكار الخروج من المسجد"
        case .beforeEating:   return "أذكار قبل الطعام"
        case .afterEating:    return "أذكار بعد الطعام"
        case .enteringHome:   return "أذكار دخول المنزل"
        case .leavingHome:    return "أذكار الخروج من المنزل"
        case .distress:       return "أذكار الكرب والهم"
        case .forgiveness:    return "أذكار الاستغفار والتوبة"
        }
    }

    /// Display name in the same language as the rest of the application.
    /// Morning/evening already have full translations; the remaining names
    /// use a compact in-code table so older translation bundles still render
    /// correctly during an in-place update.
    var localizedName: String {
        if self == .morning { return t("adhkar.morning_title") }
        if self == .evening { return t("adhkar.evening_title") }
        let names: [String: [AdhkarSet: String]] = [
            "en": [.postPrayer: "After Prayer", .sleep: "Before Sleep", .waking: "Upon Waking", .afterAblution: "After Ablution", .enteringMosque: "Entering the Mosque", .leavingMosque: "Leaving the Mosque", .beforeEating: "Before Eating", .afterEating: "After Eating", .enteringHome: "Entering Home", .leavingHome: "Leaving Home", .distress: "Distress and Worry", .forgiveness: "Forgiveness and Repentance"],
            "fr": [.postPrayer: "Après la prière", .sleep: "Avant de dormir", .waking: "Au réveil", .afterAblution: "Après les ablutions", .enteringMosque: "Entrée à la mosquée", .leavingMosque: "Sortie de la mosquée", .beforeEating: "Avant de manger", .afterEating: "Après avoir mangé", .enteringHome: "Entrée à la maison", .leavingHome: "Sortie de la maison", .distress: "Détresse et souci", .forgiveness: "Pardon et repentir"],
            "es": [.postPrayer: "Después de la oración", .sleep: "Antes de dormir", .waking: "Al despertar", .afterAblution: "Después de la ablución", .enteringMosque: "Al entrar en la mezquita", .leavingMosque: "Al salir de la mezquita", .beforeEating: "Antes de comer", .afterEating: "Después de comer", .enteringHome: "Al entrar en casa", .leavingHome: "Al salir de casa", .distress: "Angustia y preocupación", .forgiveness: "Perdón y arrepentimiento"],
            "ar": [.postPrayer: "أذكار بعد الصلاة", .sleep: "أذكار النوم", .waking: "أذكار الاستيقاظ", .afterAblution: "أذكار بعد الوضوء", .enteringMosque: "أذكار دخول المسجد", .leavingMosque: "أذكار الخروج من المسجد", .beforeEating: "أذكار قبل الطعام", .afterEating: "أذكار بعد الطعام", .enteringHome: "أذكار دخول المنزل", .leavingHome: "أذكار الخروج من المنزل", .distress: "أذكار الكرب والهم", .forgiveness: "أذكار الاستغفار والتوبة"],
            "zh": [.postPrayer: "礼拜后", .sleep: "睡前", .waking: "醒来时", .afterAblution: "小净后", .enteringMosque: "进入清真寺", .leavingMosque: "离开清真寺", .beforeEating: "用餐前", .afterEating: "用餐后", .enteringHome: "进入家中", .leavingHome: "离开家中", .distress: "忧虑与困苦", .forgiveness: "求饶与悔过"],
            "hi": [.postPrayer: "नमाज़ के बाद", .sleep: "सोने से पहले", .waking: "जागने पर", .afterAblution: "वुज़ू के बाद", .enteringMosque: "मस्जिद में प्रवेश", .leavingMosque: "मस्जिद से निकलना", .beforeEating: "खाने से पहले", .afterEating: "खाने के बाद", .enteringHome: "घर में प्रवेश", .leavingHome: "घर से निकलना", .distress: "चिंता और परेशानी", .forgiveness: "माफ़ी और तौबा"],
            "bn": [.postPrayer: "নামাজের পরে", .sleep: "ঘুমের আগে", .waking: "ঘুম থেকে জাগলে", .afterAblution: "ওযুর পরে", .enteringMosque: "মসজিদে প্রবেশ", .leavingMosque: "মসজিদ থেকে বের হওয়া", .beforeEating: "খাওয়ার আগে", .afterEating: "খাওয়ার পরে", .enteringHome: "ঘরে প্রবেশ", .leavingHome: "ঘর থেকে বের হওয়া", .distress: "দুশ্চিন্তা ও কষ্ট", .forgiveness: "ক্ষমা ও তওবা"],
            "ru": [.postPrayer: "После молитвы", .sleep: "Перед сном", .waking: "После пробуждения", .afterAblution: "После омовения", .enteringMosque: "Вход в мечеть", .leavingMosque: "Выход из мечети", .beforeEating: "Перед едой", .afterEating: "После еды", .enteringHome: "Вход в дом", .leavingHome: "Выход из дома", .distress: "Тревога и печаль", .forgiveness: "Прощение и покаяние"],
            "pt": [.postPrayer: "Depois da oração", .sleep: "Antes de dormir", .waking: "Ao acordar", .afterAblution: "Depois da ablução", .enteringMosque: "Ao entrar na mesquita", .leavingMosque: "Ao sair da mesquita", .beforeEating: "Antes de comer", .afterEating: "Depois de comer", .enteringHome: "Ao entrar em casa", .leavingHome: "Ao sair de casa", .distress: "Angústia e preocupação", .forgiveness: "Perdão e arrependimento"],
            "ur": [.postPrayer: "نماز کے بعد", .sleep: "سونے سے پہلے", .waking: "جاگنے پر", .afterAblution: "وضو کے بعد", .enteringMosque: "مسجد میں داخلہ", .leavingMosque: "مسجد سے نکلنا", .beforeEating: "کھانے سے پہلے", .afterEating: "کھانے کے بعد", .enteringHome: "گھر میں داخلہ", .leavingHome: "گھر سے نکلنا", .distress: "پریشانی اور غم", .forgiveness: "مغفرت اور توبہ"]
        ]
        return names[Localizer.shared.current.code]?[self]
            ?? names["en"]?[self]
            ?? arabicName
    }
    /// Default schedule anchor for auto-play ("manual" = no schedule).
    var defaultAnchor: String {
        switch self {
        case .morning:  return "shuruq"
        case .evening:  return "asr"
        case .sleep:    return "isha"
        default:        return "manual"
        }
    }
}

/// Loads + filters the bundled `adhkar.json`. Cached after first load.
/// v3.1: loads ALL categories dynamically (any key whose value is an array),
/// not just morning/evening.
enum AdhkarData {
    private static var cache: [String: [AdhkarItem]]?
    static func loadAll() -> [String: [AdhkarItem]] {
        if let c = cache { return c }
        guard let url = Bundle.main.url(forResource: "adhkar", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let raw = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return [:]
        }
        // Parse loosely: any top-level key whose value is an array becomes an
        // AdhkarItem list. Metadata keys (dicts like "_meta") are skipped.
        let decoder = JSONDecoder()
        var out: [String: [AdhkarItem]] = [:]
        for (key, val) in raw {
            guard let arr = val as? [Any] else { continue }  // skip non-arrays
            if let jsonData = try? JSONSerialization.data(withJSONObject: arr),
               let items = try? decoder.decode([AdhkarItem].self, from: jsonData) {
                out[key] = items
            }
        }
        cache = out
        return out
    }
    static func items(for set: AdhkarSet) -> [AdhkarItem] {
        loadAll()[set.rawValue] ?? []
    }
    /// v3.1: items for a raw category key (e.g. "post_prayer").
    static func items(forKey key: String) -> [AdhkarItem] {
        loadAll()[key] ?? []
    }
}

// ============================================================================
// MARK: Adhkar collections — user-editable groups of adhkar (v3 data model)
// ============================================================================
// Replaces the hardcoded morning/evening split with a user-defined Collection
// model. Each collection has a name, an optional schedule (anchor prayer),
// and an ordered list of AdhkarEntry items. Defaults are seeded once on first
// launch of v3 (see `migrateAdhkarDefaults()` in AppDelegate) so existing v2
// users keep their sunrise/Asr behavior.

/// One user-authored dhikr inside a collection. `audioRef` is a logical ref,
/// NOT a path — resolved at runtime by `resolveAdhkarAudio(_:)`. Two forms:
///   • "bundled:<filename>"  → looked up in Resources/adhkar_audio/
///   • "imported:<uuid>.<ext>" → looked up in ~/Library/Application Support/
/// Storing a logical ref (not a path) means app-support can move without
/// breaking saved libraries.
struct AdhkarEntry: Codable, Identifiable, Equatable {
    var id:       UUID
    var arabic:   String
    /// Recommended repetitions. Audio loops up to 3× authentically; higher
    /// counts (33, 100) play once and the count is shown for the user.
    var count:    Int
    var virtue:   String
    var source:   String
    var audioRef: String
    /// Initialize from a bundled-library AdhkarItem (preserves its content).
    init(from item: AdhkarItem) {
        self.id       = UUID()
        self.arabic   = item.arabic
        self.count    = item.count
        self.virtue   = item.virtue
        self.source   = item.source
        self.audioRef = "bundled:\(item.audio_file)"
    }
    init(id: UUID = UUID(), arabic: String, count: Int = 1,
         virtue: String = "", source: String = "", audioRef: String = "") {
        self.id = id; self.arabic = arabic; self.count = count
        self.virtue = virtue; self.source = source; self.audioRef = audioRef
    }
}

/// A user-defined collection of adhkar (e.g. "Morning", "Evening", "Sleep").
/// `anchorKind` controls the auto-trigger; "manual" means no schedule.
struct AdhkarCollection: Codable, Identifiable, Equatable {
    var id:         UUID
    var name:       String
    /// Stable bundled category key (`AdhkarSet.rawValue`). Nil means this is
    /// a fully user-defined collection whose name must be preserved verbatim.
    var categoryKey: String?
    /// "manual" (no schedule) | "shuruq" | "fajr" | "dhuhr" | "asr" | "maghrib" | "isha"
    var anchorKind: String
    /// When true, the collection auto-recites at `anchorKind` time once/day.
    var autoPlay:   Bool
    var items:      [AdhkarEntry]
    init(id: UUID = UUID(), name: String, categoryKey: String? = nil,
         anchorKind: String = "manual", autoPlay: Bool = false,
         items: [AdhkarEntry] = []) {
        self.id = id; self.name = name; self.categoryKey = categoryKey
        self.anchorKind = anchorKind
        self.autoPlay = autoPlay; self.items = items
    }

    var displayName: String {
        guard let key = categoryKey, let set = AdhkarSet(rawValue: key) else {
            return name
        }
        return set.localizedName
    }
}

/// Loads / saves the user's adhkar library to UserDefaults as JSON Data.
/// Mirrors the favorites pattern (kFavoritesKey / loadFavorites / saveFavorites).
enum AdhkarLibrary {
    static func load() -> [AdhkarCollection] {
        guard let data = UserDefaults.standard.data(forKey: kAdhkarLibraryKey),
              let arr  = try? JSONDecoder().decode([AdhkarCollection].self, from: data) else {
            return []
        }
        return arr
    }
    static func save(_ collections: [AdhkarCollection]) {
        if let data = try? JSONEncoder().encode(collections) {
            UserDefaults.standard.set(data, forKey: kAdhkarLibraryKey)
        }
    }
    /// Find a collection by ID (defensive; returns nil if user deleted it).
    static func find(_ id: UUID, in collections: [AdhkarCollection]) -> Int? {
        collections.firstIndex(where: { $0.id == id })
    }
}

/// One-time migration from v2's fixed morning/evening sets to v3 collections.
/// Seeds "Morning" (sunrise anchor) + "Evening" (asr anchor) from the bundled
/// library on first run of v3. Idempotent via `kAdhkarMigrated` flag.
/// One-time v2→v3 migration: seeds Morning + Evening collections from the
/// bundled library on first run of v3. Idempotent via `kAdhkarMigrated`.
func migrateAdhkarDefaults() {
    let migrated = UserDefaults.standard.bool(forKey: kAdhkarMigrated)
    if migrated { return }
    // Only seed if there's no library yet (don't clobber user edits).
    if !AdhkarLibrary.load().isEmpty {
        UserDefaults.standard.set(true, forKey: kAdhkarMigrated)
        return
    }
    seedAllDefaultCollections()
    UserDefaults.standard.set(true, forKey: kAdhkarMigrated)
}

/// v3.1 migration: adds the expanded catalog (sleep, waking, post-prayer,
/// etc.) to users who already migrated on v3.0.0 (which only seeded
/// morning/evening). Idempotent — only adds collections that don't already
/// exist by name, so user edits are never clobbered.
func migrateAdhkarExpandedCatalog() {
    let expanded = UserDefaults.standard.bool(forKey: "adhkarCatalogExpanded_v31")
    if expanded { return }
    var existing = AdhkarLibrary.load()
    let existingNames = Set(existing.map { $0.name })
    // Respect the user's v2 anchor prefs for morning/evening.
    let mAnchor = UserDefaults.standard.string(forKey: kAdhkarMorningAnchor) ?? "shuruq"
    let eAnchor = UserDefaults.standard.string(forKey: kAdhkarEveningAnchor) ?? "asr"
    let autoOn  = UserDefaults.standard.object(forKey: kAdhkarEnabled) != nil
                  ? UserDefaults.standard.bool(forKey: kAdhkarEnabled) : true
    for set in AdhkarSet.allCases {
        let name = set.arabicName
        if existingNames.contains(name) { continue }  // don't clobber
        let items = AdhkarData.items(for: set).map { AdhkarEntry(from: $0) }
        guard !items.isEmpty else { continue }
        // Override anchors for morning/evening from v2 prefs.
        var anchor = set.defaultAnchor
        if set == .morning { anchor = mAnchor }
        if set == .evening { anchor = eAnchor }
        // Only morning/evening/sleep auto-play by default; the rest are manual.
        let plays = (set == .morning || set == .evening) ? autoOn : false
        existing.append(AdhkarCollection(name: name, categoryKey: set.rawValue,
                                          anchorKind: anchor,
                                          autoPlay: plays, items: items))
    }
    AdhkarLibrary.save(existing)
    UserDefaults.standard.set(true, forKey: "adhkarCatalogExpanded_v31")
}

/// Seeds the full default catalog (used by the v2→v3 first-run migration).
func seedAllDefaultCollections() {
    let mAnchor = UserDefaults.standard.string(forKey: kAdhkarMorningAnchor) ?? "shuruq"
    let eAnchor = UserDefaults.standard.string(forKey: kAdhkarEveningAnchor) ?? "asr"
    let autoOn  = UserDefaults.standard.object(forKey: kAdhkarEnabled) != nil
                  ? UserDefaults.standard.bool(forKey: kAdhkarEnabled) : true
    var seeded: [AdhkarCollection] = []
    for set in AdhkarSet.allCases {
        let items = AdhkarData.items(for: set).map { AdhkarEntry(from: $0) }
        guard !items.isEmpty else { continue }
        var anchor = set.defaultAnchor
        if set == .morning { anchor = mAnchor }
        if set == .evening { anchor = eAnchor }
        let plays = (set == .morning || set == .evening) ? autoOn : false
        seeded.append(AdhkarCollection(name: set.arabicName,
                                       categoryKey: set.rawValue,
                                       anchorKind: anchor,
                                       autoPlay: plays, items: items))
    }
    AdhkarLibrary.save(seeded)
}

/// Attach stable identities to collections created by pre-v3.7 builds. Only
/// exact bundled Arabic names are migrated, so custom or renamed collections
/// are never reclassified or overwritten.
func migrateAdhkarCollectionIdentity() {
    guard !UserDefaults.standard.bool(forKey: kAdhkarIdentityMigrated) else { return }
    let byArabicName = Dictionary(uniqueKeysWithValues:
        AdhkarSet.allCases.map { ($0.arabicName, $0.rawValue) })
    var collections = AdhkarLibrary.load()
    var changed = false
    for i in collections.indices where collections[i].categoryKey == nil {
        if let key = byArabicName[collections[i].name] {
            collections[i].categoryKey = key
            changed = true
        }
    }
    if changed { AdhkarLibrary.save(collections) }
    UserDefaults.standard.set(true, forKey: kAdhkarIdentityMigrated)
}

/// Keep the legacy morning/evening preference keys and the v3 collection
/// model synchronized. The collection model is the scheduler's source of
/// truth; the legacy keys remain for compatibility with older installs.
func updateBuiltInAdhkarSchedule(_ set: AdhkarSet,
                                 anchor: String? = nil,
                                 autoPlay: Bool? = nil) {
    var collections = AdhkarLibrary.load()
    guard let i = collections.firstIndex(where: { $0.categoryKey == set.rawValue }) else { return }
    if let anchor = anchor { collections[i].anchorKind = anchor }
    if let autoPlay = autoPlay { collections[i].autoPlay = autoPlay }
    AdhkarLibrary.save(collections)
    if let anchor = anchor {
        if set == .morning { UserDefaults.standard.set(anchor, forKey: kAdhkarMorningAnchor) }
        if set == .evening { UserDefaults.standard.set(anchor, forKey: kAdhkarEveningAnchor) }
    }
}

/// Resolves an `audioRef` to a playable URL, or nil if not found.
///   "bundled:75.mp3"  → Resources/adhkar_audio/75.mp3
///   "imported:abc.mp3" → ~/Library/Application Support/SalatTime/audio/abc.mp3
func resolveAdhkarAudio(_ ref: String) -> URL? {
    if ref.hasPrefix("bundled:") {
        let fname = String(ref.dropFirst("bundled:".count))
        let base  = fname.replacingOccurrences(of: ".mp3", with: "")
        return Bundle.main.url(forResource: base, withExtension: "mp3",
                                subdirectory: "adhkar_audio")
    }
    if ref.hasPrefix("imported:") {
        let fname = String(ref.dropFirst("imported:".count))
        return adhkarAudioStorageDir().appendingPathComponent(fname)
    }
    return nil
}

/// Directory for user-imported adhkar audio. Created lazily on first import.
func adhkarAudioStorageDir() -> URL {
    let fm = FileManager.default
    let support = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
        ?? URL(fileURLWithPath: NSTemporaryDirectory())
    let dir = support.appendingPathComponent("SalatTime/audio", isDirectory: true)
    if !fm.fileExists(atPath: dir.path) {
        try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
    }
    return dir
}

/// One entry in the audio picker UI — bundled recitation or imported file.
struct AdhkarAudioOption: Identifiable, Equatable {
    let id: String          // the audioRef ("bundled:75.mp3" / "imported:abc.mp3")
    let displayName: String // what the user sees in the popup
    let isBundled: Bool
}

/// Lists all audio available to the adhkar picker: the bundled recitations
/// (from adhkar.json) plus any user-imported files in app-support. The
/// editor popup shows these in alphabetical order.
func adhkarAudioOptions() -> [AdhkarAudioOption] {
    var out: [AdhkarAudioOption] = []
    // Bundled — dedupe by filename across ALL categories (not just morning/evening).
    var seen = Set<String>()
    let raw = AdhkarData.loadAll()
    for setKey in raw.keys {
        for item in raw[setKey] ?? [] {
            if item.audio_file.isEmpty { continue }
            if seen.insert(item.audio_file).inserted {
                let ref = "bundled:\(item.audio_file)"
                out.append(AdhkarAudioOption(id: ref,
                                              displayName: "Bundled · \(item.audio_file)",
                                              isBundled: true))
            }
        }
    }
    // Imported — anything in app-support/audio.
    let dir = adhkarAudioStorageDir()
    if let names = try? FileManager.default.contentsOfDirectory(atPath: dir.path) {
        for name in names.sorted() {
            let lower = name.lowercased()
            guard lower.hasSuffix(".mp3") || lower.hasSuffix(".m4a") || lower.hasSuffix(".aac") || lower.hasSuffix(".wav") else { continue }
            let ref = "imported:\(name)"
            out.append(AdhkarAudioOption(id: ref,
                                          displayName: "Imported · \(name)",
                                          isBundled: false))
        }
    }
    return out
}

/// Imports a user-selected audio file into app-support and returns the
/// `audioRef` ("imported:<filename>") on success, or nil on failure.
/// Copies (not moves) so the user's source file is untouched. Filenames are
/// de-duplicated by appending a counter if a name collision occurs.
@discardableResult
func importAdhkarAudio(from sourceURL: URL) -> String? {
    let dir = adhkarAudioStorageDir()
    var dest = dir.appendingPathComponent(sourceURL.lastPathComponent)
    // De-dup: if the file exists, append " 2", " 3", … before the extension.
    if FileManager.default.fileExists(atPath: dest.path) {
        let ext = dest.pathExtension
        let base = dest.deletingPathExtension().lastPathComponent
        var i = 2
        repeat {
            let candidate = dir.appendingPathComponent("\(base) \(i).\(ext)")
            if !FileManager.default.fileExists(atPath: candidate.path) {
                dest = candidate; break
            }
            i += 1
        } while i < 1000
    }
    do {
        // .copyItem refuses to cross certain volume boundaries; use Data for safety.
        let data = try Data(contentsOf: sourceURL)
        try data.write(to: dest, options: [.atomic])
        return "imported:\(dest.lastPathComponent)"
    } catch {
        return nil
    }
}

/// Presents the audio-open panel and returns the imported audioRef, or nil
/// if the user cancelled. Filtered to common audio formats.
func presentAudioImportPanel() -> String? {
    let panel = NSOpenPanel()
    panel.canChooseFiles = true
    panel.canChooseDirectories = false
    panel.allowsMultipleSelection = false
    panel.allowsOtherFileTypes = false
    panel.prompt = t("adhkar.import_audio")
    panel.allowedContentTypes = [
        .mp3, .mpeg4Audio, .wav, .aiff
    ]
    guard panel.runModal() == .OK, let url = panel.url else { return nil }
    return importAdhkarAudio(from: url)
}

/// Drives adhkar playback. Owns its own `AVAudioPlayer` (separate from the
/// adhan player so the two never collide). The owning panel drives the UI by
/// setting `onItemChange` / `onPlaybackStateChange` / `onFinish` closures.
final class AdhkarSession: NSObject, AVAudioPlayerDelegate, AVSpeechSynthesizerDelegate {

    /// `(current item, current item index 0-based, total items)`.
    var onItemChange:          ((AdhkarEntry, Int, Int) -> Void)?
    /// Fired on play / pause / resume / mute toggles so the panel can refresh.
    var onPlaybackStateChange: (() -> Void)?
    /// Fired when the whole set completes naturally (last item finished).
    var onFinish:              (() -> Void)?

    private(set) var items: [AdhkarEntry] = []
    private var index   = 0
    /// How many times the CURRENT item's audio has played so far.
    private var playsSoFar = 0
    /// How many times we should play the current item's audio before advancing.
    private var targetPlays = 1

    private var player: AVAudioPlayer?
    private let speechSynthesizer = AVSpeechSynthesizer()
    private var activeCategoryKey: String?
    private var cleanSegments: [ClosedRange<TimeInterval>] = []
    private var cleanSegmentIndex = 0
    private var cleanSegmentTimer: Timer?
    private var sessionGeneration = 0
    private var activeUtterance: AVSpeechUtterance?
    private(set) var isPlaying  = false
    private(set) var isPaused   = false
    private(set) var isMuted    = false

    /// Total number of items in the active set (0 if not started).
    var count: Int { items.count }
    /// Currently-active item, or nil if the session hasn't started / has ended.
    var currentItem: AdhkarEntry? {
        guard index >= 0 && index < items.count else { return nil }
        return items[index]
    }
    /// 1-based position for display ("3 of 25"); nil if nothing active.
    var position: (Int, Int)? {
        guard !items.isEmpty, index < items.count else { return nil }
        return (index + 1, items.count)
    }

    /// Begin reciting a full collection. Replaces any in-flight session.
    /// v3 entry point — accepts user-edited collections.
    func start(collection: AdhkarCollection) {
        stop()
        items = collection.items
        activeCategoryKey = collection.categoryKey
        guard !items.isEmpty else { return }
        index = 0
        playsSoFar = 0
        playCurrent()
    }

    /// v2 compatibility shim — wraps a bundled morning/evening set into a
    /// collection and starts it. Used by the right-click menu's fixed
    /// morning/evening entries (which now read from the user's library).
    func start(set: AdhkarSet) {
        let entries = AdhkarData.items(for: set).map { AdhkarEntry(from: $0) }
        start(collection: AdhkarCollection(name: set.arabicName,
                                            categoryKey: set.rawValue,
                                            items: entries))
    }

    /// Advance to the next item (skips remaining repeats of the current one).
    func next() {
        guard !items.isEmpty else { return }
        if index + 1 < items.count {
            index += 1
            playsSoFar = 0
            if isPaused { onItemChange?(items[index], index, items.count); return }
            playCurrent()
        } else {
            finish()
        }
    }

    /// Jump back to the previous item.
    func previous() {
        guard !items.isEmpty else { return }
        if index > 0 {
            index -= 1
            playsSoFar = 0
            if isPaused { onItemChange?(items[index], index, items.count); return }
            playCurrent()
        }
    }

    func pause() {
        guard isPlaying else { return }
        player?.pause()
        if speechSynthesizer.isSpeaking {
            speechSynthesizer.pauseSpeaking(at: .immediate)
        }
        isPlaying = false
        isPaused  = true
        onPlaybackStateChange?()
    }

    func resume() {
        guard isPaused else { return }
        let resumed = (player?.play() ?? false)
            || (speechSynthesizer.isPaused && speechSynthesizer.continueSpeaking())
        if resumed {
            isPlaying = true
            isPaused  = false
            onPlaybackStateChange?()
        }
    }

    /// Toggle mute — keeps advancing through items but the audio is silent.
    var muted: Bool { isMuted }
    func setMuted(_ m: Bool) {
        guard isMuted != m else { return }
        isMuted = m
        player?.volume = m ? 0 : savedAdhkarVolume()
        onPlaybackStateChange?()
    }

    /// Hard stop — abandons the session and releases the player.
    func stop() {
        sessionGeneration += 1
        cleanSegmentTimer?.invalidate()
        cleanSegmentTimer = nil
        player?.stop()
        player = nil
        if speechSynthesizer.isSpeaking || speechSynthesizer.isPaused {
            activeUtterance = nil
            speechSynthesizer.stopSpeaking(at: .immediate)
        }
        items = []
        activeCategoryKey = nil
        index = 0
        playsSoFar = 0
        isPlaying = false
        isPaused  = false
        onPlaybackStateChange?()
    }

    // MARK: - internal

    private func playCurrent() {
        guard index >= 0 && index < items.count else { finish(); return }
        let item = items[index]
        // Loop count: respect up to 3 (authentic for the three Quls); higher
        // recommended counts (33, 100) are shown in the UI for the user to
        // complete via tasbih — we only play the audio once in that case.
        targetPlays = max(1, min(item.count, 3))
        playsSoFar = 0
        onItemChange?(item, index, items.count)
        playAudioRef(item.audioRef, text: item.arabic)
    }

    /// Resolve a logical audioRef to a URL and start playback. Handles both
    /// bundled ("bundled:75.mp3") and imported ("imported:abc.mp3") refs via
    /// resolveAdhkarAudio(). Falls back to auto-advance if audio is missing.
    private func playAudioRef(_ ref: String, text: String) {
        cleanSegmentTimer?.invalidate()
        cleanSegmentTimer = nil
        player?.stop()
        if speechSynthesizer.isSpeaking || speechSynthesizer.isPaused {
            activeUtterance = nil
            speechSynthesizer.stopSpeaking(at: .immediate)
        }
        // If the entry has no audio at all, just advance after a beat.
        guard !ref.isEmpty else {
            scheduleAutoAdvance()
            return
        }

        // Several evening files contain the morning wording followed by a
        // spoken instruction explaining what to substitute at night. Reading
        // that file would contradict the text on screen, so use the installed
        // macOS Arabic voice for these exact variants instead.
        let eveningVariants: Set<String> = [
            "bundled:77.mp3", "bundled:78.mp3", "bundled:80.mp3",
            "bundled:81.mp3", "bundled:89.mp3", "bundled:90.mp3"
        ]
        if activeCategoryKey == AdhkarSet.evening.rawValue,
           eveningVariants.contains(ref) {
            playSpokenText(text)
            return
        }
        guard let url = resolveAdhkarAudio(ref),
              FileManager.default.fileExists(atPath: url.path),
              let p = try? AVAudioPlayer(contentsOf: url) else {
            // Expanded collections in older installs referenced Hisn files
            // that were never bundled. Read their exact Arabic text instead
            // of silently flashing past them in half a second.
            if ref.hasPrefix("bundled:"), !text.isEmpty {
                playSpokenText(text)
            } else {
                scheduleAutoAdvance()
            }
            return
        }
        player = p
        p.delegate = self
        // Apply volume from settings (default 1.0), silenced if muted.
        p.volume = isMuted ? 0 : savedAdhkarVolume()
        // Route to the selected output device (mirrors playAdhan's routing).
        let wantedUID = UserDefaults.standard.string(forKey: kAdhkarAudioDevice) ?? ""
        if !wantedUID.isEmpty { p.currentDevice = wantedUID }
        p.prepareToPlay()

        // Hisn recordings often append phrases such as "three times" or
        // "and in the evening say…". These ranges contain only the dhikr
        // itself. File 75 has two ranges so its title and "Ayat al-Kursi"
        // announcement are skipped while the ta'awwudh is preserved.
        cleanSegments = cleanRecitationSegments(for: ref)
        cleanSegmentIndex = 0
        if let first = cleanSegments.first { p.currentTime = first.lowerBound }
        if p.play() {
            isPlaying = true
            isPaused  = false
            startCleanSegmentMonitorIfNeeded()
            onPlaybackStateChange?()
        }
    }

    private func savedAdhkarVolume() -> Float {
        if UserDefaults.standard.object(forKey: kAdhkarVolume) == nil { return 1.0 }
        return min(1, max(0, UserDefaults.standard.float(forKey: kAdhkarVolume)))
    }

    private func cleanRecitationSegments(for ref: String) -> [ClosedRange<TimeInterval>] {
        let ranges: [String: [ClosedRange<TimeInterval>]] = [
            "bundled:75.mp3":  [13.60...16.96, 18.36...74.80],
            "bundled:77.mp3":  [0.0...40.60],
            "bundled:78.mp3":  [0.0...12.16],
            "bundled:80.mp3":  [0.0...20.86],
            "bundled:82.mp3":  [0.0...26.90],
            "bundled:83.mp3":  [0.0...7.94],
            "bundled:86.mp3":  [0.0...9.34],
            "bundled:87.mp3":  [0.0...11.14],
            "bundled:91.mp3":  [0.0...3.44],
            "bundled:92.mp3":  [0.0...11.59],
            "bundled:93.mp3":  [0.0...10.78],
            "bundled:94.mp3":  [0.0...12.20],
            "bundled:95.mp3":  [0.0...8.84],
            "bundled:96.mp3":  [0.0...4.50],
            "bundled:97.mp3":  [0.0...5.86]
        ]
        return ranges[ref] ?? []
    }

    private func startCleanSegmentMonitorIfNeeded() {
        guard !cleanSegments.isEmpty else { return }
        cleanSegmentTimer?.invalidate()
        cleanSegmentTimer = Timer.scheduledTimer(withTimeInterval: 0.05,
                                                  repeats: true) { [weak self] timer in
            guard let self = self, let p = self.player else {
                timer.invalidate(); return
            }
            guard p.isPlaying,
                  self.cleanSegments.indices.contains(self.cleanSegmentIndex) else { return }
            let range = self.cleanSegments[self.cleanSegmentIndex]
            guard p.currentTime >= range.upperBound else { return }
            if self.cleanSegmentIndex + 1 < self.cleanSegments.count {
                self.cleanSegmentIndex += 1
                p.currentTime = self.cleanSegments[self.cleanSegmentIndex].lowerBound
            } else {
                timer.invalidate()
                self.cleanSegmentTimer = nil
                p.stop()
                self.player = nil
                self.completeCurrentPlay()
            }
        }
    }

    private func playSpokenText(_ text: String) {
        guard !text.isEmpty else { scheduleAutoAdvance(); return }
        speechSynthesizer.delegate = self
        let utterance = AVSpeechUtterance(string: text)
        // Prefer the highest-quality Arabic voice installed on this Mac.
        // If the user later adds an Enhanced or Premium Arabic voice in
        // macOS, the reader adopts it automatically without an app update.
        // Quality outranks regional matching because adhkar use MSA.
        let arabicVoices = AVSpeechSynthesisVoice.speechVoices().filter {
            $0.language.lowercased().hasPrefix("ar")
        }
        utterance.voice = arabicVoices.max { lhs, rhs in
            if lhs.quality.rawValue != rhs.quality.rawValue {
                return lhs.quality.rawValue < rhs.quality.rawValue
            }
            let lhsRegional = lhs.language == "ar-SA" ? 1 : 0
            let rhsRegional = rhs.language == "ar-SA" ? 1 : 0
            return lhsRegional < rhsRegional
        } ?? AVSpeechSynthesisVoice(language: "ar-SA")
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate * 0.82
        utterance.pitchMultiplier = 0.98
        utterance.volume = isMuted ? 0 : savedAdhkarVolume()
        activeUtterance = utterance
        isPlaying = true
        isPaused = false
        speechSynthesizer.speak(utterance)
        onPlaybackStateChange?()
    }

    /// If audio is missing, auto-advance after a beat so the session never
    /// stalls on a single broken/silent entry.
    private func scheduleAutoAdvance() {
        let generation = sessionGeneration
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            guard let self = self else { return }
            guard generation == self.sessionGeneration, !self.items.isEmpty else { return }
            self.completeCurrentPlay()
        }
    }

    private func finish() {
        cleanSegmentTimer?.invalidate()
        cleanSegmentTimer = nil
        player?.stop()
        player = nil
        isPlaying = false
        isPaused  = false
        let cb = onFinish
        items = []
        index = 0
        cb?()
    }

    // MARK: - AVAudioPlayerDelegate
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        cleanSegmentTimer?.invalidate()
        cleanSegmentTimer = nil
        completeCurrentPlay()
    }

    private func completeCurrentPlay() {
        playsSoFar += 1
        if playsSoFar < targetPlays {
            // Same item, repeat.
            if items.indices.contains(index) {
                playAudioRef(items[index].audioRef, text: items[index].arabic)
            }
            return
        }
        // Advance to next item.
        if index + 1 < items.count {
            index += 1
            playCurrent()
        } else {
            finish()
        }
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer,
                           didFinish utterance: AVSpeechUtterance) {
        guard activeUtterance === utterance, !items.isEmpty else { return }
        activeUtterance = nil
        completeCurrentPlay()
    }
    func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: Error?) {
        // Skip to next on decode failure rather than stalling.
        next()
    }
}

// ============================================================================
// MARK: Adhkar panel — floating, always-on-top window for following the recitation
// ============================================================================
// The adhkar panel is a borderless NSPanel that floats above other apps so the
// user can follow along while doing other things. It owns its own AdhkarSession
// (separate from the adhan player so they never collide). The text on screen is
// always the dhikr currently being recited.

final class AdhkarPanel: NSPanel {

    private let session = AdhkarSession()
    private var currentSet: AdhkarSet = .morning
    private var currentCollection: AdhkarCollection?
    var onDismiss: (() -> Void)?
    private var isFinishing = false

    // UI elements
    private var titleLabel:    NSTextField!
    private var positionLabel: NSTextField!       // "3 of 25"
    private var arabicLabel:   NSTextField!       // the dhikr (large, RTL)
    private var countLabel:    NSTextField!       // "تُقرأ 3 مرات"
    private var virtueLabel:   NSTextField!      // virtue / hadith source
    private var playBtn:       HoverIconButton!
    private var muteBtn:       HoverIconButton!
    private var container:     NSView!            // everything sits in here

    private let panelWidth:  CGFloat = 460
    private let panelHeight: CGFloat = 620

    init() {
        let frame = NSRect(x: 0, y: 0, width: panelWidth, height: panelHeight)
        // nonactivatingPanel = the panel doesn't steal focus from the current
        // app (you can keep typing while it floats). floating level keeps it
        // above normal windows. titled + closable for the standard chrome.
        super.init(contentRect: frame,
                   styleMask: [.nonactivatingPanel, .titled, .closable, .resizable],
                   backing: .buffered, defer: false)
        self.level              = .floating
        self.isOpaque           = false
        self.backgroundColor    = .clear
        self.isMovableByWindowBackground = true
        self.titleVisibility    = .hidden
        self.titlebarAppearsTransparent = false
        self.collectionBehavior = [.canJoinAllSpaces, .stationary]
        self.isReleasedWhenClosed = false
        buildUI()
        wireSession()
    }

    // MARK: - public API

    /// Open (or reopen) the panel and start reciting the chosen set.
    func present(set: AdhkarSet, autoPlay: Bool = true) {
        currentSet = set
        currentCollection = matchingUserCollection(for: set)
        titleLabel.stringValue = set.localizedName
        centerOnActiveScreen()
        makeKeyAndOrderFront(nil)
        if autoPlay {
            // Try to play from the user's matching collection first; fall back
            // to the bundled set if no user collection exists.
            if let c = currentCollection {
                session.start(collection: c)
            } else {
                session.start(set: set)
            }
        }
    }

    /// v3 entry point — present a specific user-edited collection.
    func present(collection: AdhkarCollection, autoPlay: Bool = true) {
        currentCollection = collection
        if let key = collection.categoryKey, let set = AdhkarSet(rawValue: key) {
            currentSet = set
        }
        titleLabel.stringValue = collection.displayName
        centerOnActiveScreen()
        makeKeyAndOrderFront(nil)
        if autoPlay { session.start(collection: collection) }
    }

    /// Find the user's built-in collection by stable category identity. The
    /// Arabic-name fallback only exists for libraries not yet migrated.
    private func matchingUserCollection(for set: AdhkarSet) -> AdhkarCollection? {
        return AdhkarLibrary.load().first(where: {
            $0.categoryKey == set.rawValue || $0.name == set.arabicName
        })
    }

    func togglePlayPause() {
        if session.isPlaying { session.pause() }
        else if session.isPaused { session.resume() }
        else {
            // Restart from the user's matching collection if present.
            if let c = matchingUserCollection(for: currentSet) {
                session.start(collection: c)
            } else {
                session.start(set: currentSet)
            }
        }
    }

    func reloadForPreferences() {
        buildUI()
        wireSession()
        titleLabel.stringValue = currentCollection?.displayName ?? currentSet.localizedName
        if let item = session.currentItem, let position = session.position {
            renderItem(item, idx: position.0 - 1, total: position.1)
        }
    }

    // MARK: - UI build

    private func buildUI() {
        let root = RootPanelView(frame: NSRect(x: 0, y: 0,
                                               width: panelWidth,
                                               height: panelHeight))
        root.autoresizingMask = [.width, .height]
        contentView = root
        let content = root.contentContainer

        let header = NSView()
        header.translatesAutoresizingMaskIntoConstraints = false
        header.wantsLayer = true
        header.layer?.backgroundColor = NSColor.appGreenHeader.cgColor
        content.addSubview(header)

        let mark = NSImageView()
        mark.translatesAutoresizingMaskIntoConstraints = false
        mark.image = templateSymbol("book.pages.fill", pointSize: 27, weight: .semibold)
        mark.contentTintColor = NSColor(white: 1, alpha: 0.96)
        header.addSubview(mark)

        container = NSView()
        container.translatesAutoresizingMaskIntoConstraints = false
        content.addSubview(container)

        titleLabel = makeLabel(fontSize: 18, weight: .semibold,
                               alignment: Localizer.shared.leadingAlignment,
                               textColor: .white)
        positionLabel = makeLabel(fontSize: 11, weight: .medium,
                                   alignment: Localizer.shared.leadingAlignment,
                                   textColor: NSColor(white: 1, alpha: 0.82))
        header.addSubview(titleLabel)
        header.addSubview(positionLabel)

        let readingCard = AdaptiveCardView()
        readingCard.translatesAutoresizingMaskIntoConstraints = false
        readingCard.cornerRadius = 14
        readingCard.addsDepth = true
        container.addSubview(readingCard)

        // Big Arabic line — this is the centerpiece. RTL, large Cairo.
        arabicLabel = NSTextField(wrappingLabelWithString: "")
        arabicLabel.isEditable = false
        arabicLabel.isBordered = false
        arabicLabel.drawsBackground = false
        arabicLabel.alignment = .center
        arabicLabel.font = NSFont(name: "Cairo", size: 24)
            ?? NSFont.systemFont(ofSize: 24, weight: .medium)
        arabicLabel.baseWritingDirection = .rightToLeft
        arabicLabel.translatesAutoresizingMaskIntoConstraints = false
        arabicLabel.cell?.truncatesLastVisibleLine = false
        arabicLabel.cell?.wraps = true
        arabicLabel.maximumNumberOfLines = 0

        countLabel = makeLabel(fontSize: 12, weight: .regular, alignment: .center,
                               textColor: .secondaryLabelColor)
        virtueLabel = makeLabel(fontSize: 11, weight: .regular, alignment: .center,
                                textColor: .tertiaryLabelColor)
        virtueLabel.baseWritingDirection = .rightToLeft
        virtueLabel.alignment = .right
        virtueLabel.cell?.truncatesLastVisibleLine = false
        virtueLabel.cell?.wraps = true
        virtueLabel.maximumNumberOfLines = 0

        // Controls row
        let prevBtn  = makeControl(symbol: "backward.fill", tool: t("adhkar.prev"),
                                    action: #selector(prevTapped))
        playBtn      = makeControl(symbol: "pause.fill", tool: t("adhkar.pause"),
                                    action: #selector(playTapped))
        let nextBtn  = makeControl(symbol: "forward.fill", tool: t("adhkar.next"),
                                    action: #selector(nextTapped))
        muteBtn      = makeControl(symbol: "speaker.wave.2.fill", tool: t("adhkar.mute"),
                                    action: #selector(muteTapped))
        let stopBtn  = makeControl(symbol: "stop.fill", tool: t("adhkar.stop"),
                                    action: #selector(stopTapped), tint: .systemRed)

        let controls = NSStackView(views: [prevBtn, playBtn, nextBtn, muteBtn, stopBtn])
        controls.orientation = .horizontal
        controls.spacing = 14
        controls.distribution = .equalCentering
        controls.translatesAutoresizingMaskIntoConstraints = false

        readingCard.addSubview(arabicLabel)
        readingCard.addSubview(countLabel)
        readingCard.addSubview(virtueLabel)
        container.addSubview(controls)

        NSLayoutConstraint.activate([
            header.leadingAnchor.constraint(equalTo: content.leadingAnchor),
            header.trailingAnchor.constraint(equalTo: content.trailingAnchor),
            header.topAnchor.constraint(equalTo: content.topAnchor),
            header.heightAnchor.constraint(equalToConstant: 92),

            mark.leadingAnchor.constraint(equalTo: header.leadingAnchor, constant: 22),
            mark.centerYAnchor.constraint(equalTo: header.centerYAnchor, constant: 4),
            mark.widthAnchor.constraint(equalToConstant: 42),
            mark.heightAnchor.constraint(equalToConstant: 42),

            titleLabel.leadingAnchor.constraint(equalTo: mark.trailingAnchor, constant: 12),
            titleLabel.trailingAnchor.constraint(equalTo: header.trailingAnchor, constant: -20),
            titleLabel.topAnchor.constraint(equalTo: mark.topAnchor),
            positionLabel.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            positionLabel.trailingAnchor.constraint(equalTo: titleLabel.trailingAnchor),
            positionLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 2),

            container.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 20),
            container.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -20),
            container.topAnchor.constraint(equalTo: header.bottomAnchor, constant: 18),
            container.bottomAnchor.constraint(equalTo: content.bottomAnchor, constant: -18),

            readingCard.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            readingCard.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            readingCard.topAnchor.constraint(equalTo: container.topAnchor),
            readingCard.bottomAnchor.constraint(equalTo: controls.topAnchor, constant: -18),

            arabicLabel.topAnchor.constraint(greaterThanOrEqualTo: readingCard.topAnchor, constant: 22),
            arabicLabel.leadingAnchor.constraint(equalTo: readingCard.leadingAnchor, constant: 22),
            arabicLabel.trailingAnchor.constraint(equalTo: readingCard.trailingAnchor, constant: -22),

            countLabel.topAnchor.constraint(equalTo: arabicLabel.bottomAnchor, constant: 20),
            countLabel.centerXAnchor.constraint(equalTo: readingCard.centerXAnchor),

            virtueLabel.topAnchor.constraint(equalTo: countLabel.bottomAnchor, constant: 14),
            virtueLabel.leadingAnchor.constraint(equalTo: readingCard.leadingAnchor, constant: 22),
            virtueLabel.trailingAnchor.constraint(equalTo: readingCard.trailingAnchor, constant: -22),
            virtueLabel.bottomAnchor.constraint(lessThanOrEqualTo: readingCard.bottomAnchor,
                                                 constant: -20),

            controls.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            controls.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            controls.heightAnchor.constraint(equalToConstant: 44),
        ])
    }

    private func makeLabel(fontSize: CGFloat, weight: NSFont.Weight,
                           alignment: NSTextAlignment,
                           textColor: NSColor = .labelColor) -> NSTextField {
        let l = NSTextField(labelWithString: "")
        l.font = Localizer.shared.font(size: fontSize, weight: weight)
        l.textColor = textColor
        l.alignment = alignment
        l.translatesAutoresizingMaskIntoConstraints = false
        l.lineBreakMode = .byWordWrapping
        return l
    }

    private func makeControl(symbol: String, tool: String,
                              action: Selector, tint: NSColor? = nil) -> HoverIconButton {
        let b = HoverIconButton(symbol: symbol, toolTip: tool,
                                 target: self, action: action,
                                 pointSize: 17, size: NSSize(width: 46, height: 42))
        if let tint = tint { b.idleTint = tint; b.hoverTint = tint }
        return b
    }

    // MARK: - session wiring

    private func wireSession() {
        session.onItemChange = { [weak self] item, idx, total in
            self?.renderItem(item, idx: idx, total: total)
        }
        session.onPlaybackStateChange = { [weak self] in
            self?.refreshPlayButton()
        }
        session.onFinish = { [weak self] in
            self?.isFinishing = true
            self?.close()
        }
    }

    private func renderItem(_ item: AdhkarEntry, idx: Int, total: Int) {
        arabicLabel.stringValue = item.arabic
        // Show the repeat count as a localized "N times" string when > 1.
        let countText: String
        if item.count > 1 {
            countText = localizedInterfaceDigits(
                String(format: t("adhkar.editor.count_times"), item.count))
        } else {
            countText = ""
        }
        countLabel.stringValue = countText
        // Virtue + source (small, dimmed). Truncate virtue so it doesn't dominate.
        var v = item.virtue
        if v.count > 220 { v = String(v.prefix(220)) + "…" }
        virtueLabel.stringValue = v
        positionLabel.stringValue = "\(idx + 1) / \(total)"
        refreshPlayButton()
    }

    private func refreshPlayButton() {
        let playing = session.isPlaying
        let sym = playing ? "pause.fill" : "play.fill"
        let tool = playing ? t("adhkar.pause") : t("adhkar.play")
        if let img = templateSymbol(sym, pointSize: 16) {
            playBtn.image = img
        }
        playBtn.toolTip = tool
        muteBtn.image = templateSymbol(session.muted ? "speaker.slash.fill" : "speaker.wave.2.fill",
                                        pointSize: 16)
        muteBtn.toolTip = session.muted ? t("adhkar.unmute") : t("adhkar.mute")
    }

    // MARK: - control actions

    @objc private func prevTapped()  { session.previous() }
    @objc private func nextTapped()  { session.next() }
    @objc private func playTapped()  { togglePlayPause() }
    @objc private func muteTapped()  { session.setMuted(!session.muted) }
    @objc private func stopTapped()  { session.stop(); close() }

    // MARK: - placement

    /// Anchor to the top-right of whichever screen the user is on, just under
    /// the menu bar — predictable location that doesn't fight the active app.
    private func centerOnActiveScreen() {
        guard let screen = NSScreen.main else { return }
        let sf = screen.visibleFrame
        let w = panelWidth, h = panelHeight
        let x = sf.maxX - w - 24
        let y = sf.maxY - h - 8
        setFrame(NSRect(x: x, y: y, width: w, height: h), display: true)
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    override func close() {
        if !isFinishing { session.stop() }
        isFinishing = false
        super.close()
        let callback = onDismiss
        onDismiss = nil
        callback?()
    }
}

// ============================================================================
// MARK: Adaptive colors / views
// ============================================================================
extension NSColor {
    /// Appearance-adaptive accent color. Returned instance is fresh on each
    /// access so changing the accent preference and rebuilding the views is
    /// enough to roll out the new color everywhere — no per-color cache to
    /// invalidate. The closure resolves the current appearance + the user's
    /// chosen accent key at draw time so dark/light flips remain seamless.
    static var appAccent: NSColor {
        return NSColor(name: nil, dynamicProvider: { appearance in
            let isDark = appearance.bestMatch(from: [.darkAqua, .vibrantDark]) != nil
            let pair = currentAccentPair()
            return isDark ? pair.dark : pair.light
        })
    }

    /// Back-compat alias — the codebase was written around `appGreenAccent`
    /// before the palette existed, and keeping the name means we didn't have
    /// to touch 20+ call sites. The returned color is whatever accent the
    /// user currently has selected, not necessarily green.
    static var appGreenAccent: NSColor { return appAccent }

    /// Header strip color — always uses the current accent's light-mode
    /// shade so the white title text stays legible against it regardless
    /// of system dark mode.
    static var appAccentHeader: NSColor {
        return currentAccentPair().light
    }

    /// Preserved for any lingering reference; redirects to the dynamic header.
    static var appGreenHeader: NSColor { return appAccentHeader }
}

final class AdaptiveBackgroundView: NSView {
    private let lightColor: NSColor
    private let darkColor: NSColor
    init(frame: NSRect, light: NSColor, dark: NSColor, radius: CGFloat = 0) {
        self.lightColor = light
        self.darkColor  = dark
        super.init(frame: frame)
        wantsLayer = true
        layer?.cornerRadius = radius
        refresh()
    }
    required init?(coder: NSCoder) { fatalError() }
    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        refresh()
    }
    private func refresh() {
        let isDark = effectiveAppearance.bestMatch(from: [.darkAqua, .vibrantDark]) != nil
        layer?.backgroundColor = (isDark ? darkColor : lightColor).cgColor
    }
    // Decorative view — never intercept mouse events. Without this, a
    // full-frame AdaptiveBackgroundView (like the row selection highlight)
    // eats all clicks, making the parent row unclickable.
    override func hitTest(_ point: NSPoint) -> NSView? { nil }
}

/// Appearance-aware card that remains fully interactive. Unlike
/// `AdaptiveBackgroundView`, this view participates in hit testing, so it can
/// safely contain buttons, sliders, popups, and text fields. The colors are
/// resolved whenever the effective appearance changes instead of caching a
/// semantic system color's CGColor from whichever mode happened to be active
/// when the card was created.
final class AdaptiveCardView: NSView {
    var cornerRadius: CGFloat = 12 { didSet { needsDisplay = true } }
    var addsDepth = false { didSet { needsDisplay = true } }

    override var wantsUpdateLayer: Bool { true }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
    }

    required init?(coder: NSCoder) { fatalError() }

    override func updateLayer() {
        guard let layer else { return }
        let isDark = effectiveAppearance.bestMatch(from: [.darkAqua, .vibrantDark]) != nil
        layer.cornerRadius = cornerRadius
        layer.backgroundColor = isDark
            ? NSColor(white: 1.0, alpha: 0.075).cgColor
            : NSColor(white: 1.0, alpha: 0.82).cgColor
        layer.borderWidth = 0.5
        layer.borderColor = isDark
            ? NSColor.white.withAlphaComponent(0.13).cgColor
            : NSColor.black.withAlphaComponent(0.10).cgColor
        layer.shadowColor = NSColor.black.cgColor
        layer.shadowOpacity = addsDepth ? (isDark ? 0.22 : 0.10) : 0
        layer.shadowRadius = addsDepth ? 5 : 0
        layer.shadowOffset = NSSize(width: 0, height: -1)
        layer.masksToBounds = false
    }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        needsDisplay = true
    }
}

class FlippedView: NSView { override var isFlipped: Bool { true } }

/// Appearance-aware semi-transparent veil layered between the Liquid Glass
/// blur and the popover content. Liquid Glass is beautiful but against
/// bright or saturated wallpapers `.labelColor` (near-black in light mode
/// / near-white in dark mode) loses contrast. This scrim nudges the
/// backdrop back toward the conventional popover luminance — you still
/// see the blurred wallpaper peek through, but text is unambiguously
/// legible in both appearances. Apple's own popovers in macOS Tahoe do
/// the same: the "Liquid Glass" look is a translucent panel, not a raw
/// blur, precisely because a raw blur sacrifices readability.
final class GlassContrastScrim: NSView {
    override var wantsUpdateLayer: Bool { true }
    override init(frame: NSRect) {
        super.init(frame: frame)
        wantsLayer = true
    }
    required init?(coder: NSCoder) { fatalError() }
    override func updateLayer() {
        let isDark = effectiveAppearance.bestMatch(from: [.darkAqua, .vibrantDark]) != nil
        // Alphas tuned against a range of wallpapers:
        //   • Light: white veil at 0.55 keeps the sheet clearly "white-ish"
        //     so labelColor (dark) and secondaryLabelColor (mid-grey) stay
        //     readable. Any lower and secondary/tertiary text starts to
        //     vanish over bright photos.
        //   • Dark: black veil at 0.48 keeps the sheet clearly "dark-ish"
        //     so labelColor (light) stays readable. Dark wallpapers blur
        //     very bright colours through unless we darken the backdrop.
        layer?.backgroundColor = isDark
            ? NSColor(white: 0.04, alpha: 0.48).cgColor
            : NSColor(white: 1.00, alpha: 0.55).cgColor
    }
    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        needsDisplay = true
    }
    // Translucent decorative view — never intercept mouse events.
    override func hitTest(_ point: NSPoint) -> NSView? { nil }
}

/// Appearance-adaptive root panel. When the user picks the "Liquid Glass"
/// material, content is **nested inside** an NSVisualEffectView (not laid
/// on top of one) so that:
///   • semantic colors like `.labelColor` inherit the vibrancy appearance
///     the OS provides to descendants of an active effect view, and
///   • a GlassContrastScrim sits between the blur and the content to
///     guarantee a predictable minimum contrast in both light and dark
///     modes, regardless of what wallpaper the blur is sampling.
final class RootPanelView: FlippedView {
    override var wantsUpdateLayer: Bool { true }

    /// Visual-effect view installed only when Liquid Glass is active.
    /// When present, it owns the entire content subtree.
    private(set) var glassLayer: NSVisualEffectView?

    /// Scrim installed as a child of `glassLayer` (below content).
    private var scrim: GlassContrastScrim?

    /// View callers should use as the content parent. In Liquid Glass
    /// mode this is the visual-effect view; otherwise it's `self`. Using
    /// this container for ALL content (main, picker, settings) keeps the
    /// glass aesthetic consistent across the app's screens.
    var contentContainer: NSView { glassLayer ?? self }

    override init(frame: NSRect) {
        super.init(frame: frame)
        wantsLayer = true
        applyMaterial()
    }
    required init?(coder: NSCoder) { fatalError() }

    /// Install or tear down the Liquid Glass layer. Safe to call after
    /// content has been added — existing content is reparented between
    /// the two containers so the material switch doesn't require a full
    /// popover rebuild (though `applyThemeChange()` still rebuilds to
    /// refresh color-dependent views elsewhere).
    func applyMaterial() {
        if isGlassMaterial() {
            if glassLayer == nil {
                let v = NSVisualEffectView(frame: bounds)
                // `.popover` is Apple's recommended material for popover
                // surfaces; `.behindWindow` lets the desktop blur through
                // even when the app isn't key. `.active` keeps the blur
                // running regardless of key-window state (transient
                // popovers often aren't key).
                v.material = .popover
                v.blendingMode = .behindWindow
                v.state = .active
                v.autoresizingMask = [.width, .height]
                // Take ownership of any pre-existing content so it picks
                // up vibrancy and sits above the scrim.
                let movable = subviews
                movable.forEach { $0.removeFromSuperview() }
                addSubview(v)
                let s = GlassContrastScrim(frame: v.bounds)
                s.autoresizingMask = [.width, .height]
                v.addSubview(s)
                movable.forEach { v.addSubview($0) }
                glassLayer = v
                scrim = s
            }
        } else {
            if let glass = glassLayer {
                // Reparent any content back to self, drop scrim + glass.
                let moveable = glass.subviews.filter { $0 !== scrim }
                moveable.forEach { child in
                    child.removeFromSuperview()
                    addSubview(child)
                }
                scrim?.removeFromSuperview()
                glass.removeFromSuperview()
            }
            glassLayer = nil
            scrim = nil
        }
        needsDisplay = true
    }

    override func updateLayer() {
        if isGlassMaterial() {
            // The visual-effect view does the painting; the hosting
            // layer must be clear so we don't cover the blur.
            layer?.backgroundColor = NSColor.clear.cgColor
        } else {
            let isDark = effectiveAppearance.bestMatch(from: [.darkAqua, .vibrantDark]) != nil
            layer?.backgroundColor = isDark
                ? NSColor(calibratedWhite: 0.13, alpha: 1.0).cgColor
                : NSColor(calibratedWhite: 0.97, alpha: 1.0).cgColor
        }
    }
    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        needsDisplay = true
    }
}

// ============================================================================
// MARK: Localization (i18n) — JSON-backed, 10 languages, Cairo font for Arabic
// ============================================================================

struct Language {
    let code: String
    let nativeName: String
    let isRTL: Bool
}

/// 10 supported languages. `nativeName` is shown in the picker.
let kSupportedLanguages: [Language] = [
    Language(code: "en", nativeName: "English",        isRTL: false),
    Language(code: "fr", nativeName: "Français",       isRTL: false),
    Language(code: "es", nativeName: "Español",        isRTL: false),
    Language(code: "ar", nativeName: "العربية",        isRTL: true),
    Language(code: "zh", nativeName: "中文",           isRTL: false),
    Language(code: "hi", nativeName: "हिन्दी",          isRTL: false),
    Language(code: "bn", nativeName: "বাংলা",         isRTL: false),
    Language(code: "ru", nativeName: "Русский",        isRTL: false),
    Language(code: "pt", nativeName: "Português",      isRTL: false),
    Language(code: "ur", nativeName: "اردو",           isRTL: true),
]

final class Localizer {
    static let shared = Localizer()

    /// All translations keyed by language code, loaded from translations.json
    /// in the app bundle Resources folder.
    private var dicts: [String: [String: String]] = [:]

    /// Currently-selected language. Defaults to English.
    private(set) var current: Language = kSupportedLanguages[0]

    /// Called when the user picks a new language (so we can rebuild the UI).
    var onChange: (() -> Void)?

    private init() { load() }

    func load() {
        if let url = Bundle.main.url(forResource: "translations", withExtension: "json"),
           let data = try? Data(contentsOf: url),
           let obj  = try? JSONSerialization.jsonObject(with: data) as? [String: [String: String]] {
            dicts = obj
        }
        let code = UserDefaults.standard.string(forKey: kLanguageKey) ?? "en"
        current = kSupportedLanguages.first(where: { $0.code == code }) ?? kSupportedLanguages[0]
    }

    func setLanguage(_ code: String) {
        guard let l = kSupportedLanguages.first(where: { $0.code == code }) else { return }
        current = l
        UserDefaults.standard.set(code, forKey: kLanguageKey)
        onChange?()
    }

    /// Translate a key using the current language; falls back to English, then to the key.
    func t(_ key: String) -> String {
        let value: String
        if let s = dicts[current.code]?[key], !s.isEmpty {
            value = s
        } else if let s = dicts["en"]?[key], !s.isEmpty {
            value = s
        } else {
            value = key
        }
        return applyingArabicDigitPreference(value, languageCode: current.code)
    }

    var isRTL: Bool    { current.isRTL }
    var isArabic: Bool { current.code == "ar" }

    /// Cairo font for Arabic, system font for everything else.
    /// The font is shipped as a single variable TTF (the static per-weight
    /// files were removed from Google's font repo), so we ask NSFontManager
    /// to synthesise each requested weight from the variable axis.
    func font(size: CGFloat, weight: NSFont.Weight = .regular) -> NSFont {
        if isArabic {
            // NSFontManager's weight scale is 1–15 where 5 = regular, 9 = bold.
            let wInt: Int
            switch weight {
            case .ultraLight:           wInt = 2
            case .thin:                 wInt = 3
            case .light:                wInt = 4
            case .regular:              wInt = 5
            case .medium:               wInt = 6
            case .semibold:             wInt = 8
            case .bold:                 wInt = 9
            case .heavy:                wInt = 10
            case .black:                wInt = 12
            default:                    wInt = 5
            }
            let traits: NSFontTraitMask = (weight >= .semibold) ? .boldFontMask : []
            if let f = NSFontManager.shared.font(withFamily: "Cairo",
                                                 traits: traits,
                                                 weight: wInt,
                                                 size: size) {
                return f
            }
            // Last-ditch: any registered Cairo at all.
            if let f = NSFont(name: "Cairo", size: size) { return f }
        }
        return NSFont.systemFont(ofSize: size, weight: weight)
    }

    /// Leading alignment: .left LTR, .right RTL. Use for body text that should read
    /// "outward from the binding" in each script.
    var leadingAlignment:  NSTextAlignment { isRTL ? .right : .left  }
    var trailingAlignment: NSTextAlignment { isRTL ? .left  : .right }
}

/// Cairo's typographic line box is substantially taller than San Francisco's
/// at the same point size. Frame-based AppKit labels must honor the real font
/// metrics or Arabic ascenders/descenders are visibly sliced off.
func localizedTextHeight(_ text: String, font: NSFont, width: CGFloat,
                         maximumLines: Int = 1) -> CGFloat {
    let lineHeight = ceil(font.ascender - font.descender + font.leading)
    guard Localizer.shared.isArabic else { return lineHeight }
    let paragraph = NSMutableParagraphStyle()
    paragraph.lineBreakMode = maximumLines > 1 ? .byWordWrapping : .byTruncatingTail
    paragraph.baseWritingDirection = .rightToLeft
    let measured = (text as NSString).boundingRect(
        with: NSSize(width: max(1, width), height: .greatestFiniteMagnitude),
        options: [.usesLineFragmentOrigin, .usesFontLeading],
        attributes: [.font: font, .paragraphStyle: paragraph])
    let maximumHeight = lineHeight * CGFloat(max(1, maximumLines))
    return min(maximumHeight, max(lineHeight, ceil(measured.height))) + 3
}

func localizedTextFrame(_ frame: NSRect, text: String, font: NSFont,
                        maximumLines: Int = 1) -> NSRect {
    guard Localizer.shared.isArabic else { return frame }
    let required = localizedTextHeight(text, font: font, width: frame.width,
                                       maximumLines: maximumLines)
    guard required > frame.height else { return frame }
    return NSRect(x: frame.minX, y: frame.midY - required / 2,
                  width: frame.width, height: required)
}

func fitLocalizedLabel(_ label: NSTextField, maximumLines: Int = 1) {
    guard let font = label.font else { return }
    label.frame = localizedTextFrame(label.frame, text: label.stringValue,
                                     font: font, maximumLines: maximumLines)
    label.cell?.truncatesLastVisibleLine = false
    if maximumLines > 1 {
        label.cell?.wraps = true
        label.maximumNumberOfLines = maximumLines
    }
}

/// Convenience global: `t("col.prayer")`.
func t(_ key: String) -> String { Localizer.shared.t(key) }

/// Localized copy for the compact reader and the Nawafil dashboard. Keeping
/// these additions in source lets an upgraded build expose the new surfaces
/// in every language immediately, while the larger JSON catalog remains the
/// source for all existing app copy.
private let featureTranslations: [String: [String: String]] = [
    "en": [
        "full.open_more": "More controls…", "full.nawafil": "Nawafil prayers",
        "full.rakahs": "Rak‘ahs", "full.window": "Time window", "full.best": "Best time",
        "full.guidance": "Calculated from today’s mosque times. Treat these windows as guidance and follow local scholarly advice.",
        "nawafil.rawatib": "Sunnah Rawatib", "nawafil.rawatib.count": "12 total",
        "nawafil.rawatib.window": "2 before Fajr · 4 before and 2 after Dhuhr · 2 after Maghrib · 2 after Isha",
        "nawafil.rawatib.best": "Close to their obligatory prayers",
        "nawafil.duha": "Duha", "nawafil.duha.count": "2–8",
        "nawafil.duha.best": "Later morning, after the sun’s heat is felt",
        "nawafil.qiyam": "Night prayer", "nawafil.qiyam.count": "2 at a time",
        "nawafil.qiyam.best": "Final third of the night",
        "nawafil.witr": "Witr", "nawafil.witr.count": "Odd number, minimum 1",
        "nawafil.witr.best": "The last prayer of the night",
        "popup.adhkar.empty": "This collection has no adhkar yet.",
        "popup.text.smaller": "Smaller text", "popup.text.larger": "Larger text",
        "popup.text.automatic": "Automatic text size", "popup.text.expand": "Expand reading area",
        "popup.text.collapse": "Restore controls", "adhkar.after_adhan": "Start after Adhan",
        "adhkar.after_adhan.immediate": "Immediately after Adhan",
        "adhkar.after_adhan.minutes": "%d min after Adhan",
        "full.view.overview": "Overview", "full.view.timeline": "Day timeline",
        "full.next_prayer": "Next prayer", "full.timeline.title": "Prayer rhythm today",
        "settings.general": "General",
        "settings.menu_bar.help": "Choose what appears beside the Salat Time icon in the menu bar.",
        "settings.prayer_modes": "Each prayer",
        "settings.prayer_modes.help": "Choose whether each prayer plays the Adhan, shows only a notification, or stays quiet.",
        "adhan.mode.off": "Off", "adhan.mode.notify": "Notification only",
        "adhan.mode.play": "Play Adhan",
        "full.view.list": "List", "full.view.clock": "Clock",
        "full.nawafil.hide": "Hide", "full.nawafil.integrated": "Integrated",
        "full.nawafil.separate": "Separate section", "full.landmarks": "Day landmarks",
        "full.landmark.sunrise": "Sunrise", "full.landmark.sunset": "Sunset",
        "full.landmark.friday": "Friday prayers", "full.sunset": "Sunset",
        "full.sunset.maghrib_fallback": "Maghrib fallback when no separate time is published",
        "full.clock.accessibility": "Live prayer clock",
        "full.clock.am_outer": "AM · outer ring    PM · inner ring",
        "settings.numerals": "Arabic-interface numerals",
        "settings.numerals.western": "Arabic numerals",
        "settings.numerals.indic": "Arabic-Indic numerals"
    ],
    "fr": [
        "full.open_more": "Plus de contrôles…", "full.nawafil": "Prières surérogatoires",
        "full.rakahs": "Rak‘āt", "full.window": "Plage horaire", "full.best": "Meilleur moment",
        "full.guidance": "Calculé selon les horaires de la mosquée aujourd’hui. Ces plages sont indicatives ; suivez les conseils religieux locaux.",
        "nawafil.rawatib": "Sunan Rawātib", "nawafil.rawatib.count": "12 au total",
        "nawafil.rawatib.window": "2 avant Fajr · 4 avant et 2 après Dhuhr · 2 après Maghrib · 2 après Isha",
        "nawafil.rawatib.best": "Au plus près des prières obligatoires",
        "nawafil.duha": "Duha", "nawafil.duha.count": "2 à 8",
        "nawafil.duha.best": "En fin de matinée, lorsque la chaleur du soleil se fait sentir",
        "nawafil.qiyam": "Prière de nuit", "nawafil.qiyam.count": "2 par 2",
        "nawafil.qiyam.best": "Dernier tiers de la nuit",
        "nawafil.witr": "Witr", "nawafil.witr.count": "Nombre impair, minimum 1",
        "nawafil.witr.best": "La dernière prière de la nuit",
        "popup.adhkar.empty": "Cette collection ne contient encore aucun adhkār.",
        "popup.text.smaller": "Réduire le texte", "popup.text.larger": "Agrandir le texte",
        "popup.text.automatic": "Taille automatique", "popup.text.expand": "Agrandir la zone de lecture",
        "popup.text.collapse": "Rétablir les contrôles", "adhkar.after_adhan": "Commencer après l’Adhan",
        "adhkar.after_adhan.immediate": "Juste après l’Adhan",
        "adhkar.after_adhan.minutes": "%d min après l’Adhan",
        "full.view.overview": "Vue d’ensemble", "full.view.timeline": "Chronologie du jour",
        "full.next_prayer": "Prochaine prière", "full.timeline.title": "Rythme des prières aujourd’hui",
        "settings.general": "Général",
        "settings.menu_bar.help": "Choisissez ce qui apparaît à côté de l’icône Salat Time dans la barre des menus.",
        "settings.prayer_modes": "Pour chaque prière",
        "settings.prayer_modes.help": "Choisissez si chaque prière diffuse l’Adhan, affiche seulement une notification ou reste silencieuse.",
        "adhan.mode.off": "Désactivé", "adhan.mode.notify": "Notification seule",
        "adhan.mode.play": "Lire l’Adhan",
        "full.view.list": "Liste", "full.view.clock": "Horloge",
        "full.nawafil.hide": "Masquer", "full.nawafil.integrated": "Intégrées",
        "full.nawafil.separate": "Section séparée", "full.landmarks": "Repères du jour",
        "full.landmark.sunrise": "Lever du soleil", "full.landmark.sunset": "Coucher du soleil",
        "full.landmark.friday": "Prières du vendredi", "full.sunset": "Coucher du soleil",
        "full.sunset.maghrib_fallback": "Repli sur Maghrib sans horaire distinct",
        "full.clock.accessibility": "Horloge des prières en direct",
        "full.clock.am_outer": "Matin · anneau extérieur    Après-midi/soir · anneau intérieur",
        "settings.numerals": "Chiffres de l’interface arabe",
        "settings.numerals.western": "Chiffres arabes",
        "settings.numerals.indic": "Chiffres arabo-indiens"
    ],
    "es": [
        "full.open_more": "Más controles…", "full.nawafil": "Oraciones voluntarias",
        "full.rakahs": "Rak‘āt", "full.window": "Franja horaria", "full.best": "Mejor momento",
        "full.guidance": "Calculado con los horarios de la mezquita de hoy. Usa estas franjas como guía y sigue el consejo religioso local.",
        "nawafil.rawatib": "Sunan Rawātib", "nawafil.rawatib.count": "12 en total",
        "nawafil.rawatib.window": "2 antes del Fajr · 4 antes y 2 después del Dhuhr · 2 después del Maghrib · 2 después del Isha",
        "nawafil.rawatib.best": "Cerca de sus oraciones obligatorias",
        "nawafil.duha": "Duha", "nawafil.duha.count": "2–8",
        "nawafil.duha.best": "A media mañana, cuando se siente el calor del sol",
        "nawafil.qiyam": "Oración nocturna", "nawafil.qiyam.count": "De 2 en 2",
        "nawafil.qiyam.best": "Último tercio de la noche",
        "nawafil.witr": "Witr", "nawafil.witr.count": "Número impar, mínimo 1",
        "nawafil.witr.best": "La última oración de la noche",
        "popup.adhkar.empty": "Esta colección todavía no contiene adhkār.",
        "popup.text.smaller": "Texto más pequeño", "popup.text.larger": "Texto más grande",
        "popup.text.automatic": "Tamaño automático", "popup.text.expand": "Ampliar área de lectura",
        "popup.text.collapse": "Restaurar controles", "adhkar.after_adhan": "Comenzar después del Adhan",
        "adhkar.after_adhan.immediate": "Inmediatamente después del Adhan",
        "adhkar.after_adhan.minutes": "%d min después del Adhan",
        "full.view.overview": "Resumen", "full.view.timeline": "Cronología del día",
        "full.next_prayer": "Próxima oración", "full.timeline.title": "Ritmo de oración de hoy",
        "settings.general": "General",
        "settings.menu_bar.help": "Elige qué aparece junto al icono de Salat Time en la barra de menús.",
        "settings.prayer_modes": "Cada oración",
        "settings.prayer_modes.help": "Elige si cada oración reproduce el Adhan, muestra solo una notificación o permanece en silencio.",
        "adhan.mode.off": "Desactivado", "adhan.mode.notify": "Solo notificación",
        "adhan.mode.play": "Reproducir Adhan",
        "full.view.list": "Lista", "full.view.clock": "Reloj",
        "full.nawafil.hide": "Ocultar", "full.nawafil.integrated": "Integradas",
        "full.nawafil.separate": "Sección separada", "full.landmarks": "Referencias del día",
        "full.landmark.sunrise": "Amanecer", "full.landmark.sunset": "Puesta de sol",
        "full.landmark.friday": "Oraciones del viernes", "full.sunset": "Puesta de sol",
        "full.sunset.maghrib_fallback": "Usa Maghrib si no hay hora propia",
        "full.clock.accessibility": "Reloj de oración en directo",
        "full.clock.am_outer": "AM · anillo exterior    PM · anillo interior",
        "settings.numerals": "Números de la interfaz árabe",
        "settings.numerals.western": "Números arábigos",
        "settings.numerals.indic": "Números arábigo-índicos"
    ],
    "ar": [
        "full.open_more": "مزيد من التحكم…", "full.nawafil": "صلوات النوافل",
        "full.rakahs": "الركعات", "full.window": "وقت الصلاة", "full.best": "أفضل وقت",
        "full.guidance": "محسوب وفق مواقيت مسجدك اليوم. هذه الأوقات إرشادية، فاتبع توجيه أهل العلم في بلدك.",
        "nawafil.rawatib": "السنن الرواتب", "nawafil.rawatib.count": "١٢ ركعة",
        "nawafil.rawatib.window": "٢ قبل الفجر · ٤ قبل الظهر و٢ بعده · ٢ بعد المغرب · ٢ بعد العشاء",
        "nawafil.rawatib.best": "قريبًا من الصلوات المفروضة",
        "nawafil.duha": "صلاة الضحى", "nawafil.duha.count": "٢–٨ ركعات",
        "nawafil.duha.best": "بعد ارتفاع الشمس واشتداد حرها",
        "nawafil.qiyam": "قيام الليل", "nawafil.qiyam.count": "ركعتان ركعتان",
        "nawafil.qiyam.best": "الثلث الأخير من الليل",
        "nawafil.witr": "الوتر", "nawafil.witr.count": "عدد فردي، أقله ركعة",
        "nawafil.witr.best": "آخر صلاة الليل",
        "popup.adhkar.empty": "لا تحتوي هذه المجموعة على أذكار بعد.",
        "popup.text.smaller": "تصغير النص", "popup.text.larger": "تكبير النص",
        "popup.text.automatic": "حجم تلقائي", "popup.text.expand": "توسيع مساحة القراءة",
        "popup.text.collapse": "إظهار عناصر التحكم", "adhkar.after_adhan": "البدء بعد الأذان",
        "adhkar.after_adhan.immediate": "مباشرة بعد الأذان",
        "adhkar.after_adhan.minutes": "بعد الأذان بـ %d دقائق",
        "full.view.overview": "نظرة عامة", "full.view.timeline": "الخط الزمني لليوم",
        "full.next_prayer": "الصلاة القادمة", "full.timeline.title": "نسق الصلوات اليوم",
        "settings.general": "عام",
        "settings.menu_bar.help": "اختر ما يظهر بجانب أيقونة Salat Time في شريط القائمة.",
        "settings.prayer_modes": "إعداد كل صلاة",
        "settings.prayer_modes.help": "اختر لكل صلاة تشغيل الأذان أو عرض إشعار فقط أو البقاء صامتة.",
        "adhan.mode.off": "إيقاف", "adhan.mode.notify": "إشعار فقط",
        "adhan.mode.play": "تشغيل الأذان",
        "full.view.list": "قائمة", "full.view.clock": "ساعة",
        "full.nawafil.hide": "إخفاء", "full.nawafil.integrated": "مدمجة",
        "full.nawafil.separate": "قسم منفصل", "full.landmarks": "معالم اليوم",
        "full.landmark.sunrise": "شروق الشمس", "full.landmark.sunset": "غروب الشمس",
        "full.landmark.friday": "صلوات الجمعة", "full.sunset": "الغروب",
        "full.sunset.maghrib_fallback": "وقت المغرب عند غياب وقت مستقل",
        "full.clock.accessibility": "ساعة مواقيت الصلاة الحية",
        "full.clock.am_outer": "صباحًا · الحلقة الخارجية    مساءً · الحلقة الداخلية",
        "settings.numerals": "أرقام الواجهة العربية",
        "settings.numerals.western": "الأرقام العربية",
        "settings.numerals.indic": "الأرقام الهندية"
    ],
    "zh": [
        "full.open_more": "更多控制…", "full.nawafil": "副功拜",
        "full.rakahs": "拜数", "full.window": "时间范围", "full.best": "最佳时间",
        "full.guidance": "根据今日清真寺礼拜时间计算，仅供参考；请遵循当地学者的指导。",
        "nawafil.rawatib": "常行圣行拜", "nawafil.rawatib.count": "共12拜",
        "nawafil.rawatib.window": "晨礼前2拜 · 晌礼前4拜、后2拜 · 昏礼后2拜 · 宵礼后2拜",
        "nawafil.rawatib.best": "靠近相应的主命拜",
        "nawafil.duha": "杜哈拜", "nawafil.duha.count": "2–8拜",
        "nawafil.duha.best": "上午较晚、太阳已有热度时",
        "nawafil.qiyam": "夜间拜", "nawafil.qiyam.count": "每次2拜",
        "nawafil.qiyam.best": "夜晚最后三分之一",
        "nawafil.witr": "奇数拜", "nawafil.witr.count": "奇数，至少1拜",
        "nawafil.witr.best": "作为夜间最后的礼拜",
        "popup.adhkar.empty": "此合集中还没有赞词。",
        "popup.text.smaller": "缩小文字", "popup.text.larger": "放大文字",
        "popup.text.automatic": "自动文字大小", "popup.text.expand": "扩大阅读区域",
        "popup.text.collapse": "恢复控制", "adhkar.after_adhan": "宣礼后开始",
        "adhkar.after_adhan.immediate": "宣礼结束后立即开始",
        "adhkar.after_adhan.minutes": "宣礼后 %d 分钟",
        "full.view.overview": "概览", "full.view.timeline": "全天时间线",
        "full.next_prayer": "下一次礼拜", "full.timeline.title": "今日礼拜节奏",
        "settings.general": "常规",
        "settings.menu_bar.help": "选择菜单栏中 Salat Time 图标旁显示的内容。",
        "settings.prayer_modes": "各礼拜设置",
        "settings.prayer_modes.help": "选择每次礼拜播放宣礼、仅显示通知或保持静音。",
        "adhan.mode.off": "关闭", "adhan.mode.notify": "仅通知",
        "adhan.mode.play": "播放宣礼",
        "full.view.list": "列表", "full.view.clock": "时钟",
        "full.nawafil.hide": "隐藏", "full.nawafil.integrated": "融入日程",
        "full.nawafil.separate": "单独分区", "full.landmarks": "全天参考时间",
        "full.landmark.sunrise": "日出", "full.landmark.sunset": "日落",
        "full.landmark.friday": "主麻拜", "full.sunset": "日落",
        "full.sunset.maghrib_fallback": "无独立时间时使用昏礼时间",
        "full.clock.accessibility": "实时礼拜时钟",
        "full.clock.am_outer": "上午 · 外圈    下午及夜间 · 内圈",
        "settings.numerals": "阿拉伯语界面数字",
        "settings.numerals.western": "阿拉伯数字",
        "settings.numerals.indic": "阿拉伯-印度数字"
    ],
    "hi": [
        "full.open_more": "और नियंत्रण…", "full.nawafil": "नफ़्ल नमाज़ें",
        "full.rakahs": "रकअत", "full.window": "समय सीमा", "full.best": "बेहतर समय",
        "full.guidance": "आज की मस्जिद के समयों से गणना की गई है। इसे मार्गदर्शन मानें और स्थानीय आलिम की सलाह का पालन करें।",
        "nawafil.rawatib": "सुन्नत रावतिब", "nawafil.rawatib.count": "कुल 12",
        "nawafil.rawatib.window": "फ़ज्र से पहले 2 · ज़ुहर से पहले 4 और बाद में 2 · मग़रिब के बाद 2 · इशा के बाद 2",
        "nawafil.rawatib.best": "संबंधित फ़र्ज़ नमाज़ के पास",
        "nawafil.duha": "दुहा", "nawafil.duha.count": "2–8",
        "nawafil.duha.best": "दिन चढ़ने पर, जब सूरज की गर्मी महसूस हो",
        "nawafil.qiyam": "रात की नमाज़", "nawafil.qiyam.count": "2-2 रकअत",
        "nawafil.qiyam.best": "रात का आख़िरी तिहाई",
        "nawafil.witr": "वित्र", "nawafil.witr.count": "विषम संख्या, कम से कम 1",
        "nawafil.witr.best": "रात की आख़िरी नमाज़",
        "popup.adhkar.empty": "इस संग्रह में अभी कोई अज़्कार नहीं है।",
        "popup.text.smaller": "छोटा पाठ", "popup.text.larger": "बड़ा पाठ",
        "popup.text.automatic": "स्वचालित पाठ आकार", "popup.text.expand": "पढ़ने का क्षेत्र बढ़ाएँ",
        "popup.text.collapse": "नियंत्रण वापस लाएँ", "adhkar.after_adhan": "अज़ान के बाद शुरू करें",
        "adhkar.after_adhan.immediate": "अज़ान के तुरंत बाद",
        "adhkar.after_adhan.minutes": "अज़ान के %d मिनट बाद",
        "full.view.overview": "अवलोकन", "full.view.timeline": "दिन की समयरेखा",
        "full.next_prayer": "अगली नमाज़", "full.timeline.title": "आज की नमाज़ का क्रम",
        "settings.general": "सामान्य",
        "settings.menu_bar.help": "मेनू बार में Salat Time आइकन के पास क्या दिखे, चुनें।",
        "settings.prayer_modes": "हर नमाज़",
        "settings.prayer_modes.help": "हर नमाज़ के लिए अज़ान, केवल सूचना या मौन चुनें।",
        "adhan.mode.off": "बंद", "adhan.mode.notify": "केवल सूचना",
        "adhan.mode.play": "अज़ान चलाएँ",
        "full.view.list": "सूची", "full.view.clock": "घड़ी",
        "full.nawafil.hide": "छिपाएँ", "full.nawafil.integrated": "साथ में",
        "full.nawafil.separate": "अलग भाग", "full.landmarks": "दिन के प्रमुख समय",
        "full.landmark.sunrise": "सूर्योदय", "full.landmark.sunset": "सूर्यास्त",
        "full.landmark.friday": "जुमे की नमाज़", "full.sunset": "सूर्यास्त",
        "full.sunset.maghrib_fallback": "अलग समय न हो तो मग़रिब का समय",
        "full.clock.accessibility": "सीधी नमाज़ घड़ी",
        "full.clock.am_outer": "सुबह · बाहरी घेरा    दोपहर/रात · भीतरी घेरा",
        "settings.numerals": "अरबी इंटरफ़ेस के अंक",
        "settings.numerals.western": "अरबी अंक",
        "settings.numerals.indic": "अरबी-इंडिक अंक"
    ],
    "bn": [
        "full.open_more": "আরও নিয়ন্ত্রণ…", "full.nawafil": "নফল নামাজ",
        "full.rakahs": "রাকাত", "full.window": "সময়সীমা", "full.best": "উত্তম সময়",
        "full.guidance": "আজকের মসজিদের সময় থেকে হিসাব করা। এগুলো নির্দেশনা হিসেবে নিন এবং স্থানীয় আলেমের পরামর্শ অনুসরণ করুন।",
        "nawafil.rawatib": "সুন্নাতে রাওয়াতিব", "nawafil.rawatib.count": "মোট ১২",
        "nawafil.rawatib.window": "ফজরের আগে ২ · যোহরের আগে ৪ ও পরে ২ · মাগরিবের পরে ২ · ইশার পরে ২",
        "nawafil.rawatib.best": "সংশ্লিষ্ট ফরজ নামাজের কাছাকাছি",
        "nawafil.duha": "দুহা", "nawafil.duha.count": "২–৮",
        "nawafil.duha.best": "বেলা বাড়লে, সূর্যের তাপ অনুভূত হওয়ার পর",
        "nawafil.qiyam": "রাতের নামাজ", "nawafil.qiyam.count": "২ রাকাত করে",
        "nawafil.qiyam.best": "রাতের শেষ তৃতীয়াংশ",
        "nawafil.witr": "বিতর", "nawafil.witr.count": "বিজোড়, কমপক্ষে ১",
        "nawafil.witr.best": "রাতের শেষ নামাজ",
        "popup.adhkar.empty": "এই সংগ্রহে এখনও কোনো আজকার নেই।",
        "popup.text.smaller": "ছোট লেখা", "popup.text.larger": "বড় লেখা",
        "popup.text.automatic": "স্বয়ংক্রিয় লেখার আকার", "popup.text.expand": "পাঠের স্থান বড় করুন",
        "popup.text.collapse": "নিয়ন্ত্রণ ফিরিয়ে আনুন", "adhkar.after_adhan": "আজানের পরে শুরু",
        "adhkar.after_adhan.immediate": "আজানের পরপরই",
        "adhkar.after_adhan.minutes": "আজানের %d মিনিট পরে",
        "full.view.overview": "সারসংক্ষেপ", "full.view.timeline": "দিনের সময়রেখা",
        "full.next_prayer": "পরবর্তী নামাজ", "full.timeline.title": "আজকের নামাজের ছন্দ",
        "settings.general": "সাধারণ",
        "settings.menu_bar.help": "মেনু বারে Salat Time আইকনের পাশে কী দেখাবে তা বেছে নিন।",
        "settings.prayer_modes": "প্রতি নামাজ",
        "settings.prayer_modes.help": "প্রতি নামাজে আজান, শুধু বিজ্ঞপ্তি অথবা নীরবতা বেছে নিন।",
        "adhan.mode.off": "বন্ধ", "adhan.mode.notify": "শুধু বিজ্ঞপ্তি",
        "adhan.mode.play": "আজান চালান",
        "full.view.list": "তালিকা", "full.view.clock": "ঘড়ি",
        "full.nawafil.hide": "লুকান", "full.nawafil.integrated": "একসাথে",
        "full.nawafil.separate": "আলাদা অংশ", "full.landmarks": "দিনের প্রধান সময়",
        "full.landmark.sunrise": "সূর্যোদয়", "full.landmark.sunset": "সূর্যাস্ত",
        "full.landmark.friday": "জুমার নামাজ", "full.sunset": "সূর্যাস্ত",
        "full.sunset.maghrib_fallback": "আলাদা সময় না থাকলে মাগরিবের সময়",
        "full.clock.accessibility": "সরাসরি নামাজের ঘড়ি",
        "full.clock.am_outer": "সকাল · বাইরের বলয়    বিকেল/রাত · ভেতরের বলয়",
        "settings.numerals": "আরবি ইন্টারফেসের সংখ্যা",
        "settings.numerals.western": "আরবি সংখ্যা",
        "settings.numerals.indic": "আরবি-ইন্ডিক সংখ্যা"
    ],
    "ru": [
        "full.open_more": "Больше настроек…", "full.nawafil": "Дополнительные молитвы",
        "full.rakahs": "Ракааты", "full.window": "Период", "full.best": "Лучшее время",
        "full.guidance": "Рассчитано по сегодняшнему расписанию мечети. Используйте как ориентир и следуйте местным религиозным рекомендациям.",
        "nawafil.rawatib": "Сунна-рауатиб", "nawafil.rawatib.count": "Всего 12",
        "nawafil.rawatib.window": "2 до Фаджра · 4 до и 2 после Зухра · 2 после Магриба · 2 после Иша",
        "nawafil.rawatib.best": "Рядом с соответствующими обязательными молитвами",
        "nawafil.duha": "Духа", "nawafil.duha.count": "2–8",
        "nawafil.duha.best": "Позднее утро, когда ощущается тепло солнца",
        "nawafil.qiyam": "Ночная молитва", "nawafil.qiyam.count": "По 2 ракаата",
        "nawafil.qiyam.best": "Последняя треть ночи",
        "nawafil.witr": "Витр", "nawafil.witr.count": "Нечётное число, минимум 1",
        "nawafil.witr.best": "Последняя молитва ночи",
        "popup.adhkar.empty": "В этой коллекции пока нет азкаров.",
        "popup.text.smaller": "Уменьшить текст", "popup.text.larger": "Увеличить текст",
        "popup.text.automatic": "Автоматический размер", "popup.text.expand": "Расширить область чтения",
        "popup.text.collapse": "Вернуть элементы управления", "adhkar.after_adhan": "Начать после азана",
        "adhkar.after_adhan.immediate": "Сразу после азана",
        "adhkar.after_adhan.minutes": "Через %d мин после азана",
        "full.view.overview": "Обзор", "full.view.timeline": "Распорядок дня",
        "full.next_prayer": "Следующая молитва", "full.timeline.title": "Ритм молитв сегодня",
        "settings.general": "Основные",
        "settings.menu_bar.help": "Выберите, что показывать рядом со значком Salat Time в строке меню.",
        "settings.prayer_modes": "Для каждой молитвы",
        "settings.prayer_modes.help": "Для каждой молитвы выберите азан, только уведомление или тишину.",
        "adhan.mode.off": "Выкл.", "adhan.mode.notify": "Только уведомление",
        "adhan.mode.play": "Воспроизводить азан",
        "full.view.list": "Список", "full.view.clock": "Часы",
        "full.nawafil.hide": "Скрыть", "full.nawafil.integrated": "В расписании",
        "full.nawafil.separate": "Отдельный раздел", "full.landmarks": "Ориентиры дня",
        "full.landmark.sunrise": "Восход", "full.landmark.sunset": "Закат",
        "full.landmark.friday": "Пятничные молитвы", "full.sunset": "Закат",
        "full.sunset.maghrib_fallback": "Магриб, если нет отдельного времени",
        "full.clock.accessibility": "Живые часы молитв",
        "full.clock.am_outer": "До полудня · внешнее кольцо    После полудня · внутреннее",
        "settings.numerals": "Цифры арабского интерфейса",
        "settings.numerals.western": "Арабские цифры",
        "settings.numerals.indic": "Арабо-индийские цифры"
    ],
    "pt": [
        "full.open_more": "Mais controlos…", "full.nawafil": "Orações voluntárias",
        "full.rakahs": "Rak‘āt", "full.window": "Janela de tempo", "full.best": "Melhor momento",
        "full.guidance": "Calculado com os horários da mesquita de hoje. Use como orientação e siga o aconselhamento religioso local.",
        "nawafil.rawatib": "Sunan Rawātib", "nawafil.rawatib.count": "12 no total",
        "nawafil.rawatib.window": "2 antes do Fajr · 4 antes e 2 depois do Dhuhr · 2 depois do Maghrib · 2 depois do Isha",
        "nawafil.rawatib.best": "Perto das respetivas orações obrigatórias",
        "nawafil.duha": "Duha", "nawafil.duha.count": "2–8",
        "nawafil.duha.best": "Mais tarde de manhã, quando se sente o calor do sol",
        "nawafil.qiyam": "Oração noturna", "nawafil.qiyam.count": "2 de cada vez",
        "nawafil.qiyam.best": "Último terço da noite",
        "nawafil.witr": "Witr", "nawafil.witr.count": "Número ímpar, mínimo 1",
        "nawafil.witr.best": "A última oração da noite",
        "popup.adhkar.empty": "Esta coleção ainda não contém adhkār.",
        "popup.text.smaller": "Texto menor", "popup.text.larger": "Texto maior",
        "popup.text.automatic": "Tamanho automático", "popup.text.expand": "Ampliar área de leitura",
        "popup.text.collapse": "Restaurar controlos", "adhkar.after_adhan": "Começar após o Adhan",
        "adhkar.after_adhan.immediate": "Imediatamente após o Adhan",
        "adhkar.after_adhan.minutes": "%d min após o Adhan",
        "full.view.overview": "Visão geral", "full.view.timeline": "Cronologia do dia",
        "full.next_prayer": "Próxima oração", "full.timeline.title": "Ritmo das orações de hoje",
        "settings.general": "Geral",
        "settings.menu_bar.help": "Escolha o que aparece junto ao ícone Salat Time na barra de menus.",
        "settings.prayer_modes": "Cada oração",
        "settings.prayer_modes.help": "Escolha se cada oração reproduz o Adhan, mostra só uma notificação ou fica em silêncio.",
        "adhan.mode.off": "Desativado", "adhan.mode.notify": "Só notificação",
        "adhan.mode.play": "Reproduzir Adhan",
        "full.view.list": "Lista", "full.view.clock": "Relógio",
        "full.nawafil.hide": "Ocultar", "full.nawafil.integrated": "Integradas",
        "full.nawafil.separate": "Secção separada", "full.landmarks": "Marcos do dia",
        "full.landmark.sunrise": "Nascer do sol", "full.landmark.sunset": "Pôr do sol",
        "full.landmark.friday": "Orações de sexta-feira", "full.sunset": "Pôr do sol",
        "full.sunset.maghrib_fallback": "Usa o Maghrib sem horário próprio",
        "full.clock.accessibility": "Relógio de oração em direto",
        "full.clock.am_outer": "Manhã · anel exterior    Tarde/noite · anel interior",
        "settings.numerals": "Algarismos da interface árabe",
        "settings.numerals.western": "Algarismos árabes",
        "settings.numerals.indic": "Algarismos árabe-índicos"
    ],
    "ur": [
        "full.open_more": "مزید کنٹرول…", "full.nawafil": "نفل نمازیں",
        "full.rakahs": "رکعات", "full.window": "وقت کی حد", "full.best": "بہترین وقت",
        "full.guidance": "آج کے مسجد کے اوقات سے حساب کیا گیا ہے۔ اسے رہنمائی سمجھیں اور مقامی علما کی ہدایت پر عمل کریں۔",
        "nawafil.rawatib": "سننِ رواتب", "nawafil.rawatib.count": "کل ۱۲",
        "nawafil.rawatib.window": "فجر سے پہلے ۲ · ظہر سے پہلے ۴ اور بعد میں ۲ · مغرب کے بعد ۲ · عشا کے بعد ۲",
        "nawafil.rawatib.best": "متعلقہ فرض نمازوں کے قریب",
        "nawafil.duha": "چاشت", "nawafil.duha.count": "۲–۸",
        "nawafil.duha.best": "دن چڑھنے پر، جب سورج کی گرمی محسوس ہو",
        "nawafil.qiyam": "قیام اللیل", "nawafil.qiyam.count": "دو دو رکعت",
        "nawafil.qiyam.best": "رات کا آخری تہائی",
        "nawafil.witr": "وتر", "nawafil.witr.count": "طاق عدد، کم از کم ۱",
        "nawafil.witr.best": "رات کی آخری نماز",
        "popup.adhkar.empty": "اس مجموعے میں ابھی کوئی اذکار نہیں ہیں۔",
        "popup.text.smaller": "متن چھوٹا کریں", "popup.text.larger": "متن بڑا کریں",
        "popup.text.automatic": "خودکار متن", "popup.text.expand": "مطالعہ کی جگہ بڑھائیں",
        "popup.text.collapse": "کنٹرول واپس لائیں", "adhkar.after_adhan": "اذان کے بعد شروع کریں",
        "adhkar.after_adhan.immediate": "اذان کے فوراً بعد",
        "adhkar.after_adhan.minutes": "اذان کے %d منٹ بعد",
        "full.view.overview": "جائزہ", "full.view.timeline": "دن کی وقت بندی",
        "full.next_prayer": "اگلی نماز", "full.timeline.title": "آج کی نمازوں کی ترتیب",
        "settings.general": "عمومی",
        "settings.menu_bar.help": "مینو بار میں Salat Time آئیکن کے ساتھ کیا دکھائی دے، منتخب کریں۔",
        "settings.prayer_modes": "ہر نماز",
        "settings.prayer_modes.help": "ہر نماز کے لیے اذان، صرف اطلاع یا خاموشی منتخب کریں۔",
        "adhan.mode.off": "بند", "adhan.mode.notify": "صرف اطلاع",
        "adhan.mode.play": "اذان چلائیں",
        "full.view.list": "فہرست", "full.view.clock": "گھڑی",
        "full.nawafil.hide": "چھپائیں", "full.nawafil.integrated": "ساتھ شامل",
        "full.nawafil.separate": "الگ حصہ", "full.landmarks": "دن کے اہم اوقات",
        "full.landmark.sunrise": "طلوعِ آفتاب", "full.landmark.sunset": "غروبِ آفتاب",
        "full.landmark.friday": "جمعہ کی نمازیں", "full.sunset": "غروبِ آفتاب",
        "full.sunset.maghrib_fallback": "الگ وقت نہ ہو تو مغرب کا وقت",
        "full.clock.accessibility": "براہِ راست نماز گھڑی",
        "full.clock.am_outer": "صبح · بیرونی حلقہ    دوپہر/رات · اندرونی حلقہ",
        "settings.numerals": "عربی انٹرفیس کے ہندسے",
        "settings.numerals.western": "عربی ہندسے",
        "settings.numerals.indic": "عربی-ہندی ہندسے"
    ]
]

/// Qur'an controls use the same ten-language matrix as prayer and Adhkar.
/// Edition names remain bilingual proper names (Hafs · حفص / Warsh · ورش),
/// while every action, source boundary, and error is localized here.
private let quranTranslationKeys = [
    "quran.tab", "main.destinations", "quran.source.kfgqpc", "quran.provenance",
    "quran.official_moroccan", "quran.official_moroccan.help", "quran.forward",
    "quran.search.placeholder", "quran.study.search", "quran.study.tafsir",
    "quran.study.official_source", "quran.bookmarks", "quran.bookmark.add",
    "quran.bookmark.remove", "quran.reader", "quran.tafsir.placeholder",
    "quran.source.kfgqpc.developer", "quran.study.hafs_only",
    "quran.source.foundation", "quran.bookmark.name.help", "quran.bookmark",
    "quran.bookmarks.empty", "quran.provenance.title", "quran.provenance.detail",
    "quran.provenance.open", "quran.unavailable",
]

private let quranTranslationRows: [String: [String]] = [
    "en": [
        "Qur’an", "App destinations", "Bundled King Fahd Complex Mushaf",
        "Source and integrity", "Offline Warsh Mushaf",
        "Use the bundled verified Warsh pages",
        "Next", "Search the Qur’an or enter 2:255", "Search",
        "Word meanings", "Verified local data", "Bookmarks", "Add bookmark",
        "Remove current bookmark", "Offline Mushaf reader",
        "Enter a verse, for example 2:255", "Bundled verse index",
        "Word meanings follow the Hafs reference and are unavailable in Warsh",
        "Muyassar Ghareeb word meanings", "Name this reading place.",
        "Reading bookmark", "No bookmarks yet", "Verified Qur’an sources",
        "The unchanged Hafs and Warsh pages and verse indexes are bundled from the King Fahd Complex. Reading and search are fully offline; bookmarks store only edition and page.",
        "Close", "Verified bundled content is unavailable",
    ],
    "fr": [
        "Coran", "Sections de l’app", "Mushaf intégré du Complexe du roi Fahd",
        "Source et intégrité", "Mushaf Warsh hors ligne",
        "Utiliser les pages Warsh vérifiées intégrées",
        "Suivant", "Rechercher dans le Coran ou saisir 2:255", "Recherche",
        "Sens des mots", "Données locales vérifiées", "Signets", "Ajouter un signet",
        "Supprimer le signet actuel", "Lecteur du Mushaf hors ligne",
        "Saisissez un verset, par exemple 2:255", "Index de versets intégré",
        "Les sens suivent la référence Hafs et ne sont pas disponibles en Warsh",
        "Sens des mots Muyassar Ghareeb", "Nommez cet emplacement de lecture.",
        "Signet de lecture", "Aucun signet", "Sources coraniques vérifiées",
        "Les pages Hafs et Warsh inchangées et leurs index sont intégrés depuis le Complexe du roi Fahd. Lecture et recherche sont hors ligne ; les signets ne gardent que l’édition et la page.",
        "Fermer", "Le contenu intégré vérifié est indisponible",
    ],
    "es": [
        "Corán", "Secciones de la app", "Mushaf integrado del Complejo Rey Fahd",
        "Fuente e integridad", "Mushaf Warsh sin conexión",
        "Usar las páginas Warsh verificadas integradas",
        "Siguiente", "Buscar en el Corán o escribir 2:255", "Buscar",
        "Significados", "Datos locales verificados", "Marcadores", "Añadir marcador",
        "Quitar marcador actual", "Lector Mushaf sin conexión",
        "Escribe una aleya, por ejemplo 2:255", "Índice de aleyas integrado",
        "Los significados siguen la referencia Hafs y no están disponibles en Warsh",
        "Significados Muyassar Ghareeb", "Pon un nombre a este punto de lectura.",
        "Marcador de lectura", "Aún no hay marcadores", "Fuentes coránicas verificadas",
        "Las páginas Hafs y Warsh sin cambios y sus índices se integran desde el Complejo Rey Fahd. Lectura y búsqueda son locales; los marcadores solo guardan edición y página.",
        "Cerrar", "El contenido integrado verificado no está disponible",
    ],
    "ar": [
        "القرآن", "أقسام التطبيق", "مصحف مجمع الملك فهد المضمّن",
        "المصدر وسلامة المحتوى", "مصحف ورش دون اتصال",
        "استخدام صفحات ورش الموثّقة والمضمّنة",
        "التالي", "ابحث في القرآن أو أدخل 2:255", "بحث",
        "معاني الكلمات", "بيانات محلية موثّقة", "العلامات المرجعية", "إضافة علامة",
        "حذف العلامة الحالية", "قارئ المصحف دون اتصال",
        "أدخل آية، مثل 2:255", "فهرس الآيات المضمّن",
        "تتبع المعاني مرجع حفص ولا تتاح في مصحف ورش",
        "معاني ميسّر غريب القرآن", "سمِّ موضع القراءة هذا.",
        "علامة قراءة", "لا توجد علامات بعد", "مصادر قرآن موثّقة",
        "صفحات حفص وورش وفهارس الآيات الموثّقة مضمّنة كما هي من مجمع الملك فهد. القراءة والبحث دون اتصال، وتحفظ العلامات الرواية والصفحة فقط.",
        "إغلاق", "المحتوى المضمّن الموثّق غير متاح",
    ],
    "zh": [
        "古兰经", "应用分区", "内置法赫德国王印刷院穆斯哈夫",
        "来源与完整性", "离线 Warsh 穆斯哈夫",
        "使用内置且已验证的 Warsh 页面",
        "下一页", "搜索古兰经或输入 2:255", "搜索",
        "词义", "已验证的本地数据", "书签", "添加书签",
        "移除当前书签", "离线穆斯哈夫阅读器",
        "输入经文，例如 2:255", "内置经文索引",
        "词义以 Hafs 为参考，在 Warsh 中不可用",
        "Muyassar Ghareeb 词义", "为此阅读位置命名。",
        "阅读书签", "暂无书签", "已验证的古兰经来源",
        "Hafs 与 Warsh 原始页面及经文索引由法赫德国王印刷院内置提供。阅读和搜索完全离线；书签只保存版本和页码。",
        "关闭", "已验证的内置内容不可用",
    ],
    "hi": [
        "क़ुरआन", "ऐप के भाग", "किंग फ़हद कॉम्प्लेक्स का अंतर्निहित मुसहफ़",
        "स्रोत और शुद्धता", "ऑफ़लाइन वार्श मुसहफ़",
        "अंतर्निहित सत्यापित वार्श पृष्ठ उपयोग करें",
        "अगला", "क़ुरआन खोजें या 2:255 लिखें", "खोज",
        "शब्दार्थ", "सत्यापित स्थानीय डेटा", "बुकमार्क", "बुकमार्क जोड़ें",
        "मौजूदा बुकमार्क हटाएँ", "ऑफ़लाइन मुसहफ़ रीडर",
        "आयत लिखें, जैसे 2:255", "अंतर्निहित आयत सूचकांक",
        "शब्दार्थ हफ़्स संदर्भ के हैं और वार्श में उपलब्ध नहीं हैं",
        "मुयस्सर ग़रीब शब्दार्थ", "इस पढ़ने की जगह को नाम दें।",
        "पढ़ने का बुकमार्क", "अभी कोई बुकमार्क नहीं", "सत्यापित क़ुरआन स्रोत",
        "हफ़्स और वार्श के अपरिवर्तित पृष्ठ व सूचकांक किंग फ़हद कॉम्प्लेक्स से अंतर्निहित हैं। पढ़ना और खोज पूरी तरह ऑफ़लाइन हैं; बुकमार्क केवल संस्करण और पृष्ठ रखते हैं।",
        "बंद करें", "सत्यापित अंतर्निहित सामग्री उपलब्ध नहीं है",
    ],
    "bn": [
        "কুরআন", "অ্যাপের বিভাগ", "কিং ফাহদ কমপ্লেক্সের অন্তর্ভুক্ত মুসহাফ",
        "উৎস ও অখণ্ডতা", "অফলাইন ওয়ারশ মুসহাফ",
        "অন্তর্ভুক্ত যাচাইকৃত ওয়ারশ পৃষ্ঠা ব্যবহার করুন",
        "পরের পৃষ্ঠা", "কুরআনে খুঁজুন বা 2:255 লিখুন", "খোঁজ",
        "শব্দার্থ", "যাচাইকৃত স্থানীয় ডেটা", "বুকমার্ক", "বুকমার্ক যোগ করুন",
        "বর্তমান বুকমার্ক মুছুন", "অফলাইন মুসহাফ পাঠক",
        "আয়াত লিখুন, যেমন 2:255", "অন্তর্ভুক্ত আয়াত সূচি",
        "শব্দার্থ হাফস রেফারেন্স অনুসরণ করে এবং ওয়ারশে পাওয়া যায় না",
        "মুয়াসসার গরীব শব্দার্থ", "এই পড়ার স্থানটির নাম দিন।",
        "পড়ার বুকমার্ক", "এখনও কোনো বুকমার্ক নেই", "যাচাইকৃত কুরআনের উৎস",
        "হাফস ও ওয়ারশের অপরিবর্তিত পৃষ্ঠা ও সূচি কিং ফাহদ কমপ্লেক্স থেকে অন্তর্ভুক্ত। পড়া ও খোঁজ সম্পূর্ণ অফলাইন; বুকমার্ক শুধু সংস্করণ ও পৃষ্ঠা রাখে।",
        "বন্ধ করুন", "যাচাইকৃত অন্তর্ভুক্ত বিষয়বস্তু পাওয়া যাচ্ছে না",
    ],
    "ru": [
        "Коран", "Разделы приложения", "Встроенный мусхаф Комплекса короля Фахда",
        "Источник и целостность", "Офлайн-мусхаф Варш",
        "Использовать встроенные проверенные страницы Варш",
        "Далее", "Поиск по Корану или ссылка 2:255", "Поиск",
        "Значения слов", "Проверенные локальные данные", "Закладки", "Добавить закладку",
        "Удалить текущую закладку", "Офлайн-ридер мусхафа",
        "Введите аят, например 2:255", "Встроенный индекс аятов",
        "Значения следуют Хафс и недоступны в Варш",
        "Значения слов Muyassar Ghareeb", "Назовите это место чтения.",
        "Закладка чтения", "Закладок пока нет", "Проверенные источники Корана",
        "Неизменённые страницы Хафс и Варш и индексы встроены из Комплекса короля Фахда. Чтение и поиск полностью офлайн; закладки хранят только издание и страницу.",
        "Закрыть", "Проверенное встроенное содержимое недоступно",
    ],
    "pt": [
        "Alcorão", "Secções da app", "Mushaf integrado do Complexo Rei Fahd",
        "Fonte e integridade", "Mushaf Warsh offline",
        "Usar as páginas Warsh verificadas integradas",
        "Seguinte", "Pesquisar no Alcorão ou introduzir 2:255", "Pesquisa",
        "Significados", "Dados locais verificados", "Marcadores", "Adicionar marcador",
        "Remover marcador atual", "Leitor Mushaf offline",
        "Introduza um versículo, por exemplo 2:255", "Índice de versículos integrado",
        "Os significados seguem a referência Hafs e não estão disponíveis em Warsh",
        "Significados Muyassar Ghareeb", "Dê um nome a este ponto de leitura.",
        "Marcador de leitura", "Ainda não há marcadores", "Fontes do Alcorão verificadas",
        "As páginas Hafs e Warsh inalteradas e os índices estão integrados pelo Complexo Rei Fahd. Leitura e pesquisa são offline; os marcadores guardam apenas edição e página.",
        "Fechar", "O conteúdo integrado verificado está indisponível",
    ],
    "ur": [
        "قرآن", "ایپ کے حصے", "کنگ فہد کمپلیکس کا شامل مصحف",
        "ماخذ اور صحت", "آف لائن ورش مصحف",
        "شامل شدہ تصدیق شدہ ورش صفحات استعمال کریں",
        "اگلا", "قرآن میں تلاش کریں یا 2:255 لکھیں", "تلاش",
        "الفاظ کے معنی", "تصدیق شدہ مقامی ڈیٹا", "بک مارکس", "بک مارک شامل کریں",
        "موجودہ بک مارک ہٹائیں", "آف لائن مصحف قاری",
        "آیت لکھیں، مثلاً 2:255", "شامل شدہ آیات کا اشاریہ",
        "معانی حفص کے حوالے کے مطابق ہیں اور ورش میں دستیاب نہیں",
        "میسر غریب الفاظ کے معنی", "اس مطالعہ کی جگہ کو نام دیں۔",
        "مطالعہ بک مارک", "ابھی کوئی بک مارک نہیں", "تصدیق شدہ قرآنی ماخذ",
        "حفص اور ورش کے اصل صفحات اور اشاریے کنگ فہد کمپلیکس سے شامل ہیں۔ مطالعہ اور تلاش مکمل آف لائن ہیں؛ بک مارکس صرف روایت اور صفحہ محفوظ کرتے ہیں۔",
        "بند کریں", "تصدیق شدہ شامل مواد دستیاب نہیں",
    ],
]

func featureText(_ key: String) -> String {
    let code = Localizer.shared.current.code
    let value: String
    if let index = quranTranslationKeys.firstIndex(of: key),
       let row = quranTranslationRows[code], row.indices.contains(index) {
        value = row[index]
    } else if let index = quranTranslationKeys.firstIndex(of: key),
              let row = quranTranslationRows["en"], row.indices.contains(index) {
        value = row[index]
    } else {
        value = featureTranslations[code]?[key]
            ?? featureTranslations["en"]?[key]
            ?? key
    }
    return applyingArabicDigitPreference(value, languageCode: code)
}

/// Compact offline guidance copy for all ten supported interface languages.
/// English remains a defensive per-field fallback for migrated preferences or
/// future language additions that have not yet supplied a new key.
private let prayerInfoTranslations: [String: [String: String]] = [
    "en": [
        "category.obligatory": "Obligatory prayer",
        "category.nawafil": "Voluntary prayer",
        "info.when": "When", "info.how": "How", "info.why": "Why",
        "info.evidence": "Evidence", "info.open": "Prayer information",
        "obligatory.when.iqama": "Prayer time enters at %@. This mosque’s iqama is %@.",
        "obligatory.when.no_iqama": "Prayer time enters at %@. No iqama is published; pray within its valid time.",
        "obligatory.how": "Pray %@ obligatory rak‘ahs facing the qibla; follow the imam in congregation.",
        "obligatory.why": "One of the five daily obligations, prescribed at appointed times.",
        "rawatib.before.window": "From prayer entry %@ until the published iqama %@.",
        "rawatib.before.marker": "Prayer time enters at %@. Pray before the Fard; no iqama end time is published.",
        "rawatib.after.iqama": "After the obligatory prayer beginning at iqama %@; this is a marker, not a timed window.",
        "rawatib.after.no_iqama": "After the obligatory prayer whose time enters at %@; no iqama is published.",
        "rawatib.before": "Before Fard", "rawatib.after": "After Fard",
        "rawatib.how": "Pray in units of two. Keep the two before Fajr brief.",
        "rawatib.why": "Keeping twelve Rawatib daily is a means to a house in Paradise.",
        "nawafil.rawatib.fajr.count": "2 rak‘ahs",
        "nawafil.rawatib.dhuhr.before.count": "4 rak‘ahs",
        "nawafil.rawatib.after.count": "2 rak‘ahs",
        "duha.when": "Guidance: from about twenty minutes after sunrise (%@) until before Dhuhr (%@); avoid the zenith itself.",
        "duha.how": "Pray at least two rak‘ahs in units of two; eight are also authentically reported.",
        "duha.why": "Two rak‘ahs of Duha fulfill the morning charity due from the body’s joints.",
        "qiyam.when.no_iqama": "After Isha (entry %@) until Fajr %@; no iqama is published.",
        "qiyam.when.iqama": "After the Isha congregation (iqama %@) until Fajr %@.",
        "qiyam.how": "Pray two by two; if dawn is near, conclude with one Witr.",
        "qiyam.why": "The best voluntary prayer after the obligations; the final third of night is especially virtuous.",
        "witr.how": "Pray an odd number of rak‘ahs and make it the final prayer of the night.",
        "witr.why": "Witr closes the night prayer with an odd-numbered prayer.",
        "visual.countdown.show": "Show next-prayer countdown in every view",
        "visual.countdown.help": "Keeps a live countdown visible above Overview, List, Timeline, and Clock.",
        "visual.countdown.accessibility": "Time remaining until the next prayer",
        "timeline.earlier": "Earlier", "timeline.later": "Later",
        "timeline.zoom_out": "Zoom out", "timeline.zoom_in": "Zoom in",
        "timeline.fit": "Fit full day",
        "timeline.gesture_hint": "Drag or scroll to move · pinch to zoom · arrows work from the keyboard",
        "timeline.accessibility_help": "Use left and right arrows to move, plus and minus to zoom, up and down to select, then Return for details.",
        "clock.previous": "Previous event", "clock.next": "Next event",
        "clock.accessibility_help": "Use arrow keys to select a prayer, then Return for details.",
    ],
    "fr": [
        "category.obligatory": "Prière obligatoire", "category.nawafil": "Prière surérogatoire",
        "info.when": "Quand", "info.how": "Comment", "info.why": "Pourquoi",
        "info.evidence": "Référence", "info.open": "Informations sur la prière",
        "obligatory.when.iqama": "L’heure de la prière commence à %@. L’iqama de cette mosquée est à %@.",
        "obligatory.when.no_iqama": "L’heure de la prière commence à %@. Aucune iqama n’est publiée ; priez dans sa plage valide.",
        "obligatory.how": "Accomplissez %@ rak‘āt obligatoires face à la qibla ; en groupe, suivez l’imam.",
        "obligatory.why": "L’une des cinq obligations quotidiennes prescrites à des heures déterminées.",
        "rawatib.before.window": "De l’entrée de l’heure à %@ jusqu’à l’iqama publiée à %@.",
        "rawatib.before.marker": "L’heure entre à %@. Priez avant le Fard ; aucune fin par iqama n’est publiée.",
        "rawatib.after.iqama": "Après la prière obligatoire commençant à l’iqama de %@ ; c’est un repère, pas une plage chronométrée.",
        "rawatib.after.no_iqama": "Après la prière obligatoire dont l’heure entre à %@ ; aucune iqama n’est publiée.",
        "rawatib.before": "Avant le Fard", "rawatib.after": "Après le Fard",
        "rawatib.how": "Priez par unités de deux. Gardez brèves les deux rak‘āt avant Fajr.",
        "rawatib.why": "La régularité dans les douze Rawatib est une cause d’une demeure au Paradis.",
        "nawafil.rawatib.fajr.count": "2 rak‘āt", "nawafil.rawatib.dhuhr.before.count": "4 rak‘āt",
        "nawafil.rawatib.after.count": "2 rak‘āt",
        "duha.when": "Repère : environ vingt minutes après le lever du soleil (%@) jusqu’avant Dhuhr (%@) ; évitez le zénith.",
        "duha.how": "Priez au moins deux rak‘āt, deux par deux ; huit sont aussi authentiquement rapportées.",
        "duha.why": "Deux rak‘āt de Duha acquittent l’aumône matinale due pour les articulations du corps.",
        "qiyam.when.no_iqama": "Après l’entrée de Isha à %@ jusqu’à Fajr %@ ; aucune iqama n’est publiée.",
        "qiyam.when.iqama": "Après la prière de Isha (iqama %@) jusqu’à Fajr %@.",
        "qiyam.how": "Priez deux par deux ; à l’approche de l’aube, terminez par un Witr.",
        "qiyam.why": "La meilleure prière volontaire après les obligations ; le dernier tiers est particulièrement méritoire.",
        "witr.how": "Priez un nombre impair de rak‘āt et faites-en la dernière prière de la nuit.",
        "witr.why": "Le Witr clôt la prière nocturne par un nombre impair.",
        "visual.countdown.show": "Afficher le compte à rebours dans chaque vue",
        "visual.countdown.help": "Garde le compte à rebours visible dans Vue d’ensemble, Liste, Chronologie et Horloge.",
        "visual.countdown.accessibility": "Temps restant avant la prochaine prière",
        "timeline.earlier": "Plus tôt", "timeline.later": "Plus tard",
        "timeline.zoom_out": "Dézoomer", "timeline.zoom_in": "Zoomer",
        "timeline.fit": "Afficher la journée entière",
        "timeline.gesture_hint": "Faites glisser pour parcourir · pincez pour zoomer · clavier compatible",
        "timeline.accessibility_help": "Utilisez gauche et droite pour parcourir, plus et moins pour zoomer, haut et bas pour sélectionner, puis Entrée pour les détails.",
        "clock.previous": "Événement précédent", "clock.next": "Événement suivant",
        "clock.accessibility_help": "Utilisez les flèches pour sélectionner une prière, puis Entrée pour les détails.",
    ],
    "es": [
        "category.obligatory": "Oración obligatoria", "category.nawafil": "Oración voluntaria",
        "info.when": "Cuándo", "info.how": "Cómo", "info.why": "Por qué",
        "info.evidence": "Referencia", "info.open": "Información de la oración",
        "obligatory.when.iqama": "El tiempo de la oración comienza a las %@. El iqama de esta mezquita es a las %@.",
        "obligatory.when.no_iqama": "El tiempo de la oración comienza a las %@. No hay iqama publicado; reza dentro de su tiempo válido.",
        "obligatory.how": "Reza %@ rak‘āt obligatorios hacia la qibla; en congregación, sigue al imam.",
        "obligatory.why": "Una de las cinco obligaciones diarias prescritas en tiempos determinados.",
        "rawatib.before.window": "Desde la entrada del tiempo a las %@ hasta el iqama publicado a las %@.",
        "rawatib.before.marker": "El tiempo entra a las %@. Reza antes del Fard; no hay una hora de iqama publicada que cierre el intervalo.",
        "rawatib.after.iqama": "Después de la oración obligatoria que comienza con el iqama de las %@; es una referencia, no un intervalo cronometrado.",
        "rawatib.after.no_iqama": "Después de la oración obligatoria cuyo tiempo entra a las %@; no hay iqama publicado.",
        "rawatib.before": "Antes del Fard", "rawatib.after": "Después del Fard",
        "rawatib.how": "Reza de dos en dos. Haz breves las dos rak‘āt anteriores al Fajr.",
        "rawatib.why": "Mantener doce Rawatib diarios es causa de una casa en el Paraíso.",
        "nawafil.rawatib.fajr.count": "2 rak‘āt", "nawafil.rawatib.dhuhr.before.count": "4 rak‘āt",
        "nawafil.rawatib.after.count": "2 rak‘āt",
        "duha.when": "Orientación: desde unos veinte minutos después del amanecer (%@) hasta antes del Dhuhr (%@); evita el cenit.",
        "duha.how": "Reza al menos dos rak‘āt, de dos en dos; también se han transmitido auténticamente ocho.",
        "duha.why": "Dos rak‘āt de Duha cubren la caridad matutina debida por las articulaciones del cuerpo.",
        "qiyam.when.no_iqama": "Después de la entrada del Isha a las %@ hasta el Fajr %@; no hay iqama publicado.",
        "qiyam.when.iqama": "Después de la congregación del Isha (iqama %@) hasta el Fajr %@.",
        "qiyam.how": "Reza de dos en dos; si se acerca el alba, concluye con un Witr.",
        "qiyam.why": "La mejor oración voluntaria después de las obligatorias; el último tercio de la noche es especialmente virtuoso.",
        "witr.how": "Reza un número impar de rak‘āt y haz que sea la última oración de la noche.",
        "witr.why": "El Witr cierra la oración nocturna con un número impar.",
        "visual.countdown.show": "Mostrar la cuenta atrás en todas las vistas",
        "visual.countdown.help": "Mantiene visible la cuenta atrás en Resumen, Lista, Cronología y Reloj.",
        "visual.countdown.accessibility": "Tiempo restante hasta la próxima oración",
        "timeline.earlier": "Antes", "timeline.later": "Después",
        "timeline.zoom_out": "Alejar", "timeline.zoom_in": "Acercar",
        "timeline.fit": "Ver el día completo",
        "timeline.gesture_hint": "Arrastra para moverte · pellizca para ampliar · admite teclado",
        "timeline.accessibility_help": "Usa izquierda y derecha para moverte, más y menos para ampliar, arriba y abajo para seleccionar y después Intro para ver detalles.",
        "clock.previous": "Evento anterior", "clock.next": "Evento siguiente",
        "clock.accessibility_help": "Usa las flechas para seleccionar una oración y después Intro para ver detalles.",
    ],
    "ar": [
        "category.obligatory": "صلاة مفروضة", "category.nawafil": "صلاة نافلة",
        "info.when": "متى", "info.how": "كيف", "info.why": "لماذا",
        "info.evidence": "الدليل", "info.open": "معلومات الصلاة",
        "obligatory.when.iqama": "يدخل وقت الصلاة عند %@، وإقامة هذا المسجد عند %@.",
        "obligatory.when.no_iqama": "يدخل وقت الصلاة عند %@. لا يوجد وقت إقامة منشور؛ فصلّها في وقتها المعتبر.",
        "obligatory.how": "صلِّ %@ ركعات مفروضة مستقبلًا القبلة، واتبع الإمام في الجماعة.",
        "obligatory.why": "واحدة من الصلوات الخمس المفروضة في أوقات محددة.",
        "rawatib.before.window": "من دخول الوقت عند %@ إلى الإقامة المنشورة عند %@.",
        "rawatib.before.marker": "يدخل الوقت عند %@. صلِّها قبل الفرض؛ لا يوجد وقت إقامة منشور لنهاية المدة.",
        "rawatib.after.iqama": "بعد الفريضة التي تبدأ بإقامة %@؛ هذه علامة إرشادية وليست مدة محددة.",
        "rawatib.after.no_iqama": "بعد الفريضة التي يدخل وقتها عند %@؛ لا يوجد وقت إقامة منشور.",
        "rawatib.before": "قبل الفرض", "rawatib.after": "بعد الفرض",
        "rawatib.how": "تُصلّى ركعتين ركعتين، وتُخفف ركعتا سنة الفجر.",
        "rawatib.why": "المحافظة على اثنتي عشرة ركعة من الرواتب سبب لبيت في الجنة.",
        "nawafil.rawatib.fajr.count": "ركعتان", "nawafil.rawatib.dhuhr.before.count": "أربع ركعات",
        "nawafil.rawatib.after.count": "ركعتان",
        "duha.when": "إرشاد: من نحو عشرين دقيقة بعد الشروق (%@) إلى ما قبل الظهر (%@)، مع اجتناب وقت الزوال.",
        "duha.how": "صلِّ ركعتين على الأقل، ركعتين ركعتين؛ وثبتت ثماني ركعات أيضًا.",
        "duha.why": "ركعتا الضحى تجزئان عن صدقة الصباح عن مفاصل الجسد.",
        "qiyam.when.no_iqama": "بعد دخول وقت العشاء عند %@ إلى الفجر %@؛ لا يوجد وقت إقامة منشور.",
        "qiyam.when.iqama": "بعد جماعة العشاء (الإقامة %@) إلى الفجر %@.",
        "qiyam.how": "صلِّ ركعتين ركعتين، فإذا خفت الصبح فاختم بركعة وتر.",
        "qiyam.why": "أفضل صلاة التطوع بعد الفريضة، والثلث الأخير من الليل أفضل أوقاته.",
        "witr.how": "صلِّ عددًا فرديًا من الركعات واجعلها آخر صلاة الليل.",
        "witr.why": "يختم الوتر صلاة الليل بصلاة ذات عدد فردي.",
        "visual.countdown.show": "إظهار العد التنازلي للصلاة القادمة في كل عرض",
        "visual.countdown.help": "يبقي العد التنازلي ظاهرًا في النظرة العامة والقائمة والخط الزمني والساعة.",
        "visual.countdown.accessibility": "الوقت المتبقي للصلاة القادمة",
        "timeline.earlier": "وقت أبكر", "timeline.later": "وقت لاحق",
        "timeline.zoom_out": "تصغير", "timeline.zoom_in": "تكبير",
        "timeline.fit": "عرض اليوم كاملًا",
        "timeline.gesture_hint": "اسحب للتنقل · اقرص للتكبير · يدعم لوحة المفاتيح",
        "timeline.accessibility_help": "استخدم السهمين يمينًا ويسارًا للتنقل، وزائداً وناقصاً للتكبير، وأعلى وأسفل للاختيار، ثم الإدخال للتفاصيل.",
        "clock.previous": "الحدث السابق", "clock.next": "الحدث التالي",
        "clock.accessibility_help": "استخدم الأسهم لاختيار صلاة ثم الإدخال لعرض التفاصيل.",
    ],
    "zh": [
        "category.obligatory": "主命拜", "category.nawafil": "副功拜",
        "info.when": "时间", "info.how": "做法", "info.why": "意义",
        "info.evidence": "依据", "info.open": "礼拜说明",
        "obligatory.when.iqama": "礼拜时间于 %@ 进入，本清真寺的成拜时间为 %@。",
        "obligatory.when.no_iqama": "礼拜时间于 %@ 进入。清真寺未公布成拜时间，请在有效时段内礼拜。",
        "obligatory.how": "面向朝向礼 %@ 拜主命拜；集体礼拜时跟随伊玛目。",
        "obligatory.why": "这是每日五番在规定时间履行的主命之一。",
        "rawatib.before.window": "从礼拜时间进入的 %@ 到公布的成拜时间 %@。",
        "rawatib.before.marker": "礼拜时间于 %@ 进入。请在主命拜前礼；因未公布成拜时间，无法给出结束点。",
        "rawatib.after.iqama": "在 %@ 成拜开始的主命拜结束后；这是提示点，不是固定时段。",
        "rawatib.after.no_iqama": "在 %@ 进入时间的主命拜结束后；未公布成拜时间。",
        "rawatib.before": "主命拜前", "rawatib.after": "主命拜后",
        "rawatib.how": "每两拜一组。晨礼前的两拜宜简短。",
        "rawatib.why": "坚持每日十二拜常行圣行拜，是获得乐园住宅的善因。",
        "nawafil.rawatib.fajr.count": "2拜", "nawafil.rawatib.dhuhr.before.count": "4拜",
        "nawafil.rawatib.after.count": "2拜",
        "duha.when": "参考：日出约二十分钟后（%@）至晌礼前（%@）；避开正午天顶时刻。",
        "duha.how": "至少礼两拜，每两拜一组；可靠传述中也有八拜。",
        "duha.why": "杜哈的两拜可履行身体各关节在清晨应尽的施舍。",
        "qiyam.when.no_iqama": "宵礼时间 %@ 进入后至晨礼 %@；未公布成拜时间。",
        "qiyam.when.iqama": "宵礼集体礼拜（成拜 %@）后至晨礼 %@。",
        "qiyam.how": "每两拜一组；若担心黎明将至，以一拜奇数拜结束。",
        "qiyam.why": "主命拜之后最优的副功拜；夜晚最后三分之一尤为尊贵。",
        "witr.how": "礼奇数拜，并将其作为夜间最后的礼拜。",
        "witr.why": "奇数拜以奇数拜数结束夜间礼拜。",
        "visual.countdown.show": "在所有视图显示下一次礼拜倒计时",
        "visual.countdown.help": "在概览、列表、时间线和时钟中持续显示倒计时。",
        "visual.countdown.accessibility": "距离下一次礼拜的剩余时间",
        "timeline.earlier": "较早", "timeline.later": "较晚",
        "timeline.zoom_out": "缩小", "timeline.zoom_in": "放大",
        "timeline.fit": "显示全天",
        "timeline.gesture_hint": "拖动浏览 · 捏合缩放 · 支持键盘",
        "timeline.accessibility_help": "用左右键移动、加减键缩放、上下键选择，然后按回车查看详情。",
        "clock.previous": "上一事件", "clock.next": "下一事件",
        "clock.accessibility_help": "用方向键选择礼拜，然后按回车查看详情。",
    ],
    "hi": [
        "category.obligatory": "फ़र्ज़ नमाज़", "category.nawafil": "नफ़्ल नमाज़",
        "info.when": "कब", "info.how": "कैसे", "info.why": "क्यों",
        "info.evidence": "दलील", "info.open": "नमाज़ की जानकारी",
        "obligatory.when.iqama": "नमाज़ का वक़्त %@ पर शुरू होता है। इस मस्जिद की इक़ामत %@ पर है।",
        "obligatory.when.no_iqama": "नमाज़ का वक़्त %@ पर शुरू होता है। इक़ामत प्रकाशित नहीं है; मान्य वक़्त के भीतर नमाज़ पढ़ें।",
        "obligatory.how": "क़िबला की ओर %@ फ़र्ज़ रकअत पढ़ें; जमाअत में इमाम की पैरवी करें।",
        "obligatory.why": "तय वक़्तों पर फ़र्ज़ की गई पाँच रोज़ाना नमाज़ों में से एक।",
        "rawatib.before.window": "वक़्त के %@ पर शुरू होने से प्रकाशित इक़ामत %@ तक।",
        "rawatib.before.marker": "वक़्त %@ पर शुरू होता है। फ़र्ज़ से पहले पढ़ें; अंत बताने वाली इक़ामत प्रकाशित नहीं है।",
        "rawatib.after.iqama": "%@ की इक़ामत से शुरू होने वाली फ़र्ज़ नमाज़ के बाद; यह संकेत है, तय अवधि नहीं।",
        "rawatib.after.no_iqama": "उस फ़र्ज़ नमाज़ के बाद जिसका वक़्त %@ पर शुरू होता है; इक़ामत प्रकाशित नहीं है।",
        "rawatib.before": "फ़र्ज़ से पहले", "rawatib.after": "फ़र्ज़ के बाद",
        "rawatib.how": "दो-दो रकअत पढ़ें। फ़ज्र से पहले की दो रकअत हल्की रखें।",
        "rawatib.why": "रोज़ बारह रावतिब की पाबंदी जन्नत में घर का सबब है।",
        "nawafil.rawatib.fajr.count": "2 रकअत", "nawafil.rawatib.dhuhr.before.count": "4 रकअत",
        "nawafil.rawatib.after.count": "2 रकअत",
        "duha.when": "मार्गदर्शन: सूर्योदय के लगभग बीस मिनट बाद (%@) से ज़ुहर से पहले (%@) तक; ठीक ज़वाल से बचें।",
        "duha.how": "कम से कम दो रकअत, दो-दो करके पढ़ें; आठ रकअत भी सही रिवायत से साबित हैं।",
        "duha.why": "दुहा की दो रकअत शरीर के जोड़ों की सुबह की सदक़ा ज़िम्मेदारी पूरी करती हैं।",
        "qiyam.when.no_iqama": "इशा का वक़्त %@ पर शुरू होने के बाद से फ़ज्र %@ तक; इक़ामत प्रकाशित नहीं है।",
        "qiyam.when.iqama": "इशा की जमाअत (इक़ामत %@) के बाद से फ़ज्र %@ तक।",
        "qiyam.how": "दो-दो रकअत पढ़ें; सुबह का डर हो तो एक वित्र से समाप्त करें।",
        "qiyam.why": "फ़र्ज़ों के बाद सबसे उत्तम नफ़्ल नमाज़; रात का आख़िरी तिहाई विशेष फ़ज़ीलत वाला है।",
        "witr.how": "विषम संख्या में रकअत पढ़ें और इसे रात की आख़िरी नमाज़ बनाएँ।",
        "witr.why": "वित्र रात की नमाज़ को विषम संख्या से पूरा करता है।",
        "visual.countdown.show": "हर दृश्य में अगली नमाज़ की उलटी गिनती दिखाएँ",
        "visual.countdown.help": "अवलोकन, सूची, समयरेखा और घड़ी में उलटी गिनती दिखाई देती रहेगी।",
        "visual.countdown.accessibility": "अगली नमाज़ तक बचा समय",
        "timeline.earlier": "पहले", "timeline.later": "बाद में",
        "timeline.zoom_out": "ज़ूम आउट", "timeline.zoom_in": "ज़ूम इन",
        "timeline.fit": "पूरा दिन दिखाएँ",
        "timeline.gesture_hint": "चलाने के लिए खींचें · ज़ूम के लिए पिंच करें · कीबोर्ड समर्थित",
        "timeline.accessibility_help": "चलाने के लिए बाएँ-दाएँ, ज़ूम के लिए प्लस-माइनस, चुनने के लिए ऊपर-नीचे और विवरण के लिए रिटर्न दबाएँ।",
        "clock.previous": "पिछला समय", "clock.next": "अगला समय",
        "clock.accessibility_help": "नमाज़ चुनने के लिए तीर कुंजियाँ और विवरण के लिए रिटर्न दबाएँ।",
    ],
    "bn": [
        "category.obligatory": "ফরজ নামাজ", "category.nawafil": "নফল নামাজ",
        "info.when": "কখন", "info.how": "কীভাবে", "info.why": "কেন",
        "info.evidence": "দলিল", "info.open": "নামাজের তথ্য",
        "obligatory.when.iqama": "নামাজের সময় %@-এ শুরু হয়। এই মসজিদের ইকামত %@-এ।",
        "obligatory.when.no_iqama": "নামাজের সময় %@-এ শুরু হয়। ইকামতের সময় প্রকাশিত নেই; বৈধ সময়ের মধ্যে নামাজ পড়ুন।",
        "obligatory.how": "কিবলামুখী হয়ে %@ রাকাত ফরজ পড়ুন; জামাতে ইমামকে অনুসরণ করুন।",
        "obligatory.why": "নির্ধারিত সময়ে আদায়ের জন্য ফরজ করা দৈনিক পাঁচ নামাজের একটি।",
        "rawatib.before.window": "ওয়াক্ত %@-এ শুরু হওয়া থেকে প্রকাশিত ইকামত %@ পর্যন্ত।",
        "rawatib.before.marker": "ওয়াক্ত %@-এ শুরু হয়। ফরজের আগে পড়ুন; শেষ নির্ধারণের ইকামত প্রকাশিত নেই।",
        "rawatib.after.iqama": "%@-এর ইকামতে শুরু হওয়া ফরজ নামাজের পরে; এটি নির্দেশক, নির্দিষ্ট সময়সীমা নয়।",
        "rawatib.after.no_iqama": "যে ফরজের ওয়াক্ত %@-এ শুরু হয়, তা শেষ হওয়ার পরে; ইকামত প্রকাশিত নেই।",
        "rawatib.before": "ফরজের আগে", "rawatib.after": "ফরজের পরে",
        "rawatib.how": "দুই রাকাত করে পড়ুন। ফজরের আগের দুই রাকাত সংক্ষিপ্ত রাখুন।",
        "rawatib.why": "দৈনিক বারো রাকাত রাওয়াতিব নিয়মিত পড়া জান্নাতে ঘরের কারণ।",
        "nawafil.rawatib.fajr.count": "২ রাকাত", "nawafil.rawatib.dhuhr.before.count": "৪ রাকাত",
        "nawafil.rawatib.after.count": "২ রাকাত",
        "duha.when": "নির্দেশনা: সূর্যোদয়ের প্রায় বিশ মিনিট পরে (%@) থেকে যোহরের আগে (%@) পর্যন্ত; ঠিক মধ্যাহ্ন এড়িয়ে চলুন।",
        "duha.how": "অন্তত দুই রাকাত, দুই রাকাত করে পড়ুন; আট রাকাতও সহিহ বর্ণনায় আছে।",
        "duha.why": "দুহার দুই রাকাত শরীরের অস্থিসন্ধিগুলোর সকালের সদকার দায় পূরণ করে।",
        "qiyam.when.no_iqama": "ইশার ওয়াক্ত %@-এ শুরু হওয়ার পর থেকে ফজর %@ পর্যন্ত; ইকামত প্রকাশিত নেই।",
        "qiyam.when.iqama": "ইশার জামাতের (ইকামত %@) পর থেকে ফজর %@ পর্যন্ত।",
        "qiyam.how": "দুই রাকাত করে পড়ুন; ভোর হওয়ার আশঙ্কা হলে এক রাকাত বিতর দিয়ে শেষ করুন।",
        "qiyam.why": "ফরজের পরে সর্বোত্তম নফল নামাজ; রাতের শেষ তৃতীয়াংশ বিশেষ মর্যাদাপূর্ণ।",
        "witr.how": "বিজোড় সংখ্যক রাকাত পড়ুন এবং এটিকে রাতের শেষ নামাজ করুন।",
        "witr.why": "বিতর বিজোড় নামাজ দিয়ে রাতের নামাজ সম্পন্ন করে।",
        "visual.countdown.show": "সব দৃশ্যে পরবর্তী নামাজের কাউন্টডাউন দেখান",
        "visual.countdown.help": "সারাংশ, তালিকা, সময়রেখা ও ঘড়িতে কাউন্টডাউন দৃশ্যমান রাখে।",
        "visual.countdown.accessibility": "পরবর্তী নামাজ পর্যন্ত বাকি সময়",
        "timeline.earlier": "আগের সময়", "timeline.later": "পরের সময়",
        "timeline.zoom_out": "ছোট করুন", "timeline.zoom_in": "বড় করুন",
        "timeline.fit": "পুরো দিন দেখান",
        "timeline.gesture_hint": "সরাতে টানুন · জুম করতে পিঞ্চ করুন · কিবোর্ড সমর্থিত",
        "timeline.accessibility_help": "সরাতে বাম-ডান, জুমে প্লাস-মাইনাস, বাছতে উপর-নিচ এবং বিস্তারিতের জন্য রিটার্ন চাপুন।",
        "clock.previous": "আগের সময়", "clock.next": "পরের সময়",
        "clock.accessibility_help": "নামাজ বাছতে তীরচিহ্ন এবং বিস্তারিতের জন্য রিটার্ন চাপুন।",
    ],
    "ru": [
        "category.obligatory": "Обязательная молитва", "category.nawafil": "Дополнительная молитва",
        "info.when": "Когда", "info.how": "Как", "info.why": "Зачем",
        "info.evidence": "Источник", "info.open": "Сведения о молитве",
        "obligatory.when.iqama": "Время молитвы наступает в %@. Икама этой мечети — в %@.",
        "obligatory.when.no_iqama": "Время молитвы наступает в %@. Икама не опубликована; совершите молитву в пределах её времени.",
        "obligatory.how": "Совершите %@ обязательных ракаата лицом к кибле; в джамаате следуйте за имамом.",
        "obligatory.why": "Одна из пяти ежедневных обязанностей, предписанных в установленное время.",
        "rawatib.before.window": "С наступления времени в %@ до опубликованной икамы в %@.",
        "rawatib.before.marker": "Время наступает в %@. Совершите до фарда; время икамы для конца интервала не опубликовано.",
        "rawatib.after.iqama": "После обязательной молитвы, начинающейся с икамы в %@; это ориентир, а не точный интервал.",
        "rawatib.after.no_iqama": "После обязательной молитвы, время которой наступает в %@; икама не опубликована.",
        "rawatib.before": "До фарда", "rawatib.after": "После фарда",
        "rawatib.how": "Совершайте по два ракаата. Два ракаата перед Фаджром делайте краткими.",
        "rawatib.why": "Постоянство в двенадцати рауатиб ежедневно — причина дома в Раю.",
        "nawafil.rawatib.fajr.count": "2 ракаата", "nawafil.rawatib.dhuhr.before.count": "4 ракаата",
        "nawafil.rawatib.after.count": "2 ракаата",
        "duha.when": "Ориентир: примерно через двадцать минут после восхода (%@) до Зухра (%@); избегайте самого зенита.",
        "duha.how": "Совершите не менее двух ракаатов, по два; достоверно переданы и восемь.",
        "duha.why": "Два ракаата Духа заменяют утреннюю милостыню за суставы тела.",
        "qiyam.when.no_iqama": "После наступления Иша в %@ до Фаджра %@; икама не опубликована.",
        "qiyam.when.iqama": "После джамаата Иша (икама %@) до Фаджра %@.",
        "qiyam.how": "Совершайте по два ракаата; если приближается рассвет, завершите одним Витром.",
        "qiyam.why": "Лучшая добровольная молитва после обязательных; последняя треть ночи особенно достойна.",
        "witr.how": "Совершите нечётное число ракаатов и сделайте Витр последней молитвой ночи.",
        "witr.why": "Витр завершает ночную молитву нечётным числом ракаатов.",
        "visual.countdown.show": "Показывать отсчёт до следующей молитвы во всех видах",
        "visual.countdown.help": "Оставляет отсчёт видимым в обзоре, списке, шкале дня и часах.",
        "visual.countdown.accessibility": "Время до следующей молитвы",
        "timeline.earlier": "Раньше", "timeline.later": "Позже",
        "timeline.zoom_out": "Уменьшить", "timeline.zoom_in": "Увеличить",
        "timeline.fit": "Показать весь день",
        "timeline.gesture_hint": "Перетаскивайте для навигации · щипок меняет масштаб · работает с клавиатурой",
        "timeline.accessibility_help": "Стрелки влево и вправо перемещают, плюс и минус меняют масштаб, вверх и вниз выбирают, Enter открывает сведения.",
        "clock.previous": "Предыдущее событие", "clock.next": "Следующее событие",
        "clock.accessibility_help": "Выберите молитву стрелками и нажмите Enter для сведений.",
    ],
    "pt": [
        "category.obligatory": "Oração obrigatória", "category.nawafil": "Oração voluntária",
        "info.when": "Quando", "info.how": "Como", "info.why": "Porquê",
        "info.evidence": "Referência", "info.open": "Informação da oração",
        "obligatory.when.iqama": "O tempo da oração começa às %@. O iqama desta mesquita é às %@.",
        "obligatory.when.no_iqama": "O tempo da oração começa às %@. Não há iqama publicado; ore dentro do período válido.",
        "obligatory.how": "Ore %@ rak‘āt obrigatórios voltado para a qibla; em congregação, siga o imam.",
        "obligatory.why": "Uma das cinco obrigações diárias prescritas em horários determinados.",
        "rawatib.before.window": "Desde a entrada do tempo às %@ até ao iqama publicado às %@.",
        "rawatib.before.marker": "O tempo entra às %@. Ore antes do Fard; não há iqama publicado para indicar o fim.",
        "rawatib.after.iqama": "Depois da oração obrigatória iniciada pelo iqama das %@; é um marco, não um intervalo cronometrado.",
        "rawatib.after.no_iqama": "Depois da oração obrigatória cujo tempo entra às %@; não há iqama publicado.",
        "rawatib.before": "Antes do Fard", "rawatib.after": "Depois do Fard",
        "rawatib.how": "Ore de duas em duas. Mantenha breves as duas rak‘āt antes do Fajr.",
        "rawatib.why": "Manter doze Rawatib diariamente é causa de uma casa no Paraíso.",
        "nawafil.rawatib.fajr.count": "2 rak‘āt", "nawafil.rawatib.dhuhr.before.count": "4 rak‘āt",
        "nawafil.rawatib.after.count": "2 rak‘āt",
        "duha.when": "Orientação: cerca de vinte minutos após o nascer do sol (%@) até antes do Dhuhr (%@); evite o zénite.",
        "duha.how": "Ore pelo menos duas rak‘āt, de duas em duas; oito também foram transmitidas autenticamente.",
        "duha.why": "Duas rak‘āt de Duha cumprem a caridade matinal devida pelas articulações do corpo.",
        "qiyam.when.no_iqama": "Após a entrada do Isha às %@ até ao Fajr %@; não há iqama publicado.",
        "qiyam.when.iqama": "Após a congregação do Isha (iqama %@) até ao Fajr %@.",
        "qiyam.how": "Ore de duas em duas; se a alvorada estiver próxima, conclua com um Witr.",
        "qiyam.why": "A melhor oração voluntária após as obrigatórias; o último terço da noite é especialmente virtuoso.",
        "witr.how": "Ore um número ímpar de rak‘āt e faça dela a última oração da noite.",
        "witr.why": "O Witr encerra a oração noturna com um número ímpar.",
        "visual.countdown.show": "Mostrar contagem para a próxima oração em todas as vistas",
        "visual.countdown.help": "Mantém a contagem visível na Vista geral, Lista, Cronologia e Relógio.",
        "visual.countdown.accessibility": "Tempo restante até à próxima oração",
        "timeline.earlier": "Mais cedo", "timeline.later": "Mais tarde",
        "timeline.zoom_out": "Afastar", "timeline.zoom_in": "Aproximar",
        "timeline.fit": "Mostrar o dia inteiro",
        "timeline.gesture_hint": "Arraste para navegar · belisque para ampliar · suporta teclado",
        "timeline.accessibility_help": "Use esquerda e direita para navegar, mais e menos para ampliar, cima e baixo para selecionar e Enter para detalhes.",
        "clock.previous": "Evento anterior", "clock.next": "Evento seguinte",
        "clock.accessibility_help": "Use as setas para selecionar uma oração e Enter para os detalhes.",
    ],
    "ur": [
        "category.obligatory": "فرض نماز", "category.nawafil": "نفل نماز",
        "info.when": "کب", "info.how": "کیسے", "info.why": "کیوں",
        "info.evidence": "دلیل", "info.open": "نماز کی معلومات",
        "obligatory.when.iqama": "نماز کا وقت %@ پر شروع ہوتا ہے۔ اس مسجد کی اقامت %@ پر ہے۔",
        "obligatory.when.no_iqama": "نماز کا وقت %@ پر شروع ہوتا ہے۔ اقامت شائع نہیں؛ معتبر وقت کے اندر نماز ادا کریں۔",
        "obligatory.how": "قبلہ رخ ہو کر %@ فرض رکعتیں پڑھیں؛ جماعت میں امام کی پیروی کریں۔",
        "obligatory.why": "مقررہ اوقات میں فرض کی گئی روزانہ پانچ نمازوں میں سے ایک۔",
        "rawatib.before.window": "وقت کے %@ پر شروع ہونے سے شائع شدہ اقامت %@ تک۔",
        "rawatib.before.marker": "وقت %@ پر شروع ہوتا ہے۔ فرض سے پہلے پڑھیں؛ اختتام کے لیے اقامت شائع نہیں۔",
        "rawatib.after.iqama": "%@ کی اقامت سے شروع ہونے والی فرض نماز کے بعد؛ یہ رہنما نشان ہے، مقررہ دورانیہ نہیں۔",
        "rawatib.after.no_iqama": "اس فرض نماز کے بعد جس کا وقت %@ پر شروع ہوتا ہے؛ اقامت شائع نہیں۔",
        "rawatib.before": "فرض سے پہلے", "rawatib.after": "فرض کے بعد",
        "rawatib.how": "دو دو رکعت پڑھیں۔ فجر سے پہلے کی دو رکعتیں مختصر رکھیں۔",
        "rawatib.why": "روزانہ بارہ رواتب کی پابندی جنت میں گھر کا سبب ہے۔",
        "nawafil.rawatib.fajr.count": "۲ رکعت", "nawafil.rawatib.dhuhr.before.count": "۴ رکعت",
        "nawafil.rawatib.after.count": "۲ رکعت",
        "duha.when": "رہنمائی: طلوعِ آفتاب کے تقریباً بیس منٹ بعد (%@) سے ظہر سے پہلے (%@) تک؛ عین زوال سے بچیں۔",
        "duha.how": "کم از کم دو رکعت، دو دو کر کے پڑھیں؛ آٹھ رکعت بھی صحیح روایت سے ثابت ہیں۔",
        "duha.why": "ضحیٰ کی دو رکعتیں جسم کے جوڑوں کی صبح کی صدقہ ذمہ داری پوری کرتی ہیں۔",
        "qiyam.when.no_iqama": "عشا کا وقت %@ پر شروع ہونے کے بعد سے فجر %@ تک؛ اقامت شائع نہیں۔",
        "qiyam.when.iqama": "عشا کی جماعت (اقامت %@) کے بعد سے فجر %@ تک۔",
        "qiyam.how": "دو دو رکعت پڑھیں؛ صبح قریب ہو تو ایک وتر سے ختم کریں۔",
        "qiyam.why": "فرضوں کے بعد بہترین نفل نماز؛ رات کا آخری تہائی خاص فضیلت رکھتا ہے۔",
        "witr.how": "طاق تعداد میں رکعتیں پڑھیں اور اسے رات کی آخری نماز بنائیں۔",
        "witr.why": "وتر رات کی نماز کو طاق نماز پر مکمل کرتا ہے۔",
        "visual.countdown.show": "ہر منظر میں اگلی نماز کی الٹی گنتی دکھائیں",
        "visual.countdown.help": "عمومی منظر، فہرست، وقت کی لکیر اور گھڑی میں الٹی گنتی دکھاتا ہے۔",
        "visual.countdown.accessibility": "اگلی نماز تک باقی وقت",
        "timeline.earlier": "پہلے", "timeline.later": "بعد میں",
        "timeline.zoom_out": "چھوٹا کریں", "timeline.zoom_in": "بڑا کریں",
        "timeline.fit": "پورا دن دکھائیں",
        "timeline.gesture_hint": "منتقل کرنے کے لیے گھسیٹیں · زوم کے لیے پنچ کریں · کی بورڈ معاون",
        "timeline.accessibility_help": "منتقلی کے لیے بائیں دائیں، زوم کے لیے جمع تفریق، انتخاب کے لیے اوپر نیچے اور تفصیل کے لیے ریٹرن دبائیں۔",
        "clock.previous": "پچھلا وقت", "clock.next": "اگلا وقت",
        "clock.accessibility_help": "نماز منتخب کرنے کے لیے تیر اور تفصیل کے لیے ریٹرن دبائیں۔",
    ],
]

func prayerInfoText(_ key: String) -> String {
    let code = Localizer.shared.current.code
    let value = prayerInfoTranslations[code]?[key]
        ?? prayerInfoTranslations["en"]?[key]
        ?? featureText(key)
    return applyingArabicDigitPreference(value, languageCode: code)
}

/// Register the bundled Cairo font so NSFont(name:…) / NSFontManager can find
/// it. We now ship a single variable .ttf — the old per-weight files were
/// retired from Google Fonts' repo in 2024. We still look for the legacy
/// per-weight names too, so an older build that still has them around keeps
/// working without a rebuild.
func registerCairoFonts() {
    let candidates = [
        "Cairo-Variable",
        "Cairo-Regular", "Cairo-Medium", "Cairo-SemiBold", "Cairo-Bold", "Cairo-Light",
    ]
    for n in candidates {
        if let url = Bundle.main.url(forResource: n, withExtension: "ttf") {
            CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
        }
    }
}

/// Recursively applies RTL styling to `root` and every descendant:
///  • mirrors each view's frame horizontally inside its parent's bounds,
///  • swaps left/right text alignments,
///  • sets `baseWritingDirection = .rightToLeft` on NSTextFields so mixed
///    Arabic/numeric content flows correctly,
///  • sets `userInterfaceLayoutDirection = .rightToLeft` so native controls
///    (popup arrows, segment order, checkbox box position) render mirrored.
/// Call this once on the root of any freshly-built subtree when RTL is active.
func applyRTL(_ root: NSView) {
    for sub in root.subviews {
        // Mirror frame within parent's bounds
        var f = sub.frame
        f.origin.x = root.bounds.width - f.origin.x - f.size.width
        sub.frame = f

        // Text-field specific: flip alignment + set writing direction
        if let tf = sub as? NSTextField {
            switch tf.alignment {
            case .left:  tf.alignment = .right
            case .right: tf.alignment = .left
            default: break
            }
            tf.baseWritingDirection = .rightToLeft
        }

        // Tell native controls to render right-to-left
        sub.userInterfaceLayoutDirection = .rightToLeft

        // Skip recursion into AppKit-managed container views — they handle
        // RTL internally once userInterfaceLayoutDirection is set. Manually
        // mirroring their private subviews (clip view, scrollers, segment
        // cells) would fight AppKit's own layout.
        if sub is NSScrollView || sub is NSSegmentedControl
            || sub is NSPopUpButton || sub is NSButton {
            continue
        }

        // Recurse into children (in the subview's own coordinate system)
        applyRTL(sub)
    }
}

/// Legacy alias. Kept so callers that still pass a `totalWidth` compile —
/// the width parameter is ignored because `applyRTL` uses each parent's bounds.
@inline(__always)
func mirrorSubviewsHorizontally(_ parent: NSView, totalWidth: CGFloat) {
    applyRTL(parent)
}

/// Returns the SF Symbol name to use for a "back" chevron in the current
/// language. In RTL locales the chevron points right (forward visually).
var backChevronSymbol: String {
    Localizer.shared.isRTL ? "chevron.right" : "chevron.left"
}

// ============================================================================
// MARK: Icons & hover-animated icon button
// ============================================================================

/// Returns a minimalist monochrome template image for the macOS menu-bar status item.
/// Draws a small crescent + star glyph so it adapts to light/dark automatically.
func makeMenuBarIcon() -> NSImage {
    if #available(macOS 11.0, *) {
        let cfg = NSImage.SymbolConfiguration(pointSize: 13, weight: .semibold)
        if let img = NSImage(systemSymbolName: "moon.stars.fill",
                             accessibilityDescription: "Salat Time")?
                        .withSymbolConfiguration(cfg) {
            img.isTemplate = true
            return img
        }
    }
    // Fallback (pre-macOS 11): simple filled dot. App minimum is 11, so rarely hit.
    let size = NSSize(width: 16, height: 16)
    let img = NSImage(size: size, flipped: false) { _ in
        NSColor.black.setFill()
        NSBezierPath(ovalIn: NSRect(x: 3, y: 3, width: 10, height: 10)).fill()
        return true
    }
    img.isTemplate = true
    return img
}

/// Returns a template SF-Symbol image (monotone, adapts to dark/light).
func templateSymbol(_ name: String, pointSize: CGFloat = 14,
                    weight: NSFont.Weight = .medium) -> NSImage? {
    if #available(macOS 11.0, *) {
        let cfg = NSImage.SymbolConfiguration(pointSize: pointSize, weight: weight)
        if let img = NSImage(systemSymbolName: name, accessibilityDescription: name)?
                        .withSymbolConfiguration(cfg) {
            img.isTemplate = true
            return img
        }
    }
    return nil
}

/// Icon-only button with a smooth hover animation (fade-in background, tint brighten,
/// subtle press scale). Designed to look clean in both light and dark mode.
final class HoverIconButton: NSButton {
    private var trackingAreaRef: NSTrackingArea?
    private var hovering = false

    var idleTint:  NSColor = .secondaryLabelColor
    var hoverTint: NSColor = .labelColor
    var hoverBG:   NSColor = NSColor(white: 0.5, alpha: 0.18)
    var cornerRad: CGFloat = 8 { didSet { layer?.cornerRadius = cornerRad } }

    init(symbol: String,
         toolTip: String,
         target: AnyObject?,
         action: Selector,
         pointSize: CGFloat = 14,
         size: NSSize = NSSize(width: 40, height: 30)) {

        super.init(frame: NSRect(origin: .zero, size: size))
        self.target = target
        self.action = action
        self.toolTip = toolTip
        self.title = ""
        self.isBordered = false
        self.bezelStyle = .regularSquare
        self.imagePosition = .imageOnly
        self.imageScaling = .scaleProportionallyDown
        self.focusRingType = .default
        self.setAccessibilityLabel(toolTip)
        self.wantsLayer = true
        self.layer?.cornerRadius = cornerRad
        self.layer?.masksToBounds = true
        self.layer?.backgroundColor = NSColor.clear.cgColor

        if let img = templateSymbol(symbol, pointSize: pointSize) {
            self.image = img
        } else {
            // Last-resort fallback: small dot
            let img = NSImage(size: NSSize(width: 14, height: 14), flipped: false) { _ in
                NSColor.black.setFill()
                NSBezierPath(ovalIn: NSRect(x: 3, y: 3, width: 8, height: 8)).fill()
                return true
            }
            img.isTemplate = true
            self.image = img
        }
        self.contentTintColor = idleTint
    }

    required init?(coder: NSCoder) { fatalError() }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let ta = trackingAreaRef { removeTrackingArea(ta) }
        let ta = NSTrackingArea(
            rect: bounds,
            options: [.mouseEnteredAndExited, .activeInActiveApp, .inVisibleRect],
            owner: self, userInfo: nil)
        addTrackingArea(ta)
        trackingAreaRef = ta
    }

    override func mouseEntered(with event: NSEvent) {
        hovering = true
        contentTintColor = hoverTint
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.14
            ctx.timingFunction = CAMediaTimingFunction(name: .easeOut)
            ctx.allowsImplicitAnimation = true
            self.layer?.backgroundColor = self.hoverBG.cgColor
        }
    }

    override func mouseExited(with event: NSEvent) {
        hovering = false
        contentTintColor = idleTint
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.18
            ctx.timingFunction = CAMediaTimingFunction(name: .easeIn)
            ctx.allowsImplicitAnimation = true
            self.layer?.backgroundColor = NSColor.clear.cgColor
        }
    }

    override func mouseDown(with event: NSEvent) {
        // Press flash
        let was = self.alphaValue
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.07
            ctx.timingFunction = CAMediaTimingFunction(name: .easeOut)
            ctx.allowsImplicitAnimation = true
            self.alphaValue = 0.55
        }
        super.mouseDown(with: event)
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.14
            ctx.timingFunction = CAMediaTimingFunction(name: .easeOut)
            ctx.allowsImplicitAnimation = true
            self.alphaValue = was
        }
    }
}

// ============================================================================
// MARK: Mawaqit search (API-first, web-scrape fallback)
// ============================================================================
final class MosqueSearch: NSObject, WKNavigationDelegate {
    private var webView: WKWebView?
    private var completion: (([MosqueRef]) -> Void)?
    private var validationCompletion: ((MosqueRef?) -> Void)?
    private var isValidationMode = false
    private var timeoutTimer: Timer?
    /// In-flight API request. Stored so a fresh keystroke can cancel the
    /// previous live-search request before firing a new one — prevents
    /// stale results from arriving out-of-order after the user has kept
    /// typing.
    private var liveTask: URLSessionDataTask?

    override init() { super.init() }

    func searchText(_ word: String, completion: @escaping ([MosqueRef]) -> Void) {
        let q = word.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { completion([]); return }
        let enc = q.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? q
        let api = "https://mawaqit.net/api/2.0/mosque/search?word=\(enc)&page=1"
        tryAPI(urlString: api) { [weak self] refs in
            if !refs.isEmpty { completion(refs); return }
            self?.webScrapeSearch(word: q, completion: completion)
        }
    }

    /// Keystroke-level search. Goes through Mawaqit's JSON API only
    /// (no WKWebView fallback) so it returns fast enough to drive a
    /// type-ahead list, and cancels any previous in-flight request so
    /// results can't arrive out-of-order while the user is still typing.
    /// Call `cancelLiveSearch()` to abort cleanly if the query becomes
    /// empty or the view is torn down.
    func searchTextLive(_ word: String,
                        completion: @escaping ([MosqueRef]) -> Void) {
        liveTask?.cancel()
        liveTask = nil
        let q = word.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { completion([]); return }
        let enc = q.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? q
        guard let url = URL(string:
            "https://mawaqit.net/api/2.0/mosque/search?word=\(enc)&page=1")
        else { completion([]); return }
        var req = URLRequest(url: url, timeoutInterval: 8)
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        req.setValue("Salat-Time/2.1 (macOS)", forHTTPHeaderField: "User-Agent")
        let task = URLSession.shared.dataTask(with: req) { [weak self] data, response, error in
            // Treat cancellation as a no-op: a fresher keystroke is
            // already on its way, so we don't want to step on it.
            if let e = error as NSError?, e.code == NSURLErrorCancelled { return }
            var refs: [MosqueRef] = []
            if let http = response as? HTTPURLResponse, http.statusCode == 200,
               let data = data,
               let obj = try? JSONSerialization.jsonObject(with: data) {
                refs = Self.parseAPIResponse(obj)
            }
            DispatchQueue.main.async {
                self?.liveTask = nil
                completion(refs)
            }
        }
        liveTask = task
        task.resume()
    }

    /// Abort any in-flight live search — useful when the user clears
    /// the text field or navigates away from the Search tab.
    func cancelLiveSearch() {
        liveTask?.cancel()
        liveTask = nil
    }

    func searchNearMe(lat: Double, lon: Double, completion: @escaping ([MosqueRef]) -> Void) {
        let api = "https://mawaqit.net/api/2.0/mosque/geolocation/\(lat)/\(lon)?page=1"
        tryAPI(urlString: api) { [weak self] refs in
            if !refs.isEmpty { completion(refs); return }
            let urlStr = "https://mawaqit.net/fr/find?latitude=\(lat)&longitude=\(lon)"
            self?.startWebNav(urlStr: urlStr, completion: completion)
        }
    }

    private func tryAPI(urlString: String, completion: @escaping ([MosqueRef]) -> Void) {
        guard let url = URL(string: urlString) else { completion([]); return }
        var req = URLRequest(url: url, timeoutInterval: 12)
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        req.setValue("Salat-Time/2.1 (macOS)", forHTTPHeaderField: "User-Agent")
        URLSession.shared.dataTask(with: req) { data, response, error in
            var refs: [MosqueRef] = []
            if let http = response as? HTTPURLResponse, http.statusCode == 200,
               let data = data,
               let obj = try? JSONSerialization.jsonObject(with: data) {
                refs = Self.parseAPIResponse(obj)
            }
            DispatchQueue.main.async { completion(refs) }
        }.resume()
    }

    /// Best-effort extraction of a clean city name from a free-form address
    /// line. Mawaqit's Morocco data often leaves the `city` field empty and
    /// stuffs the town name at the tail of `localisation` (e.g.
    /// "hay ryad 25000 KHOURIBGA" → "Khouribga"). This parser covers the
    /// patterns we've seen in the wild:
    ///   • "... NNNNN CITYNAME"         (postal code then city, any script)
    ///   • "..., CITYNAME"              (comma-separated — last segment)
    ///   • "... CITYNAME"               (trailing all-caps word in Latin)
    static func extractCityFromAddress(_ raw: String) -> String? {
        let s = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if s.isEmpty { return nil }
        // Pattern 1: trailing postal code followed by the city. We look for
        // 4–6 digits anywhere and take everything after the last such run.
        do {
            let re = try NSRegularExpression(
                pattern: #"\b\d{4,6}\s+([^\d,]+)$"#, options: [])
            let range = NSRange(s.startIndex..., in: s)
            if let m = re.firstMatch(in: s, options: [], range: range),
               let grp = Range(m.range(at: 1), in: s) {
                let cand = String(s[grp]).trimmingCharacters(in: .whitespaces)
                if cand.count >= 2 { return cand.capitalized }
            }
        } catch { /* regex should always compile */ }
        // Pattern 2: last comma-separated segment.
        if let commaIdx = s.range(of: ",", options: .backwards) {
            let tail = String(s[commaIdx.upperBound...])
                .trimmingCharacters(in: .whitespaces)
            if tail.count >= 2 && !tail.contains(where: { $0.isNumber }) {
                return tail.capitalized
            }
        }
        // Pattern 3: trailing all-caps Latin word (common in French data).
        let parts = s.split(whereSeparator: { $0 == " " || $0 == "\t" })
                     .map(String.init)
        if let last = parts.last,
           last.count >= 3,
           last == last.uppercased(),
           last != last.lowercased() {
            return last.capitalized
        }
        return nil
    }

    private static func parseAPIResponse(_ obj: Any) -> [MosqueRef] {
        var items: [[String: Any]] = []
        if let arr = obj as? [[String: Any]] {
            items = arr
        } else if let dict = obj as? [String: Any] {
            for key in ["data", "results", "items", "mosques"] {
                if let a = dict[key] as? [[String: Any]] { items = a; break }
            }
        }
        var refs: [MosqueRef] = []
        var seen = Set<String>()
        for it in items {
            let name = (it["label"] as? String) ?? (it["name"] as? String) ?? ""

            // Parse city and street address separately.
            //  - `city` may come as a plain string ("city"/"locality") or a
            //    nested dict {"name": "..."}.
            //  - `localisation` / `address` is the street address.
            var city = ""
            if let s = it["city"] as? String, !s.isEmpty { city = s }
            else if let ci = it["city"] as? [String: Any],
                    let n  = ci["name"] as? String, !n.isEmpty { city = n }
            else if let s = it["locality"] as? String, !s.isEmpty { city = s }

            var address = ""
            for k in ["localisation", "address", "street"] {
                if let s = it[k] as? String, !s.isEmpty { address = s; break }
            }

            // If the API didn't give us a clean city, try to pull one out
            // of the address string. CRUCIALLY: keep the address intact so
            // mosque cards still show the full street line underneath the
            // city, matching the Nearby look.
            if city.isEmpty, !address.isEmpty,
               let extracted = Self.extractCityFromAddress(address) {
                city = extracted
            }

            var urlStr = (it["url"] as? String) ?? ""
            if urlStr.isEmpty, let slug = it["slug"] as? String {
                urlStr = "https://mawaqit.net/fr/m/\(slug)"
            }
            if urlStr.isEmpty, let uuid = it["uuid"] as? String {
                urlStr = "https://mawaqit.net/fr/id/\(uuid)"
            }
            if name.isEmpty || urlStr.isEmpty { continue }

            // Coordinates — Mawaqit returns them either as Double or as a
            // stringified number, so accept both.
            func num(_ key: String) -> Double? {
                if let d = it[key] as? Double { return d }
                if let i = it[key] as? Int    { return Double(i) }
                if let s = it[key] as? String { return Double(s) }
                return nil
            }
            let lat = num("latitude") ?? num("lat")
            let lon = num("longitude") ?? num("lng") ?? num("lon")

            let norm = normalizeMosqueURL(urlStr)
            if seen.contains(norm) { continue }
            seen.insert(norm)
            refs.append(MosqueRef(name: name,
                                  city: city,
                                  url:  urlStr,
                                  address: address.isEmpty ? nil : address,
                                  lat: lat,
                                  lon: lon))
        }
        return refs
    }

    private func webScrapeSearch(word: String, completion: @escaping ([MosqueRef]) -> Void) {
        let enc = word.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? word
        startWebNav(urlStr: "https://mawaqit.net/fr/search?search=\(enc)", completion: completion)
    }

    private func startWebNav(urlStr: String, completion: @escaping ([MosqueRef]) -> Void) {
        guard let url = URL(string: urlStr) else { completion([]); return }
        self.completion = completion
        self.isValidationMode = false
        ensureWebView()
        timeoutTimer?.invalidate()
        timeoutTimer = Timer.scheduledTimer(withTimeInterval: 18, repeats: false) { [weak self] _ in
            self?.finishSearch(with: [])
        }
        webView?.load(URLRequest(url: url))
    }

    private func ensureWebView() {
        if webView != nil { return }
        let cfg = WKWebViewConfiguration()
        let wv = WKWebView(frame: NSRect(x: 0, y: 0, width: 1024, height: 768), configuration: cfg)
        wv.navigationDelegate = self
        webView = wv
    }

    func webView(_ wv: WKWebView, didFinish navigation: WKNavigation!) {
        if isValidationMode {
            runValidationExtraction()
        } else {
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.2) { [weak self, weak wv] in
                self?.runSearchExtraction(on: wv)
            }
        }
    }
    func webView(_ wv: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        if isValidationMode { finishValidation(with: nil) } else { finishSearch(with: []) }
    }
    func webView(_ wv: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        if isValidationMode { finishValidation(with: nil) } else { finishSearch(with: []) }
    }

    private func runSearchExtraction(on wv: WKWebView?) {
        let js = """
        (function() {
            var seen = {};
            var out = [];
            var anchors = document.querySelectorAll('a[href*="/m/"]');
            for (var i = 0; i < anchors.length; i++) {
                var a = anchors[i];
                var href = a.href || '';
                if (href.indexOf('/m/') < 0) continue;
                if (href.indexOf('mawaqit.net') < 0) continue;
                if (seen[href]) continue;
                seen[href] = true;
                var c = a.closest('li, article, .mosque, .mosque-card, .search-result, .result, div') || a;
                var name = (a.textContent || '').trim();
                if (!name) {
                    var h = c.querySelector('h1,h2,h3,h4,h5,.name,.title');
                    if (h) name = (h.textContent || '').trim();
                }
                if (!name) name = href.split('/m/').pop().replace(/-/g,' ');
                var city = '';
                var ce = c.querySelector('.city, .localisation, .address, small, .subtitle, p');
                if (ce) city = (ce.textContent || '').trim();
                if (name.length > 200) name = name.substring(0, 200);
                if (city.length > 200) city = city.substring(0, 200);
                out.push({name: name, city: city, url: href});
            }
            return JSON.stringify(out);
        })();
        """
        wv?.evaluateJavaScript(js) { [weak self] result, _ in
            var refs: [MosqueRef] = []
            if let s = result as? String,
               let data = s.data(using: .utf8),
               let arr = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] {
                var seen = Set<String>()
                for it in arr {
                    let name = (it["name"] as? String) ?? ""
                    let city = (it["city"] as? String) ?? ""
                    let url  = (it["url"] as? String) ?? ""
                    if name.isEmpty || url.isEmpty { continue }
                    let norm = normalizeMosqueURL(url)
                    if seen.contains(norm) { continue }
                    seen.insert(norm)
                    refs.append(MosqueRef(name: name, city: city, url: url))
                }
            }
            self?.finishSearch(with: refs)
        }
    }

    private func finishSearch(with refs: [MosqueRef]) {
        timeoutTimer?.invalidate(); timeoutTimer = nil
        let cb = completion
        completion = nil
        cb?(refs)
    }

    func validateURL(_ raw: String, completion: @escaping (MosqueRef?) -> Void) {
        guard isValidMawaqitURL(raw), let url = URL(string: raw.trimmingCharacters(in: .whitespacesAndNewlines)) else {
            completion(nil); return
        }
        isValidationMode = true
        validationCompletion = completion
        ensureWebView()
        timeoutTimer?.invalidate()
        timeoutTimer = Timer.scheduledTimer(withTimeInterval: 15, repeats: false) { [weak self] _ in
            self?.finishValidation(with: nil)
        }
        webView?.load(URLRequest(url: url))
    }

    private func runValidationExtraction() {
        let js = """
        (function() {
            try {
                var d = (typeof confData !== 'undefined') ? confData : null;
                if (!d && window.confData) d = window.confData;
                if (!d) return null;
                return JSON.stringify({
                    name: d.name || d.label || '',
                    localisation: d.localisation || d.association || ''
                });
            } catch (e) { return null; }
        })();
        """
        webView?.evaluateJavaScript(js) { [weak self] result, _ in
            guard let self = self else { return }
            guard let s = result as? String,
                  let data = s.data(using: .utf8),
                  let d = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                self.finishValidation(with: nil); return
            }
            let name = (d["name"] as? String) ?? ""
            let city = (d["localisation"] as? String) ?? ""
            if name.isEmpty { self.finishValidation(with: nil); return }
            let finalURL = self.webView?.url?.absoluteString ?? ""
            self.finishValidation(with: MosqueRef(name: name, city: city, url: finalURL))
        }
    }

    private func finishValidation(with ref: MosqueRef?) {
        timeoutTimer?.invalidate(); timeoutTimer = nil
        isValidationMode = false
        let cb = validationCompletion
        validationCompletion = nil
        cb?(ref)
    }
}

// ============================================================================
// MARK: City row — tappable group header in the Nearby tab
// ============================================================================
/// Tappable row that drills from the city list into the per-city mosque list.
/// Subclasses FlippedView so we keep the top-down coordinate space the rest
/// of the picker uses; the tap fires a Swift closure so the MosquePickerView
/// doesn't have to keep a keyed dictionary of cities → handlers.
final class CityRowView: FlippedView {
    var onTap: (() -> Void)?
    var cityName: String = ""
    override init(frame: NSRect) {
        super.init(frame: frame)
        wantsLayer = true
        layer?.cornerRadius = 8
        let click = NSClickGestureRecognizer(target: self, action: #selector(clicked))
        addGestureRecognizer(click)
    }
    required init?(coder: NSCoder) { fatalError() }
    @objc private func clicked() {
        // Quick visual pulse for tactile feedback, then drill in.
        let was = layer?.backgroundColor
        layer?.backgroundColor = NSColor(white: 0.5, alpha: 0.18).cgColor
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.10) { [weak self] in
            self?.layer?.backgroundColor = was
        }
        onTap?()
    }
    override func resetCursorRects() {
        super.resetCursorRects()
        addCursorRect(bounds, cursor: .pointingHand)
    }
}

// ============================================================================
// MARK: Hoverable mosque row — shows a richer popup on mouse hover
// ============================================================================
/// Row used in the Search / Nearby / Favorites result lists. When the mouse
/// lingers over the row, macOS shows a multi-line tooltip that reveals the
/// mosque's full name, city, street address, and URL — without truncation.
final class HoverablePickerRow: FlippedView {
    var mosque: MosqueRef? {
        didSet { updateRichToolTip() }
    }

    /// Build and assign a multi-line tooltip so hovering over the row shows
    /// a "popup" with every detail, even ones that are truncated in the card.
    private func updateRichToolTip() {
        guard let m = mosque else { toolTip = nil; return }
        var parts: [String] = []
        parts.append(m.name)
        if !m.city.isEmpty { parts.append("📍 \(m.city)") }
        if let addr = m.address, !addr.isEmpty { parts.append("🏠 \(addr)") }
        // Show the **desktop** URL here — that's what the "open" button uses
        // and it's the URL the user actually wants to see in their browser.
        parts.append("🔗 \(desktopMawaqitURL(m.url))")
        let text = parts.joined(separator: "\n")
        // Apply the same tooltip to the whole row AND its subviews so hovering
        // over a child label also reveals the popup (AppKit doesn't walk up
        // the view hierarchy when deciding which tooltip to show).
        toolTip = text
        for sub in subviews { sub.toolTip = text }
    }

    /// Re-apply the tooltip to any child views that were added after the
    /// mosque was assigned. Called from `didAddSubview` so dynamic layouts
    /// don't miss the rich tooltip.
    override func didAddSubview(_ subview: NSView) {
        super.didAddSubview(subview)
        subview.toolTip = toolTip
    }
}

// ============================================================================
// MARK: Mosque picker view
// ============================================================================
final class MosquePickerView: FlippedView, NSTextFieldDelegate, CLLocationManagerDelegate {
    weak var appDelegate: AppDelegate?
    var onDone: (() -> Void)?
    private let showsNavigationHeader: Bool

    private let segmented = NSSegmentedControl()
    private let titleLbl  = NSTextField(labelWithString: t("picker.title"))
    private var backBtn: HoverIconButton!
    private let inputContainer = FlippedView()
    private let statusLabel = NSTextField(labelWithString: "")
    private let scrollView  = NSScrollView()
    private let resultsStack = NSStackView()

    private let searchField = NSTextField()
    private let goSearchBtn = NSButton(title: t("picker.btn.search"), target: nil, action: nil)
    private let urlField    = NSTextField()
    private let addUrlBtn   = NSButton(title: t("picker.btn.add"), target: nil, action: nil)
    // Nearby tab: an editable "your city" text field + a location icon button.
    // Typing a city and hitting Enter runs the search by city name (the same
    // pipeline the Search tab uses). The location button reverse-geocodes the
    // device coordinates into a city name and feeds that string into the same
    // search so it never comes up empty when there are mosques nearby.
    private let cityField   = NSTextField()
    private let nearMeBtn   = NSButton(title: "", target: nil, action: nil)

    private let search = MosqueSearch()
    private var locationManager: CLLocationManager?
    private var mode: Int = 0
    private var scrollWidth: CGFloat = 0

    // ---------- Nearby drill-down state --------------------------------------
    // The Nearby tab first shows a list of *cities* derived from the mosques
    // returned by the geolocation API. Tapping a city switches to an in-city
    // list with a "Back to cities" row at the top. `nearbyRefs` caches the
    // full list so we don't re-request location + re-hit the API each time
    // the user drills in/out.
    private enum NearbyState {
        case idle                 // Before geo fetch completes.
        case results              // Showing the flat distance-sorted list.
    }
    private var nearbyState: NearbyState = .idle
    private var nearbyRefs: [MosqueRef] = []
    private var nearbyCoord: (lat: Double, lon: Double)?

    // ---------- Search-as-you-type state -------------------------------------
    // Debounce live keystrokes so we don't fire an HTTP request on every
    // character. 300 ms is the sweet spot that feels responsive without
    // drowning the API in noise from fast typists.
    private var searchDebounceTimer: Timer?
    private static let searchDebounceInterval: TimeInterval = 0.30
    /// Query string for which the current visible result list was rendered.
    /// We use this to drop out-of-order live-search responses when the user
    /// has moved on to a newer query mid-request.
    private var lastLiveQuery: String = ""

    // ---------- Search tab: country → city → mosques drill-down --------------
    struct PickerCountry { let code: String; let name: String; let flag: String }
    /// Curated list of countries where Mawaqit has good mosque coverage.
    /// Ordered alphabetically by English name so the list is easy to scan.
    private static let pickerCountries: [PickerCountry] = [
        PickerCountry(code: "DZ", name: "Algeria",        flag: "🇩🇿"),
        PickerCountry(code: "AU", name: "Australia",      flag: "🇦🇺"),
        PickerCountry(code: "BD", name: "Bangladesh",     flag: "🇧🇩"),
        PickerCountry(code: "BE", name: "Belgium",        flag: "🇧🇪"),
        PickerCountry(code: "CA", name: "Canada",         flag: "🇨🇦"),
        PickerCountry(code: "DK", name: "Denmark",        flag: "🇩🇰"),
        PickerCountry(code: "EG", name: "Egypt",          flag: "🇪🇬"),
        PickerCountry(code: "FR", name: "France",         flag: "🇫🇷"),
        PickerCountry(code: "DE", name: "Germany",        flag: "🇩🇪"),
        PickerCountry(code: "IN", name: "India",          flag: "🇮🇳"),
        PickerCountry(code: "ID", name: "Indonesia",      flag: "🇮🇩"),
        PickerCountry(code: "IT", name: "Italy",          flag: "🇮🇹"),
        PickerCountry(code: "KW", name: "Kuwait",         flag: "🇰🇼"),
        PickerCountry(code: "MY", name: "Malaysia",       flag: "🇲🇾"),
        PickerCountry(code: "MA", name: "Morocco",        flag: "🇲🇦"),
        PickerCountry(code: "NL", name: "Netherlands",    flag: "🇳🇱"),
        PickerCountry(code: "NO", name: "Norway",         flag: "🇳🇴"),
        PickerCountry(code: "PK", name: "Pakistan",       flag: "🇵🇰"),
        PickerCountry(code: "PT", name: "Portugal",       flag: "🇵🇹"),
        PickerCountry(code: "QA", name: "Qatar",          flag: "🇶🇦"),
        PickerCountry(code: "SA", name: "Saudi Arabia",   flag: "🇸🇦"),
        PickerCountry(code: "ZA", name: "South Africa",   flag: "🇿🇦"),
        PickerCountry(code: "ES", name: "Spain",          flag: "🇪🇸"),
        PickerCountry(code: "SE", name: "Sweden",         flag: "🇸🇪"),
        PickerCountry(code: "CH", name: "Switzerland",    flag: "🇨🇭"),
        PickerCountry(code: "TN", name: "Tunisia",        flag: "🇹🇳"),
        PickerCountry(code: "TR", name: "Turkey",         flag: "🇹🇷"),
        PickerCountry(code: "AE", name: "UAE",            flag: "🇦🇪"),
        PickerCountry(code: "GB", name: "United Kingdom", flag: "🇬🇧"),
        PickerCountry(code: "US", name: "United States",  flag: "🇺🇸"),
    ]
    private enum SearchState {
        case countries                              // Root list of countries.
        case cities(PickerCountry)                  // Cities in the chosen country.
        case mosques(PickerCountry, String)         // Mosques in a chosen city.
    }
    private var searchState: SearchState = .countries
    /// Accumulating cache of cities for the country the user is currently
    /// browsing. NEW results get merged in (never replace) so the list grows
    /// as the user types. Keys are normalised (lowercased, trimmed) city
    /// names; `searchCityOrder` preserves first-seen order for display.
    private var searchCityBucket: [String: [MosqueRef]] = [:]
    private var searchCityOrder:  [String] = []
    /// Tracks which country the current bucket was built for so we know when
    /// to reset vs. reuse it across back/forward navigation.
    private var searchCountryCode: String? = nil

    init(width: CGFloat, height: CGFloat, showsNavigationHeader: Bool = true) {
        self.showsNavigationHeader = showsNavigationHeader
        super.init(frame: NSRect(x: 0, y: 0, width: width, height: height))
        build()
        refreshCurrentMode()
    }
    required init?(coder: NSCoder) { fatalError() }

    private func build() {
        let W = bounds.width, H = bounds.height

        // -------------------- Header: back + title -------------------------
        if showsNavigationHeader {
            backBtn = HoverIconButton(
                symbol: backChevronSymbol,
                toolTip: t("tooltip.back"),
                target: self,
                action: #selector(backTapped),
                pointSize: 14,
                size: NSSize(width: 44, height: 44))
            backBtn.setFrameOrigin(NSPoint(x: 6, y: 2))
            addSubview(backBtn)

            titleLbl.frame = NSRect(x: 60, y: 14, width: W - 120, height: 20)
            titleLbl.font = Localizer.shared.font(size: 13, weight: .semibold)
            titleLbl.alignment = .center
            titleLbl.textColor = .labelColor
            titleLbl.drawsBackground = false
            fitLocalizedLabel(titleLbl)
            addSubview(titleLbl)

            // Hairline under the title bar for visual separation.
            let hdrSep = NSBox(frame: NSRect(x: 12, y: 42, width: W - 24, height: 1))
            hdrSep.boxType = .separator
            addSubview(hdrSep)
        }

        // -------------------- Segmented tab bar ---------------------------
        // 4 segments across W-24 with monotone SF-Symbol glyphs only (no
        // text labels — sub-labels were removed to reclaim vertical space).
        // Tooltips explain each tab.
        let segCount = 4
        let segTotal = W - 24
        let segW = segTotal / CGFloat(segCount)
        segmented.segmentCount = segCount
        let segSymbols  = ["star.fill", "magnifyingglass", "location.fill", "link"]
        let segTooltips = [t("picker.tab.favorites"),
                           t("picker.tab.search"),
                           t("picker.tab.near"),
                           t("picker.tab.url")]
        for (i, s) in segSymbols.enumerated() {
            if let img = templateSymbol(s, pointSize: 13, weight: .medium) {
                segmented.setImage(img, forSegment: i)
            } else {
                // Fallback to a short text label
                segmented.setLabel(["Fav", "Find", "Near", "URL"][i], forSegment: i)
            }
            segmented.setToolTip(segTooltips[i], forSegment: i)
            segmented.setWidth(segW, forSegment: i)
        }
        segmented.segmentStyle = .texturedRounded
        segmented.selectedSegment = 0
        segmented.target = self
        segmented.action = #selector(segmentChanged)
        segmented.frame = NSRect(x: 12, y: showsNavigationHeader ? 50 : 10,
                                 width: segTotal, height: 30)
        segmented.setAccessibilityLabel(t("settings.section.mosque"))
        addSubview(segmented)

        // Status / help line. Dynamically shows the active tab's hint text,
        // the search-in-progress message, or a result count.
        statusLabel.frame = NSRect(x: 12, y: showsNavigationHeader ? 80 : 46,
                                   width: W - 24, height: 18)
        statusLabel.font = Localizer.shared.font(size: 10)
        statusLabel.textColor = .secondaryLabelColor
        statusLabel.drawsBackground = false
        statusLabel.alignment = .center
        statusLabel.lineBreakMode = .byTruncatingTail
        statusLabel.autoresizingMask = [.width]
        addSubview(statusLabel)

        // -------------------- Input area ----------------------------------
        inputContainer.frame = NSRect(x: 12, y: showsNavigationHeader ? 100 : 68,
                                      width: W - 24, height: 44)
        inputContainer.autoresizingMask = [.width]
        addSubview(inputContainer)

        let iw = inputContainer.bounds.width

        // Compact Go / Add icon buttons (arrow.right in a 30×26 pill) leave
        // the textfield with most of the row. All-icon to honour the
        // monotone-icon rule.
        let btnW: CGFloat = 44

        searchField.frame = NSRect(x: 0, y: 8, width: iw - btnW - 4, height: 28)
        searchField.placeholderString = t("picker.placeholder.search")
        searchField.font = Localizer.shared.font(size: 12)
        searchField.delegate = self
        searchField.target = self
        searchField.action = #selector(runSearch)
        searchField.autoresizingMask = [.width]
        // `controlTextDidChange(_:)` fires on every keystroke through the
        // NSControlTextDidChange notification; `isContinuous = true` is the
        // belt-and-suspenders switch for older AppKit paths.
        searchField.isContinuous = true

        goSearchBtn.frame = NSRect(x: iw - btnW, y: 0, width: btnW, height: 44)
        goSearchBtn.bezelStyle = .rounded
        goSearchBtn.title = ""
        goSearchBtn.target = self
        goSearchBtn.action = #selector(runSearch)
        goSearchBtn.keyEquivalent = "\r"
        goSearchBtn.autoresizingMask = [.minXMargin]
        goSearchBtn.toolTip = t("picker.btn.search")
        goSearchBtn.setAccessibilityLabel(t("picker.btn.search"))
        if let img = templateSymbol("magnifyingglass", pointSize: 12, weight: .semibold) {
            goSearchBtn.image = img
            goSearchBtn.imagePosition = .imageOnly
        }

        urlField.frame = NSRect(x: 0, y: 8, width: iw - btnW - 4, height: 28)
        urlField.placeholderString = "mawaqit.net/fr/m/…"
        urlField.font = Localizer.shared.font(size: 12)
        urlField.target = self
        urlField.action = #selector(runAddURL)
        urlField.autoresizingMask = [.width]

        addUrlBtn.frame = NSRect(x: iw - btnW, y: 0, width: btnW, height: 44)
        addUrlBtn.bezelStyle = .rounded
        addUrlBtn.title = ""
        addUrlBtn.target = self
        addUrlBtn.action = #selector(runAddURL)
        addUrlBtn.keyEquivalent = "\r"
        addUrlBtn.autoresizingMask = [.minXMargin]
        addUrlBtn.toolTip = t("picker.btn.add")
        addUrlBtn.setAccessibilityLabel(t("picker.btn.add"))
        if let img = templateSymbol("plus", pointSize: 12, weight: .semibold) {
            addUrlBtn.image = img
            addUrlBtn.imagePosition = .imageOnly
        }

        // Nearby: compact [city text field][location icon button] row. The
        // icon button on the right reverse-geocodes the device location into
        // a city name and runs the same search the text field does — so the
        // UX stays uniform regardless of whether the city is typed or
        // detected automatically.
        cityField.frame = NSRect(x: 0, y: 8, width: iw - btnW - 4, height: 28)
        cityField.placeholderString = t("picker.placeholder.city")
        cityField.font = Localizer.shared.font(size: 12)
        cityField.delegate = self
        cityField.target = self
        cityField.action = #selector(runCitySearch)
        cityField.autoresizingMask = [.width]
        cityField.stringValue = userCity()

        nearMeBtn.frame = NSRect(x: iw - btnW, y: 0, width: btnW, height: 44)
        nearMeBtn.bezelStyle = .rounded
        nearMeBtn.title = ""
        nearMeBtn.target = self
        nearMeBtn.action = #selector(runNearMe)
        nearMeBtn.keyEquivalent = ""
        nearMeBtn.autoresizingMask = [.minXMargin]
        nearMeBtn.toolTip = t("picker.btn.near")
        nearMeBtn.setAccessibilityLabel(t("picker.btn.near"))
        if let img = templateSymbol("location.fill", pointSize: 12, weight: .semibold) {
            nearMeBtn.image = img
            nearMeBtn.imagePosition = .imageOnly
        }

        // -------------------- Results scroll view -------------------------
        let resultsY: CGFloat = showsNavigationHeader ? 152 : 120
        scrollView.frame = NSRect(x: 12, y: resultsY, width: W - 24,
                                  height: H - resultsY - 12)
        scrollView.hasVerticalScroller = true
        scrollView.drawsBackground = false
        scrollView.borderType = .noBorder
        scrollView.autohidesScrollers = true
        scrollView.autoresizingMask = [.width, .height]
        // Document inside scroll view is slightly narrower than the frame to
        // leave room for the optional scroller + 2px breathing room.
        scrollWidth = scrollView.frame.width - 18

        resultsStack.orientation = .vertical
        resultsStack.spacing = 6
        resultsStack.alignment = .leading
        resultsStack.edgeInsets = NSEdgeInsets(top: 4, left: 2, bottom: 4, right: 2)
        resultsStack.translatesAutoresizingMaskIntoConstraints = false

        let doc = FlippedView()
        doc.translatesAutoresizingMaskIntoConstraints = false
        doc.addSubview(resultsStack)
        scrollView.documentView = doc
        NSLayoutConstraint.activate([
            doc.widthAnchor.constraint(equalTo: scrollView.widthAnchor, constant: -2),
            resultsStack.topAnchor.constraint(equalTo: doc.topAnchor),
            resultsStack.leadingAnchor.constraint(equalTo: doc.leadingAnchor),
            resultsStack.trailingAnchor.constraint(equalTo: doc.trailingAnchor),
            resultsStack.bottomAnchor.constraint(equalTo: doc.bottomAnchor),
        ])
        addSubview(scrollView)

        // RTL: recursive mirror + native control direction.
        if Localizer.shared.isRTL {
            applyRTL(self)
        }
    }

    func refreshCurrentMode() {
        updateInputContainer()
        switch mode {
        case 0: showFavorites()
        case 1: showSearchPrompt()
        case 2: showNearMePrompt()
        case 3: showUrlPrompt()
        default: break
        }
    }

    @objc private func backTapped() { onDone?() }
    @objc private func segmentChanged() { mode = segmented.selectedSegment; refreshCurrentMode() }

    private func updateInputContainer() {
        inputContainer.subviews.forEach { $0.removeFromSuperview() }
        // Whenever we leave a tab, cancel any work in flight so results from
        // the previous tab can't land in the newly-visible list.
        searchDebounceTimer?.invalidate()
        searchDebounceTimer = nil
        search.cancelLiveSearch()
        switch mode {
        case 0: break
        case 1:
            // In the country-list root we don't show any input — picking a
            // country is the only valid action. In city or mosque states we
            // show the search field (repurposed as a city filter).
            switch searchState {
            case .countries:
                break
            case .cities:
                inputContainer.addSubview(searchField)
                inputContainer.addSubview(goSearchBtn)
                window?.makeFirstResponder(searchField)
            case .mosques:
                break
            }
        case 2:
            inputContainer.addSubview(cityField)
            inputContainer.addSubview(nearMeBtn)
            // Pre-fill with the saved city so the user sees their previous
            // choice without having to re-type it.
            cityField.stringValue = userCity()
            window?.makeFirstResponder(cityField)
        case 3:
            inputContainer.addSubview(urlField)
            inputContainer.addSubview(addUrlBtn)
            window?.makeFirstResponder(urlField)
        default: break
        }
    }

    private func showFavorites() {
        clearResults()
        let favs = loadFavorites()
        if favs.isEmpty {
            statusLabel.stringValue = "No favorites yet. Add from Search, Near me, or By URL."
            return
        }
        statusLabel.stringValue = "\(favs.count) favorite\(favs.count == 1 ? "" : "s")"
        for f in favs {
            resultsStack.addArrangedSubview(makeRow(for: f, fromFavorites: true))
        }
    }
    private func showSearchPrompt() {
        // Drill-down: countries → cities → mosques. Each state re-renders
        // `resultsStack` with the appropriate row type. Switching tabs keeps
        // the current state so the user doesn't lose their place.
        switch searchState {
        case .countries:
            showCountriesList()
        case .cities(let country):
            showCitiesList(in: country)
        case .mosques(let country, let city):
            showMosquesList(country: country, city: city)
        }
    }

    /// Root of the Search tab: list every curated country as a tappable row.
    private func showCountriesList() {
        clearResults()
        searchField.stringValue = ""
        statusLabel.stringValue = "Pick a country to see its cities"
        for c in MosquePickerView.pickerCountries {
            resultsStack.addArrangedSubview(makeCountryRow(country: c))
        }
    }

    /// List of cities in `country`. The list is pulled live from the Mawaqit
    /// text-search API and then **filtered client-side** by the search field.
    /// The bucket accumulates across keystrokes so typing narrows the already-
    /// shown list instantly while the API enriches it in the background.
    private func showCitiesList(in country: PickerCountry) {
        clearResults()
        searchField.placeholderString = "Filter cities in \(country.name)"
        // Back row pinned at the top of the results stack.
        resultsStack.addArrangedSubview(
            makeBackRow(label: "← Back to countries") { [weak self] in
                self?.searchState = .countries
                self?.updateInputContainer()
                self?.showSearchPrompt()
            })
        // If we already have a cached list for this country (e.g. the user
        // tapped a city then came back), re-render it immediately.
        if searchCountryCode == country.code && !searchCityOrder.isEmpty {
            renderFilteredCityList(country: country)
        } else {
            // Fresh visit — reset the accumulator and fire the initial load.
            searchCityBucket.removeAll()
            searchCityOrder.removeAll()
            searchCountryCode = country.code
            statusLabel.stringValue = "Loading cities in \(country.name)…"
        }
        // Always kick a country-seeded query to pull in (more) cities.
        let q = searchField.stringValue.trimmingCharacters(in: .whitespaces)
        let seed = q.isEmpty ? country.name : "\(q) \(country.name)"
        liveCitySearch(seed, country: country)
    }

    /// Mosques in a given city within the selected country. Pulls from the
    /// `searchCityBucket` cache populated during the city-list step so this
    /// view is instantaneous once the city list has been fetched.
    private func showMosquesList(country: PickerCountry, city: String) {
        clearResults()
        let key = city.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        let mosques = searchCityBucket[key] ?? []
        statusLabel.stringValue =
            "\(mosques.count) \(mosques.count == 1 ? "mosque" : "mosques") in \(city), \(country.name)"
        resultsStack.addArrangedSubview(
            makeBackRow(label: "← Back to cities") { [weak self] in
                self?.searchState = .cities(country)
                self?.updateInputContainer()
                self?.showSearchPrompt()
            })
        for m in mosques {
            resultsStack.addArrangedSubview(makeRow(for: m, fromFavorites: false))
        }
    }

    /// Run a Mawaqit text search scoped to `country`. When results come back
    /// we MERGE them into `searchCityBucket` (never replacing) and re-render
    /// the list with the current filter applied. Stale-response guarded via
    /// `lastLiveQuery` so a slower prior request can't clobber a newer one.
    private func liveCitySearch(_ q: String, country: PickerCountry) {
        lastLiveQuery = q
        search.searchTextLive(q) { [weak self] refs in
            guard let self = self else { return }
            if case .cities(let cur) = self.searchState, cur.code == country.code {
                if self.lastLiveQuery != q { return }
                self.mergeIntoCityBucket(refs, country: country)
                self.renderFilteredCityList(country: country)
            }
        }
    }

    /// Fold `refs` into the persistent city bucket for `country`. De-dupes
    /// mosques by normalised URL and preserves the first-seen order so the
    /// list feels stable as new API results trickle in.
    private func mergeIntoCityBucket(_ refs: [MosqueRef], country: PickerCountry) {
        if searchCountryCode != country.code {
            searchCityBucket.removeAll()
            searchCityOrder.removeAll()
            searchCountryCode = country.code
        }
        for r in refs {
            let raw = r.city.trimmingCharacters(in: .whitespacesAndNewlines)
            let display = raw.isEmpty ? "Other" : raw
            let key = display.lowercased()
            if searchCityBucket[key] == nil { searchCityOrder.append(key) }
            var list = searchCityBucket[key] ?? []
            if !list.contains(r) { list.append(r) }
            searchCityBucket[key] = list
        }
    }

    /// Render the city list using the current `searchField` text as a
    /// substring filter. The back row at index 0 is preserved. Called on
    /// every keystroke (instant local filter) and after every API response.
    private func renderFilteredCityList(country: PickerCountry) {
        // Drop every existing row except the back row at index 0.
        while resultsStack.arrangedSubviews.count > 1 {
            let v = resultsStack.arrangedSubviews[1]
            resultsStack.removeArrangedSubview(v)
            v.removeFromSuperview()
        }
        if searchCityOrder.isEmpty {
            statusLabel.stringValue = "Loading cities in \(country.name)…"
            return
        }
        let filterRaw = searchField.stringValue
            .trimmingCharacters(in: .whitespaces)
        let filter = filterRaw.lowercased()
        let matchingKeys: [String] = searchCityOrder.filter { key in
            if filter.isEmpty { return true }
            // Match against both the key and the display name so users
            // typing with diacritics still hit the intended row.
            let display = (searchCityBucket[key]?.first?.city ?? "").lowercased()
            return key.contains(filter) || display.contains(filter)
        }
        // Alphabetical by display name — predictable scanning for the user.
        let sortedKeys = matchingKeys.sorted { lhs, rhs in
            let l = searchCityBucket[lhs]?.first?.city.lowercased() ?? lhs
            let r = searchCityBucket[rhs]?.first?.city.lowercased() ?? rhs
            return l < r
        }
        if sortedKeys.isEmpty {
            statusLabel.stringValue =
                "No city matches “\(filterRaw)” in \(country.name) yet — keep typing…"
            return
        }
        let totalMosques = sortedKeys.reduce(0) {
            $0 + (searchCityBucket[$1]?.count ?? 0)
        }
        let cityWord = sortedKeys.count == 1 ? "city" : "cities"
        let mosqueWord = totalMosques == 1 ? "mosque" : "mosques"
        statusLabel.stringValue =
            "\(sortedKeys.count) \(cityWord), \(totalMosques) \(mosqueWord) in \(country.name) — tap a city"
        for key in sortedKeys {
            let display = searchCityBucket[key]?.first?.city
                .trimmingCharacters(in: .whitespacesAndNewlines)
            let shown = (display?.isEmpty ?? true) ? "Other" : display!
            let count = searchCityBucket[key]?.count ?? 0
            resultsStack.addArrangedSubview(
                makeCityRowForSearch(city: shown, count: count, country: country))
        }
    }
    private func showNearMePrompt() {
        // Re-entering the tab with a fresh-enough cache keeps the previous
        // view so the user doesn't lose context to a spinner every tab-switch.
        switch nearbyState {
        case .idle:
            let saved = userCity()
            clearResults()
            if saved.isEmpty {
                statusLabel.stringValue =
                    "Type your city or tap the location button to detect it."
            } else {
                // Auto-run the saved city so returning users see results
                // immediately without having to press Enter again.
                runNearbyCityQuery(saved, origin: .typed)
            }
        case .results:
            let label = cityField.stringValue.trimmingCharacters(in: .whitespaces)
            showNearbyFlat(cityLabel: label.isEmpty ? userCity() : label)
        }
    }
    private func showUrlPrompt() {
        clearResults()
        statusLabel.stringValue = "Paste a Mawaqit mosque URL."
    }

    @objc private func runSearch() {
        // Only relevant while in the cities state. Enter key re-runs the
        // current typed text through the country-scoped typeahead.
        guard case .cities(let country) = searchState else { return }
        let q = searchField.stringValue.trimmingCharacters(in: .whitespaces)
        searchDebounceTimer?.invalidate()
        searchDebounceTimer = nil
        search.cancelLiveSearch()
        let seed = q.isEmpty ? country.name : "\(q) \(country.name)"
        liveCitySearch(seed, country: country)
    }

    // NSTextFieldDelegate — every keystroke in the Search tab's city field
    // does two things: (1) an instant client-side filter on the cached city
    // list so the UI responds immediately, and (2) a debounced API call to
    // pull more cities matching the new query into the bucket. The URL tab
    // shares the delegate but we ignore edits from other fields.
    func controlTextDidChange(_ obj: Notification) {
        guard let tf = obj.object as? NSTextField, tf === searchField else { return }
        guard case .cities(let country) = searchState else { return }
        // 1. Instant local filter — feels snappy even with 0 network.
        renderFilteredCityList(country: country)
        // 2. Schedule the API enrichment.
        let q = tf.stringValue.trimmingCharacters(in: .whitespaces)
        searchDebounceTimer?.invalidate()
        searchDebounceTimer = nil
        let seed = q.isEmpty ? country.name : "\(q) \(country.name)"
        searchDebounceTimer = Timer.scheduledTimer(
            withTimeInterval: MosquePickerView.searchDebounceInterval,
            repeats: false
        ) { [weak self] _ in
            self?.liveCitySearch(seed, country: country)
        }
    }

    @objc private func runAddURL() {
        let raw = urlField.stringValue.trimmingCharacters(in: .whitespaces)
        guard isValidMawaqitURL(raw) else {
            statusLabel.stringValue = "Not a valid Mawaqit URL."
            return
        }
        clearResults()
        statusLabel.stringValue = "Validating URL…"
        search.validateURL(raw) { [weak self] ref in
            guard let self = self else { return }
            guard let ref = ref else {
                self.statusLabel.stringValue = "Could not load mosque at that URL."
                return
            }
            self.showResults([ref], emptyMsg: "")
            self.statusLabel.stringValue = "Found \"\(ref.name)\"."
        }
    }

    /// Trigger the city-name search pipeline. Called when the user presses
    /// Enter in the city field or when the reverse-geocoder hands us a city.
    /// This goes through the *same* API path as the Search tab, which is the
    /// pipeline that actually returns results — the Mawaqit
    /// `/mosque/geolocation/{lat}/{lon}` endpoint has been coming back empty,
    /// so we pivot to lat/lon → city name → name search.
    @objc private func runCitySearch() {
        let q = cityField.stringValue.trimmingCharacters(in: .whitespaces)
        guard !q.isEmpty else {
            statusLabel.stringValue = "Type a city, or tap the location button to detect it."
            return
        }
        setUserCity(q)
        runNearbyCityQuery(q, origin: .typed)
    }

    /// Geolocate → reverse-geocode → city-name search. We hit CLGeocoder
    /// (not Mawaqit) so the "No mosques near me" dead end we were hitting
    /// turns into a real city name that the proven text-search pipeline
    /// can match against.
    @objc private func runNearMe() {
        nearbyState = .idle
        nearbyRefs = []
        nearbyCoord = nil
        clearResults()
        // If the user already has a saved city, use it as an immediate
        // response while the location request is in flight so the list
        // isn't blank for several seconds.
        let saved = userCity()
        if !saved.isEmpty {
            statusLabel.stringValue = "Using your saved city \"\(saved)\" while checking location…"
            runNearbyCityQuery(saved, origin: .savedPendingGeo)
        } else {
            statusLabel.stringValue = "Requesting your location…"
        }
        let lm = CLLocationManager()
        lm.delegate = self
        lm.desiredAccuracy = kCLLocationAccuracyHundredMeters
        locationManager = lm
        if #available(macOS 10.15, *) {
            lm.requestLocation()
        } else {
            lm.startUpdatingLocation()
        }
    }

    func locationManager(_ m: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        if status == .denied || status == .restricted {
            statusLabel.stringValue = "Location denied. Type your city above, or enable Location in System Settings → Privacy."
        }
    }

    func locationManager(_ m: CLLocationManager, didUpdateLocations locs: [CLLocation]) {
        guard let loc = locs.first else { return }
        m.stopUpdatingLocation()
        let lat = loc.coordinate.latitude, lon = loc.coordinate.longitude
        nearbyCoord = (lat, lon)
        statusLabel.stringValue = localizedInterfaceDigits(
            String(format: "Identifying your city (%.3f, %.3f)…", lat, lon))

        // Reverse-geocode with Apple's geocoder — CLPlacemark gives us a
        // proper locality/subLocality string that Mawaqit's name search can
        // match against. Fall back through progressively coarser names if
        // the precise locality comes back nil.
        let gc = CLGeocoder()
        gc.reverseGeocodeLocation(loc) { [weak self] placemarks, err in
            guard let self = self, self.mode == 2 else { return }
            let pm = placemarks?.first
            let candidates = [
                pm?.locality,
                pm?.subLocality,
                pm?.subAdministrativeArea,
                pm?.administrativeArea,
                pm?.country,
            ].compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
             .filter { !$0.isEmpty }
            guard let city = candidates.first else {
                if err != nil {
                    self.statusLabel.stringValue = "Couldn't identify your city. Type it in the field above."
                } else {
                    self.statusLabel.stringValue = "No city name for this location. Type one above."
                }
                return
            }
            // Persist so the next session starts from the detected city even
            // without re-running location. If the user typed a different
            // city while geocoding was in flight, don't clobber their input.
            let typed = self.cityField.stringValue.trimmingCharacters(in: .whitespaces)
            if typed.isEmpty || typed.caseInsensitiveCompare(userCity()) == .orderedSame {
                setUserCity(city)
                self.cityField.stringValue = city
            }
            self.runNearbyCityQuery(city, origin: .geocoded)
        }
    }

    func locationManager(_ m: CLLocationManager, didFailWithError err: Error) {
        // If the user has a saved city we've already started searching with,
        // don't clobber the in-progress status with a scary error — just
        // tell them location was unavailable.
        if userCity().isEmpty {
            statusLabel.stringValue = "Location error: \(err.localizedDescription). Type your city above."
        }
    }

    /// Which code path seeded the current nearby lookup — used to fine-tune
    /// status messages without duplicating the result-handling logic.
    private enum NearbyOrigin {
        case typed              // User hit Enter in the cityField
        case geocoded           // CLGeocoder returned a locality
        case savedPendingGeo    // Saved city, shown while location fetches
    }

    /// Push a city name through the existing text-search pipeline, then show
    /// a flat list of mosques sorted from closest to farthest using the
    /// device location (when available). All three origins (typed / geocoded
    /// / saved) funnel through here so the result handling stays consistent.
    private func runNearbyCityQuery(_ city: String, origin: NearbyOrigin) {
        clearResults()
        statusLabel.stringValue = "Searching mosques in \"\(city)\"…"
        search.searchText(city) { [weak self] refs in
            guard let self = self, self.mode == 2 else { return }
            self.nearbyRefs = self.sortByDistance(refs)
            if self.nearbyRefs.isEmpty {
                self.nearbyState = .idle
                self.clearResults()
                self.statusLabel.stringValue =
                    "No mosques found for \"\(city)\". Try a nearby city name."
                return
            }
            self.nearbyState = .results
            self.showNearbyFlat(cityLabel: city)
        }
    }

    // ---------- Nearby: flat distance-sorted list -----------------------------

    /// Return `refs` sorted by Haversine distance from the user's detected
    /// location, closest first. Mosques without coordinates are kept in
    /// their original order at the tail of the list.
    private func sortByDistance(_ refs: [MosqueRef]) -> [MosqueRef] {
        guard let uc = nearbyCoord else { return refs }
        let withCoord    = refs.filter { $0.lat != nil && $0.lon != nil }
        let withoutCoord = refs.filter { $0.lat == nil || $0.lon == nil }
        let sorted = withCoord.sorted {
            haversineKm(lat1: uc.lat, lon1: uc.lon, lat2: $0.lat!, lon2: $0.lon!) <
            haversineKm(lat1: uc.lat, lon1: uc.lon, lat2: $1.lat!, lon2: $1.lon!)
        }
        return sorted + withoutCoord
    }

    /// Great-circle distance in kilometres between two lat/lon points.
    private func haversineKm(lat1: Double, lon1: Double,
                             lat2: Double, lon2: Double) -> Double {
        let R = 6371.0
        let φ1 = lat1 * .pi / 180, φ2 = lat2 * .pi / 180
        let dφ = (lat2 - lat1) * .pi / 180
        let dλ = (lon2 - lon1) * .pi / 180
        let a = sin(dφ/2) * sin(dφ/2) +
                cos(φ1) * cos(φ2) * sin(dλ/2) * sin(dλ/2)
        return 2 * R * atan2(sqrt(a), sqrt(1 - a))
    }

    /// Render a flat list of every mosque in `nearbyRefs` (already sorted by
    /// distance when possible). The header tells the user how many we found
    /// and which city seed we used.
    private func showNearbyFlat(cityLabel: String) {
        clearResults()
        if nearbyRefs.isEmpty {
            statusLabel.stringValue = "No mosques found near you."
            return
        }
        let n = nearbyRefs.count
        let sortedNote = (nearbyCoord != nil && nearbyRefs.contains(where: { $0.lat != nil })) ?
            ", sorted by distance" : ""
        statusLabel.stringValue =
            "\(n) \(n == 1 ? "mosque" : "mosques") near \(cityLabel)\(sortedNote)"
        for r in nearbyRefs {
            resultsStack.addArrangedSubview(makeRow(for: r, fromFavorites: false))
        }
    }

    /// Small "← Back to X" affordance used at the top of city/mosque lists.
    /// Styled to be visually subtle so it doesn't compete with the real
    /// result cards below it.
    private func makeBackRow(label: String, onTap: @escaping () -> Void) -> NSView {
        let rowW = scrollWidth - 4
        let rowH: CGFloat = 32
        let row = CityRowView(frame: NSRect(x: 0, y: 0, width: rowW, height: rowH))
        row.onTap = onTap
        let bg = AdaptiveBackgroundView(
            frame: row.bounds,
            light: NSColor(white: 0, alpha: 0.03),
            dark:  NSColor(white: 1, alpha: 0.05),
            radius: 6
        )
        bg.autoresizingMask = [.width, .height]
        row.addSubview(bg)
        let lbl = NSTextField(labelWithString: label)
        lbl.frame = NSRect(x: 10, y: 7, width: rowW - 20, height: 18)
        lbl.font = Localizer.shared.font(size: 12, weight: .medium)
        lbl.textColor = .secondaryLabelColor
        lbl.drawsBackground = false
        row.addSubview(lbl)
        row.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            row.heightAnchor.constraint(equalToConstant: rowH),
            row.widthAnchor.constraint(equalToConstant: rowW),
        ])
        if Localizer.shared.isRTL { applyRTL(row) }
        return row
    }

    /// Card row for a country in the Search tab's root list.
    private func makeCountryRow(country: PickerCountry) -> NSView {
        let rowW = scrollWidth - 4
        let rowH: CGFloat = 44
        let row = CityRowView(frame: NSRect(x: 0, y: 0, width: rowW, height: rowH))
        row.cityName = country.name
        row.onTap = { [weak self] in
            guard let self = self else { return }
            self.searchState = .cities(country)
            self.searchField.stringValue = ""
            // If the user is (re-)entering a different country, wipe the
            // bucket so stale cities don't briefly show. `showCitiesList`
            // then refills it from cache or the API.
            if self.searchCountryCode != country.code {
                self.searchCityBucket.removeAll()
                self.searchCityOrder.removeAll()
                self.searchCountryCode = nil
            }
            self.updateInputContainer()
            self.showSearchPrompt()
        }
        let bg = AdaptiveBackgroundView(
            frame: row.bounds,
            light: NSColor(white: 0, alpha: 0.05),
            dark:  NSColor(white: 1, alpha: 0.07),
            radius: 8
        )
        bg.autoresizingMask = [.width, .height]
        row.addSubview(bg)
        // Flag emoji on the left.
        let flag = NSTextField(labelWithString: country.flag)
        flag.frame = NSRect(x: 12, y: 10, width: 26, height: 24)
        flag.font = NSFont.systemFont(ofSize: 20)
        flag.drawsBackground = false
        row.addSubview(flag)
        // Country name.
        let name = NSTextField(labelWithString: country.name)
        name.frame = NSRect(x: 44, y: 13, width: rowW - 44 - 26, height: 18)
        name.font = Localizer.shared.font(size: 13, weight: .semibold)
        name.textColor = .labelColor
        name.drawsBackground = false
        name.lineBreakMode = .byTruncatingTail
        row.addSubview(name)
        // Chevron on the right.
        let chev = NSImageView(frame: NSRect(
            x: rowW - 10 - 14, y: (rowH - 14) / 2,
            width: 14, height: 14))
        if let img = templateSymbol("chevron.right", pointSize: 11, weight: .semibold) {
            chev.image = img
        }
        chev.contentTintColor = .tertiaryLabelColor
        row.addSubview(chev)
        row.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            row.heightAnchor.constraint(equalToConstant: rowH),
            row.widthAnchor.constraint(equalToConstant: rowW),
        ])
        if Localizer.shared.isRTL { applyRTL(row) }
        return row
    }

    /// Card row for a city in the Search → country drill-down. Tapping it
    /// pushes the mosques-in-city view.
    private func makeCityRowForSearch(city: String, count: Int,
                                      country: PickerCountry) -> NSView {
        let rowW = scrollWidth - 4
        let rowH: CGFloat = Localizer.shared.isArabic ? 64 : 44
        let row = CityRowView(frame: NSRect(x: 0, y: 0, width: rowW, height: rowH))
        row.cityName = city
        row.onTap = { [weak self] in
            guard let self = self else { return }
            self.searchState = .mosques(country, city)
            self.updateInputContainer()
            self.showSearchPrompt()
        }
        let bg = AdaptiveBackgroundView(
            frame: row.bounds,
            light: NSColor(white: 0, alpha: 0.05),
            dark:  NSColor(white: 1, alpha: 0.07),
            radius: 8
        )
        bg.autoresizingMask = [.width, .height]
        row.addSubview(bg)
        let iconSize: CGFloat = 18
        let iconView = NSImageView(frame: NSRect(
            x: 10, y: (rowH - iconSize) / 2,
            width: iconSize, height: iconSize))
        if let img = templateSymbol("building.2.fill", pointSize: 13, weight: .medium) {
            iconView.image = img
        }
        iconView.contentTintColor = .secondaryLabelColor
        row.addSubview(iconView)
        let chev = NSImageView(frame: NSRect(
            x: rowW - 10 - 14, y: (rowH - 14) / 2,
            width: 14, height: 14))
        if let img = templateSymbol("chevron.right", pointSize: 11, weight: .semibold) {
            chev.image = img
        }
        chev.contentTintColor = .tertiaryLabelColor
        row.addSubview(chev)
        let textX: CGFloat = 10 + iconSize + 10
        let textW = rowW - textX - 10 - 14 - 8
        let nameLbl = NSTextField(labelWithString: city)
        nameLbl.frame = NSRect(x: textX, y: Localizer.shared.isArabic ? 4 : 5,
                               width: textW,
                               height: Localizer.shared.isArabic ? 30 : 18)
        nameLbl.font = Localizer.shared.font(size: 13, weight: .semibold)
        nameLbl.textColor = .labelColor
        nameLbl.drawsBackground = false
        nameLbl.lineBreakMode = .byTruncatingTail
        row.addSubview(nameLbl)
        let countText = localizedInterfaceDigits(String(count))
        let sub = NSTextField(labelWithString: "\(countText) \(count == 1 ? "mosque" : "mosques")")
        sub.frame = NSRect(x: textX, y: Localizer.shared.isArabic ? 34 : 23,
                           width: textW,
                           height: Localizer.shared.isArabic ? 24 : 14)
        sub.font = Localizer.shared.font(size: 10)
        sub.textColor = .secondaryLabelColor
        sub.drawsBackground = false
        sub.lineBreakMode = .byTruncatingTail
        row.addSubview(sub)
        row.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            row.heightAnchor.constraint(equalToConstant: rowH),
            row.widthAnchor.constraint(equalToConstant: rowW),
        ])
        if Localizer.shared.isRTL { applyRTL(row) }
        return row
    }

    private func clearResults() {
        for v in resultsStack.arrangedSubviews {
            resultsStack.removeArrangedSubview(v)
            v.removeFromSuperview()
        }
    }
    private func showResults(_ refs: [MosqueRef], emptyMsg: String) {
        clearResults()
        if refs.isEmpty { statusLabel.stringValue = emptyMsg; return }
        statusLabel.stringValue = "\(localizedInterfaceDigits(String(refs.count))) result\(refs.count == 1 ? "" : "s")"
        for r in refs {
            resultsStack.addArrangedSubview(makeRow(for: r, fromFavorites: false))
        }
    }

    private func makeRow(for m: MosqueRef, fromFavorites: Bool) -> NSView {
        // Card-style row sized for the 280-wide popover. The card stacks
        //   • mosque name  (bold, primary)
        //   • city         (11pt, secondary)
        //   • street addr  (10pt, tertiary, italicised feel via colour)
        // Height auto-sizes so rows with no city/address stay compact while
        // rows with both lines grow to fit, keeping the design tight.
        let rowW = scrollWidth - 4
        let addr = (m.address ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let hasCity    = !m.city.isEmpty
        let hasAddress = !addr.isEmpty

        let padTop:    CGFloat = 10
        let padBot:    CGFloat = 10
        let lineGap:   CGFloat = 2
        let nameFont = Localizer.shared.font(size: 13, weight: .semibold)
        let cityFont = Localizer.shared.font(size: 11, weight: .medium)
        let addressFont = Localizer.shared.font(size: 10)
        let nameH = max(18, localizedTextHeight(m.name, font: nameFont,
                                               width: max(120, rowW * 0.55)))
        let cityH = max(14, localizedTextHeight(m.city, font: cityFont,
                                               width: max(120, rowW * 0.55)))
        let addressH = max(14, localizedTextHeight(addr, font: addressFont,
                                                  width: max(120, rowW * 0.55)))
        let extraLines = (hasCity ? 1 : 0) + (hasAddress ? 1 : 0)
        let rowH: CGFloat = padTop + nameH +
                            (extraLines > 0 ? lineGap : 0) +
                            (hasCity ? cityH : 0) + (hasAddress ? addressH : 0) +
                            (extraLines > 1 ? lineGap : 0) +
                            padBot
        // Use a hoverable row so that hovering over the card pops up a
        // richer detail view with name, city, address, and URL.
        let row = HoverablePickerRow(frame: NSRect(x: 0, y: 0, width: rowW, height: rowH))
        row.mosque = m

        let bg = AdaptiveBackgroundView(
            frame: row.bounds,
            light: NSColor(white: 0, alpha: 0.05),
            dark:  NSColor(white: 1, alpha: 0.07),
            radius: 10
        )
        bg.autoresizingMask = [.width, .height]
        row.addSubview(bg)

        let isCurrent  = normalizeMosqueURL(m.url) == normalizeMosqueURL(currentMosqueURL())
        let alreadyFav = loadFavorites().contains(m)

        // ---------- Right-side action buttons (icon-only, monotone) -------
        // 28×28 each, 6px gap, 8px from the trailing edge. Buttons stay
        // vertically centred no matter how tall the card grows.
        let btnSize: CGFloat = 28
        let btnGap:  CGFloat = 6
        let rightPad: CGFloat = 8
        let btnY: CGFloat = (rowH - btnSize) / 2

        let favBtn = NSButton(frame: NSRect(x: rowW - rightPad - btnSize,
                                            y: btnY, width: btnSize, height: btnSize))
        favBtn.bezelStyle = .regularSquare
        favBtn.isBordered = false
        favBtn.title = ""
        favBtn.target = self
        favBtn.identifier = NSUserInterfaceItemIdentifier(serialize(m))
        favBtn.imagePosition = .imageOnly
        favBtn.imageScaling = .scaleProportionallyDown
        favBtn.focusRingType = .none
        if fromFavorites {
            // In the Favorites tab, the single star action removes it.
            if let img = templateSymbol("star.slash", pointSize: 14, weight: .medium) {
                favBtn.image = img
            }
            favBtn.contentTintColor = .secondaryLabelColor
            favBtn.toolTip = t("picker.tooltip.remove_fav")
            favBtn.action = #selector(removeFavTapped(_:))
        } else {
            // In Search / Near / URL tabs, the star toggles save state.
            let sym = alreadyFav ? "star.fill" : "star"
            if let img = templateSymbol(sym, pointSize: 14, weight: .medium) {
                favBtn.image = img
            }
            favBtn.contentTintColor = alreadyFav ? .appGreenAccent : .secondaryLabelColor
            favBtn.toolTip = alreadyFav ? t("picker.tooltip.saved")
                                        : t("picker.tooltip.add_fav")
            favBtn.isEnabled = !alreadyFav
            favBtn.action = #selector(addFavTapped(_:))
        }
        row.addSubview(favBtn)

        let defBtn = NSButton(frame: NSRect(x: rowW - rightPad - btnSize * 2 - btnGap,
                                            y: btnY, width: btnSize, height: btnSize))
        defBtn.bezelStyle = .regularSquare
        defBtn.isBordered = false
        defBtn.title = ""
        defBtn.target = self
        defBtn.action = #selector(setDefaultTapped(_:))
        defBtn.identifier = NSUserInterfaceItemIdentifier(serialize(m))
        defBtn.imagePosition = .imageOnly
        defBtn.imageScaling = .scaleProportionallyDown
        defBtn.focusRingType = .none
        let checkSym = isCurrent ? "checkmark.circle.fill" : "checkmark.circle"
        if let img = templateSymbol(checkSym, pointSize: 14, weight: .medium) {
            defBtn.image = img
        }
        defBtn.contentTintColor = isCurrent ? .appGreenAccent : .secondaryLabelColor
        defBtn.toolTip = isCurrent ? t("picker.tooltip.is_default")
                                   : t("picker.tooltip.set_default")
        defBtn.isEnabled = !isCurrent
        row.addSubview(defBtn)

        // ---------- Open-in-browser button ---------------------------------
        // Opens the mosque's **desktop** Mawaqit page (stripping /m/ from the
        // path) so the user sees the full site instead of the mobile/embed
        // variant. Lives to the left of the check+star buttons.
        let linkBtn = NSButton(frame: NSRect(x: rowW - rightPad - btnSize * 3 - btnGap * 2,
                                             y: btnY, width: btnSize, height: btnSize))
        linkBtn.bezelStyle = .regularSquare
        linkBtn.isBordered = false
        linkBtn.title = ""
        linkBtn.target = self
        linkBtn.action = #selector(openMosquePageTapped(_:))
        linkBtn.identifier = NSUserInterfaceItemIdentifier(serialize(m))
        linkBtn.imagePosition = .imageOnly
        linkBtn.imageScaling = .scaleProportionallyDown
        linkBtn.focusRingType = .none
        if let img = templateSymbol("arrow.up.right.square", pointSize: 14, weight: .medium) {
            linkBtn.image = img
        }
        linkBtn.contentTintColor = .secondaryLabelColor
        linkBtn.toolTip = "Open on mawaqit.net"
        row.addSubview(linkBtn)

        // ---------- Text block ---------------------------------------------
        // Name + city + address stack fills the remaining horizontal space
        // to the left of the three action buttons (open-link, check, star).
        let leftPad: CGFloat = 12
        let textW = rowW - rightPad - btnSize * 3 - btnGap * 2 - leftPad - 8

        var y: CGFloat = padTop

        let name = NSTextField(labelWithString: m.name)
        name.frame = NSRect(x: leftPad, y: y, width: textW, height: nameH)
        name.font = nameFont
        name.textColor = isCurrent ? .appGreenAccent : .labelColor
        name.drawsBackground = false
        name.lineBreakMode = .byTruncatingTail
        name.toolTip = m.name
        row.addSubview(name)
        y += nameH

        if hasCity {
            y += lineGap
            let city = NSTextField(labelWithString: m.city)
            city.frame = NSRect(x: leftPad, y: y, width: textW, height: cityH)
            city.font = cityFont
            city.textColor = .secondaryLabelColor
            city.drawsBackground = false
            city.lineBreakMode = .byTruncatingTail
            city.toolTip = m.city
            row.addSubview(city)
            y += cityH
        }

        if hasAddress {
            y += lineGap
            let addrLbl = NSTextField(labelWithString: addr)
            addrLbl.frame = NSRect(x: leftPad, y: y, width: textW, height: addressH)
            addrLbl.font = addressFont
            addrLbl.textColor = .tertiaryLabelColor
            addrLbl.drawsBackground = false
            addrLbl.lineBreakMode = .byTruncatingTail
            addrLbl.toolTip = addr
            row.addSubview(addrLbl)
        }

        row.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            row.heightAnchor.constraint(equalToConstant: rowH),
            row.widthAnchor.constraint(equalToConstant: rowW),
        ])

        // RTL pass for dynamically-added rows (makeRow is called after build()).
        if Localizer.shared.isRTL {
            applyRTL(row)
        }
        return row
    }

    private func serialize(_ m: MosqueRef) -> String {
        if let d = try? JSONEncoder().encode(m), let s = String(data: d, encoding: .utf8) { return s }
        return m.url
    }
    private func deserialize(_ s: String) -> MosqueRef? {
        guard let d = s.data(using: .utf8) else { return nil }
        return try? JSONDecoder().decode(MosqueRef.self, from: d)
    }

    @objc private func setDefaultTapped(_ sender: NSButton) {
        guard let m = deserialize(sender.identifier?.rawValue ?? "") else { return }
        setCurrentMosque(m.url)
        appDelegate?.currentMosqueDidChange()
        statusLabel.stringValue = "\(t("picker.status.set_default_prefix")) \"\(m.name)\""
        // Rebuild so the check marks + accent colours reflect the new default.
        refreshCurrentMode()
    }
    @objc private func addFavTapped(_ sender: NSButton) {
        guard let m = deserialize(sender.identifier?.rawValue ?? "") else { return }
        _ = addFavorite(m)
        statusLabel.stringValue = "\(t("picker.status.added_fav_prefix")) \"\(m.name)\""
        // Flip icon to "saved" state right on the tapped button so the user
        // gets instant visual feedback without re-running the search.
        if let img = templateSymbol("star.fill", pointSize: 14, weight: .medium) {
            sender.image = img
        }
        sender.contentTintColor = .appGreenAccent
        sender.toolTip = t("picker.tooltip.saved")
        sender.isEnabled = false
    }
    @objc private func removeFavTapped(_ sender: NSButton) {
        guard let m = deserialize(sender.identifier?.rawValue ?? "") else { return }
        removeFavorite(url: m.url)
        statusLabel.stringValue = "\(t("picker.status.removed_fav_prefix")) \"\(m.name)\""
        showFavorites()
    }

    /// Open the mosque's official Mawaqit page in the user's default browser,
    /// switched to the desktop variant (`/fr/slug` instead of `/fr/m/slug`).
    @objc private func openMosquePageTapped(_ sender: NSButton) {
        guard let m = deserialize(sender.identifier?.rawValue ?? "") else { return }
        let desktop = desktopMawaqitURL(m.url)
        guard let url = URL(string: desktop) else { return }
        NSWorkspace.shared.open(url)
        statusLabel.stringValue = "Opening \(m.name) on mawaqit.net…"
    }
}

// ============================================================================
// MARK: Accent swatch button (theme picker in Settings)
// ============================================================================
/// Circular color swatch used in the Appearance settings tab. Tracks selection
/// state with a thicker ring so the active accent is easy to spot, and draws
/// the accent's theme-appropriate shade (light vs dark) instead of forcing
/// the light palette on both appearances.
final class AccentSwatchButton: NSButton {
    let accentKey: String
    var isSelectedSwatch: Bool = false { didSet { needsDisplay = true } }
    private let diameter: CGFloat

    init(key: String, diameter: CGFloat = 30, target: AnyObject?, action: Selector) {
        self.accentKey = key
        self.diameter = diameter
        super.init(frame: NSRect(x: 0, y: 0, width: diameter, height: diameter))
        self.target = target
        self.action = action
        self.title = ""
        self.isBordered = false
        self.bezelStyle = .regularSquare
        self.focusRingType = .none
        self.toolTip = accentLocalizedName(key)
        self.wantsLayer = true
        self.layer?.backgroundColor = NSColor.clear.cgColor
    }
    required init?(coder: NSCoder) { fatalError() }

    override func draw(_ dirtyRect: NSRect) {
        guard let pair = kAccentPalette[accentKey] else { return }
        let isDark = effectiveAppearance.bestMatch(from: [.darkAqua, .vibrantDark]) != nil
        let color = isDark ? pair.dark : pair.light
        // Fill ring stays outside the swatch so the selected state sits in
        // negative space (no pixel overlap with the color itself).
        let pad: CGFloat = 4
        let inner = NSRect(x: pad, y: pad,
                           width: bounds.width - pad * 2,
                           height: bounds.height - pad * 2)
        color.setFill()
        NSBezierPath(ovalIn: inner).fill()
        // Subtle outline so very-pale swatches still read as circular shapes
        // against a light material.
        NSColor.separatorColor.setStroke()
        let outline = NSBezierPath(ovalIn: inner)
        outline.lineWidth = 0.5
        outline.stroke()

        if isSelectedSwatch {
            NSColor.labelColor.setStroke()
            let ring = NSBezierPath(ovalIn: bounds.insetBy(dx: 1.5, dy: 1.5))
            ring.lineWidth = 2
            ring.stroke()
        }
    }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        needsDisplay = true
    }
}

// ============================================================================
// MARK: Settings view
// ============================================================================
final class SettingsView: FlippedView {
    weak var appDelegate: AppDelegate?
    var onDone: (() -> Void)?
    var onOpenPicker: (() -> Void)?

    private let appearanceSeg   = NSSegmentedControl()
    /// Accent swatches displayed in the Appearance tab. Kept as a stored
    /// array so the selection ring can be refreshed when the user picks a
    /// new color without rebuilding the whole panel.
    private var accentSwatches: [AccentSwatchButton] = []
    /// Opaque / Liquid Glass material chooser. Same options as the quick
    /// theme menu on the main page.
    private let materialSeg     = NSSegmentedControl()
    private let adhanCheck      = NSButton(checkboxWithTitle: t("settings.adhan.play"),
                                           target: nil, action: nil)
    private let adhanSoundPopup = NSPopUpButton()
    private let adhanOutputPopup = NSPopUpButton()
    private var adhanOutputDevices: [AudioOutputDevice] = []
    private var testBtn: HoverIconButton!
    private let notifCheck      = NSButton(checkboxWithTitle: t("settings.notif.show"),
                                           target: nil, action: nil)
    /// Master on/off for auto-reciting the morning & evening adhkar at the
    /// chosen anchor time. Manual opening from the menu still works when off.
    private let adhkarCheck     = NSButton(checkboxWithTitle: t("settings.adhkar.auto"),
                                           target: nil, action: nil)
    /// Pick how many minutes before each prayer to fire a heads-up
    /// notification. First entry = Off; rest are values from
    /// `kPreAdhanOptions` rendered as "N min before".
    private let preAdhanPopup   = NSPopUpButton()
    private let languagePopup   = NSPopUpButton()
    private let changeMosqueBtn = NSButton(title: t("settings.mosque.change"), target: nil, action: nil)
    private let currentMosqueLbl = NSTextField(labelWithString: "")
    // Time-format segmented control (24h / 12h).
    private let timeFormatSeg   = NSSegmentedControl()
    // Menu-bar element toggles.
    private let barIconCheck      = NSButton(checkboxWithTitle: t("settings.bar.icon"),
                                             target: nil, action: nil)
    private let barTimeCheck      = NSButton(checkboxWithTitle: t("settings.bar.time"),
                                             target: nil, action: nil)
    private let barCountdownCheck = NSButton(checkboxWithTitle: t("settings.bar.countdown"),
                                             target: nil, action: nil)
    // Hijri gets a popup now so the user can pick a compact format instead
    // of being forced to show the full "15 Shawwāl 1447" string.
    private let barHijriPopup     = NSPopUpButton()
    // Launch at macOS login.
    private let openAtLoginCheck = NSButton(checkboxWithTitle: t("settings.startup.open_at_login"),
                                            target: nil, action: nil)

    // Tab bar (icon-only segmented control) at the top of the body lets us
    // split the 8 settings sections into 4 focused panels instead of cramming
    // everything into a single scrolling column. Each tab owns its own
    // scroll-view panel so long sections (e.g. language list on small
    // displays) still scroll gracefully.
    private let tabBar           = NSSegmentedControl()
    private let tabHintLabel     = NSTextField(labelWithString: "")
    private let mosqueTabScroll  = NSScrollView()
    private let displayTabScroll = NSScrollView()
    private let barTabScroll     = NSScrollView()
    private let soundTabScroll   = NSScrollView()
    private var panelScrolls: [NSScrollView] { [mosqueTabScroll, displayTabScroll, barTabScroll, soundTabScroll] }
    private var tabHints: [String] = []

    init(width: CGFloat, height: CGFloat) {
        super.init(frame: NSRect(x: 0, y: 0, width: width, height: height))
        build()
    }
    required init?(coder: NSCoder) { fatalError() }

    func refresh() {
        let curAp = UserDefaults.standard.string(forKey: kAppearanceKey) ?? "system"
        appearanceSeg.selectedSegment = ["system","light","dark"].firstIndex(of: curAp) ?? 0

        adhanCheck.state = UserDefaults.standard.bool(forKey: kAdhanEnabled) ? .on : .off
        notifCheck.state = UserDefaults.standard.bool(forKey: kNotificationsKey) ? .on : .off
        adhkarCheck.state = UserDefaults.standard.bool(forKey: kAdhkarEnabled) ? .on : .off

        // Select the pre-adhan popup item matching the saved minutes; fall
        // back to "Off" (index 0) if the saved value isn't in the menu.
        let savedLead = UserDefaults.standard.integer(forKey: kPreAdhanLeadMinutes)
        if let preIdx = kPreAdhanOptions.firstIndex(of: savedLead) {
            preAdhanPopup.selectItem(at: preIdx)
        } else {
            preAdhanPopup.selectItem(at: 0)
        }

        if let idx = adhanCatalog.firstIndex(where: { $0.id == currentAdhanOption().id }) {
            adhanSoundPopup.selectItem(at: idx)
        }

        // Audio output device — rebuild list in case devices changed (e.g. user
        // plugged in headphones between opens).
        adhanOutputDevices = listAudioOutputDevices()
        adhanOutputPopup.removeAllItems()
        adhanOutputPopup.addItem(withTitle: t("settings.adhan.output.default"))
        for dev in adhanOutputDevices {
            adhanOutputPopup.addItem(withTitle: dev.name)
        }
        let wantedUID = UserDefaults.standard.string(forKey: kAdhanAudioDevice) ?? ""
        if wantedUID.isEmpty {
            adhanOutputPopup.selectItem(at: 0)
        } else if let i = adhanOutputDevices.firstIndex(where: { $0.uid == wantedUID }) {
            adhanOutputPopup.selectItem(at: i + 1)
        } else {
            // Previously selected device is no longer connected — fall back to
            // the system default and clear the stale preference.
            adhanOutputPopup.selectItem(at: 0)
        }

        // Language popup — items are added in build()
        if let idx = kSupportedLanguages.firstIndex(where: { $0.code == Localizer.shared.current.code }) {
            languagePopup.selectItem(at: idx)
        }

        // Time format — 0 = 24h, 1 = 12h.
        timeFormatSeg.selectedSegment = is12HourFormat() ? 1 : 0

        // Menu-bar toggles.
        barIconCheck.state      = (UserDefaults.standard.object(forKey: kBarShowIcon)      as? Bool ?? true)  ? .on : .off
        barTimeCheck.state      = (UserDefaults.standard.object(forKey: kBarShowTime)      as? Bool ?? true)  ? .on : .off
        barCountdownCheck.state = (UserDefaults.standard.object(forKey: kBarShowCountdown) as? Bool ?? true)  ? .on : .off
        // Hijri popup reflects the enum; items are installed in buildMenuBarTab.
        if let idx = kHijriFormatOrder.firstIndex(of: currentHijriFormat()) {
            barHijriPopup.selectItem(at: idx)
        }

        // Startup — read live status from ServiceManagement so the checkbox
        // reflects reality if the user toggled it in System Settings.
        openAtLoginCheck.state = isOpenAtLoginEnabled() ? .on : .off

        let info = appDelegate?.info
        if let name = info?.name, !name.isEmpty, name != t("mosque.default") {
            currentMosqueLbl.stringValue = "\(t("settings.mosque.currently")) \(name)"
        } else {
            currentMosqueLbl.stringValue = t("settings.mosque.none")
        }
    }

    private func sectionLabel(_ text: String, y: CGFloat, width: CGFloat) -> NSTextField {
        let lbl = NSTextField(labelWithString: text)
        lbl.frame = NSRect(x: 18, y: y, width: width - 36, height: 14)
        lbl.font = NSFont.systemFont(ofSize: 10, weight: .bold)
        lbl.textColor = .tertiaryLabelColor
        lbl.drawsBackground = false
        return lbl
    }

    private func build() {
        let W = bounds.width
        let H = bounds.height

        // --------------------------------------------------------- Header
        let backBtn = HoverIconButton(
            symbol: backChevronSymbol,
            toolTip: t("tooltip.back"),
            target: self,
            action: #selector(backTapped),
            pointSize: 14,
            size: NSSize(width: 36, height: 28))
        backBtn.setFrameOrigin(NSPoint(x: 10, y: 10))
        addSubview(backBtn)

        let title = NSTextField(labelWithString: t("settings.title"))
        title.frame = NSRect(x: 60, y: 14, width: W - 120, height: 20)
        title.font = Localizer.shared.font(size: 13, weight: .semibold)
        title.alignment = .center
        title.textColor = .labelColor
        title.drawsBackground = false
        addSubview(title)

        // "Save" primary button, top-right of the title bar. Every setting is
        // auto-persisted on change, so this is really a "done — close and go
        // back" affordance. Keyed to Return so hitting ↵ also dismisses.
        let saveBtn = NSButton(title: t("settings.save"),
                               target: self,
                               action: #selector(saveTapped))
        saveBtn.bezelStyle = .rounded
        saveBtn.keyEquivalent = "\r"   // Return triggers it
        // Use the accent tint so it reads as the primary action against the
        // secondary back chevron on the left.
        saveBtn.bezelColor = .appGreenAccent
        saveBtn.contentTintColor = .white
        saveBtn.frame = NSRect(x: W - 68, y: 10, width: 58, height: 28)
        addSubview(saveBtn)

        // Hairline under the header so it reads as a clear title bar.
        let hdrSep = NSBox(frame: NSRect(x: 12, y: 42, width: W - 24, height: 1))
        hdrSep.boxType = .separator
        addSubview(hdrSep)

        // --------------------------------------------------------- Footer (pinned)
        // About line + Quit button sit at the bottom of the popover and never
        // scroll, so the user can always see the version and get out fast.
        let footerH: CGFloat = 60
        let footerY = H - footerH

        let footerSep = NSBox(frame: NSRect(x: 12, y: footerY, width: W - 24, height: 1))
        footerSep.boxType = .separator
        addSubview(footerSep)

        let about = NSTextField(labelWithString: "Salat Time v\(kAppVersion) · mawaqit.net")
        about.frame = NSRect(x: 10, y: footerY + 6, width: W - 20, height: 12)
        about.font = Localizer.shared.font(size: 9)
        about.textColor = .tertiaryLabelColor
        about.drawsBackground = false
        about.alignment = .center
        addSubview(about)

        let quitBtn = NSButton(title: t("settings.quit"), target: NSApp,
                               action: #selector(NSApplication.terminate(_:)))
        quitBtn.bezelStyle = .rounded
        quitBtn.frame = NSRect(x: (W - 140) / 2, y: footerY + 26, width: 140, height: 24)
        addSubview(quitBtn)

        // --------------------------------------------------------- Tab bar
        // 4 icon-only segments mirror the mosque-picker style and group the
        // 8 settings sections into 4 focused panels instead of piling them all
        // into a single scrolling column. Tooltips carry the localized label
        // so the tab bar stays compact for every language.
        let tabCount = 4
        let tabTotal = W - 24
        let tabW = tabTotal / CGFloat(tabCount)
        tabBar.segmentCount = tabCount
        let tabSymbols  = ["mappin.and.ellipse", "paintbrush.fill",
                           "menubar.rectangle",  "bell.fill"]
        tabHints = [t("settings.tab.mosque"),
                    t("settings.tab.appearance"),
                    t("settings.tab.menu_bar"),
                    t("settings.tab.sound")]
        for (i, s) in tabSymbols.enumerated() {
            if let img = templateSymbol(s, pointSize: 13, weight: .medium) {
                tabBar.setImage(img, forSegment: i)
            } else {
                tabBar.setLabel(["Mosque","Look","Bar","Sound"][i], forSegment: i)
            }
            tabBar.setToolTip(tabHints[i], forSegment: i)
            tabBar.setWidth(tabW, forSegment: i)
        }
        tabBar.segmentStyle = .texturedRounded
        tabBar.selectedSegment = 0
        tabBar.target = self
        tabBar.action = #selector(tabChanged)
        tabBar.frame = NSRect(x: 12, y: 50, width: tabTotal, height: 26)
        addSubview(tabBar)

        // Subtle helper line under the tab bar — shows the active tab's
        // localized name so the icon-only tabs stay unambiguous.
        tabHintLabel.frame = NSRect(x: 12, y: 82, width: W - 24, height: 14)
        tabHintLabel.font = Localizer.shared.font(size: 10, weight: .medium)
        tabHintLabel.textColor = .secondaryLabelColor
        tabHintLabel.drawsBackground = false
        tabHintLabel.alignment = .center
        tabHintLabel.stringValue = tabHints[0]
        addSubview(tabHintLabel)

        // --------------------------------------------------------- Panel area
        // Each tab owns its own scroll view stacked at the same frame. We
        // only unhide the selected one — cheaper than rebuilding subviews on
        // each tap, and the scrollers remember their last offset per tab.
        let panelY: CGFloat = 102
        let panelH = footerY - panelY - 6
        let panelFrame = NSRect(x: 0, y: panelY, width: W, height: panelH)
        for (i, scroll) in panelScrolls.enumerated() {
            scroll.frame = panelFrame
            scroll.hasVerticalScroller = true
            scroll.drawsBackground = false
            scroll.borderType = .noBorder
            scroll.autohidesScrollers = true
            scroll.autoresizingMask = [.width, .height]
            scroll.isHidden = (i != 0)
            addSubview(scroll)
        }

        // Build each tab's body. `addPanel` returns a FlippedView the caller
        // populates top-to-bottom; the helper sizes the doc view from the
        // final `y` and installs it into the paired scroll view.
        buildMosqueTab(width: W)
        buildAppearanceTab(width: W)
        buildMenuBarTab(width: W)
        buildSoundTab(width: W)

        // RTL: recursive mirror + native control direction.
        if Localizer.shared.isRTL {
            applyRTL(self)
        }
    }

    // ------------------------------------------------------------------
    // MARK: Tab panel builders
    // ------------------------------------------------------------------
    /// Create a FlippedView doc view sized to its content, install it in the
    /// given scroll view, and return it so the caller can add subviews.
    private func makePanelBody(width W: CGFloat) -> FlippedView {
        let body = FlippedView(frame: NSRect(x: 0, y: 0, width: W, height: 10))
        return body
    }

    /// After populating a panel body, size it to fit `contentHeight` and hand
    /// it off to the paired scroll view as the documentView.
    private func installPanel(_ body: FlippedView,
                              contentHeight: CGFloat,
                              scrollView: NSScrollView,
                              width W: CGFloat) {
        body.frame = NSRect(x: 0, y: 0, width: W, height: contentHeight + 12)
        scrollView.documentView = body
        body.scroll(NSPoint(x: 0, y: 0))
    }

    /// Narrow helper that draws a hairline separator between sections inside
    /// a tab so the visual grouping is obvious without relying on card fills.
    private func sectionDivider(y: CGFloat, width W: CGFloat) -> NSBox {
        let box = NSBox(frame: NSRect(x: 18, y: y, width: W - 36, height: 1))
        box.boxType = .separator
        return box
    }

    // --- Tab 0: Mosque + Language ---
    private func buildMosqueTab(width W: CGFloat) {
        let body = makePanelBody(width: W)
        var y: CGFloat = 12

        // Mosque
        body.addSubview(sectionLabel(t("settings.section.mosque"), y: y, width: W)); y += 18
        currentMosqueLbl.frame = NSRect(x: 18, y: y, width: W - 36, height: 14)
        currentMosqueLbl.font = Localizer.shared.font(size: 11)
        currentMosqueLbl.textColor = .secondaryLabelColor
        currentMosqueLbl.drawsBackground = false
        currentMosqueLbl.lineBreakMode = .byTruncatingTail
        body.addSubview(currentMosqueLbl)
        y += 20
        changeMosqueBtn.frame = NSRect(x: 18, y: y, width: W - 36, height: 26)
        changeMosqueBtn.bezelStyle = .rounded
        changeMosqueBtn.target = self
        changeMosqueBtn.action = #selector(openPickerTapped)
        if let img = templateSymbol("mappin.and.ellipse", pointSize: 11, weight: .medium) {
            changeMosqueBtn.image = img
            changeMosqueBtn.imagePosition = .imageLeft
            changeMosqueBtn.imageHugsTitle = true
        }
        body.addSubview(changeMosqueBtn)
        y += 36

        body.addSubview(sectionDivider(y: y, width: W)); y += 14

        // Language
        body.addSubview(sectionLabel(t("settings.section.language"), y: y, width: W)); y += 18
        languagePopup.frame = NSRect(x: 18, y: y, width: W - 36, height: 26)
        for lang in kSupportedLanguages {
            languagePopup.addItem(withTitle: lang.nativeName)
        }
        languagePopup.target = self
        languagePopup.action = #selector(languageChanged)
        body.addSubview(languagePopup)
        y += 32

        installPanel(body, contentHeight: y, scrollView: mosqueTabScroll, width: W)
    }

    // --- Tab 1: Appearance + Time format ---
    private func buildAppearanceTab(width W: CGFloat) {
        let body = makePanelBody(width: W)
        var y: CGFloat = 12

        // Appearance (system / light / dark)
        body.addSubview(sectionLabel(t("settings.section.appearance"), y: y, width: W)); y += 18
        appearanceSeg.segmentCount = 3
        appearanceSeg.setLabel(t("settings.appearance.system"), forSegment: 0)
        appearanceSeg.setLabel(t("settings.appearance.light"),  forSegment: 1)
        appearanceSeg.setLabel(t("settings.appearance.dark"),   forSegment: 2)
        appearanceSeg.segmentStyle = .texturedRounded
        appearanceSeg.frame = NSRect(x: 18, y: y, width: W - 36, height: 26)
        appearanceSeg.target = self
        appearanceSeg.action = #selector(appearanceChanged)
        body.addSubview(appearanceSeg)
        y += 36

        body.addSubview(sectionDivider(y: y, width: W)); y += 14

        // Accent color — mirrors the quick-theme menu on the main page so
        // the picker lives in both places. Swatches are laid out in a single
        // row; 6 × ~34px fits inside the 280-wide popover with gaps.
        body.addSubview(sectionLabel(t("settings.section.accent"), y: y, width: W)); y += 20
        accentSwatches.removeAll()
        let swatchDiameter: CGFloat = 30
        let swatchCount = kAccentOrder.count
        let available = W - 36
        let gap = max(4, (available - CGFloat(swatchCount) * swatchDiameter) / CGFloat(swatchCount - 1))
        let curAccent = currentAccentKey()
        for (i, key) in kAccentOrder.enumerated() {
            let btn = AccentSwatchButton(key: key,
                                         diameter: swatchDiameter,
                                         target: self,
                                         action: #selector(accentSwatchTapped(_:)))
            btn.frame = NSRect(x: 18 + CGFloat(i) * (swatchDiameter + gap),
                               y: y, width: swatchDiameter, height: swatchDiameter)
            btn.isSelectedSwatch = (key == curAccent)
            body.addSubview(btn)
            accentSwatches.append(btn)
        }
        y += swatchDiameter + 12

        body.addSubview(sectionDivider(y: y, width: W)); y += 14

        // Material — Opaque vs Liquid Glass, same pair of options as the
        // quick menu so the Appearance tab is now the single source of truth
        // for all theme preferences.
        body.addSubview(sectionLabel(t("settings.section.material"), y: y, width: W)); y += 18
        materialSeg.segmentCount = 2
        materialSeg.setLabel(t("menu.theme.material.opaque"), forSegment: 0)
        materialSeg.setLabel(t("menu.theme.material.glass"),  forSegment: 1)
        materialSeg.segmentStyle = .texturedRounded
        materialSeg.frame = NSRect(x: 18, y: y, width: W - 36, height: 26)
        materialSeg.target = self
        materialSeg.action = #selector(materialChanged)
        let curMat = UserDefaults.standard.string(forKey: kMaterialPref) ?? "opaque"
        materialSeg.selectedSegment = (curMat == "glass") ? 1 : 0
        body.addSubview(materialSeg)
        y += 36

        body.addSubview(sectionDivider(y: y, width: W)); y += 14

        // Time format
        body.addSubview(sectionLabel(t("settings.section.time_format"), y: y, width: W)); y += 18
        timeFormatSeg.segmentCount = 2
        timeFormatSeg.setLabel(t("settings.time_format.24h"), forSegment: 0)
        timeFormatSeg.setLabel(t("settings.time_format.12h"), forSegment: 1)
        timeFormatSeg.segmentStyle = .texturedRounded
        timeFormatSeg.frame = NSRect(x: 18, y: y, width: W - 36, height: 26)
        timeFormatSeg.target = self
        timeFormatSeg.action = #selector(timeFormatChanged)
        body.addSubview(timeFormatSeg)
        y += 32

        installPanel(body, contentHeight: y, scrollView: displayTabScroll, width: W)
    }

    // --- Tab 2: Menu Bar + Startup ---
    private func buildMenuBarTab(width W: CGFloat) {
        let body = makePanelBody(width: W)
        var y: CGFloat = 12

        // Menu bar — stacked (not 3-across) so labels don't truncate in
        // non-English locales. Users only tap these once, so vertical real
        // estate is a fair trade for readability.
        body.addSubview(sectionLabel(t("settings.section.menu_bar"), y: y, width: W)); y += 18
        let rowH: CGFloat = 22
        // Three independent checkboxes so the user can mix-and-match:
        // • Icon only              → just the moon glyph
        // • Time only              → "Dhuhr 13:45"
        // • Countdown only         → "Dhuhr 00:42:15"
        // • Time + Countdown       → "Dhuhr 13:45 · 00:42:15"
        for (i, cb) in [barIconCheck, barTimeCheck, barCountdownCheck].enumerated() {
            cb.frame = NSRect(x: 18, y: y + CGFloat(i) * (rowH + 2),
                              width: W - 36, height: rowH)
            cb.target = self
            cb.action = #selector(menuBarToggleChanged)
            body.addSubview(cb)
        }
        y += 3 * (rowH + 2) + 6

        // Hijri: label + popup so the user can pick a compact variant
        // ("15 Shawwāl", "Shawwāl", "15") instead of the full date, or
        // turn it off entirely. Label sits to the left; popup fills the
        // remaining width so localised strings don't truncate.
        let hijriLbl = NSTextField(labelWithString: t("settings.bar.hijri"))
        hijriLbl.font = Localizer.shared.font(size: 12)
        hijriLbl.textColor = .labelColor
        hijriLbl.drawsBackground = false
        hijriLbl.frame = NSRect(x: 18, y: y + 5, width: 70, height: 18)
        body.addSubview(hijriLbl)

        barHijriPopup.frame = NSRect(x: 92, y: y, width: W - 110, height: 26)
        barHijriPopup.removeAllItems()
        for fmt in kHijriFormatOrder {
            barHijriPopup.addItem(withTitle: t("settings.bar.hijri.format.\(fmt.rawValue)"))
        }
        barHijriPopup.target = self
        barHijriPopup.action = #selector(barHijriFormatChanged)
        body.addSubview(barHijriPopup)
        y += 34

        body.addSubview(sectionDivider(y: y, width: W)); y += 14

        // Startup
        body.addSubview(sectionLabel(t("settings.section.startup"), y: y, width: W)); y += 18
        openAtLoginCheck.frame = NSRect(x: 18, y: y, width: W - 36, height: 22)
        openAtLoginCheck.target = self
        openAtLoginCheck.action = #selector(openAtLoginChanged)
        body.addSubview(openAtLoginCheck)
        y += 30

        installPanel(body, contentHeight: y, scrollView: barTabScroll, width: W)
    }

    // --- Tab 3: Adhan + Notifications ---
    private func buildSoundTab(width W: CGFloat) {
        let body = makePanelBody(width: W)
        var y: CGFloat = 12

        // Adhan
        body.addSubview(sectionLabel(t("settings.section.adhan"), y: y, width: W)); y += 18
        adhanCheck.frame = NSRect(x: 18, y: y, width: W - 36, height: 22)
        adhanCheck.target = self
        adhanCheck.action = #selector(adhanToggleChanged)
        body.addSubview(adhanCheck)
        y += 28

        let soundLbl = NSTextField(labelWithString: t("settings.adhan.sound"))
        soundLbl.frame = NSRect(x: 18, y: y + 5, width: 54, height: 18)
        soundLbl.font = Localizer.shared.font(size: 12)
        soundLbl.textColor = .labelColor
        soundLbl.drawsBackground = false
        body.addSubview(soundLbl)

        adhanSoundPopup.frame = NSRect(x: 72, y: y, width: W - 124, height: 26)
        for opt in adhanCatalog { adhanSoundPopup.addItem(withTitle: opt.name) }
        adhanSoundPopup.target = self
        adhanSoundPopup.action = #selector(adhanSoundChanged)
        body.addSubview(adhanSoundPopup)

        testBtn = HoverIconButton(
            symbol: "play.fill",
            toolTip: t("tooltip.test_adhan"),
            target: self,
            action: #selector(testTapped),
            pointSize: 13,
            size: NSSize(width: 36, height: 26))
        testBtn.setFrameOrigin(NSPoint(x: W - 46, y: y))
        body.addSubview(testBtn)
        // Flip the icon between play/stop whenever playback state changes —
        // covers user-initiated stops as well as natural end-of-file.
        appDelegate?.onAdhanStateChanged = { [weak self] in
            DispatchQueue.main.async { self?.refreshTestButton() }
        }
        refreshTestButton()
        y += 36

        // Output device picker — lets the user force the adhan to a specific
        // output (e.g. built-in speakers) regardless of the system default
        // (e.g. headphones).
        let outLbl = NSTextField(labelWithString: t("settings.adhan.output"))
        outLbl.frame = NSRect(x: 18, y: y + 5, width: 60, height: 18)
        outLbl.font = Localizer.shared.font(size: 12)
        outLbl.textColor = .labelColor
        outLbl.drawsBackground = false
        body.addSubview(outLbl)

        adhanOutputPopup.frame = NSRect(x: 78, y: y, width: W - 96, height: 26)
        adhanOutputPopup.removeAllItems()
        adhanOutputPopup.addItem(withTitle: t("settings.adhan.output.default"))
        adhanOutputDevices = listAudioOutputDevices()
        for dev in adhanOutputDevices {
            adhanOutputPopup.addItem(withTitle: dev.name)
        }
        adhanOutputPopup.target = self
        adhanOutputPopup.action = #selector(adhanOutputChanged)
        body.addSubview(adhanOutputPopup)
        y += 36

        body.addSubview(sectionDivider(y: y, width: W)); y += 14

        // Notifications
        body.addSubview(sectionLabel(t("settings.section.notifications"), y: y, width: W)); y += 18
        notifCheck.frame = NSRect(x: 18, y: y, width: W - 36, height: 22)
        notifCheck.target = self
        notifCheck.action = #selector(notifToggleChanged)
        body.addSubview(notifCheck)
        y += 30

        // Heads-up before prayer — popup with "Off / 5 / 10 / 15 / 20 / 30 /
        // 45 / 60 min before". Adhan still plays at the scheduled time; this
        // is purely a reminder so the user has time to prepare.
        let puLbl = NSTextField(labelWithString: t("settings.notif.headsup"))
        puLbl.frame = NSRect(x: 18, y: y + 5, width: W - 126, height: 18)
        puLbl.font = Localizer.shared.font(size: 12)
        puLbl.textColor = .labelColor
        puLbl.drawsBackground = false
        puLbl.lineBreakMode = .byTruncatingTail
        body.addSubview(puLbl)

        preAdhanPopup.frame = NSRect(x: W - 126 + 18, y: y,
                                     width: 108, height: 26)
        preAdhanPopup.removeAllItems()
        for minutes in kPreAdhanOptions {
            if minutes == 0 {
                preAdhanPopup.addItem(withTitle: t("settings.notif.headsup.off"))
            } else {
                let fmt = t("settings.notif.headsup.minutes")
                preAdhanPopup.addItem(withTitle:
                    localizedInterfaceDigits(String(format: fmt, minutes)))
            }
        }
        preAdhanPopup.target = self
        preAdhanPopup.action = #selector(preAdhanChanged)
        body.addSubview(preAdhanPopup)
        y += 34

        // Adhkar auto-recite toggle — when on, the morning/evening adhkar
        // recitation opens automatically at the anchor time (sunrise / Asr).
        body.addSubview(sectionLabel(t("settings.section.adhkar"), y: y, width: W)); y += 18
        adhkarCheck.frame = NSRect(x: 18, y: y, width: W - 36, height: 22)
        adhkarCheck.target = self
        adhkarCheck.action = #selector(adhkarToggleChanged)
        body.addSubview(adhkarCheck)
        y += 30

        installPanel(body, contentHeight: y, scrollView: soundTabScroll, width: W)
    }

    @objc private func backTapped() { onDone?() }
    /// Save = close and return to main. Every preference already persists the
    /// moment it's changed (adhanChanged, notifToggleChanged, etc. all write
    /// straight to UserDefaults), so there's nothing to commit here — this is
    /// really a "done" button with a clearer label.
    @objc private func saveTapped() { onDone?() }
    @objc private func openPickerTapped() { onOpenPicker?() }
    @objc private func tabChanged() {
        let idx = tabBar.selectedSegment
        for (i, s) in panelScrolls.enumerated() { s.isHidden = (i != idx) }
        if tabHints.indices.contains(idx) {
            tabHintLabel.stringValue = tabHints[idx]
        }
    }
    @objc private func appearanceChanged() {
        let vals = ["system", "light", "dark"]
        UserDefaults.standard.set(vals[appearanceSeg.selectedSegment], forKey: kAppearanceKey)
        appDelegate?.applyAppearancePref()
    }
    @objc private func accentSwatchTapped(_ sender: AccentSwatchButton) {
        // Persist the new accent and trigger a full rebuild of the popover so
        // every label, chip, and swatch re-reads the palette. Same path the
        // quick theme menu on the main page uses (`themeAccentPicked`).
        UserDefaults.standard.set(sender.accentKey, forKey: kAccentPref)
        for btn in accentSwatches {
            btn.isSelectedSwatch = (btn.accentKey == sender.accentKey)
        }
        appDelegate?.applyThemeChange()
    }
    @objc private func materialChanged() {
        let key = materialSeg.selectedSegment == 1 ? "glass" : "opaque"
        UserDefaults.standard.set(key, forKey: kMaterialPref)
        appDelegate?.applyThemeChange()
    }
    @objc private func languageChanged() {
        let idx = languagePopup.indexOfSelectedItem
        guard kSupportedLanguages.indices.contains(idx) else { return }
        Localizer.shared.setLanguage(kSupportedLanguages[idx].code)
    }
    @objc private func adhanToggleChanged() {
        UserDefaults.standard.set(adhanCheck.state == .on, forKey: kAdhanEnabled)
    }
    @objc private func adhanSoundChanged() {
        let idx = adhanSoundPopup.indexOfSelectedItem
        guard adhanCatalog.indices.contains(idx) else { return }
        setCurrentAdhan(adhanCatalog[idx].id)
    }
    @objc private func adhanOutputChanged() {
        let idx = adhanOutputPopup.indexOfSelectedItem
        if idx <= 0 {
            // "System default" selected — clear the override.
            UserDefaults.standard.set("", forKey: kAdhanAudioDevice)
        } else if adhanOutputDevices.indices.contains(idx - 1) {
            UserDefaults.standard.set(adhanOutputDevices[idx - 1].uid,
                                      forKey: kAdhanAudioDevice)
        }
    }
    @objc private func testTapped() {
        // Toggle: playing → stop; idle → play. The button's icon is swapped
        // in `refreshTestButton()` which is called both from the action and
        // from the adhan-state observer so natural end-of-playback also
        // restores the play glyph.
        guard let app = appDelegate else { return }
        if app.isAdhanPlaying {
            app.stopAdhan()
        } else {
            app.playAdhan()
        }
    }

    /// Sync the Test button's icon + tooltip to the current adhan state.
    /// Called on playback state transitions so the play ↔ stop affordance
    /// tracks reality even when playback ends on its own.
    fileprivate func refreshTestButton() {
        guard testBtn != nil else { return }
        let playing = appDelegate?.isAdhanPlaying ?? false
        let sym = playing ? "stop.fill" : "play.fill"
        if let img = templateSymbol(sym, pointSize: 13, weight: .regular) {
            testBtn.image = img
        }
        testBtn.toolTip = playing ? t("tooltip.stop_adhan") : t("tooltip.test_adhan")
    }
    @objc private func notifToggleChanged() {
        let on = (notifCheck.state == .on)
        UserDefaults.standard.set(on, forKey: kNotificationsKey)
        if on { appDelegate?.requestNotificationAuthorization() }
    }
    @objc private func adhkarToggleChanged() {
        let on = (adhkarCheck.state == .on)
        UserDefaults.standard.set(on, forKey: kAdhkarEnabled)
    }
    @objc private func preAdhanChanged() {
        let idx = preAdhanPopup.indexOfSelectedItem
        guard kPreAdhanOptions.indices.contains(idx) else { return }
        let minutes = kPreAdhanOptions[idx]
        UserDefaults.standard.set(minutes, forKey: kPreAdhanLeadMinutes)
        // Turning the feature on implies the user wants notifications — ask
        // for the OS permission now so the first real heads-up actually
        // surfaces instead of being silently swallowed.
        if minutes > 0 { appDelegate?.requestNotificationAuthorization() }
    }
    @objc private func timeFormatChanged() {
        let fmt = timeFormatSeg.selectedSegment == 1 ? "12h" : "24h"
        UserDefaults.standard.set(fmt, forKey: kTimeFormat)
        // All user-facing times pass through displayTime() — re-render both
        // the popover contents and the menu-bar title. The status-item width
        // is also sized for the current format (12h needs ~20px more), so
        // rebuild it so "11:45 PM" isn't clipped.
        appDelegate?.updateUI()
        appDelegate?.rebuildStatusItem()
    }
    @objc private func menuBarToggleChanged() {
        UserDefaults.standard.set(barIconCheck.state      == .on, forKey: kBarShowIcon)
        UserDefaults.standard.set(barTimeCheck.state      == .on, forKey: kBarShowTime)
        UserDefaults.standard.set(barCountdownCheck.state == .on, forKey: kBarShowCountdown)
        // Status-item width depends on which parts are shown; rebuild it.
        appDelegate?.rebuildStatusItem()
    }

    @objc private func barHijriFormatChanged() {
        let idx = max(0, barHijriPopup.indexOfSelectedItem)
        let fmt = kHijriFormatOrder[idx]
        UserDefaults.standard.set(fmt.rawValue, forKey: kBarHijriFormat)
        // Keep the legacy bool in sync in case any older code path still
        // reads it — "off" maps to false, everything else to true.
        UserDefaults.standard.set(fmt != .off, forKey: kBarShowHijri)
        appDelegate?.rebuildStatusItem()
    }
    @objc private func openAtLoginChanged() {
        let wanted = (openAtLoginCheck.state == .on)
        let ok = setOpenAtLogin(wanted)
        // Re-read the live status; on sandboxed / unsigned builds the register
        // call can silently fail and we want the checkbox to mirror reality.
        openAtLoginCheck.state = isOpenAtLoginEnabled() ? .on : .off
        if !ok {
            // Briefly let the user know it didn't stick.
            openAtLoginCheck.toolTip = t("tooltip.open_at_login_failed")
        } else {
            openAtLoginCheck.toolTip = nil
        }
    }
}

// ============================================================================
// MARK: Main window — full prayer and Adhkar management UI
// ============================================================================
// The app stays a menu-bar app by default (LSUIElement=true, .accessory
// policy). When the adhkar window opens we flip to .regular so a dock icon
// appears, and flip back to .accessory when it closes.
//
// Adhan/prayer times and Adhkar are equal destinations. Shared settings are
// opened from a gear button rather than occupying a third content tab.

protocol MainTabContent: NSViewController {
    func tabDidActivate()
}

final class MainWindow: NSWindow, NSWindowDelegate, NSToolbarDelegate {

    private static let destinationsItemID = NSToolbarItem.Identifier("salattime.destinations")
    private static let settingsItemID = NSToolbarItem.Identifier("salattime.settings")

    private weak var appDelegate: AppDelegate?
    private var contentContainer: NSView!
    private var adhanVC: PrayerDashboardViewController?
    private var editorVC: AdhkarEditorViewController?
    private var quranVC: QuranViewController?
    private var settingsVC: AdhkarSettingsViewController?
    private var viewSwitcher: NSSegmentedControl!
    private var settingsButton: HoverIconButton!
    private var isShowingSettings = false

    init(appDelegate: AppDelegate) {
        self.appDelegate = appDelegate
        let frame = NSRect(x: 0, y: 0, width: 960, height: 640)
        super.init(contentRect: frame,
                   styleMask: [.titled, .closable, .miniaturizable, .resizable],
                   backing: .buffered, defer: false)
        self.title = "Salat Time"
        self.titleVisibility = .visible
        self.titlebarAppearsTransparent = false
        self.isMovableByWindowBackground = false
        if #available(macOS 11.0, *) { self.toolbarStyle = .unifiedCompact }
        self.center()
        self.isReleasedWhenClosed = false
        self.minSize = NSSize(width: 820, height: 540)
        self.delegate = self
        buildShell()
    }

    func showMainWindow(selecting destination: Int? = nil) {
        if let destination {
            viewSwitcher.selectedSegment = max(0, min(2, destination))
            isShowingSettings = false
            showSelectedDestination()
        }
        NSApp.setActivationPolicy(.regular)
        makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        activeViewController()?.tabDidActivate()
    }

    func windowWillClose(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
    }

    private func buildShell() {
        let root = RootPanelView(frame: self.contentLayoutRect)
        root.autoresizingMask = [.width, .height]
        root.userInterfaceLayoutDirection = Localizer.shared.isRTL ? .rightToLeft : .leftToRight
        contentView = root

        // The main destinations belong in native macOS chrome. This keeps
        // traffic lights, focus, translucency, and compact-window behavior
        // consistent with the rest of the system while Moroccan detail stays
        // inside the content where it can support rather than overpower it.
        viewSwitcher = NSSegmentedControl()
        viewSwitcher.segmentCount = 3
        viewSwitcher.setLabel(t("settings.section.adhan"), forSegment: 0)
        viewSwitcher.setLabel(t("settings.section.adhkar"), forSegment: 1)
        viewSwitcher.setLabel(featureText("quran.tab"), forSegment: 2)
        viewSwitcher.segmentStyle = .texturedRounded
        viewSwitcher.userInterfaceLayoutDirection = root.userInterfaceLayoutDirection
        viewSwitcher.selectedSegment = 0
        viewSwitcher.target = self
        viewSwitcher.action = #selector(viewSwitched(_:))
        viewSwitcher.frame = NSRect(x: 0, y: 0, width: 360, height: 28)
        viewSwitcher.setAccessibilityLabel(featureText("main.destinations"))

        settingsButton = HoverIconButton(symbol: "gearshape.fill",
                                         toolTip: t("tooltip.settings"),
                                         target: self,
                                         action: #selector(settingsTapped),
                                         pointSize: 15,
                                         size: NSSize(width: 40, height: 34))
        settingsButton.idleTint = .secondaryLabelColor
        settingsButton.hoverTint = .labelColor
        settingsButton.contentTintColor = settingsButton.idleTint

        contentContainer = NSView()
        contentContainer.translatesAutoresizingMaskIntoConstraints = false
        root.contentContainer.addSubview(contentContainer)

        NSLayoutConstraint.activate([
            contentContainer.leadingAnchor.constraint(equalTo: root.contentContainer.leadingAnchor),
            contentContainer.trailingAnchor.constraint(equalTo: root.contentContainer.trailingAnchor),
            contentContainer.topAnchor.constraint(equalTo: root.contentContainer.topAnchor),
            contentContainer.bottomAnchor.constraint(equalTo: root.contentContainer.bottomAnchor),
        ])

        let toolbar = NSToolbar(identifier: NSToolbar.Identifier("salattime.main.toolbar"))
        toolbar.delegate = self
        toolbar.displayMode = .iconOnly
        toolbar.allowsUserCustomization = false
        toolbar.autosavesConfiguration = false
        self.toolbar = toolbar
    }

    func toolbarAllowedItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        [.flexibleSpace, Self.destinationsItemID, Self.settingsItemID]
    }

    func toolbarDefaultItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        [.flexibleSpace, Self.destinationsItemID, .flexibleSpace, Self.settingsItemID]
    }

    func toolbar(_ toolbar: NSToolbar,
                 itemForItemIdentifier itemIdentifier: NSToolbarItem.Identifier,
                 willBeInsertedIntoToolbar flag: Bool) -> NSToolbarItem? {
        let item = NSToolbarItem(itemIdentifier: itemIdentifier)
        if itemIdentifier == Self.destinationsItemID {
            item.view = viewSwitcher
            item.label = featureText("main.destinations")
            item.paletteLabel = item.label
            return item
        }
        if itemIdentifier == Self.settingsItemID {
            item.view = settingsButton
            item.label = t("settings.title")
            item.paletteLabel = item.label
            return item
        }
        return nil
    }

    /// Rebuild every full-window surface after a language, accent, material,
    /// or appearance change. The previous implementation refreshed only the
    /// popup, leaving this window visually and linguistically stale.
    func reloadForPreferences() {
        let selectedTab = viewSwitcher?.selectedSegment ?? 0
        let wasShowingSettings = isShowingSettings
        adhanVC = nil
        editorVC = nil
        quranVC = nil
        settingsVC = nil
        contentView = nil
        buildShell()
        if let appDelegate = appDelegate {
            setAdhan(PrayerDashboardViewController(appDelegate: appDelegate))
            setEditor(AdhkarEditorViewController(appDelegate: appDelegate))
            setQuran(QuranViewController())
        }
        viewSwitcher.selectedSegment = selectedTab
        if wasShowingSettings {
            isShowingSettings = true
            showSettings(section: nil)
        } else {
            showSelectedDestination()
        }
    }

    @objc private func viewSwitched(_ sender: NSSegmentedControl) {
        isShowingSettings = false
        showSelectedDestination()
    }

    @objc private func settingsTapped() {
        if isShowingSettings {
            isShowingSettings = false
            showSelectedDestination()
        } else {
            isShowingSettings = true
            showSettings(section: nil)
        }
    }

    private func activeViewController() -> MainTabContent? {
        if isShowingSettings { return settingsVC }
        switch viewSwitcher?.selectedSegment ?? 0 {
        case 1: return editorVC
        case 2: return quranVC
        default: return adhanVC
        }
    }

    private func showSelectedDestination() {
        switch viewSwitcher.selectedSegment {
        case 1:
            if let editorVC { present(editorVC) }
        case 2:
            if let quranVC { present(quranVC) }
        default:
            if let adhanVC { present(adhanVC) }
        }
    }

    private func showSettings(section: SettingsSection?) {
        if settingsVC == nil {
            settingsVC = AdhkarSettingsViewController(initialSection: section ?? .general)
        } else if let section {
            settingsVC?.selectSection(section)
        }
        guard let settingsVC else { return }
        present(settingsVC)
    }

    /// Public entry point used by the popup gear. Settings remain a single
    /// full-window surface; the compact popup only chooses which section is
    /// most relevant to open.
    func showSettingsWindow(section: SettingsSection) {
        isShowingSettings = true
        showSettings(section: section)
    }

    func reloadPrayerDashboard() {
        adhanVC?.tabDidActivate()
    }

    /// Reuse the app's existing one-second heartbeat for the full dashboard.
    /// This keeps Overview, List, Timeline, and Clock synchronized without
    /// creating a timer per visualization.
    func refreshPrayerLiveState(now: Date = Date()) {
        adhanVC?.refreshLiveState(now: now)
    }

    private func present(_ vc: MainTabContent) {
        contentContainer.subviews.forEach { $0.removeFromSuperview() }
        vc.view.translatesAutoresizingMaskIntoConstraints = false
        contentContainer.addSubview(vc.view)
        NSLayoutConstraint.activate([
            vc.view.leadingAnchor.constraint(equalTo: contentContainer.leadingAnchor),
            vc.view.trailingAnchor.constraint(equalTo: contentContainer.trailingAnchor),
            vc.view.topAnchor.constraint(equalTo: contentContainer.topAnchor),
            vc.view.bottomAnchor.constraint(equalTo: contentContainer.bottomAnchor),
        ])
        vc.tabDidActivate()
    }

    func setAdhan(_ vc: PrayerDashboardViewController) {
        adhanVC = vc
        if viewSwitcher.selectedSegment == 0 && !isShowingSettings {
            present(vc)
        }
    }

    func setEditor(_ vc: AdhkarEditorViewController) {
        editorVC = vc
        if viewSwitcher.selectedSegment == 1 && !isShowingSettings {
            present(vc)
        }
    }

    func setQuran(_ vc: QuranViewController) {
        quranVC = vc
        if viewSwitcher.selectedSegment == 2 && !isShowingSettings {
            present(vc)
        }
    }
}

// ============================================================================
// MARK: Full Adhan dashboard — prayer times + Nawafil guidance
// ============================================================================

/// Eight-point geometry is the one deliberate Moroccan signature in the full
/// dashboard. It is drawn as a quiet lattice instead of using a decorative
/// image so it remains crisp at every window size and never competes with the
/// prayer information.
private func zelligeStarPath(center: NSPoint, outer: CGFloat,
                              inner: CGFloat) -> NSBezierPath {
    let path = NSBezierPath()
    for point in 0..<16 {
        let angle = CGFloat(point) * .pi / 8 - .pi / 2
        let radius = point.isMultiple(of: 2) ? outer : inner
        let value = NSPoint(x: center.x + cos(angle) * radius,
                            y: center.y + sin(angle) * radius)
        point == 0 ? path.move(to: value) : path.line(to: value)
    }
    path.close()
    return path
}

final class MoroccanPatternView: NSView {
    override var isFlipped: Bool { true }
    override var isOpaque: Bool { false }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        let isDark = effectiveAppearance.bestMatch(from: [.darkAqua, .vibrantDark]) != nil
        let ink = NSColor.appAccent.withAlphaComponent(isDark ? 0.085 : 0.048)
        ink.setStroke()

        var row = 0
        var y: CGFloat = 28
        while y < bounds.height + 30 {
            var x: CGFloat = row.isMultiple(of: 2) ? 30 : 64
            while x < bounds.width + 30 {
                let star = zelligeStarPath(center: NSPoint(x: x, y: y),
                                            outer: 12, inner: 5.2)
                star.lineWidth = 0.7
                star.stroke()

                let diamond = NSBezierPath()
                diamond.move(to: NSPoint(x: x + 22, y: y))
                diamond.line(to: NSPoint(x: x + 30, y: y + 8))
                diamond.line(to: NSPoint(x: x + 38, y: y))
                diamond.line(to: NSPoint(x: x + 30, y: y - 8))
                diamond.close()
                diamond.lineWidth = 0.55
                diamond.stroke()
                x += 68
            }
            y += 54
            row += 1
        }
    }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        needsDisplay = true
    }

    override func hitTest(_ point: NSPoint) -> NSView? { nil }
}

final class MoroccanHeroView: NSView {
    override var isFlipped: Bool { true }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.shadowColor = NSColor.black.cgColor
        layer?.shadowOpacity = 0.16
        layer?.shadowRadius = 9
        layer?.shadowOffset = NSSize(width: 0, height: -2)
        setAccessibilityRole(.group)
        setAccessibilityLabel(featureText("full.next_prayer"))
    }

    required init?(coder: NSCoder) { fatalError() }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        let cardRect = bounds.insetBy(dx: 1, dy: 1)
        let card = NSBezierPath(roundedRect: cardRect, xRadius: 18, yRadius: 18)
        let accent = currentAccentPair().light
        let deepGreen = NSColor(red: 0.025, green: 0.19, blue: 0.135, alpha: 1)
        NSGraphicsContext.saveGraphicsState()
        card.addClip()
        NSGradient(starting: accent, ending: deepGreen)?.draw(in: card, angle: 0)

        NSColor.white.withAlphaComponent(0.10).setStroke()
        var x = bounds.width * 0.56
        while x < bounds.width + 30 {
            var y: CGFloat = 12
            while y < bounds.height + 24 {
                let star = zelligeStarPath(center: NSPoint(x: x, y: y),
                                            outer: 19, inner: 8)
                star.lineWidth = 0.8
                star.stroke()
                y += 44
            }
            x += 48
        }
        NSGraphicsContext.restoreGraphicsState()

        NSColor.white.withAlphaComponent(0.18).setStroke()
        card.lineWidth = 0.8
        card.stroke()
    }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        needsDisplay = true
    }
}

enum PrayerScheduleKind: String {
    case obligatory
    case rawatib
    case duha
    case qiyam
    case witr
}

enum PrayerSchedulePrecision {
    /// Both edges come from published mosque or astronomical times.
    case exactWindow
    /// A real published time anchors the event, but completion depends on the
    /// congregation or the worshipper. The UI must describe it as guidance.
    case instructionalMarker
}

/// Offline, reviewable guidance shown from every prayer visualization. It is
/// deliberately paraphrased rather than quoting scripture, and always keeps
/// its source reference visible so the reader can distinguish evidence from
/// schedule calculation.
struct PrayerKnowledge {
    let id: String
    let title: String
    let category: String
    let rakahs: String
    let whenText: String
    let howText: String
    let whyText: String
    let citation: String
}

/// One item on the shared prayer-day schedule. Timeline and clock consume the
/// same values as Overview and List, avoiding subtly different invented
/// windows across views.
struct PrayerScheduleEvent {
    let id: String
    let kind: PrayerScheduleKind
    let prayerIndex: Int?
    let startMinute: Int
    let endMinute: Int?
    let precision: PrayerSchedulePrecision
    let knowledge: PrayerKnowledge
}

enum PrayerScheduleBuilder {
    private static let obligatoryRakahs = [2, 4, 4, 3, 4]

    private static func minute(_ value: String) -> Int? {
        let parts = value.split(separator: ":")
        guard parts.count == 2, let hour = Int(parts[0]),
              let minute = Int(parts[1]), (0..<24).contains(hour),
              (0..<60).contains(minute) else { return nil }
        return hour * 60 + minute
    }

    private static func normalizedAfter(_ candidate: Int, start: Int) -> Int {
        candidate < start ? candidate + 24 * 60 : candidate
    }

    private static func time(_ minute: Int) -> String {
        let normalized = (minute % (24 * 60) + 24 * 60) % (24 * 60)
        return displayTime(String(format: "%02d:%02d", normalized / 60,
                                  normalized % 60))
    }

    private static func obligatoryKnowledge(index: Int, title: String,
                                             entry: Int,
                                             iqama: Int?) -> PrayerKnowledge {
        let count = localizedInterfaceDigits(String(obligatoryRakahs[index]))
        let iqamaText = iqama.map {
            String(format: prayerInfoText("obligatory.when.iqama"), time(entry), time($0))
        } ?? String(format: prayerInfoText("obligatory.when.no_iqama"), time(entry))
        return PrayerKnowledge(
            id: "fard.\(index)", title: title,
            category: prayerInfoText("category.obligatory"), rakahs: count,
            whenText: iqamaText,
            howText: String(format: prayerInfoText("obligatory.how"), count),
            whyText: prayerInfoText("obligatory.why"),
            citation: "Qur’an 4:103 · Ṣaḥīḥ al-Bukhārī 527")
    }

    private static func nawafilKnowledge(id: String, titleKey: String,
                                         rakahsKey: String, whenText: String,
                                         howKey: String, whyKey: String,
                                         citation: String) -> PrayerKnowledge {
        PrayerKnowledge(
            id: id, title: featureText(titleKey),
            category: prayerInfoText("category.nawafil"),
            rakahs: prayerInfoText(rakahsKey), whenText: whenText,
            howText: prayerInfoText(howKey), whyText: prayerInfoText(whyKey),
            citation: citation)
    }

    /// Builds all five obligatory prayers plus evidence-backed Rawatib, Duha,
    /// Qiyam, and Witr guidance. A before-Fard Sunnah never begins before the
    /// prayer's entry: when iqama is available that real interval is used;
    /// otherwise the entry time becomes an instructional marker.
    static func events(info: MosqueInfo, prayerNames: [String],
                       iqamaTimeAt: (Int) -> String?) -> [PrayerScheduleEvent] {
        var result: [PrayerScheduleEvent] = []
        var entries: [Int?] = (0..<5).map {
            info.times.indices.contains($0) ? minute(info.times[$0]) : nil
        }
        if entries.count < 5 { entries += Array(repeating: nil, count: 5 - entries.count) }
        let iqamas: [Int?] = (0..<5).map { index in
            guard let start = entries[index], let raw = iqamaTimeAt(index),
                  let parsed = minute(raw) else { return nil }
            let value = normalizedAfter(parsed, start: start)
            // Reject malformed next-day values; normal mosque iqama intervals
            // are short and should never span most of a day.
            return value > start && value - start <= 180 ? value : nil
        }

        for index in 0..<min(5, prayerNames.count) {
            guard let entry = entries[index] else { continue }
            let knowledge = obligatoryKnowledge(index: index,
                                                title: prayerNames[index],
                                                entry: entry,
                                                iqama: iqamas[index])
            result.append(PrayerScheduleEvent(
                id: knowledge.id, kind: .obligatory, prayerIndex: index,
                startMinute: entry, endMinute: nil,
                precision: .instructionalMarker,
                knowledge: knowledge))
        }

        func beforeFard(id: String, prayerIndex: Int, rakahsKey: String,
                        citation: String) {
            guard let entry = entries[prayerIndex] else { return }
            let whenText: String
            let precision: PrayerSchedulePrecision
            if let iqama = iqamas[prayerIndex] {
                whenText = String(format: prayerInfoText("rawatib.before.window"),
                                  time(entry), time(iqama))
                precision = .exactWindow
            } else {
                whenText = String(format: prayerInfoText("rawatib.before.marker"),
                                  time(entry))
                precision = .instructionalMarker
            }
            let knowledge = nawafilKnowledge(
                id: id, titleKey: "nawafil.rawatib", rakahsKey: rakahsKey,
                whenText: whenText, howKey: "rawatib.how",
                whyKey: "rawatib.why", citation: citation)
            result.append(PrayerScheduleEvent(
                id: id, kind: .rawatib, prayerIndex: prayerIndex,
                startMinute: entry, endMinute: iqamas[prayerIndex],
                precision: precision, knowledge: knowledge))
        }

        func afterFard(id: String, prayerIndex: Int, rakahsKey: String,
                       citation: String) {
            guard let entry = entries[prayerIndex] else { return }
            let marker = iqamas[prayerIndex] ?? entry
            let whenText = iqamas[prayerIndex].map {
                String(format: prayerInfoText("rawatib.after.iqama"), time($0))
            } ?? String(format: prayerInfoText("rawatib.after.no_iqama"), time(entry))
            let knowledge = nawafilKnowledge(
                id: id, titleKey: "nawafil.rawatib", rakahsKey: rakahsKey,
                whenText: whenText, howKey: "rawatib.how",
                whyKey: "rawatib.why", citation: citation)
            result.append(PrayerScheduleEvent(
                id: id, kind: .rawatib, prayerIndex: prayerIndex,
                startMinute: marker, endMinute: nil,
                precision: .instructionalMarker, knowledge: knowledge))
        }

        beforeFard(id: "rawatib.fajr.before", prayerIndex: 0,
                    rakahsKey: "nawafil.rawatib.fajr.count",
                    citation: "Jāmiʿ at-Tirmidhī 415 · Ṣaḥīḥ Muslim 725a")
        beforeFard(id: "rawatib.dhuhr.before", prayerIndex: 1,
                    rakahsKey: "nawafil.rawatib.dhuhr.before.count",
                    citation: "Jāmiʿ at-Tirmidhī 415")
        afterFard(id: "rawatib.dhuhr.after", prayerIndex: 1,
                   rakahsKey: "nawafil.rawatib.after.count",
                   citation: "Jāmiʿ at-Tirmidhī 415")
        afterFard(id: "rawatib.maghrib.after", prayerIndex: 3,
                   rakahsKey: "nawafil.rawatib.after.count",
                   citation: "Jāmiʿ at-Tirmidhī 415")
        afterFard(id: "rawatib.isha.after", prayerIndex: 4,
                   rakahsKey: "nawafil.rawatib.after.count",
                   citation: "Jāmiʿ at-Tirmidhī 415")

        if let sunrise = minute(info.shuruq), let dhuhr = entries[1] {
            let start = sunrise + 20
            if start < dhuhr {
                let whenText = String(format: prayerInfoText("duha.when"),
                                      time(start), time(dhuhr))
                let knowledge = nawafilKnowledge(
                    id: "duha", titleKey: "nawafil.duha",
                    rakahsKey: "nawafil.duha.count", whenText: whenText,
                    howKey: "duha.how", whyKey: "duha.why",
                    citation: "Ṣaḥīḥ Muslim 720 · Ṣaḥīḥ al-Bukhārī 1176")
                result.append(PrayerScheduleEvent(
                    id: "duha", kind: .duha, prayerIndex: nil,
                    startMinute: start, endMinute: dhuhr,
                    precision: .instructionalMarker, knowledge: knowledge))
            }
        }

        if let isha = entries[4], let fajrBase = entries[0] {
            let start = iqamas[4] ?? isha
            let fajr = normalizedAfter(fajrBase, start: start)
            if start < fajr {
                let qiyamWhen = String(format: prayerInfoText(
                    iqamas[4] == nil ? "qiyam.when.no_iqama" : "qiyam.when.iqama"),
                    time(start), time(fajr))
                let qiyam = nawafilKnowledge(
                    id: "qiyam", titleKey: "nawafil.qiyam",
                    rakahsKey: "nawafil.qiyam.count", whenText: qiyamWhen,
                    howKey: "qiyam.how", whyKey: "qiyam.why",
                    citation: "Ṣaḥīḥ Muslim 1163a · Ṣaḥīḥ al-Bukhārī 1145")
                result.append(PrayerScheduleEvent(
                    id: "qiyam", kind: .qiyam, prayerIndex: nil,
                    startMinute: start, endMinute: fajr,
                    precision: .instructionalMarker,
                    knowledge: qiyam))

                let witr = nawafilKnowledge(
                    id: "witr", titleKey: "nawafil.witr",
                    rakahsKey: "nawafil.witr.count", whenText: qiyamWhen,
                    howKey: "witr.how", whyKey: "witr.why",
                    citation: "Ṣaḥīḥ Muslim 751b")
                result.append(PrayerScheduleEvent(
                    id: "witr", kind: .witr, prayerIndex: nil,
                    startMinute: start, endMinute: fajr,
                    precision: .instructionalMarker,
                    knowledge: witr))
            }
        }
        return result.sorted {
            $0.startMinute == $1.startMinute ? $0.id < $1.id
                                             : $0.startMinute < $1.startMinute
        }
    }
}

final class PrayerInfoViewController: NSViewController {
    private let knowledge: PrayerKnowledge

    init(knowledge: PrayerKnowledge) {
        self.knowledge = knowledge
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError() }

    override func loadView() {
        let width: CGFloat = 400
        let viewportHeight: CGFloat = 390
        let scroll = NSScrollView(frame: NSRect(x: 0, y: 0, width: width,
                                                 height: viewportHeight))
        scroll.drawsBackground = false
        scroll.hasVerticalScroller = true
        scroll.autohidesScrollers = true

        let content = FlippedView(frame: NSRect(x: 0, y: 0, width: width, height: 560))
        scroll.documentView = content
        let isRTL = Localizer.shared.isRTL
        let alignment: NSTextAlignment = isRTL ? .right : .left
        var y: CGFloat = 20

        @discardableResult
        func addLabel(_ text: String, size: CGFloat,
                      weight: NSFont.Weight = .regular,
                      color: NSColor = .labelColor,
                      maximumLines: Int = 4,
                      spacingAfter: CGFloat = 8) -> NSTextField {
            let font = Localizer.shared.font(size: size, weight: weight)
            let textWidth = width - 40
            // Measure every language as a wrapping paragraph. The shared
            // localizedTextHeight helper intentionally keeps short LTR labels
            // compact, which is not suitable for these longer guidance cards.
            let measured = (text as NSString).boundingRect(
                with: NSSize(width: textWidth,
                             height: CGFloat.greatestFiniteMagnitude),
                options: [.usesLineFragmentOrigin, .usesFontLeading],
                attributes: [.font: font]).height
            let height = max(ceil(measured), ceil(font.ascender - font.descender
                                                   + font.leading))
            let field = NSTextField(wrappingLabelWithString: text)
            field.frame = NSRect(x: 20, y: y, width: textWidth, height: height)
            field.font = font
            field.textColor = color
            field.alignment = alignment
            field.baseWritingDirection = isRTL ? .rightToLeft : .leftToRight
            field.maximumNumberOfLines = 0
            field.lineBreakMode = .byWordWrapping
            field.cell?.truncatesLastVisibleLine = false
            content.addSubview(field)
            y += height + spacingAfter
            return field
        }

        addLabel(knowledge.category.uppercased(), size: 10.5, weight: .bold,
                 color: .appGreenAccent, maximumLines: 1, spacingAfter: 3)
        addLabel(knowledge.title, size: 24, weight: .bold,
                 maximumLines: 2, spacingAfter: 4)
        addLabel("\(featureText("full.rakahs")) · \(knowledge.rakahs)",
                 size: 13, weight: .semibold, color: .secondaryLabelColor,
                 maximumLines: 2, spacingAfter: 16)

        func addSection(_ headingKey: String, _ body: String) {
            addLabel(prayerInfoText(headingKey).uppercased(), size: 10.5,
                     weight: .bold, color: .tertiaryLabelColor,
                     maximumLines: 1, spacingAfter: 2)
            addLabel(body, size: 13.5, maximumLines: 5, spacingAfter: 13)
        }
        addSection("info.when", knowledge.whenText)
        addSection("info.how", knowledge.howText)
        addSection("info.why", knowledge.whyText)
        addSection("info.evidence", localizedInterfaceDigits(knowledge.citation))

        content.frame.size.height = max(viewportHeight, y + 10)
        content.setAccessibilityElement(true)
        content.setAccessibilityRole(.group)
        content.setAccessibilityLabel("\(knowledge.title). \(knowledge.category)")
        scroll.setAccessibilityLabel(prayerInfoText("info.open"))
        self.view = scroll
        preferredContentSize = NSSize(width: width, height: viewportHeight)
    }
}

/// A 24-hour visualization that makes the relationship between the obligatory
/// prayers and the Nawafil windows visible at a glance. The overview remains
/// available for users who prefer a conventional list.
final class PrayerDayTimelineView: NSControl {
    private let info: MosqueInfo
    private let prayerNames: [String]
    private let showsNawafil: Bool
    private let events: [PrayerScheduleEvent]
    var onSelectEvent: ((PrayerScheduleEvent, NSView) -> Void)?
    private var markerPoints: [(point: NSPoint, name: String, raw: String,
                                event: PrayerScheduleEvent?)] = []
    private var hoveredMarker: Int?
    private var selectedMarker: Int?
    private var trackingAreaRef: NSTrackingArea?
    private var minuteTimer: Timer?

    override var isFlipped: Bool { true }
    override var acceptsFirstResponder: Bool { true }

    init(frame: NSRect, info: MosqueInfo, prayerNames: [String],
         showsNawafil: Bool, events: [PrayerScheduleEvent] = [],
         onSelectEvent: ((PrayerScheduleEvent, NSView) -> Void)? = nil) {
        self.info = info
        self.prayerNames = prayerNames
        self.showsNawafil = showsNawafil
        self.events = events
        self.onSelectEvent = onSelectEvent
        super.init(frame: frame)
        setAccessibilityElement(true)
        setAccessibilityRole(.group)
        setAccessibilityLabel(featureText("full.timeline.title"))
        let summary = zip(prayerNames, info.times).map {
            "\($0.0) \(displayTime($0.1))"
        }.joined(separator: ", ")
        setAccessibilityValue(summary)
    }

    required init?(coder: NSCoder) { fatalError() }

    deinit { minuteTimer?.invalidate() }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        minuteTimer?.invalidate()
        guard window != nil else { return }
        window?.acceptsMouseMovedEvents = true
        let timer = Timer(timeInterval: 30, repeats: true) { [weak self] _ in
            self?.needsDisplay = true
        }
        RunLoop.main.add(timer, forMode: .common)
        minuteTimer = timer
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let trackingAreaRef { removeTrackingArea(trackingAreaRef) }
        let area = NSTrackingArea(rect: bounds,
                                  options: [.mouseMoved, .mouseEnteredAndExited,
                                            .activeInActiveApp, .inVisibleRect],
                                  owner: self, userInfo: nil)
        addTrackingArea(area)
        trackingAreaRef = area
    }

    private func nearestMarker(to point: NSPoint) -> Int? {
        markerPoints.enumerated().min(by: {
            hypot($0.element.point.x - point.x, $0.element.point.y - point.y)
              < hypot($1.element.point.x - point.x, $1.element.point.y - point.y)
        }).flatMap {
            hypot($0.element.point.x - point.x, $0.element.point.y - point.y) <= 30
                ? $0.offset : nil
        }
    }

    override func mouseMoved(with event: NSEvent) {
        hoveredMarker = nearestMarker(to: convert(event.locationInWindow, from: nil))
        needsDisplay = true
    }

    override func mouseExited(with event: NSEvent) {
        hoveredMarker = nil
        needsDisplay = true
    }

    override func mouseDown(with event: NSEvent) {
        window?.makeFirstResponder(self)
        selectedMarker = nearestMarker(to: convert(event.locationInWindow, from: nil))
        if let selectedMarker, markerPoints.indices.contains(selectedMarker),
           let scheduleEvent = markerPoints[selectedMarker].event {
            onSelectEvent?(scheduleEvent, self)
        }
        needsDisplay = true
    }

    override func keyDown(with event: NSEvent) {
        guard event.keyCode == 123 || event.keyCode == 124, !markerPoints.isEmpty else {
            super.keyDown(with: event)
            return
        }
        let delta = event.keyCode == 123 ? -1 : 1
        selectedMarker = ((selectedMarker ?? (delta > 0 ? -1 : 0)) + delta
                          + markerPoints.count) % markerPoints.count
        needsDisplay = true
    }

    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        if (event.keyCode == 36 || event.characters == " "),
           let selectedMarker, markerPoints.indices.contains(selectedMarker),
           let scheduleEvent = markerPoints[selectedMarker].event {
            onSelectEvent?(scheduleEvent, self)
            return true
        }
        return super.performKeyEquivalent(with: event)
    }

    private func minute(_ hhmm: String) -> Int? {
        let parts = hhmm.split(separator: ":")
        guard parts.count == 2, let hour = Int(parts[0]),
              let minute = Int(parts[1]) else { return nil }
        return max(0, min(1439, hour * 60 + minute))
    }

    private func drawText(_ value: String, in rect: NSRect, size: CGFloat,
                          weight: NSFont.Weight = .regular,
                          color: NSColor = .labelColor,
                          alignment: NSTextAlignment = .left,
                          lineBreak: NSLineBreakMode = .byTruncatingTail) {
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = alignment
        paragraph.lineBreakMode = lineBreak
        paragraph.baseWritingDirection = Localizer.shared.isRTL ? .rightToLeft : .leftToRight
        let font = Localizer.shared.font(size: size, weight: weight)
        let lines = value.contains("\n") ? 2 : 1
        let drawingRect = localizedTextFrame(rect, text: value, font: font,
                                             maximumLines: lines)
        NSAttributedString(string: value, attributes: [
            .font: font,
            .foregroundColor: color,
            .paragraphStyle: paragraph,
        ]).draw(with: drawingRect,
                options: [.usesLineFragmentOrigin, .usesFontLeading])
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        let isDark = effectiveAppearance.bestMatch(from: [.darkAqua, .vibrantDark]) != nil
        let card = NSBezierPath(roundedRect: bounds.insetBy(dx: 1, dy: 1),
                                xRadius: 16, yRadius: 16)
        (isDark ? NSColor(white: 1, alpha: 0.07)
                : NSColor(white: 1, alpha: 0.86)).setFill()
        card.fill()
        (isDark ? NSColor.white.withAlphaComponent(0.13)
                : NSColor.black.withAlphaComponent(0.10)).setStroke()
        card.lineWidth = 0.7
        card.stroke()

        let leading = Localizer.shared.isRTL ? NSTextAlignment.right : .left
        drawText(featureText("full.timeline.title"),
                 in: NSRect(x: 22, y: 18, width: bounds.width - 44, height: 26),
                 size: 20, weight: .semibold, alignment: leading)
        drawText(featureText("full.guidance"),
                 in: NSRect(x: 22, y: 46, width: bounds.width - 44, height: 18),
                 size: 11, color: .secondaryLabelColor, alignment: leading)

        let left: CGFloat = 38
        let right: CGFloat = bounds.width - 38
        let timelineWidth = max(1, right - left)
        func xFor(_ value: Int) -> CGFloat {
            let fraction = CGFloat(max(0, min(1440, value))) / 1440
            return Localizer.shared.isRTL
                ? right - timelineWidth * fraction
                : left + timelineWidth * fraction
        }
        func drawBand(from start: Int, to end: Int, color: NSColor,
                      title: String, showsTitle: Bool = true) {
            guard end > start else { return }
            let startX = xFor(start)
            let endX = xFor(end)
            let rect = NSRect(x: min(startX, endX), y: 82,
                              width: max(3, abs(endX - startX)), height: 25)
            color.setFill()
            NSBezierPath(roundedRect: rect, xRadius: 6, yRadius: 6).fill()
            if showsTitle && rect.width > 44 {
                drawText(title, in: rect.insetBy(dx: 5, dy: 5), size: 8.5,
                         weight: .semibold,
                         color: isDark ? .white : .labelColor,
                         alignment: .center)
            }
        }

        let fajr = info.times.indices.contains(0) ? minute(info.times[0]) : nil
        let dhuhr = info.times.indices.contains(1) ? minute(info.times[1]) : nil
        let maghrib = info.times.indices.contains(3) ? minute(info.times[3]) : nil
        let isha = info.times.indices.contains(4) ? minute(info.times[4]) : nil
        let shuruq = minute(info.shuruq)
        if showsNawafil {
            let nightColor = NSColor.systemIndigo.withAlphaComponent(isDark ? 0.30 : 0.16)
            if let fajr { drawBand(from: 0, to: fajr, color: nightColor,
                                   title: featureText("nawafil.qiyam"), showsTitle: fajr > 100) }
            if let isha { drawBand(from: isha, to: 1440, color: nightColor,
                                   title: featureText("nawafil.qiyam")) }
            if let shuruq, let dhuhr {
                drawBand(from: min(1440, shuruq + 20), to: max(0, dhuhr - 10),
                         color: NSColor.appAccent.withAlphaComponent(isDark ? 0.28 : 0.17),
                         title: featureText("nawafil.duha"))
            }
        }

        let lineY: CGFloat = 184
        let line = NSBezierPath()
        line.move(to: NSPoint(x: left, y: lineY))
        line.line(to: NSPoint(x: right, y: lineY))
        (isDark ? NSColor.white.withAlphaComponent(0.30)
                : NSColor.black.withAlphaComponent(0.24)).setStroke()
        line.lineWidth = 1.2
        line.stroke()

        let gold = NSColor(red: 0.79, green: 0.57, blue: 0.18, alpha: 1)
        func rawatib(_ start: Int, _ end: Int) {
            let startX = xFor(max(0, start))
            let endX = xFor(min(1440, end))
            let rect = NSRect(x: min(startX, endX), y: lineY - 12,
                              width: max(3, abs(endX - startX)),
                              height: 4)
            gold.setFill()
            NSBezierPath(roundedRect: rect, xRadius: 2, yRadius: 2).fill()
        }
        if showsNawafil {
            if let fajr { rawatib(fajr - 35, fajr - 5) }
            if let dhuhr { rawatib(dhuhr - 50, dhuhr - 5); rawatib(dhuhr + 5, dhuhr + 30) }
            if let maghrib { rawatib(maghrib + 5, maghrib + 32) }
            if let isha { rawatib(isha + 5, isha + 35) }
        }

        var points: [(name: String, raw: String, minute: Int, sunrise: Bool)] = []
        for index in 0..<min(5, info.times.count, prayerNames.count) {
            if let value = minute(info.times[index]) {
                points.append((prayerNames[index], info.times[index], value, false))
            }
        }
        if let value = shuruq, !info.shuruq.isEmpty {
            points.append((t("adhkar.editor.schedule.shuruq"), info.shuruq, value, true))
        }
        points.sort { $0.minute < $1.minute }

        markerPoints.removeAll(keepingCapacity: true)
        for (index, point) in points.enumerated() {
            let x = xFor(point.minute)
            let upper = !index.isMultiple(of: 2)
            let stem = NSBezierPath()
            stem.move(to: NSPoint(x: x, y: lineY))
            stem.line(to: NSPoint(x: x, y: upper ? 132 : 214))
            (point.sunrise ? gold : NSColor.appAccent).withAlphaComponent(0.78).setStroke()
            stem.lineWidth = 1
            stem.stroke()

            let marker = NSBezierPath(ovalIn: NSRect(x: x - 4.5, y: lineY - 4.5,
                                                     width: 9, height: 9))
            (point.sunrise ? gold : NSColor.appAccent).setFill()
            marker.fill()
            let scheduleEvent = events.first {
                $0.kind == .obligatory && $0.prayerIndex.flatMap {
                    prayerNames.indices.contains($0) ? prayerNames[$0] : nil
                } == point.name
            }
            markerPoints.append((NSPoint(x: x, y: lineY), point.name,
                                 point.raw, scheduleEvent))
            let labelX = max(8, min(bounds.width - 98, x - 45))
            let labelY: CGFloat = upper ? 112 : 220
            drawText("\(point.name)\n\(displayTime(point.raw))",
                     in: NSRect(x: labelX, y: labelY, width: 90, height: 38),
                     size: 11, weight: .medium,
                     color: point.sunrise ? gold : .labelColor,
                     alignment: .center, lineBreak: .byWordWrapping)
        }

        // A live cursor turns this from a static chart into a day-at-a-glance
        // instrument. Hover or click a marker to inspect it; arrow keys move
        // the selection while the control has focus.
        let calendar = Calendar.current
        let now = Date()
        let nowMinute = calendar.component(.hour, from: now) * 60
                      + calendar.component(.minute, from: now)
        let nowX = xFor(nowMinute)
        let cursor = NSBezierPath()
        cursor.move(to: NSPoint(x: nowX, y: 73))
        cursor.line(to: NSPoint(x: nowX, y: 286))
        NSColor.systemRed.withAlphaComponent(0.72).setStroke()
        cursor.lineWidth = 1
        cursor.stroke()

        if let index = hoveredMarker ?? selectedMarker,
           markerPoints.indices.contains(index) {
            let item = markerPoints[index]
            let calloutW: CGFloat = 150
            let calloutX = max(12, min(bounds.width - calloutW - 12,
                                       item.point.x - calloutW / 2))
            let callout = NSRect(x: calloutX, y: 292, width: calloutW, height: 38)
            (isDark ? NSColor(white: 0.16, alpha: 0.98)
                    : NSColor(white: 0.98, alpha: 0.98)).setFill()
            NSBezierPath(roundedRect: callout, xRadius: 8, yRadius: 8).fill()
            drawText("\(item.name)  \(displayTime(item.raw))", in: callout,
                     size: 12, weight: .semibold, alignment: .center)
        }

        for hour in stride(from: 0, through: 24, by: 6) {
            let x = xFor(hour * 60)
            let tick = NSBezierPath()
            tick.move(to: NSPoint(x: x, y: lineY - 4))
            tick.line(to: NSPoint(x: x, y: lineY + 4))
            NSColor.secondaryLabelColor.setStroke()
            tick.lineWidth = 0.7
            tick.stroke()
            let labelX = max(5, min(bounds.width - 39, x - 18))
            drawText(localizedInterfaceDigits(String(format: "%02d:00", hour % 24)),
                     in: NSRect(x: labelX, y: 272, width: 36, height: 14),
                     size: 9.5, color: .tertiaryLabelColor, alignment: .center)
        }

        if showsNawafil {
            gold.setFill()
            NSBezierPath(roundedRect: NSRect(x: 22, y: 310, width: 24, height: 4),
                         xRadius: 2, yRadius: 2).fill()
            drawText(featureText("nawafil.rawatib"),
                     in: NSRect(x: 54, y: 303, width: bounds.width - 76, height: 18),
                     size: 11, color: .secondaryLabelColor, alignment: leading)
        }
    }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        needsDisplay = true
    }
}

/// An actionable virtual button for events drawn inside a custom prayer view.
/// The owner keeps these elements alive so VoiceOver can enumerate prayers
/// and invoke the same info action as a pointer click.
final class PrayerEventAccessibilityElement: NSAccessibilityElement {
    private let pressHandler: () -> Void

    init(parent: NSView, frame: NSRect, label: String, help: String,
         pressHandler: @escaping () -> Void) {
        self.pressHandler = pressHandler
        super.init()
        setAccessibilityEnabled(true)
        setAccessibilityRole(.button)
        setAccessibilityParent(parent)
        setAccessibilityFrameInParentSpace(frame)
        setAccessibilityLabel(label)
        setAccessibilityHelp(help)
    }

    required init?(coder: NSCoder) { fatalError() }

    override func accessibilityPerformPress() -> Bool {
        pressHandler()
        return true
    }
}

/// Interactive, zoomable prayer-day instrument. It deliberately renders only
/// `PrayerScheduleEvent` values from the shared builder: no visual-only prayer
/// windows or guessed Rawatib offsets are introduced here.
final class InteractivePrayerDayTimelineView: NSControl {
    private struct EventTarget {
        let visualRect: NSRect
        let hitRect: NSRect
        let event: PrayerScheduleEvent
    }

    private let info: MosqueInfo
    private let prayerNames: [String]
    private let showsNawafil: Bool
    private let events: [PrayerScheduleEvent]
    var onSelectEvent: ((PrayerScheduleEvent, NSView) -> Void)?
    var onStateChange: ((CGFloat, CGFloat, String?) -> Void)?

    private var controlRail: NSStackView!
    private var trackingAreaRef: NSTrackingArea?
    private var eventTargets: [EventTarget] = []
    private var selectedEventID: String?
    private var hoveredEventID: String?
    private var hoverMinute: CGFloat?
    private var hoverFocusStartedAt: TimeInterval = 0
    private var selectionPulseStartedAt: TimeInterval?
    private var plotRect: NSRect = .zero
    private var visibleStart: CGFloat = 0
    private var visibleDuration: CGFloat = 1440
    private var dragOriginX: CGFloat?
    private var mouseDownPoint: NSPoint?
    private var dragStartMinute: CGFloat = 0
    private var pendingTarget: EventTarget?
    private var didDrag = false
    private var liveTimer: Timer?
    private var accessibilityEventElements: [PrayerEventAccessibilityElement] = []
    private var accessibilityGeometrySignature = ""
    private lazy var nowText: String = {
        let formatter = RelativeDateTimeFormatter()
        formatter.locale = preferredInterfaceLocale()
        formatter.dateTimeStyle = .named
        formatter.unitsStyle = .full
        return formatter.localizedString(fromTimeInterval: 0)
    }()

    override var isFlipped: Bool { true }
    override var acceptsFirstResponder: Bool { true }

    static func preferredHeight(for width: CGFloat) -> CGFloat {
        width < 760 ? 500 : 530
    }

    init(frame: NSRect, info: MosqueInfo, prayerNames: [String],
         showsNawafil: Bool, events: [PrayerScheduleEvent],
         initialVisibleStart: CGFloat = 0,
         initialVisibleDuration: CGFloat = 1440,
         initialSelectedEventID: String? = nil,
         onStateChange: ((CGFloat, CGFloat, String?) -> Void)? = nil,
         onSelectEvent: ((PrayerScheduleEvent, NSView) -> Void)? = nil) {
        self.info = info
        self.prayerNames = prayerNames
        self.showsNawafil = showsNawafil
        self.events = events
        let duration = max(240, min(1440, initialVisibleDuration))
        self.visibleDuration = duration
        self.visibleStart = max(0, min(1440 - duration, initialVisibleStart))
        self.selectedEventID = events.contains {
            $0.id == initialSelectedEventID
                && (showsNawafil || $0.kind == .obligatory)
        } ? initialSelectedEventID : nil
        self.onStateChange = onStateChange
        self.onSelectEvent = onSelectEvent
        super.init(frame: frame)

        let earlierSymbol = Localizer.shared.isRTL ? "chevron.right" : "chevron.left"
        let laterSymbol = Localizer.shared.isRTL ? "chevron.left" : "chevron.right"
        let controls: [(String, String, Selector)] = [
            (earlierSymbol, prayerInfoText("timeline.earlier"), #selector(showEarlier(_:))),
            ("minus.magnifyingglass", prayerInfoText("timeline.zoom_out"), #selector(zoomOut(_:))),
            ("arrow.left.and.right", prayerInfoText("timeline.fit"), #selector(fitDay(_:))),
            ("scope", nowText, #selector(showNow(_:))),
            ("plus.magnifyingglass", prayerInfoText("timeline.zoom_in"), #selector(zoomIn(_:))),
            (laterSymbol, prayerInfoText("timeline.later"), #selector(showLater(_:))),
        ]
        let buttons = controls.map { symbol, label, action -> NSView in
            let button = HoverIconButton(symbol: symbol, toolTip: label,
                                         target: self, action: action,
                                         pointSize: 14,
                                         size: NSSize(width: 44, height: 44))
            button.setAccessibilityLabel(label)
            button.setAccessibilityHelp(featureText("full.timeline.title"))
            return button
        }
        controlRail = NSStackView(views: buttons)
        controlRail.orientation = .horizontal
        controlRail.alignment = .centerY
        controlRail.spacing = 2
        controlRail.userInterfaceLayoutDirection = Localizer.shared.isRTL
            ? .rightToLeft : .leftToRight
        addSubview(controlRail)

        setAccessibilityElement(true)
        setAccessibilityRole(.group)
        setAccessibilityLabel(featureText("full.timeline.title"))
        setAccessibilityHelp(prayerInfoText("timeline.accessibility_help"))
        updateAccessibilityValue()
    }

    required init?(coder: NSCoder) { fatalError() }
    deinit { liveTimer?.invalidate() }

    override func layout() {
        super.layout()
        let railWidth: CGFloat = 44 * 6 + 2 * 5
        controlRail.frame = NSRect(
            x: Localizer.shared.isRTL ? 16 : bounds.width - railWidth - 16,
            y: 10, width: railWidth, height: 44)
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        liveTimer?.invalidate()
        guard window != nil else { return }
        window?.acceptsMouseMovedEvents = true
        let reduced = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        let interval: TimeInterval = reduced ? 30 : (1.0 / 12.0)
        let timer = Timer(timeInterval: interval, repeats: true) { [weak self] _ in
            guard let self, let window = self.window,
                  window.occlusionState.contains(.visible) else { return }
            self.needsDisplay = true
        }
        timer.tolerance = reduced ? 1 : 0.015
        RunLoop.main.add(timer, forMode: .common)
        liveTimer = timer
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let trackingAreaRef { removeTrackingArea(trackingAreaRef) }
        let area = NSTrackingArea(rect: bounds,
                                  options: [.mouseMoved, .mouseEnteredAndExited,
                                            .activeInActiveApp, .inVisibleRect],
                                  owner: self, userInfo: nil)
        addTrackingArea(area)
        trackingAreaRef = area
    }

    private var displayedEvents: [PrayerScheduleEvent] {
        events.filter { showsNawafil || $0.kind == .obligatory }
    }

    private func updateAccessibilityValue() {
        let selected = displayedEvents.first { $0.id == selectedEventID }
        if let selected {
            setAccessibilityValue("\(selected.knowledge.title). \(selected.knowledge.whenText)")
        } else {
            let summary = zip(prayerNames, info.times).map {
                "\($0.0) \(displayTime($0.1))"
            }.joined(separator: ", ")
            setAccessibilityValue(summary)
        }
    }

    private func setViewport(start: CGFloat, duration: CGFloat) {
        let nextDuration = max(240, min(1440, duration))
        let nextStart = max(0, min(1440 - nextDuration, start))
        visibleDuration = nextDuration
        visibleStart = nextStart
        onStateChange?(visibleStart, visibleDuration, selectedEventID)
        needsDisplay = true
    }

    private func zoom(by factor: CGFloat, anchoredAt anchor: CGFloat? = nil) {
        let focus = anchor ?? (visibleStart + visibleDuration / 2)
        let fraction = max(0, min(1, (focus - visibleStart) / visibleDuration))
        let duration = max(240, min(1440, visibleDuration * factor))
        setViewport(start: focus - duration * fraction, duration: duration)
    }

    private func pan(minutes: CGFloat) {
        setViewport(start: visibleStart + minutes, duration: visibleDuration)
    }

    @objc private func zoomIn(_ sender: Any?) { zoom(by: 0.72) }
    @objc private func zoomOut(_ sender: Any?) { zoom(by: 1.38) }
    @objc private func fitDay(_ sender: Any?) { setViewport(start: 0, duration: 1440) }
    @objc private func showNow(_ sender: Any?) {
        let minute = currentMinute()
        let duration = visibleDuration >= 1439 ? 720 : visibleDuration
        setViewport(start: minute - duration / 2, duration: duration)
    }
    @objc private func showEarlier(_ sender: Any?) { pan(minutes: -visibleDuration * 0.22) }
    @objc private func showLater(_ sender: Any?) { pan(minutes: visibleDuration * 0.22) }

    override func magnify(with event: NSEvent) {
        let factor = max(0.55, min(1.45, 1 - event.magnification))
        let point = convert(event.locationInWindow, from: nil)
        zoom(by: factor, anchoredAt: minute(at: point))
    }

    override func scrollWheel(with event: NSEvent) {
        let horizontal = abs(event.scrollingDeltaX) > abs(event.scrollingDeltaY)
        let shifted = event.modifierFlags.contains(.shift)
        guard horizontal || shifted else {
            // Preserve ordinary vertical document scrolling when the pointer
            // happens to be above the chart.
            super.scrollWheel(with: event)
            return
        }
        let raw = horizontal ? event.scrollingDeltaX : event.scrollingDeltaY
        let direction: CGFloat = Localizer.shared.isRTL ? -1 : 1
        pan(minutes: raw * visibleDuration / 90 * direction)
    }

    private func target(at point: NSPoint) -> EventTarget? {
        eventTargets.filter { $0.hitRect.contains(point) }.min {
            hypot($0.visualRect.midX - point.x, $0.visualRect.midY - point.y)
                < hypot($1.visualRect.midX - point.x, $1.visualRect.midY - point.y)
        }
    }

    private func minute(at point: NSPoint) -> CGFloat? {
        guard !plotRect.isEmpty, plotRect.contains(point) else { return nil }
        let fraction = Localizer.shared.isRTL
            ? (plotRect.maxX - point.x) / plotRect.width
            : (point.x - plotRect.minX) / plotRect.width
        return max(0, min(1440, visibleStart + fraction * visibleDuration))
    }

    override func mouseMoved(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        let nextTarget = target(at: point)
        let nextID = nextTarget?.event.id
        if nextID != hoveredEventID {
            hoveredEventID = nextID
            hoverFocusStartedAt = ProcessInfo.processInfo.systemUptime
        }
        hoverMinute = minute(at: point)
        if nextTarget != nil {
            NSCursor.pointingHand.set()
        } else if hoverMinute != nil {
            NSCursor.crosshair.set()
        } else {
            NSCursor.arrow.set()
        }
        needsDisplay = true
    }

    override func mouseExited(with event: NSEvent) {
        hoveredEventID = nil
        hoverMinute = nil
        NSCursor.arrow.set()
        needsDisplay = true
    }

    override func mouseDown(with event: NSEvent) {
        window?.makeFirstResponder(self)
        let point = convert(event.locationInWindow, from: nil)
        guard plotRect.contains(point) else { return }
        dragOriginX = point.x
        mouseDownPoint = point
        dragStartMinute = visibleStart
        pendingTarget = target(at: point)
        didDrag = false
        NSCursor.closedHand.set()
        needsDisplay = true
    }

    override func mouseDragged(with event: NSEvent) {
        guard let dragOriginX, let mouseDownPoint else { return }
        let point = convert(event.locationInWindow, from: nil)
        if hypot(point.x - mouseDownPoint.x, point.y - mouseDownPoint.y) >= 4 {
            didDrag = true
            pendingTarget = nil
        }
        guard didDrag else { return }
        NSCursor.closedHand.set()
        let usableWidth = max(1, plotRect.width)
        let rtl: CGFloat = Localizer.shared.isRTL ? -1 : 1
        let minutes = -(point.x - dragOriginX) / usableWidth * visibleDuration * rtl
        setViewport(start: dragStartMinute + minutes, duration: visibleDuration)
    }

    override func mouseUp(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        if !didDrag, let target = pendingTarget {
            selectedEventID = target.event.id
            selectionPulseStartedAt = ProcessInfo.processInfo.systemUptime
            updateAccessibilityValue()
            onStateChange?(visibleStart, visibleDuration, selectedEventID)
            onSelectEvent?(target.event, self)
        }
        dragOriginX = nil
        mouseDownPoint = nil
        pendingTarget = nil
        didDrag = false
        hoverMinute = minute(at: point)
        if target(at: point) != nil {
            NSCursor.pointingHand.set()
        } else if minute(at: point) != nil {
            NSCursor.crosshair.set()
        } else {
            NSCursor.arrow.set()
        }
        needsDisplay = true
    }

    private func moveSelection(_ delta: Int) {
        let ordered = displayedEvents.sorted {
            $0.startMinute == $1.startMinute ? $0.id < $1.id
                                             : $0.startMinute < $1.startMinute
        }
        guard !ordered.isEmpty else { return }
        let current = ordered.firstIndex { $0.id == selectedEventID }
        let index = ((current ?? (delta > 0 ? -1 : 0)) + delta + ordered.count)
                  % ordered.count
        selectedEventID = ordered[index].id
        selectionPulseStartedAt = ProcessInfo.processInfo.systemUptime
        let minute = CGFloat(ordered[index].startMinute % 1440)
        if minute < visibleStart || minute > visibleStart + visibleDuration {
            setViewport(start: minute - visibleDuration / 2,
                        duration: visibleDuration)
        }
        updateAccessibilityValue()
        onStateChange?(visibleStart, visibleDuration, selectedEventID)
        needsDisplay = true
    }

    private func inspectSelected() -> Bool {
        guard let selected = displayedEvents.first(where: { $0.id == selectedEventID })
        else { return false }
        onSelectEvent?(selected, self)
        return true
    }

    override func keyDown(with event: NSEvent) {
        let rtl = Localizer.shared.isRTL
        switch event.keyCode {
        case 123:
            pan(minutes: visibleDuration * (rtl ? 0.12 : -0.12))
        case 124:
            pan(minutes: visibleDuration * (rtl ? -0.12 : 0.12))
        case 125: moveSelection(1)
        case 126: moveSelection(-1)
        case 36, 49:
            if !inspectSelected() { super.keyDown(with: event) }
        default:
            switch event.charactersIgnoringModifiers {
            case "+", "=": zoom(by: 0.72)
            case "-", "_": zoom(by: 1.38)
            case "0": setViewport(start: 0, duration: 1440)
            case "n", "N": showNow(nil)
            default: super.keyDown(with: event)
            }
        }
    }

    override func accessibilityPerformPress() -> Bool { inspectSelected() }

    private func minute(_ hhmm: String) -> Int? {
        let parts = hhmm.split(separator: ":")
        guard parts.count == 2, let hour = Int(parts[0]), let minute = Int(parts[1])
        else { return nil }
        return max(0, min(1439, hour * 60 + minute))
    }

    private func timeLabel(_ value: Int) -> String {
        let normalized = (value % 1440 + 1440) % 1440
        return displayTime(String(format: "%02d:%02d",
                                  normalized / 60, normalized % 60))
    }

    private func currentMinute(at date: Date = Date()) -> CGFloat {
        let calendar = Calendar.current
        let parts = calendar.dateComponents([.hour, .minute, .second, .nanosecond],
                                            from: date)
        return CGFloat(parts.hour ?? 0) * 60
            + CGFloat(parts.minute ?? 0)
            + CGFloat(parts.second ?? 0) / 60
            + CGFloat(parts.nanosecond ?? 0) / 60_000_000_000
    }

    private func eventTimeText(_ event: PrayerScheduleEvent) -> String {
        let start = timeLabel(event.startMinute)
        guard let end = event.endMinute else { return start }
        return "\(start) – \(timeLabel(end))"
    }

    private func drawText(_ value: String, in rect: NSRect, size: CGFloat,
                          weight: NSFont.Weight = .regular,
                          color: NSColor = .labelColor,
                          alignment: NSTextAlignment = .left,
                          maximumLines: Int = 1) {
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = alignment
        paragraph.lineBreakMode = .byTruncatingTail
        paragraph.baseWritingDirection = Localizer.shared.isRTL ? .rightToLeft : .leftToRight
        let font = Localizer.shared.font(size: size, weight: weight)
        let drawingRect = localizedTextFrame(rect, text: value, font: font,
                                             maximumLines: maximumLines)
        NSAttributedString(string: value, attributes: [
            .font: font, .foregroundColor: color, .paragraphStyle: paragraph,
        ]).draw(with: drawingRect,
                options: [.usesLineFragmentOrigin, .usesFontLeading])
    }

    private func segments(for event: PrayerScheduleEvent) -> [(CGFloat, CGFloat?)] {
        let start = CGFloat(event.startMinute)
        guard let rawEnd = event.endMinute else {
            return [(CGFloat((event.startMinute % 1440 + 1440) % 1440), nil)]
        }
        let end = CGFloat(rawEnd)
        if end <= 1440 { return [(max(0, start), min(1440, end))] }
        return [(max(0, start), 1440), (0, min(1440, end - 1440))]
    }

    private func color(for kind: PrayerScheduleKind) -> NSColor {
        switch kind {
        case .obligatory: return .appAccent
        case .rawatib: return NSColor(red: 0.84, green: 0.59, blue: 0.18, alpha: 1)
        case .duha: return .systemTeal
        case .qiyam: return .systemIndigo
        case .witr: return .systemPurple
        }
    }

    private func laneIndex(for kind: PrayerScheduleKind) -> Int {
        switch kind {
        case .obligatory: return 0
        case .rawatib: return 1
        case .duha, .qiyam, .witr: return 2
        }
    }

    private func minimumHitRect(for rect: NSRect) -> NSRect {
        let width = max(44, rect.width)
        let height = max(44, rect.height)
        return NSRect(x: rect.midX - width / 2, y: rect.midY - height / 2,
                      width: width, height: height)
    }

    private func activateEvent(_ id: String) {
        guard let event = displayedEvents.first(where: { $0.id == id }) else { return }
        selectedEventID = id
        selectionPulseStartedAt = ProcessInfo.processInfo.systemUptime
        updateAccessibilityValue()
        onStateChange?(visibleStart, visibleDuration, selectedEventID)
        onSelectEvent?(event, self)
        needsDisplay = true
    }

    private func updateAccessibilityEventChildren() {
        var unioned: [(event: PrayerScheduleEvent, rect: NSRect)] = []
        for event in displayedEvents {
            let rects = eventTargets.filter { $0.event.id == event.id }.map(\.hitRect)
            guard var frame = rects.first else { continue }
            for rect in rects.dropFirst() { frame = frame.union(rect) }
            unioned.append((event, frame))
        }
        let geometry = unioned.map { item in
            "\(item.event.id):\(Int(item.rect.minX)):\(Int(item.rect.minY)):"
                + "\(Int(item.rect.width)):\(Int(item.rect.height))"
        }.joined(separator: "|")
        let signature = "\(Int(bounds.width))x\(Int(bounds.height))@"
            + "\(Int(visibleStart))/\(Int(visibleDuration))|\(geometry)"
        guard signature != accessibilityGeometrySignature else { return }
        accessibilityGeometrySignature = signature
        accessibilityEventElements = unioned.map { item in
            let event = item.event
            return PrayerEventAccessibilityElement(
                parent: self, frame: item.rect,
                label: "\(event.knowledge.title). \(eventTimeText(event)). "
                    + event.knowledge.whenText,
                help: prayerInfoText("info.open"),
                pressHandler: { [weak self] in self?.activateEvent(event.id) })
        }
        let children: [Any] = [controlRail as Any]
            + accessibilityEventElements.map { $0 as Any }
        setAccessibilityChildren(children)
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        let dark = effectiveAppearance.bestMatch(from: [.darkAqua, .vibrantDark]) != nil
        let reducedMotion = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        let animationTime = ProcessInfo.processInfo.systemUptime
        if let started = selectionPulseStartedAt,
           animationTime - started > 0.42 {
            selectionPulseStartedAt = nil
        }
        let card = NSBezierPath(roundedRect: bounds.insetBy(dx: 1, dy: 1),
                                xRadius: 18, yRadius: 18)
        (dark ? NSColor(white: 0.08, alpha: 0.96)
              : NSColor(white: 0.985, alpha: 0.96)).setFill()
        card.fill()
        (dark ? NSColor.white.withAlphaComponent(0.14)
              : NSColor.black.withAlphaComponent(0.10)).setStroke()
        card.lineWidth = 1
        card.stroke()

        let rtl = Localizer.shared.isRTL
        let leading: NSTextAlignment = rtl ? .right : .left
        let titleWidth = max(180, bounds.width - 330)
        drawText(featureText("full.timeline.title"),
                 in: NSRect(x: rtl ? bounds.width - titleWidth - 20 : 20,
                            y: 14, width: titleWidth, height: 28),
                 size: 20, weight: .semibold, alignment: leading)
        drawText(prayerInfoText("timeline.gesture_hint"),
                 in: NSRect(x: rtl ? bounds.width - titleWidth - 20 : 20,
                            y: 42, width: titleWidth, height: 18),
                 size: 10.5, color: .secondaryLabelColor, alignment: leading)

        let labelWidth: CGFloat = 104
        let plot = NSRect(x: rtl ? 26 : labelWidth + 22,
                          y: 86,
                          width: bounds.width - labelWidth - 48,
                          height: bounds.height - 166)
        plotRect = plot
        guard plot.width > 80, plot.height > 150 else {
            plotRect = .zero
            return
        }

        func xFor(_ minute: CGFloat) -> CGFloat {
            let fraction = (minute - visibleStart) / visibleDuration
            return rtl ? plot.maxX - plot.width * fraction
                       : plot.minX + plot.width * fraction
        }

        let nowMinute = currentMinute()

        // A six-part sky follows the mosque's own day landmarks. It gives
        // panning a spatial rhythm without adding or guessing prayer windows.
        let fajr = info.times.indices.contains(0)
            ? minute(info.times[0]) ?? 5 * 60 : 5 * 60
        let sunrise = max(fajr, minute(info.shuruq) ?? 6 * 60)
        let dhuhr = max(sunrise, info.times.indices.contains(1)
            ? minute(info.times[1]) ?? 12 * 60 : 12 * 60)
        let maghrib = max(dhuhr, info.times.indices.contains(3)
            ? minute(info.times[3]) ?? 18 * 60 : 18 * 60)
        let isha = max(maghrib, info.times.indices.contains(4)
            ? minute(info.times[4]) ?? 21 * 60 : 21 * 60)
        let phases: [(Int, Int, NSColor)] = [
            (0, fajr, NSColor(red: 0.19, green: 0.22, blue: 0.48, alpha: 1)),
            (fajr, sunrise, NSColor(red: 0.91, green: 0.50, blue: 0.25, alpha: 1)),
            (sunrise, dhuhr, NSColor(red: 0.91, green: 0.68, blue: 0.25, alpha: 1)),
            (dhuhr, maghrib, NSColor(red: 0.18, green: 0.63, blue: 0.61, alpha: 1)),
            (maghrib, isha, NSColor(red: 0.75, green: 0.34, blue: 0.31, alpha: 1)),
            (isha, 1440, NSColor(red: 0.27, green: 0.22, blue: 0.49, alpha: 1)),
        ]
        for (start, end, color) in phases {
            let a = max(CGFloat(start), visibleStart)
            let b = min(CGFloat(end), visibleStart + visibleDuration)
            guard b > a else { continue }
            let x1 = xFor(a), x2 = xFor(b)
            let rect = NSRect(x: min(x1, x2), y: plot.minY,
                              width: abs(x2 - x1), height: plot.height)
            let isCurrent = nowMinute >= CGFloat(start) && nowMinute < CGFloat(end)
            let alpha: CGFloat = dark
                ? (isCurrent ? 0.145 : 0.090)
                : (isCurrent ? 0.125 : 0.075)
            let first = color.withAlphaComponent(alpha * 0.70)
            let second = color.withAlphaComponent(alpha)
            if let gradient = NSGradient(starting: first, ending: second) {
                gradient.draw(in: rect, angle: rtl ? 180 : 0)
            } else {
                second.setFill()
                rect.fill()
            }
        }

        // Quiet zellige diamonds connect the visualization to the Moroccan
        // identity while retaining native macOS contrast and hierarchy.
        NSGraphicsContext.saveGraphicsState()
        NSBezierPath(rect: plot).addClip()
        (dark ? NSColor.white.withAlphaComponent(0.032)
              : NSColor.appGreenAccent.withAlphaComponent(0.045)).setStroke()
        for y in stride(from: plot.minY + 18, through: plot.maxY, by: 38) {
            for x in stride(from: plot.minX + 18, through: plot.maxX, by: 48) {
                let diamond = NSBezierPath()
                diamond.move(to: NSPoint(x: x, y: y - 5))
                diamond.line(to: NSPoint(x: x + 5, y: y))
                diamond.line(to: NSPoint(x: x, y: y + 5))
                diamond.line(to: NSPoint(x: x - 5, y: y))
                diamond.close()
                diamond.lineWidth = 0.7
                diamond.stroke()
            }
        }
        NSGraphicsContext.restoreGraphicsState()

        let laneGap: CGFloat = 8
        let laneHeight = (plot.height - laneGap * 2) / 3
        let laneTitles = [prayerInfoText("category.obligatory"),
                          featureText("nawafil.rawatib"),
                          featureText("full.nawafil")]
        for index in 0..<3 {
            let y = plot.minY + CGFloat(index) * (laneHeight + laneGap)
            let lane = NSRect(x: plot.minX, y: y, width: plot.width,
                              height: laneHeight)
            (dark ? NSColor.white.withAlphaComponent(0.045)
                  : NSColor.white.withAlphaComponent(0.38)).setFill()
            NSBezierPath(roundedRect: lane, xRadius: 10, yRadius: 10).fill()
            let labelRect = NSRect(x: rtl ? plot.maxX + 8 : 14, y: y,
                                   width: labelWidth - 18, height: laneHeight)
            drawText(laneTitles[index], in: labelRect, size: 11,
                     weight: .semibold, color: .secondaryLabelColor,
                     alignment: leading)
        }

        let tickStep: Int = visibleDuration <= 360 ? 60
            : (visibleDuration <= 720 ? 120 : 240)
        let firstTick = Int(ceil(visibleStart / CGFloat(tickStep))) * tickStep
        for value in stride(from: firstTick,
                            through: Int(visibleStart + visibleDuration),
                            by: tickStep) {
            let x = xFor(CGFloat(value))
            let path = NSBezierPath()
            path.move(to: NSPoint(x: x, y: plot.minY - 5))
            path.line(to: NSPoint(x: x, y: plot.maxY))
            NSColor.secondaryLabelColor.withAlphaComponent(0.20).setStroke()
            path.lineWidth = 0.7
            path.stroke()
            let labelWidth: CGFloat = is12HourFormat() ? 82 : 58
            drawText(timeLabel(value),
                     in: NSRect(x: x - labelWidth / 2, y: plot.minY - 25,
                                width: labelWidth, height: 18),
                     size: 10, color: .secondaryLabelColor, alignment: .center)
        }

        func easedHoverProgress(for eventID: String) -> CGFloat {
            guard eventID == hoveredEventID else { return 0 }
            guard !reducedMotion else { return 1 }
            let raw = max(0, min(1,
                CGFloat((animationTime - hoverFocusStartedAt) / 0.16)))
            return raw * raw * (3 - 2 * raw)
        }

        func selectionPulseProgress(for eventID: String) -> CGFloat? {
            guard eventID == selectedEventID,
                  !reducedMotion,
                  let started = selectionPulseStartedAt else { return nil }
            return max(0, min(1, CGFloat((animationTime - started) / 0.42)))
        }

        func drawRoundedFocus(_ rect: NSRect, radius: CGFloat,
                              color: NSColor, selected: Bool,
                              hoverProgress: CGFloat,
                              pulseProgress: CGFloat?) {
            guard selected || hoverProgress > 0 else { return }
            let focusRect = rect.insetBy(dx: -2, dy: -2)
            if selected {
                let underlay = NSBezierPath(roundedRect: focusRect,
                                             xRadius: radius + 2,
                                             yRadius: radius + 2)
                (dark ? NSColor.white.withAlphaComponent(0.28)
                      : NSColor.black.withAlphaComponent(0.22)).setStroke()
                underlay.lineWidth = 4.5
                underlay.stroke()
            }
            let outline = NSBezierPath(roundedRect: focusRect,
                                       xRadius: radius + 2,
                                       yRadius: radius + 2)
            color.withAlphaComponent(selected ? 0.96 : 0.35 + 0.48 * hoverProgress)
                .setStroke()
            outline.lineWidth = selected ? 2.6 : 1.2 + hoverProgress
            outline.stroke()
            if let pulseProgress {
                let expansion = 4 + 8 * pulseProgress
                let pulse = NSBezierPath(roundedRect: rect.insetBy(dx: -expansion,
                                                                   dy: -expansion),
                                         xRadius: radius + expansion,
                                         yRadius: radius + expansion)
                color.withAlphaComponent(0.34 * (1 - pulseProgress)).setStroke()
                pulse.lineWidth = 2.2
                pulse.stroke()
            }
        }

        func drawMarkerFocus(_ rect: NSRect, color: NSColor,
                             selected: Bool, hoverProgress: CGFloat,
                             pulseProgress: CGFloat?) {
            guard selected || hoverProgress > 0 else { return }
            let focusRect = rect.insetBy(dx: -5, dy: -5)
            if selected {
                let underlay = NSBezierPath(ovalIn: focusRect)
                (dark ? NSColor.white.withAlphaComponent(0.28)
                      : NSColor.black.withAlphaComponent(0.22)).setStroke()
                underlay.lineWidth = 5
                underlay.stroke()
            }
            let outline = NSBezierPath(ovalIn: focusRect)
            color.withAlphaComponent(selected ? 0.96 : 0.35 + 0.48 * hoverProgress)
                .setStroke()
            outline.lineWidth = selected ? 3 : 1.5 + hoverProgress
            outline.stroke()
            if let pulseProgress {
                let expansion = 8 + 8 * pulseProgress
                let pulse = NSBezierPath(ovalIn: rect.insetBy(dx: -expansion,
                                                              dy: -expansion))
                color.withAlphaComponent(0.34 * (1 - pulseProgress)).setStroke()
                pulse.lineWidth = 2.2
                pulse.stroke()
            }
        }

        eventTargets.removeAll(keepingCapacity: true)
        for event in displayedEvents {
            let lane = laneIndex(for: event.kind)
            let laneY = plot.minY + CGFloat(lane) * (laneHeight + laneGap)
            let color = color(for: event.kind)
            let selected = event.id == selectedEventID
            let hovered = event.id == hoveredEventID
            let hoverProgress = easedHoverProgress(for: event.id)
            let pulseProgress = selectionPulseProgress(for: event.id)
            for segment in segments(for: event) {
                let start = max(segment.0, visibleStart)
                let segmentEnd = segment.1.map {
                    min($0, visibleStart + visibleDuration)
                }
                if let segmentEnd, segmentEnd <= start { continue }
                if segment.1 == nil,
                   (segment.0 < visibleStart
                    || segment.0 > visibleStart + visibleDuration) { continue }
                let baseY: CGFloat
                let height: CGFloat
                switch event.kind {
                case .obligatory: baseY = laneY + laneHeight * 0.30; height = 24
                case .rawatib:
                    // Before/after markers may share the same published entry
                    // when a mosque has no iqama. Separate tracks keep both
                    // events visible and independently actionable.
                    baseY = event.id.hasSuffix(".before")
                        ? laneY + laneHeight * 0.20
                        : laneY + laneHeight * 0.62
                    height = 16
                case .duha: baseY = laneY + 8; height = 20
                case .qiyam: baseY = laneY + laneHeight * 0.38; height = 20
                case .witr: baseY = laneY + laneHeight - 23; height = 12
                }
                let x1 = xFor(start)
                if let segmentEnd {
                    let x2 = xFor(segmentEnd)
                    let rect = NSRect(x: min(x1, x2), y: baseY,
                                      width: max(5, abs(x2 - x1)), height: height)
                    let opacity: CGFloat = selected ? 0.92
                        : (hovered ? 0.60 + 0.22 * hoverProgress : 0.60)
                    color.withAlphaComponent(opacity).setFill()
                    NSBezierPath(roundedRect: rect, xRadius: height / 2,
                                 yRadius: height / 2).fill()
                    if event.precision == .instructionalMarker {
                        let outline = NSBezierPath(roundedRect: rect, xRadius: height / 2,
                                                   yRadius: height / 2)
                        color.setStroke()
                        outline.setLineDash([4, 3], count: 2, phase: 0)
                        outline.lineWidth = selected ? 2.5 : 1.2
                        outline.stroke()
                    }
                    drawRoundedFocus(rect, radius: height / 2,
                                     color: color, selected: selected,
                                     hoverProgress: hoverProgress,
                                     pulseProgress: pulseProgress)
                    if rect.width > 76 {
                        drawText(event.knowledge.title,
                                 in: rect.insetBy(dx: 8, dy: 1), size: 10,
                                 weight: .semibold,
                                 color: dark ? .white : .labelColor,
                                 alignment: .center)
                    }
                    eventTargets.append(EventTarget(
                        visualRect: rect,
                        hitRect: minimumHitRect(for: rect).intersection(plot),
                        event: event))
                } else {
                    let markerRect = NSRect(x: x1 - 7, y: baseY - 2,
                                            width: 14, height: 14)
                    color.setFill()
                    let shape = NSBezierPath()
                    if event.kind == .rawatib && event.id.hasSuffix(".before") {
                        shape.move(to: NSPoint(x: markerRect.midX, y: markerRect.minY))
                        shape.line(to: NSPoint(x: markerRect.maxX, y: markerRect.maxY))
                        shape.line(to: NSPoint(x: markerRect.minX, y: markerRect.maxY))
                        shape.close()
                    } else if event.kind == .rawatib {
                        shape.move(to: NSPoint(x: markerRect.minX, y: markerRect.minY))
                        shape.line(to: NSPoint(x: markerRect.maxX, y: markerRect.minY))
                        shape.line(to: NSPoint(x: markerRect.midX, y: markerRect.maxY))
                        shape.close()
                    } else if event.kind == .witr {
                        shape.move(to: NSPoint(x: markerRect.midX, y: markerRect.minY))
                        shape.line(to: NSPoint(x: markerRect.maxX, y: markerRect.midY))
                        shape.line(to: NSPoint(x: markerRect.midX, y: markerRect.maxY))
                        shape.line(to: NSPoint(x: markerRect.minX, y: markerRect.midY))
                        shape.close()
                    } else {
                        shape.appendOval(in: markerRect)
                    }
                    shape.fill()
                    drawMarkerFocus(markerRect, color: color,
                                    selected: selected,
                                    hoverProgress: hoverProgress,
                                    pulseProgress: pulseProgress)
                    let hit = NSRect(x: x1 - 22, y: baseY - 17,
                                     width: 44, height: 44).intersection(plot)
                    eventTargets.append(EventTarget(visualRect: markerRect,
                                                    hitRect: hit,
                                                    event: event))
                }
            }
        }
        updateAccessibilityEventChildren()

        func drawPill(_ text: String, centerX: CGFloat, y: CGFloat,
                      background: NSColor, foreground: NSColor) {
            let font = Localizer.shared.font(size: 10.5, weight: .semibold)
            let measured = (text as NSString).size(withAttributes: [.font: font])
            let width = min(plot.width - 12, max(72, ceil(measured.width) + 22))
            let rect = NSRect(x: max(plot.minX + 6,
                                     min(plot.maxX - width - 6,
                                         centerX - width / 2)),
                              y: y, width: width, height: 24)
            background.setFill()
            NSBezierPath(roundedRect: rect, xRadius: 12, yRadius: 12).fill()
            drawText(text, in: rect.insetBy(dx: 10, dy: 4), size: 10.5,
                     weight: .semibold, color: foreground, alignment: .center)
        }

        // The day-progress rail and fractional-minute cursor make the chart a
        // live instrument. Reduce Motion keeps the same information but uses
        // a static orb and the slower lifecycle timer configured above.
        let railY = plot.minY + 2
        let rail = NSBezierPath()
        rail.move(to: NSPoint(x: plot.minX, y: railY))
        rail.line(to: NSPoint(x: plot.maxX, y: railY))
        NSColor.secondaryLabelColor.withAlphaComponent(dark ? 0.24 : 0.18).setStroke()
        rail.lineWidth = 3
        rail.lineCapStyle = .round
        rail.stroke()

        if nowMinute > visibleStart {
            let progressMinute = min(nowMinute, visibleStart + visibleDuration)
            let x1 = xFor(visibleStart)
            let x2 = xFor(progressMinute)
            let progress = NSBezierPath()
            progress.move(to: NSPoint(x: x1, y: railY))
            progress.line(to: NSPoint(x: x2, y: railY))
            NSColor.appAccent.withAlphaComponent(0.74).setStroke()
            progress.lineWidth = 3.4
            progress.lineCapStyle = .round
            progress.stroke()
        }

        if nowMinute >= visibleStart,
           nowMinute <= visibleStart + visibleDuration {
            let x = xFor(nowMinute)
            let gold = NSColor(red: 0.92, green: 0.64, blue: 0.20, alpha: 1)
            let cursor = NSBezierPath()
            cursor.move(to: NSPoint(x: x, y: railY))
            cursor.line(to: NSPoint(x: x, y: plot.maxY))
            gold.withAlphaComponent(0.70).setStroke()
            cursor.lineWidth = 1.8
            cursor.stroke()

            let pulse = reducedMotion ? 0 : CGFloat(
                (sin(animationTime * 2 * Double.pi / 1.8) + 1) / 2)
            let haloRadius = 9 + 4 * pulse
            gold.withAlphaComponent(reducedMotion ? 0.20 : 0.10 + 0.12 * (1 - pulse))
                .setFill()
            NSBezierPath(ovalIn: NSRect(x: x - haloRadius,
                                        y: railY - haloRadius,
                                        width: haloRadius * 2,
                                        height: haloRadius * 2)).fill()
            gold.setFill()
            NSBezierPath(ovalIn: NSRect(x: x - 5.5, y: railY - 5.5,
                                        width: 11, height: 11)).fill()
            let label = "\(nowText) · \(timeLabel(Int(floor(nowMinute))))"
            drawPill(label, centerX: x, y: plot.minY + 9,
                     background: gold.withAlphaComponent(dark ? 0.92 : 0.96),
                     foreground: NSColor.black.withAlphaComponent(0.82))
        }

        if let hoverMinute, dragOriginX == nil {
            let x = xFor(hoverMinute)
            let guide = NSBezierPath()
            guide.move(to: NSPoint(x: x, y: plot.minY + 4))
            guide.line(to: NSPoint(x: x, y: plot.maxY))
            guide.setLineDash([3, 4], count: 2, phase: 0)
            NSColor.labelColor.withAlphaComponent(dark ? 0.38 : 0.28).setStroke()
            guide.lineWidth = 1
            guide.stroke()
            drawPill(timeLabel(Int(floor(hoverMinute))), centerX: x,
                     y: plot.maxY - 29,
                     background: dark
                        ? NSColor(white: 0.15, alpha: 0.96)
                        : NSColor(white: 1, alpha: 0.96),
                     foreground: .labelColor)
        }

        if let id = hoveredEventID ?? selectedEventID,
           let event = displayedEvents.first(where: { $0.id == id }) {
            let ribbon = NSRect(x: 20, y: bounds.height - 66,
                                width: bounds.width - 40, height: 50)
            (dark ? NSColor.white.withAlphaComponent(0.09)
                  : NSColor.black.withAlphaComponent(0.045)).setFill()
            NSBezierPath(roundedRect: ribbon, xRadius: 10, yRadius: 10).fill()
            drawText("\(event.knowledge.title) · \(eventTimeText(event))",
                     in: NSRect(x: ribbon.minX + 12, y: ribbon.minY + 5,
                                width: ribbon.width - 24, height: 18),
                     size: 12, weight: .semibold, alignment: leading)
            drawText(event.knowledge.whenText,
                     in: NSRect(x: ribbon.minX + 12, y: ribbon.minY + 25,
                                width: ribbon.width - 24, height: 17),
                     size: 10.5, color: .secondaryLabelColor,
                     alignment: leading)
        }
    }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        needsDisplay = true
    }
}

/// A live analog clock with two prayer rings: AM events sit on the outer
/// ring and PM events on the inner ring. This preserves conventional
/// clockwise clock behavior in Arabic while the labels and surrounding UI
/// still follow RTL.
final class PrayerAnalogClockView: NSControl {
    private let info: MosqueInfo
    private let prayerNames: [String]
    private let showsNawafil: Bool
    private let events: [PrayerScheduleEvent]
    var onSelectEvent: ((PrayerScheduleEvent, NSView) -> Void)?
    private var timer: Timer?
    private var trackingAreaRef: NSTrackingArea?
    private var markerPoints: [(point: NSPoint, title: String, raw: String,
                                event: PrayerScheduleEvent?)] = []
    private var hoveredMarker: Int?

    override var isFlipped: Bool { true }

    init(frame: NSRect, info: MosqueInfo, prayerNames: [String],
         showsNawafil: Bool, events: [PrayerScheduleEvent] = [],
         onSelectEvent: ((PrayerScheduleEvent, NSView) -> Void)? = nil) {
        self.info = info
        self.prayerNames = prayerNames
        self.showsNawafil = showsNawafil
        self.events = events
        self.onSelectEvent = onSelectEvent
        super.init(frame: frame)
        setAccessibilityElement(true)
        setAccessibilityRole(.group)
        setAccessibilityLabel(featureText("full.clock.accessibility"))
        let summary = zip(prayerNames, info.times).map {
            "\($0.0) \(displayTime($0.1))"
        }.joined(separator: ", ")
        setAccessibilityValue(summary)
    }

    required init?(coder: NSCoder) { fatalError() }
    deinit { timer?.invalidate() }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        timer?.invalidate()
        guard window != nil else { return }
        window?.acceptsMouseMovedEvents = true
        let next = Timer(timeInterval: 1, repeats: true) { [weak self] _ in
            self?.needsDisplay = true
        }
        RunLoop.main.add(next, forMode: .common)
        timer = next
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let trackingAreaRef { removeTrackingArea(trackingAreaRef) }
        let area = NSTrackingArea(rect: bounds,
                                  options: [.mouseMoved, .mouseEnteredAndExited,
                                            .activeInActiveApp, .inVisibleRect],
                                  owner: self, userInfo: nil)
        addTrackingArea(area)
        trackingAreaRef = area
    }

    override func mouseMoved(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        hoveredMarker = markerPoints.enumerated().min(by: {
            hypot($0.element.point.x - point.x, $0.element.point.y - point.y)
              < hypot($1.element.point.x - point.x, $1.element.point.y - point.y)
        }).flatMap {
            hypot($0.element.point.x - point.x, $0.element.point.y - point.y) < 34
                ? $0.offset : nil
        }
        needsDisplay = true
    }

    override func mouseExited(with event: NSEvent) {
        hoveredMarker = nil
        needsDisplay = true
    }

    override func mouseDown(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        guard let index = markerPoints.enumerated().min(by: {
            hypot($0.element.point.x - point.x, $0.element.point.y - point.y)
              < hypot($1.element.point.x - point.x, $1.element.point.y - point.y)
        }).flatMap({
            hypot($0.element.point.x - point.x, $0.element.point.y - point.y) < 34
                ? $0.offset : nil
        }), markerPoints.indices.contains(index),
              let scheduleEvent = markerPoints[index].event else { return }
        onSelectEvent?(scheduleEvent, self)
    }

    private func minute(_ value: String) -> Int? {
        let parts = value.split(separator: ":")
        guard parts.count == 2, let h = Int(parts[0]), let m = Int(parts[1]) else {
            return nil
        }
        return h * 60 + m
    }

    private func point(center: NSPoint, radius: CGFloat, minute: Int) -> NSPoint {
        let twelveHourMinute = minute % 720
        let angle = CGFloat(twelveHourMinute) / 720 * 2 * .pi - .pi / 2
        return NSPoint(x: center.x + cos(angle) * radius,
                       y: center.y + sin(angle) * radius)
    }

    private func drawText(_ string: String, rect: NSRect, size: CGFloat,
                          weight: NSFont.Weight = .regular,
                          color: NSColor = .labelColor,
                          alignment: NSTextAlignment = .center) {
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = alignment
        paragraph.baseWritingDirection = Localizer.shared.isRTL ? .rightToLeft : .leftToRight
        let font = Localizer.shared.font(size: size, weight: weight)
        let drawingRect = localizedTextFrame(rect, text: string, font: font)
        NSAttributedString(string: string, attributes: [
            .font: font,
            .foregroundColor: color,
            .paragraphStyle: paragraph,
        ]).draw(with: drawingRect,
                options: [.usesLineFragmentOrigin, .usesFontLeading])
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        let dark = effectiveAppearance.bestMatch(from: [.darkAqua, .vibrantDark]) != nil
        let card = NSBezierPath(roundedRect: bounds.insetBy(dx: 1, dy: 1),
                                xRadius: 18, yRadius: 18)
        (dark ? NSColor(white: 1, alpha: 0.065)
              : NSColor(white: 1, alpha: 0.88)).setFill()
        card.fill()
        (dark ? NSColor.white.withAlphaComponent(0.13)
              : NSColor.black.withAlphaComponent(0.10)).setStroke()
        card.lineWidth = 0.8
        card.stroke()

        let center = NSPoint(x: bounds.midX, y: bounds.midY + 8)
        let outer = min(bounds.width * 0.31, bounds.height * 0.41)
        let inner = outer * 0.76

        for radius in [outer, inner] {
            let ring = NSBezierPath(ovalIn: NSRect(x: center.x - radius,
                                                   y: center.y - radius,
                                                   width: radius * 2,
                                                   height: radius * 2))
            NSColor.secondaryLabelColor.withAlphaComponent(0.26).setStroke()
            ring.lineWidth = radius == outer ? 1.6 : 0.7
            ring.stroke()
        }

        // Hour ticks and numerals follow a physical clock in every language.
        for hour in 1...12 {
            let minute = hour * 60
            let tickOuter = point(center: center, radius: outer, minute: minute)
            let tickInner = point(center: center, radius: outer - 8, minute: minute)
            let tick = NSBezierPath()
            tick.move(to: tickOuter)
            tick.line(to: tickInner)
            NSColor.secondaryLabelColor.setStroke()
            tick.lineWidth = hour.isMultiple(of: 3) ? 1.8 : 0.8
            tick.stroke()
            let numeral = point(center: center, radius: outer - 20, minute: minute)
            drawText(localizedInterfaceDigits(String(hour)),
                     rect: NSRect(x: numeral.x - 12, y: numeral.y - 9,
                                               width: 24, height: 18),
                     size: 10, color: .secondaryLabelColor)
        }

        if showsNawafil {
            func arc(from start: Int, to end: Int, radius: CGFloat, color: NSColor) {
                guard end > start else { return }
                let path = NSBezierPath()
                path.appendArc(withCenter: center, radius: radius,
                               startAngle: 90 - CGFloat(end % 720) / 2,
                               endAngle: 90 - CGFloat(start % 720) / 2,
                               clockwise: false)
                color.setStroke()
                path.lineWidth = 6
                path.stroke()
            }
            if let sunrise = minute(info.shuruq),
               info.times.indices.contains(1), let dhuhr = minute(info.times[1]) {
                arc(from: sunrise + 20, to: dhuhr - 10, radius: outer + 8,
                    color: NSColor.appAccent.withAlphaComponent(0.46))
            }
            if info.times.indices.contains(4), let isha = minute(info.times[4]) {
                arc(from: isha, to: 1439, radius: inner - 8,
                    color: NSColor.systemIndigo.withAlphaComponent(0.42))
            }
        }

        markerPoints.removeAll(keepingCapacity: true)
        for index in 0..<min(5, info.times.count, prayerNames.count) {
            guard let value = minute(info.times[index]) else { continue }
            let radius = value < 720 ? outer : inner
            let marker = point(center: center, radius: radius, minute: value)
            markerPoints.append((marker, prayerNames[index], info.times[index],
                                 events.first {
                                     $0.kind == .obligatory
                                         && $0.prayerIndex == index
                                 }))
            NSColor.appAccent.setFill()
            NSBezierPath(ovalIn: NSRect(x: marker.x - 5, y: marker.y - 5,
                                        width: 10, height: 10)).fill()
            let labelPoint = point(center: center,
                                   radius: radius == outer ? outer + 27 : inner - 27,
                                   minute: value)
            drawText(prayerNames[index], rect: NSRect(x: labelPoint.x - 48,
                                                       y: labelPoint.y - 11,
                                                       width: 96, height: 22),
                     size: 11.5, weight: .semibold)
        }

        let now = Date()
        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: now)
        let minuteValue = calendar.component(.minute, from: now)
        let second = calendar.component(.second, from: now)
        func hand(length: CGFloat, minute: Double, width: CGFloat, color: NSColor) {
            let angle = CGFloat(minute / 720 * 2 * Double.pi) - .pi / 2
            let path = NSBezierPath()
            path.move(to: center)
            path.line(to: NSPoint(x: center.x + cos(angle) * length,
                                  y: center.y + sin(angle) * length))
            color.setStroke()
            path.lineCapStyle = .round
            path.lineWidth = width
            path.stroke()
        }
        hand(length: inner * 0.55,
             minute: Double((hour % 12) * 60 + minuteValue) + Double(second) / 60,
             width: 4.5, color: .labelColor)
        hand(length: inner * 0.78,
             minute: Double(minuteValue * 12) + Double(second) / 5,
             width: 2.6, color: .labelColor)
        hand(length: inner * 0.84, minute: Double(second * 12),
             width: 1.2, color: .systemRed)
        NSColor.appAccent.setFill()
        NSBezierPath(ovalIn: NSRect(x: center.x - 5, y: center.y - 5,
                                    width: 10, height: 10)).fill()

        let liveFormatter = DateFormatter()
        liveFormatter.locale = preferredInterfaceLocale()
        liveFormatter.dateStyle = .none
        liveFormatter.timeStyle = .medium
        let nowString = liveFormatter.string(from: now)
        drawText(nowString, rect: NSRect(x: center.x - 80, y: center.y + 38,
                                         width: 160, height: 24),
                 size: 16, weight: .semibold)
        drawText(featureText("full.clock.am_outer"),
                 rect: NSRect(x: 18, y: bounds.height - 36,
                              width: bounds.width - 36, height: 18),
                 size: 10.5, color: .secondaryLabelColor)

        if let hoveredMarker, markerPoints.indices.contains(hoveredMarker) {
            let marker = markerPoints[hoveredMarker]
            drawText("\(marker.title) · \(displayTime(marker.raw))",
                     rect: NSRect(x: 24, y: 18, width: bounds.width - 48, height: 26),
                     size: 14, weight: .semibold, color: .appGreenAccent)
        }
    }
}

/// A high-legibility dual-ring clock. The outer ring is AM and the inner ring
/// is PM; every Nawafil arc and marker comes from the shared daily schedule.
final class PrayerRingClockView: NSControl {
    private let info: MosqueInfo
    private let prayerNames: [String]
    private let showsNawafil: Bool
    private let events: [PrayerScheduleEvent]
    var onSelectEvent: ((PrayerScheduleEvent, NSView) -> Void)?
    var onStateChange: ((String?) -> Void)?

    private var controlRail: NSStackView!
    private var infoButton: HoverIconButton!
    private var legendButtons: [NSButton] = []
    private var legendEvents: [PrayerScheduleEvent] = []
    private var trackingAreaRef: NSTrackingArea?
    private var timer: Timer?
    private var eventTargets: [(rect: NSRect, event: PrayerScheduleEvent)] = []
    private var selectedEventID: String?
    private var hoveredEventID: String?
    private var accessibilityEventElements: [PrayerEventAccessibilityElement] = []
    private var accessibilityGeometrySignature = ""

    override var isFlipped: Bool { true }
    override var acceptsFirstResponder: Bool { true }

    static func preferredHeight(for width: CGFloat) -> CGFloat {
        max(600, min(680, width * 0.74))
    }

    init(frame: NSRect, info: MosqueInfo, prayerNames: [String],
         showsNawafil: Bool, events: [PrayerScheduleEvent],
         initialSelectedEventID: String? = nil,
         onStateChange: ((String?) -> Void)? = nil,
         onSelectEvent: ((PrayerScheduleEvent, NSView) -> Void)? = nil) {
        self.info = info
        self.prayerNames = prayerNames
        self.showsNawafil = showsNawafil
        self.events = events
        self.selectedEventID = events.contains {
            $0.id == initialSelectedEventID
                && (showsNawafil || $0.kind == .obligatory)
        } ? initialSelectedEventID : nil
        self.onStateChange = onStateChange
        self.onSelectEvent = onSelectEvent
        super.init(frame: frame)

        let previousSymbol = Localizer.shared.isRTL ? "chevron.right" : "chevron.left"
        let nextSymbol = Localizer.shared.isRTL ? "chevron.left" : "chevron.right"
        let previous = HoverIconButton(symbol: previousSymbol,
            toolTip: prayerInfoText("clock.previous"), target: self,
            action: #selector(selectPrevious(_:)), pointSize: 14,
            size: NSSize(width: 44, height: 44))
        previous.setAccessibilityLabel(prayerInfoText("clock.previous"))
        infoButton = HoverIconButton(symbol: "info.circle",
            toolTip: prayerInfoText("info.open"), target: self,
            action: #selector(inspectSelection(_:)), pointSize: 15,
            size: NSSize(width: 44, height: 44))
        infoButton.setAccessibilityLabel(prayerInfoText("info.open"))
        infoButton.isEnabled = false
        let next = HoverIconButton(symbol: nextSymbol,
            toolTip: prayerInfoText("clock.next"), target: self,
            action: #selector(selectNext(_:)), pointSize: 14,
            size: NSSize(width: 44, height: 44))
        next.setAccessibilityLabel(prayerInfoText("clock.next"))
        controlRail = NSStackView(views: [previous, infoButton, next])
        controlRail.orientation = .horizontal
        controlRail.alignment = .centerY
        controlRail.spacing = 2
        controlRail.userInterfaceLayoutDirection = Localizer.shared.isRTL
            ? .rightToLeft : .leftToRight
        addSubview(controlRail)

        legendEvents = showsNawafil ? events.filter { $0.kind != .obligatory } : []
        for (index, event) in legendEvents.enumerated() {
            let button = NSButton(title: legendTitle(for: event), target: self,
                                  action: #selector(legendEventTapped(_:)))
            button.tag = index
            button.isBordered = false
            button.bezelStyle = .recessed
            button.setButtonType(.momentaryChange)
            button.font = Localizer.shared.font(size: 11.5, weight: .semibold)
            button.alignment = Localizer.shared.isRTL ? .right : .left
            button.userInterfaceLayoutDirection = Localizer.shared.isRTL
                ? .rightToLeft : .leftToRight
            button.image = templateSymbol(legendSymbol(for: event), pointSize: 13,
                                          weight: .semibold)
            button.imagePosition = Localizer.shared.isRTL ? .imageRight : .imageLeft
            button.contentTintColor = color(for: event.kind)
            button.toolTip = event.knowledge.whenText
            button.lineBreakMode = .byWordWrapping
            button.cell?.wraps = true
            button.setAccessibilityLabel(
                "\(legendTitle(for: event)). \(event.knowledge.whenText)")
            button.setAccessibilityHelp(prayerInfoText("info.open"))
            button.wantsLayer = true
            button.layer?.cornerRadius = 8
            addSubview(button)
            legendButtons.append(button)
        }
        infoButton.isEnabled = selectedEventID != nil

        setAccessibilityElement(true)
        setAccessibilityRole(.group)
        setAccessibilityLabel(featureText("full.clock.accessibility"))
        setAccessibilityHelp(prayerInfoText("clock.accessibility_help"))
        updateAccessibilityValue()
    }

    required init?(coder: NSCoder) { fatalError() }
    deinit { timer?.invalidate() }

    override func layout() {
        super.layout()
        let width: CGFloat = 44 * 3 + 4
        controlRail.frame = NSRect(
            x: Localizer.shared.isRTL ? 16 : bounds.width - width - 16,
            y: 10, width: width, height: 44)
        guard !legendButtons.isEmpty else { return }
        let legend = legendRect()
        let rowHeight: CGFloat = 44
        let gap: CGFloat = 3
        for (index, button) in legendButtons.enumerated() {
            button.frame = NSRect(x: legend.minX + 8,
                                  y: legend.minY + 34
                                     + CGFloat(index) * (rowHeight + gap),
                                  width: legend.width - 16, height: rowHeight)
        }
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        timer?.invalidate()
        guard window != nil else { return }
        window?.acceptsMouseMovedEvents = true
        let interval: TimeInterval = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
            ? 30 : 1
        let next = Timer(timeInterval: interval, repeats: true) { [weak self] _ in
            self?.needsDisplay = true
        }
        RunLoop.main.add(next, forMode: .common)
        timer = next
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let trackingAreaRef { removeTrackingArea(trackingAreaRef) }
        let area = NSTrackingArea(rect: bounds,
                                  options: [.mouseMoved, .mouseEnteredAndExited,
                                            .activeInActiveApp, .inVisibleRect],
                                  owner: self, userInfo: nil)
        addTrackingArea(area)
        trackingAreaRef = area
    }

    private var displayedEvents: [PrayerScheduleEvent] {
        events.filter { showsNawafil || $0.kind == .obligatory }
    }

    private var orderedEvents: [PrayerScheduleEvent] {
        displayedEvents.sorted {
            $0.startMinute == $1.startMinute ? $0.id < $1.id
                                             : $0.startMinute < $1.startMinute
        }
    }

    private func legendRect() -> NSRect {
        guard !legendButtons.isEmpty else { return .zero }
        let width = min(270, max(230, bounds.width * 0.29))
        let height = 42 + CGFloat(legendButtons.count) * 47
        return NSRect(x: Localizer.shared.isRTL ? 16 : bounds.width - width - 16,
                      y: 72, width: width,
                      height: min(bounds.height - 142, height))
    }

    private func formattedMinute(_ minute: Int) -> String {
        let normalized = (minute % 1440 + 1440) % 1440
        return displayTime(String(format: "%02d:%02d", normalized / 60,
                                  normalized % 60))
    }

    private func eventTimeText(_ event: PrayerScheduleEvent) -> String {
        let start = formattedMinute(event.startMinute)
        if let end = event.endMinute {
            return "\(start) – \(formattedMinute(end))"
        }
        return "◇ \(start)"
    }

    private func legendTitle(for event: PrayerScheduleEvent) -> String {
        var name = event.knowledge.title
        if event.kind == .rawatib {
            let prayer = event.prayerIndex.flatMap {
                prayerNames.indices.contains($0) ? prayerNames[$0] : nil
            } ?? ""
            let relation = event.id.hasSuffix(".before")
                ? prayerInfoText("rawatib.before") : prayerInfoText("rawatib.after")
            name = [name, prayer, relation].filter { !$0.isEmpty }
                .joined(separator: " · ")
        }
        return "\(name)\n\(eventTimeText(event))"
    }

    private func legendSymbol(for event: PrayerScheduleEvent) -> String {
        switch event.kind {
        case .obligatory: return "circle.fill"
        case .rawatib:
            return event.id.hasSuffix(".before") ? "arrow.up.to.line"
                                                  : "arrow.down.to.line"
        case .duha: return "sun.max.fill"
        case .qiyam: return "moon.stars.fill"
        case .witr: return "diamond.fill"
        }
    }

    private func updateAccessibilityValue() {
        if let selected = displayedEvents.first(where: { $0.id == selectedEventID }) {
            setAccessibilityValue("\(selected.knowledge.title). \(selected.knowledge.whenText)")
            infoButton?.setAccessibilityLabel(
                "\(prayerInfoText("info.open")): \(selected.knowledge.title)")
        } else {
            setAccessibilityValue(zip(prayerNames, info.times).map {
                "\($0.0) \(displayTime($0.1))"
            }.joined(separator: ", "))
        }
    }

    private func moveSelection(_ delta: Int) {
        let items = orderedEvents
        guard !items.isEmpty else { return }
        let current = items.firstIndex { $0.id == selectedEventID }
        let index = ((current ?? (delta > 0 ? -1 : 0)) + delta + items.count)
                  % items.count
        selectedEventID = items[index].id
        infoButton.isEnabled = true
        updateAccessibilityValue()
        onStateChange?(selectedEventID)
        needsDisplay = true
    }

    @objc private func selectPrevious(_ sender: Any?) { moveSelection(-1) }
    @objc private func selectNext(_ sender: Any?) { moveSelection(1) }
    @objc private func inspectSelection(_ sender: Any?) { _ = inspectSelected() }

    @objc private func legendEventTapped(_ sender: NSButton) {
        guard legendEvents.indices.contains(sender.tag) else { return }
        let event = legendEvents[sender.tag]
        selectedEventID = event.id
        infoButton.isEnabled = true
        updateAccessibilityValue()
        onStateChange?(selectedEventID)
        onSelectEvent?(event, sender)
        needsDisplay = true
    }

    private func inspectSelected() -> Bool {
        guard let selected = displayedEvents.first(where: { $0.id == selectedEventID })
        else { return false }
        onSelectEvent?(selected, infoButton ?? self)
        return true
    }

    private func target(at point: NSPoint) -> PrayerScheduleEvent? {
        eventTargets.filter { $0.rect.contains(point) }.min {
            hypot($0.rect.midX - point.x, $0.rect.midY - point.y)
                < hypot($1.rect.midX - point.x, $1.rect.midY - point.y)
        }?.event
    }

    override func mouseMoved(with event: NSEvent) {
        hoveredEventID = target(at: convert(event.locationInWindow, from: nil))?.id
        needsDisplay = true
    }

    override func mouseExited(with event: NSEvent) {
        hoveredEventID = nil
        needsDisplay = true
    }

    override func mouseDown(with event: NSEvent) {
        window?.makeFirstResponder(self)
        guard let item = target(at: convert(event.locationInWindow, from: nil)) else {
            return
        }
        selectedEventID = item.id
        infoButton.isEnabled = true
        updateAccessibilityValue()
        onStateChange?(selectedEventID)
        onSelectEvent?(item, self)
        needsDisplay = true
    }

    override func keyDown(with event: NSEvent) {
        let rtl = Localizer.shared.isRTL
        switch event.keyCode {
        case 123: moveSelection(rtl ? 1 : -1)
        case 124: moveSelection(rtl ? -1 : 1)
        case 125: moveSelection(1)
        case 126: moveSelection(-1)
        case 36, 49:
            if !inspectSelected() { super.keyDown(with: event) }
        default: super.keyDown(with: event)
        }
    }

    override func accessibilityPerformPress() -> Bool { inspectSelected() }

    private func point(center: NSPoint, radius: CGFloat, minute: CGFloat) -> NSPoint {
        let angle = (minute.truncatingRemainder(dividingBy: 720)) / 720
                  * 2 * .pi - .pi / 2
        return NSPoint(x: center.x + cos(angle) * radius,
                       y: center.y + sin(angle) * radius)
    }

    private func radius(for minute: CGFloat, outer: CGFloat, inner: CGFloat) -> CGFloat {
        minute.truncatingRemainder(dividingBy: 1440) < 720 ? outer : inner
    }

    private func color(for kind: PrayerScheduleKind) -> NSColor {
        switch kind {
        case .obligatory: return .appAccent
        case .rawatib: return NSColor(red: 0.84, green: 0.59, blue: 0.18, alpha: 1)
        case .duha: return .systemTeal
        case .qiyam: return .systemIndigo
        case .witr: return .systemPurple
        }
    }

    private func radialOffset(for event: PrayerScheduleEvent,
                              isAM: Bool) -> CGFloat {
        switch event.kind {
        case .obligatory: return 0
        case .rawatib:
            let distance: CGFloat = event.id.hasSuffix(".before") ? 15 : 39
            return isAM ? distance : -distance
        case .duha: return 29
        case .qiyam: return isAM ? -19 : 19
        case .witr: return isAM ? -35 : 35
        }
    }

    private func segments(for event: PrayerScheduleEvent) -> [(CGFloat, CGFloat?)] {
        let start = CGFloat(event.startMinute)
        guard let rawEnd = event.endMinute else {
            return [(CGFloat((event.startMinute % 1440 + 1440) % 1440), nil)]
        }
        let end = CGFloat(rawEnd)
        var daySegments: [(CGFloat, CGFloat)] = []
        if end <= 1440 {
            daySegments.append((max(0, start), min(1440, end)))
        } else {
            daySegments.append((max(0, start), 1440))
            daySegments.append((0, min(1440, end - 1440)))
        }
        var split: [(CGFloat, CGFloat?)] = []
        for (a, b) in daySegments where b > a {
            if a < 720, b > 720 {
                split.append((a, 720))
                split.append((720, b))
            } else {
                split.append((a, b))
            }
        }
        return split
    }

    private func drawText(_ value: String, in rect: NSRect, size: CGFloat,
                          weight: NSFont.Weight = .regular,
                          color: NSColor = .labelColor,
                          alignment: NSTextAlignment = .center) {
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = alignment
        paragraph.lineBreakMode = .byTruncatingTail
        paragraph.baseWritingDirection = Localizer.shared.isRTL ? .rightToLeft : .leftToRight
        let font = Localizer.shared.font(size: size, weight: weight)
        let drawingRect = localizedTextFrame(rect, text: value, font: font)
        NSAttributedString(string: value, attributes: [
            .font: font, .foregroundColor: color, .paragraphStyle: paragraph,
        ]).draw(with: drawingRect,
                options: [.usesLineFragmentOrigin, .usesFontLeading])
    }

    private func drawArc(center: NSPoint, radius: CGFloat, start: CGFloat,
                         end: CGFloat, color: NSColor, width: CGFloat,
                         instructional: Bool) {
        guard end > start else { return }
        let path = NSBezierPath()
        path.appendArc(withCenter: center, radius: radius,
                       startAngle: 90 - end.truncatingRemainder(dividingBy: 720) / 2,
                       endAngle: 90 - start.truncatingRemainder(dividingBy: 720) / 2,
                       clockwise: false)
        color.setStroke()
        path.lineWidth = width
        path.lineCapStyle = .round
        if instructional { path.setLineDash([5, 4], count: 2, phase: 0) }
        path.stroke()
    }

    private func activateEvent(_ id: String) {
        guard let event = displayedEvents.first(where: { $0.id == id }) else { return }
        selectedEventID = id
        infoButton.isEnabled = true
        updateAccessibilityValue()
        onStateChange?(selectedEventID)
        onSelectEvent?(event, self)
        needsDisplay = true
    }

    private func updateAccessibilityEventChildren() {
        let obligatory = orderedEvents.filter { $0.kind == .obligatory }
        var geometryParts: [String] = []
        var elements: [PrayerEventAccessibilityElement] = []
        for event in obligatory {
            let rects = eventTargets.filter { $0.event.id == event.id }.map(\.rect)
            guard var frame = rects.first else { continue }
            for rect in rects.dropFirst() { frame = frame.union(rect) }
            geometryParts.append("\(event.id):\(Int(frame.minX)):\(Int(frame.minY)):"
                + "\(Int(frame.width)):\(Int(frame.height))")
            elements.append(PrayerEventAccessibilityElement(
                parent: self, frame: frame,
                label: "\(event.knowledge.title). \(event.knowledge.whenText)",
                help: prayerInfoText("info.open"),
                pressHandler: { [weak self] in self?.activateEvent(event.id) }))
        }
        let signature = "\(Int(bounds.width))x\(Int(bounds.height))|"
            + geometryParts.joined(separator: "|")
        guard signature != accessibilityGeometrySignature else { return }
        accessibilityGeometrySignature = signature
        accessibilityEventElements = elements
        let children: [Any] = [controlRail as Any]
            + legendButtons.map { $0 as Any }
            + accessibilityEventElements.map { $0 as Any }
        setAccessibilityChildren(children)
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        let dark = effectiveAppearance.bestMatch(from: [.darkAqua, .vibrantDark]) != nil
        let card = NSBezierPath(roundedRect: bounds.insetBy(dx: 1, dy: 1),
                                xRadius: 18, yRadius: 18)
        (dark ? NSColor(white: 0.08, alpha: 0.96)
              : NSColor(white: 0.985, alpha: 0.96)).setFill()
        card.fill()
        (dark ? NSColor.white.withAlphaComponent(0.14)
              : NSColor.black.withAlphaComponent(0.10)).setStroke()
        card.lineWidth = 1
        card.stroke()

        let rtl = Localizer.shared.isRTL
        let leading: NSTextAlignment = rtl ? .right : .left
        drawText(featureText("full.view.clock"),
                 in: NSRect(x: 20, y: 14, width: bounds.width - 190, height: 30),
                 size: 20, weight: .semibold, alignment: leading)
        drawText(featureText("full.clock.am_outer"),
                 in: NSRect(x: 20, y: 43, width: bounds.width - 190, height: 18),
                 size: 10.5, color: .secondaryLabelColor, alignment: leading)

        let legend = legendRect()
        if !legend.isEmpty {
            (dark ? NSColor.white.withAlphaComponent(0.045)
                  : NSColor.black.withAlphaComponent(0.035)).setFill()
            NSBezierPath(roundedRect: legend, xRadius: 13, yRadius: 13).fill()
            drawText(featureText("full.nawafil"),
                     in: NSRect(x: legend.minX + 12, y: legend.minY + 9,
                                width: legend.width - 24, height: 20),
                     size: 13, weight: .bold, color: .secondaryLabelColor,
                     alignment: leading)
            for (index, button) in legendButtons.enumerated() {
                let selected = legendEvents.indices.contains(index)
                    && legendEvents[index].id == selectedEventID
                button.layer?.backgroundColor = (selected
                    ? NSColor.appAccent.withAlphaComponent(dark ? 0.24 : 0.13)
                    : NSColor.clear).cgColor
            }
        }

        let clockArea: NSRect
        if legend.isEmpty {
            clockArea = NSRect(x: 20, y: 70, width: bounds.width - 40,
                               height: bounds.height - 127)
        } else if rtl {
            clockArea = NSRect(x: legend.maxX + 56, y: 70,
                               width: bounds.width - legend.maxX - 76,
                               height: bounds.height - 127)
        } else {
            clockArea = NSRect(x: 20, y: 70,
                               width: legend.minX - 76,
                               height: bounds.height - 127)
        }
        let center = NSPoint(x: clockArea.midX, y: clockArea.midY + 3)
        let outer = min(clockArea.width * 0.40, clockArea.height * 0.45)
        let inner = outer * 0.66

        // Soft concentric surfaces make AM/PM separation visible in both
        // appearances while the markers remain the primary color signals.
        NSColor.systemIndigo.withAlphaComponent(dark ? 0.075 : 0.045).setFill()
        NSBezierPath(ovalIn: NSRect(x: center.x - outer - 13,
                                    y: center.y - outer - 13,
                                    width: (outer + 13) * 2,
                                    height: (outer + 13) * 2)).fill()
        (dark ? NSColor(white: 0.10, alpha: 0.96)
              : NSColor(white: 0.99, alpha: 0.96)).setFill()
        NSBezierPath(ovalIn: NSRect(x: center.x - outer,
                                    y: center.y - outer,
                                    width: outer * 2, height: outer * 2)).fill()

        for radius in [outer, inner] {
            let ring = NSBezierPath(ovalIn: NSRect(x: center.x - radius,
                                                   y: center.y - radius,
                                                   width: radius * 2,
                                                   height: radius * 2))
            NSColor.secondaryLabelColor.withAlphaComponent(0.34).setStroke()
            ring.lineWidth = radius == outer ? 3.2 : 2.2
            ring.stroke()
        }

        for hour in 1...12 {
            let minute = CGFloat(hour * 60)
            let major = hour.isMultiple(of: 3)
            let a = point(center: center, radius: outer + 1, minute: minute)
            let b = point(center: center, radius: outer - (major ? 16 : 10),
                          minute: minute)
            let tick = NSBezierPath()
            tick.move(to: a)
            tick.line(to: b)
            NSColor.labelColor.withAlphaComponent(major ? 0.80 : 0.50).setStroke()
            tick.lineWidth = major ? 5 : 2
            tick.lineCapStyle = .round
            tick.stroke()
            let numeral = point(center: center, radius: outer - 30, minute: minute)
            drawText(localizedInterfaceDigits(String(hour)),
                     in: NSRect(x: numeral.x - 18, y: numeral.y - 12,
                                width: 36, height: 24),
                     size: 17, weight: major ? .bold : .semibold)
        }

        eventTargets.removeAll(keepingCapacity: true)
        for event in displayedEvents {
            let color = color(for: event.kind)
            let selected = event.id == selectedEventID
            let hovered = event.id == hoveredEventID
            for segment in segments(for: event) {
                let isAM = segment.0 < 720
                let baseRadius = radius(for: segment.0, outer: outer, inner: inner)
                let radius = baseRadius + radialOffset(for: event, isAM: isAM)
                let width: CGFloat
                switch event.kind {
                case .obligatory: width = 12
                case .rawatib: width = 8
                case .duha, .qiyam: width = 10
                case .witr: width = 5
                }
                if let end = segment.1 {
                    drawArc(center: center, radius: radius, start: segment.0,
                            end: end, color: color.withAlphaComponent(
                                selected ? 1 : (hovered ? 0.88 : 0.64)),
                            width: selected ? width + 4 : width,
                            instructional: event.precision == .instructionalMarker)
                    // Sample the complete visible arc so every painted point
                    // sits inside a 44pt target, not just the midpoint.
                    let arcLength = radius * (end - segment.0) / 720 * 2 * .pi
                    let steps = max(1, Int(ceil(arcLength / 28)))
                    for step in 0...steps {
                        let fraction = CGFloat(step) / CGFloat(steps)
                        let value = segment.0 + (end - segment.0) * fraction
                        let marker = point(center: center, radius: radius,
                                           minute: value)
                        eventTargets.append((NSRect(x: marker.x - 22,
                                                    y: marker.y - 22,
                                                    width: 44, height: 44), event))
                    }
                } else {
                    let marker = point(center: center, radius: radius,
                                       minute: segment.0)
                    let markerRect = NSRect(x: marker.x - 7, y: marker.y - 7,
                                            width: 14, height: 14)
                    color.setFill()
                    let shape = NSBezierPath()
                    if event.kind == .rawatib && event.id.hasSuffix(".before") {
                        shape.move(to: NSPoint(x: markerRect.midX, y: markerRect.minY))
                        shape.line(to: NSPoint(x: markerRect.maxX, y: markerRect.maxY))
                        shape.line(to: NSPoint(x: markerRect.minX, y: markerRect.maxY))
                        shape.close()
                    } else if event.kind == .rawatib {
                        shape.move(to: NSPoint(x: markerRect.minX, y: markerRect.minY))
                        shape.line(to: NSPoint(x: markerRect.maxX, y: markerRect.minY))
                        shape.line(to: NSPoint(x: markerRect.midX, y: markerRect.maxY))
                        shape.close()
                    } else if event.kind == .witr {
                        shape.move(to: NSPoint(x: markerRect.midX, y: markerRect.minY))
                        shape.line(to: NSPoint(x: markerRect.maxX, y: markerRect.midY))
                        shape.line(to: NSPoint(x: markerRect.midX, y: markerRect.maxY))
                        shape.line(to: NSPoint(x: markerRect.minX, y: markerRect.midY))
                        shape.close()
                    } else {
                        shape.appendOval(in: markerRect)
                    }
                    shape.fill()
                    if selected {
                        color.withAlphaComponent(0.32).setStroke()
                        let focus = NSBezierPath(ovalIn: markerRect.insetBy(dx: -6,
                                                                           dy: -6))
                        focus.lineWidth = 3
                        focus.stroke()
                    }
                    eventTargets.append((NSRect(x: marker.x - 22, y: marker.y - 22,
                                                width: 44, height: 44), event))
                }
            }
        }
        updateAccessibilityEventChildren()

        // Obligatory labels remain larger than auxiliary markers and sit on
        // their AM/PM ring, so the clock can be read without a legend hunt.
        for event in displayedEvents where event.kind == .obligatory {
            let value = CGFloat((event.startMinute % 1440 + 1440) % 1440)
            let base = radius(for: value, outer: outer, inner: inner)
            let marker = point(center: center, radius: base, minute: value)
            NSColor.appAccent.setFill()
            NSBezierPath(ovalIn: NSRect(x: marker.x - 8, y: marker.y - 8,
                                        width: 16, height: 16)).fill()
            let labelRadius = value < 720 ? outer + 42 : inner - 39
            let label = point(center: center, radius: labelRadius, minute: value)
            drawText(event.knowledge.title,
                     in: NSRect(x: label.x - 55, y: label.y - 12,
                                width: 110, height: 24),
                     size: 13, weight: .bold, color: .labelColor)
        }

        let now = Date()
        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: now)
        let minuteValue = calendar.component(.minute, from: now)
        let second = calendar.component(.second, from: now)
        func hand(length: CGFloat, clockMinute: Double, width: CGFloat,
                  color: NSColor) {
            let angle = CGFloat(clockMinute / 720 * 2 * Double.pi) - .pi / 2
            let path = NSBezierPath()
            path.move(to: center)
            path.line(to: NSPoint(x: center.x + cos(angle) * length,
                                  y: center.y + sin(angle) * length))
            color.setStroke()
            path.lineCapStyle = .round
            path.lineWidth = width
            path.stroke()
        }
        hand(length: inner * 0.54,
             clockMinute: Double((hour % 12) * 60 + minuteValue)
                        + Double(second) / 60,
             width: 7, color: .labelColor)
        hand(length: inner * 0.82,
             clockMinute: Double(minuteValue * 12) + Double(second) / 5,
             width: 4, color: .labelColor)
        if !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion {
            hand(length: inner * 0.90, clockMinute: Double(second * 12),
                 width: 1.8, color: .systemRed)
        }
        NSColor.appAccent.setFill()
        NSBezierPath(ovalIn: NSRect(x: center.x - 7, y: center.y - 7,
                                    width: 14, height: 14)).fill()

        let formatter = DateFormatter()
        formatter.locale = preferredInterfaceLocale()
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        drawText(formatter.string(from: now),
                 in: NSRect(x: center.x - 90, y: center.y + 40,
                            width: 180, height: 30),
                 size: 19, weight: .bold, color: .appGreenAccent)

        if let id = hoveredEventID ?? selectedEventID,
           let event = displayedEvents.first(where: { $0.id == id }) {
            let ribbon = NSRect(x: 20, y: bounds.height - 57,
                                width: bounds.width - 40, height: 41)
            (dark ? NSColor.white.withAlphaComponent(0.09)
                  : NSColor.black.withAlphaComponent(0.045)).setFill()
            NSBezierPath(roundedRect: ribbon, xRadius: 10, yRadius: 10).fill()
            drawText("\(event.knowledge.title) · \(event.knowledge.whenText)",
                     in: ribbon.insetBy(dx: 12, dy: 9), size: 12,
                     weight: .semibold, alignment: leading)
        }
    }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        needsDisplay = true
    }
}

/// Icon-led presentation picker for the four prayer-time views.  Each mode is
/// still a native NSButton (rather than a drawn hit region), so keyboard focus,
/// VoiceOver actions, and the 48-point targets remain first-class AppKit
/// behavior while the surrounding capsule follows the visual language of the
/// reference control.
final class PrayerDisplayModeButton: NSButton {
    let modeIndex: Int
    private var trackingAreaRef: NSTrackingArea?
    private var isHovering = false
    var onVisualArrow: ((Int) -> Void)?

    var isModeSelected = false {
        didSet {
            state = isModeSelected ? .on : .off
            setAccessibilityValue(NSNumber(value: isModeSelected))
            updateModeAppearance()
        }
    }

    init(modeIndex: Int, symbol: String, label: String,
         target: AnyObject?, action: Selector) {
        self.modeIndex = modeIndex
        super.init(frame: NSRect(x: 0, y: 0, width: 48, height: 48))
        self.target = target
        self.action = action
        self.tag = modeIndex
        self.title = ""
        self.toolTip = label
        self.isBordered = false
        self.bezelStyle = .regularSquare
        self.imagePosition = .imageOnly
        self.imageScaling = .scaleProportionallyDown
        self.focusRingType = .default
        self.setButtonType(.toggle)
        self.image = templateSymbol(symbol, pointSize: 17, weight: .semibold)
        self.translatesAutoresizingMaskIntoConstraints = false
        self.wantsLayer = true
        self.layer?.cornerRadius = 24
        self.layer?.masksToBounds = true
        self.setAccessibilityRole(.radioButton)
        self.setAccessibilityLabel(label)
        self.setAccessibilityHelp("\(t("main.tab.prayer_times")) · \(label)")
        updateModeAppearance()
    }

    required init?(coder: NSCoder) { fatalError() }

    func updateLocalization(_ label: String) {
        toolTip = label
        setAccessibilityLabel(label)
        setAccessibilityHelp("\(t("main.tab.prayer_times")) · \(label)")
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let trackingAreaRef { removeTrackingArea(trackingAreaRef) }
        let area = NSTrackingArea(rect: bounds,
                                  options: [.mouseEnteredAndExited,
                                            .activeInActiveApp, .inVisibleRect],
                                  owner: self, userInfo: nil)
        addTrackingArea(area)
        trackingAreaRef = area
    }

    override func mouseEntered(with event: NSEvent) {
        isHovering = true
        updateModeAppearance()
    }

    override func mouseExited(with event: NSEvent) {
        isHovering = false
        updateModeAppearance()
    }

    override func keyDown(with event: NSEvent) {
        if event.keyCode == 123 || event.keyCode == 124 {
            onVisualArrow?(event.keyCode == 123 ? -1 : 1)
            return
        }
        super.keyDown(with: event)
    }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        updateModeAppearance()
    }

    private func updateModeAppearance() {
        let dark = effectiveAppearance.bestMatch(from: [.darkAqua, .vibrantDark]) != nil
        contentTintColor = isModeSelected ? .appAccent : .secondaryLabelColor
        layer?.borderWidth = isModeSelected ? 2 : 1
        layer?.borderColor = (isModeSelected
            ? NSColor.appAccent
            : NSColor.separatorColor.withAlphaComponent(dark ? 0.58 : 0.42)).cgColor
        let background: NSColor
        if isModeSelected {
            background = NSColor.appAccent.withAlphaComponent(dark ? 0.18 : 0.09)
        } else if isHovering {
            background = NSColor.labelColor.withAlphaComponent(dark ? 0.10 : 0.055)
        } else {
            background = .clear
        }
        layer?.backgroundColor = background.cgColor
    }
}

final class PrayerDisplayModeRail: NSControl {
    private static let definitions: [(key: String, symbol: String)] = [
        ("full.view.overview", "square.grid.2x2"),
        ("full.view.list", "list.bullet"),
        ("full.view.timeline", "chart.xyaxis.line"),
        ("full.view.clock", "clock"),
    ]

    private var buttonsByMode: [Int: PrayerDisplayModeButton] = [:]
    private var visuallyOrderedButtons: [PrayerDisplayModeButton] = []
    private let buttonStack = NSStackView()
    private(set) var selectedMode: Int

    override var intrinsicContentSize: NSSize {
        NSSize(width: 232, height: 60)
    }

    init(selectedMode: Int, target: AnyObject?, action: Selector) {
        self.selectedMode = max(0, min(3, selectedMode))
        super.init(frame: NSRect(x: 0, y: 0, width: 232, height: 60))
        self.target = target
        self.action = action
        self.translatesAutoresizingMaskIntoConstraints = false
        self.wantsLayer = true
        self.layer?.cornerRadius = 30
        self.layer?.masksToBounds = false
        self.setAccessibilityElement(true)
        self.setAccessibilityRole(.radioGroup)
        self.setAccessibilityLabel(t("main.tab.prayer_times"))

        buttonStack.orientation = .horizontal
        buttonStack.alignment = .centerY
        buttonStack.spacing = 8
        // The logical tags never change; only the visual order mirrors.
        buttonStack.userInterfaceLayoutDirection = .leftToRight
        buttonStack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(buttonStack)

        let logical = Self.definitions.enumerated().map { index, definition in
            PrayerDisplayModeButton(
                modeIndex: index,
                symbol: definition.symbol,
                label: featureText(definition.key),
                target: self,
                action: #selector(modePressed(_:)))
        }
        visuallyOrderedButtons = Localizer.shared.isRTL ? Array(logical.reversed()) : logical
        for button in logical {
            buttonsByMode[button.modeIndex] = button
            button.onVisualArrow = { [weak self, weak button] delta in
                guard let self, let button else { return }
                self.moveSelectionVisually(from: button, delta: delta)
            }
            NSLayoutConstraint.activate([
                button.widthAnchor.constraint(equalToConstant: 48),
                button.heightAnchor.constraint(equalToConstant: 48),
            ])
        }
        visuallyOrderedButtons.forEach { buttonStack.addArrangedSubview($0) }
        NSLayoutConstraint.activate([
            buttonStack.centerXAnchor.constraint(equalTo: centerXAnchor),
            buttonStack.centerYAnchor.constraint(equalTo: centerYAnchor),
        ])
        updateSelectionAppearance()
        updateRailAppearance()
    }

    required init?(coder: NSCoder) { fatalError() }

    func setSelectedMode(_ mode: Int, notify: Bool = false) {
        selectedMode = max(0, min(3, mode))
        updateSelectionAppearance()
        if notify { _ = sendAction(action, to: target) }
    }

    func refreshLocalization() {
        setAccessibilityLabel(t("main.tab.prayer_times"))
        for (index, definition) in Self.definitions.enumerated() {
            buttonsByMode[index]?.updateLocalization(featureText(definition.key))
        }
    }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        updateRailAppearance()
    }

    @objc private func modePressed(_ sender: PrayerDisplayModeButton) {
        setSelectedMode(sender.modeIndex, notify: true)
    }

    private func moveSelectionVisually(from button: PrayerDisplayModeButton,
                                       delta: Int) {
        guard let current = visuallyOrderedButtons.firstIndex(where: { $0 === button }) else {
            return
        }
        let next = max(0, min(visuallyOrderedButtons.count - 1, current + delta))
        let nextButton = visuallyOrderedButtons[next]
        setSelectedMode(nextButton.modeIndex, notify: true)
        window?.makeFirstResponder(nextButton)
    }

    private func updateSelectionAppearance() {
        for (mode, button) in buttonsByMode {
            button.isModeSelected = mode == selectedMode
        }
        setAccessibilityValue(featureText(Self.definitions[selectedMode].key))
    }

    private func updateRailAppearance() {
        let dark = effectiveAppearance.bestMatch(from: [.darkAqua, .vibrantDark]) != nil
        layer?.backgroundColor = (dark
            ? NSColor.white.withAlphaComponent(0.055)
            : NSColor.white.withAlphaComponent(0.68)).cgColor
        layer?.borderWidth = 1
        layer?.borderColor = NSColor.separatorColor.withAlphaComponent(dark ? 0.55 : 0.32).cgColor
        layer?.shadowColor = NSColor.black.cgColor
        layer?.shadowOpacity = dark ? 0.14 : 0.08
        layer?.shadowRadius = 9
        layer?.shadowOffset = NSSize(width: 0, height: -2)
    }
}

final class PrayerDashboardViewController: NSViewController, MainTabContent {
    private weak var appDelegate: AppDelegate?
    private var scrollView: NSScrollView!
    private var modeControl: PrayerDisplayModeRail!
    private var nawafilSwitch: NSSwitch!
    private var nawafilSwitchLabel: NSTextField!
    private var nawafilPlacementButton: NSPopUpButton!
    private var mosqueSettingsButton: HoverIconButton!
    private var countdownCard: AdaptiveCardView!
    private var countdownTitleLabel: NSTextField!
    private var countdownValueLabel: NSTextField!
    private var countdownHeightConstraint: NSLayoutConstraint!
    private var countdownWasVisible: Bool?
    private var lastCountdownPrayerIndex: Int?
    private var scheduleEvents: [PrayerScheduleEvent] = []
    private var knowledgeByButtonTag: [Int: PrayerKnowledge] = [:]
    private var nextKnowledgeButtonTag = 20_000
    private let prayerInfoPopover: NSPopover = {
        let popover = NSPopover()
        popover.behavior = .transient
        popover.animates = true
        return popover
    }()
    private var displayMode = max(0, min(3,
        UserDefaults.standard.integer(forKey: kPrayerDashboardMode)))
    private var nawafilMode: Int = {
        guard UserDefaults.standard.object(forKey: kPrayerNawafilMode) != nil else { return 2 }
        return max(0, min(2, UserDefaults.standard.integer(forKey: kPrayerNawafilMode)))
    }()
    private static let lastVisibleNawafilModeKey = "prayerNawafilLastVisibleMode"
    private var lastVisibleNawafilMode: Int = {
        let defaults = UserDefaults.standard
        let remembered = defaults.integer(forKey: "prayerNawafilLastVisibleMode")
        if (1...2).contains(remembered) { return remembered }
        let current = defaults.integer(forKey: kPrayerNawafilMode)
        return (1...2).contains(current) ? current : 2
    }()
    private var lastRenderedWidth: CGFloat = 0
    private var didSetInitialScrollPosition = false
    private var timelineVisibleStart: CGFloat = 0
    private var timelineVisibleDuration: CGFloat = 1440
    private var timelineSelectedEventID: String?
    private var clockSelectedEventID: String?

    private struct NawafilData {
        let title: String
        let count: String
        let window: String
        let best: String
        let source: String
        let knowledge: PrayerKnowledge
    }

    init(appDelegate: AppDelegate) {
        self.appDelegate = appDelegate
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError() }

    override func loadView() {
        let root = NSView()
        root.userInterfaceLayoutDirection = Localizer.shared.isRTL ? .rightToLeft : .leftToRight
        modeControl = PrayerDisplayModeRail(
            selectedMode: displayMode,
            target: self,
            action: #selector(modeChanged(_:)))

        nawafilSwitchLabel = NSTextField(labelWithString: featureText("full.nawafil"))
        nawafilSwitchLabel.font = Localizer.shared.font(size: 12.5, weight: .semibold)
        nawafilSwitchLabel.alignment = Localizer.shared.leadingAlignment
        nawafilSwitchLabel.baseWritingDirection = Localizer.shared.isRTL
            ? .rightToLeft : .leftToRight
        nawafilSwitchLabel.lineBreakMode = .byTruncatingTail
        nawafilSwitchLabel.translatesAutoresizingMaskIntoConstraints = false
        nawafilSwitchLabel.setAccessibilityElement(false)
        nawafilSwitchLabel.toolTip = featureText("full.nawafil")
        nawafilSwitchLabel.setContentCompressionResistancePriority(.defaultLow,
                                                                    for: .horizontal)

        nawafilSwitch = NSSwitch()
        nawafilSwitch.state = nawafilMode == 0 ? .off : .on
        nawafilSwitch.target = self
        nawafilSwitch.action = #selector(nawafilVisibilityChanged(_:))
        nawafilSwitch.toolTip = featureText("full.nawafil")
        nawafilSwitch.setAccessibilityLabel(featureText("full.nawafil"))
        nawafilSwitch.setAccessibilityHelp(featureText("full.nawafil.integrated"))
        nawafilSwitch.translatesAutoresizingMaskIntoConstraints = false

        nawafilPlacementButton = NSPopUpButton(frame: .zero, pullsDown: false)
        nawafilPlacementButton.addItems(withTitles: [
            featureText("full.nawafil.integrated"),
            featureText("full.nawafil.separate"),
        ])
        nawafilPlacementButton.selectItem(at: max(0, lastVisibleNawafilMode - 1))
        nawafilPlacementButton.target = self
        nawafilPlacementButton.action = #selector(nawafilPlacementChanged(_:))
        nawafilPlacementButton.image = templateSymbol("slider.horizontal.3",
                                                       pointSize: 14,
                                                       weight: .semibold)
        nawafilPlacementButton.imagePosition = .imageOnly
        nawafilPlacementButton.bezelStyle = .texturedRounded
        nawafilPlacementButton.focusRingType = .default
        nawafilPlacementButton.toolTip = selectedNawafilPlacementTitle()
        nawafilPlacementButton.setAccessibilityLabel(featureText("full.nawafil"))
        nawafilPlacementButton.setAccessibilityValue(selectedNawafilPlacementTitle())
        nawafilPlacementButton.translatesAutoresizingMaskIntoConstraints = false
        nawafilPlacementButton.isEnabled = nawafilMode != 0

        mosqueSettingsButton = HoverIconButton(
            symbol: "mappin.and.ellipse",
            toolTip: t("menu.choose"),
            target: self,
            action: #selector(openMosqueSettings(_:)),
            pointSize: 15,
            size: NSSize(width: 44, height: 44))
        mosqueSettingsButton.setAccessibilityLabel(t("menu.choose"))
        mosqueSettingsButton.setAccessibilityHelp(t("settings.mosque.change"))
        mosqueSettingsButton.translatesAutoresizingMaskIntoConstraints = false

        let nawafilControls = NSStackView(views: [nawafilSwitchLabel,
                                                  nawafilSwitch,
                                                  nawafilPlacementButton])
        nawafilControls.orientation = .horizontal
        nawafilControls.alignment = .centerY
        nawafilControls.spacing = 7
        nawafilControls.userInterfaceLayoutDirection = root.userInterfaceLayoutDirection
        nawafilControls.translatesAutoresizingMaskIntoConstraints = false
        nawafilControls.setAccessibilityElement(false)
        root.addSubview(modeControl)
        root.addSubview(nawafilControls)
        root.addSubview(mosqueSettingsButton)

        countdownCard = AdaptiveCardView()
        countdownCard.cornerRadius = 12
        countdownCard.translatesAutoresizingMaskIntoConstraints = false
        countdownCard.setAccessibilityElement(true)
        countdownCard.setAccessibilityRole(.group)
        countdownCard.setAccessibilityLabel(
            prayerInfoText("visual.countdown.accessibility"))
        root.addSubview(countdownCard)

        let countdownIcon = NSImageView()
        countdownIcon.image = templateSymbol("hourglass", pointSize: 14,
                                               weight: .semibold)
        countdownIcon.contentTintColor = .appGreenAccent
        countdownIcon.translatesAutoresizingMaskIntoConstraints = false
        countdownIcon.setAccessibilityElement(false)

        countdownTitleLabel = NSTextField(labelWithString: "")
        countdownTitleLabel.font = Localizer.shared.font(size: 13,
                                                          weight: .semibold)
        countdownTitleLabel.lineBreakMode = .byTruncatingTail
        countdownTitleLabel.alignment = Localizer.shared.isRTL ? .right : .left
        countdownTitleLabel.baseWritingDirection = Localizer.shared.isRTL
            ? .rightToLeft : .leftToRight
        countdownTitleLabel.translatesAutoresizingMaskIntoConstraints = false

        countdownValueLabel = NSTextField(labelWithString: "--:--:--")
        countdownValueLabel.font = NSFont.monospacedDigitSystemFont(ofSize: 18,
                                                                    weight: .semibold)
        countdownValueLabel.textColor = .appGreenAccent
        countdownValueLabel.alignment = .center
        countdownValueLabel.translatesAutoresizingMaskIntoConstraints = false
        countdownValueLabel.setAccessibilityLabel(
            prayerInfoText("visual.countdown.accessibility"))

        let countdownStack = NSStackView(views: [countdownIcon,
                                                  countdownTitleLabel,
                                                  countdownValueLabel])
        countdownStack.orientation = .horizontal
        countdownStack.alignment = .centerY
        countdownStack.spacing = 10
        countdownStack.userInterfaceLayoutDirection = root.userInterfaceLayoutDirection
        countdownStack.translatesAutoresizingMaskIntoConstraints = false
        countdownCard.addSubview(countdownStack)
        NSLayoutConstraint.activate([
            countdownStack.leadingAnchor.constraint(equalTo: countdownCard.leadingAnchor,
                                                      constant: 14),
            countdownStack.trailingAnchor.constraint(equalTo: countdownCard.trailingAnchor,
                                                       constant: -14),
            countdownStack.centerYAnchor.constraint(equalTo: countdownCard.centerYAnchor),
            countdownIcon.widthAnchor.constraint(equalToConstant: 20),
            countdownIcon.heightAnchor.constraint(equalToConstant: 20),
            countdownValueLabel.widthAnchor.constraint(greaterThanOrEqualToConstant: 104),
        ])

        scrollView = NSScrollView()
        scrollView.drawsBackground = false
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        if Localizer.shared.isRTL { scrollView.userInterfaceLayoutDirection = .rightToLeft }
        root.addSubview(scrollView)
        countdownHeightConstraint = countdownCard.heightAnchor.constraint(equalToConstant: 46)
        NSLayoutConstraint.activate([
            modeControl.topAnchor.constraint(equalTo: root.topAnchor, constant: 10),
            modeControl.centerXAnchor.constraint(equalTo: root.centerXAnchor),
            modeControl.widthAnchor.constraint(equalToConstant: 232),
            modeControl.heightAnchor.constraint(equalToConstant: 60),

            mosqueSettingsButton.leadingAnchor.constraint(equalTo: root.leadingAnchor,
                                                           constant: 20),
            mosqueSettingsButton.centerYAnchor.constraint(equalTo: modeControl.centerYAnchor),
            mosqueSettingsButton.widthAnchor.constraint(equalToConstant: 44),
            mosqueSettingsButton.heightAnchor.constraint(equalToConstant: 44),

            nawafilControls.trailingAnchor.constraint(equalTo: root.trailingAnchor,
                                                       constant: -20),
            nawafilControls.centerYAnchor.constraint(equalTo: modeControl.centerYAnchor),
            nawafilControls.leadingAnchor.constraint(greaterThanOrEqualTo:
                modeControl.trailingAnchor, constant: 18),
            nawafilSwitch.widthAnchor.constraint(equalToConstant: 44),
            nawafilSwitch.heightAnchor.constraint(equalToConstant: 44),
            nawafilSwitchLabel.widthAnchor.constraint(lessThanOrEqualToConstant: 130),
            nawafilPlacementButton.widthAnchor.constraint(equalToConstant: 44),
            nawafilPlacementButton.heightAnchor.constraint(equalToConstant: 44),

            countdownCard.topAnchor.constraint(equalTo: modeControl.bottomAnchor,
                                                constant: 6),
            countdownCard.centerXAnchor.constraint(equalTo: root.centerXAnchor),
            countdownCard.widthAnchor.constraint(equalToConstant: 540),
            countdownHeightConstraint,

            scrollView.leadingAnchor.constraint(equalTo: root.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: root.trailingAnchor),
            scrollView.topAnchor.constraint(equalTo: countdownCard.bottomAnchor, constant: 8),
            scrollView.bottomAnchor.constraint(equalTo: root.bottomAnchor),
        ])
        self.view = root
        rebuild()
        refreshLiveState()
    }

    override func viewDidLayout() {
        super.viewDidLayout()
        guard scrollView != nil else { return }
        let width = max(760, scrollView.contentSize.width)
        if abs(width - lastRenderedWidth) > 2 { rebuild() }
    }

    func tabDidActivate() {
        modeControl?.setSelectedMode(displayMode)
        modeControl?.refreshLocalization()
        refreshNawafilControlCopy()
        rebuild()
        refreshLiveState()
    }

    /// Updated by AppDelegate's existing one-second heartbeat. The countdown
    /// lives above the document view, so it remains visible in every display
    /// mode without rebuilding a timeline or clock once per second.
    func refreshLiveState(now: Date = Date()) {
        guard countdownCard != nil else { return }
        let visible = UserDefaults.standard.object(forKey: kPrayerShowCountdown)
            as? Bool ?? true
        if countdownWasVisible != visible {
            countdownWasVisible = visible
            countdownCard.isHidden = !visible
            countdownHeightConstraint.constant = visible ? 46 : 0
        }
        guard visible else { return }
        guard let app = appDelegate, app.info.times.count >= 5 else {
            countdownTitleLabel.stringValue = featureText("full.next_prayer")
            countdownValueLabel.stringValue = "--:--:--"
            countdownCard.setAccessibilityLabel(
                prayerInfoText("visual.countdown.accessibility"))
            countdownValueLabel.setAccessibilityValue("")
            lastCountdownPrayerIndex = nil
            return
        }
        let next = app.nextPrayer()
        guard (0..<5).contains(next.index), let date = next.date,
              app.info.times.indices.contains(next.index) else {
            countdownTitleLabel.stringValue = featureText("full.next_prayer")
            countdownValueLabel.stringValue = "--:--:--"
            countdownCard.setAccessibilityLabel(
                prayerInfoText("visual.countdown.accessibility"))
            countdownValueLabel.setAccessibilityValue("")
            lastCountdownPrayerIndex = nil
            return
        }
        if let previous = lastCountdownPrayerIndex, previous != next.index {
            lastCountdownPrayerIndex = next.index
            // The Overview hero and active prayer cards are document content;
            // refresh them once at the boundary. Other modes keep their zoom,
            // selection, and document scroll uninterrupted.
            if displayMode == 0 { rebuild() }
        } else {
            lastCountdownPrayerIndex = next.index
        }
        let seconds = max(0, Int(date.timeIntervalSince(now)))
        let hours = seconds / 3600
        let minutes = (seconds % 3600) / 60
        let remainingSeconds = seconds % 60
        let remaining = localizedInterfaceDigits(
            String(format: "%02d:%02d:%02d", hours, minutes, remainingSeconds))
        let prayer = app.localizedPrayerName(at: next.index)
        let scheduled = displayTime(app.info.times[next.index])
        countdownTitleLabel.stringValue =
            "\(featureText("full.next_prayer")) · \(prayer) · \(scheduled)"
        countdownValueLabel.stringValue = remaining
        let spoken = "\(countdownTitleLabel.stringValue). "
                   + "\(prayerInfoText("visual.countdown.accessibility")): \(remaining)"
        countdownCard.setAccessibilityLabel(spoken)
        countdownValueLabel.setAccessibilityValue(remaining)
    }

    @objc private func modeChanged(_ sender: PrayerDisplayModeRail) {
        displayMode = max(0, min(3, sender.selectedMode))
        UserDefaults.standard.set(displayMode, forKey: kPrayerDashboardMode)
        rebuild()
        scrollView.contentView.scroll(to: .zero)
        scrollView.reflectScrolledClipView(scrollView.contentView)
    }

    private func selectedNawafilPlacementTitle() -> String {
        featureText(lastVisibleNawafilMode == 1
                    ? "full.nawafil.integrated" : "full.nawafil.separate")
    }

    private func refreshNawafilControlCopy() {
        guard nawafilSwitch != nil, nawafilPlacementButton != nil else { return }
        nawafilSwitchLabel.stringValue = featureText("full.nawafil")
        nawafilSwitchLabel.font = Localizer.shared.font(size: 12.5, weight: .semibold)
        nawafilSwitchLabel.alignment = Localizer.shared.leadingAlignment
        nawafilSwitchLabel.baseWritingDirection = Localizer.shared.isRTL
            ? .rightToLeft : .leftToRight
        nawafilSwitchLabel.toolTip = featureText("full.nawafil")
        nawafilSwitch.toolTip = featureText("full.nawafil")
        nawafilSwitch.setAccessibilityLabel(featureText("full.nawafil"))
        nawafilSwitch.setAccessibilityHelp(selectedNawafilPlacementTitle())

        nawafilPlacementButton.removeAllItems()
        nawafilPlacementButton.addItems(withTitles: [
            featureText("full.nawafil.integrated"),
            featureText("full.nawafil.separate"),
        ])
        nawafilPlacementButton.image = templateSymbol("slider.horizontal.3",
                                                       pointSize: 14,
                                                       weight: .semibold)
        updateNawafilControlState()
    }

    private func updateNawafilControlState() {
        nawafilSwitch.state = nawafilMode == 0 ? .off : .on
        nawafilPlacementButton.selectItem(at: max(0, lastVisibleNawafilMode - 1))
        nawafilPlacementButton.image = templateSymbol("slider.horizontal.3",
                                                       pointSize: 14,
                                                       weight: .semibold)
        nawafilPlacementButton.imagePosition = .imageOnly
        nawafilPlacementButton.isEnabled = nawafilMode != 0
        let placement = selectedNawafilPlacementTitle()
        nawafilSwitch.setAccessibilityHelp(placement)
        nawafilPlacementButton.toolTip = placement
        nawafilPlacementButton.setAccessibilityLabel(featureText("full.nawafil"))
        nawafilPlacementButton.setAccessibilityValue(placement)
        nawafilPlacementButton.setAccessibilityHelp(placement)
    }

    @objc private func nawafilVisibilityChanged(_ sender: NSSwitch) {
        if sender.state == .on {
            nawafilMode = lastVisibleNawafilMode
        } else {
            if (1...2).contains(nawafilMode) {
                lastVisibleNawafilMode = nawafilMode
                UserDefaults.standard.set(lastVisibleNawafilMode,
                                          forKey: Self.lastVisibleNawafilModeKey)
            }
            nawafilMode = 0
        }
        UserDefaults.standard.set(nawafilMode, forKey: kPrayerNawafilMode)
        updateNawafilControlState()
        rebuild()
        scrollView.contentView.scroll(to: .zero)
        scrollView.reflectScrolledClipView(scrollView.contentView)
    }

    @objc private func nawafilPlacementChanged(_ sender: NSPopUpButton) {
        lastVisibleNawafilMode = max(1, min(2, sender.indexOfSelectedItem + 1))
        UserDefaults.standard.set(lastVisibleNawafilMode,
                                  forKey: Self.lastVisibleNawafilModeKey)
        guard nawafilSwitch.state == .on else {
            updateNawafilControlState()
            return
        }
        nawafilMode = lastVisibleNawafilMode
        UserDefaults.standard.set(nawafilMode, forKey: kPrayerNawafilMode)
        updateNawafilControlState()
        rebuild()
        scrollView.contentView.scroll(to: .zero)
        scrollView.reflectScrolledClipView(scrollView.contentView)
    }

    @objc private func openMosqueSettings(_ sender: Any?) {
        appDelegate?.openMosqueSettings()
    }

    private func makeInfoButton(for knowledge: PrayerKnowledge,
                                frame: NSRect) -> HoverIconButton {
        let button = HoverIconButton(
            symbol: "info.circle",
            toolTip: prayerInfoText("info.open"),
            target: self,
            action: #selector(prayerInfoTapped(_:)),
            pointSize: 14,
            size: frame.size)
        button.frame = frame
        button.tag = nextKnowledgeButtonTag
        knowledgeByButtonTag[nextKnowledgeButtonTag] = knowledge
        nextKnowledgeButtonTag += 1
        button.setAccessibilityLabel(
            "\(prayerInfoText("info.open")): \(knowledge.title)")
        button.setAccessibilityHelp(knowledge.category)
        return button
    }

    @objc private func prayerInfoTapped(_ sender: NSButton) {
        guard let knowledge = knowledgeByButtonTag[sender.tag] else { return }
        showPrayerInfo(knowledge, from: sender)
    }

    private func showPrayerInfo(_ knowledge: PrayerKnowledge, from source: NSView) {
        if prayerInfoPopover.isShown { prayerInfoPopover.performClose(nil) }
        prayerInfoPopover.contentViewController = PrayerInfoViewController(
            knowledge: knowledge)
        let edge: NSRectEdge = Localizer.shared.isRTL ? .minX : .maxX
        prayerInfoPopover.show(relativeTo: source.bounds, of: source,
                               preferredEdge: edge)
    }

    private func knowledge(forPrayer index: Int) -> PrayerKnowledge? {
        scheduleEvents.first { $0.kind == .obligatory && $0.prayerIndex == index }?.knowledge
    }

    private func knowledge(for kind: PrayerScheduleKind) -> PrayerKnowledge? {
        let matching = scheduleEvents.filter { $0.kind == kind }
        guard let first = matching.first else { return nil }
        guard kind == .rawatib else { return first.knowledge }
        let windows = matching.map(\.knowledge.whenText).reduce(into: [String]()) {
            if !$0.contains($1) { $0.append($1) }
        }.joined(separator: "\n")
        return PrayerKnowledge(
            id: "rawatib.all", title: featureText("nawafil.rawatib"),
            category: prayerInfoText("category.nawafil"),
            rakahs: featureText("nawafil.rawatib.count"),
            whenText: windows,
            howText: first.knowledge.howText,
            whyText: first.knowledge.whyText,
            citation: "Jāmiʿ at-Tirmidhī 415 · Ṣaḥīḥ Muslim 725a")
    }

    private func displayKnowledge(for kind: PrayerScheduleKind,
                                  title: String, count: String,
                                  window: String, citation: String) -> PrayerKnowledge {
        if let scheduled = knowledge(for: kind) { return scheduled }
        let keys: (how: String, why: String) = {
            switch kind {
            case .rawatib: return ("rawatib.how", "rawatib.why")
            case .duha: return ("duha.how", "duha.why")
            case .qiyam: return ("qiyam.how", "qiyam.why")
            case .witr: return ("witr.how", "witr.why")
            case .obligatory: return ("obligatory.how", "obligatory.why")
            }
        }()
        return PrayerKnowledge(
            id: kind.rawValue, title: title,
            category: prayerInfoText("category.nawafil"), rakahs: count,
            whenText: window, howText: prayerInfoText(keys.how),
            whyText: prayerInfoText(keys.why), citation: citation)
    }

    private func rebuild() {
        guard scrollView != nil else { return }
        let width = max(760, scrollView.contentSize.width)
        lastRenderedWidth = width
        knowledgeByButtonTag.removeAll(keepingCapacity: true)
        nextKnowledgeButtonTag = 20_000
        guard let app = appDelegate else { return }
        let contentWidth = min(856, max(680, width - 64))
        let separateCount = nawafilMode == 2 ? nawafilData(app: app).count : 0
        let separateExtra: CGFloat = nawafilMode == 2 ? 560 : 0
        let bodyHeight: CGFloat
        switch displayMode {
        case 0: bodyHeight = 670 + separateExtra
        case 1: bodyHeight = (nawafilMode == 1 ? 1240 : 820) + separateExtra
        case 2:
            let chart = InteractivePrayerDayTimelineView.preferredHeight(
                for: contentWidth)
            bodyHeight = chart + 260
                + (nawafilMode == 2 ? 100 + CGFloat(separateCount) * 128 : 0)
        default:
            let clock = PrayerRingClockView.preferredHeight(for: contentWidth)
            bodyHeight = clock + 262
                + (nawafilMode == 2 ? 100 + CGFloat(separateCount) * 128 : 0)
        }
        let body = FlippedView(frame: NSRect(x: 0, y: 0, width: width, height: bodyHeight))
        body.autoresizingMask = [.width]
        scrollView.documentView = body
        let names = (0..<5).map { app.localizedPrayerName(at: $0) }
        scheduleEvents = PrayerScheduleBuilder.events(
            info: app.info, prayerNames: names,
            iqamaTimeAt: { app.iqamaTimeAt($0) })
        let contentX = (width - contentWidth) / 2

        let pattern = MoroccanPatternView(frame: body.bounds)
        pattern.autoresizingMask = [.width, .height]
        body.addSubview(pattern)

        switch displayMode {
        case 0:
            buildOverview(in: body, app: app, x: contentX, width: contentWidth)
        case 1:
            buildList(in: body, app: app, x: contentX, width: contentWidth)
        case 2:
            buildTimeline(in: body, app: app, x: contentX, width: contentWidth)
        default:
            buildClock(in: body, app: app, x: contentX, width: contentWidth)
        }
        if !didSetInitialScrollPosition {
            didSetInitialScrollPosition = true
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                self.scrollView.contentView.scroll(to: .zero)
                self.scrollView.reflectScrolledClipView(self.scrollView.contentView)
            }
        }
    }

    private func dashboardLabel(_ text: String, frame: NSRect, size: CGFloat,
                                weight: NSFont.Weight = .regular,
                                color: NSColor = .labelColor,
                                alignment: NSTextAlignment? = nil,
                                wrapping: Bool = false) -> NSTextField {
        let isRTL = Localizer.shared.isRTL
        let field = wrapping ? NSTextField(wrappingLabelWithString: text)
                             : NSTextField(labelWithString: text)
        let font = Localizer.shared.font(size: size, weight: weight)
        field.font = font
        field.frame = localizedTextFrame(frame, text: text, font: font,
                                         maximumLines: wrapping ? 2 : 1)
        field.textColor = color
        field.alignment = alignment ?? (isRTL ? .right : .left)
        field.baseWritingDirection = isRTL ? .rightToLeft : .leftToRight
        field.lineBreakMode = wrapping ? .byWordWrapping : .byTruncatingTail
        if wrapping { field.maximumNumberOfLines = 2 }
        return field
    }

    /// Auto Layout label used inside the List presentation.  Unlike
    /// dashboardLabel, it keeps Cairo's intrinsic line box instead of expanding
    /// a fixed frame into a neighboring label.
    private func listLabel(_ text: String, size: CGFloat,
                           weight: NSFont.Weight = .regular,
                           color: NSColor = .labelColor,
                           alignment: NSTextAlignment? = nil,
                           maximumLines: Int = 1) -> NSTextField {
        let field = maximumLines > 1
            ? NSTextField(wrappingLabelWithString: text)
            : NSTextField(labelWithString: text)
        field.font = Localizer.shared.font(size: size, weight: weight)
        field.textColor = color
        field.alignment = alignment ?? Localizer.shared.leadingAlignment
        field.baseWritingDirection = Localizer.shared.isRTL
            ? .rightToLeft : .leftToRight
        field.lineBreakMode = maximumLines > 1 ? .byWordWrapping : .byTruncatingTail
        field.maximumNumberOfLines = maximumLines
        field.cell?.wraps = maximumLines > 1
        field.cell?.truncatesLastVisibleLine = maximumLines == 1
        field.translatesAutoresizingMaskIntoConstraints = false
        return field
    }

    /// Numeric clock values remain LTR even when their surrounding row is RTL;
    /// separating them from Arabic prose also avoids bidi punctuation swaps.
    private func listTimeLabel(_ text: String, size: CGFloat,
                               weight: NSFont.Weight = .semibold,
                               color: NSColor = .labelColor) -> NSTextField {
        let field = NSTextField(labelWithString: text)
        field.font = NSFont.monospacedDigitSystemFont(ofSize: size, weight: weight)
        field.textColor = color
        field.alignment = .center
        field.baseWritingDirection = .leftToRight
        field.lineBreakMode = .byClipping
        field.maximumNumberOfLines = 1
        field.translatesAutoresizingMaskIntoConstraints = false
        return field
    }

    private func localizedAdhanModeTitle(_ mode: AdhanMode) -> String {
        switch mode {
        case .off: return featureText("adhan.mode.off")
        case .notify: return featureText("adhan.mode.notify")
        case .adhan: return featureText("adhan.mode.play")
        }
    }

    private func updatePrayerModeAccessibility(_ button: NSButton, index: Int) {
        let mode = adhanModeForPrayer(index)
        let prayer = appDelegate?.localizedPrayerName(at: index) ?? ""
        let modeTitle = localizedAdhanModeTitle(mode)
        let description = "\(prayer): \(modeTitle)"
        button.toolTip = description
        button.setAccessibilityLabel(prayer)
        button.setAccessibilityValue(modeTitle)
        button.setAccessibilityHelp(description)
    }

    @objc private func prayerListModeTapped(_ sender: NSButton) {
        appDelegate?.adhanModeButtonTapped(sender)
        updatePrayerModeAccessibility(sender, index: sender.tag)
    }

    private func localizedLongDate() -> String {
        let formatter = DateFormatter()
        formatter.locale = preferredInterfaceLocale()
        formatter.dateStyle = .full
        formatter.timeStyle = .none
        return formatter.string(from: Date())
    }

    private func buildOverview(in body: NSView, app: AppDelegate,
                               x: CGFloat, width: CGFloat) {
        let isRTL = Localizer.shared.isRTL
        let nextIndex = app.info.times.count >= 5 ? app.nextPrayer().index : -1
        let validNext = (0..<5).contains(nextIndex)
        let mosqueName = app.info.name.isEmpty ? t("mosque.default") : app.info.name
        let nextName = validNext ? app.localizedPrayerName(at: nextIndex) : "—"
        let nextRaw = validNext && app.info.times.indices.contains(nextIndex)
                    ? app.info.times[nextIndex] : ""
        let nextTime = nextRaw.isEmpty ? "—" : displayTime(nextRaw)
        let iqamaRaw = validNext ? (app.iqamaTimeAt(nextIndex) ?? "") : ""

        let hero = MoroccanHeroView(frame: NSRect(x: x, y: 22, width: width, height: 178))
        body.addSubview(hero)
        let primaryX = isRTL ? width * 0.40 : 26
        let primaryWidth = width * 0.54
        let timeX = isRTL ? 26 : width * 0.66
        let timeWidth = width * 0.28
        hero.addSubview(dashboardLabel(mosqueName,
            frame: NSRect(x: primaryX, y: 17, width: primaryWidth, height: 24),
            size: 13, weight: .medium, color: NSColor.white.withAlphaComponent(0.84)))
        hero.addSubview(dashboardLabel(featureText("full.next_prayer").uppercased(),
            frame: NSRect(x: primaryX, y: 52, width: primaryWidth, height: 19),
            size: 11.5, weight: .bold, color: NSColor.white.withAlphaComponent(0.74)))
        hero.addSubview(dashboardLabel(nextName,
            frame: NSRect(x: primaryX, y: 73, width: primaryWidth, height: 40),
            size: 30, weight: .bold, color: .white))
        hero.addSubview(dashboardLabel(localizedLongDate(),
            frame: NSRect(x: primaryX, y: 136, width: primaryWidth, height: 21),
            size: 12, color: NSColor.white.withAlphaComponent(0.76)))

        let time = dashboardLabel(nextTime,
            frame: NSRect(x: timeX, y: 52, width: timeWidth, height: 58),
            size: 44, weight: .semibold, color: .white, alignment: .center)
        time.font = NSFont.monospacedDigitSystemFont(ofSize: 44, weight: .semibold)
        hero.addSubview(time)
        let iqamaText = iqamaRaw.isEmpty ? t("col.adhan")
            : "\(t("col.iqama")) · \(displayTime(iqamaRaw))"
        hero.addSubview(dashboardLabel(iqamaText,
            frame: NSRect(x: timeX, y: 118, width: timeWidth, height: 21),
            size: 12, weight: .medium,
            color: NSColor.white.withAlphaComponent(0.76), alignment: .center))

        body.addSubview(dashboardLabel(t("main.tab.prayer_times"),
            frame: NSRect(x: x, y: 222, width: width, height: 30),
            size: 22, weight: .bold))

        let gap: CGFloat = 10
        let tileWidth = (width - gap * 4) / 5
        for index in 0..<5 {
            let visualIndex = isRTL ? 4 - index : index
            let tileX = x + CGFloat(visualIndex) * (tileWidth + gap)
            let card = AdaptiveCardView(frame: NSRect(x: tileX, y: 262,
                                                       width: tileWidth, height: 144))
            card.cornerRadius = 14
            card.addsDepth = index == nextIndex
            body.addSubview(card)
            if index == nextIndex {
                let pair = currentAccentPair()
                card.addSubview(AdaptiveBackgroundView(frame: card.bounds,
                    light: pair.light.withAlphaComponent(0.13),
                    dark: pair.dark.withAlphaComponent(0.18), radius: 14))
            }
            let content = FlippedView(frame: card.bounds)
            content.autoresizingMask = [.width, .height]
            card.addSubview(content)

            let mode = NSButton(frame: NSRect(x: isRTL ? 2 : tileWidth - 46,
                                              y: 2, width: 44, height: 44))
            mode.isBordered = false
            mode.title = ""
            mode.tag = index
            mode.target = app
            mode.action = #selector(AppDelegate.adhanModeButtonTapped(_:))
            mode.imagePosition = .imageOnly
            mode.focusRingType = .default
            mode.setAccessibilityLabel(app.localizedPrayerName(at: index))
            app.applyAdhanModeIcon(to: mode, mode: adhanModeForPrayer(index))
            content.addSubview(mode)

            if let knowledge = knowledge(forPrayer: index) {
                content.addSubview(makeInfoButton(
                    for: knowledge,
                    frame: NSRect(x: isRTL ? tileWidth - 46 : 2,
                                  y: 2, width: 44, height: 44)))
            }

            let nameX: CGFloat = 46
            content.addSubview(dashboardLabel(app.localizedPrayerName(at: index),
                frame: NSRect(x: nameX, y: 14, width: tileWidth - 92, height: 24),
                size: 15.5, weight: .semibold,
                color: index == nextIndex ? .appGreenAccent : .labelColor,
                alignment: .center))
            let raw = app.info.times.indices.contains(index) ? app.info.times[index] : ""
            let adhan = dashboardLabel(raw.isEmpty ? "—" : displayTime(raw),
                frame: NSRect(x: 10, y: 54, width: tileWidth - 20, height: 36),
                size: 27, weight: .semibold,
                color: index == nextIndex ? .appGreenAccent : .labelColor,
                alignment: .center)
            adhan.font = NSFont.monospacedDigitSystemFont(ofSize: 27, weight: .semibold)
            content.addSubview(adhan)
            let iqama = app.iqamaTimeAt(index).map(displayTime) ?? "—"
            content.addSubview(dashboardLabel("\(t("col.iqama")) · \(iqama)",
                frame: NSRect(x: 8, y: 111, width: tileWidth - 16, height: 21),
                size: 11.5, color: .secondaryLabelColor, alignment: .center))
        }

        body.addSubview(dashboardLabel(featureText("full.landmarks"),
            frame: NSRect(x: x, y: 434, width: width, height: 30),
            size: 22, weight: .bold))
        addLandmarksStrip(to: body, app: app,
                          frame: NSRect(x: x, y: 472, width: width, height: 82))

        if nawafilMode == 1 {
            addIntegratedNawafilSummary(to: body, app: app,
                frame: NSRect(x: x, y: 582, width: width, height: 72))
        } else if nawafilMode == 2 {
            body.addSubview(dashboardLabel(featureText("full.nawafil"),
                frame: NSRect(x: x, y: 584, width: width, height: 30),
                size: 22, weight: .bold))
            let rows = nawafilData(app: app)
            for (index, row) in rows.enumerated() {
                addNawafilRow(to: body,
                              frame: NSRect(x: x, y: 622 + CGFloat(index) * 128,
                                            width: width, height: 116), data: row)
            }
            addGuidance(to: body, frame: NSRect(x: x, y: 1142,
                                                width: width, height: 38))
        }
    }

    private func addLandmarksStrip(to parent: NSView, app: AppDelegate, frame: NSRect) {
        let isRTL = Localizer.shared.isRTL
        let sunsetRaw = (app.info.sunset ?? "").isEmpty
            ? (app.info.times.indices.contains(3) ? app.info.times[3] : "")
            : (app.info.sunset ?? "")
        let jumuaValues = (app.info.jumuaTimes?.isEmpty == false
            ? app.info.jumuaTimes! : (app.info.jumua.isEmpty ? [] : [app.info.jumua]))
        let items: [(title: String, value: String, note: String, symbol: String)] = [
            (t("prayer.shuruq"), displayTime(app.info.shuruq),
             featureText("full.landmark.sunrise"), "sunrise.fill"),
            (featureText("full.sunset"), displayTime(sunsetRaw),
             (app.info.sunset ?? "").isEmpty
                ? featureText("full.sunset.maghrib_fallback") : featureText("full.landmark.sunset"),
             "sunset.fill"),
            (t("label.jumua"), jumuaValues.map(displayTime).joined(separator: " · "),
             featureText("full.landmark.friday"), "person.2.fill"),
        ]
        let gap: CGFloat = 10
        let cardWidth = (frame.width - gap * 2) / 3
        for (index, item) in items.enumerated() {
            let visualIndex = isRTL ? items.count - 1 - index : index
            let card = AdaptiveCardView(frame: NSRect(
                x: frame.minX + CGFloat(visualIndex) * (cardWidth + gap),
                y: frame.minY, width: cardWidth, height: frame.height))
            card.cornerRadius = 13
            parent.addSubview(card)
            let icon = NSImageView(frame: NSRect(x: isRTL ? cardWidth - 38 : 14,
                                                 y: 14, width: 20, height: 20))
            icon.image = templateSymbol(item.symbol, pointSize: 14, weight: .semibold)
            icon.contentTintColor = .appGreenAccent
            card.addSubview(icon)
            let textX: CGFloat = isRTL ? 12 : 44
            card.addSubview(dashboardLabel(item.title,
                frame: NSRect(x: textX, y: 10, width: cardWidth - 56, height: 22),
                size: 13, weight: .semibold))
            let value = item.value.isEmpty ? "—" : item.value
            let time = dashboardLabel(value,
                frame: NSRect(x: 12, y: 34, width: cardWidth - 24, height: 24),
                size: 17, weight: .semibold, alignment: .center)
            time.font = NSFont.monospacedDigitSystemFont(ofSize: 17, weight: .semibold)
            card.addSubview(time)
            card.addSubview(dashboardLabel(item.note,
                frame: NSRect(x: 10, y: 61, width: cardWidth - 20, height: 15),
                size: 10.5, color: .secondaryLabelColor, alignment: .center))
        }
    }

    private func addIntegratedNawafilSummary(to parent: NSView, app: AppDelegate,
                                               frame: NSRect) {
        let card = AdaptiveCardView(frame: frame)
        card.cornerRadius = 13
        parent.addSubview(card)
        let rows = nawafilData(app: app)
        let isRTL = Localizer.shared.isRTL
        let columnWidth = frame.width / CGFloat(rows.count)
        for (index, row) in rows.enumerated() {
            let visual = isRTL ? rows.count - 1 - index : index
            let x = CGFloat(visual) * columnWidth
            if index > 0 {
                let separator = NSBox(frame: NSRect(x: x, y: 12, width: 1,
                                                     height: frame.height - 24))
                separator.boxType = .separator
                card.addSubview(separator)
            }
            let infoX = isRTL ? x : x + columnWidth - 44
            card.addSubview(makeInfoButton(
                for: row.knowledge,
                frame: NSRect(x: infoX, y: 2, width: 44, height: 44)))
            let textX = isRTL ? x + 44 : x + 6
            card.addSubview(dashboardLabel(row.title,
                frame: NSRect(x: textX, y: 10, width: columnWidth - 50, height: 22),
                size: 13, weight: .semibold, alignment: .center))
            card.addSubview(dashboardLabel(row.count,
                frame: NSRect(x: textX, y: 39, width: columnWidth - 50, height: 18),
                size: 11, weight: .medium, color: .appGreenAccent, alignment: .center))
        }
        card.setAccessibilityLabel(featureText("full.nawafil.integrated"))
    }

    private func buildTimeline(in body: NSView, app: AppDelegate,
                               x: CGFloat, width: CGFloat) {
        let mosqueName = app.info.name.isEmpty ? t("mosque.default") : app.info.name
        body.addSubview(dashboardLabel(t("main.tab.prayer_times"),
            frame: NSRect(x: x, y: 20, width: width, height: 30),
            size: 24, weight: .bold))
        body.addSubview(dashboardLabel("\(mosqueName) · \(localizedLongDate())",
            frame: NSRect(x: x, y: 50, width: width, height: 18),
            size: 12, color: .secondaryLabelColor))
        let names = (0..<5).map { app.localizedPrayerName(at: $0) }
        let timelineHeight = InteractivePrayerDayTimelineView.preferredHeight(
            for: width)
        let timeline = InteractivePrayerDayTimelineView(
            frame: NSRect(x: x, y: 84, width: width, height: timelineHeight),
            info: app.info, prayerNames: names, showsNawafil: nawafilMode != 0,
            events: scheduleEvents,
            initialVisibleStart: timelineVisibleStart,
            initialVisibleDuration: timelineVisibleDuration,
            initialSelectedEventID: timelineSelectedEventID,
            onStateChange: { [weak self] start, duration, selectedID in
                self?.timelineVisibleStart = start
                self?.timelineVisibleDuration = duration
                self?.timelineSelectedEventID = selectedID
            },
            onSelectEvent: { [weak self] event, source in
                self?.showPrayerInfo(event.knowledge, from: source)
            })
        body.addSubview(timeline)

        var y = 84 + timelineHeight + 24
        body.addSubview(dashboardLabel(featureText("full.landmarks"),
            frame: NSRect(x: x, y: y, width: width, height: 30),
            size: 22, weight: .bold))
        y += 38
        addLandmarksStrip(to: body, app: app,
                          frame: NSRect(x: x, y: y, width: width, height: 82))
        y += 110

        if nawafilMode == 2 {
            body.addSubview(dashboardLabel(featureText("full.nawafil"),
                frame: NSRect(x: x, y: y, width: width, height: 30),
                size: 22, weight: .bold))
            y += 38
            let rows = nawafilData(app: app)
            for row in rows {
                addNawafilRow(to: body,
                              frame: NSRect(x: x, y: y,
                                            width: width, height: 116), data: row)
                y += 128
            }
            addGuidance(to: body, frame: NSRect(x: x, y: y,
                                                width: width, height: 34))
        }
    }

    private func buildList(in body: NSView, app: AppDelegate,
                           x: CGFloat, width: CGFloat) {
        let mosqueName = app.info.name.isEmpty ? t("mosque.default") : app.info.name
        let header = FlippedView(frame: NSRect(x: x, y: 14, width: width, height: 80))
        body.addSubview(header)
        let heading = listLabel(featureText("full.view.list"), size: 24,
                                weight: .bold)
        let mosque = listLabel(mosqueName, size: 12,
                               color: .secondaryLabelColor)
        let date = listLabel(localizedLongDate(), size: 12,
                             color: .secondaryLabelColor)
        mosque.setContentCompressionResistancePriority(.defaultHigh, for: .horizontal)
        date.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        let context = NSStackView(views: [mosque, date])
        context.orientation = .horizontal
        context.alignment = .centerY
        context.spacing = 8
        context.userInterfaceLayoutDirection = Localizer.shared.isRTL
            ? .rightToLeft : .leftToRight
        context.translatesAutoresizingMaskIntoConstraints = false
        header.addSubview(heading)
        header.addSubview(context)
        NSLayoutConstraint.activate([
            heading.leadingAnchor.constraint(equalTo: header.leadingAnchor),
            heading.trailingAnchor.constraint(equalTo: header.trailingAnchor),
            heading.topAnchor.constraint(equalTo: header.topAnchor, constant: 2),
            context.leadingAnchor.constraint(equalTo: header.leadingAnchor),
            context.trailingAnchor.constraint(lessThanOrEqualTo: header.trailingAnchor),
            context.topAnchor.constraint(equalTo: heading.bottomAnchor, constant: 2),
            context.bottomAnchor.constraint(lessThanOrEqualTo: header.bottomAnchor,
                                            constant: -2),
        ])

        var y: CGFloat = 108
        func prayer(_ index: Int) {
            addPrayerListRow(to: body, app: app, index: index,
                frame: NSRect(x: x, y: y, width: width, height: 78))
            y += 86
        }
        func nafl(_ kind: PrayerScheduleKind, _ title: String, _ detail: String,
                  _ citation: String) {
            let item = displayKnowledge(for: kind, title: title, count: detail,
                                        window: detail, citation: citation)
            addNawafilListRow(to: body, title: title, detail: detail,
                knowledge: item,
                frame: NSRect(x: x + 20, y: y, width: width - 40, height: 64))
            y += 72
        }
        func landmark(_ title: String, _ raw: String, _ symbol: String) {
            addLandmarkListRow(to: body, title: title, raw: raw, symbol: symbol,
                frame: NSRect(x: x + 20, y: y, width: width - 40, height: 64))
            y += 72
        }

        if nawafilMode == 1 {
            nafl(.rawatib, featureText("nawafil.rawatib"),
                 featureText("nawafil.rawatib.count"),
                 "Jāmiʿ at-Tirmidhī 415 · Ṣaḥīḥ Muslim 725a")
            prayer(0)
            landmark(t("prayer.shuruq"), app.info.shuruq, "sunrise.fill")
            nafl(.duha, featureText("nawafil.duha"),
                 featureText("nawafil.duha.count"), "Ṣaḥīḥ Muslim 720")
            prayer(1)
            if !app.info.jumua.isEmpty {
                landmark(t("label.jumua"), app.info.jumua, "person.2.fill")
            }
            nafl(.rawatib, featureText("nawafil.rawatib"),
                 featureText("nawafil.rawatib.best"), "Jāmiʿ at-Tirmidhī 415")
            prayer(2)
            let sunset = (app.info.sunset ?? "").isEmpty
                ? (app.info.times.indices.contains(3) ? app.info.times[3] : "")
                : app.info.sunset!
            landmark(featureText("full.sunset"), sunset, "sunset.fill")
            prayer(3)
            nafl(.rawatib, featureText("nawafil.rawatib"),
                 featureText("nawafil.rawatib.best"), "Jāmiʿ at-Tirmidhī 415")
            prayer(4)
            nafl(.qiyam, featureText("nawafil.qiyam"),
                 featureText("nawafil.qiyam.best"),
                 "Ṣaḥīḥ Muslim 1163a · Ṣaḥīḥ al-Bukhārī 1145")
            nafl(.witr, featureText("nawafil.witr"),
                 featureText("nawafil.witr.best"), "Ṣaḥīḥ Muslim 751b")
        } else {
            for index in 0..<5 { prayer(index) }
            body.addSubview(dashboardLabel(featureText("full.landmarks"),
                frame: NSRect(x: x, y: y + 8, width: width, height: 30),
                size: 22, weight: .bold))
            y += 46
            addLandmarksStrip(to: body, app: app,
                              frame: NSRect(x: x, y: y, width: width, height: 82))
            y += 110
        }

        if nawafilMode == 2 {
            body.addSubview(dashboardLabel(featureText("full.nawafil"),
                frame: NSRect(x: x, y: y, width: width, height: 30),
                size: 22, weight: .bold))
            y += 38
            let rows = nawafilData(app: app)
            for row in rows {
                addNawafilRow(to: body,
                              frame: NSRect(x: x, y: y, width: width, height: 116),
                              data: row)
                y += 128
            }
            addGuidance(to: body, frame: NSRect(x: x, y: y,
                                                width: width, height: 34))
        }
    }

    private func addPrayerListRow(to parent: NSView, app: AppDelegate, index: Int,
                                  frame: NSRect) {
        let card = AdaptiveCardView(frame: frame)
        card.cornerRadius = 12
        parent.addSubview(card)

        let mode = NSButton(frame: NSRect(x: 0, y: 0, width: 44, height: 44))
        mode.isBordered = false
        mode.title = ""
        mode.tag = index
        mode.target = self
        mode.action = #selector(prayerListModeTapped(_:))
        mode.imagePosition = .imageOnly
        mode.focusRingType = .default
        mode.translatesAutoresizingMaskIntoConstraints = false
        app.applyAdhanModeIcon(to: mode, mode: adhanModeForPrayer(index))
        updatePrayerModeAccessibility(mode, index: index)

        let infoView: NSView
        if let knowledge = knowledge(forPrayer: index) {
            let button = makeInfoButton(
                for: knowledge,
                frame: NSRect(x: 0, y: 0, width: 44, height: 44))
            button.translatesAutoresizingMaskIntoConstraints = false
            infoView = button
        } else {
            let placeholder = NSView()
            placeholder.translatesAutoresizingMaskIntoConstraints = false
            placeholder.setAccessibilityElement(false)
            infoView = placeholder
        }

        let title = listLabel(app.localizedPrayerName(at: index), size: 17,
                              weight: .semibold, maximumLines: 2)
        title.setContentHuggingPriority(.defaultLow, for: .horizontal)
        title.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        let raw = app.info.times.indices.contains(index) ? app.info.times[index] : ""
        let adhan = listTimeLabel(raw.isEmpty ? "—" : displayTime(raw), size: 27)
        let iqama = app.iqamaTimeAt(index).map(displayTime) ?? "—"
        let iqamaTitle = listLabel(t("col.iqama"), size: 10.5,
                                   weight: .medium,
                                   color: .secondaryLabelColor,
                                   alignment: .center)
        let iqamaValue = listTimeLabel(iqama, size: 15,
                                       color: .secondaryLabelColor)
        let iqamaStack = NSStackView(views: [iqamaTitle, iqamaValue])
        iqamaStack.orientation = .vertical
        iqamaStack.alignment = .centerX
        iqamaStack.spacing = 0
        iqamaStack.translatesAutoresizingMaskIntoConstraints = false

        let row = NSStackView(views: [infoView, title, adhan, iqamaStack, mode])
        row.orientation = .horizontal
        row.alignment = .centerY
        row.spacing = 10
        row.userInterfaceLayoutDirection = Localizer.shared.isRTL
            ? .rightToLeft : .leftToRight
        row.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(row)
        NSLayoutConstraint.activate([
            row.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 8),
            row.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -8),
            row.topAnchor.constraint(equalTo: card.topAnchor, constant: 6),
            row.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -6),
            infoView.widthAnchor.constraint(equalToConstant: 44),
            infoView.heightAnchor.constraint(equalToConstant: 44),
            adhan.widthAnchor.constraint(equalToConstant: 112),
            iqamaStack.widthAnchor.constraint(equalToConstant: 132),
            mode.widthAnchor.constraint(equalToConstant: 44),
            mode.heightAnchor.constraint(equalToConstant: 44),
        ])
    }

    private func addNawafilListRow(to parent: NSView, title: String, detail: String,
                                   knowledge: PrayerKnowledge,
                                   frame: NSRect) {
        let card = AdaptiveCardView(frame: frame)
        card.cornerRadius = 10
        parent.addSubview(card)

        let icon = NSImageView()
        icon.image = templateSymbol("sparkles", pointSize: 13, weight: .semibold)
        icon.contentTintColor = .appGreenAccent
        icon.translatesAutoresizingMaskIntoConstraints = false
        icon.setAccessibilityElement(false)
        let info = makeInfoButton(
            for: knowledge,
            frame: NSRect(x: 0, y: 0, width: 44, height: 44))
        info.translatesAutoresizingMaskIntoConstraints = false
        let titleLabel = listLabel(title, size: 14, weight: .semibold,
                                   color: .appGreenAccent, maximumLines: 1)
        let detailLabel = listLabel(detail, size: 11.5,
                                    color: .secondaryLabelColor,
                                    maximumLines: 2)
        let text = NSStackView(views: [titleLabel, detailLabel])
        text.orientation = .vertical
        text.alignment = .leading
        text.spacing = 1
        text.userInterfaceLayoutDirection = Localizer.shared.isRTL
            ? .rightToLeft : .leftToRight
        text.translatesAutoresizingMaskIntoConstraints = false
        text.setContentHuggingPriority(.defaultLow, for: .horizontal)
        text.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        let row = NSStackView(views: [icon, text, info])
        row.orientation = .horizontal
        row.alignment = .centerY
        row.spacing = 10
        row.userInterfaceLayoutDirection = Localizer.shared.isRTL
            ? .rightToLeft : .leftToRight
        row.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(row)
        NSLayoutConstraint.activate([
            row.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 14),
            row.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -4),
            row.topAnchor.constraint(equalTo: card.topAnchor, constant: 6),
            row.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -6),
            icon.widthAnchor.constraint(equalToConstant: 20),
            icon.heightAnchor.constraint(equalToConstant: 20),
            info.widthAnchor.constraint(equalToConstant: 44),
            info.heightAnchor.constraint(equalToConstant: 44),
        ])
    }

    private func addLandmarkListRow(to parent: NSView, title: String, raw: String,
                                    symbol: String, frame: NSRect) {
        let card = AdaptiveCardView(frame: frame)
        card.cornerRadius = 10
        parent.addSubview(card)

        let icon = NSImageView()
        icon.image = templateSymbol(symbol, pointSize: 13, weight: .semibold)
        icon.contentTintColor = NSColor.systemOrange
        icon.translatesAutoresizingMaskIntoConstraints = false
        icon.setAccessibilityElement(false)
        let titleLabel = listLabel(title, size: 14, weight: .semibold,
                                   maximumLines: 2)
        titleLabel.setContentHuggingPriority(.defaultLow, for: .horizontal)
        titleLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        let shownTime = raw.isEmpty ? "—" : displayTime(raw)
        let time = listTimeLabel(shownTime, size: 19)

        let row = NSStackView(views: [icon, titleLabel, time])
        row.orientation = .horizontal
        row.alignment = .centerY
        row.spacing = 10
        row.userInterfaceLayoutDirection = Localizer.shared.isRTL
            ? .rightToLeft : .leftToRight
        row.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(row)
        NSLayoutConstraint.activate([
            row.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 14),
            row.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -14),
            row.topAnchor.constraint(equalTo: card.topAnchor, constant: 6),
            row.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -6),
            icon.widthAnchor.constraint(equalToConstant: 20),
            icon.heightAnchor.constraint(equalToConstant: 20),
            time.widthAnchor.constraint(equalToConstant: 116),
        ])
        card.setAccessibilityElement(true)
        card.setAccessibilityRole(.group)
        card.setAccessibilityLabel("\(title), \(shownTime)")
        titleLabel.setAccessibilityElement(false)
        time.setAccessibilityElement(false)
    }

    private func buildClock(in body: NSView, app: AppDelegate,
                            x: CGFloat, width: CGFloat) {
        let mosqueName = app.info.name.isEmpty ? t("mosque.default") : app.info.name
        body.addSubview(dashboardLabel(featureText("full.view.clock"),
            frame: NSRect(x: x, y: 20, width: width, height: 32),
            size: 24, weight: .bold))
        body.addSubview(dashboardLabel("\(mosqueName) · \(localizedLongDate())",
            frame: NSRect(x: x, y: 52, width: width, height: 21),
            size: 12, color: .secondaryLabelColor))
        let names = (0..<5).map { app.localizedPrayerName(at: $0) }
        let clockHeight = PrayerRingClockView.preferredHeight(for: width)
        let clock = PrayerRingClockView(
            frame: NSRect(x: x, y: 84, width: width, height: clockHeight),
            info: app.info, prayerNames: names, showsNawafil: nawafilMode != 0,
            events: scheduleEvents,
            initialSelectedEventID: clockSelectedEventID,
            onStateChange: { [weak self] selectedID in
                self?.clockSelectedEventID = selectedID
            },
            onSelectEvent: { [weak self] event, source in
                self?.showPrayerInfo(event.knowledge, from: source)
            })
        body.addSubview(clock)
        var y = 84 + clockHeight + 26
        body.addSubview(dashboardLabel(featureText("full.landmarks"),
            frame: NSRect(x: x, y: y, width: width, height: 30),
            size: 22, weight: .bold))
        y += 38
        addLandmarksStrip(to: body, app: app,
                          frame: NSRect(x: x, y: y, width: width, height: 82))
        y += 110

        if nawafilMode == 2 {
            body.addSubview(dashboardLabel(featureText("full.nawafil"),
                frame: NSRect(x: x, y: y, width: width, height: 30),
                size: 22, weight: .bold))
            y += 38
            let rows = nawafilData(app: app)
            for row in rows {
                addNawafilRow(to: body,
                              frame: NSRect(x: x, y: y,
                                            width: width, height: 116), data: row)
                y += 128
            }
            addGuidance(to: body, frame: NSRect(x: x, y: y,
                                                width: width, height: 34))
        }
    }

    private func nawafilData(app: AppDelegate) -> [NawafilData] {
        let duhaWindow: String = {
            guard !app.info.shuruq.isEmpty, app.info.times.indices.contains(1) else { return "—" }
            return "\(displayTime(app.addMinutes(to: app.info.shuruq, minutes: 20))) – "
                 + "\(displayTime(app.info.times[1]))"
        }()
        let nightWindow: String = {
            guard app.info.times.indices.contains(4), app.info.times.indices.contains(0) else { return "—" }
            let start = app.iqamaTimeAt(4) ?? app.info.times[4]
            return "\(displayTime(start)) – \(displayTime(app.info.times[0]))"
        }()
        let finalThirdBest = lastThirdStart(using: app.info).map {
            "\(featureText("nawafil.qiyam.best")) · \(displayTime($0)) – \(displayTime(app.info.times[0]))"
        } ?? featureText("nawafil.qiyam.best")
        let rawatib = displayKnowledge(
            for: .rawatib, title: featureText("nawafil.rawatib"),
            count: featureText("nawafil.rawatib.count"),
            window: featureText("nawafil.rawatib.window"),
            citation: "Jāmiʿ at-Tirmidhī 415 · Ṣaḥīḥ Muslim 725a")
        let duha = displayKnowledge(
            for: .duha, title: featureText("nawafil.duha"),
            count: featureText("nawafil.duha.count"), window: duhaWindow,
            citation: "Ṣaḥīḥ Muslim 720")
        let qiyam = displayKnowledge(
            for: .qiyam, title: featureText("nawafil.qiyam"),
            count: featureText("nawafil.qiyam.count"), window: nightWindow,
            citation: "Ṣaḥīḥ Muslim 1163a · Ṣaḥīḥ al-Bukhārī 1145")
        let witr = displayKnowledge(
            for: .witr, title: featureText("nawafil.witr"),
            count: featureText("nawafil.witr.count"), window: nightWindow,
            citation: "Ṣaḥīḥ Muslim 751b")
        return [
            NawafilData(title: rawatib.title, count: rawatib.rakahs,
                         window: featureText("nawafil.rawatib.window"),
                         best: featureText("nawafil.rawatib.best"),
                         source: rawatib.citation, knowledge: rawatib),
            NawafilData(title: duha.title, count: duha.rakahs, window: duhaWindow,
                         best: featureText("nawafil.duha.best"),
                         source: duha.citation, knowledge: duha),
            NawafilData(title: qiyam.title, count: qiyam.rakahs,
                         window: qiyam.whenText,
                         best: finalThirdBest, source: qiyam.citation,
                         knowledge: qiyam),
            NawafilData(title: witr.title, count: witr.rakahs,
                         window: witr.whenText,
                         best: featureText("nawafil.witr.best"),
                         source: witr.citation, knowledge: witr),
        ]
    }

    private func addNawafilRow(to parent: NSView, frame: NSRect, data: NawafilData) {
        let isRTL = Localizer.shared.isRTL
        let card = AdaptiveCardView(frame: frame)
        card.cornerRadius = 13
        parent.addSubview(card)
        let content = FlippedView(frame: card.bounds)
        content.autoresizingMask = [.width, .height]
        card.addSubview(content)

        let countWidth: CGFloat = 160
        let titleX: CGFloat = isRTL ? countWidth + 18 : 52
        let countX: CGFloat = isRTL ? 18 : frame.width - countWidth - 18
        content.addSubview(makeInfoButton(
            for: data.knowledge,
            frame: NSRect(x: isRTL ? frame.width - 48 : 4,
                          y: 2, width: 44, height: 44)))
        content.addSubview(dashboardLabel(data.title,
            frame: NSRect(x: titleX, y: 12,
                          width: frame.width - countWidth - 100, height: 23),
            size: 17, weight: .semibold))
        content.addSubview(dashboardLabel(data.count,
            frame: NSRect(x: countX, y: 14, width: countWidth, height: 19),
            size: 12, weight: .semibold, color: .appGreenAccent,
            alignment: isRTL ? .left : .right))
        let sep = NSBox(frame: NSRect(x: 16, y: 42, width: frame.width - 32, height: 1))
        sep.boxType = .separator
        content.addSubview(sep)

        let columnGap: CGFloat = 30
        let columnWidth = (frame.width - 36 - columnGap) / 2
        let firstX: CGFloat = isRTL ? 18 + columnWidth + columnGap : 18
        let secondX: CGFloat = isRTL ? 18 : 18 + columnWidth + columnGap
        content.addSubview(dashboardLabel(featureText("full.window").uppercased(),
            frame: NSRect(x: firstX, y: 52, width: columnWidth, height: 14),
            size: 10.5, weight: .bold, color: .tertiaryLabelColor))
        content.addSubview(dashboardLabel(data.window,
            frame: NSRect(x: firstX, y: 68, width: columnWidth, height: 28),
            size: 13, color: .secondaryLabelColor, wrapping: true))
        content.addSubview(dashboardLabel(featureText("full.best").uppercased(),
            frame: NSRect(x: secondX, y: 52, width: columnWidth, height: 14),
            size: 10.5, weight: .bold, color: .tertiaryLabelColor))
        content.addSubview(dashboardLabel(data.best,
            frame: NSRect(x: secondX, y: 68, width: columnWidth, height: 28),
            size: 13, color: .secondaryLabelColor, wrapping: true))
        content.addSubview(dashboardLabel(localizedInterfaceDigits(data.source),
            frame: NSRect(x: 18, y: 100, width: frame.width - 36, height: 13),
            size: 10.5, color: .tertiaryLabelColor,
            alignment: isRTL ? .right : .left))
    }

    private func addGuidance(to parent: NSView, frame: NSRect) {
        let guidance = dashboardLabel(featureText("full.guidance"), frame: frame,
                                       size: 11, color: .tertiaryLabelColor,
                                       alignment: .center, wrapping: true)
        guidance.maximumNumberOfLines = 2
        parent.addSubview(guidance)
    }

    private func lastThirdStart(using info: MosqueInfo) -> String? {
        guard info.times.indices.contains(3), info.times.indices.contains(0),
              let maghrib = minutes(info.times[3]), let fajrBase = minutes(info.times[0]) else {
            return nil
        }
        let fajr = fajrBase <= maghrib ? fajrBase + 24 * 60 : fajrBase
        let start = maghrib + (fajr - maghrib) * 2 / 3
        return String(format: "%02d:%02d", (start / 60) % 24, start % 60)
    }

    private func minutes(_ hhmm: String) -> Int? {
        let parts = hhmm.split(separator: ":")
        guard parts.count == 2, let hour = Int(parts[0]), let minute = Int(parts[1]) else {
            return nil
        }
        return hour * 60 + minute
    }
}

// ============================================================================
// MARK: Qur'an — verified offline Hafs/Warsh Mushaf and local reading state
// ============================================================================

private struct OfflineQuranBookmark: Codable {
    var id: UUID = UUID()
    var title: String
    var edition: String
    var page: Int
    var sura: Int? = nil
    var ayah: Int? = nil
    var createdAt: Date = Date()
}

private struct OfflineQuranVerse: Decodable {
    let id: Int
    let jozz: Int
    let pageStart: Int
    let pageEnd: Int
    let suraNumber: Int
    let suraNameEnglish: String
    let suraNameArabic: String
    let ayahNumber: Int
    let uthmanicText: String
    let searchableText: String

    var pageLabel: String {
        pageStart == pageEnd ? "\(pageStart)" : "\(pageStart)–\(pageEnd)"
    }

    func appears(on page: Int) -> Bool { (pageStart...pageEnd).contains(page) }

    private enum CodingKeys: String, CodingKey {
        case id, jozz, page
        case suraNumber = "sura_no"
        case suraNameEnglish = "sura_name_en"
        case suraNameArabic = "sura_name_ar"
        case ayahNumber = "aya_no"
        case uthmanicText = "aya_text"
        case searchableText = "aya_text_emlaey"
    }

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        id = try values.decode(Int.self, forKey: .id)
        jozz = try values.decode(Int.self, forKey: .jozz)
        suraNumber = try values.decode(Int.self, forKey: .suraNumber)
        suraNameEnglish = try values.decode(String.self, forKey: .suraNameEnglish)
        suraNameArabic = try values.decode(String.self, forKey: .suraNameArabic)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        ayahNumber = try values.decode(Int.self, forKey: .ayahNumber)
        uthmanicText = try values.decode(String.self, forKey: .uthmanicText)
        searchableText = (try? values.decode(String.self, forKey: .searchableText))
            ?? uthmanicText

        if let number = try? values.decode(Int.self, forKey: .page) {
            pageStart = number
            pageEnd = number
        } else {
            let raw = (try? values.decode(String.self, forKey: .page)) ?? "1"
            let pages = raw.split(whereSeparator: { !$0.isNumber }).compactMap { Int($0) }
            pageStart = pages.first ?? 1
            pageEnd = pages.dropFirst().first ?? pageStart
        }
    }
}

private struct OfflineQuranWordMeaning: Decodable {
    let id: Int
    let page: Int
    let suraName: String
    let ayahNumber: Int
    let word: String
    let explanation: String

    private enum CodingKeys: String, CodingKey {
        case id, page
        case suraName = "sura_name"
        case ayahNumber = "aya_no"
        case word = "quranic_words"
        case explanation
    }
}

private let offlineQuranTextKeys = [
    "offline", "pages", "text", "words", "page", "of", "previous", "next",
    "zoom.out", "zoom.fit", "zoom.in", "view.continuous", "view.single",
    "sidebar", "search.loading", "search.none", "search.count",
    "words.source", "words.none", "resource.missing", "resource.detail",
    "provenance.detail", "provenance.omitted", "close"
]

private let offlineQuranTextRows: [String: [String]] = [
    "en": [
        "Offline", "Pages", "Text", "Word meanings", "Page", "of", "Previous page",
        "Next page", "Zoom out", "Fit page", "Zoom in", "Continuous",
        "Single page", "Show or hide sidebar", "Preparing offline search…",
        "No matching verses", "%@ results", "Muyassar Ghareeb word meanings · Hafs reference · not a full tafsir",
        "No word meanings on this page", "Offline Mushaf unavailable",
        "A verified bundled Qur’an resource is missing or invalid. Rebuild the app to restore it.",
        "The 604-page Hafs and Warsh Mushafs, verse indexes, and Muyassar Ghareeb word meanings are bundled locally from the King Fahd Complex. Reading, search, bookmarks, and meanings never load a web page.",
        "Full Tafsir Muyassar v3 is intentionally not bundled because the downloaded file did not match the publisher’s integrity hash.",
        "Close"
    ],
    "fr": [
        "Hors ligne", "Pages", "Texte", "Sens des mots", "Page", "sur", "Page précédente",
        "Page suivante", "Réduire", "Ajuster à la page", "Agrandir", "Continu",
        "Une page", "Afficher ou masquer la barre latérale", "Préparation de la recherche hors ligne…",
        "Aucun verset correspondant", "%@ résultats", "Sens des mots Muyassar Ghareeb · référence Hafs · pas un tafsir complet",
        "Aucun sens de mot sur cette page", "Mushaf hors ligne indisponible",
        "Une ressource coranique vérifiée manque ou est invalide. Recompilez l’app pour la restaurer.",
        "Les Mushafs Hafs et Warsh de 604 pages, les index de versets et les sens Muyassar Ghareeb sont intégrés depuis le Complexe du roi Fahd. La lecture, la recherche, les signets et les sens ne chargent jamais de page web.",
        "Le Tafsir Muyassar v3 complet n’est volontairement pas intégré car le fichier téléchargé ne correspondait pas à l’empreinte d’intégrité de l’éditeur.",
        "Fermer"
    ],
    "ar": [
        "دون اتصال", "الصفحات", "النص", "معاني الكلمات", "الصفحة", "من", "الصفحة السابقة",
        "الصفحة التالية", "تصغير", "ملاءمة الصفحة", "تكبير", "عرض متواصل",
        "صفحة واحدة", "إظهار الشريط الجانبي أو إخفاؤه", "جارٍ تجهيز البحث دون اتصال…",
        "لا توجد آيات مطابقة", "%@ نتيجة", "معاني ميسّر غريب القرآن · مرجع حفص · ليست تفسيرًا كاملًا",
        "لا توجد معاني كلمات في هذه الصفحة", "المصحف دون اتصال غير متاح",
        "أحد موارد القرآن الموثّقة المضمّنة مفقود أو غير صالح. أعد بناء التطبيق لاستعادته.",
        "مصحفا حفص وورش ذوا 604 صفحات وفهارس الآيات ومعاني ميسّر غريب القرآن مضمّنة محليًا من مجمع الملك فهد. لا تحمّل القراءة والبحث والعلامات والمعاني أي صفحة ويب.",
        "لم يُضمَّن التفسير الميسّر الكامل، الإصدار 3، لأن الملف المنزّل لم يطابق بصمة السلامة المنشورة.",
        "إغلاق"
    ],
    "es": [
        "Sin conexión", "Páginas", "Texto", "Significados", "Página", "de", "Página anterior",
        "Página siguiente", "Alejar", "Ajustar página", "Acercar", "Continuo",
        "Página única", "Mostrar u ocultar la barra lateral", "Preparando la búsqueda local…",
        "No hay aleyas coincidentes", "%@ resultados", "Significados Muyassar Ghareeb · referencia Hafs · no es un tafsir completo",
        "No hay significados en esta página", "Mushaf sin conexión no disponible",
        "Falta un recurso coránico verificado o no es válido. Vuelve a compilar la app para restaurarlo.",
        "Los Mushafs Hafs y Warsh de 604 páginas, los índices y los significados Muyassar Ghareeb se incluyen localmente desde el Complejo Rey Fahd. La lectura, búsqueda, marcadores y significados nunca cargan una web.",
        "El Tafsir Muyassar v3 completo no se incluye porque el archivo descargado no coincidía con la huella de integridad publicada.",
        "Cerrar"
    ],
    "zh": [
        "离线", "页面", "文本", "词义", "第", "共", "上一页", "下一页", "缩小", "适合页面",
        "放大", "连续", "单页", "显示或隐藏侧边栏", "正在准备离线搜索…", "没有匹配的经文",
        "%@ 个结果", "Muyassar Ghareeb 词义 · Hafs 参考 · 非完整经注", "本页没有词义",
        "离线穆斯哈夫不可用", "缺少或损坏了经验证的内置古兰经资源。请重新构建应用以恢复。",
        "604 页 Hafs 与 Warsh 穆斯哈夫、经文索引和 Muyassar Ghareeb 词义均来自法赫德国王印刷院并内置本地。阅读、搜索、书签和词义不会加载网页。",
        "未内置完整 Tafsir Muyassar v3，因为下载文件与发布方的完整性哈希不符。", "关闭"
    ],
    "hi": [
        "ऑफ़लाइन", "पृष्ठ", "पाठ", "शब्दार्थ", "पृष्ठ", "में से", "पिछला पृष्ठ", "अगला पृष्ठ",
        "ज़ूम आउट", "पृष्ठ में फ़िट", "ज़ूम इन", "निरंतर", "एक पृष्ठ", "साइडबार दिखाएँ या छिपाएँ",
        "ऑफ़लाइन खोज तैयार हो रही है…", "कोई मिलती आयत नहीं", "%@ परिणाम",
        "मुयस्सर ग़रीब शब्दार्थ · हफ़्स संदर्भ · पूर्ण तफ़सीर नहीं", "इस पृष्ठ पर शब्दार्थ नहीं",
        "ऑफ़लाइन मुसहफ़ उपलब्ध नहीं", "सत्यापित बंडल क़ुरआन संसाधन गायब या अमान्य है। इसे लौटाने के लिए ऐप फिर बनाएँ।",
        "604-पृष्ठ हफ़्स व वार्श मुसहफ़, आयत सूचकांक और मुयस्सर ग़रीब शब्दार्थ किंग फ़हद कॉम्प्लेक्स से स्थानीय रूप से शामिल हैं। पढ़ना, खोजना, बुकमार्क और शब्दार्थ कोई वेब पृष्ठ नहीं खोलते।",
        "पूर्ण तफ़सीर मुयस्सर v3 शामिल नहीं है क्योंकि डाउनलोड फ़ाइल प्रकाशक की अखंडता हैश से मेल नहीं खाई।", "बंद करें"
    ],
    "bn": [
        "অফলাইন", "পৃষ্ঠা", "পাঠ", "শব্দের অর্থ", "পৃষ্ঠা", "এর মধ্যে", "আগের পৃষ্ঠা", "পরের পৃষ্ঠা",
        "ছোট করুন", "পৃষ্ঠা মানান", "বড় করুন", "ধারাবাহিক", "এক পৃষ্ঠা", "সাইডবার দেখান বা লুকান",
        "অফলাইন খোঁজ প্রস্তুত হচ্ছে…", "মিল থাকা আয়াত নেই", "%@ ফলাফল",
        "মুয়াসসার গরীব শব্দার্থ · হাফস রেফারেন্স · পূর্ণ তাফসির নয়", "এই পৃষ্ঠায় শব্দার্থ নেই",
        "অফলাইন মুসহাফ পাওয়া যায়নি", "যাচাইকৃত অন্তর্ভুক্ত কুরআন রিসোর্স অনুপস্থিত বা অবৈধ। পুনরুদ্ধার করতে অ্যাপটি আবার বিল্ড করুন।",
        "৬০৪ পৃষ্ঠার হাফস ও ওয়ারশ মুসহাফ, আয়াত সূচি এবং মুয়াসসার গরীব শব্দার্থ কিং ফাহদ কমপ্লেক্স থেকে স্থানীয়ভাবে অন্তর্ভুক্ত। পড়া, খোঁজ, বুকমার্ক ও অর্থ কোনো ওয়েব পৃষ্ঠা লোড করে না।",
        "সম্পূর্ণ তাফসির মুয়াসসার v3 অন্তর্ভুক্ত নয়, কারণ ডাউনলোড করা ফাইলটি প্রকাশকের অখণ্ডতা হ্যাশের সঙ্গে মেলেনি।", "বন্ধ করুন"
    ],
    "ru": [
        "Офлайн", "Страницы", "Текст", "Значения слов", "Страница", "из", "Предыдущая страница",
        "Следующая страница", "Уменьшить", "По размеру страницы", "Увеличить", "Непрерывно",
        "Одна страница", "Показать или скрыть боковую панель", "Подготовка офлайн-поиска…",
        "Совпадающих аятов нет", "%@ результатов", "Значения слов Muyassar Ghareeb · Хафс · не полный тафсир",
        "На этой странице нет значений слов", "Офлайн-мусхаф недоступен",
        "Проверенный встроенный ресурс Корана отсутствует или повреждён. Пересоберите приложение.",
        "604-страничные мусхафы Хафс и Варш, индексы аятов и значения Muyassar Ghareeb встроены из Комплекса короля Фахда. Чтение, поиск, закладки и значения не загружают веб-страницы.",
        "Полный Tafsir Muyassar v3 не включён: загруженный файл не совпал с опубликованным хэшем целостности.",
        "Закрыть"
    ],
    "pt": [
        "Offline", "Páginas", "Texto", "Significados", "Página", "de", "Página anterior",
        "Página seguinte", "Reduzir", "Ajustar à página", "Ampliar", "Contínuo",
        "Página única", "Mostrar ou ocultar a barra lateral", "A preparar a pesquisa offline…",
        "Nenhum versículo correspondente", "%@ resultados", "Significados Muyassar Ghareeb · referência Hafs · não é tafsir completo",
        "Sem significados nesta página", "Mushaf offline indisponível",
        "Um recurso verificado do Alcorão está ausente ou inválido. Recompile a app para o restaurar.",
        "Os Mushafs Hafs e Warsh de 604 páginas, índices e significados Muyassar Ghareeb são incluídos localmente pelo Complexo Rei Fahd. Leitura, pesquisa, marcadores e significados nunca carregam uma página web.",
        "O Tafsir Muyassar v3 completo não é incluído porque o ficheiro transferido não correspondia ao hash de integridade publicado.",
        "Fechar"
    ],
    "ur": [
        "آف لائن", "صفحات", "متن", "الفاظ کے معنی", "صفحہ", "میں سے", "پچھلا صفحہ", "اگلا صفحہ",
        "چھوٹا کریں", "صفحہ فِٹ کریں", "بڑا کریں", "مسلسل", "ایک صفحہ", "سائیڈ بار دکھائیں یا چھپائیں",
        "آف لائن تلاش تیار ہو رہی ہے…", "کوئی مماثل آیت نہیں", "%@ نتائج",
        "میسر غریب الفاظ کے معنی · حوالہ حفص · مکمل تفسیر نہیں", "اس صفحے پر الفاظ کے معنی نہیں",
        "آف لائن مصحف دستیاب نہیں", "تصدیق شدہ شامل قرآنی وسیلہ غائب یا ناقص ہے۔ بحالی کے لیے ایپ دوبارہ بنائیں۔",
        "604 صفحات کے حفص و ورش مصاحف، آیات کے اشاریے اور میسر غریب کے معانی کنگ فہد کمپلیکس سے مقامی طور پر شامل ہیں۔ مطالعہ، تلاش، بک مارکس اور معانی کوئی ویب صفحہ لوڈ نہیں کرتے۔",
        "مکمل تفسیر میسر v3 شامل نہیں کیونکہ ڈاؤن لوڈ فائل ناشر کے شائع کردہ سالمیت ہیش سے مماثل نہیں تھی۔", "بند کریں"
    ]
]

private func offlineQuranText(_ key: String) -> String {
    let code = Localizer.shared.current.code
    let index = offlineQuranTextKeys.firstIndex(of: key)
    let raw = index.flatMap { offlineQuranTextRows[code]?[$0] }
        ?? index.flatMap { offlineQuranTextRows["en"]?[$0] }
        ?? key
    return applyingArabicDigitPreference(raw, languageCode: code)
}

private func normalizedQuranSearch(_ value: String) -> String {
    var folded = value.folding(options: [.diacriticInsensitive, .widthInsensitive,
                                          .caseInsensitive],
                               locale: Locale(identifier: "ar"))
    for (source, target) in [("أ", "ا"), ("إ", "ا"), ("آ", "ا"),
                             ("ٱ", "ا"), ("ى", "ي"), ("ؤ", "و"),
                             ("ئ", "ي")] {
        folded = folded.replacingOccurrences(of: source, with: target)
    }
    let filtered = folded.unicodeScalars.filter { scalar in
        let value = scalar.value
        if CharacterSet.nonBaseCharacters.contains(scalar) { return false }
        if (0xFC00...0xFDFF).contains(value) { return false }
        return true
    }
    return String(filtered)
        .components(separatedBy: .punctuationCharacters).joined(separator: " ")
        .components(separatedBy: .whitespacesAndNewlines)
        .filter { !$0.isEmpty }.joined(separator: " ")
}

private func westernQuranDigits(_ value: String) -> String {
    let from = Array("٠١٢٣٤٥٦٧٨٩۰۱۲۳۴۵۶۷۸۹")
    let to = Array("01234567890123456789")
    let map = Dictionary(uniqueKeysWithValues: zip(from, to))
    return String(value.map { map[$0] ?? $0 })
}

private func parseQuranReference(_ raw: String) -> (sura: Int, ayah: Int)? {
    var value = westernQuranDigits(raw).trimmingCharacters(in: .whitespacesAndNewlines)
    for separator in ["：", "/", "،", "٫"] {
        value = value.replacingOccurrences(of: separator, with: ":")
    }
    let parts = value.split(separator: ":", omittingEmptySubsequences: true)
    guard parts.count == 2,
          let sura = Int(parts[0].trimmingCharacters(in: .whitespaces)),
          let ayah = Int(parts[1].trimmingCharacters(in: .whitespaces)),
          (1...114).contains(sura), ayah > 0 else { return nil }
    return (sura, ayah)
}

/// Native, fully offline reader for the verified KFGQPC 604-page PDF assets.
/// No URL request, web view, fallback page, or external-open action exists in
/// this controller.
final class LegacyPDFQuranViewController: NSViewController, MainTabContent,
                                             NSSearchFieldDelegate,
                                             NSTableViewDataSource,
                                             NSTableViewDelegate {
    private var editionControl: NSSegmentedControl!
    private var sourceLabel: NSTextField!
    private var searchField: NSSearchField!
    private var pageField: NSTextField!
    private var pageStepper: NSStepper!
    private var displayPopup: NSPopUpButton!
    private var previousButton: HoverIconButton!
    private var nextButton: HoverIconButton!
    private var removeBookmarkButton: HoverIconButton!
    private var sidebar: NSVisualEffectView!
    private var sidebarWidth: NSLayoutConstraint!
    private var sidebarMode: NSSegmentedControl!
    private var sidebarStatus: NSTextField!
    private var pdfView: PDFView!
    private var thumbnailView: PDFThumbnailView!
    private var searchTable: NSTableView!
    private var searchScroll: NSScrollView!
    private var pageTextTable: NSTableView!
    private var pageTextScroll: NSScrollView!
    private var wordTable: NSTableView!
    private var wordScroll: NSScrollView!
    private var unavailableOverlay: NSVisualEffectView!
    private var unavailableDetail: NSTextField!

    private var verses: [OfflineQuranVerse] = []
    private var searchResults: [OfflineQuranVerse] = []
    private var currentPageVerses: [OfflineQuranVerse] = []
    private var searchMatchCount = 0
    private var meanings: [OfflineQuranWordMeaning] = []
    private var visibleMeanings: [OfflineQuranWordMeaning] = []
    private var selectedReference: OfflineQuranVerse?
    private var dataGeneration = UUID()
    private var isSearchReady = false
    private var isMeaningsReady = false
    private var loadedEdition = "hafs"
    private var suppressPagePersistence = false
    private var isLoadingEdition = false
    private var pageRestorationWorkItem: DispatchWorkItem?

    private var edition: String {
        editionControl?.selectedSegment == 1 ? "warsh" : "hafs"
    }

    private var currentPageNumber: Int {
        guard let document = pdfView?.document,
              let page = pdfView?.currentPage else { return 1 }
        return document.index(for: page) + 1
    }

    deinit {
        pageRestorationWorkItem?.cancel()
        NotificationCenter.default.removeObserver(self)
    }

    override func loadView() {
        let root = NSView()
        root.userInterfaceLayoutDirection = Localizer.shared.isRTL
            ? .rightToLeft : .leftToRight

        let header = NSVisualEffectView()
        header.material = .headerView
        header.blendingMode = .withinWindow
        header.state = .active
        header.translatesAutoresizingMaskIntoConstraints = false
        root.addSubview(header)

        let hafsLabel = "\u{2066}Hafs\u{2069} · \u{2067}حفص\u{2069}"
        let warshLabel = "\u{2066}Warsh\u{2069} · \u{2067}ورش\u{2069}"
        editionControl = NSSegmentedControl(labels: [hafsLabel, warshLabel],
                                             trackingMode: .selectOne,
                                             target: self,
                                             action: #selector(editionChanged(_:)))
        editionControl.segmentStyle = .texturedRounded
        editionControl.selectedSegment = (UserDefaults.standard.string(forKey: kQuranEditionKey)
                                           ?? "hafs") == "warsh" ? 1 : 0
        editionControl.setAccessibilityLabel(featureText("quran.tab"))
        editionControl.translatesAutoresizingMaskIntoConstraints = false
        header.addSubview(editionControl)

        sourceLabel = NSTextField(labelWithString: "")
        sourceLabel.font = Localizer.shared.font(size: 11.5, weight: .medium)
        sourceLabel.textColor = .secondaryLabelColor
        sourceLabel.lineBreakMode = .byTruncatingTail
        sourceLabel.alignment = Localizer.shared.leadingAlignment
        sourceLabel.baseWritingDirection = Localizer.shared.isRTL ? .rightToLeft : .leftToRight
        sourceLabel.translatesAutoresizingMaskIntoConstraints = false
        header.addSubview(sourceLabel)

        let provenanceButton = HoverIconButton(symbol: "checkmark.shield.fill",
            toolTip: featureText("quran.provenance"), target: self,
            action: #selector(showProvenance), pointSize: 14,
            size: NSSize(width: 44, height: 44))
        let bookmarkButton = HoverIconButton(symbol: "bookmark.fill",
            toolTip: featureText("quran.bookmarks"), target: self,
            action: #selector(showBookmarks(_:)), pointSize: 13,
            size: NSSize(width: 44, height: 44))
        let addBookmarkButton = HoverIconButton(symbol: "bookmark.badge.plus",
            toolTip: featureText("quran.bookmark.add"), target: self,
            action: #selector(addBookmark), pointSize: 13,
            size: NSSize(width: 44, height: 44))
        removeBookmarkButton = HoverIconButton(symbol: "bookmark.slash",
            toolTip: featureText("quran.bookmark.remove"), target: self,
            action: #selector(removeCurrentBookmark), pointSize: 13,
            size: NSSize(width: 44, height: 44))
        for button in [provenanceButton, bookmarkButton, addBookmarkButton,
                       removeBookmarkButton!] {
            button.translatesAutoresizingMaskIntoConstraints = false
            header.addSubview(button)
        }

        let sidebarButton = HoverIconButton(symbol: Localizer.shared.isRTL
                                                ? "sidebar.right" : "sidebar.left",
            toolTip: offlineQuranText("sidebar"), target: self,
            action: #selector(toggleSidebar), pointSize: 13,
            size: NSSize(width: 44, height: 44))
        previousButton = HoverIconButton(
            symbol: Localizer.shared.isRTL ? "chevron.right" : "chevron.left",
            toolTip: offlineQuranText("previous"), target: self,
            action: #selector(previousPage), pointSize: 13,
            size: NSSize(width: 44, height: 44))
        nextButton = HoverIconButton(
            symbol: Localizer.shared.isRTL ? "chevron.left" : "chevron.right",
            toolTip: offlineQuranText("next"), target: self,
            action: #selector(nextPage), pointSize: 13,
            size: NSSize(width: 44, height: 44))
        for button in [sidebarButton, previousButton!, nextButton!] {
            button.translatesAutoresizingMaskIntoConstraints = false
            header.addSubview(button)
        }

        pageField = NSTextField()
        pageField.alignment = .center
        pageField.font = NSFont.monospacedDigitSystemFont(ofSize: 12.5, weight: .medium)
        pageField.target = self
        pageField.action = #selector(jumpToPage)
        pageField.setAccessibilityLabel(offlineQuranText("page"))
        pageField.translatesAutoresizingMaskIntoConstraints = false
        header.addSubview(pageField)

        pageStepper = NSStepper()
        pageStepper.minValue = 1
        pageStepper.maxValue = 604
        pageStepper.increment = 1
        pageStepper.valueWraps = false
        pageStepper.target = self
        pageStepper.action = #selector(stepPage(_:))
        pageStepper.setAccessibilityLabel(offlineQuranText("page"))
        pageStepper.translatesAutoresizingMaskIntoConstraints = false
        header.addSubview(pageStepper)

        let zoomOut = HoverIconButton(symbol: "minus.magnifyingglass",
            toolTip: offlineQuranText("zoom.out"), target: self,
            action: #selector(zoomOut), pointSize: 13,
            size: NSSize(width: 44, height: 44))
        let fitPage = HoverIconButton(symbol: "arrow.up.left.and.arrow.down.right",
            toolTip: offlineQuranText("zoom.fit"), target: self,
            action: #selector(fitPage), pointSize: 12,
            size: NSSize(width: 44, height: 44))
        let zoomIn = HoverIconButton(symbol: "plus.magnifyingglass",
            toolTip: offlineQuranText("zoom.in"), target: self,
            action: #selector(zoomIn), pointSize: 13,
            size: NSSize(width: 44, height: 44))
        for button in [zoomOut, fitPage, zoomIn] {
            button.translatesAutoresizingMaskIntoConstraints = false
            header.addSubview(button)
        }

        displayPopup = NSPopUpButton(frame: .zero, pullsDown: false)
        displayPopup.addItems(withTitles: [offlineQuranText("view.continuous"),
                                           offlineQuranText("view.single")])
        displayPopup.target = self
        displayPopup.action = #selector(displayModeChanged(_:))
        displayPopup.setAccessibilityLabel(featureText("quran.reader"))
        displayPopup.translatesAutoresizingMaskIntoConstraints = false
        header.addSubview(displayPopup)

        searchField = NSSearchField()
        searchField.placeholderString = featureText("quran.search.placeholder")
        searchField.font = Localizer.shared.font(size: 12.5)
        searchField.target = self
        searchField.action = #selector(runSearch)
        searchField.delegate = self
        searchField.userInterfaceLayoutDirection = root.userInterfaceLayoutDirection
        searchField.translatesAutoresizingMaskIntoConstraints = false
        header.addSubview(searchField)

        sidebar = NSVisualEffectView()
        sidebar.material = .sidebar
        sidebar.blendingMode = .withinWindow
        sidebar.state = .active
        sidebar.translatesAutoresizingMaskIntoConstraints = false
        root.addSubview(sidebar)

        sidebarMode = NSSegmentedControl(labels: [offlineQuranText("pages"),
                                                   featureText("quran.study.search"),
                                                   offlineQuranText("text"),
                                                   offlineQuranText("words")],
                                                trackingMode: .selectOne,
                                                target: self,
                                                action: #selector(sidebarModeChanged(_:)))
        sidebarMode.segmentStyle = .texturedRounded
        sidebarMode.selectedSegment = 0
        sidebarMode.translatesAutoresizingMaskIntoConstraints = false
        sidebar.addSubview(sidebarMode)

        sidebarStatus = NSTextField(wrappingLabelWithString: "")
        sidebarStatus.font = Localizer.shared.font(size: 10.5, weight: .medium)
        sidebarStatus.textColor = .secondaryLabelColor
        sidebarStatus.alignment = .center
        sidebarStatus.maximumNumberOfLines = 2
        sidebarStatus.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        sidebarStatus.translatesAutoresizingMaskIntoConstraints = false
        sidebar.addSubview(sidebarStatus)

        pdfView = PDFView()
        pdfView.autoScales = true
        pdfView.displayMode = .singlePageContinuous
        pdfView.displayDirection = .vertical
        pdfView.displaysPageBreaks = true
        pdfView.pageShadowsEnabled = true
        pdfView.backgroundColor = .windowBackgroundColor
        pdfView.minScaleFactor = 0.2
        pdfView.maxScaleFactor = 5
        pdfView.setAccessibilityLabel(featureText("quran.reader"))
        pdfView.translatesAutoresizingMaskIntoConstraints = false
        root.addSubview(pdfView)

        thumbnailView = PDFThumbnailView()
        thumbnailView.thumbnailSize = NSSize(width: 110, height: 154)
        thumbnailView.pdfView = pdfView
        thumbnailView.setAccessibilityLabel(offlineQuranText("pages"))
        thumbnailView.translatesAutoresizingMaskIntoConstraints = false
        sidebar.addSubview(thumbnailView)

        (searchScroll, searchTable) = makeTable(accessibilityLabel: featureText("quran.study.search"))
        (pageTextScroll, pageTextTable) = makeTable(accessibilityLabel: offlineQuranText("text"))
        (wordScroll, wordTable) = makeTable(accessibilityLabel: offlineQuranText("words"))
        for scroll in [searchScroll!, pageTextScroll!, wordScroll!] {
            scroll.translatesAutoresizingMaskIntoConstraints = false
            sidebar.addSubview(scroll)
        }

        let separator = NSBox()
        separator.boxType = .separator
        separator.translatesAutoresizingMaskIntoConstraints = false
        root.addSubview(separator)

        unavailableOverlay = NSVisualEffectView()
        unavailableOverlay.material = .popover
        unavailableOverlay.blendingMode = .withinWindow
        unavailableOverlay.state = .active
        unavailableOverlay.wantsLayer = true
        unavailableOverlay.layer?.cornerRadius = 16
        unavailableOverlay.isHidden = true
        unavailableOverlay.setAccessibilityElement(true)
        unavailableOverlay.setAccessibilityRole(.group)
        unavailableOverlay.setAccessibilityLabel(offlineQuranText("resource.missing"))
        unavailableOverlay.translatesAutoresizingMaskIntoConstraints = false
        root.addSubview(unavailableOverlay)

        let unavailableTitle = NSTextField(labelWithString: offlineQuranText("resource.missing"))
        unavailableTitle.font = Localizer.shared.font(size: 20, weight: .semibold)
        unavailableTitle.alignment = .center
        unavailableDetail = NSTextField(wrappingLabelWithString: offlineQuranText("resource.detail"))
        unavailableDetail.font = Localizer.shared.font(size: 12.5)
        unavailableDetail.textColor = .secondaryLabelColor
        unavailableDetail.alignment = .center
        unavailableDetail.maximumNumberOfLines = 4
        let unavailableStack = NSStackView(views: [unavailableTitle, unavailableDetail])
        unavailableStack.orientation = .vertical
        unavailableStack.alignment = .centerX
        unavailableStack.spacing = 10
        unavailableStack.edgeInsets = NSEdgeInsets(top: 22, left: 22, bottom: 22, right: 22)
        unavailableStack.translatesAutoresizingMaskIntoConstraints = false
        unavailableOverlay.addSubview(unavailableStack)

        sidebarWidth = sidebar.widthAnchor.constraint(equalToConstant:
            UserDefaults.standard.object(forKey: kQuranSidebarVisible) == nil
                || UserDefaults.standard.bool(forKey: kQuranSidebarVisible) ? 292 : 0)

        NSLayoutConstraint.activate([
            header.leadingAnchor.constraint(equalTo: root.leadingAnchor),
            header.trailingAnchor.constraint(equalTo: root.trailingAnchor),
            header.topAnchor.constraint(equalTo: root.topAnchor),
            header.heightAnchor.constraint(equalToConstant: 112),

            editionControl.leadingAnchor.constraint(equalTo: header.leadingAnchor, constant: 20),
            editionControl.topAnchor.constraint(equalTo: header.topAnchor, constant: 6),
            editionControl.widthAnchor.constraint(equalToConstant: 220),
            editionControl.heightAnchor.constraint(equalToConstant: 44),
            sourceLabel.leadingAnchor.constraint(equalTo: editionControl.trailingAnchor, constant: 12),
            sourceLabel.centerYAnchor.constraint(equalTo: editionControl.centerYAnchor),
            sourceLabel.trailingAnchor.constraint(lessThanOrEqualTo: provenanceButton.leadingAnchor,
                                                   constant: -8),
            provenanceButton.trailingAnchor.constraint(equalTo: bookmarkButton.leadingAnchor,
                                                        constant: -4),
            provenanceButton.centerYAnchor.constraint(equalTo: editionControl.centerYAnchor),
            provenanceButton.widthAnchor.constraint(equalToConstant: 44),
            provenanceButton.heightAnchor.constraint(equalToConstant: 44),
            bookmarkButton.trailingAnchor.constraint(equalTo: addBookmarkButton.leadingAnchor,
                                                      constant: -2),
            bookmarkButton.centerYAnchor.constraint(equalTo: editionControl.centerYAnchor),
            bookmarkButton.widthAnchor.constraint(equalToConstant: 44),
            bookmarkButton.heightAnchor.constraint(equalToConstant: 44),
            addBookmarkButton.trailingAnchor.constraint(equalTo: removeBookmarkButton.leadingAnchor,
                                                         constant: -2),
            addBookmarkButton.centerYAnchor.constraint(equalTo: editionControl.centerYAnchor),
            addBookmarkButton.widthAnchor.constraint(equalToConstant: 44),
            addBookmarkButton.heightAnchor.constraint(equalToConstant: 44),
            removeBookmarkButton.trailingAnchor.constraint(equalTo: header.trailingAnchor,
                                                            constant: -20),
            removeBookmarkButton.centerYAnchor.constraint(equalTo: editionControl.centerYAnchor),
            removeBookmarkButton.widthAnchor.constraint(equalToConstant: 44),
            removeBookmarkButton.heightAnchor.constraint(equalToConstant: 44),

            sidebarButton.leadingAnchor.constraint(equalTo: header.leadingAnchor, constant: 20),
            sidebarButton.topAnchor.constraint(equalTo: header.topAnchor, constant: 62),
            sidebarButton.widthAnchor.constraint(equalToConstant: 44),
            sidebarButton.heightAnchor.constraint(equalToConstant: 44),
            previousButton.leadingAnchor.constraint(equalTo: sidebarButton.trailingAnchor, constant: 8),
            previousButton.centerYAnchor.constraint(equalTo: sidebarButton.centerYAnchor),
            previousButton.widthAnchor.constraint(equalToConstant: 44),
            previousButton.heightAnchor.constraint(equalToConstant: 44),
            nextButton.leadingAnchor.constraint(equalTo: previousButton.trailingAnchor, constant: 2),
            nextButton.centerYAnchor.constraint(equalTo: sidebarButton.centerYAnchor),
            nextButton.widthAnchor.constraint(equalToConstant: 44),
            nextButton.heightAnchor.constraint(equalToConstant: 44),
            pageField.leadingAnchor.constraint(equalTo: nextButton.trailingAnchor, constant: 8),
            pageField.centerYAnchor.constraint(equalTo: sidebarButton.centerYAnchor),
            pageField.widthAnchor.constraint(equalToConstant: 74),
            pageField.heightAnchor.constraint(equalToConstant: 44),
            pageStepper.leadingAnchor.constraint(equalTo: pageField.trailingAnchor, constant: 2),
            pageStepper.centerYAnchor.constraint(equalTo: sidebarButton.centerYAnchor),
            pageStepper.widthAnchor.constraint(equalToConstant: 44),
            pageStepper.heightAnchor.constraint(equalToConstant: 44),
            zoomOut.leadingAnchor.constraint(equalTo: pageStepper.trailingAnchor, constant: 8),
            zoomOut.centerYAnchor.constraint(equalTo: sidebarButton.centerYAnchor),
            zoomOut.widthAnchor.constraint(equalToConstant: 44),
            zoomOut.heightAnchor.constraint(equalToConstant: 44),
            fitPage.leadingAnchor.constraint(equalTo: zoomOut.trailingAnchor, constant: 2),
            fitPage.centerYAnchor.constraint(equalTo: sidebarButton.centerYAnchor),
            fitPage.widthAnchor.constraint(equalToConstant: 44),
            fitPage.heightAnchor.constraint(equalToConstant: 44),
            zoomIn.leadingAnchor.constraint(equalTo: fitPage.trailingAnchor, constant: 2),
            zoomIn.centerYAnchor.constraint(equalTo: sidebarButton.centerYAnchor),
            zoomIn.widthAnchor.constraint(equalToConstant: 44),
            zoomIn.heightAnchor.constraint(equalToConstant: 44),
            displayPopup.leadingAnchor.constraint(equalTo: zoomIn.trailingAnchor, constant: 8),
            displayPopup.centerYAnchor.constraint(equalTo: sidebarButton.centerYAnchor),
            displayPopup.widthAnchor.constraint(equalToConstant: 132),
            displayPopup.heightAnchor.constraint(equalToConstant: 44),
            searchField.leadingAnchor.constraint(equalTo: displayPopup.trailingAnchor, constant: 10),
            searchField.trailingAnchor.constraint(equalTo: header.trailingAnchor, constant: -20),
            searchField.centerYAnchor.constraint(equalTo: sidebarButton.centerYAnchor),
            searchField.heightAnchor.constraint(equalToConstant: 44),
            searchField.widthAnchor.constraint(greaterThanOrEqualToConstant: 150),

            sidebar.leadingAnchor.constraint(equalTo: root.leadingAnchor),
            sidebar.topAnchor.constraint(equalTo: header.bottomAnchor),
            sidebar.bottomAnchor.constraint(equalTo: root.bottomAnchor),
            sidebarWidth,
            separator.leadingAnchor.constraint(equalTo: sidebar.trailingAnchor),
            separator.topAnchor.constraint(equalTo: header.bottomAnchor),
            separator.bottomAnchor.constraint(equalTo: root.bottomAnchor),
            separator.widthAnchor.constraint(equalToConstant: 1),
            pdfView.leadingAnchor.constraint(equalTo: separator.trailingAnchor),
            pdfView.trailingAnchor.constraint(equalTo: root.trailingAnchor),
            pdfView.topAnchor.constraint(equalTo: header.bottomAnchor),
            pdfView.bottomAnchor.constraint(equalTo: root.bottomAnchor),

            sidebarMode.leadingAnchor.constraint(equalTo: sidebar.leadingAnchor, constant: 10),
            sidebarMode.trailingAnchor.constraint(equalTo: sidebar.trailingAnchor, constant: -10),
            sidebarMode.topAnchor.constraint(equalTo: sidebar.topAnchor, constant: 10),
            sidebarMode.heightAnchor.constraint(equalToConstant: 44),
            sidebarStatus.leadingAnchor.constraint(equalTo: sidebar.leadingAnchor, constant: 10),
            sidebarStatus.trailingAnchor.constraint(equalTo: sidebar.trailingAnchor, constant: -10),
            sidebarStatus.topAnchor.constraint(equalTo: sidebarMode.bottomAnchor, constant: 5),
            sidebarStatus.heightAnchor.constraint(equalToConstant: 54),
        ] + [thumbnailView, searchScroll, pageTextScroll, wordScroll].flatMap { content in
            [content.leadingAnchor.constraint(equalTo: sidebar.leadingAnchor, constant: 6),
             content.trailingAnchor.constraint(equalTo: sidebar.trailingAnchor, constant: -6),
             content.topAnchor.constraint(equalTo: sidebarStatus.bottomAnchor, constant: 4),
             content.bottomAnchor.constraint(equalTo: sidebar.bottomAnchor, constant: -6)]
        } + [
            unavailableOverlay.centerXAnchor.constraint(equalTo: pdfView.centerXAnchor),
            unavailableOverlay.centerYAnchor.constraint(equalTo: pdfView.centerYAnchor),
            unavailableOverlay.widthAnchor.constraint(equalToConstant: 560),
            unavailableOverlay.leadingAnchor.constraint(greaterThanOrEqualTo: pdfView.leadingAnchor,
                                                         constant: 30),
            unavailableOverlay.trailingAnchor.constraint(lessThanOrEqualTo: pdfView.trailingAnchor,
                                                          constant: -30),
            unavailableStack.leadingAnchor.constraint(equalTo: unavailableOverlay.leadingAnchor),
            unavailableStack.trailingAnchor.constraint(equalTo: unavailableOverlay.trailingAnchor),
            unavailableStack.topAnchor.constraint(equalTo: unavailableOverlay.topAnchor),
            unavailableStack.bottomAnchor.constraint(equalTo: unavailableOverlay.bottomAnchor),
            unavailableDetail.widthAnchor.constraint(lessThanOrEqualToConstant: 500),
        ])

        let viewMode = UserDefaults.standard.string(forKey: kQuranViewMode) ?? "continuous"
        displayPopup.selectItem(at: viewMode == "single" ? 1 : 0)
        applyDisplayMode()
        sidebar.isHidden = sidebarWidth.constant == 0
        searchScroll.isHidden = true
        pageTextScroll.isHidden = true
        wordScroll.isHidden = true
        sidebarStatus.stringValue = offlineQuranText("search.loading")

        NotificationCenter.default.addObserver(self,
            selector: #selector(pdfPageChanged(_:)),
            name: Notification.Name.PDFViewPageChanged,
            object: pdfView)

        view = root
        loadEdition(targetPage: nil)
    }

    func tabDidActivate() {
        updatePageState()
    }

    private func makeTable(accessibilityLabel: String) -> (NSScrollView, NSTableView) {
        let table = NSTableView()
        table.headerView = nil
        table.rowSizeStyle = .custom
        table.usesAlternatingRowBackgroundColors = false
        table.intercellSpacing = NSSize(width: 0, height: 2)
        table.delegate = self
        table.dataSource = self
        table.setAccessibilityLabel(accessibilityLabel)
        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("content"))
        column.resizingMask = .autoresizingMask
        table.addTableColumn(column)
        let scroll = NSScrollView()
        scroll.documentView = table
        scroll.hasVerticalScroller = true
        scroll.autohidesScrollers = true
        scroll.drawsBackground = false
        return (scroll, table)
    }

    private func quranResourceURL(_ components: [String]) -> URL? {
        var url = Bundle.main.resourceURL?.appendingPathComponent("Quran", isDirectory: true)
        for component in components { url?.appendPathComponent(component) }
        return url
    }

    private func pdfResourceURL(for edition: String) -> URL? {
        quranResourceURL(edition == "warsh"
            ? ["Warsh", "uthmanic_warsh_v21.pdf"]
            : ["Hafs", "uthmanic_hafs_v2-0.pdf"])
    }

    private func dataResourceURL(for edition: String) -> URL? {
        quranResourceURL(edition == "warsh"
            ? ["Warsh", "warshData_v2-1.json"]
            : ["Hafs", "hafsData_v2-0.json"])
    }

    private func lastPageKey(for edition: String) -> String {
        edition == "warsh" ? kQuranLastWarshPage : kQuranLastHafsPage
    }

    private func normalizedEdition(_ raw: String) -> String? {
        let value = normalizedQuranSearch(raw)
        let isHafs = value.contains("hafs") || value.contains("حفص")
        let isWarsh = value.contains("warsh") || value.contains("ورش")
        if isHafs != isWarsh { return isHafs ? "hafs" : "warsh" }
        return nil
    }

    /// Accept only the two KFGQPC flipbooks used by the former reader. A
    /// random URL ending in digits is never promoted into a local bookmark.
    private func recognizedLegacyPage(_ raw: String, edition: String) -> Int? {
        guard let components = URLComponents(string: raw),
              components.scheme?.lowercased() == "https",
              let host = components.host?.lowercased(),
              host == "qurancomplex.gov.sa" || host.hasSuffix(".qurancomplex.gov.sa"),
              let fragment = components.fragment else { return nil }
        let flipbook = edition == "warsh" ? "11326" : "11301"
        let pattern = "^flipbook-df_\(flipbook)/([1-9][0-9]{0,2})/?$"
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: fragment,
                  range: NSRange(fragment.startIndex..., in: fragment)),
              let range = Range(match.range(at: 1), in: fragment),
              let page = Int(fragment[range]), (1...604).contains(page) else { return nil }
        return page
    }

    private func restoredPage(for edition: String) -> Int {
        let defaults = UserDefaults.standard
        let key = lastPageKey(for: edition)
        if defaults.object(forKey: key) != nil {
            return min(max(defaults.integer(forKey: key), 1), 604)
        }
        // Preserve the user's last reading place from the former flipbook.
        let legacyKey = edition == "warsh" ? "quranLastWarshURL" : "quranLastHafsURL"
        if let raw = defaults.string(forKey: legacyKey) {
            let backupKey = "\(legacyKey)_backup"
            if defaults.object(forKey: backupKey) == nil { defaults.set(raw, forKey: backupKey) }
            if let page = recognizedLegacyPage(raw, edition: edition) {
                defaults.set(page, forKey: key)
                return page
            }
        }
        return 1
    }

    private func loadEdition(targetPage: Int?) {
        pageRestorationWorkItem?.cancel()
        pageRestorationWorkItem = nil
        if !isLoadingEdition, pdfView.document != nil, !suppressPagePersistence {
            UserDefaults.standard.set(currentPageNumber, forKey: lastPageKey(for: loadedEdition))
        }
        isLoadingEdition = true
        suppressPagePersistence = true
        dataGeneration = UUID()
        let generation = dataGeneration
        let selectedEdition = edition
        UserDefaults.standard.set(selectedEdition, forKey: kQuranEditionKey)
        verses = []
        searchResults = []
        currentPageVerses = []
        visibleMeanings = []
        meanings = []
        isMeaningsReady = selectedEdition == "warsh"
        searchMatchCount = 0
        isSearchReady = false
        selectedReference = nil
        searchTable.reloadData()
        pageTextTable.reloadData()
        wordTable.reloadData()
        sidebarStatus.stringValue = offlineQuranText("search.loading")
        pdfView.document = nil
        thumbnailView.pdfView = nil

        guard let pdfURL = pdfResourceURL(for: selectedEdition),
              FileManager.default.fileExists(atPath: pdfURL.path),
              let document = PDFDocument(url: pdfURL),
              document.pageCount == 604,
              let dataURL = dataResourceURL(for: selectedEdition),
              FileManager.default.fileExists(atPath: dataURL.path) else {
            showUnavailable()
            return
        }

        unavailableOverlay.isHidden = true
        pdfView.document = document
        thumbnailView.pdfView = pdfView
        loadedEdition = selectedEdition
        sidebarMode.setEnabled(selectedEdition == "hafs", forSegment: 3)
        if selectedEdition == "warsh" && sidebarMode.selectedSegment == 3 {
            sidebarMode.selectedSegment = 0
            sidebarModeChanged(sidebarMode)
        }
        sourceLabel.stringValue = "\(offlineQuranText("offline")) · King Fahd Complex · "
            + (selectedEdition == "warsh" ? "Warsh v2.1" : "Hafs v2.0")

        let requestedPage = min(max(targetPage ?? restoredPage(for: selectedEdition), 1),
                                document.pageCount)
        beginPageRestoration(targetPage: requestedPage,
                             generation: generation,
                             edition: selectedEdition,
                             document: document)

        let meaningsURL = quranResourceURL(["MuyassarGhareeb", "muyassar_ghareeb_1.json"])
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self else { return }
            do {
                let verseData = try Data(contentsOf: dataURL, options: .mappedIfSafe)
                let decodedVerses = try JSONDecoder().decode([OfflineQuranVerse].self,
                                                              from: verseData)
                DispatchQueue.main.async { [weak self] in
                    guard let self, self.dataGeneration == generation,
                          self.edition == selectedEdition else { return }
                    self.verses = decodedVerses
                    self.isSearchReady = true
                    self.updatePageState()
                    self.updateCurrentPageContent()
                    self.refreshLoadedSearchIfReady()
                }
            } catch {
                DispatchQueue.main.async { [weak self] in
                    guard let self, self.dataGeneration == generation else { return }
                    self.isSearchReady = false
                    self.sidebarStatus.stringValue = featureText("quran.unavailable")
                }
            }
        }

        // Ghareeb is optional, Hafs-only study material. Its failure must not
        // hide or disable the canonical PDF and verse index.
        if selectedEdition == "hafs", let meaningsURL {
            DispatchQueue.global(qos: .utility).async { [weak self] in
                let decoded = (try? Data(contentsOf: meaningsURL, options: .mappedIfSafe))
                    .flatMap { try? JSONDecoder().decode([OfflineQuranWordMeaning].self, from: $0) }
                    ?? []
                DispatchQueue.main.async { [weak self] in
                    guard let self, self.dataGeneration == generation,
                          self.edition == "hafs" else { return }
                    self.meanings = decoded
                    self.isMeaningsReady = true
                    self.updateVisibleMeanings()
                }
            }
        }
    }

    private func showUnavailable(detail: String? = nil) {
        pageRestorationWorkItem?.cancel()
        pageRestorationWorkItem = nil
        pdfView.document = nil
        thumbnailView.pdfView = nil
        sourceLabel.stringValue = offlineQuranText("resource.missing")
        unavailableDetail.stringValue = [offlineQuranText("resource.detail"), detail]
            .compactMap { $0 }.joined(separator: "\n")
        unavailableOverlay.isHidden = false
        previousButton.isEnabled = false
        nextButton.isEnabled = false
        isLoadingEdition = false
        suppressPagePersistence = false
    }

    /// PDFKit posts page-change notifications while it finishes laying out a newly
    /// assigned document. Keep persistence closed until the requested page survives
    /// several layout passes so those transient pages never replace the saved page.
    private func beginPageRestoration(targetPage: Int, generation: UUID,
                                      edition: String, document: PDFDocument) {
        pageRestorationWorkItem?.cancel()
        pdfView.autoScales = true
        view.layoutSubtreeIfNeeded()
        pdfView.layoutSubtreeIfNeeded()
        goToPage(targetPage, clearReference: false, persist: false)
        schedulePageRestorationCheck(targetPage: targetPage,
                                     generation: generation,
                                     edition: edition,
                                     document: document,
                                     stableChecks: 0,
                                     attempt: 0)
    }

    private func schedulePageRestorationCheck(targetPage: Int, generation: UUID,
                                               edition: String, document: PDFDocument,
                                               stableChecks: Int, attempt: Int) {
        let delay: TimeInterval = attempt < 4 ? 0.06 : 0.12
        let item = DispatchWorkItem { [weak self] in
            guard let self,
                  self.dataGeneration == generation,
                  self.edition == edition,
                  self.loadedEdition == edition,
                  self.pdfView.document === document,
                  self.isLoadingEdition,
                  self.suppressPagePersistence else { return }

            self.view.layoutSubtreeIfNeeded()
            self.pdfView.layoutSubtreeIfNeeded()

            let nextStableChecks: Int
            if self.currentPageNumber == targetPage {
                nextStableChecks = stableChecks + 1
            } else {
                nextStableChecks = 0
                self.goToPage(targetPage, clearReference: false, persist: false)
                self.view.layoutSubtreeIfNeeded()
                self.pdfView.layoutSubtreeIfNeeded()
            }

            guard nextStableChecks < 3 || self.currentPageNumber != targetPage else {
                self.pageRestorationWorkItem = nil
                self.suppressPagePersistence = false
                self.isLoadingEdition = false
                self.updatePageState()
                self.refreshLoadedSearchIfReady()
                return
            }

            self.schedulePageRestorationCheck(targetPage: targetPage,
                                              generation: generation,
                                              edition: edition,
                                              document: document,
                                              stableChecks: nextStableChecks,
                                              attempt: attempt + 1)
        }
        pageRestorationWorkItem = item
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: item)
    }

    @objc private func editionChanged(_ sender: NSSegmentedControl) {
        loadEdition(targetPage: nil)
    }

    @objc private func previousPage() { goToPage(currentPageNumber - 1) }
    @objc private func nextPage() { goToPage(currentPageNumber + 1) }

    @objc private func jumpToPage() {
        let raw = westernQuranDigits(pageField.stringValue)
        guard let page = Int(raw.trimmingCharacters(in: .whitespacesAndNewlines)) else {
            updatePageState()
            NSSound.beep()
            return
        }
        goToPage(page)
    }

    @objc private func stepPage(_ sender: NSStepper) {
        goToPage(sender.integerValue)
    }

    private func goToPage(_ pageNumber: Int, clearReference: Bool = true,
                          persist: Bool = true) {
        guard let document = pdfView.document else { return }
        let clamped = min(max(pageNumber, 1), document.pageCount)
        guard let page = document.page(at: clamped - 1) else { return }
        if clearReference { selectedReference = nil }
        pdfView.go(to: page)
        if persist && !suppressPagePersistence && loadedEdition == edition {
            UserDefaults.standard.set(clamped, forKey: lastPageKey(for: loadedEdition))
        }
        updatePageState()
    }

    @objc private func pdfPageChanged(_ notification: Notification) {
        if pdfView.document != nil && !suppressPagePersistence
            && !isLoadingEdition && loadedEdition == edition {
            UserDefaults.standard.set(currentPageNumber, forKey: lastPageKey(for: loadedEdition))
        }
        if selectedReference?.appears(on: currentPageNumber) != true { selectedReference = nil }
        updatePageState()
        updateCurrentPageContent()
    }

    private func updatePageState() {
        let page = currentPageNumber
        let text = localizedInterfaceDigits("\(page)")
        pageField?.stringValue = text
        pageStepper?.integerValue = page
        let canNavigate = pdfView?.document != nil && !isLoadingEdition
        pageField?.isEnabled = canNavigate
        pageStepper?.isEnabled = canNavigate
        previousButton?.isEnabled = canNavigate && page > 1
        nextButton?.isEnabled = canNavigate
            && page < (pdfView?.document?.pageCount ?? 0)
        removeBookmarkButton?.isEnabled = loadBookmarks().contains {
            $0.edition == loadedEdition && $0.page == page
        }
        guard sidebarMode?.selectedSegment == 0 else { return }
        sidebarStatus?.stringValue = localizedInterfaceDigits(
            "\(offlineQuranText("page")) \(page) \(offlineQuranText("of")) 604")
    }

    @objc private func zoomOut() {
        pdfView.autoScales = false
        pdfView.scaleFactor = max(pdfView.minScaleFactor, pdfView.scaleFactor / 1.18)
    }

    @objc private func fitPage() { pdfView.autoScales = true }

    @objc private func zoomIn() {
        pdfView.autoScales = false
        pdfView.scaleFactor = min(pdfView.maxScaleFactor, pdfView.scaleFactor * 1.18)
    }

    @objc private func displayModeChanged(_ sender: NSPopUpButton) {
        UserDefaults.standard.set(sender.indexOfSelectedItem == 1 ? "single" : "continuous",
                                  forKey: kQuranViewMode)
        applyDisplayMode()
    }

    private func applyDisplayMode() {
        let single = displayPopup?.indexOfSelectedItem == 1
        pdfView?.displayMode = single ? .singlePage : .singlePageContinuous
        pdfView?.displayDirection = .vertical
        pdfView?.displaysPageBreaks = true
        pdfView?.autoScales = true
    }

    @objc private func toggleSidebar() {
        let showing = sidebarWidth.constant > 0
        let targetWidth: CGFloat = showing ? 0 : 292
        sidebar.isHidden = false
        UserDefaults.standard.set(!showing, forKey: kQuranSidebarVisible)
        if NSWorkspace.shared.accessibilityDisplayShouldReduceMotion {
            sidebarWidth.constant = targetWidth
            view.layoutSubtreeIfNeeded()
            sidebar.isHidden = showing
            return
        }
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.2
            sidebarWidth.animator().constant = targetWidth
            view.layoutSubtreeIfNeeded()
        } completionHandler: { [weak self] in
            self?.sidebar.isHidden = showing
        }
    }

    @objc private func sidebarModeChanged(_ sender: NSSegmentedControl) {
        thumbnailView.isHidden = sender.selectedSegment != 0
        searchScroll.isHidden = sender.selectedSegment != 1
        pageTextScroll.isHidden = sender.selectedSegment != 2
        wordScroll.isHidden = sender.selectedSegment != 3
        switch sender.selectedSegment {
        case 0:
            updatePageState()
        case 1:
            updateSearchStatus()
        case 2:
            updateCurrentPageContent()
        default:
            updateVisibleMeanings()
        }
    }

    @objc private func runSearch() {
        guard isSearchReady else {
            sidebarStatus.stringValue = offlineQuranText("search.loading")
            return
        }
        let query = searchField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else {
            searchResults = []
            searchMatchCount = 0
            searchTable.reloadData()
            sidebarMode.selectedSegment = 1
            sidebarModeChanged(sidebarMode)
            return
        }

        if let reference = parseQuranReference(query),
           let match = verses.first(where: {
               $0.suraNumber == reference.sura && $0.ayahNumber == reference.ayah
           }) {
            searchResults = [match]
            searchMatchCount = 1
            selectedReference = match
            goToPage(match.pageStart, clearReference: false)
        } else {
            let needle = normalizedQuranSearch(query)
            guard !needle.isEmpty else {
                searchResults = []
                searchMatchCount = 0
                searchTable.reloadData()
                NSSound.beep()
                updateSearchStatus()
                return
            }
            var firstMatches: [OfflineQuranVerse] = []
            var total = 0
            for verse in verses where normalizedQuranSearch(verse.searchableText).contains(needle)
                || normalizedQuranSearch(verse.suraNameArabic).contains(needle)
                || normalizedQuranSearch(verse.suraNameEnglish).contains(needle) {
                total += 1
                if firstMatches.count < 250 { firstMatches.append(verse) }
            }
            searchResults = firstMatches
            searchMatchCount = total
        }
        searchTable.reloadData()
        sidebarMode.selectedSegment = 1
        sidebarModeChanged(sidebarMode)
        if searchResults.count == 1 { searchTable.selectRowIndexes([0], byExtendingSelection: false) }
    }

    private func updateSearchStatus() {
        if !isSearchReady {
            sidebarStatus.stringValue = offlineQuranText("search.loading")
        } else if searchResults.isEmpty {
            sidebarStatus.stringValue = offlineQuranText("search.none")
        } else if searchMatchCount > searchResults.count {
            sidebarStatus.stringValue = localizedInterfaceDigits(
                "\(featureText("quran.study.search")) · \(searchResults.count) / \(searchMatchCount)")
        } else {
            let count = localizedInterfaceDigits(String(searchMatchCount))
            sidebarStatus.stringValue = offlineQuranText("search.count")
                .replacingOccurrences(of: "%@", with: count)
        }
    }

    /// A PDF restore and its local verse index finish independently. Refresh a
    /// retained query only after both are stable so search navigation cannot be
    /// snapped back to the restored page by a late PDFKit layout notification.
    private func refreshLoadedSearchIfReady() {
        guard isSearchReady, !isLoadingEdition,
              sidebarMode?.selectedSegment == 1 else { return }
        let query = searchField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        if query.isEmpty {
            updateSearchStatus()
        } else {
            runSearch()
        }
    }

    private func updateVisibleMeanings() {
        guard edition == "hafs" else {
            visibleMeanings = []
            wordTable?.reloadData()
            if sidebarMode?.selectedSegment == 3 {
                sidebarStatus?.stringValue = featureText("quran.study.hafs_only")
            }
            return
        }
        guard !meanings.isEmpty else {
            visibleMeanings = []
            wordTable?.reloadData()
            if sidebarMode?.selectedSegment == 3 {
                sidebarStatus?.stringValue = isMeaningsReady
                    ? offlineQuranText("words.none") : offlineQuranText("search.loading")
            }
            return
        }
        let page = currentPageNumber
        if let selected = selectedReference, selected.appears(on: page) {
            let sura = normalizedQuranSearch(selected.suraNameArabic)
            visibleMeanings = meanings.filter {
                $0.page == page && $0.ayahNumber == selected.ayahNumber
                    && normalizedQuranSearch($0.suraName) == sura
            }
        } else {
            visibleMeanings = meanings.filter { $0.page == page }
        }
        wordTable?.reloadData()
        guard sidebarMode?.selectedSegment == 3 else { return }
        sidebarStatus?.stringValue = visibleMeanings.isEmpty
            ? offlineQuranText("words.none") : offlineQuranText("words.source")
    }

    private func updateCurrentPageContent() {
        currentPageVerses = verses.filter { $0.appears(on: currentPageNumber) }
        pageTextTable?.reloadData()
        if sidebarMode?.selectedSegment == 2 {
            sidebarStatus?.stringValue = currentPageVerses.isEmpty
                ? featureText("quran.unavailable")
                : localizedInterfaceDigits("\(offlineQuranText("page")) \(currentPageNumber)")
        }
        updateVisibleMeanings()
    }

    func numberOfRows(in tableView: NSTableView) -> Int {
        if tableView === searchTable { return searchResults.count }
        if tableView === pageTextTable { return currentPageVerses.count }
        return visibleMeanings.count
    }

    func tableView(_ tableView: NSTableView, heightOfRow row: Int) -> CGFloat {
        let value: String
        if tableView === searchTable, searchResults.indices.contains(row) {
            value = searchResults[row].uthmanicText
        } else if tableView === pageTextTable, currentPageVerses.indices.contains(row) {
            value = currentPageVerses[row].uthmanicText
        } else if visibleMeanings.indices.contains(row) {
            value = visibleMeanings[row].explanation
        } else { return 72 }
        let font = Localizer.shared.font(size: Localizer.shared.isRTL ? 14.5 : 13.5)
        let width = max(tableView.bounds.width - 24, 120)
        let height = (value as NSString).boundingRect(
            with: NSSize(width: width, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: [.font: font]).height
        return max(72, ceil(height) + 42)
    }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?,
                   row: Int) -> NSView? {
        let identifier = NSUserInterfaceItemIdentifier(tableView === searchTable
            ? "quranSearchCell" : (tableView === pageTextTable ? "quranTextCell" : "quranWordCell"))
        let label = tableView.makeView(withIdentifier: identifier, owner: self) as? NSTextField
            ?? NSTextField(wrappingLabelWithString: "")
        label.identifier = identifier
        label.maximumNumberOfLines = 0
        label.lineBreakMode = .byWordWrapping
        label.baseWritingDirection = .rightToLeft
        label.alignment = .right
        label.textColor = .labelColor
        if tableView === searchTable || tableView === pageTextTable {
            let source = tableView === searchTable ? searchResults : currentPageVerses
            guard source.indices.contains(row) else { return nil }
            let verse = source[row]
            let reference = localizedInterfaceDigits("\(verse.suraNumber):\(verse.ayahNumber)")
            let page = localizedInterfaceDigits("\(offlineQuranText("page")) \(verse.pageLabel)")
            label.font = Localizer.shared.font(size: Localizer.shared.isRTL ? 14.5 : 13.5,
                                               weight: .medium)
            label.stringValue = "\(verse.suraNameArabic) · \(reference) · \(page)\n\(verse.uthmanicText)"
            label.setAccessibilityLabel("\(verse.suraNameArabic), \(reference), \(page), \(verse.uthmanicText)")
        } else {
            guard visibleMeanings.indices.contains(row) else { return nil }
            let meaning = visibleMeanings[row]
            let reference = localizedInterfaceDigits("\(meaning.suraName) \(meaning.ayahNumber)")
            label.font = Localizer.shared.font(size: Localizer.shared.isRTL ? 14.5 : 13.5)
            label.stringValue = "\(meaning.word) · \(reference)\n\(meaning.explanation)"
            label.setAccessibilityLabel(label.stringValue)
        }
        return label
    }

    func tableViewSelectionDidChange(_ notification: Notification) {
        guard let table = notification.object as? NSTableView,
              table === searchTable,
              searchResults.indices.contains(table.selectedRow) else { return }
        let verse = searchResults[table.selectedRow]
        selectedReference = verse
        goToPage(verse.pageStart, clearReference: false)
        updateVisibleMeanings()
    }

    private func loadBookmarks() -> [OfflineQuranBookmark] {
        migrateLegacyBookmarksIfNeeded()
        guard let data = UserDefaults.standard.data(forKey: kQuranBookmarksKey),
              let decoded = try? JSONDecoder().decode([OfflineQuranBookmark].self,
                                                       from: data) else { return [] }
        return decoded.compactMap { value in
            guard let edition = normalizedEdition(value.edition),
                  (1...604).contains(value.page) else { return nil }
            var normalized = value
            normalized.edition = edition
            return normalized
        }
    }

    private func migrateLegacyBookmarksIfNeeded() {
        let defaults = UserDefaults.standard
        guard !defaults.bool(forKey: kQuranBookmarkMigrationDone) else { return }
        defer { defaults.set(true, forKey: kQuranBookmarkMigrationDone) }
        guard let legacyData = defaults.data(forKey: kQuranLegacyBookmarksKey) else { return }
        if defaults.data(forKey: kQuranLegacyBookmarksBackup) == nil {
            defaults.set(legacyData, forKey: kQuranLegacyBookmarksBackup)
        }
        guard let legacy = try? JSONDecoder().decode([QuranBookmark].self,
                                                      from: legacyData) else {
            defaults.set(legacyData, forKey: kQuranUnsupportedBookmarks)
            return
        }
        var supported: [OfflineQuranBookmark] = []
        var unsupported: [QuranBookmark] = []
        for item in legacy {
            guard let edition = normalizedEdition(item.edition),
                  let page = recognizedLegacyPage(item.url, edition: edition) else {
                unsupported.append(item)
                continue
            }
            supported.append(OfflineQuranBookmark(id: item.id, title: item.title,
                                                   edition: edition, page: page,
                                                   createdAt: item.createdAt))
        }
        if defaults.data(forKey: kQuranBookmarksKey) == nil { saveBookmarks(supported) }
        if !unsupported.isEmpty, let data = try? JSONEncoder().encode(unsupported) {
            defaults.set(data, forKey: kQuranUnsupportedBookmarks)
        }
    }

    private func saveBookmarks(_ values: [OfflineQuranBookmark]) {
        guard let data = try? JSONEncoder().encode(values) else { return }
        UserDefaults.standard.set(data, forKey: kQuranBookmarksKey)
    }

    @objc private func addBookmark() {
        guard pdfView.document != nil else { return }
        let page = currentPageNumber
        let nearby = verses.first { $0.appears(on: page) }
        let suggested = nearby.map {
            "\($0.suraNameArabic) · " + localizedInterfaceDigits("\($0.suraNumber):\($0.ayahNumber)")
        } ?? "\(featureText("quran.bookmark")) · "
            + localizedInterfaceDigits("\(offlineQuranText("page")) \(page)")
        let alert = NSAlert()
        alert.messageText = featureText("quran.bookmark.add")
        alert.informativeText = featureText("quran.bookmark.name.help")
        alert.addButton(withTitle: t("settings.save"))
        alert.addButton(withTitle: t("adhkar.editor.cancel"))
        let field = NSTextField(frame: NSRect(x: 0, y: 0, width: 320, height: 24))
        field.stringValue = suggested
        alert.accessoryView = field
        guard alert.runModal() == .alertFirstButtonReturn else { return }
        let title = field.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        var values = loadBookmarks()
        if let index = values.firstIndex(where: { $0.edition == loadedEdition && $0.page == page }) {
            values[index].title = title.isEmpty ? suggested : title
        } else {
            values.append(OfflineQuranBookmark(title: title.isEmpty ? suggested : title,
                                               edition: loadedEdition, page: page))
        }
        saveBookmarks(values)
        updatePageState()
    }

    @objc private func showBookmarks(_ sender: NSButton) {
        let menu = NSMenu()
        let values = loadBookmarks().sorted { $0.createdAt > $1.createdAt }
        if values.isEmpty {
            let empty = NSMenuItem(title: featureText("quran.bookmarks.empty"),
                                   action: nil, keyEquivalent: "")
            empty.isEnabled = false
            menu.addItem(empty)
        } else {
            for (index, bookmark) in values.enumerated() {
                let page = localizedInterfaceDigits("\(offlineQuranText("page")) \(bookmark.page)")
                let item = NSMenuItem(title: "\(bookmark.title) · \(page)",
                                      action: #selector(openBookmark(_:)),
                                      keyEquivalent: "")
                item.tag = index
                item.representedObject = values
                item.image = templateSymbol(bookmark.edition == "warsh"
                                                ? "book.closed.fill" : "book.fill",
                                             pointSize: 11)
                menu.addItem(item)
            }
        }
        menu.popUp(positioning: nil, at: NSPoint(x: 0, y: sender.bounds.height + 4), in: sender)
    }

    @objc private func openBookmark(_ sender: NSMenuItem) {
        guard let values = sender.representedObject as? [OfflineQuranBookmark],
              values.indices.contains(sender.tag) else { return }
        let bookmark = values[sender.tag]
        let segment = bookmark.edition == "warsh" ? 1 : 0
        if editionControl.selectedSegment != segment {
            editionControl.selectedSegment = segment
            loadEdition(targetPage: bookmark.page)
        } else {
            goToPage(bookmark.page)
        }
    }

    @objc private func removeCurrentBookmark() {
        let page = currentPageNumber
        var values = loadBookmarks()
        values.removeAll { $0.edition == loadedEdition && $0.page == page }
        saveBookmarks(values)
        updatePageState()
    }

    @objc private func showProvenance() {
        let alert = NSAlert()
        alert.messageText = featureText("quran.provenance.title")
        alert.informativeText = offlineQuranText("provenance.detail")
            + "\n\nHafs PDF v2.0 · 604 pages\nSHA-256 c0d57c9f193e509272d17b9c5bbd6d6ca8077de15e1de6f775d8c7aca64d6406"
            + "\n\nWarsh PDF v2.1 · 604 pages\nSHA-256 b99cd519590bdc8036e54eae8589857cb4cc9c5dc8f303692de79725d93deb9e"
            + "\n\nMuyassar Ghareeb v0.1\nSHA-256 aa57282cff9517c8f7b74432b17077f70decb4eb1530ff78d4fb663f435cdc65"
            + "\n\n" + offlineQuranText("provenance.omitted")
        alert.addButton(withTitle: offlineQuranText("close"))
        alert.runModal()
    }
}

// ============================================================================
// MARK: Qur'an — Riwaq native verse reader
// ============================================================================

/// A translation is a human rendering of meanings, never Qur'an text. These
/// descriptors point only at immutable, versioned QuranEnc SQLite snapshots
/// copied into the app at build time. They are intentionally Hafs-only because
/// Warsh has different verse boundaries in 52 surahs.
private struct QuranTranslationDescriptor: Equatable {
    let key: String
    let languageCode: String
    let nativeLanguage: String
    let title: String
    let version: String
    let fileName: String
    let isRTL: Bool

    static let verified: [QuranTranslationDescriptor] = [
        .init(key: "english_rwwad", languageCode: "en", nativeLanguage: "English",
              title: "Rowwad Translation Center", version: "1.0.19",
              fileName: "english_rwwad_v1.0.19.sqlite", isRTL: false),
        .init(key: "french_rashid", languageCode: "fr", nativeLanguage: "Français",
              title: "Rachid Maach", version: "1.0.3",
              fileName: "french_rashid_v1.0.3.sqlite", isRTL: false),
        .init(key: "spanish_garcia", languageCode: "es", nativeLanguage: "Español",
              title: "Isa García", version: "1.0.2",
              fileName: "spanish_garcia_v1.0.2.sqlite", isRTL: false),
        .init(key: "portuguese_nasr", languageCode: "pt", nativeLanguage: "Português",
              title: "Helmi Nasr", version: "1.4.1",
              fileName: "portuguese_nasr_v1.4.1.sqlite", isRTL: false),
        .init(key: "chinese_suliman", languageCode: "zh", nativeLanguage: "中文",
              title: "Muhammad Suleiman", version: "1.0.8",
              fileName: "chinese_suliman_v1.0.8.sqlite", isRTL: false),
        .init(key: "urdu_junagarhi", languageCode: "ur", nativeLanguage: "اردو",
              title: "Muhammad Junagarhi", version: "1.1.3",
              fileName: "urdu_junagarhi_v1.1.3.sqlite", isRTL: true),
        .init(key: "hindi_omari", languageCode: "hi", nativeLanguage: "हिन्दी",
              title: "Azizul Haq Al-Omari", version: "1.1.5",
              fileName: "hindi_omari_v1.1.5.sqlite", isRTL: false),
    ]

    static var preferred: QuranTranslationDescriptor {
        let saved = UserDefaults.standard.string(forKey: kQuranTranslationKey)
        if let value = verified.first(where: { $0.key == saved }) { return value }
        let code = Localizer.shared.current.code
        return verified.first(where: { $0.languageCode == code }) ?? verified[0]
    }
}

private struct QuranTranslationVerse {
    let text: String
    let footnotes: String
}

private enum QuranReaderPalette: Int, CaseIterable {
    case ivory = 0, sage, night

    var background: NSColor {
        switch self {
        case .ivory: return NSColor(red: 0.965, green: 0.944, blue: 0.885, alpha: 1)
        case .sage: return NSColor(red: 0.875, green: 0.914, blue: 0.872, alpha: 1)
        case .night: return NSColor(red: 0.055, green: 0.071, blue: 0.075, alpha: 1)
        }
    }
    var surface: NSColor {
        switch self {
        case .ivory: return NSColor(red: 0.995, green: 0.982, blue: 0.945, alpha: 0.94)
        case .sage: return NSColor(red: 0.945, green: 0.969, blue: 0.939, alpha: 0.94)
        case .night: return NSColor(red: 0.095, green: 0.119, blue: 0.122, alpha: 0.96)
        }
    }
    var primary: NSColor {
        self == .night ? NSColor(red: 0.94, green: 0.92, blue: 0.84, alpha: 1)
                       : NSColor(red: 0.12, green: 0.16, blue: 0.13, alpha: 1)
    }
    var secondary: NSColor {
        self == .night ? NSColor(red: 0.68, green: 0.73, blue: 0.69, alpha: 1)
                       : NSColor(red: 0.36, green: 0.40, blue: 0.36, alpha: 1)
    }
    var motif: NSColor {
        switch self {
        case .ivory: return NSColor(red: 0.53, green: 0.36, blue: 0.13, alpha: 0.12)
        case .sage: return NSColor(red: 0.10, green: 0.35, blue: 0.24, alpha: 0.12)
        case .night: return NSColor(red: 0.79, green: 0.61, blue: 0.28, alpha: 0.13)
        }
    }
    var divider: NSColor { motif.withAlphaComponent(0.34) }
}

private enum QuranReaderLayout: Int, CaseIterable {
    case flow = 0, study, focus
}

private let quranReaderEnglish: [String: String] = [
    "translation": "Translation of meanings", "show.translation": "Show translation",
    "hafs.only": "Translations of meanings use Hafs verse boundaries and are unavailable in Warsh.",
    "surah": "Surah", "search": "Search Arabic or enter 2:255",
    "background": "Background", "reading.style": "Reading style",
    "flow": "Flow", "study": "Study", "focus": "Focus",
    "ivory": "Ivory", "sage": "Sage", "night": "Night",
    "smaller": "Smaller Qur'an text", "larger": "Larger Qur'an text",
    "previous": "Previous verse", "next": "Next verse",
    "bookmark.add": "Bookmark verse", "bookmarks": "Bookmarks",
    "source": "Verified offline source", "notes": "Translation notes",
    "word.meanings": "Verified Arabic word meanings", "word.meanings.none": "No word meanings on this page",
    "no.results": "No matching verses", "verses": "%@ verses",
    "exact.hafs": "Hafs · exact KFGQPC Uthmanic text",
    "exact.warsh": "Warsh · exact KFGQPC Uthmanic text",
    "offline": "Offline", "close": "Close", "unavailable": "Verified reader unavailable",
    "unavailable.detail": "A required verified Qur'an text or font resource is unavailable. Rebuild the app to restore it.",
]

private let quranReaderArabic: [String: String] = [
    "translation": "ترجمة معاني القرآن", "show.translation": "إظهار الترجمة",
    "hafs.only": "ترجمات المعاني مرتبطة بترقيم حفص، لذلك لا تُعرض مع رواية ورش.",
    "surah": "السورة", "search": "ابحث في النص العربي أو اكتب ٢:٢٥٥",
    "background": "الخلفية", "reading.style": "نمط القراءة",
    "flow": "متتابع", "study": "تدبّر", "focus": "تركيز",
    "ivory": "عاجي", "sage": "أخضر هادئ", "night": "ليلي",
    "smaller": "تصغير نص القرآن", "larger": "تكبير نص القرآن",
    "previous": "الآية السابقة", "next": "الآية التالية",
    "bookmark.add": "حفظ الآية", "bookmarks": "العلامات",
    "source": "مصدر موثّق دون اتصال", "notes": "حواشي الترجمة",
    "word.meanings": "معاني غريب القرآن الموثّقة", "word.meanings.none": "لا توجد معاني كلمات في هذه الصفحة",
    "no.results": "لا توجد آيات مطابقة", "verses": "%@ آية",
    "exact.hafs": "حفص · نص عثماني مطابق لمجمع الملك فهد",
    "exact.warsh": "ورش · نص عثماني مطابق لمجمع الملك فهد",
    "offline": "دون اتصال", "close": "إغلاق", "unavailable": "القارئ الموثّق غير متاح",
    "unavailable.detail": "أحد موارد نص القرآن أو خطه الموثّق مفقود. أعد بناء التطبيق لاستعادته.",
]

private func quranReaderText(_ key: String) -> String {
    let code = Localizer.shared.current.code
    let localized: [String: [String: String]] = [
        "fr": ["translation":"Traduction des sens", "show.translation":"Afficher la traduction",
               "surah":"Sourate", "search":"Rechercher en arabe ou saisir 2:255",
               "background":"Arrière-plan", "reading.style":"Style de lecture",
               "flow":"Continu", "study":"Étude", "focus":"Focus",
               "ivory":"Ivoire", "sage":"Sauge", "night":"Nuit",
               "no.results":"Aucun verset correspondant", "offline":"Hors ligne"],
        "es": ["translation":"Traducción de los significados", "show.translation":"Mostrar traducción",
               "surah":"Sura", "search":"Buscar en árabe o escribir 2:255",
               "background":"Fondo", "reading.style":"Estilo de lectura",
               "flow":"Flujo", "study":"Estudio", "focus":"Enfoque",
               "ivory":"Marfil", "sage":"Salvia", "night":"Noche",
               "no.results":"No hay aleyas coincidentes", "offline":"Sin conexión"],
        "pt": ["translation":"Tradução dos significados", "show.translation":"Mostrar tradução",
               "surah":"Surata", "search":"Pesquisar em árabe ou escrever 2:255",
               "background":"Fundo", "reading.style":"Estilo de leitura",
               "flow":"Fluxo", "study":"Estudo", "focus":"Foco",
               "ivory":"Marfim", "sage":"Sálvia", "night":"Noite",
               "no.results":"Nenhum versículo encontrado", "offline":"Offline"],
        "zh": ["translation":"经义翻译", "show.translation":"显示翻译", "surah":"章",
               "search":"搜索阿拉伯文或输入 2:255", "background":"背景", "reading.style":"阅读样式",
               "flow":"连读", "study":"研读", "focus":"专注", "ivory":"象牙",
               "sage":"鼠尾草", "night":"夜间", "no.results":"没有匹配的经文", "offline":"离线"],
        "hi": ["translation":"अर्थों का अनुवाद", "show.translation":"अनुवाद दिखाएँ",
               "surah":"सूरह", "background":"पृष्ठभूमि", "reading.style":"पठन शैली",
               "flow":"प्रवाह", "study":"अध्ययन", "focus":"फ़ोकस", "ivory":"आइवरी",
               "sage":"सेज", "night":"रात्रि", "no.results":"कोई मिलती आयत नहीं", "offline":"ऑफ़लाइन"],
        "ur": ["translation":"معانی کا ترجمہ", "show.translation":"ترجمہ دکھائیں", "surah":"سورت",
               "background":"پس منظر", "reading.style":"مطالعہ کا انداز", "flow":"تسلسل",
               "study":"مطالعہ", "focus":"توجہ", "ivory":"عاجی", "sage":"سبز",
               "night":"رات", "no.results":"کوئی مماثل آیت نہیں", "offline":"آف لائن"],
        "ru": ["translation":"Перевод смыслов", "show.translation":"Показать перевод",
               "surah":"Сура", "background":"Фон", "reading.style":"Режим чтения",
               "flow":"Поток", "study":"Изучение", "focus":"Фокус",
               "ivory":"Слоновая кость", "sage":"Шалфей", "night":"Ночь",
               "no.results":"Совпадающих аятов нет", "offline":"Офлайн"],
        "bn": ["translation":"অর্থের অনুবাদ", "show.translation":"অনুবাদ দেখান",
               "surah":"সূরা", "background":"পটভূমি", "reading.style":"পাঠের ধরন",
               "flow":"প্রবাহ", "study":"অধ্যয়ন", "focus":"মনোযোগ",
               "ivory":"আইভরি", "sage":"সবুজ", "night":"রাত",
               "no.results":"মিল থাকা আয়াত নেই", "offline":"অফলাইন"],
    ]
    let raw = (code == "ar" ? quranReaderArabic[key] : localized[code]?[key])
        ?? quranReaderEnglish[key] ?? key
    return applyingArabicDigitPreference(raw, languageCode: code)
}

private var quranFontNames: [String: [String]] = [:]

/// Registers only fonts bundled below Quran/Fonts. The PostScript name is read
/// from the verified file instead of guessed, so publisher renames cannot make
/// the reader silently fall back to an unrelated Arabic font.
private func registerVerifiedQuranFonts() {
    guard quranFontNames.isEmpty,
          let root = Bundle.main.resourceURL?.appendingPathComponent("Quran/Fonts")
    else { return }
    let manager = FileManager.default
    guard let enumerator = manager.enumerator(at: root,
                                               includingPropertiesForKeys: nil)
    else { return }
    for case let url as URL in enumerator where ["ttf", "otf"].contains(url.pathExtension.lowercased()) {
        CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
        guard let descriptors = CTFontManagerCreateFontDescriptorsFromURL(url as CFURL) as? [CTFontDescriptor]
        else { continue }
        let edition = url.path.lowercased().contains("warsh") ? "warsh" : "hafs"
        for descriptor in descriptors {
            if let name = CTFontDescriptorCopyAttribute(descriptor, kCTFontNameAttribute) as? String {
                quranFontNames[edition, default: []].append(name)
            }
        }
    }
}

private func verifiedQuranFont(edition: String, size: CGFloat) -> NSFont? {
    registerVerifiedQuranFonts()
    for name in quranFontNames[edition] ?? [] {
        if let font = NSFont(name: name, size: size) { return font }
    }
    return nil
}

private func quranTranslationURL(_ descriptor: QuranTranslationDescriptor) -> URL? {
    let value = Bundle.main.resourceURL?
        .appendingPathComponent("Quran/Translations/QuranEnc")
        .appendingPathComponent(descriptor.fileName)
    guard let value, FileManager.default.fileExists(atPath: value.path) else { return nil }
    return value
}

/// Opens the publisher snapshot read-only and fails closed unless the complete
/// Hafs key space is present. No SQL ever changes the bundled database.
private func loadQuranTranslation(_ descriptor: QuranTranslationDescriptor) throws
    -> [String: QuranTranslationVerse] {
    guard let url = quranTranslationURL(descriptor) else {
        throw NSError(domain: "SalatTime.Quran", code: 20,
                      userInfo: [NSLocalizedDescriptionKey: "Missing translation snapshot"])
    }
    var database: OpaquePointer?
    guard sqlite3_open_v2(url.path, &database, SQLITE_OPEN_READONLY | SQLITE_OPEN_NOMUTEX,
                          nil) == SQLITE_OK, let database else {
        throw NSError(domain: "SalatTime.Quran", code: 21,
                      userInfo: [NSLocalizedDescriptionKey: "Unreadable translation snapshot"])
    }
    defer { sqlite3_close(database) }
    var statement: OpaquePointer?
    let sql = "SELECT sura, aya, translation, COALESCE(footnotes, '') FROM translations ORDER BY sura, aya"
    guard sqlite3_prepare_v2(database, sql, -1, &statement, nil) == SQLITE_OK,
          let statement else {
        throw NSError(domain: "SalatTime.Quran", code: 22,
                      userInfo: [NSLocalizedDescriptionKey: "Invalid translation schema"])
    }
    defer { sqlite3_finalize(statement) }
    var result: [String: QuranTranslationVerse] = [:]
    while sqlite3_step(statement) == SQLITE_ROW {
        let sura = Int(sqlite3_column_int(statement, 0))
        let ayah = Int(sqlite3_column_int(statement, 1))
        guard let rawText = sqlite3_column_text(statement, 2) else { continue }
        let text = String(cString: rawText)
        let notes = sqlite3_column_text(statement, 3).map { String(cString: $0) } ?? ""
        guard (1...114).contains(sura), ayah > 0, !text.isEmpty else { continue }
        result["\(sura):\(ayah)"] = QuranTranslationVerse(text: text, footnotes: notes)
    }
    guard result.count == 6_236 else {
        throw NSError(domain: "SalatTime.Quran", code: 23,
                      userInfo: [NSLocalizedDescriptionKey: "Incomplete translation snapshot"])
    }
    return result
}

private final class QuranReadingBackdropView: NSView {
    var palette: QuranReaderPalette = .ivory { didSet { needsDisplay = true } }
    override var isFlipped: Bool { true }
    override func draw(_ dirtyRect: NSRect) {
        palette.background.setFill()
        bounds.fill()
        let top = palette.surface.withAlphaComponent(palette == .night ? 0.18 : 0.30)
        NSGradient(starting: top, ending: palette.background)?.draw(in: bounds, angle: 90)
        palette.motif.setStroke()
        for y in stride(from: CGFloat(54), through: bounds.height, by: 104) {
            for x in [CGFloat(30), bounds.width - 30] {
                let path = zelligeStarPath(center: NSPoint(x: x, y: y), outer: 18, inner: 8)
                path.lineWidth = 0.8
                path.stroke()
            }
        }
    }
}

private final class QuranReaderHeroView: NSView {
    let titleLabel = NSTextField(labelWithString: "")
    let subtitleLabel = NSTextField(labelWithString: "")
    let progressLabel = NSTextField(labelWithString: "")
    var palette: QuranReaderPalette = .ivory { didSet { updateColors(); needsDisplay = true } }
    override var isFlipped: Bool { true }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        titleLabel.font = Localizer.shared.font(size: 25, weight: .bold)
        titleLabel.alignment = .center
        titleLabel.maximumNumberOfLines = 1
        subtitleLabel.font = Localizer.shared.font(size: 12, weight: .medium)
        subtitleLabel.alignment = .center
        progressLabel.font = NSFont.monospacedDigitSystemFont(ofSize: 11, weight: .medium)
        progressLabel.alignment = .center
        for label in [titleLabel, subtitleLabel, progressLabel] {
            label.translatesAutoresizingMaskIntoConstraints = false
            addSubview(label)
        }
        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: topAnchor, constant: 20),
            titleLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 72),
            titleLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -72),
            subtitleLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 5),
            subtitleLabel.centerXAnchor.constraint(equalTo: centerXAnchor),
            progressLabel.topAnchor.constraint(equalTo: subtitleLabel.bottomAnchor, constant: 7),
            progressLabel.centerXAnchor.constraint(equalTo: centerXAnchor),
        ])
        updateColors()
    }
    required init?(coder: NSCoder) { fatalError() }

    private func updateColors() {
        titleLabel.textColor = palette.primary
        subtitleLabel.textColor = palette.secondary
        progressLabel.textColor = .appGreenAccent
    }

    override func draw(_ dirtyRect: NSRect) {
        let rect = bounds.insetBy(dx: 1, dy: 1)
        let path = NSBezierPath(roundedRect: rect, xRadius: 20, yRadius: 20)
        palette.surface.setFill()
        path.fill()
        palette.divider.setStroke()
        path.lineWidth = NSWorkspace.shared.accessibilityDisplayShouldIncreaseContrast ? 1.5 : 0.8
        path.stroke()
        palette.motif.setStroke()
        for x in [CGFloat(38), bounds.width - 38] {
            let motif = zelligeStarPath(center: NSPoint(x: x, y: bounds.midY), outer: 20, inner: 9)
            motif.lineWidth = 1
            motif.stroke()
        }
    }
}

private final class QuranVerseNumberView: NSView {
    var value = "" { didSet { needsDisplay = true; setAccessibilityLabel(value) } }
    var palette: QuranReaderPalette = .ivory { didSet { needsDisplay = true } }
    override var isFlipped: Bool { true }
    override func draw(_ dirtyRect: NSRect) {
        let rect = bounds.insetBy(dx: 5, dy: 5)
        let outer = NSBezierPath(ovalIn: rect)
        palette.motif.withAlphaComponent(0.95).setFill()
        outer.fill()
        palette.divider.withAlphaComponent(0.9).setStroke()
        outer.lineWidth = 1
        outer.stroke()
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .center
        NSAttributedString(string: value, attributes: [
            .font: NSFont.monospacedDigitSystemFont(ofSize: 11, weight: .semibold),
            .foregroundColor: palette.primary, .paragraphStyle: paragraph,
        ]).draw(in: NSRect(x: 2, y: bounds.midY - 7, width: bounds.width - 4, height: 16))
    }
}

private final class QuranVerseRowView: NSTableCellView {
    private let surahHeader = NSTextField(labelWithString: "")
    private let arabicLabel = NSTextField(wrappingLabelWithString: "")
    private let translationLabel = NSTextField(wrappingLabelWithString: "")
    private let referenceLabel = NSTextField(labelWithString: "")
    private let numberView = QuranVerseNumberView()
    private let bookmarkImage = NSImageView()
    private var notesButton: HoverIconButton!
    private var notesHandler: (() -> Void)?
    private var palette: QuranReaderPalette = .ivory
    private var layoutMode: QuranReaderLayout = .flow
    private var isSurahStart = false
    override var isFlipped: Bool { true }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        surahHeader.alignment = .center
        surahHeader.maximumNumberOfLines = 1
        arabicLabel.maximumNumberOfLines = 0
        arabicLabel.isSelectable = true
        arabicLabel.baseWritingDirection = .rightToLeft
        translationLabel.maximumNumberOfLines = 0
        translationLabel.isSelectable = true
        referenceLabel.font = NSFont.monospacedDigitSystemFont(ofSize: 10.5, weight: .medium)
        notesButton = HoverIconButton(symbol: "text.bubble", toolTip: quranReaderText("notes"),
                                      target: self, action: #selector(showNotes(_:)),
                                      pointSize: 13, size: NSSize(width: 44, height: 44))
        bookmarkImage.image = templateSymbol("bookmark.fill", pointSize: 11, weight: .semibold)
        bookmarkImage.contentTintColor = .appGreenAccent
        for child in [surahHeader, arabicLabel, translationLabel, referenceLabel,
                      numberView, notesButton as NSView, bookmarkImage] {
            addSubview(child)
        }
        setAccessibilityElement(true)
        setAccessibilityRole(.group)
    }
    required init?(coder: NSCoder) { fatalError() }

    func configure(verse: OfflineQuranVerse,
                   translation: QuranTranslationVerse?,
                   descriptor: QuranTranslationDescriptor?,
                   palette: QuranReaderPalette,
                   layout: QuranReaderLayout,
                   textScale: CGFloat,
                   isSurahStart: Bool,
                   isBookmarked: Bool,
                   officialFont: NSFont?,
                   onNotes: @escaping () -> Void) {
        self.palette = palette
        self.layoutMode = layout
        self.isSurahStart = isSurahStart
        self.notesHandler = onNotes
        surahHeader.stringValue = Localizer.shared.isRTL
            ? verse.suraNameArabic : "\(verse.suraNameArabic)  ·  \(verse.suraNameEnglish)"
        surahHeader.font = Localizer.shared.font(size: 18, weight: .bold)
        // With the publisher font present, the terminal KFG ayah marker is
        // rendered exactly. The build is expected to bundle that verified font.
        // A tightly-scoped fallback removes only the presentation marker and
        // draws the separate, source-provided ayah number medallion.
        let hasOfficialFont = officialFont != nil
        let renderedArabic: String
        if hasOfficialFont {
            renderedArabic = verse.uthmanicText
        } else {
            renderedArabic = verse.uthmanicText.unicodeScalars
                .filter { !(0xFC00...0xFDFF).contains($0.value) }
                .map(String.init).joined()
                .trimmingCharacters(in: .whitespacesAndNewlines)
        }
        arabicLabel.stringValue = renderedArabic
        arabicLabel.font = officialFont ?? NSFont(name: "Geeza Pro", size: 30 * textScale)
            ?? Localizer.shared.font(size: 30 * textScale)
        arabicLabel.alignment = layout == .focus ? .center : .right
        arabicLabel.textColor = palette.primary
        let arabicParagraph = NSMutableParagraphStyle()
        arabicParagraph.alignment = arabicLabel.alignment
        arabicParagraph.baseWritingDirection = .rightToLeft
        arabicParagraph.lineBreakMode = .byWordWrapping
        arabicParagraph.lineSpacing = layout == .flow ? 8 : 12
        arabicLabel.attributedStringValue = NSAttributedString(string: renderedArabic, attributes: [
            .font: arabicLabel.font!, .foregroundColor: palette.primary,
            .paragraphStyle: arabicParagraph,
        ])

        translationLabel.stringValue = translation?.text ?? ""
        translationLabel.isHidden = translation == nil
        translationLabel.font = Localizer.shared.font(size: 14.5 * min(1.2, textScale), weight: .regular)
        translationLabel.textColor = palette.secondary
        translationLabel.baseWritingDirection = descriptor?.isRTL == true ? .rightToLeft : .leftToRight
        translationLabel.alignment = layout == .focus ? .center
            : (descriptor?.isRTL == true ? .right : .left)
        referenceLabel.stringValue = "\(localizedInterfaceDigits(String(verse.suraNumber))):\(localizedInterfaceDigits(String(verse.ayahNumber)))  ·  Juz \(localizedInterfaceDigits(String(verse.jozz)))"
        referenceLabel.textColor = palette.secondary
        numberView.value = localizedInterfaceDigits(String(verse.ayahNumber))
        numberView.palette = palette
        bookmarkImage.isHidden = !isBookmarked
        notesButton.isHidden = translation?.footnotes.isEmpty != false
        notesButton.setAccessibilityLabel(quranReaderText("notes"))
        surahHeader.isHidden = !isSurahStart
        setAccessibilityLabel("\(verse.suraNameEnglish), \(verse.ayahNumber)")
        setAccessibilityHelp(quranReaderText("source"))
        needsLayout = true
        needsDisplay = true
    }

    @objc private func showNotes(_ sender: Any?) { notesHandler?() }

    override func layout() {
        super.layout()
        let inset: CGFloat = layoutMode == .flow ? 30 : 42
        var top: CGFloat = 14
        if isSurahStart {
            surahHeader.frame = NSRect(x: inset, y: top, width: bounds.width - inset * 2,
                                       height: 28)
            top += 45
        }
        let numberX = Localizer.shared.isRTL ? bounds.width - inset - 44 : inset
        numberView.frame = NSRect(x: numberX, y: top, width: 44, height: 44)
        let contentX = Localizer.shared.isRTL ? inset : inset + 56
        let contentRight = Localizer.shared.isRTL ? inset + 56 : inset
        let contentWidth = max(260, bounds.width - contentX - contentRight)
        let arabicHeight = localizedTextHeight(arabicLabel.stringValue,
                                               font: arabicLabel.font!,
                                               width: contentWidth,
                                               maximumLines: 0) + 16
        arabicLabel.frame = NSRect(x: contentX, y: top,
                                   width: contentWidth, height: arabicHeight)
        top += arabicHeight + 8
        if !translationLabel.isHidden {
            let translationHeight = localizedTextHeight(translationLabel.stringValue,
                                                         font: translationLabel.font!,
                                                         width: contentWidth,
                                                         maximumLines: 0) + 8
            translationLabel.frame = NSRect(x: contentX, y: top,
                                             width: contentWidth, height: translationHeight)
            top += translationHeight + 8
        }
        referenceLabel.frame = NSRect(x: contentX, y: bounds.height - 33,
                                      width: min(210, contentWidth), height: 18)
        bookmarkImage.frame = NSRect(x: bounds.width - inset - 18, y: bounds.height - 32,
                                     width: 14, height: 14)
        notesButton.frame = NSRect(x: Localizer.shared.isRTL ? inset : bounds.width - inset - 44,
                                   y: bounds.height - 46, width: 44, height: 44)
    }

    override func draw(_ dirtyRect: NSRect) {
        if layoutMode != .flow {
            let rect = bounds.insetBy(dx: 14, dy: 5)
            let path = NSBezierPath(roundedRect: rect, xRadius: 18, yRadius: 18)
            palette.surface.setFill()
            path.fill()
            palette.divider.setStroke()
            path.lineWidth = 0.8
            path.stroke()
        } else {
            palette.divider.setStroke()
            let line = NSBezierPath()
            line.move(to: NSPoint(x: 30, y: bounds.maxY - 1))
            line.line(to: NSPoint(x: bounds.width - 30, y: bounds.maxY - 1))
            line.lineWidth = 0.7
            line.stroke()
        }
    }
}

/// Modern native reader driven exclusively by the verified KFG JSON corpus.
/// PDF assets remain bundled for independent audit, but no PDFView or network
/// content is part of this surface.
final class QuranViewController: NSViewController, MainTabContent,
                                 NSTableViewDataSource, NSTableViewDelegate,
                                 NSSearchFieldDelegate {
    private var backdrop: QuranReadingBackdropView!
    private var header: NSVisualEffectView!
    private var hero: QuranReaderHeroView!
    private var editionControl: NSSegmentedControl!
    private var surahPopup: NSPopUpButton!
    private var searchField: NSSearchField!
    private var translationSwitch: NSSwitch!
    private var translationPopup: NSPopUpButton!
    private var palettePopup: NSPopUpButton!
    private var layoutPopup: NSPopUpButton!
    private var tableView: NSTableView!
    private var scrollView: NSScrollView!
    private var sourceLabel: NSTextField!
    private var unavailableOverlay: NSVisualEffectView!
    private var unavailableTitle: NSTextField!
    private var unavailableDetail: NSTextField!
    private var previousButton: HoverIconButton!
    private var nextButton: HoverIconButton!
    private var bookmarkButton: HoverIconButton!
    private var bookmarksButton: HoverIconButton!
    private var provenanceButton: HoverIconButton!
    private var meaningsButton: HoverIconButton!

    private var verses: [OfflineQuranVerse] = []
    private var surahVerses: [Int: [OfflineQuranVerse]] = [:]
    private var visibleVerses: [OfflineQuranVerse] = []
    private var translations: [String: QuranTranslationVerse] = [:]
    private var wordMeanings: [OfflineQuranWordMeaning] = []
    private var selectedSurah = max(1, min(114,
        UserDefaults.standard.integer(forKey: kQuranReaderSurah) == 0
            ? 1 : UserDefaults.standard.integer(forKey: kQuranReaderSurah)))
    private var selectedAyah = max(1, UserDefaults.standard.integer(forKey: kQuranReaderAyah))
    private var searchGeneration = UUID()
    private var translationGeneration = UUID()
    private var loadGeneration = UUID()
    private var searchActive = false
    private var currentWidth: CGFloat = 0
    private var bookmarks: [OfflineQuranBookmark] = []
    private var bookmarkMenuItems: [Int: OfflineQuranBookmark] = [:]
    private var currentTranslation = QuranTranslationDescriptor.preferred

    private var edition: String { editionControl?.selectedSegment == 1 ? "warsh" : "hafs" }
    private var palette: QuranReaderPalette {
        QuranReaderPalette(rawValue: palettePopup?.indexOfSelectedItem
                           ?? UserDefaults.standard.integer(forKey: kQuranReaderPalette)) ?? .ivory
    }
    private var readerLayout: QuranReaderLayout {
        QuranReaderLayout(rawValue: layoutPopup?.indexOfSelectedItem
                          ?? UserDefaults.standard.integer(forKey: kQuranReaderLayout)) ?? .flow
    }
    private var textScale: CGFloat {
        let saved = UserDefaults.standard.double(forKey: kQuranReaderTextScale)
        return CGFloat(saved == 0 ? 1 : max(0.78, min(1.55, saved)))
    }
    private var wantsTranslation: Bool {
        translationSwitch?.state == .on && edition == "hafs"
    }

    override func loadView() {
        registerVerifiedQuranFonts()
        bookmarks = loadBookmarks()
        let root = NSView()
        root.userInterfaceLayoutDirection = Localizer.shared.isRTL ? .rightToLeft : .leftToRight

        backdrop = QuranReadingBackdropView()
        backdrop.translatesAutoresizingMaskIntoConstraints = false
        root.addSubview(backdrop)

        header = NSVisualEffectView()
        header.material = .headerView
        header.blendingMode = .withinWindow
        header.state = .active
        header.translatesAutoresizingMaskIntoConstraints = false
        root.addSubview(header)

        editionControl = NSSegmentedControl(labels: ["Hafs", "Warsh"], trackingMode: .selectOne,
                                             target: self, action: #selector(editionChanged(_:)))
        editionControl.segmentStyle = .texturedRounded
        editionControl.selectedSegment = (UserDefaults.standard.string(forKey: kQuranEditionKey)
                                          ?? "hafs") == "warsh" ? 1 : 0
        editionControl.setAccessibilityLabel(featureText("quran.tab"))

        surahPopup = NSPopUpButton(frame: .zero, pullsDown: false)
        surahPopup.target = self
        surahPopup.action = #selector(surahChanged(_:))
        surahPopup.setAccessibilityLabel(quranReaderText("surah"))

        previousButton = HoverIconButton(symbol: Localizer.shared.isRTL ? "chevron.right" : "chevron.left",
                                         toolTip: quranReaderText("previous"), target: self,
                                         action: #selector(previousVerse(_:)), pointSize: 14,
                                         size: NSSize(width: 44, height: 44))
        nextButton = HoverIconButton(symbol: Localizer.shared.isRTL ? "chevron.left" : "chevron.right",
                                     toolTip: quranReaderText("next"), target: self,
                                     action: #selector(nextVerse(_:)), pointSize: 14,
                                     size: NSSize(width: 44, height: 44))
        searchField = NSSearchField()
        searchField.placeholderString = quranReaderText("search")
        searchField.delegate = self
        searchField.sendsWholeSearchString = true
        searchField.target = self
        searchField.action = #selector(searchChanged(_:))

        bookmarkButton = HoverIconButton(symbol: "bookmark", toolTip: quranReaderText("bookmark.add"),
                                         target: self, action: #selector(toggleBookmark(_:)),
                                         pointSize: 14, size: NSSize(width: 44, height: 44))
        bookmarksButton = HoverIconButton(symbol: "books.vertical", toolTip: quranReaderText("bookmarks"),
                                          target: self, action: #selector(showBookmarks(_:)),
                                          pointSize: 14, size: NSSize(width: 44, height: 44))
        provenanceButton = HoverIconButton(symbol: "checkmark.seal", toolTip: quranReaderText("source"),
                                           target: self, action: #selector(showProvenance(_:)),
                                           pointSize: 14, size: NSSize(width: 44, height: 44))
        meaningsButton = HoverIconButton(symbol: "character.book.closed",
                                         toolTip: quranReaderText("word.meanings"),
                                         target: self, action: #selector(showWordMeanings(_:)),
                                         pointSize: 14, size: NSSize(width: 44, height: 44))
        meaningsButton.setAccessibilityLabel(quranReaderText("word.meanings"))

        translationSwitch = NSSwitch()
        translationSwitch.state = (UserDefaults.standard.object(forKey: kQuranTranslationVisible)
                                   as? Bool ?? false) ? .on : .off
        translationSwitch.target = self
        translationSwitch.action = #selector(translationVisibilityChanged(_:))
        translationSwitch.setAccessibilityLabel(quranReaderText("show.translation"))
        let translationLabel = NSTextField(labelWithString: quranReaderText("show.translation"))
        translationLabel.font = Localizer.shared.font(size: 12, weight: .medium)

        translationPopup = NSPopUpButton(frame: .zero, pullsDown: false)
        for descriptor in QuranTranslationDescriptor.verified {
            translationPopup.addItem(withTitle: "\(descriptor.nativeLanguage) · \(descriptor.title) · v\(descriptor.version)")
        }
        translationPopup.selectItem(at: QuranTranslationDescriptor.verified.firstIndex(of: currentTranslation) ?? 0)
        translationPopup.target = self
        translationPopup.action = #selector(translationChanged(_:))
        translationPopup.setAccessibilityLabel(quranReaderText("translation"))

        palettePopup = NSPopUpButton(frame: .zero, pullsDown: false)
        palettePopup.addItems(withTitles: [quranReaderText("ivory"), quranReaderText("sage"),
                                            quranReaderText("night")])
        palettePopup.selectItem(at: max(0, min(2,
            UserDefaults.standard.integer(forKey: kQuranReaderPalette))))
        palettePopup.target = self
        palettePopup.action = #selector(paletteChanged(_:))
        palettePopup.setAccessibilityLabel(quranReaderText("background"))

        layoutPopup = NSPopUpButton(frame: .zero, pullsDown: false)
        layoutPopup.addItems(withTitles: [quranReaderText("flow"), quranReaderText("study"),
                                           quranReaderText("focus")])
        layoutPopup.selectItem(at: max(0, min(2,
            UserDefaults.standard.integer(forKey: kQuranReaderLayout))))
        layoutPopup.target = self
        layoutPopup.action = #selector(layoutChanged(_:))
        layoutPopup.setAccessibilityLabel(quranReaderText("reading.style"))

        let smaller = HoverIconButton(symbol: "textformat.size.smaller", toolTip: quranReaderText("smaller"),
                                      target: self, action: #selector(decreaseText(_:)), pointSize: 14,
                                      size: NSSize(width: 44, height: 44))
        let larger = HoverIconButton(symbol: "textformat.size.larger", toolTip: quranReaderText("larger"),
                                     target: self, action: #selector(increaseText(_:)), pointSize: 14,
                                     size: NSSize(width: 44, height: 44))
        sourceLabel = NSTextField(labelWithString: "")
        sourceLabel.font = Localizer.shared.font(size: 10.5, weight: .medium)
        sourceLabel.textColor = .secondaryLabelColor
        sourceLabel.lineBreakMode = .byTruncatingMiddle
        sourceLabel.setAccessibilityLabel(quranReaderText("source"))

        let rowOne = NSStackView(views: [editionControl, surahPopup, previousButton, nextButton,
                                          searchField, bookmarkButton, bookmarksButton,
                                          meaningsButton, provenanceButton])
        rowOne.orientation = .horizontal
        rowOne.alignment = .centerY
        rowOne.spacing = 8
        rowOne.userInterfaceLayoutDirection = root.userInterfaceLayoutDirection
        let rowTwo = NSStackView(views: [translationLabel, translationSwitch, translationPopup,
                                          sourceLabel, palettePopup, layoutPopup, smaller, larger])
        rowTwo.orientation = .horizontal
        rowTwo.alignment = .centerY
        rowTwo.spacing = 8
        rowTwo.userInterfaceLayoutDirection = root.userInterfaceLayoutDirection
        let controls = NSStackView(views: [rowOne, rowTwo])
        controls.orientation = .vertical
        controls.alignment = .leading
        controls.spacing = 7
        controls.translatesAutoresizingMaskIntoConstraints = false
        header.addSubview(controls)

        hero = QuranReaderHeroView()
        hero.translatesAutoresizingMaskIntoConstraints = false
        backdrop.addSubview(hero)

        tableView = NSTableView()
        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("verse"))
        column.resizingMask = .autoresizingMask
        tableView.addTableColumn(column)
        tableView.headerView = nil
        tableView.backgroundColor = .clear
        tableView.selectionHighlightStyle = .none
        tableView.intercellSpacing = .zero
        tableView.dataSource = self
        tableView.delegate = self
        tableView.rowHeight = 180
        tableView.usesAutomaticRowHeights = false
        tableView.setAccessibilityLabel(featureText("quran.reader"))
        scrollView = NSScrollView()
        scrollView.documentView = tableView
        scrollView.drawsBackground = false
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        backdrop.addSubview(scrollView)

        unavailableOverlay = NSVisualEffectView()
        unavailableOverlay.material = .popover
        unavailableOverlay.blendingMode = .withinWindow
        unavailableOverlay.state = .active
        unavailableOverlay.wantsLayer = true
        unavailableOverlay.layer?.cornerRadius = 18
        unavailableOverlay.translatesAutoresizingMaskIntoConstraints = false
        unavailableOverlay.isHidden = true
        unavailableTitle = NSTextField(labelWithString: quranReaderText("unavailable"))
        unavailableTitle.font = Localizer.shared.font(size: 18, weight: .semibold)
        unavailableTitle.alignment = .center
        unavailableDetail = NSTextField(wrappingLabelWithString: quranReaderText("unavailable.detail"))
        unavailableDetail.font = Localizer.shared.font(size: 13)
        unavailableDetail.alignment = .center
        for label in [unavailableTitle!, unavailableDetail!] {
            label.translatesAutoresizingMaskIntoConstraints = false
            unavailableOverlay.addSubview(label)
        }
        root.addSubview(unavailableOverlay)

        for control in [editionControl!, surahPopup!, searchField!, translationSwitch!,
                        translationPopup!, palettePopup!, layoutPopup!] {
            control.translatesAutoresizingMaskIntoConstraints = false
        }
        NSLayoutConstraint.activate([
            backdrop.leadingAnchor.constraint(equalTo: root.leadingAnchor),
            backdrop.trailingAnchor.constraint(equalTo: root.trailingAnchor),
            backdrop.topAnchor.constraint(equalTo: header.bottomAnchor),
            backdrop.bottomAnchor.constraint(equalTo: root.bottomAnchor),
            header.leadingAnchor.constraint(equalTo: root.leadingAnchor),
            header.trailingAnchor.constraint(equalTo: root.trailingAnchor),
            header.topAnchor.constraint(equalTo: root.topAnchor),
            header.heightAnchor.constraint(equalToConstant: 105),
            controls.leadingAnchor.constraint(equalTo: header.leadingAnchor, constant: 18),
            controls.trailingAnchor.constraint(equalTo: header.trailingAnchor, constant: -18),
            controls.topAnchor.constraint(equalTo: header.topAnchor, constant: 7),
            controls.bottomAnchor.constraint(equalTo: header.bottomAnchor, constant: -7),
            rowOne.widthAnchor.constraint(equalTo: controls.widthAnchor),
            rowTwo.widthAnchor.constraint(equalTo: controls.widthAnchor),
            editionControl.widthAnchor.constraint(equalToConstant: 150),
            editionControl.heightAnchor.constraint(equalToConstant: 32),
            surahPopup.widthAnchor.constraint(equalToConstant: 210),
            surahPopup.heightAnchor.constraint(equalToConstant: 32),
            searchField.widthAnchor.constraint(greaterThanOrEqualToConstant: 150),
            searchField.heightAnchor.constraint(equalToConstant: 32),
            translationPopup.widthAnchor.constraint(greaterThanOrEqualToConstant: 230),
            palettePopup.widthAnchor.constraint(equalToConstant: 108),
            layoutPopup.widthAnchor.constraint(equalToConstant: 108),
            hero.leadingAnchor.constraint(equalTo: backdrop.leadingAnchor, constant: 54),
            hero.trailingAnchor.constraint(equalTo: backdrop.trailingAnchor, constant: -54),
            hero.topAnchor.constraint(equalTo: backdrop.topAnchor, constant: 16),
            hero.heightAnchor.constraint(equalToConstant: 102),
            scrollView.leadingAnchor.constraint(equalTo: backdrop.leadingAnchor, constant: 42),
            scrollView.trailingAnchor.constraint(equalTo: backdrop.trailingAnchor, constant: -42),
            scrollView.topAnchor.constraint(equalTo: hero.bottomAnchor, constant: 10),
            scrollView.bottomAnchor.constraint(equalTo: backdrop.bottomAnchor),
            unavailableOverlay.centerXAnchor.constraint(equalTo: root.centerXAnchor),
            unavailableOverlay.centerYAnchor.constraint(equalTo: root.centerYAnchor),
            unavailableOverlay.widthAnchor.constraint(equalToConstant: 440),
            unavailableTitle.topAnchor.constraint(equalTo: unavailableOverlay.topAnchor, constant: 24),
            unavailableTitle.leadingAnchor.constraint(equalTo: unavailableOverlay.leadingAnchor, constant: 24),
            unavailableTitle.trailingAnchor.constraint(equalTo: unavailableOverlay.trailingAnchor, constant: -24),
            unavailableDetail.topAnchor.constraint(equalTo: unavailableTitle.bottomAnchor, constant: 12),
            unavailableDetail.leadingAnchor.constraint(equalTo: unavailableOverlay.leadingAnchor, constant: 28),
            unavailableDetail.trailingAnchor.constraint(equalTo: unavailableOverlay.trailingAnchor, constant: -28),
            unavailableDetail.bottomAnchor.constraint(equalTo: unavailableOverlay.bottomAnchor, constant: -24),
        ])
        self.view = root
        applyPalette()
        updateTranslationAvailability()
        loadEdition(restorePosition: true)
    }

    override func viewDidLayout() {
        super.viewDidLayout()
        guard tableView != nil else { return }
        if abs(tableView.bounds.width - currentWidth) > 8 {
            currentWidth = tableView.bounds.width
            tableView.noteHeightOfRows(withIndexesChanged: IndexSet(integersIn: 0..<visibleVerses.count))
        }
    }

    func tabDidActivate() {
        applyPalette()
        updateHero()
        tableView?.reloadData()
    }

    private func corpusURL(for edition: String) -> URL? {
        let component = edition == "warsh" ? "Warsh/warshData_v2-1.json"
                                            : "Hafs/hafsData_v2-0.json"
        let url = Bundle.main.resourceURL?.appendingPathComponent("Quran/\(component)")
        guard let url, FileManager.default.fileExists(atPath: url.path) else { return nil }
        return url
    }

    private func loadEdition(restorePosition: Bool) {
        let selectedEdition = edition
        UserDefaults.standard.set(selectedEdition, forKey: kQuranEditionKey)
        let generation = UUID()
        loadGeneration = generation
        unavailableOverlay.isHidden = true
        sourceLabel.stringValue = quranReaderText("offline") + " · "
            + quranReaderText(selectedEdition == "warsh" ? "exact.warsh" : "exact.hafs")
        guard let url = corpusURL(for: selectedEdition) else {
            unavailableOverlay.isHidden = false
            return
        }
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            do {
                let decoded = try JSONDecoder().decode([OfflineQuranVerse].self,
                                                        from: Data(contentsOf: url))
                let expected = selectedEdition == "warsh" ? 6_214 : 6_236
                guard decoded.count == expected,
                      Set(decoded.map(\.suraNumber)).count == 114,
                      decoded.allSatisfy({ !$0.uthmanicText.isEmpty }) else {
                    throw NSError(domain: "SalatTime.Quran", code: 30)
                }
                let grouped = Dictionary(grouping: decoded, by: \.suraNumber)
                DispatchQueue.main.async {
                    guard let self, self.loadGeneration == generation,
                          self.edition == selectedEdition else { return }
                    self.verses = decoded
                    self.surahVerses = grouped
                    self.populateSurahPopup()
                    self.loadWordMeaningsIfNeeded()
                    if !restorePosition { self.selectedAyah = 1 }
                    self.rebuildVisibleVerses(scrollToSelection: true)
                    self.updateTranslationAvailability()
                }
            } catch {
                DispatchQueue.main.async { [weak self] in self?.unavailableOverlay.isHidden = false }
            }
        }
    }

    private func populateSurahPopup() {
        surahPopup.removeAllItems()
        for sura in 1...114 {
            guard let verse = surahVerses[sura]?.first else { continue }
            let title = Localizer.shared.isRTL
                ? "\(localizedInterfaceDigits(String(sura))) · \(verse.suraNameArabic)"
                : "\(localizedInterfaceDigits(String(sura))) · \(verse.suraNameArabic) · \(verse.suraNameEnglish)"
            surahPopup.addItem(withTitle: title)
            surahPopup.lastItem?.tag = sura
        }
        if let item = surahPopup.itemArray.first(where: { $0.tag == selectedSurah }) {
            surahPopup.select(item)
        }
    }

    private func rebuildVisibleVerses(scrollToSelection: Bool) {
        let base = surahVerses[selectedSurah] ?? []
        if readerLayout == .focus {
            visibleVerses = [base.first(where: { $0.ayahNumber == selectedAyah }) ?? base.first]
                .compactMap { $0 }
        } else if !searchActive {
            visibleVerses = base
        }
        tableView.reloadData()
        tableView.noteHeightOfRows(withIndexesChanged: IndexSet(integersIn: 0..<visibleVerses.count))
        updateHero()
        updateBookmarkButton()
        if scrollToSelection, let index = visibleVerses.firstIndex(where: {
            $0.suraNumber == selectedSurah && $0.ayahNumber == selectedAyah
        }) {
            tableView.scrollRowToVisible(index)
            tableView.selectRowIndexes(IndexSet(integer: index), byExtendingSelection: false)
        } else if scrollToSelection, !visibleVerses.isEmpty {
            tableView.scrollRowToVisible(0)
        }
    }

    private func updateHero() {
        guard let first = surahVerses[selectedSurah]?.first else { return }
        hero.titleLabel.stringValue = first.suraNameArabic
        hero.subtitleLabel.stringValue = Localizer.shared.isRTL
            ? quranReaderText(edition == "warsh" ? "exact.warsh" : "exact.hafs")
            : "\(first.suraNameEnglish) · \(quranReaderText(edition == "warsh" ? "exact.warsh" : "exact.hafs"))"
        let count = surahVerses[selectedSurah]?.count ?? 0
        hero.progressLabel.stringValue = String(format: quranReaderText("verses"),
            localizedInterfaceDigits(String(count)))
    }

    private func updateTranslationAvailability() {
        guard translationSwitch != nil else { return }
        let hafs = edition == "hafs"
        meaningsButton.isEnabled = hafs
        translationSwitch.isEnabled = hafs
        translationPopup.isEnabled = hafs && translationSwitch.state == .on
        if !hafs {
            sourceLabel.stringValue = quranReaderText("hafs.only")
            translations = [:]
            tableView?.reloadData()
        } else if translationSwitch.state == .on {
            loadCurrentTranslation()
        } else {
            translations = [:]
            sourceLabel.stringValue = quranReaderText("offline") + " · " + quranReaderText("exact.hafs")
            tableView?.reloadData()
        }
    }

    private func loadCurrentTranslation() {
        let descriptor = currentTranslation
        let generation = UUID()
        translationGeneration = generation
        sourceLabel.stringValue = "\(quranReaderText("translation")) · \(descriptor.title) · v\(descriptor.version) · QuranEnc.com"
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let value = try? loadQuranTranslation(descriptor)
            DispatchQueue.main.async {
                guard let self, self.translationGeneration == generation,
                      self.edition == "hafs", self.translationSwitch.state == .on else { return }
                self.translations = value ?? [:]
                if value == nil {
                    self.sourceLabel.stringValue = quranReaderText("unavailable.detail")
                }
                self.tableView.reloadData()
                self.tableView.noteHeightOfRows(withIndexesChanged:
                    IndexSet(integersIn: 0..<self.visibleVerses.count))
            }
        }
    }

    private func loadWordMeaningsIfNeeded() {
        guard edition == "hafs" else {
            wordMeanings = []
            return
        }
        guard wordMeanings.isEmpty,
              let url = Bundle.main.resourceURL?
                .appendingPathComponent("Quran/MuyassarGhareeb/muyassar_ghareeb_1.json")
        else { return }
        DispatchQueue.global(qos: .utility).async { [weak self] in
            let decoded = (try? JSONDecoder().decode([OfflineQuranWordMeaning].self,
                                                      from: Data(contentsOf: url))) ?? []
            DispatchQueue.main.async { self?.wordMeanings = decoded }
        }
    }

    @objc private func editionChanged(_ sender: NSSegmentedControl) {
        searchField.stringValue = ""
        searchActive = false
        loadEdition(restorePosition: true)
    }

    @objc private func surahChanged(_ sender: NSPopUpButton) {
        selectedSurah = max(1, sender.selectedItem?.tag ?? 1)
        selectedAyah = 1
        searchField.stringValue = ""
        searchActive = false
        persistLocator()
        rebuildVisibleVerses(scrollToSelection: true)
    }

    @objc private func translationVisibilityChanged(_ sender: NSSwitch) {
        UserDefaults.standard.set(sender.state == .on, forKey: kQuranTranslationVisible)
        updateTranslationAvailability()
    }

    @objc private func translationChanged(_ sender: NSPopUpButton) {
        let index = max(0, min(QuranTranslationDescriptor.verified.count - 1,
                               sender.indexOfSelectedItem))
        currentTranslation = QuranTranslationDescriptor.verified[index]
        UserDefaults.standard.set(currentTranslation.key, forKey: kQuranTranslationKey)
        if wantsTranslation { loadCurrentTranslation() }
    }

    @objc private func paletteChanged(_ sender: NSPopUpButton) {
        UserDefaults.standard.set(sender.indexOfSelectedItem, forKey: kQuranReaderPalette)
        applyPalette()
        tableView.reloadData()
    }

    private func applyPalette() {
        guard backdrop != nil else { return }
        backdrop.palette = palette
        hero.palette = palette
        tableView?.backgroundColor = .clear
    }

    @objc private func layoutChanged(_ sender: NSPopUpButton) {
        UserDefaults.standard.set(sender.indexOfSelectedItem, forKey: kQuranReaderLayout)
        rebuildVisibleVerses(scrollToSelection: true)
    }

    @objc private func decreaseText(_ sender: Any?) { changeTextScale(by: -0.1) }
    @objc private func increaseText(_ sender: Any?) { changeTextScale(by: 0.1) }
    private func changeTextScale(by delta: CGFloat) {
        let next = max(0.78, min(1.55, textScale + delta))
        UserDefaults.standard.set(Double(next), forKey: kQuranReaderTextScale)
        tableView.reloadData()
        tableView.noteHeightOfRows(withIndexesChanged: IndexSet(integersIn: 0..<visibleVerses.count))
    }

    @objc private func previousVerse(_ sender: Any?) { moveVerse(by: -1) }
    @objc private func nextVerse(_ sender: Any?) { moveVerse(by: 1) }
    private func moveVerse(by delta: Int) {
        guard !verses.isEmpty else { return }
        let current = verses.firstIndex { $0.suraNumber == selectedSurah && $0.ayahNumber == selectedAyah }
            ?? 0
        let index = max(0, min(verses.count - 1, current + delta))
        selectedSurah = verses[index].suraNumber
        selectedAyah = verses[index].ayahNumber
        if let item = surahPopup.itemArray.first(where: { $0.tag == selectedSurah }) {
            surahPopup.select(item)
        }
        searchField.stringValue = ""
        searchActive = false
        persistLocator()
        rebuildVisibleVerses(scrollToSelection: true)
    }

    func controlTextDidChange(_ obj: Notification) {
        guard let field = obj.object as? NSSearchField, field === searchField else { return }
        scheduleSearch(field.stringValue)
    }

    @objc private func searchChanged(_ sender: NSSearchField) { scheduleSearch(sender.stringValue) }
    private func scheduleSearch(_ raw: String) {
        let query = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if query.isEmpty {
            searchActive = false
            rebuildVisibleVerses(scrollToSelection: false)
            return
        }
        if let reference = parseQuranReference(query),
           let match = verses.first(where: {
               $0.suraNumber == reference.sura && $0.ayahNumber == reference.ayah
           }) {
            selectedSurah = match.suraNumber
            selectedAyah = match.ayahNumber
            searchActive = false
            if let item = surahPopup.itemArray.first(where: { $0.tag == selectedSurah }) {
                surahPopup.select(item)
            }
            persistLocator()
            rebuildVisibleVerses(scrollToSelection: true)
            return
        }
        let normalized = normalizedQuranSearch(query)
        let generation = UUID()
        searchGeneration = generation
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self else { return }
            let matches = self.verses.filter {
                normalizedQuranSearch($0.searchableText).contains(normalized)
                    || normalizedQuranSearch($0.suraNameArabic).contains(normalized)
                    || $0.suraNameEnglish.localizedCaseInsensitiveContains(query)
            }
            DispatchQueue.main.async {
                guard self.searchGeneration == generation,
                      self.searchField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines) == query
                else { return }
                self.searchActive = true
                self.visibleVerses = Array(matches.prefix(500))
                self.tableView.reloadData()
                self.tableView.noteHeightOfRows(withIndexesChanged:
                    IndexSet(integersIn: 0..<self.visibleVerses.count))
                if self.visibleVerses.isEmpty {
                    self.hero.titleLabel.stringValue = quranReaderText("no.results")
                    self.hero.subtitleLabel.stringValue = query
                    self.hero.progressLabel.stringValue = ""
                } else {
                    self.hero.titleLabel.stringValue = quranReaderText("search")
                    self.hero.subtitleLabel.stringValue = query
                    self.hero.progressLabel.stringValue = String(format: quranReaderText("verses"),
                        localizedInterfaceDigits(String(self.visibleVerses.count)))
                }
            }
        }
    }

    func numberOfRows(in tableView: NSTableView) -> Int { visibleVerses.count }

    func tableView(_ tableView: NSTableView,
                   viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        guard visibleVerses.indices.contains(row) else { return nil }
        let identifier = NSUserInterfaceItemIdentifier("riwaq.verse")
        let cell = (tableView.makeView(withIdentifier: identifier, owner: self)
                    as? QuranVerseRowView) ?? QuranVerseRowView()
        cell.identifier = identifier
        let verse = visibleVerses[row]
        let translated = wantsTranslation ? translations["\(verse.suraNumber):\(verse.ayahNumber)"] : nil
        let startsSurah = row == 0 || visibleVerses[row - 1].suraNumber != verse.suraNumber
        let font = verifiedQuranFont(edition: edition, size: 30 * textScale)
        cell.configure(verse: verse, translation: translated,
                       descriptor: translated == nil ? nil : currentTranslation,
                       palette: palette, layout: readerLayout, textScale: textScale,
                       isSurahStart: startsSurah, isBookmarked: isBookmarked(verse),
                       officialFont: font) { [weak self, weak cell] in
            guard let self, let translated, let cell else { return }
            self.showTranslationNotes(translated, from: cell)
        }
        return cell
    }

    func tableView(_ tableView: NSTableView, heightOfRow row: Int) -> CGFloat {
        guard visibleVerses.indices.contains(row) else { return 120 }
        let verse = visibleVerses[row]
        let width = max(420, tableView.bounds.width - 150)
        let font = verifiedQuranFont(edition: edition, size: 30 * textScale)
            ?? NSFont(name: "Geeza Pro", size: 30 * textScale)
            ?? Localizer.shared.font(size: 30 * textScale)
        var height = localizedTextHeight(verse.uthmanicText, font: font,
                                         width: width, maximumLines: 0) + 78
        if wantsTranslation,
           let translated = translations["\(verse.suraNumber):\(verse.ayahNumber)"] {
            let translationFont = Localizer.shared.font(size: 14.5 * min(1.2, textScale))
            height += localizedTextHeight(translated.text, font: translationFont,
                                          width: width, maximumLines: 0) + 18
        }
        if row == 0 || visibleVerses[row - 1].suraNumber != verse.suraNumber { height += 45 }
        if readerLayout != .flow { height += 24 }
        if readerLayout == .focus { height = max(height, tableView.bounds.height - 20) }
        return max(128, height)
    }

    func tableViewSelectionDidChange(_ notification: Notification) {
        let row = tableView.selectedRow
        guard visibleVerses.indices.contains(row) else { return }
        selectedSurah = visibleVerses[row].suraNumber
        selectedAyah = visibleVerses[row].ayahNumber
        persistLocator()
        updateBookmarkButton()
    }

    private func persistLocator() {
        UserDefaults.standard.set(selectedSurah, forKey: kQuranReaderSurah)
        UserDefaults.standard.set(selectedAyah, forKey: kQuranReaderAyah)
    }

    private func currentVerse() -> OfflineQuranVerse? {
        if let selected = visibleVerses.first(where: {
            $0.suraNumber == selectedSurah && $0.ayahNumber == selectedAyah
        }) { return selected }
        return visibleVerses.first
    }

    private func loadBookmarks() -> [OfflineQuranBookmark] {
        guard let data = UserDefaults.standard.data(forKey: kQuranBookmarksKey),
              let value = try? JSONDecoder().decode([OfflineQuranBookmark].self, from: data)
        else { return [] }
        return value
    }

    private func saveBookmarks() {
        if let data = try? JSONEncoder().encode(bookmarks) {
            UserDefaults.standard.set(data, forKey: kQuranBookmarksKey)
        }
    }

    private func isBookmarked(_ verse: OfflineQuranVerse) -> Bool {
        bookmarks.contains {
            guard $0.edition == edition else { return false }
            if let sura = $0.sura, let ayah = $0.ayah {
                return sura == verse.suraNumber && ayah == verse.ayahNumber
            }
            return $0.page == verse.pageStart
        }
    }

    @objc private func toggleBookmark(_ sender: Any?) {
        guard let verse = currentVerse() else { return }
        if let index = bookmarks.firstIndex(where: {
            $0.edition == edition && $0.sura == verse.suraNumber && $0.ayah == verse.ayahNumber
        }) {
            bookmarks.remove(at: index)
        } else {
            bookmarks.append(OfflineQuranBookmark(
                title: "\(verse.suraNameArabic) \(localizedInterfaceDigits(String(verse.ayahNumber)))",
                edition: edition, page: verse.pageStart,
                sura: verse.suraNumber, ayah: verse.ayahNumber))
        }
        saveBookmarks()
        updateBookmarkButton()
        tableView.reloadData()
    }

    private func updateBookmarkButton() {
        guard bookmarkButton != nil else { return }
        let active = currentVerse().map(isBookmarked) ?? false
        bookmarkButton.image = templateSymbol(active ? "bookmark.fill" : "bookmark",
                                               pointSize: 14, weight: .semibold)
        bookmarkButton.contentTintColor = active ? .appGreenAccent : bookmarkButton.idleTint
    }

    @objc private func showBookmarks(_ sender: NSButton) {
        let menu = NSMenu(title: quranReaderText("bookmarks"))
        bookmarkMenuItems.removeAll()
        let values = bookmarks.sorted { $0.createdAt > $1.createdAt }
        if values.isEmpty {
            let empty = NSMenuItem(title: offlineQuranText("search.none"), action: nil,
                                   keyEquivalent: "")
            empty.isEnabled = false
            menu.addItem(empty)
        } else {
            for (index, bookmark) in values.enumerated() {
                let item = NSMenuItem(title: bookmark.title, action: #selector(openBookmark(_:)),
                                      keyEquivalent: "")
                item.target = self
                item.tag = index
                bookmarkMenuItems[index] = bookmark
                menu.addItem(item)
            }
        }
        menu.popUp(positioning: nil, at: NSPoint(x: 0, y: sender.bounds.height + 4), in: sender)
    }

    @objc private func openBookmark(_ sender: NSMenuItem) {
        guard let bookmark = bookmarkMenuItems[sender.tag] else { return }
        editionControl.selectedSegment = bookmark.edition == "warsh" ? 1 : 0
        selectedSurah = bookmark.sura ?? selectedSurah
        selectedAyah = bookmark.ayah ?? selectedAyah
        if bookmark.sura == nil {
            // Lossless migration path for the legacy page-only locator.
            if let verse = verses.first(where: { $0.appears(on: bookmark.page) }) {
                selectedSurah = verse.suraNumber
                selectedAyah = verse.ayahNumber
            }
        }
        persistLocator()
        loadEdition(restorePosition: true)
    }

    private func showTranslationNotes(_ value: QuranTranslationVerse, from source: NSView) {
        let popover = NSPopover()
        popover.behavior = .transient
        popover.animates = !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        let vc = NSViewController()
        let text = NSTextView(frame: NSRect(x: 0, y: 0, width: 380, height: 250))
        text.isEditable = false
        text.isSelectable = true
        text.drawsBackground = false
        text.textContainerInset = NSSize(width: 16, height: 16)
        text.font = Localizer.shared.font(size: 13)
        text.string = "\(quranReaderText("translation")) · \(currentTranslation.title) · v\(currentTranslation.version) · QuranEnc.com\n\n\(value.footnotes)"
        text.baseWritingDirection = currentTranslation.isRTL ? .rightToLeft : .leftToRight
        vc.view = text
        vc.preferredContentSize = NSSize(width: 380, height: 250)
        popover.contentViewController = vc
        popover.show(relativeTo: source.bounds, of: source, preferredEdge: .maxY)
    }

    @objc private func showWordMeanings(_ sender: NSButton) {
        guard edition == "hafs", let verse = currentVerse() else { return }
        let values = wordMeanings.filter { $0.page == verse.pageStart }
        let body = values.isEmpty
            ? quranReaderText("word.meanings.none")
            : values.map { "\($0.word)\n\($0.explanation)" }.joined(separator: "\n\n")
        let popover = NSPopover()
        popover.behavior = .transient
        popover.animates = !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        let controller = NSViewController()
        let scroll = NSScrollView(frame: NSRect(x: 0, y: 0, width: 390, height: 300))
        scroll.hasVerticalScroller = true
        scroll.drawsBackground = false
        let text = NSTextView(frame: NSRect(x: 0, y: 0, width: 370, height: 300))
        text.isEditable = false
        text.isSelectable = true
        text.drawsBackground = false
        text.textContainerInset = NSSize(width: 16, height: 16)
        text.font = Localizer.shared.font(size: 14)
        text.baseWritingDirection = .rightToLeft
        text.alignment = .right
        text.string = "\(quranReaderText("word.meanings")) · Muyassar Ghareeb v0.1\n"
            + "King Fahd Complex · Hafs · \(offlineQuranText("page")) \(localizedInterfaceDigits(String(verse.pageStart)))\n\n"
            + body
        scroll.documentView = text
        controller.view = scroll
        controller.preferredContentSize = NSSize(width: 390, height: 300)
        popover.contentViewController = controller
        popover.show(relativeTo: sender.bounds, of: sender, preferredEdge: .maxY)
    }

    @objc private func showProvenance(_ sender: Any?) {
        let alert = NSAlert()
        alert.messageText = quranReaderText("source")
        let translationDetail = QuranTranslationDescriptor.verified.map {
            "• \($0.nativeLanguage): \($0.title) v\($0.version) · QuranEnc.com · Hafs only"
        }.joined(separator: "\n")
        alert.informativeText = "King Fahd Glorious Quran Printing Complex\n"
            + "Hafs JSON v2.0 · 6,236 ayahs\nWarsh JSON v2.1 · 6,214 ayahs\n"
            + "Exact bundled text · verified at build time · no runtime network\n\n"
            + quranReaderText("translation") + ":\n" + translationDetail
            + "\n\nTranslations are human renderings of meanings, not Qur'an text."
        alert.addButton(withTitle: quranReaderText("close"))
        alert.runModal()
    }
}

private extension String {
    var nonEmpty: String? { isEmpty ? nil : self }
}

// ============================================================================
// MARK: Adhkar settings — Apple-style grouped settings panel (frame-based)
// ============================================================================
/// Settings panel designed like macOS System Settings. All frame-based
/// (no Auto Layout) so it works inside the FlippedView documentView.

final class AdhkarSettingsViewController: NSViewController, MainTabContent {

    private var sectionControl: NSSegmentedControl!
    private var settingsScrollView: NSScrollView!
    private var selectedSection: SettingsSection = .general
    private var embeddedMosquePicker: MosquePickerView?

    private var languagePopup: NSPopUpButton!
    private var appearanceSeg: NSSegmentedControl!
    private var materialSeg: NSSegmentedControl!
    private var timeFormatSeg: NSSegmentedControl!
    private var numeralStyleSeg: NSSegmentedControl!
    private var dashboardCountdownCheck: NSButton!
    private var openAtLoginCheck: NSButton!
    private var accentSwatches: [AccentSwatchButton] = []

    private var barIconCheck: NSButton!
    private var barTimeCheck: NSButton!
    private var barCountdownCheck: NSButton!
    private var barHijriPopup: NSPopUpButton!

    private var adhanCheck: NSButton!
    private var adhanSoundPopup: NSPopUpButton!
    private var adhanOutputPopup: NSPopUpButton!
    private var adhanOutputDevices: [AudioOutputDevice] = []
    private var notificationCheck: NSButton!
    private var preAdhanPopup: NSPopUpButton!
    private var perPrayerModePopups: [NSPopUpButton] = []

    private var adhkarVolumeSlider: NSSlider!
    private var adhkarOutputPopup: NSPopUpButton!
    private var adhkarOutputDevices: [AudioOutputDevice] = []
    private var adhkarAutoPlayCheck: NSButton!
    private var morningPopup: NSPopUpButton!
    private var eveningPopup: NSPopUpButton!
    private var afterAdhanDelayPopup: NSPopUpButton!
    private let adhkarTestSession = AdhkarSession()

    private var appDelegate: AppDelegate? { NSApp.delegate as? AppDelegate }

    init(initialSection: SettingsSection = .general) {
        selectedSection = initialSection
        super.init(nibName: nil, bundle: nil)
    }
    required init?(coder: NSCoder) { fatalError() }

    func selectSection(_ section: SettingsSection) {
        selectedSection = section
        guard isViewLoaded else { return }
        sectionControl.selectedSegment = selectedSection.rawValue
        rebuildSelectedSection()
        tabDidActivate()
    }

    override func loadView() {
        let root = NSView()
        root.userInterfaceLayoutDirection = Localizer.shared.isRTL ? .rightToLeft : .leftToRight
        sectionControl = NSSegmentedControl()
        sectionControl.segmentCount = SettingsSection.allCases.count
        sectionControl.setLabel(featureText("settings.general"),
                                forSegment: SettingsSection.general.rawValue)
        sectionControl.setLabel(t("settings.section.mosque"),
                                forSegment: SettingsSection.mosque.rawValue)
        sectionControl.setLabel(t("settings.section.menu_bar"),
                                forSegment: SettingsSection.menuBar.rawValue)
        sectionControl.setLabel(t("settings.section.adhan"),
                                forSegment: SettingsSection.adhan.rawValue)
        sectionControl.setLabel(t("settings.section.adhkar"),
                                forSegment: SettingsSection.adhkar.rawValue)
        sectionControl.segmentStyle = .texturedRounded
        sectionControl.userInterfaceLayoutDirection = root.userInterfaceLayoutDirection
        sectionControl.selectedSegment = selectedSection.rawValue
        sectionControl.target = self
        sectionControl.action = #selector(settingsSectionChanged(_:))
        sectionControl.translatesAutoresizingMaskIntoConstraints = false

        settingsScrollView = NSScrollView()
        settingsScrollView.drawsBackground = false
        settingsScrollView.hasVerticalScroller = true
        settingsScrollView.autohidesScrollers = true
        settingsScrollView.translatesAutoresizingMaskIntoConstraints = false
        if Localizer.shared.isRTL {
            settingsScrollView.userInterfaceLayoutDirection = .rightToLeft
        }

        root.addSubview(sectionControl)
        root.addSubview(settingsScrollView)
        NSLayoutConstraint.activate([
            sectionControl.topAnchor.constraint(equalTo: root.topAnchor, constant: 18),
            sectionControl.centerXAnchor.constraint(equalTo: root.centerXAnchor),
            sectionControl.widthAnchor.constraint(equalToConstant: 600),
            sectionControl.heightAnchor.constraint(equalToConstant: 30),

            settingsScrollView.leadingAnchor.constraint(equalTo: root.leadingAnchor),
            settingsScrollView.trailingAnchor.constraint(equalTo: root.trailingAnchor),
            settingsScrollView.topAnchor.constraint(equalTo: sectionControl.bottomAnchor,
                                                     constant: 10),
            settingsScrollView.bottomAnchor.constraint(equalTo: root.bottomAnchor),
        ])
        self.view = root
        rebuildSelectedSection()
    }

    override func viewDidLayout() {
        super.viewDidLayout()
        guard let picker = embeddedMosquePicker else { return }
        let size = settingsScrollView.contentSize
        picker.frame = NSRect(x: 0, y: 0, width: max(780, size.width),
                              height: max(470, size.height))
    }

    private func rebuildSelectedSection() {
        accentSwatches.removeAll()
        embeddedMosquePicker = nil
        if selectedSection == .mosque {
            settingsScrollView.hasVerticalScroller = false
            let size = settingsScrollView.contentSize
            let picker = MosquePickerView(width: max(780, size.width),
                                          height: max(470, size.height),
                                          showsNavigationHeader: false)
            picker.appDelegate = appDelegate
            picker.autoresizingMask = [.width, .height]
            picker.setAccessibilityLabel(t("settings.section.mosque"))
            settingsScrollView.documentView = picker
            embeddedMosquePicker = picker
            return
        }
        settingsScrollView.hasVerticalScroller = true
        let body = FlippedView(frame: NSRect(x: 0, y: 0, width: 960, height: 620))
        settingsScrollView.documentView = body
        buildContent(into: body)
        body.needsDisplay = true
    }

    @objc private func settingsSectionChanged(_ sender: NSSegmentedControl) {
        guard let section = SettingsSection(rawValue: max(0, sender.selectedSegment)) else {
            return
        }
        selectedSection = section
        rebuildSelectedSection()
        tabDidActivate()
    }

    private func buildContent(into body: FlippedView) {
        let isRTL = Localizer.shared.isRTL
        let width: CGFloat = 960
        let cardX: CGFloat = 140
        let cardW: CGFloat = 680
        let rowH: CGFloat = 44
        let labelW: CGFloat = 190
        var y: CGFloat = 26
        var rowY: CGFloat = 0

        func sectionHeader(_ title: String, subtitle: String? = nil) {
            let label = NSTextField(labelWithString: title)
            label.font = Localizer.shared.font(size: 17, weight: .semibold)
            label.textColor = .labelColor
            label.alignment = isRTL ? .right : .left
            label.baseWritingDirection = isRTL ? .rightToLeft : .leftToRight
            let titleHeight = max(24, localizedTextHeight(title, font: label.font!,
                                                         width: cardW - 8))
            label.frame = NSRect(x: cardX + 4, y: y,
                                 width: cardW - 8, height: titleHeight)
            body.addSubview(label)
            y += titleHeight + 2
            if let subtitle = subtitle {
                let detail = NSTextField(wrappingLabelWithString: subtitle)
                detail.font = Localizer.shared.font(size: 11)
                detail.textColor = .secondaryLabelColor
                detail.alignment = isRTL ? .right : .left
                detail.baseWritingDirection = isRTL ? .rightToLeft : .leftToRight
                let detailHeight = max(30, localizedTextHeight(subtitle, font: detail.font!,
                                                              width: cardW - 8,
                                                              maximumLines: 2))
                detail.frame = NSRect(x: cardX + 4, y: y,
                                      width: cardW - 8, height: detailHeight)
                detail.maximumNumberOfLines = 2
                body.addSubview(detail)
                y += detailHeight + 4
            }
        }

        func beginCard(rows: Int) -> (NSView, CGFloat) {
            let h = CGFloat(rows) * rowH
            let card = AdaptiveCardView(frame: NSRect(x: cardX, y: y,
                                                       width: cardW, height: h))
            card.addsDepth = true
            body.addSubview(card)
            rowY = 0
            return (card, h)
        }

        func addRow(_ card: NSView, label text: String, control: NSView) {
            if rowY > 0 {
                let separator = NSBox(frame: NSRect(x: 14, y: rowY,
                                                     width: cardW - 28, height: 1))
                separator.boxType = .separator
                card.addSubview(separator)
            }
            let controlX: CGFloat = isRTL ? 14 : labelW + 22
            let labelX: CGFloat = isRTL ? cardW - labelW - 14 : 14
            let controlW = cardW - labelW - 36
            if !text.isEmpty {
                let label = NSTextField(labelWithString: text)
                label.font = Localizer.shared.font(size: 13)
                label.textColor = .labelColor
                label.alignment = isRTL ? .right : .left
                label.baseWritingDirection = isRTL ? .rightToLeft : .leftToRight
                let labelHeight = max(20, localizedTextHeight(text, font: label.font!,
                                                             width: labelW))
                label.frame = NSRect(x: labelX,
                                     y: rowY + (rowH - labelHeight) / 2,
                                     width: labelW, height: labelHeight)
                card.addSubview(label)
            }
            let x = text.isEmpty ? 14 : controlX
            let w = text.isEmpty ? cardW - 28 : controlW
            control.frame = NSRect(x: x, y: rowY + 8, width: w, height: 28)
            card.addSubview(control)
            rowY += rowH
        }

        func endCard(_ height: CGFloat) { y += height + 30 }

        if selectedSection == .general {
            // General settings are deliberately shared by prayer times,
            // Adhan, and Adhkar. There is one language and one visual system
            // everywhere.
            sectionHeader(t("settings.tab.appearance"),
                          subtitle: t("adhkar.editor.title") + " · Salat Time")
            let generalRows = 7 + (Localizer.shared.isArabic ? 1 : 0)
            let (generalCard, generalH) = beginCard(rows: generalRows)

        languagePopup = NSPopUpButton(frame: .zero, pullsDown: false)
        kSupportedLanguages.forEach { languagePopup.addItem(withTitle: $0.nativeName) }
        languagePopup.selectItem(at: kSupportedLanguages.firstIndex(where: {
            $0.code == Localizer.shared.current.code
        }) ?? 0)
        languagePopup.target = self
        languagePopup.action = #selector(languageChanged(_:))
        addRow(generalCard, label: t("settings.section.language"), control: languagePopup)

        if Localizer.shared.isArabic {
            numeralStyleSeg = NSSegmentedControl()
            numeralStyleSeg.segmentCount = 2
            // Keep the samples literal so each option remains recognizable
            // regardless of the currently-selected numeral preference.
            numeralStyleSeg.setLabel("\(featureText("settings.numerals.western"))  0 1 2 3",
                                     forSegment: 0)
            numeralStyleSeg.setLabel("\(featureText("settings.numerals.indic"))  ٠ ١ ٢ ٣",
                                     forSegment: 1)
            numeralStyleSeg.segmentStyle = .texturedRounded
            numeralStyleSeg.selectedSegment = currentArabicDigitStyle() == .arabicIndic ? 1 : 0
            numeralStyleSeg.target = self
            numeralStyleSeg.action = #selector(numeralStyleChanged(_:))
            numeralStyleSeg.setAccessibilityLabel(featureText("settings.numerals"))
            addRow(generalCard, label: featureText("settings.numerals"),
                   control: numeralStyleSeg)
        }

        appearanceSeg = NSSegmentedControl()
        appearanceSeg.segmentCount = 3
        appearanceSeg.setLabel(t("settings.appearance.system"), forSegment: 0)
        appearanceSeg.setLabel(t("settings.appearance.light"), forSegment: 1)
        appearanceSeg.setLabel(t("settings.appearance.dark"), forSegment: 2)
        appearanceSeg.segmentStyle = .texturedRounded
        appearanceSeg.selectedSegment = ["system", "light", "dark"].firstIndex(of:
            UserDefaults.standard.string(forKey: kAppearanceKey) ?? "system") ?? 0
        appearanceSeg.target = self
        appearanceSeg.action = #selector(appearanceChanged(_:))
        addRow(generalCard, label: t("settings.section.appearance"), control: appearanceSeg)

        let swatchContainer = NSView()
        var swatchX: CGFloat = 0
        for key in kAccentOrder {
            let swatch = AccentSwatchButton(key: key, diameter: 28,
                                            target: self,
                                            action: #selector(accentTapped(_:)))
            swatch.frame = NSRect(x: swatchX, y: 0, width: 30, height: 28)
            swatch.isSelectedSwatch = key == currentAccentKey()
            swatchContainer.addSubview(swatch)
            accentSwatches.append(swatch)
            swatchX += 38
        }
        addRow(generalCard, label: t("settings.section.accent"), control: swatchContainer)

        materialSeg = NSSegmentedControl()
        materialSeg.segmentCount = 2
        materialSeg.setLabel(t("menu.theme.material.opaque"), forSegment: 0)
        materialSeg.setLabel(t("menu.theme.material.glass"), forSegment: 1)
        materialSeg.segmentStyle = .texturedRounded
        materialSeg.selectedSegment = isGlassMaterial() ? 1 : 0
        materialSeg.target = self
        materialSeg.action = #selector(materialChanged(_:))
        addRow(generalCard, label: t("settings.section.material"), control: materialSeg)

        timeFormatSeg = NSSegmentedControl()
        timeFormatSeg.segmentCount = 2
        timeFormatSeg.setLabel(t("settings.time_format.24h"), forSegment: 0)
        timeFormatSeg.setLabel(t("settings.time_format.12h"), forSegment: 1)
        timeFormatSeg.segmentStyle = .texturedRounded
        timeFormatSeg.selectedSegment = (UserDefaults.standard.string(forKey: kTimeFormat) ?? "24h") == "12h" ? 1 : 0
        timeFormatSeg.target = self
        timeFormatSeg.action = #selector(timeFormatChanged(_:))
        addRow(generalCard, label: t("settings.section.time_format"), control: timeFormatSeg)

        dashboardCountdownCheck = NSButton(
            checkboxWithTitle: prayerInfoText("visual.countdown.show"),
            target: self,
            action: #selector(dashboardCountdownChanged(_:)))
        dashboardCountdownCheck.state = (UserDefaults.standard.object(
            forKey: kPrayerShowCountdown) as? Bool ?? true) ? .on : .off
        dashboardCountdownCheck.setAccessibilityHelp(prayerInfoText("visual.countdown.help"))
        addRow(generalCard, label: "", control: dashboardCountdownCheck)

        openAtLoginCheck = NSButton(checkboxWithTitle: t("settings.startup.open_at_login"),
                                    target: self, action: #selector(openAtLoginChanged(_:)))
        openAtLoginCheck.state = isOpenAtLoginEnabled() ? .on : .off
        addRow(generalCard, label: t("settings.section.startup"), control: openAtLoginCheck)

            endCard(generalH)
        }

        if selectedSection == .menuBar {
            sectionHeader(t("settings.section.menu_bar"),
                          subtitle: featureText("settings.menu_bar.help"))
            let (menuCard, menuH) = beginCard(rows: 4)

            barIconCheck = NSButton(checkboxWithTitle: t("settings.bar.icon"),
                                    target: self,
                                    action: #selector(menuBarToggleChanged(_:)))
            barIconCheck.state = (UserDefaults.standard.object(forKey: kBarShowIcon)
                                  as? Bool ?? true) ? .on : .off
            addRow(menuCard, label: "", control: barIconCheck)

            barTimeCheck = NSButton(checkboxWithTitle: t("settings.bar.time"),
                                    target: self,
                                    action: #selector(menuBarToggleChanged(_:)))
            barTimeCheck.state = (UserDefaults.standard.object(forKey: kBarShowTime)
                                  as? Bool ?? true) ? .on : .off
            addRow(menuCard, label: "", control: barTimeCheck)

            barCountdownCheck = NSButton(checkboxWithTitle: t("settings.bar.countdown"),
                                         target: self,
                                         action: #selector(menuBarToggleChanged(_:)))
            barCountdownCheck.state = (UserDefaults.standard.object(forKey: kBarShowCountdown)
                                       as? Bool ?? true) ? .on : .off
            addRow(menuCard, label: "", control: barCountdownCheck)

            barHijriPopup = NSPopUpButton(frame: .zero, pullsDown: false)
            for format in kHijriFormatOrder {
                barHijriPopup.addItem(withTitle:
                    t("settings.bar.hijri.format.\(format.rawValue)"))
            }
            barHijriPopup.selectItem(at:
                kHijriFormatOrder.firstIndex(of: currentHijriFormat()) ?? 0)
            barHijriPopup.target = self
            barHijriPopup.action = #selector(barHijriFormatChanged(_:))
            addRow(menuCard, label: t("settings.bar.hijri"), control: barHijriPopup)
            endCard(menuH)
        }

        if selectedSection == .adhan {
            // Complete Adhan controls live here as well as in the compact popup.
            sectionHeader(t("settings.section.adhan"))
            let (adhanCard, adhanH) = beginCard(rows: 6)
        adhanCheck = NSButton(checkboxWithTitle: t("settings.adhan.play"), target: self,
                              action: #selector(adhanEnabledChanged(_:)))
        adhanCheck.state = UserDefaults.standard.bool(forKey: kAdhanEnabled) ? .on : .off
        addRow(adhanCard, label: "", control: adhanCheck)

        adhanSoundPopup = NSPopUpButton(frame: .zero, pullsDown: false)
        adhanCatalog.forEach { adhanSoundPopup.addItem(withTitle: $0.name) }
        adhanSoundPopup.selectItem(at: adhanCatalog.firstIndex(where: {
            $0.id == currentAdhanOption().id
        }) ?? 0)
        adhanSoundPopup.target = self
        adhanSoundPopup.action = #selector(adhanSoundChanged(_:))
        addRow(adhanCard, label: t("settings.adhan.sound"), control: adhanSoundPopup)

        adhanOutputPopup = NSPopUpButton(frame: .zero, pullsDown: false)
        adhanOutputPopup.target = self
        adhanOutputPopup.action = #selector(adhanOutputChanged(_:))
        populateAdhanDevices()
        addRow(adhanCard, label: t("settings.adhan.output"), control: adhanOutputPopup)

        let adhanTest = NSButton(title: t("adhkar.settings.test"), target: self,
                                 action: #selector(testAdhan(_:)))
        adhanTest.bezelStyle = .rounded
        addRow(adhanCard, label: t("settings.adhan.sound"), control: adhanTest)

        notificationCheck = NSButton(checkboxWithTitle: t("settings.notif.show"), target: self,
                                     action: #selector(notificationChanged(_:)))
        notificationCheck.state = UserDefaults.standard.bool(forKey: kNotificationsKey) ? .on : .off
        addRow(adhanCard, label: "", control: notificationCheck)

        preAdhanPopup = NSPopUpButton(frame: .zero, pullsDown: false)
        for minutes in kPreAdhanOptions {
            preAdhanPopup.addItem(withTitle: minutes == 0
                ? t("settings.notif.headsup.off")
                : localizedInterfaceDigits(String(format: t("settings.notif.headsup.minutes"), minutes)))
        }
        let currentLead = UserDefaults.standard.integer(forKey: kPreAdhanLeadMinutes)
        preAdhanPopup.selectItem(at: kPreAdhanOptions.firstIndex(of: currentLead) ?? 0)
        preAdhanPopup.target = self
        preAdhanPopup.action = #selector(preAdhanChanged(_:))
        addRow(adhanCard, label: t("settings.notif.headsup"), control: preAdhanPopup)
            endCard(adhanH)

            sectionHeader(featureText("settings.prayer_modes"),
                          subtitle: featureText("settings.prayer_modes.help"))
            let (modesCard, modesH) = beginCard(rows: prayerLabels.count)
            perPrayerModePopups.removeAll()
            let prayerKeys = ["prayer.fajr", "prayer.dhuhr", "prayer.asr",
                              "prayer.maghrib", "prayer.isha"]
            for index in prayerLabels.indices {
                let popup = NSPopUpButton(frame: .zero, pullsDown: false)
                popup.addItems(withTitles: [featureText("adhan.mode.off"),
                                             featureText("adhan.mode.notify"),
                                             featureText("adhan.mode.play")])
                popup.selectItem(at: adhanModeForPrayer(index).rawValue)
                popup.tag = index
                popup.target = self
                popup.action = #selector(perPrayerModeChanged(_:))
                popup.setAccessibilityLabel(t(prayerKeys[index]))
                popup.setAccessibilityValue(popup.titleOfSelectedItem)
                perPrayerModePopups.append(popup)
                addRow(modesCard, label: t(prayerKeys[index]), control: popup)
            }
            endCard(modesH)
        }

        if selectedSection == .adhkar {
            // Adhkar-specific sound and schedule settings share the same
            // settings window without becoming another long scrolling page.
            sectionHeader(t("settings.section.adhkar"))
            let (adhkarCard, adhkarH) = beginCard(rows: 7)
        adhkarAutoPlayCheck = NSButton(checkboxWithTitle: t("adhkar.settings.autoplay"),
                                      target: self,
                                      action: #selector(adhkarAutoPlayChanged(_:)))
        adhkarAutoPlayCheck.state = UserDefaults.standard.bool(forKey: kAdhkarEnabled) ? .on : .off
        addRow(adhkarCard, label: "", control: adhkarAutoPlayCheck)

        let volume = UserDefaults.standard.object(forKey: kAdhkarVolume) == nil
            ? 1.0 : Double(UserDefaults.standard.float(forKey: kAdhkarVolume))
        adhkarVolumeSlider = NSSlider(value: volume, minValue: 0, maxValue: 1,
                                      target: self,
                                      action: #selector(adhkarVolumeChanged(_:)))
        addRow(adhkarCard, label: t("adhkar.settings.volume"), control: adhkarVolumeSlider)

        adhkarOutputPopup = NSPopUpButton(frame: .zero, pullsDown: false)
        adhkarOutputPopup.target = self
        adhkarOutputPopup.action = #selector(adhkarOutputChanged(_:))
        populateAdhkarDevices()
        addRow(adhkarCard, label: t("adhkar.settings.output_device"), control: adhkarOutputPopup)

        let adhkarTest = NSButton(title: t("adhkar.settings.test"), target: self,
                                  action: #selector(testAdhkar(_:)))
        adhkarTest.bezelStyle = .rounded
        addRow(adhkarCard, label: t("adhkar.settings.sound"), control: adhkarTest)

        morningPopup = NSPopUpButton(frame: .zero, pullsDown: false)
        morningPopup.addItems(withTitles: [t("adhkar.editor.schedule.shuruq"),
                                            t("adhkar.editor.schedule.fajr")])
        let morningAnchor = AdhkarLibrary.load().first(where: {
            $0.categoryKey == AdhkarSet.morning.rawValue
        })?.anchorKind ?? "shuruq"
        morningPopup.selectItem(at: morningAnchor == "fajr" ? 1 : 0)
        morningPopup.target = self
        morningPopup.action = #selector(morningAnchorChanged(_:))
        addRow(adhkarCard, label: t("adhkar.settings.morning_anchor"), control: morningPopup)

        eveningPopup = NSPopUpButton(frame: .zero, pullsDown: false)
        eveningPopup.addItems(withTitles: [t("adhkar.editor.schedule.asr"),
                                            t("adhkar.editor.schedule.maghrib")])
        let eveningAnchor = AdhkarLibrary.load().first(where: {
            $0.categoryKey == AdhkarSet.evening.rawValue
        })?.anchorKind ?? "asr"
        eveningPopup.selectItem(at: eveningAnchor == "maghrib" ? 1 : 0)
        eveningPopup.target = self
        eveningPopup.action = #selector(eveningAnchorChanged(_:))
        addRow(adhkarCard, label: t("adhkar.settings.evening_anchor"), control: eveningPopup)

        afterAdhanDelayPopup = NSPopUpButton(frame: .zero, pullsDown: false)
        for minutes in kAdhkarAfterAdhanOptions {
            let title = minutes == 0
                ? featureText("adhkar.after_adhan.immediate")
                : localizedInterfaceDigits(String(format: featureText("adhkar.after_adhan.minutes"), minutes))
            afterAdhanDelayPopup.addItem(withTitle: title)
        }
        let savedDelay = UserDefaults.standard.integer(forKey: kAdhkarAfterAdhanDelay)
        afterAdhanDelayPopup.selectItem(at:
            kAdhkarAfterAdhanOptions.firstIndex(of: savedDelay) ?? 0)
        afterAdhanDelayPopup.target = self
        afterAdhanDelayPopup.action = #selector(afterAdhanDelayChanged(_:))
        addRow(adhkarCard, label: featureText("adhkar.after_adhan"),
               control: afterAdhanDelayPopup)
            endCard(adhkarH)
        }

        let footer = NSTextField(labelWithString: "Salat Time v\(kAppVersion) · Hisn al-Muslim")
        footer.font = Localizer.shared.font(size: 11)
        footer.textColor = .tertiaryLabelColor
        footer.alignment = .center
        footer.frame = NSRect(x: cardX, y: y, width: cardW, height: 18)
        fitLocalizedLabel(footer)
        body.addSubview(footer)
        y += 38
        body.frame = NSRect(x: 0, y: 0, width: width, height: y)
    }

    private func populatePopup(_ popup: NSPopUpButton,
                               devices: inout [AudioOutputDevice], key: String) {
        popup.removeAllItems()
        popup.addItem(withTitle: t("settings.adhan.output.default"))
        devices = listAudioOutputDevices()
        let selectedUID = UserDefaults.standard.string(forKey: key) ?? ""
        for device in devices {
            popup.addItem(withTitle: device.name)
            if device.uid == selectedUID { popup.selectItem(at: popup.numberOfItems - 1) }
        }
        if selectedUID.isEmpty { popup.selectItem(at: 0) }
    }

    private func populateAdhanDevices() {
        guard adhanOutputPopup != nil else { return }
        populatePopup(adhanOutputPopup, devices: &adhanOutputDevices,
                      key: kAdhanAudioDevice)
    }
    private func populateAdhkarDevices() {
        guard adhkarOutputPopup != nil else { return }
        populatePopup(adhkarOutputPopup, devices: &adhkarOutputDevices,
                      key: kAdhkarAudioDevice)
    }

    func tabDidActivate() {
        embeddedMosquePicker?.refreshCurrentMode()
        populateAdhanDevices()
        populateAdhkarDevices()
    }

    @objc private func languageChanged(_ sender: NSPopUpButton) {
        guard kSupportedLanguages.indices.contains(sender.indexOfSelectedItem) else { return }
        Localizer.shared.setLanguage(kSupportedLanguages[sender.indexOfSelectedItem].code)
    }
    @objc private func appearanceChanged(_ sender: NSSegmentedControl) {
        UserDefaults.standard.set(["system", "light", "dark"][sender.selectedSegment],
                                  forKey: kAppearanceKey)
        appDelegate?.applyAppearancePref()
        appDelegate?.applyThemeChange()
    }
    @objc private func accentTapped(_ sender: AccentSwatchButton) {
        UserDefaults.standard.set(sender.accentKey, forKey: kAccentPref)
        accentSwatches.forEach { $0.isSelectedSwatch = ($0 === sender) }
        appDelegate?.applyThemeChange()
    }
    @objc private func materialChanged(_ sender: NSSegmentedControl) {
        UserDefaults.standard.set(sender.selectedSegment == 1 ? "glass" : "opaque",
                                  forKey: kMaterialPref)
        appDelegate?.applyThemeChange()
    }
    @objc private func timeFormatChanged(_ sender: NSSegmentedControl) {
        UserDefaults.standard.set(sender.selectedSegment == 1 ? "12h" : "24h",
                                  forKey: kTimeFormat)
        appDelegate?.updateUI()
        appDelegate?.rebuildStatusItem()
    }
    @objc private func dashboardCountdownChanged(_ sender: NSButton) {
        UserDefaults.standard.set(sender.state == .on, forKey: kPrayerShowCountdown)
        appDelegate?.mainWindow?.reloadPrayerDashboard()
    }
    @objc private func numeralStyleChanged(_ sender: NSSegmentedControl) {
        let style: ArabicDigitStyle = sender.selectedSegment == 1 ? .arabicIndic : .western
        UserDefaults.standard.set(style.rawValue, forKey: kArabicDigitStyle)
        // Dates, translated copy, countdowns, and custom-drawn views all read
        // this preference at construction time, so rebuild the localization
        // surfaces through the same proven path used by a language change.
        appDelegate?.applyLanguageChange()
    }
    @objc private func openAtLoginChanged(_ sender: NSButton) {
        if !setOpenAtLogin(sender.state == .on) {
            sender.state = isOpenAtLoginEnabled() ? .on : .off
        }
    }
    @objc private func menuBarToggleChanged(_ sender: NSButton) {
        UserDefaults.standard.set(barIconCheck.state == .on, forKey: kBarShowIcon)
        UserDefaults.standard.set(barTimeCheck.state == .on, forKey: kBarShowTime)
        UserDefaults.standard.set(barCountdownCheck.state == .on,
                                  forKey: kBarShowCountdown)
        appDelegate?.rebuildStatusItem()
    }
    @objc private func barHijriFormatChanged(_ sender: NSPopUpButton) {
        guard kHijriFormatOrder.indices.contains(sender.indexOfSelectedItem) else { return }
        let format = kHijriFormatOrder[sender.indexOfSelectedItem]
        UserDefaults.standard.set(format.rawValue, forKey: kBarHijriFormat)
        UserDefaults.standard.set(format != .off, forKey: kBarShowHijri)
        appDelegate?.rebuildStatusItem()
    }
    @objc private func adhanEnabledChanged(_ sender: NSButton) {
        UserDefaults.standard.set(sender.state == .on, forKey: kAdhanEnabled)
    }
    @objc private func adhanSoundChanged(_ sender: NSPopUpButton) {
        guard adhanCatalog.indices.contains(sender.indexOfSelectedItem) else { return }
        setCurrentAdhan(adhanCatalog[sender.indexOfSelectedItem].id)
    }
    @objc private func adhanOutputChanged(_ sender: NSPopUpButton) {
        let index = sender.indexOfSelectedItem - 1
        UserDefaults.standard.set(index >= 0 && adhanOutputDevices.indices.contains(index)
            ? adhanOutputDevices[index].uid : "", forKey: kAdhanAudioDevice)
    }
    @objc private func testAdhan(_ sender: NSButton) {
        guard let app = appDelegate else { return }
        app.isAdhanPlaying ? app.stopAdhan() : app.playAdhan()
    }
    @objc private func notificationChanged(_ sender: NSButton) {
        let enabled = sender.state == .on
        UserDefaults.standard.set(enabled, forKey: kNotificationsKey)
        if enabled { appDelegate?.requestNotificationAuthorization() }
    }
    @objc private func preAdhanChanged(_ sender: NSPopUpButton) {
        guard kPreAdhanOptions.indices.contains(sender.indexOfSelectedItem) else { return }
        let minutes = kPreAdhanOptions[sender.indexOfSelectedItem]
        UserDefaults.standard.set(minutes, forKey: kPreAdhanLeadMinutes)
        if minutes > 0 { appDelegate?.requestNotificationAuthorization() }
    }
    @objc private func perPrayerModeChanged(_ sender: NSPopUpButton) {
        guard prayerLabels.indices.contains(sender.tag),
              let mode = AdhanMode(rawValue: sender.indexOfSelectedItem) else { return }
        setAdhanMode(mode, forPrayer: sender.tag)
        sender.setAccessibilityValue(sender.titleOfSelectedItem)
        appDelegate?.updateUI()
        appDelegate?.mainWindow?.reloadPrayerDashboard()
    }
    @objc private func adhkarAutoPlayChanged(_ sender: NSButton) {
        UserDefaults.standard.set(sender.state == .on, forKey: kAdhkarEnabled)
    }
    @objc private func adhkarVolumeChanged(_ sender: NSSlider) {
        UserDefaults.standard.set(Float(sender.floatValue), forKey: kAdhkarVolume)
    }
    @objc private func adhkarOutputChanged(_ sender: NSPopUpButton) {
        let index = sender.indexOfSelectedItem - 1
        UserDefaults.standard.set(index >= 0 && adhkarOutputDevices.indices.contains(index)
            ? adhkarOutputDevices[index].uid : "", forKey: kAdhkarAudioDevice)
    }
    @objc private func testAdhkar(_ sender: NSButton) {
        if adhkarTestSession.isPlaying || adhkarTestSession.isPaused {
            adhkarTestSession.stop()
            return
        }
        guard let collection = AdhkarLibrary.load().first(where: { !$0.items.isEmpty }),
              let item = collection.items.first else { return }
        var preview = collection
        preview.items = [item]
        adhkarTestSession.start(collection: preview)
    }
    @objc private func morningAnchorChanged(_ sender: NSPopUpButton) {
        updateBuiltInAdhkarSchedule(.morning,
            anchor: sender.indexOfSelectedItem == 1 ? "fajr" : "shuruq")
    }
    @objc private func eveningAnchorChanged(_ sender: NSPopUpButton) {
        updateBuiltInAdhkarSchedule(.evening,
            anchor: sender.indexOfSelectedItem == 1 ? "maghrib" : "asr")
    }
    @objc private func afterAdhanDelayChanged(_ sender: NSPopUpButton) {
        guard kAdhkarAfterAdhanOptions.indices.contains(sender.indexOfSelectedItem) else { return }
        UserDefaults.standard.set(kAdhkarAfterAdhanOptions[sender.indexOfSelectedItem],
                                  forKey: kAdhkarAfterAdhanDelay)
    }
}

// ============================================================================
// MARK: Adhkar editor — two-pane collection manager (phase 4)
// ============================================================================
/// Full adhkar editor. Left pane: list of collections (add/select/rename/
/// delete). Right pane: items in the selected collection (add from library,
/// add custom, reorder, remove, pick audio per item). All edits persist to
/// UserDefaults immediately via AdhkarLibrary.save().
final class AdhkarEditorViewController: NSViewController, MainTabContent {

    weak var appDelegate: AppDelegate?

    // Data
    private var collections: [AdhkarCollection] = []
    private var selectedCollectionID: UUID?

    // Layout pieces
    private var collectionView: NSScrollView!
    private var collectionList: NSStackView!
    private var itemsContainer: NSView!
    private var itemsScrollView: NSScrollView!
    private var itemsStack: NSStackView!
    private var itemsHeaderLabel: NSTextField!
    private var emptyStateLabel: NSTextField!
    private var collectionSchedulePopup: NSPopUpButton!
    private var collectionAutoPlayCheck: NSButton!
    private let scheduleKinds = ["manual", "shuruq", "fajr", "dhuhr",
                                 "asr", "maghrib", "isha"]

    // Inline player bar
    private var playerBar: NSView!
    private var playerPlayBtn: HoverIconButton!
    private var playerPositionLabel: NSTextField!
    private var playerVolumeSlider: NSSlider!
    private var playerSettingsBtn: HoverIconButton!

    // The inline playback session (separate from AdhkarPanel's session).
    private let session = AdhkarSession()
    /// Index of the currently-highlighted card (-1 = none).
    private var highlightedCardIndex = -1

    // Preview uses the same clean-segment/exact-wording pipeline as the
    // reader so Settings never auditions the unwanted spoken instructions.
    private let previewSession = AdhkarSession()

    init(appDelegate: AppDelegate) {
        self.appDelegate = appDelegate
        super.init(nibName: nil, bundle: nil)
    }
    required init?(coder: NSCoder) { fatalError() }

    override func loadView() {
        let v = NSView()
        buildTwoPaneLayout(into: v)
        self.view = v
        wireSession()
    }

    func tabDidActivate() {
        reloadFromStorage()
    }

    // MARK: - inline playback session

    private func wireSession() {
        session.onItemChange = { [weak self] item, idx, total in
            DispatchQueue.main.async {
                self?.updatePlayerForItem(item, idx: idx, total: total)
            }
        }
        session.onPlaybackStateChange = { [weak self] in
            DispatchQueue.main.async { self?.refreshPlayerButton() }
        }
        session.onFinish = { [weak self] in
            DispatchQueue.main.async { self?.resetPlayer() }
        }
    }

    private func updatePlayerForItem(_ item: AdhkarEntry, idx: Int, total: Int) {
        playerPositionLabel.stringValue = "\(idx + 1) / \(total)"
        highlightCard(at: idx)
        refreshPlayerButton()
    }

    private func refreshPlayerButton() {
        let playing = session.isPlaying
        let sym = playing ? "pause.fill" : "play.fill"
        if let img = templateSymbol(sym, pointSize: 16) {
            playerPlayBtn.image = img
        }
        playerPlayBtn.toolTip = playing ? t("adhkar.pause") : t("adhkar.play")
    }

    private func resetPlayer() {
        playerPositionLabel.stringValue = "— / —"
        highlightedCardIndex = -1
        refreshCardsHighlight()
        refreshPlayerButton()
    }

    /// Highlight the card at the given index and scroll to it.
    private func highlightCard(at idx: Int) {
        highlightedCardIndex = idx
        refreshCardsHighlight()
        // Scroll the card into view.
        let cards = itemsStack.arrangedSubviews
        if idx >= 0 && idx < cards.count {
            let cardFrame = cards[idx].frame
            itemsScrollView.scrollToVisible(cardFrame)
        }
    }

    /// Apply/remove highlight backgrounds on all cards.
    private func refreshCardsHighlight() {
        for (i, card) in itemsStack.arrangedSubviews.enumerated() {
            // Remove old highlight subviews (identified).
            card.subviews.filter {
                $0.identifier?.rawValue == "adhkar_highlight"
            }.forEach { $0.removeFromSuperview() }
            if i == highlightedCardIndex {
                let pair = currentAccentPair()
                let hl = AdaptiveBackgroundView(frame: card.bounds,
                                                 light: pair.light.withAlphaComponent(0.18),
                                                 dark:  pair.dark.withAlphaComponent(0.25),
                                                 radius: 10)
                hl.identifier = NSUserInterfaceItemIdentifier("adhkar_highlight")
                hl.autoresizingMask = [.width, .height]
                card.addSubview(hl)
                // NSView doesn't have sendSubviewToBack; addSubview puts it
                // on top, but AdaptiveBackgroundView.hitTest returns nil so
                // it's transparent to clicks. Visual layering: since it's
                // decorative and semi-transparent, drawing on top is fine.
            }
        }
    }

    // Player bar actions
    @objc private func playerTogglePlay(_ sender: Any?) {
        if session.isPlaying { session.pause() }
        else if session.isPaused { session.resume() }
        else if let c = selectedCollection() {
            session.start(collection: c)
        }
    }
    @objc private func playerPrev(_ sender: Any?) { session.previous() }
    @objc private func playerNext(_ sender: Any?) { session.next() }
    @objc private func playerVolumeChanged(_ sender: NSSlider) {
        UserDefaults.standard.set(Float(sender.floatValue), forKey: kAdhkarVolume)
        session.setMuted(sender.floatValue == 0)
    }
    @objc private func playerSettingsTapped(_ sender: HoverIconButton) {
        showAdhkarSettingsMenu(from: sender)
    }


    // MARK: - load / save

    private func reloadFromStorage() {
        collections = AdhkarLibrary.load()
        if selectedCollectionID == nil || !collections.contains(where: { $0.id == selectedCollectionID }) {
            selectedCollectionID = collections.first?.id
        }
        rebuildCollectionList()
        rebuildItemsPane()
    }

    private func persist() {
        AdhkarLibrary.save(collections)
    }

    // MARK: - two-pane layout

    private func buildTwoPaneLayout(into root: NSView) {
        let divider = NSBox()
        divider.boxType = .separator
        divider.translatesAutoresizingMaskIntoConstraints = false

        // For RTL (Arabic): the collections sidebar goes on the RIGHT, items
        // pane on the LEFT. For LTR: sidebar on the left, items on the right.
        let isRTL = Localizer.shared.isRTL

        // ---- collections sidebar ----
        // Subtle visual-effect panel for the collections list — gives depth
        // separation from the items pane without being heavy.
        let leftWrap = NSVisualEffectView()
        leftWrap.material = .sidebar
        leftWrap.blendingMode = .withinWindow
        leftWrap.state = .active
        leftWrap.translatesAutoresizingMaskIntoConstraints = false
        if isRTL { leftWrap.userInterfaceLayoutDirection = .rightToLeft }
        root.addSubview(leftWrap)

        let collectionsTitle = NSTextField(labelWithString: t("adhkar.editor.collections"))
        collectionsTitle.font = Localizer.shared.font(size: 11, weight: .semibold)
        collectionsTitle.textColor = .tertiaryLabelColor
        collectionsTitle.alignment = isRTL ? .right : .left
        collectionsTitle.baseWritingDirection = isRTL ? .rightToLeft : .leftToRight
        collectionsTitle.translatesAutoresizingMaskIntoConstraints = false
        leftWrap.addSubview(collectionsTitle)

        let newBtn = NSButton(title: "+  \(t("adhkar.editor.new_collection"))",
                               target: self, action: #selector(newCollection))
        newBtn.bezelStyle = .rounded
        newBtn.controlSize = .small
        newBtn.translatesAutoresizingMaskIntoConstraints = false
        leftWrap.addSubview(newBtn)

        collectionList = NSStackView()
        collectionList.orientation = .vertical
        collectionList.alignment = isRTL ? .trailing : .leading
        collectionList.distribution = .fill
        collectionList.spacing = 4
        collectionList.edgeInsets = NSEdgeInsets(top: 2, left: 0, bottom: 8, right: 0)
        collectionList.translatesAutoresizingMaskIntoConstraints = false

        collectionView = NSScrollView()
        collectionView.documentView = collectionList
        collectionView.hasVerticalScroller = true
        collectionView.drawsBackground = false
        collectionView.translatesAutoresizingMaskIntoConstraints = false
        collectionView.hasHorizontalScroller = false
        collectionView.contentView.drawsBackground = false
        // autoresizingMask = .width makes the stack match the scroll view's
        // width. Height is natural (sum of rows), so it scrolls when needed.
        collectionList.autoresizingMask = [.width]
        leftWrap.addSubview(collectionView)

        // ---- items pane ----
        itemsContainer = NSView()
        itemsContainer.translatesAutoresizingMaskIntoConstraints = false
        if isRTL { itemsContainer.userInterfaceLayoutDirection = .rightToLeft }
        root.addSubview(itemsContainer)

        itemsHeaderLabel = NSTextField(labelWithString: "")
        itemsHeaderLabel.font = Localizer.shared.font(size: 18, weight: .bold)
        itemsHeaderLabel.alignment = isRTL ? .right : .left
        itemsHeaderLabel.baseWritingDirection = isRTL ? .rightToLeft : .leftToRight
        itemsHeaderLabel.translatesAutoresizingMaskIntoConstraints = false
        itemsHeaderLabel.textColor = .labelColor
        itemsContainer.addSubview(itemsHeaderLabel)

        // Scheduling is a first-class setting for the selected collection.
        // It used to exist only in a right-click menu, which made autoplay
        // nearly impossible to discover or trust.
        collectionSchedulePopup = NSPopUpButton(frame: .zero, pullsDown: false)
        collectionSchedulePopup.addItems(withTitles: scheduleKinds.map { scheduleLabel($0) })
        collectionSchedulePopup.target = self
        collectionSchedulePopup.action = #selector(selectedScheduleChanged(_:))
        collectionSchedulePopup.translatesAutoresizingMaskIntoConstraints = false
        itemsContainer.addSubview(collectionSchedulePopup)

        collectionAutoPlayCheck = NSButton(
            checkboxWithTitle: t("adhkar.editor.autoplay"), target: self,
            action: #selector(selectedAutoPlayChanged(_:)))
        collectionAutoPlayCheck.translatesAutoresizingMaskIntoConstraints = false
        itemsContainer.addSubview(collectionAutoPlayCheck)

        let addLibBtn = NSButton(title: t("adhkar.editor.add_from_library"),
                                  target: self, action: #selector(addFromLibrary))
        addLibBtn.bezelStyle = .rounded
        addLibBtn.controlSize = .small
        addLibBtn.translatesAutoresizingMaskIntoConstraints = false
        itemsContainer.addSubview(addLibBtn)

        let addCustomBtn = NSButton(title: t("adhkar.editor.add_custom"),
                                     target: self, action: #selector(addCustom))
        addCustomBtn.bezelStyle = .rounded
        addCustomBtn.controlSize = .small
        addCustomBtn.translatesAutoresizingMaskIntoConstraints = false
        itemsContainer.addSubview(addCustomBtn)

        itemsStack = NSStackView()
        itemsStack.orientation = .vertical
        itemsStack.alignment = .leading
        itemsStack.distribution = .fill
        itemsStack.spacing = 8
        itemsStack.edgeInsets = NSEdgeInsets(top: 4, left: 0, bottom: 8, right: 0)
        itemsStack.translatesAutoresizingMaskIntoConstraints = false

        itemsScrollView = NSScrollView()
        itemsScrollView.documentView = itemsStack
        itemsScrollView.hasVerticalScroller = true
        itemsScrollView.drawsBackground = false
        itemsScrollView.translatesAutoresizingMaskIntoConstraints = false
        itemsScrollView.hasHorizontalScroller = false
        itemsScrollView.autohidesScrollers = true
        itemsContainer.addSubview(itemsScrollView)

        // ---- inline player bar ----
        // Sits between the add-buttons and the scroll view. Shows play/pause,
        // prev/next, position, volume slider, and a settings gear.
        // An appearance-aware native card remains legible in both light and
        // dark mode. The previous hard-coded white border disappeared on
        // light backgrounds and made the player feel detached from the list.
        let adaptivePlayerBar = AdaptiveCardView(frame: .zero)
        adaptivePlayerBar.cornerRadius = 10
        playerBar = adaptivePlayerBar
        playerBar.translatesAutoresizingMaskIntoConstraints = false
        itemsContainer.addSubview(playerBar)

        playerPlayBtn = HoverIconButton(symbol: "play.fill",
                                         toolTip: t("adhkar.play"),
                                         target: self,
                                         action: #selector(playerTogglePlay(_:)),
                                         pointSize: 16,
                                         size: NSSize(width: 36, height: 30))
        playerPlayBtn.translatesAutoresizingMaskIntoConstraints = false
        playerBar.addSubview(playerPlayBtn)

        let playerPrevBtn = HoverIconButton(symbol: "backward.fill",
                                              toolTip: t("adhkar.prev"),
                                              target: self,
                                              action: #selector(playerPrev(_:)),
                                              pointSize: 13,
                                              size: NSSize(width: 30, height: 30))
        playerPrevBtn.translatesAutoresizingMaskIntoConstraints = false
        playerBar.addSubview(playerPrevBtn)

        let playerNextBtn = HoverIconButton(symbol: "forward.fill",
                                              toolTip: t("adhkar.next"),
                                              target: self,
                                              action: #selector(playerNext(_:)),
                                              pointSize: 13,
                                              size: NSSize(width: 30, height: 30))
        playerNextBtn.translatesAutoresizingMaskIntoConstraints = false
        playerBar.addSubview(playerNextBtn)

        playerPositionLabel = NSTextField(labelWithString: "— / —")
        playerPositionLabel.font = Localizer.shared.font(size: 12)
        playerPositionLabel.textColor = .secondaryLabelColor
        playerPositionLabel.alignment = .center
        playerPositionLabel.translatesAutoresizingMaskIntoConstraints = false
        playerBar.addSubview(playerPositionLabel)

        let volumeIcon = NSImageView()
        volumeIcon.image = templateSymbol("speaker.wave.2.fill", pointSize: 12)
        volumeIcon.contentTintColor = .secondaryLabelColor
        volumeIcon.imageScaling = .scaleProportionallyDown
        volumeIcon.setAccessibilityLabel(t("settings.adhan.volume"))
        volumeIcon.translatesAutoresizingMaskIntoConstraints = false
        playerBar.addSubview(volumeIcon)

        playerVolumeSlider = NSSlider(value: Double(UserDefaults.standard.float(forKey: kAdhkarVolume)),
                                       minValue: 0, maxValue: 1,
                                       target: self,
                                       action: #selector(playerVolumeChanged(_:)))
        playerVolumeSlider.translatesAutoresizingMaskIntoConstraints = false
        playerBar.addSubview(playerVolumeSlider)

        playerSettingsBtn = HoverIconButton(symbol: "airplayaudio",
                                              toolTip: t("adhkar.editor.audio"),
                                              target: self,
                                              action: #selector(playerSettingsTapped(_:)),
                                              pointSize: 14,
                                              size: NSSize(width: 32, height: 30))
        playerSettingsBtn.translatesAutoresizingMaskIntoConstraints = false
        playerBar.addSubview(playerSettingsBtn)

        emptyStateLabel = NSTextField(labelWithString: t("adhkar.editor.no_collection_selected"))
        emptyStateLabel.font = Localizer.shared.font(size: 13)
        emptyStateLabel.textColor = .tertiaryLabelColor
        emptyStateLabel.alignment = .center
        emptyStateLabel.baseWritingDirection = isRTL ? .rightToLeft : .leftToRight
        emptyStateLabel.translatesAutoresizingMaskIntoConstraints = false
        itemsContainer.addSubview(emptyStateLabel)

        root.addSubview(divider)

        // Layout: sidebar + divider + items pane, with order swapped for RTL.
        // The constraints below use `leading/trailing` anchors so they flip
        // automatically with userInterfaceLayoutDirection.
        NSLayoutConstraint.activate([
            // Sidebar: leading edge in LTR, trailing edge (right) in RTL.
            leftWrap.topAnchor.constraint(equalTo: root.topAnchor),
            leftWrap.bottomAnchor.constraint(equalTo: root.bottomAnchor),
            leftWrap.widthAnchor.constraint(equalToConstant: 238),

            collectionsTitle.topAnchor.constraint(equalTo: leftWrap.topAnchor, constant: 18),
            collectionsTitle.leadingAnchor.constraint(equalTo: leftWrap.leadingAnchor, constant: 12),
            collectionsTitle.trailingAnchor.constraint(equalTo: leftWrap.trailingAnchor, constant: -12),

            newBtn.topAnchor.constraint(equalTo: collectionsTitle.bottomAnchor, constant: 8),
            newBtn.leadingAnchor.constraint(equalTo: leftWrap.leadingAnchor, constant: 8),
            newBtn.trailingAnchor.constraint(equalTo: leftWrap.trailingAnchor, constant: -8),

            collectionView.topAnchor.constraint(equalTo: newBtn.bottomAnchor, constant: 10),
            collectionView.leadingAnchor.constraint(equalTo: leftWrap.leadingAnchor, constant: 6),
            collectionView.trailingAnchor.constraint(equalTo: leftWrap.trailingAnchor, constant: -4),
            collectionView.bottomAnchor.constraint(equalTo: leftWrap.bottomAnchor, constant: -8),
        ])

        if isRTL {
            // RTL: sidebar on the RIGHT, items pane on the LEFT.
            NSLayoutConstraint.activate([
                leftWrap.trailingAnchor.constraint(equalTo: root.trailingAnchor),

                divider.trailingAnchor.constraint(equalTo: leftWrap.leadingAnchor),
                divider.topAnchor.constraint(equalTo: root.topAnchor),
                divider.bottomAnchor.constraint(equalTo: root.bottomAnchor),

                itemsContainer.trailingAnchor.constraint(equalTo: divider.leadingAnchor, constant: -24),
                itemsContainer.leadingAnchor.constraint(equalTo: root.leadingAnchor, constant: 24),
                itemsContainer.topAnchor.constraint(equalTo: root.topAnchor, constant: 20),
                itemsContainer.bottomAnchor.constraint(equalTo: root.bottomAnchor, constant: -18),
            ])
        } else {
            // LTR: sidebar on the LEFT, items pane on the RIGHT.
            NSLayoutConstraint.activate([
                leftWrap.leadingAnchor.constraint(equalTo: root.leadingAnchor),

                divider.leadingAnchor.constraint(equalTo: leftWrap.trailingAnchor),
                divider.topAnchor.constraint(equalTo: root.topAnchor),
                divider.bottomAnchor.constraint(equalTo: root.bottomAnchor),

                itemsContainer.leadingAnchor.constraint(equalTo: divider.trailingAnchor, constant: 24),
                itemsContainer.trailingAnchor.constraint(equalTo: root.trailingAnchor, constant: -24),
                itemsContainer.topAnchor.constraint(equalTo: root.topAnchor, constant: 20),
                itemsContainer.bottomAnchor.constraint(equalTo: root.bottomAnchor, constant: -18),
            ])
        }

        NSLayoutConstraint.activate([
            itemsHeaderLabel.topAnchor.constraint(equalTo: itemsContainer.topAnchor),
            itemsHeaderLabel.leadingAnchor.constraint(equalTo: itemsContainer.leadingAnchor),
            itemsHeaderLabel.trailingAnchor.constraint(equalTo: itemsContainer.trailingAnchor),

            collectionSchedulePopup.topAnchor.constraint(equalTo: itemsHeaderLabel.bottomAnchor,
                                                           constant: 10),
            collectionSchedulePopup.leadingAnchor.constraint(equalTo: itemsContainer.leadingAnchor),
            collectionSchedulePopup.widthAnchor.constraint(equalToConstant: 210),
            collectionSchedulePopup.heightAnchor.constraint(equalToConstant: 30),

            collectionAutoPlayCheck.leadingAnchor.constraint(equalTo: collectionSchedulePopup.trailingAnchor,
                                                               constant: 12),
            collectionAutoPlayCheck.centerYAnchor.constraint(equalTo: collectionSchedulePopup.centerYAnchor),
            collectionAutoPlayCheck.trailingAnchor.constraint(lessThanOrEqualTo: itemsContainer.trailingAnchor),

            addLibBtn.topAnchor.constraint(equalTo: collectionSchedulePopup.bottomAnchor, constant: 10),
            addLibBtn.leadingAnchor.constraint(equalTo: itemsContainer.leadingAnchor),

            addCustomBtn.topAnchor.constraint(equalTo: collectionSchedulePopup.bottomAnchor, constant: 10),
            addCustomBtn.leadingAnchor.constraint(equalTo: addLibBtn.trailingAnchor, constant: 8),

            // Player bar: between the add-buttons and the scroll view.
            playerBar.topAnchor.constraint(equalTo: addLibBtn.bottomAnchor, constant: 10),
            playerBar.leadingAnchor.constraint(equalTo: itemsContainer.leadingAnchor),
            playerBar.trailingAnchor.constraint(equalTo: itemsContainer.trailingAnchor),
            playerBar.heightAnchor.constraint(equalToConstant: 40),

            playerPrevBtn.leadingAnchor.constraint(equalTo: playerBar.leadingAnchor, constant: 8),
            playerPrevBtn.centerYAnchor.constraint(equalTo: playerBar.centerYAnchor),
            playerPlayBtn.leadingAnchor.constraint(equalTo: playerPrevBtn.trailingAnchor, constant: 4),
            playerPlayBtn.centerYAnchor.constraint(equalTo: playerBar.centerYAnchor),
            playerNextBtn.leadingAnchor.constraint(equalTo: playerPlayBtn.trailingAnchor, constant: 4),
            playerNextBtn.centerYAnchor.constraint(equalTo: playerBar.centerYAnchor),

            playerPositionLabel.leadingAnchor.constraint(equalTo: playerNextBtn.trailingAnchor, constant: 12),
            playerPositionLabel.centerYAnchor.constraint(equalTo: playerBar.centerYAnchor),
            playerPositionLabel.widthAnchor.constraint(equalToConstant: 60),

            // Volume slider on the trailing side.
            playerVolumeSlider.trailingAnchor.constraint(equalTo: volumeIcon.leadingAnchor, constant: -4),
            playerVolumeSlider.centerYAnchor.constraint(equalTo: playerBar.centerYAnchor),
            playerVolumeSlider.widthAnchor.constraint(equalToConstant: 100),
            volumeIcon.trailingAnchor.constraint(equalTo: playerSettingsBtn.leadingAnchor, constant: -4),
            volumeIcon.centerYAnchor.constraint(equalTo: playerBar.centerYAnchor),
            volumeIcon.widthAnchor.constraint(equalToConstant: 18),
            volumeIcon.heightAnchor.constraint(equalToConstant: 18),
            playerSettingsBtn.trailingAnchor.constraint(equalTo: playerBar.trailingAnchor, constant: -8),
            playerSettingsBtn.centerYAnchor.constraint(equalTo: playerBar.centerYAnchor),

            // Scroll view below the player bar.
            itemsScrollView.topAnchor.constraint(equalTo: playerBar.bottomAnchor, constant: 10),
            itemsScrollView.leadingAnchor.constraint(equalTo: itemsContainer.leadingAnchor),
            itemsScrollView.trailingAnchor.constraint(equalTo: itemsContainer.trailingAnchor),
            itemsScrollView.bottomAnchor.constraint(equalTo: itemsContainer.bottomAnchor),

            // Pin the stack's width to the scroll view's CONTENT width (the
            // clip view, which excludes the scroller) so cards never grow to
            // fit long text horizontally — Arabic wraps vertically instead.
            itemsStack.leadingAnchor.constraint(equalTo: itemsScrollView.contentView.leadingAnchor),
            itemsStack.trailingAnchor.constraint(equalTo: itemsScrollView.contentView.trailingAnchor),
            itemsStack.topAnchor.constraint(equalTo: itemsScrollView.contentView.topAnchor),
            itemsStack.heightAnchor.constraint(greaterThanOrEqualTo: itemsScrollView.contentView.heightAnchor),

            emptyStateLabel.centerXAnchor.constraint(equalTo: itemsContainer.centerXAnchor),
            emptyStateLabel.centerYAnchor.constraint(equalTo: itemsContainer.centerYAnchor),
            emptyStateLabel.leadingAnchor.constraint(greaterThanOrEqualTo: itemsContainer.leadingAnchor, constant: 20),
        ])
    }

    // MARK: - collection list (left pane)

    private func rebuildCollectionList() {
        collectionList.arrangedSubviews.forEach { $0.removeFromSuperview() }
        for c in collections {
            let row = makeCollectionRow(c)
            collectionList.addArrangedSubview(row)
            // Pin each row's width to the stack so rows fill the pane.
            row.leadingAnchor.constraint(equalTo: collectionList.leadingAnchor).isActive = true
            row.trailingAnchor.constraint(equalTo: collectionList.trailingAnchor).isActive = true
        }
    }

    private func makeCollectionRow(_ c: AdhkarCollection) -> NSView {
        let row = CollectionRowView()
        row.translatesAutoresizingMaskIntoConstraints = false
        row.wantsLayer = true
        row.layer?.cornerRadius = 8
        row.collectionID = c.id
        let isSel = (c.id == selectedCollectionID)
        row.setAccessibilityRole(.button)
        row.setAccessibilityLabel(c.displayName)
        row.setAccessibilitySelected(isSel)

        // Selection highlight using the app's accent-aware adaptive background
        // (matches the prayer-row highlight pattern), not a raw layer tint.
        if isSel {
            let pair = currentAccentPair()
            row.addSubview(AdaptiveBackgroundView(
                frame: row.bounds,
                light: pair.light.withAlphaComponent(0.14),
                dark:  pair.dark.withAlphaComponent(0.22),
                radius: 8))
        }

        let nameLbl = NSTextField(labelWithString: c.displayName)
        nameLbl.font = Localizer.shared.font(size: 13, weight: isSel ? .semibold : .regular)
        nameLbl.textColor = isSel ? .appGreenAccent : .labelColor
        nameLbl.alignment = Localizer.shared.isRTL ? .right : .left
        nameLbl.baseWritingDirection = Localizer.shared.isRTL ? .rightToLeft : .leftToRight
        nameLbl.translatesAutoresizingMaskIntoConstraints = false
        // Make the label transparent to mouse clicks so they pass through to
        // the row's mouseDown handler (otherwise the label absorbs the click).
        nameLbl.isBezeled = false
        nameLbl.drawsBackground = false
        nameLbl.isSelectable = false
        nameLbl.isEditable = false
        row.addSubview(nameLbl)

        // Schedule badge
        let badgeText: String
        if c.anchorKind == "manual" {
            badgeText = c.autoPlay ? "●" : ""
        } else {
            badgeText = scheduleLabel(c.anchorKind)
        }
        let badge = NSTextField(labelWithString: badgeText)
        badge.font = Localizer.shared.font(size: 10)
        badge.alignment = Localizer.shared.isRTL ? .right : .left
        badge.baseWritingDirection = Localizer.shared.isRTL ? .rightToLeft : .leftToRight
        badge.textColor = .tertiaryLabelColor
        badge.translatesAutoresizingMaskIntoConstraints = false
        row.addSubview(badge)

        // Play button — opens the floating panel and starts recitation.
        // Play button. For RTL, use "backward.fill" (◀) which already points
        // left — much more reliable than flipping images at runtime.
        let playSymbol = Localizer.shared.isRTL ? "backward.fill" : "play.fill"
        let playBtn = HoverIconButton(symbol: playSymbol,
                                       toolTip: t("adhkar.play"),
                                       target: self,
                                       action: #selector(playCollection(_:)),
                                       pointSize: 13,
                                       size: NSSize(width: 40, height: 40))
        playBtn.translatesAutoresizingMaskIntoConstraints = false
        playBtn.identifier = NSUserInterfaceItemIdentifier(c.id.uuidString)
        row.addSubview(playBtn)

        // Select on click via the row's mouseDown handler (more reliable than
        // gesture recognizers, which conflict with the play button subview).
        row.onSelect = { [weak self] id in
            guard let self = self else { return }
            self.selectedCollectionID = id
            // Defer the rebuild to the next run loop — rebuilding inside
            // mouseDown would destroy the clicked row mid-event, causing
            // the click to be lost or crash.
            DispatchQueue.main.async {
                self.rebuildCollectionList()
                self.rebuildItemsPane()
            }
        }

        // Right-click = schedule submenu + delete
        let menu = NSMenu()

        // Schedule submenu — pick the anchor prayer + toggle auto-play.
        let schedItem = NSMenuItem(title: t("adhkar.editor.schedule"),
                                    action: nil, keyEquivalent: "")
        let schedSub = NSMenu()
        let anchors: [(String, String)] = [
            ("manual",  t("adhkar.editor.schedule.manual")),
            ("shuruq",  t("adhkar.editor.schedule.shuruq")),
            ("fajr",    t("adhkar.editor.schedule.fajr")),
            ("dhuhr",   t("adhkar.editor.schedule.dhuhr")),
            ("asr",     t("adhkar.editor.schedule.asr")),
            ("maghrib", t("adhkar.editor.schedule.maghrib")),
            ("isha",    t("adhkar.editor.schedule.isha")),
        ]
        for (kind, label) in anchors {
            let mi = NSMenuItem(title: label, action: #selector(setAnchor(_:)),
                                 keyEquivalent: "")
            mi.target = self
            mi.representedObject = ["id": c.id, "kind": kind] as [String: Any]
            if kind == c.anchorKind { mi.state = .on }
            schedSub.addItem(mi)
        }
        schedSub.addItem(.separator())
        let autoMi = NSMenuItem(title: t("adhkar.editor.autoplay"),
                                 action: #selector(toggleAutoPlay(_:)),
                                 keyEquivalent: "")
        autoMi.target = self
        autoMi.representedObject = c.id
        if c.autoPlay { autoMi.state = .on }
        schedSub.addItem(autoMi)
        schedItem.submenu = schedSub
        menu.addItem(schedItem)

        menu.addItem(.separator())
        // Rename option — reuses the alert-based rename flow.
        let ren = NSMenuItem(title: t("adhkar.editor.renamed"),
                              action: #selector(renameFromMenu(_:)),
                              keyEquivalent: "")
        ren.target = self
        ren.representedObject = c.id
        menu.addItem(ren)
        let del = NSMenuItem(title: t("adhkar.editor.remove"),
                              action: #selector(deleteCollection(_:)),
                              keyEquivalent: "")
        del.target = self
        del.representedObject = c.id
        menu.addItem(del)
        row.menu = menu

        let isRTL = Localizer.shared.isRTL
        NSLayoutConstraint.activate([
            // An exact source-list row height prevents NSStackView from
            // stretching the first row to absorb spare viewport height.
            row.heightAnchor.constraint(equalToConstant: 52),

            // Name: for RTL, anchor to the TRAILING (right) edge with the play
            // button to its LEFT. For LTR, name on leading (left), play on right.
            nameLbl.topAnchor.constraint(equalTo: row.topAnchor, constant: 8),

            badge.topAnchor.constraint(equalTo: nameLbl.bottomAnchor, constant: 2),
            playBtn.centerYAnchor.constraint(equalTo: row.centerYAnchor),
            playBtn.widthAnchor.constraint(equalToConstant: 40),
            playBtn.heightAnchor.constraint(equalToConstant: 40),
        ])

        if isRTL {
            // RTL: play button on the FAR RIGHT (user wants arrows on right),
            // name to its left.
            NSLayoutConstraint.activate([
                playBtn.trailingAnchor.constraint(equalTo: row.trailingAnchor, constant: -8),
                nameLbl.trailingAnchor.constraint(equalTo: playBtn.leadingAnchor, constant: -6),
                nameLbl.leadingAnchor.constraint(greaterThanOrEqualTo: row.leadingAnchor, constant: 10),
                badge.trailingAnchor.constraint(equalTo: nameLbl.trailingAnchor),
            ])
        } else {
            // LTR: name on the left, play button on the right.
            NSLayoutConstraint.activate([
                nameLbl.leadingAnchor.constraint(equalTo: row.leadingAnchor, constant: 10),
                nameLbl.trailingAnchor.constraint(equalTo: playBtn.leadingAnchor, constant: -8),
                playBtn.trailingAnchor.constraint(equalTo: row.trailingAnchor, constant: -10),
                badge.leadingAnchor.constraint(equalTo: nameLbl.leadingAnchor),
            ])
        }
        return row
    }

    private func scheduleLabel(_ kind: String) -> String {
        switch kind {
        case "shuruq":  return t("adhkar.editor.schedule.shuruq")
        case "fajr":    return t("adhkar.editor.schedule.fajr")
        case "dhuhr":   return t("adhkar.editor.schedule.dhuhr")
        case "asr":     return t("adhkar.editor.schedule.asr")
        case "maghrib": return t("adhkar.editor.schedule.maghrib")
        case "isha":    return t("adhkar.editor.schedule.isha")
        default:        return t("adhkar.editor.schedule.manual")
        }
    }

    /// Play button on a collection row — opens the floating panel and starts
    /// reciting the collection. Replaces the removed right-click menu entries.
    @objc private func playCollection(_ sender: HoverIconButton) {
        guard let idStr = sender.identifier?.rawValue,
              let id = UUID(uuidString: idStr),
              let idx = collections.firstIndex(where: { $0.id == id }) else { return }
        // Select this collection and start the inline session.
        selectedCollectionID = id
        rebuildCollectionList()
        rebuildItemsPane()
        session.start(collection: collections[idx])
    }

    /// Rename a collection via alert, triggered from the right-click menu.
    @objc private func renameFromMenu(_ mi: NSMenuItem) {
        guard let id = mi.representedObject as? UUID,
              let idx = collections.firstIndex(where: { $0.id == id }) else { return }
        let alert = NSAlert()
        alert.messageText = t("adhkar.editor.renamed")
        alert.addButton(withTitle: t("adhkar.editor.save"))
        alert.addButton(withTitle: t("adhkar.editor.cancel"))
        let input = NSTextField(frame: NSRect(x: 0, y: 0, width: 240, height: 24))
        input.stringValue = collections[idx].displayName
        alert.accessoryView = input
        alert.window.initialFirstResponder = input
        if alert.runModal() == .alertFirstButtonReturn {
            let trimmed = input.stringValue.trimmingCharacters(in: .whitespaces)
            if !trimmed.isEmpty {
                collections[idx].name = trimmed
                // Renaming a bundled collection turns the name into a true
                // user-owned value instead of replacing it on language change.
                collections[idx].categoryKey = nil
                persist()
                rebuildCollectionList()
                rebuildItemsPane()
            }
        }
    }

    @objc private func setAnchor(_ mi: NSMenuItem) {
        guard let dict = mi.representedObject as? [String: Any],
              let id = dict["id"] as? UUID,
              let kind = dict["kind"] as? String,
              let idx = collections.firstIndex(where: { $0.id == id }) else { return }
        collections[idx].anchorKind = kind
        if collections[idx].categoryKey == AdhkarSet.morning.rawValue {
            UserDefaults.standard.set(kind, forKey: kAdhkarMorningAnchor)
        } else if collections[idx].categoryKey == AdhkarSet.evening.rawValue {
            UserDefaults.standard.set(kind, forKey: kAdhkarEveningAnchor)
        }
        persist(); rebuildCollectionList()
    }
    @objc private func selectedScheduleChanged(_ sender: NSPopUpButton) {
        guard let index = selectedCollectionIndex(),
              scheduleKinds.indices.contains(sender.indexOfSelectedItem) else { return }
        let kind = scheduleKinds[sender.indexOfSelectedItem]
        collections[index].anchorKind = kind
        if collections[index].categoryKey == AdhkarSet.morning.rawValue {
            UserDefaults.standard.set(kind, forKey: kAdhkarMorningAnchor)
        } else if collections[index].categoryKey == AdhkarSet.evening.rawValue {
            UserDefaults.standard.set(kind, forKey: kAdhkarEveningAnchor)
        }
        persist()
        rebuildCollectionList()
    }
    @objc private func selectedAutoPlayChanged(_ sender: NSButton) {
        guard let index = selectedCollectionIndex() else { return }
        collections[index].autoPlay = sender.state == .on
        persist()
        rebuildCollectionList()
    }
    @objc private func toggleAutoPlay(_ mi: NSMenuItem) {
        guard let id = mi.representedObject as? UUID,
              let idx = collections.firstIndex(where: { $0.id == id }) else { return }
        collections[idx].autoPlay.toggle()
        persist(); rebuildCollectionList()
    }

    @objc private func deleteCollection(_ mi: NSMenuItem) {
        guard let id = mi.representedObject as? UUID,
              let idx = collections.firstIndex(where: { $0.id == id }) else { return }
        let alert = NSAlert()
        alert.messageText = t("adhkar.editor.delete_collection")
        alert.informativeText = t("adhkar.editor.delete_collection_msg")
        alert.addButton(withTitle: t("adhkar.editor.remove"))
        alert.addButton(withTitle: t("adhkar.editor.cancel"))
        alert.alertStyle = .warning
        if alert.runModal() == .alertFirstButtonReturn {
            collections.remove(at: idx)
            if selectedCollectionID == id { selectedCollectionID = collections.first?.id }
            persist()
            rebuildCollectionList()
            rebuildItemsPane()
        }
    }

    @objc private func newCollection() {
        let c = AdhkarCollection(name: t("adhkar.editor.untitled"))
        collections.append(c)
        selectedCollectionID = c.id
        persist()
        rebuildCollectionList()
        rebuildItemsPane()
        // Prompt rename immediately
        if let idx = collections.firstIndex(where: { $0.id == c.id }) {
            let alert = NSAlert()
            alert.messageText = t("adhkar.editor.renamed")
            alert.addButton(withTitle: t("adhkar.editor.save"))
            alert.addButton(withTitle: t("adhkar.editor.cancel"))
            let input = NSTextField(frame: NSRect(x: 0, y: 0, width: 240, height: 24))
            input.stringValue = c.name
            alert.accessoryView = input
            alert.window.initialFirstResponder = input
            if alert.runModal() == .alertFirstButtonReturn {
                let trimmed = input.stringValue.trimmingCharacters(in: .whitespaces)
                if !trimmed.isEmpty {
                    collections[idx].name = trimmed
                    persist()
                    rebuildCollectionList()
                    rebuildItemsPane()
                }
            }
        }
    }

    // MARK: - items pane (right)

    private func rebuildItemsPane() {
        itemsStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        guard let id = selectedCollectionID,
              let idx = collections.firstIndex(where: { $0.id == id }) else {
            itemsHeaderLabel.stringValue = ""
            collectionSchedulePopup.isEnabled = false
            collectionAutoPlayCheck.isEnabled = false
            emptyStateLabel.isHidden = false
            itemsScrollView.isHidden = true
            return
        }
        let c = collections[idx]
        collectionSchedulePopup.isEnabled = true
        collectionAutoPlayCheck.isEnabled = true
        collectionSchedulePopup.selectItem(at: scheduleKinds.firstIndex(of: c.anchorKind) ?? 0)
        collectionAutoPlayCheck.state = c.autoPlay ? .on : .off
        itemsHeaderLabel.stringValue = String(format: t("adhkar.editor.items_in"), c.displayName)
        emptyStateLabel.isHidden = !c.items.isEmpty
        itemsScrollView.isHidden = c.items.isEmpty
        if c.items.isEmpty {
            emptyStateLabel.stringValue = t("adhkar.editor.empty_collection")
        }
        for (i, entry) in c.items.enumerated() {
            let card = makeItemCard(entry, index: i, collectionIndex: idx)
            itemsStack.addArrangedSubview(card)
            // Pin each card's width to the stack so it always spans the full
            // available width and Arabic text wraps inside instead of stretching.
            card.leadingAnchor.constraint(equalTo: itemsStack.leadingAnchor).isActive = true
            card.trailingAnchor.constraint(equalTo: itemsStack.trailingAnchor).isActive = true
        }
        // A dedicated flexible tail absorbs spare viewport height. Without
        // it NSStackView stretches an item card, which is the same failure
        // mode that previously pushed collection rows toward the bottom.
        if !c.items.isEmpty {
            let tail = NSView()
            tail.translatesAutoresizingMaskIntoConstraints = false
            tail.setContentHuggingPriority(.defaultLow, for: .vertical)
            tail.setContentCompressionResistancePriority(.defaultLow, for: .vertical)
            itemsStack.addArrangedSubview(tail)
            tail.leadingAnchor.constraint(equalTo: itemsStack.leadingAnchor).isActive = true
            tail.trailingAnchor.constraint(equalTo: itemsStack.trailingAnchor).isActive = true
            tail.heightAnchor.constraint(greaterThanOrEqualToConstant: 0).isActive = true
        }
    }

    private func makeItemCard(_ entry: AdhkarEntry, index: Int, collectionIndex: Int) -> NSView {
        // Card: translucent "frosted" background with subtle border — looks
        // elegant on the Liquid Glass window. Slightly brighter than the
        // window background so cards stand out.
        // Interactive container: AdaptiveBackgroundView is deliberately
        // hit-test transparent and therefore cannot own these buttons.
        let card = AdaptiveCardView(frame: NSRect(x: 0, y: 0, width: 100, height: 100))
        card.translatesAutoresizingMaskIntoConstraints = false
        card.cornerRadius = 12
        card.addsDepth = false
        card.setAccessibilityRole(.group)
        card.setAccessibilityLabel("\(index + 1). \(entry.arabic)")

        let arabic = NSTextField(wrappingLabelWithString: entry.arabic)
        arabic.font = Localizer.shared.font(size: 18, weight: .medium)
        arabic.alignment = .right
        arabic.baseWritingDirection = .rightToLeft
        arabic.textColor = .labelColor
        arabic.translatesAutoresizingMaskIntoConstraints = false
        arabic.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        arabic.setContentHuggingPriority(.defaultLow, for: .horizontal)
        arabic.cell?.truncatesLastVisibleLine = false
        arabic.cell?.wraps = true
        arabic.maximumNumberOfLines = 0
        arabic.isSelectable = true

        // Meta line: repeat count + audio source. Uses Cairo so the Arabic
        // numerals/badge render consistently with the rest of the app.
        let audioDesc = entry.audioRef.isEmpty ? t("adhkar.editor.audio.none") : audioDisplayName(entry.audioRef)
        let meta = NSTextField(labelWithString: "↻ \(entry.count)×   ·   \(audioDesc)")
        meta.font = Localizer.shared.font(size: 11)
        meta.alignment = Localizer.shared.isRTL ? .right : .left
        meta.baseWritingDirection = Localizer.shared.isRTL ? .rightToLeft : .leftToRight
        meta.textColor = .tertiaryLabelColor
        meta.translatesAutoresizingMaskIntoConstraints = false

        // Up / down / remove buttons
        let upBtn = HoverIconButton(symbol: "chevron.up", toolTip: t("adhkar.editor.move_up"),
                                     target: self, action: #selector(itemMoveUp(_:)),
                                     pointSize: 13, size: NSSize(width: 32, height: 32))
        upBtn.tag = index
        let downBtn = HoverIconButton(symbol: "chevron.down", toolTip: t("adhkar.editor.move_down"),
                                       target: self, action: #selector(itemMoveDown(_:)),
                                       pointSize: 13, size: NSSize(width: 32, height: 32))
        downBtn.tag = index
        let removeBtn = HoverIconButton(symbol: "trash", toolTip: t("adhkar.editor.remove"),
                                         target: self, action: #selector(removeItem(_:)),
                                         pointSize: 13, size: NSSize(width: 32, height: 32))
        removeBtn.tag = index
        removeBtn.idleTint = .systemRed

        // Audio popup + edit button
        // Audio button — shows current state (set / none) and opens the picker.
        let audioTitle: String
        if entry.audioRef.isEmpty {
            audioTitle = "♩  \(t("adhkar.editor.audio.none"))"
        } else {
            audioTitle = "♩  \(t("adhkar.editor.audio"))"
        }
        let audioBtn = NSButton(title: audioTitle, target: self,
                                 action: #selector(pickAudio(_:)))
        audioBtn.bezelStyle = .rounded
        audioBtn.controlSize = .small
        audioBtn.tag = index
        audioBtn.toolTip = entry.audioRef.isEmpty ? t("adhkar.editor.audio.choose") : audioDisplayName(entry.audioRef)
        audioBtn.translatesAutoresizingMaskIntoConstraints = false

        // Quick preview button (only if audio is set).
        let previewBtn: HoverIconButton?
        if !entry.audioRef.isEmpty {
            previewBtn = HoverIconButton(symbol: "play.circle",
                                          toolTip: t("adhkar.editor.play_preview"),
                                          target: self,
                                          action: #selector(previewItemAudio(_:)),
                                          pointSize: 13,
                                          size: NSSize(width: 32, height: 32))
            previewBtn!.tag = index
        } else {
            previewBtn = nil
        }

        let editBtn = NSButton(title: t("adhkar.editor.repeat"), target: self,
                                action: #selector(editItem(_:)))
        editBtn.bezelStyle = .rounded
        editBtn.controlSize = .small
        editBtn.tag = index
        editBtn.translatesAutoresizingMaskIntoConstraints = false

        let buttonsRow = NSStackView()
        buttonsRow.orientation = .horizontal
        buttonsRow.spacing = 6
        buttonsRow.alignment = .centerY
        buttonsRow.translatesAutoresizingMaskIntoConstraints = false
        var rowButtons: [NSView] = [upBtn, downBtn, removeBtn, audioBtn]
        if let pb = previewBtn { rowButtons.insert(pb, at: 4) }
        rowButtons.append(editBtn)
        for b in rowButtons {
            buttonsRow.addArrangedSubview(b)
        }

        card.addSubview(arabic)
        card.addSubview(meta)
        card.addSubview(buttonsRow)

        NSLayoutConstraint.activate([
            card.heightAnchor.constraint(greaterThanOrEqualToConstant: 90),
            arabic.topAnchor.constraint(equalTo: card.topAnchor, constant: 12),
            arabic.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 14),
            arabic.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -14),
            meta.topAnchor.constraint(equalTo: arabic.bottomAnchor, constant: 8),
            meta.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 14),
            buttonsRow.topAnchor.constraint(equalTo: meta.bottomAnchor, constant: 6),
            buttonsRow.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 10),
            buttonsRow.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -10),
            buttonsRow.trailingAnchor.constraint(lessThanOrEqualTo: card.trailingAnchor, constant: -10),
        ])
        return card
    }

    private func audioDisplayName(_ ref: String) -> String {
        if ref.hasPrefix("bundled:") {
            return "Bundled · " + String(ref.dropFirst("bundled:".count))
        }
        if ref.hasPrefix("imported:") {
            return "Imported · " + String(ref.dropFirst("imported:".count))
        }
        return t("adhkar.editor.audio.none")
    }

    // MARK: - item actions

    private func selectedCollectionIndex() -> Int? {
        guard let id = selectedCollectionID else { return nil }
        return collections.firstIndex(where: { $0.id == id })
    }
    private func selectedCollection() -> AdhkarCollection? {
        guard let idx = selectedCollectionIndex() else { return nil }
        return collections[idx]
    }

    /// Settings menu for the player bar — volume is already on the slider,
    /// so this popup shows output device options (mirrors adhan settings).
    private func showAdhkarSettingsMenu(from sender: NSView) {
        let menu = NSMenu()
        let headerItem = NSMenuItem(title: t("settings.adhan.output"),
                                     action: nil, keyEquivalent: "")
        headerItem.isEnabled = false
        menu.addItem(headerItem)
        menu.addItem(.separator())
        let devices = listAudioOutputDevices()
        let curUID = UserDefaults.standard.string(forKey: kAdhkarAudioDevice) ?? ""
        // "System Default" option
        let defaultItem = NSMenuItem(title: t("settings.adhan.output.default"),
                                      action: #selector(adhkarOutputChanged(_:)),
                                      keyEquivalent: "")
        defaultItem.target = self
        defaultItem.representedObject = ""
        if curUID.isEmpty { defaultItem.state = .on }
        menu.addItem(defaultItem)
        for dev in devices {
            let mi = NSMenuItem(title: dev.name,
                                 action: #selector(adhkarOutputChanged(_:)),
                                 keyEquivalent: "")
            mi.target = self
            mi.representedObject = dev.uid
            if dev.uid == curUID { mi.state = .on }
            menu.addItem(mi)
        }
        if let event = NSApp.currentEvent {
            NSMenu.popUpContextMenu(menu, with: event, for: sender)
        }
    }
    @objc private func adhkarOutputChanged(_ mi: NSMenuItem) {
        let uid = (mi.representedObject as? String) ?? ""
        UserDefaults.standard.set(uid, forKey: kAdhkarAudioDevice)
    }

    @objc private func itemMoveUp(_ sender: NSButton) {
        guard let ci = selectedCollectionIndex(), ci >= 0 else { return }
        let i = sender.tag
        guard i > 0, i < collections[ci].items.count else { return }
        collections[ci].items.swapAt(i, i - 1)
        persist(); rebuildItemsPane()
    }
    @objc private func itemMoveDown(_ sender: NSButton) {
        guard let ci = selectedCollectionIndex() else { return }
        let i = sender.tag
        guard i >= 0, i + 1 < collections[ci].items.count else { return }
        collections[ci].items.swapAt(i, i + 1)
        persist(); rebuildItemsPane()
    }
    @objc private func removeItem(_ sender: NSButton) {
        guard let ci = selectedCollectionIndex() else { return }
        let i = sender.tag
        guard i >= 0, i < collections[ci].items.count else { return }
        let alert = NSAlert()
        alert.messageText = t("adhkar.editor.delete_item")
        alert.addButton(withTitle: t("adhkar.editor.remove"))
        alert.addButton(withTitle: t("adhkar.editor.cancel"))
        if alert.runModal() == .alertFirstButtonReturn {
            collections[ci].items.remove(at: i)
            persist(); rebuildItemsPane()
        }
    }

    @objc private func pickAudio(_ sender: NSButton) {
        guard let ci = selectedCollectionIndex() else { return }
        let i = sender.tag
        guard i >= 0, i < collections[ci].items.count else { return }
        let menu = NSMenu()
        let opts = adhkarAudioOptions()
        for opt in opts {
            let mi = NSMenuItem(title: opt.displayName, action: #selector(audioChosen(_:)),
                                 keyEquivalent: "")
            mi.target = self
            mi.representedObject = ["i": i, "ref": opt.id] as [String: Any]
            if opt.id == collections[ci].items[i].audioRef { mi.state = .on }
            menu.addItem(mi)
        }
        menu.addItem(.separator())
        let imp = NSMenuItem(title: t("adhkar.editor.audio.import"),
                              action: #selector(importAudio(_:)), keyEquivalent: "")
        imp.target = self
        imp.tag = i
        menu.addItem(imp)
        menu.addItem(.separator())
        let prev = NSMenuItem(title: t("adhkar.editor.play_preview"),
                               action: #selector(previewAudio(_:)), keyEquivalent: "")
        prev.target = self
        prev.tag = i
        menu.addItem(prev)
        if let event = NSApp.currentEvent {
            NSMenu.popUpContextMenu(menu, with: event, for: sender)
        }
    }

    @objc private func audioChosen(_ mi: NSMenuItem) {
        guard let ci = selectedCollectionIndex(),
              let dict = mi.representedObject as? [String: Any],
              let i = dict["i"] as? Int,
              let ref = dict["ref"] as? String else { return }
        guard i >= 0, i < collections[ci].items.count else { return }
        collections[ci].items[i].audioRef = ref
        persist(); rebuildItemsPane()
    }

    @objc private func importAudio(_ mi: NSMenuItem) {
        guard let ci = selectedCollectionIndex() else { return }
        let i = mi.tag
        guard i >= 0, i < collections[ci].items.count else { return }
        guard let ref = presentAudioImportPanel() else { return }
        collections[ci].items[i].audioRef = ref
        persist(); rebuildItemsPane()
    }

    @objc private func previewAudio(_ mi: NSMenuItem) {
        guard let ci = selectedCollectionIndex() else { return }
        let i = mi.tag
        guard i >= 0, i < collections[ci].items.count else { return }
        var preview = collections[ci]
        preview.items = [collections[ci].items[i]]
        previewSession.start(collection: preview)
    }

    /// Quick preview button on an item card — plays the item's audio.
    @objc private func previewItemAudio(_ sender: HoverIconButton) {
        guard let ci = selectedCollectionIndex() else { return }
        let i = sender.tag
        guard i >= 0, i < collections[ci].items.count else { return }
        guard !collections[ci].items[i].audioRef.isEmpty else { return }
        var preview = collections[ci]
        preview.items = [collections[ci].items[i]]
        previewSession.start(collection: preview)
    }

    @objc private func editItem(_ sender: NSButton) {
        guard let ci = selectedCollectionIndex() else { return }
        let i = sender.tag
        guard i >= 0, i < collections[ci].items.count else { return }
        let entry = collections[ci].items[i]
        let sheet = AdhkarItemEditSheet(arabic: entry.arabic, count: entry.count,
                                         virtue: entry.virtue, source: entry.source)
        sheet.onSave = { [weak self] newArabic, newCount, newVirtue, newSource in
            guard let self = self,
                  let ci = self.selectedCollectionIndex(),
                  i < self.collections[ci].items.count else { return }
            self.collections[ci].items[i].arabic = newArabic
            self.collections[ci].items[i].count  = newCount
            self.collections[ci].items[i].virtue = newVirtue
            self.collections[ci].items[i].source = newSource
            self.persist(); self.rebuildItemsPane()
        }
        if let window = view.window {
            sheet.beginSheetModal(for: window)
        }
    }

    // MARK: - add (library / custom)

    @objc private func addFromLibrary() {
        guard selectedCollectionIndex() != nil else { return }
        // Offer items from ALL 14 categories, deduped by Arabic text.
        var allItems: [AdhkarItem] = []
        for set in AdhkarSet.allCases {
            allItems.append(contentsOf: AdhkarData.items(for: set))
        }
        var seen = Set<String>()
        let unique = allItems.filter { seen.insert($0.arabic).inserted }
        let sheet = AdhkarLibraryPickerSheet(items: unique)
        sheet.onAdd = { [weak self] picked in
            guard let self = self,
                  let ci = self.selectedCollectionIndex() else { return }
            for item in picked {
                self.collections[ci].items.append(AdhkarEntry(from: item))
            }
            self.persist(); self.rebuildItemsPane()
        }
        if let window = view.window {
            sheet.beginSheetModal(for: window)
        }
    }

    @objc private func addCustom() {
        guard selectedCollectionIndex() != nil else { return }
        let sheet = AdhkarItemEditSheet(arabic: "", count: 1, virtue: "", source: "")
        sheet.onSave = { [weak self] arabic, count, virtue, source in
            guard let self = self,
                  let ci = self.selectedCollectionIndex(),
                  !arabic.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
            let entry = AdhkarEntry(arabic: arabic, count: count,
                                     virtue: virtue, source: source,
                                     audioRef: "")
            self.collections[ci].items.append(entry)
            self.persist(); self.rebuildItemsPane()
        }
        if let window = view.window {
            sheet.beginSheetModal(for: window)
        }
    }
}

/// Custom row view that carries its collection UUID. Handles mouse clicks
/// to select the collection (more reliable than gesture recognizers, which
/// conflict with subview buttons like the play button).
final class CollectionRowView: NSView {
    var collectionID: UUID?
    var onSelect: ((UUID) -> Void)?

    override var acceptsFirstResponder: Bool { true }

    private func select() {
        guard let id = collectionID else { return }
        window?.makeFirstResponder(self)
        onSelect?(id)
    }

    override func mouseDown(with event: NSEvent) {
        select()
    }

    override func keyDown(with event: NSEvent) {
        if event.keyCode == 36 || event.charactersIgnoringModifiers == " " {
            select()
        } else {
            super.keyDown(with: event)
        }
    }

    override func accessibilityPerformPress() -> Bool {
        select()
        return true
    }

    override var focusRingMaskBounds: NSRect { bounds.insetBy(dx: 2, dy: 2) }

    override func drawFocusRingMask() {
        NSBezierPath(roundedRect: focusRingMaskBounds, xRadius: 7, yRadius: 7).fill()
    }
}

// ----------------------------------------------------------------------------
// MARK: Adhkar item edit sheet — Arabic text + count + virtue + source
// ----------------------------------------------------------------------------
final class AdhkarItemEditSheet: NSWindowController, NSWindowDelegate,
                                  NSTextFieldDelegate {

    private var arabicField: NSTextField!
    private var countField:  NSTextField!
    private var countStepper: NSStepper!
    private var virtueField: NSTextField!
    private var sourceField: NSTextField!

    /// (arabic, count, virtue, source)
    var onSave: ((String, Int, String, String) -> Void)?

    init(arabic: String, count: Int, virtue: String, source: String) {
        let w = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 460, height: 360),
                         styleMask: [.titled, .closable],
                         backing: .buffered, defer: false)
        w.title = t("adhkar.editor.custom_title")
        w.center()
        super.init(window: w)
        w.delegate = self
        build(arabic: arabic, count: count, virtue: virtue, source: source)
    }
    required init?(coder: NSCoder) { fatalError() }

    func beginSheetModal(for parent: NSWindow) {
        parent.beginSheet(window!) { _ in self.commitIfOK() }
    }

    private func commitIfOK() {
        // The sheet's Save button sets isOK=true before closing.
        if isOK { onSave?(arabicField.stringValue, countStepper.integerValue,
                          virtueField.stringValue, sourceField.stringValue) }
    }
    private var isOK = false

    private func build(arabic: String, count: Int, virtue: String, source: String) {
        guard let w = window else { return }
        let c = NSView(frame: w.contentLayoutRect)
        w.contentView = c

        let hint = NSTextField(wrappingLabelWithString: t("adhkar.editor.custom_hint"))
        hint.font = Localizer.shared.font(size: 11)
        hint.textColor = .secondaryLabelColor
        hint.alignment = Localizer.shared.isRTL ? .right : .left
        hint.baseWritingDirection = Localizer.shared.isRTL ? .rightToLeft : .leftToRight
        hint.translatesAutoresizingMaskIntoConstraints = false
        c.addSubview(hint)

        let arabicLbl = makeLabel(t("adhkar.editor.arabic"))
        c.addSubview(arabicLbl)
        arabicField = NSTextField(wrappingLabelWithString: arabic)
        arabicField.font = Localizer.shared.font(size: 16, weight: .medium)
        arabicField.alignment = .right
        arabicField.baseWritingDirection = .rightToLeft
        arabicField.isEditable = true
        arabicField.isBordered = true
        arabicField.drawsBackground = true
        arabicField.translatesAutoresizingMaskIntoConstraints = false
        arabicField.heightAnchor.constraint(greaterThanOrEqualToConstant: 80).isActive = true
        c.addSubview(arabicField)

        let countLbl = makeLabel(t("adhkar.editor.repeat"))
        c.addSubview(countLbl)
        countStepper = NSStepper()
        countStepper.minValue = 1
        countStepper.maxValue = 1000
        countStepper.integerValue = max(1, count)
        countStepper.valueWraps = false
        countStepper.target = self
        countStepper.action = #selector(stepperChanged)
        countStepper.translatesAutoresizingMaskIntoConstraints = false
        c.addSubview(countStepper)
        countField = NSTextField(labelWithString: localizedInterfaceDigits(
            String(format: t("adhkar.editor.count_times"), countStepper.integerValue)))
        countField.font = Localizer.shared.font(size: 12)
        countField.alignment = Localizer.shared.isRTL ? .right : .left
        countField.baseWritingDirection = Localizer.shared.isRTL ? .rightToLeft : .leftToRight
        countField.translatesAutoresizingMaskIntoConstraints = false
        c.addSubview(countField)

        let virtueLbl = makeLabel(t("adhkar.editor.virtue"))
        c.addSubview(virtueLbl)
        virtueField = NSTextField(wrappingLabelWithString: virtue)
        virtueField.isEditable = true
        virtueField.isBordered = true
        virtueField.drawsBackground = true
        virtueField.font = Localizer.shared.font(size: 12)
        virtueField.alignment = Localizer.shared.isRTL ? .right : .left
        virtueField.baseWritingDirection = Localizer.shared.isRTL ? .rightToLeft : .leftToRight
        virtueField.translatesAutoresizingMaskIntoConstraints = false
        c.addSubview(virtueField)

        let sourceLbl = makeLabel(t("adhkar.editor.source"))
        c.addSubview(sourceLbl)
        sourceField = NSTextField(wrappingLabelWithString: source)
        sourceField.isEditable = true
        sourceField.isBordered = true
        sourceField.drawsBackground = true
        sourceField.font = Localizer.shared.font(size: 12)
        sourceField.alignment = Localizer.shared.isRTL ? .right : .left
        sourceField.baseWritingDirection = Localizer.shared.isRTL ? .rightToLeft : .leftToRight
        sourceField.translatesAutoresizingMaskIntoConstraints = false
        c.addSubview(sourceField)

        let saveBtn = NSButton(title: t("adhkar.editor.save"), target: self,
                                action: #selector(saveTapped))
        saveBtn.keyEquivalent = "\r"
        saveBtn.translatesAutoresizingMaskIntoConstraints = false
        c.addSubview(saveBtn)
        let cancelBtn = NSButton(title: t("adhkar.editor.cancel"), target: self,
                                   action: #selector(cancelTapped))
        cancelBtn.keyEquivalent = "\u{1b}"
        cancelBtn.translatesAutoresizingMaskIntoConstraints = false
        c.addSubview(cancelBtn)

        NSLayoutConstraint.activate([
            hint.topAnchor.constraint(equalTo: c.topAnchor, constant: 12),
            hint.leadingAnchor.constraint(equalTo: c.leadingAnchor, constant: 16),
            hint.trailingAnchor.constraint(equalTo: c.trailingAnchor, constant: -16),

            arabicLbl.topAnchor.constraint(equalTo: hint.bottomAnchor, constant: 12),
            arabicLbl.leadingAnchor.constraint(equalTo: c.leadingAnchor, constant: 16),
            arabicField.topAnchor.constraint(equalTo: arabicLbl.bottomAnchor, constant: 4),
            arabicField.leadingAnchor.constraint(equalTo: c.leadingAnchor, constant: 16),
            arabicField.trailingAnchor.constraint(equalTo: c.trailingAnchor, constant: -16),

            countLbl.topAnchor.constraint(equalTo: arabicField.bottomAnchor, constant: 12),
            countLbl.leadingAnchor.constraint(equalTo: c.leadingAnchor, constant: 16),
            countStepper.topAnchor.constraint(equalTo: countLbl.bottomAnchor, constant: 4),
            countStepper.leadingAnchor.constraint(equalTo: c.leadingAnchor, constant: 16),
            countField.leadingAnchor.constraint(equalTo: countStepper.trailingAnchor, constant: 8),
            countField.centerYAnchor.constraint(equalTo: countStepper.centerYAnchor),

            virtueLbl.topAnchor.constraint(equalTo: countStepper.bottomAnchor, constant: 12),
            virtueLbl.leadingAnchor.constraint(equalTo: c.leadingAnchor, constant: 16),
            virtueField.topAnchor.constraint(equalTo: virtueLbl.bottomAnchor, constant: 4),
            virtueField.leadingAnchor.constraint(equalTo: c.leadingAnchor, constant: 16),
            virtueField.trailingAnchor.constraint(equalTo: c.trailingAnchor, constant: -16),

            sourceLbl.topAnchor.constraint(equalTo: virtueField.bottomAnchor, constant: 12),
            sourceLbl.leadingAnchor.constraint(equalTo: c.leadingAnchor, constant: 16),
            sourceField.topAnchor.constraint(equalTo: sourceLbl.bottomAnchor, constant: 4),
            sourceField.leadingAnchor.constraint(equalTo: c.leadingAnchor, constant: 16),
            sourceField.trailingAnchor.constraint(equalTo: c.trailingAnchor, constant: -16),

            cancelBtn.bottomAnchor.constraint(equalTo: c.bottomAnchor, constant: -12),
            cancelBtn.trailingAnchor.constraint(equalTo: saveBtn.leadingAnchor, constant: -8),
            saveBtn.bottomAnchor.constraint(equalTo: c.bottomAnchor, constant: -12),
            saveBtn.trailingAnchor.constraint(equalTo: c.trailingAnchor, constant: -16),
        ])
    }

    private func makeLabel(_ s: String) -> NSTextField {
        let l = NSTextField(labelWithString: s)
        l.font = Localizer.shared.font(size: 12, weight: .medium)
        l.textColor = .secondaryLabelColor
        l.alignment = Localizer.shared.isRTL ? .right : .left
        l.baseWritingDirection = Localizer.shared.isRTL ? .rightToLeft : .leftToRight
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }

    @objc private func stepperChanged() {
        countField.stringValue = localizedInterfaceDigits(
            String(format: t("adhkar.editor.count_times"), countStepper.integerValue))
    }
    @objc private func saveTapped() {
        isOK = true
        window?.sheetParent?.endSheet(window!)
    }
    @objc private func cancelTapped() {
        isOK = false
        window?.sheetParent?.endSheet(window!)
    }
}

// ----------------------------------------------------------------------------
// MARK: Library picker sheet — multi-select adhkar from the bundled library
// ----------------------------------------------------------------------------
final class AdhkarLibraryPickerSheet: NSWindowController, NSWindowDelegate,
                                       NSTableViewDelegate, NSTableViewDataSource {

    private let items: [AdhkarItem]
    private var selected = Set<Int>()   // indices into items
    var onAdd: (([AdhkarItem]) -> Void)?

    init(items: [AdhkarItem]) {
        self.items = items
        let w = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 520, height: 480),
                         styleMask: [.titled, .closable],
                         backing: .buffered, defer: false)
        w.title = t("adhkar.editor.library_title")
        w.center()
        super.init(window: w)
        w.delegate = self
        build()
    }
    required init?(coder: NSCoder) { fatalError() }

    func beginSheetModal(for parent: NSWindow) {
        parent.beginSheet(window!) { _ in
            if !self.selected.isEmpty {
                let picked = self.selected.compactMap { i -> AdhkarItem? in
                    self.items.indices.contains(i) ? self.items[i] : nil
                }
                self.onAdd?(picked)
            }
        }
    }

    private var tableView: NSTableView!

    private func build() {
        guard let w = window else { return }
        let c = NSView(frame: w.contentLayoutRect)
        w.contentView = c

        let hint = NSTextField(labelWithString: t("adhkar.editor.library_pick"))
        hint.font = Localizer.shared.font(size: 12, weight: .medium)
        hint.textColor = .secondaryLabelColor
        hint.alignment = Localizer.shared.isRTL ? .right : .left
        hint.baseWritingDirection = Localizer.shared.isRTL ? .rightToLeft : .leftToRight
        hint.translatesAutoresizingMaskIntoConstraints = false
        c.addSubview(hint)

        tableView = NSTableView()
        tableView.delegate = self
        tableView.dataSource = self
        tableView.headerView = nil
        tableView.allowsMultipleSelection = true
        tableView.rowSizeStyle = .large
        // RTL table for Arabic so rows read right-to-left.
        if Localizer.shared.isRTL {
            tableView.userInterfaceLayoutDirection = .rightToLeft
        }
        let col = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("adhkar"))
        tableView.addTableColumn(col)
        let scroll = NSScrollView()
        scroll.documentView = tableView
        scroll.hasVerticalScroller = true
        scroll.translatesAutoresizingMaskIntoConstraints = false
        c.addSubview(scroll)

        let addBtn = NSButton(title: t("adhkar.editor.library_add_selected"),
                               target: self, action: #selector(addTapped))
        addBtn.keyEquivalent = "\r"
        addBtn.translatesAutoresizingMaskIntoConstraints = false
        c.addSubview(addBtn)
        let cancelBtn = NSButton(title: t("adhkar.editor.cancel"),
                                  target: self, action: #selector(cancelTapped))
        cancelBtn.keyEquivalent = "\u{1b}"
        cancelBtn.translatesAutoresizingMaskIntoConstraints = false
        c.addSubview(cancelBtn)

        NSLayoutConstraint.activate([
            hint.topAnchor.constraint(equalTo: c.topAnchor, constant: 12),
            hint.leadingAnchor.constraint(equalTo: c.leadingAnchor, constant: 16),
            scroll.topAnchor.constraint(equalTo: hint.bottomAnchor, constant: 8),
            scroll.leadingAnchor.constraint(equalTo: c.leadingAnchor, constant: 16),
            scroll.trailingAnchor.constraint(equalTo: c.trailingAnchor, constant: -16),
            scroll.bottomAnchor.constraint(equalTo: addBtn.topAnchor, constant: -12),
            cancelBtn.bottomAnchor.constraint(equalTo: c.bottomAnchor, constant: -12),
            cancelBtn.trailingAnchor.constraint(equalTo: addBtn.leadingAnchor, constant: -8),
            addBtn.bottomAnchor.constraint(equalTo: c.bottomAnchor, constant: -12),
            addBtn.trailingAnchor.constraint(equalTo: c.trailingAnchor, constant: -16),
        ])
    }

    func numberOfRows(in tableView: NSTableView) -> Int { items.count }
    func tableView(_ tableView: NSTableView, objectValueFor tableColumn: NSTableColumn?,
                   row: Int) -> Any? { items[row] }
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?,
                   row: Int) -> NSView? {
        let id = NSUserInterfaceItemIdentifier("cell")
        let cell = (tableView.makeView(withIdentifier: id, owner: nil) as? NSTableCellView)
                   ?? NSTableCellView()
        cell.identifier = id
        let label = cell.textField ?? NSTextField(labelWithString: "")
        label.font = Localizer.shared.font(size: 14, weight: .regular)
        label.alignment = .right
        label.baseWritingDirection = .rightToLeft
        label.stringValue = items[row].arabic
        cell.textField = label
        return cell
    }

    @objc private func addTapped() {
        selected = Set(tableView.selectedRowIndexes.map { $0 })
        window?.sheetParent?.endSheet(window!)
    }
    @objc private func cancelTapped() {
        selected.removeAll()
        window?.sheetParent?.endSheet(window!)
    }
}

// ============================================================================
// MARK: Compact Adhkar — menu-bar sibling of the prayer view
// ============================================================================

final class CompactAdhkarView: FlippedView {
    private weak var appDelegate: AppDelegate?
    private let session = AdhkarSession()
    private var collections: [AdhkarCollection] = []
    private var selectedID: UUID?
    private var manualFontSize: CGFloat?
    private var isExpanded = false

    private var collectionPopup: NSPopUpButton!
    private var textCard: AdaptiveCardView!
    private var textScrollView: NSScrollView!
    private var arabicTextView: NSTextView!
    private var positionLabel: NSTextField!
    private var progress: NSProgressIndicator!
    private var playButton: HoverIconButton!
    private var muteButton: HoverIconButton!
    private var expandButton: HoverIconButton!
    private var moreButton: NSButton!

    var onFinish: (() -> Void)?
    var isReciting: Bool { session.isPlaying || session.isPaused }

    init(frame: NSRect, appDelegate: AppDelegate) {
        self.appDelegate = appDelegate
        super.init(frame: frame)
        autoresizingMask = [.width]
        userInterfaceLayoutDirection = Localizer.shared.isRTL ? .rightToLeft : .leftToRight
        buildUI()
        wireSession()
        reloadCollections()
    }

    required init?(coder: NSCoder) { fatalError() }

    private func buildUI() {
        collectionPopup = NSPopUpButton(frame: NSRect(x: 16, y: 14,
                                                       width: bounds.width - 32, height: 28),
                                         pullsDown: false)
        collectionPopup.autoresizingMask = [.width]
        collectionPopup.target = self
        collectionPopup.action = #selector(collectionChanged(_:))
        addSubview(collectionPopup)

        textCard = AdaptiveCardView(frame: NSRect(x: 12, y: 50,
                                                   width: bounds.width - 24, height: 216))
        textCard.autoresizingMask = [.width]
        textCard.cornerRadius = 12
        textCard.addsDepth = true
        addSubview(textCard)

        positionLabel = NSTextField(labelWithString: "")
        positionLabel.frame = NSRect(x: 14, y: 11, width: 70, height: 16)
        positionLabel.font = NSFont.monospacedDigitSystemFont(ofSize: 10, weight: .medium)
        positionLabel.textColor = .secondaryLabelColor
        positionLabel.alignment = .left
        textCard.addSubview(positionLabel)

        let textTools: [(String, String, Selector)] = [
            ("textformat.size.smaller", featureText("popup.text.smaller"), #selector(smallerTextTapped)),
            ("arrow.counterclockwise", featureText("popup.text.automatic"), #selector(automaticTextTapped)),
            ("textformat.size.larger", featureText("popup.text.larger"), #selector(largerTextTapped)),
            ("arrow.up.left.and.arrow.down.right", featureText("popup.text.expand"), #selector(expandTextTapped)),
        ]
        for (index, item) in textTools.enumerated() {
            let button = HoverIconButton(symbol: item.0, toolTip: item.1,
                                         target: self, action: item.2,
                                         pointSize: 12,
                                         size: NSSize(width: 40, height: 36))
            button.frame.origin = NSPoint(x: 88 + CGFloat(index) * 40, y: 2)
            button.setAccessibilityLabel(item.1)
            textCard.addSubview(button)
            if index == 3 { expandButton = button }
        }

        textScrollView = NSScrollView(frame: NSRect(x: 12, y: 40,
                                                     width: textCard.bounds.width - 24, height: 154))
        textScrollView.autoresizingMask = [.width]
        textScrollView.drawsBackground = false
        textScrollView.borderType = .noBorder
        textScrollView.hasVerticalScroller = true
        textScrollView.autohidesScrollers = true

        arabicTextView = NSTextView(frame: textScrollView.bounds)
        arabicTextView.isEditable = false
        arabicTextView.isSelectable = true
        arabicTextView.drawsBackground = false
        arabicTextView.textColor = .labelColor
        arabicTextView.alignment = .right
        arabicTextView.baseWritingDirection = .rightToLeft
        arabicTextView.textContainerInset = NSSize(width: 8, height: 8)
        arabicTextView.isHorizontallyResizable = false
        arabicTextView.isVerticallyResizable = true
        arabicTextView.autoresizingMask = [.width]
        arabicTextView.textContainer?.widthTracksTextView = true
        arabicTextView.textContainer?.lineFragmentPadding = 0
        textScrollView.documentView = arabicTextView
        textCard.addSubview(textScrollView)

        progress = NSProgressIndicator(frame: NSRect(x: 22, y: 202,
                                                      width: textCard.bounds.width - 44, height: 4))
        progress.autoresizingMask = [.width]
        progress.style = .bar
        progress.isIndeterminate = false
        progress.minValue = 0
        progress.maxValue = 1
        textCard.addSubview(progress)

        let controlSize = NSSize(width: 40, height: 34)
        let symbols = ["backward.fill", "play.fill", "forward.fill",
                       "speaker.wave.2.fill", "stop.fill"]
        let tools = [t("adhkar.prev"), t("adhkar.play"), t("adhkar.next"),
                     t("adhkar.mute"), t("adhkar.stop")]
        let actions: [Selector] = [#selector(previousTapped), #selector(playTapped),
                                   #selector(nextTapped), #selector(muteTapped),
                                   #selector(stopTapped)]
        let totalWidth: CGFloat = 5 * controlSize.width + 4 * 7
        var x = (bounds.width - totalWidth) / 2
        var controls: [HoverIconButton] = []
        for i in 0..<symbols.count {
            let button = HoverIconButton(symbol: symbols[i], toolTip: tools[i],
                                         target: self, action: actions[i],
                                         pointSize: 14, size: controlSize)
            button.frame.origin = NSPoint(x: x, y: 274)
            button.autoresizingMask = [.minXMargin, .maxXMargin]
            button.setAccessibilityLabel(tools[i])
            addSubview(button)
            controls.append(button)
            x += controlSize.width + 7
        }
        playButton = controls[1]
        muteButton = controls[3]
        controls[4].idleTint = .systemRed
        controls[4].hoverTint = .systemRed
        controls[4].contentTintColor = .systemRed

        moreButton = NSButton(title: featureText("full.open_more"),
                              target: self, action: #selector(openMoreTapped))
        moreButton.frame = NSRect(x: 54, y: 318, width: bounds.width - 108, height: 28)
        moreButton.autoresizingMask = [.minXMargin, .maxXMargin]
        moreButton.bezelStyle = .rounded
        moreButton.controlSize = .small
        moreButton.image = templateSymbol("arrow.up.right.square", pointSize: 11)
        moreButton.imagePosition = .imageLeading
        addSubview(moreButton)
    }

    private func wireSession() {
        session.onItemChange = { [weak self] item, index, total in
            self?.render(item: item, index: index, total: total)
        }
        session.onPlaybackStateChange = { [weak self] in
            self?.refreshControls()
        }
        session.onFinish = { [weak self] in
            self?.renderPreview()
            self?.refreshControls()
            self?.onFinish?()
        }
    }

    func reloadCollections() {
        let previousID = selectedID
        collections = AdhkarLibrary.load().filter { !$0.items.isEmpty }
        collectionPopup.removeAllItems()
        collections.forEach { collectionPopup.addItem(withTitle: $0.displayName) }
        let selectedIndex = previousID.flatMap { id in
            collections.firstIndex(where: { $0.id == id })
        } ?? 0
        if collections.indices.contains(selectedIndex) {
            collectionPopup.selectItem(at: selectedIndex)
            selectedID = collections[selectedIndex].id
        } else {
            selectedID = nil
        }
        if let item = session.currentItem, let position = session.position {
            render(item: item, index: position.0 - 1, total: position.1)
        } else {
            renderPreview()
        }
        refreshControls()
    }

    private var selectedCollection: AdhkarCollection? {
        guard let id = selectedID else { return nil }
        return collections.first(where: { $0.id == id })
    }

    private func renderPreview() {
        guard let collection = selectedCollection, let first = collection.items.first else {
            arabicTextView.string = featureText("popup.adhkar.empty")
            arabicTextView.alignment = .center
            arabicTextView.baseWritingDirection = Localizer.shared.isRTL ? .rightToLeft : .leftToRight
            applyTextSize(for: arabicTextView.string)
            positionLabel.stringValue = ""
            progress.doubleValue = 0
            return
        }
        render(item: first, index: 0, total: collection.items.count)
    }

    private func render(item: AdhkarEntry, index: Int, total: Int) {
        arabicTextView.string = item.arabic
        arabicTextView.alignment = .right
        arabicTextView.baseWritingDirection = .rightToLeft
        applyTextSize(for: item.arabic)
        arabicTextView.scrollToBeginningOfDocument(nil)
        positionLabel.stringValue = "\(index + 1) / \(total)"
        progress.doubleValue = total > 0 ? Double(index + 1) / Double(total) : 0
    }

    private func applyTextSize(for text: String) {
        let automatic: CGFloat
        switch text.count {
        case 0...110:  automatic = 23
        case 111...240: automatic = 20
        case 241...430: automatic = 17
        default:       automatic = 15
        }
        let size = manualFontSize ?? automatic
        arabicTextView.font = NSFont(name: "Cairo", size: size)
            ?? NSFont.systemFont(ofSize: size, weight: .medium)
    }

    private func updateExpandedLayout() {
        collectionPopup.isHidden = isExpanded
        moreButton.isHidden = isExpanded
        textCard.frame = isExpanded
            ? NSRect(x: 12, y: 8, width: bounds.width - 24, height: 258)
            : NSRect(x: 12, y: 50, width: bounds.width - 24, height: 216)
        textScrollView.frame = NSRect(x: 12, y: 40,
                                      width: textCard.bounds.width - 24,
                                      height: isExpanded ? 196 : 154)
        progress.frame = NSRect(x: 22, y: isExpanded ? 246 : 202,
                                width: textCard.bounds.width - 44, height: 4)
        let symbol = isExpanded ? "arrow.down.right.and.arrow.up.left"
                                : "arrow.up.left.and.arrow.down.right"
        expandButton.image = templateSymbol(symbol, pointSize: 12)
        let label = featureText(isExpanded ? "popup.text.collapse" : "popup.text.expand")
        expandButton.toolTip = label
        expandButton.setAccessibilityLabel(label)
    }

    private func refreshControls() {
        let playing = session.isPlaying
        playButton.image = templateSymbol(playing ? "pause.fill" : "play.fill", pointSize: 14)
        playButton.toolTip = playing ? t("adhkar.pause") : t("adhkar.play")
        muteButton.image = templateSymbol(session.muted ? "speaker.slash.fill"
                                                          : "speaker.wave.2.fill", pointSize: 14)
        muteButton.toolTip = session.muted ? t("adhkar.unmute") : t("adhkar.mute")
    }

    @objc private func collectionChanged(_ sender: NSPopUpButton) {
        session.stop()
        guard collections.indices.contains(sender.indexOfSelectedItem) else { return }
        selectedID = collections[sender.indexOfSelectedItem].id
        renderPreview()
    }

    @objc private func playTapped() {
        if session.isPlaying {
            session.pause()
        } else if session.isPaused {
            session.resume()
        } else if let collection = selectedCollection {
            session.start(collection: collection)
        }
    }

    @objc private func previousTapped() { session.previous() }
    @objc private func nextTapped() { session.next() }
    @objc private func muteTapped() { session.setMuted(!session.muted) }
    @objc private func stopTapped() {
        session.stop()
        renderPreview()
        onFinish?()
    }
    @objc private func smallerTextTapped() {
        let current = arabicTextView.font?.pointSize ?? 19
        manualFontSize = max(13, current - 2)
        applyTextSize(for: arabicTextView.string)
    }
    @objc private func largerTextTapped() {
        let current = arabicTextView.font?.pointSize ?? 19
        manualFontSize = min(30, current + 2)
        applyTextSize(for: arabicTextView.string)
    }
    @objc private func automaticTextTapped() {
        manualFontSize = nil
        applyTextSize(for: arabicTextView.string)
    }
    @objc private func expandTextTapped() {
        isExpanded.toggle()
        updateExpandedLayout()
    }
    @objc private func openMoreTapped() { appDelegate?.openMainWindow(selecting: 1) }

    /// Select and optionally begin a collection from outside the compact
    /// view. Scheduled playback and editor handoff both use this entry point,
    /// so no secondary reader window is needed.
    func present(collection: AdhkarCollection, autoPlay: Bool) {
        session.stop()
        reloadCollections()
        if !collections.contains(where: { $0.id == collection.id }) {
            collections.append(collection)
            collectionPopup.addItem(withTitle: collection.displayName)
        }
        selectedID = collection.id
        if let index = collections.firstIndex(where: { $0.id == collection.id }) {
            collectionPopup.selectItem(at: index)
        }
        if let first = collection.items.first {
            render(item: first, index: 0, total: collection.items.count)
        } else {
            renderPreview()
        }
        if autoPlay { session.start(collection: collection) }
    }
}

// ============================================================================
// MARK: AppDelegate
// ============================================================================
class AppDelegate: NSObject, NSApplicationDelegate, WKNavigationDelegate,
                   UNUserNotificationCenterDelegate,
                   AVAudioPlayerDelegate {

    var statusItem: NSStatusItem!
    /// Transient second menu-bar item that only exists while adhan is playing.
    /// Clicking it cuts the adhan. Populated in `syncStopAdhanStatusItem()`.
    var stopAdhanStatusItem: NSStatusItem?
    var popover: NSPopover!
    var loader: WKWebView!

    /// Floating adhkar window. Lazily instantiated on first use (auto-trigger
    /// or manual menu open) so it costs nothing until needed.
    var adhkarPanel: AdhkarPanel?
    /// Scheduled collections wait here so two collections sharing an anchor
    /// never replace each other in the single reader panel.
    private var scheduledAdhkarQueue: [AdhkarCollection] = []
    private var scheduledAdhkarDelayTimer: Timer?
    private var queuedAdhkarIsWaitingForAdhan = false
    private var completedAdhanAllowsQueuedAdhkar = false

    /// Full management window (v3). Lazily instantiated on first open.
    var mainWindow: MainWindow?

    var info = MosqueInfo()

    // Root holder + mode views. Declared as RootPanelView so the
    // Liquid-Glass-aware `contentContainer` property is visible at call
    // sites (picker/settings add themselves through it).
    var rootHolder: RootPanelView!
    var mainContent: FlippedView!
    var pickerView: MosquePickerView?
    var settingsView: SettingsView?
    /// Prayer-specific views in the compact popup. They are hidden as a
    /// group when the user switches the same popup to its compact Adhkar
    /// sibling; the shared header and footer remain in place.
    var compactPrayerViews: [NSView] = []
    var compactAdhkarView: CompactAdhkarView?
    var compactAdhkarButton: HoverIconButton?
    var isCompactAdhkarMode = false

    // Main view UI
    var nameLabel:     NSTextField!
    var addressLabel:  NSTextField!
    var nextPrayerLbl: NSTextField!
    var countdownLbl:  NSTextField!
    var nextAtLbl:     NSTextField!
    // (name, adhan, offset-badge, iqama, hl-background)
    var timeRowViews:  [(NSTextField, NSTextField, NSTextField, NSTextField, NSView)] = []
    /// Per-row adhan-mode cycle button — one per prayer row. Declared as
    /// optional elements even though Shuruq is no longer a row (kept to
    /// preserve the existing call sites that guard on `.isSome`).
    var modeButtons:   [NSButton?] = []
    var jumuaLbl:      NSTextField!
    var hijriLbl:      NSTextField!
    /// Sunrise strip rendered below the Jumua band — Shuruq is informational
    /// and doesn't belong in the five-prayer table, so it has its own slot.
    var shuruqLbl:     NSTextField!
    /// Gregorian (local system) date, rendered on the right column of the
    /// summary strip alongside the Hijri date. Gives the user both calendars
    /// at a glance without opening the menu bar extras.
    var gregorianLbl:  NSTextField!
    /// Small sunrise glyph next to the Shuruq time so the row reads
    /// "[icon] Shuruq · HH:MM" — matches the monotone SF Symbol look used
    /// across the popover.
    var shuruqIcon:    NSImageView!
    /// Mosque-finder shortcut in the header. It opens the shared Mosque
    /// Settings section instead of leaving the app for a website.
    var headerLinkBtn: NSButton!

    var secondTimer:  Timer?
    var refreshTimer: Timer?
    var adhanPlayer:  AVAudioPlayer?

    /// Is an adhan currently playing? Computed from the player so it reflects
    /// natural stop (file ended) even if nothing explicitly cleared the ref.
    var isAdhanPlaying: Bool { adhanPlayer?.isPlaying ?? false }
    /// Invoked whenever adhan playback starts, stops, or ends naturally.
    /// SettingsView subscribes to swap the test button between play/stop.
    var onAdhanStateChanged: (() -> Void)?

    // ----------------------------------------------------------- setup
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Defaults
        if UserDefaults.standard.object(forKey: kAdhanEnabled) == nil {
            UserDefaults.standard.set(true, forKey: kAdhanEnabled)
        }
        if UserDefaults.standard.object(forKey: kNotificationsKey) == nil {
            UserDefaults.standard.set(true, forKey: kNotificationsKey)
        }
        if UserDefaults.standard.object(forKey: kAdhanSoundKey) == nil {
            UserDefaults.standard.set("makkah_mulla", forKey: kAdhanSoundKey)
        }
        if UserDefaults.standard.object(forKey: kTimeFormat) == nil {
            UserDefaults.standard.set("24h", forKey: kTimeFormat)
        }
        if UserDefaults.standard.object(forKey: kPrayerShowCountdown) == nil {
            UserDefaults.standard.set(true, forKey: kPrayerShowCountdown)
        }
        if UserDefaults.standard.object(forKey: kArabicDigitStyle) == nil {
            UserDefaults.standard.set(ArabicDigitStyle.western.rawValue,
                                      forKey: kArabicDigitStyle)
        }
        if UserDefaults.standard.object(forKey: kBarShowIcon) == nil {
            UserDefaults.standard.set(true, forKey: kBarShowIcon)
        }
        if UserDefaults.standard.object(forKey: kBarShowTime) == nil {
            UserDefaults.standard.set(true, forKey: kBarShowTime)
        }
        // New independent countdown toggle — defaults ON so the menu bar
        // keeps its live "MM:SS ticking down" behaviour for anyone
        // upgrading from a version that bundled time + countdown.
        if UserDefaults.standard.object(forKey: kBarShowCountdown) == nil {
            UserDefaults.standard.set(true, forKey: kBarShowCountdown)
        }
        if UserDefaults.standard.object(forKey: kBarShowHijri) == nil {
            UserDefaults.standard.set(false, forKey: kBarShowHijri)
        }
        // Migrate legacy bool → new enum the first time the user runs a
        // build that has the picker. Preserves whatever they had before.
        if UserDefaults.standard.object(forKey: kBarHijriFormat) == nil {
            let wasOn = UserDefaults.standard.bool(forKey: kBarShowHijri)
            UserDefaults.standard.set(wasOn ? HijriFormat.full.rawValue
                                            : HijriFormat.off.rawValue,
                                      forKey: kBarHijriFormat)
        }
        // Sync the persisted "open at login" preference with the live system
        // status on every launch. Covers the case where the user re-installs
        // or the OS forgot the registration; also writes `false` on first run
        // so the checkbox starts in a known state.
        if UserDefaults.standard.object(forKey: kOpenAtLogin) == nil {
            UserDefaults.standard.set(isOpenAtLoginEnabled(), forKey: kOpenAtLogin)
        } else {
            let wanted = UserDefaults.standard.bool(forKey: kOpenAtLogin)
            if wanted != isOpenAtLoginEnabled() {
                setOpenAtLogin(wanted)
            }
        }
        // Adhkar defaults: feature on, morning follows sunrise, evening follows Asr.
        if UserDefaults.standard.object(forKey: kAdhkarEnabled) == nil {
            UserDefaults.standard.set(true, forKey: kAdhkarEnabled)
        }
        if UserDefaults.standard.object(forKey: kAdhkarMorningAnchor) == nil {
            UserDefaults.standard.set("shuruq", forKey: kAdhkarMorningAnchor)
        }
        if UserDefaults.standard.object(forKey: kAdhkarEveningAnchor) == nil {
            UserDefaults.standard.set("asr", forKey: kAdhkarEveningAnchor)
        }
        if UserDefaults.standard.object(forKey: kAdhkarVolume) == nil {
            UserDefaults.standard.set(1.0, forKey: kAdhkarVolume)
        }
        if UserDefaults.standard.object(forKey: kAdhkarAfterAdhanDelay) == nil {
            UserDefaults.standard.set(0, forKey: kAdhkarAfterAdhanDelay)
        }

        registerCairoFonts()
        // One-time migrations: v2→v3 (morning/evening) + v3.1 (expanded catalog).
        migrateAdhkarDefaults()
        migrateAdhkarExpandedCatalog()
        migrateAdhkarCollectionIdentity()
        Localizer.shared.onChange = { [weak self] in self?.applyLanguageChange() }

        loadCachedInfo()
        setupStatusItem()
        setupPopover()
        setupLoader()
        applyAppearancePref()

        UNUserNotificationCenter.current().delegate = self
        requestNotificationAuthorization()

        secondTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.tick()
        }
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 30*60, repeats: true) { [weak self] _ in
            self?.fetchData()
        }

        fetchData()
        tick()
        updateUI()
    }

    /// Reopening the already-running accessory app from Finder, Spotlight,
    /// or the Dock should reveal the full experience instead of appearing to
    /// do nothing. This also makes the standard macOS reopen gesture match
    /// the "Open Main Window…" menu item.
    func applicationShouldHandleReopen(_ sender: NSApplication,
                                       hasVisibleWindows flag: Bool) -> Bool {
        openMainWindow()
        return true
    }

    func requestNotificationAuthorization() {
        UNUserNotificationCenter.current().requestAuthorization(
            options: [.alert, .sound]
        ) { _, _ in }
    }

    // Show notifications even when app is foregrounded
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification,
                                withCompletionHandler completionHandler:
                                    @escaping (UNNotificationPresentationOptions) -> Void) {
        if #available(macOS 11.0, *) {
            completionHandler([.banner, .sound])
        } else {
            completionHandler([.alert, .sound])
        }
    }

    // --------------------------------------------------------- menu bar
    func setupStatusItem() {
        // Use variableLength so the button auto-sizes to its content exactly —
        // this is Apple's recommended approach for menu-bar items and means
        // the status item never shows extra empty space on the sides. The
        // title uses a monospaced-digit font so per-second countdown ticks
        // don't cause the width to wiggle between frames.
        let showIcon = UserDefaults.standard.object(forKey: kBarShowIcon) as? Bool ?? true

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let b = statusItem.button {
            b.image = showIcon ? makeMenuBarIcon() : nil
            b.imagePosition = showIcon ? .imageLeft : .noImage
            b.imageHugsTitle = true
            b.title = ""
            b.toolTip = "Salat Time"
            b.action = #selector(statusClicked(_:))
            b.target = self
            b.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }
    }

    /// Tear down and rebuild the status-item so its length + icon reflect the
    /// current menu-bar preference toggles. Cheap (single NSStatusItem).
    func rebuildStatusItem() {
        if let item = statusItem {
            NSStatusBar.system.removeStatusItem(item)
        }
        setupStatusItem()
        tick()
    }

    /// Renders the menu-bar countdown using a monospaced-digit font so each
    /// digit occupies the same advance width (no horizontal wiggle per tick).
    /// When `color` is provided the title is drawn in that colour — used for
    /// the red iqama countdown during the adhan→iqama window. When
    /// `background` is provided the glyphs are drawn over a filled rectangle
    /// of that colour (leading/trailing spaces in the string provide the
    /// horizontal padding for the pill).
    func setStatusTitle(_ text: String,
                        color: NSColor? = nil,
                        background: NSColor? = nil) {
        guard let b = statusItem.button else { return }
        if text.isEmpty {
            b.attributedTitle = NSAttributedString(string: "")
            b.title = ""
            return
        }
        let font = NSFont.monospacedDigitSystemFont(
            ofSize: NSFont.systemFontSize(for: .small),
            weight: .medium)
        let para = NSMutableParagraphStyle()
        para.alignment = .left
        var attrs: [NSAttributedString.Key: Any] = [
            .font: font,
            .paragraphStyle: para,
        ]
        if let color = color {
            attrs[.foregroundColor] = color
        }
        if let background = background {
            attrs[.backgroundColor] = background
        }
        b.attributedTitle = NSAttributedString(string: text, attributes: attrs)
    }

    @objc func statusClicked(_ sender: Any?) {
        if NSApp.currentEvent?.type == .rightMouseUp {
            showContextMenu()
        } else {
            togglePopover()
        }
    }

    func showContextMenu() {
        let menu = NSMenu()
        let n = NSMenuItem(title: info.name.isEmpty ? t("mosque.default") : info.name, action: nil, keyEquivalent: "")
        n.isEnabled = false
        menu.addItem(n)
        menu.addItem(.separator())

        menu.addItem(NSMenuItem(title: t("menu.open"),     action: #selector(menuOpen),     keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: t("menu.refresh"),  action: #selector(menuRefresh),  keyEquivalent: "r"))
        menu.addItem(NSMenuItem(title: t("menu.choose"),   action: #selector(menuChoose),   keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: t("menu.settings"), action: #selector(menuSettings), keyEquivalent: ","))

        // Open the full main window (management UI) — the single entry point
        // for browsing, reciting, and editing adhkar.
        menu.addItem(NSMenuItem(title: t("menu.main_window"),
                                 action: #selector(menuOpenMainWindow),
                                 keyEquivalent: "o"))

        // Favorites submenu
        let favs = loadFavorites()
        if !favs.isEmpty {
            let favItem = NSMenuItem(title: t("menu.favorites"), action: nil, keyEquivalent: "")
            let sub = NSMenu()
            let curNorm = normalizeMosqueURL(currentMosqueURL())
            for (i, f) in favs.enumerated() {
                let title = f.city.isEmpty ? f.name : "\(f.name) — \(f.city)"
                let it = NSMenuItem(title: title, action: #selector(switchToFavorite(_:)), keyEquivalent: "")
                it.tag = i
                if normalizeMosqueURL(f.url) == curNorm { it.state = .on }
                sub.addItem(it)
            }
            favItem.submenu = sub
            menu.addItem(favItem)
        }

        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: t("menu.quit"),
                                action: #selector(NSApplication.terminate(_:)),
                                keyEquivalent: "q"))
        statusItem.menu = menu
        statusItem.button?.performClick(nil)
        statusItem.menu = nil
    }

    @objc func menuOpen()    { togglePopover() }
    @objc func menuRefresh() { fetchData() }
    @objc func menuChoose() { openMosqueSettings() }
    @objc func menuSettings() {
        openSettingsWindow(section: .general)
    }
    /// Open the full prayer + adhkar management window. Destination 0 is
    /// Adhan/prayer times and 1 is Adhkar.
    @objc func menuOpenMainWindow() { openMainWindow() }
    func openMainWindow(selecting destination: Int? = nil) {
        if mainWindow == nil {
            let w = MainWindow(appDelegate: self)
            let adhan = PrayerDashboardViewController(appDelegate: self)
            let editor = AdhkarEditorViewController(appDelegate: self)
            w.setAdhan(adhan)
            w.setEditor(editor)
            w.setQuran(QuranViewController())
            mainWindow = w
        }
        mainWindow?.showMainWindow(selecting: destination)
    }

    func openSettingsWindow(section: SettingsSection) {
        popover?.performClose(nil)
        if mainWindow == nil {
            let w = MainWindow(appDelegate: self)
            w.setAdhan(PrayerDashboardViewController(appDelegate: self))
            w.setEditor(AdhkarEditorViewController(appDelegate: self))
            w.setQuran(QuranViewController())
            mainWindow = w
        }
        mainWindow?.showSettingsWindow(section: section)
        mainWindow?.showMainWindow()
    }
    func openMosqueSettings() {
        openSettingsWindow(section: .mosque)
    }
    @objc func switchToFavorite(_ sender: NSMenuItem) {
        let favs = loadFavorites()
        guard favs.indices.contains(sender.tag) else { return }
        setCurrentMosque(favs[sender.tag].url)
        currentMosqueDidChange()
    }

    // -------------------------------------------------- language quick menu
    /// Pop up a native NSMenu anchored under the globe button listing all
    /// supported languages in their native script. A check-mark marks the
    /// active language. Selecting an entry routes through Localizer so every
    /// view rebuilds immediately — no need to open Settings.
    @objc func languageBtnTapped(_ sender: NSButton) {
        let menu = NSMenu()
        menu.autoenablesItems = false
        let curCode = Localizer.shared.current.code
        for lang in kSupportedLanguages {
            let item = NSMenuItem(title: lang.nativeName,
                                  action: #selector(languageMenuPicked(_:)),
                                  keyEquivalent: "")
            item.target = self
            item.representedObject = lang.code
            if lang.code == curCode { item.state = .on }
            menu.addItem(item)
        }
        // Position the menu just below the button, flush with its left edge
        // so the dropdown feels visually tethered to the icon.
        let origin = NSPoint(x: 0, y: sender.bounds.height + 4)
        menu.popUp(positioning: nil, at: origin, in: sender)
    }

    @objc func languageMenuPicked(_ sender: NSMenuItem) {
        guard let code = sender.representedObject as? String else { return }
        Localizer.shared.setLanguage(code)
    }

    // ------------------------------------------------------- theme quick menu
    private func accentDisplayName(_ key: String) -> String {
        return accentLocalizedName(key)
    }
    private func accentSwatch(_ key: String) -> NSImage? {
        return accentSwatchImage(key)
    }

    @objc func themeBtnTapped(_ sender: NSButton) {
        let menu = NSMenu()
        menu.autoenablesItems = false

        // -- Appearance radio group --
        let curAppearance = UserDefaults.standard.string(forKey: kAppearanceKey) ?? "system"
        let appearanceHdr = NSMenuItem(title: t("menu.theme.header.appearance"),
                                       action: nil, keyEquivalent: "")
        appearanceHdr.isEnabled = false
        menu.addItem(appearanceHdr)
        for (key, sym) in [("system","circle.righthalf.filled"),
                           ("light","sun.max.fill"),
                           ("dark","moon.fill")] {
            let item = NSMenuItem(title: t("menu.theme.appearance.\(key)"),
                                  action: #selector(themeAppearancePicked(_:)),
                                  keyEquivalent: "")
            item.target = self
            item.representedObject = key
            if let img = templateSymbol(sym, pointSize: 12, weight: .regular) {
                item.image = img
            }
            if key == curAppearance { item.state = .on }
            menu.addItem(item)
        }

        menu.addItem(NSMenuItem.separator())

        // -- Accent color radio group --
        let accentHdr = NSMenuItem(title: t("menu.theme.header.accent"),
                                   action: nil, keyEquivalent: "")
        accentHdr.isEnabled = false
        menu.addItem(accentHdr)
        let curAccent = currentAccentKey()
        for key in kAccentOrder {
            let item = NSMenuItem(title: accentDisplayName(key),
                                  action: #selector(themeAccentPicked(_:)),
                                  keyEquivalent: "")
            item.target = self
            item.representedObject = key
            item.image = accentSwatch(key)
            if key == curAccent { item.state = .on }
            menu.addItem(item)
        }

        menu.addItem(NSMenuItem.separator())

        // -- Material radio group --
        let matHdr = NSMenuItem(title: t("menu.theme.header.material"),
                                action: nil, keyEquivalent: "")
        matHdr.isEnabled = false
        menu.addItem(matHdr)
        let curMaterial = UserDefaults.standard.string(forKey: kMaterialPref) ?? "opaque"
        for (key, sym) in [("opaque","square.fill"),
                           ("glass","drop.fill")] {
            let item = NSMenuItem(title: t("menu.theme.material.\(key)"),
                                  action: #selector(themeMaterialPicked(_:)),
                                  keyEquivalent: "")
            item.target = self
            item.representedObject = key
            if let img = templateSymbol(sym, pointSize: 12, weight: .regular) {
                item.image = img
            }
            if key == curMaterial { item.state = .on }
            menu.addItem(item)
        }

        let origin = NSPoint(x: 0, y: sender.bounds.height + 4)
        menu.popUp(positioning: nil, at: origin, in: sender)
    }

    @objc func themeAppearancePicked(_ sender: NSMenuItem) {
        guard let key = sender.representedObject as? String else { return }
        UserDefaults.standard.set(key, forKey: kAppearanceKey)
        applyAppearancePref()
    }

    @objc func themeAccentPicked(_ sender: NSMenuItem) {
        guard let key = sender.representedObject as? String else { return }
        UserDefaults.standard.set(key, forKey: kAccentPref)
        // Views captured the previous accent at build time; rebuild so the
        // new shade propagates to every label, chip, and swatch.
        applyThemeChange()
    }

    @objc func themeMaterialPicked(_ sender: NSMenuItem) {
        guard let key = sender.representedObject as? String else { return }
        UserDefaults.standard.set(key, forKey: kMaterialPref)
        applyThemeChange()
    }

    /// Rebuild the popover contents so any color- or material-dependent
    /// views get a fresh pass. Mirrors `applyLanguageChange` which handles
    /// the same problem for localised strings. RootPanelView.init calls
    /// applyMaterial() itself so we don't need to nudge it again here.
    func applyThemeChange() {
        let wasShown = popover?.isShown ?? false
        pickerView = nil
        settingsView = nil
        popover.contentViewController = buildContent()
        mainWindow?.reloadForPreferences()
        adhkarPanel?.reloadForPreferences()
        updateUI()
        tick()
        if wasShown, let btn = statusItem.button {
            popover.show(relativeTo: btn.bounds, of: btn, preferredEdge: .minY)
        }
    }

    func togglePopover() {
        guard let btn = statusItem.button else { return }
        if popover.isShown { popover.performClose(nil); return }
        popover.show(relativeTo: btn.bounds, of: btn, preferredEdge: .minY)
        popover.contentViewController?.view.window?.makeKey()
        updateUI()
    }

    // --------------------------------------------------------- popover
    func setupPopover() {
        popover = NSPopover()
        popover.behavior = .transient
        popover.animates = true
        popover.contentSize = NSSize(width: 280, height: 490)
        popover.contentViewController = buildContent()
    }

    func buildContent() -> NSViewController {
        let vc = NSViewController()
        let W: CGFloat = 280, H: CGFloat = 490

        compactPrayerViews.removeAll()
        compactAdhkarView = nil
        compactAdhkarButton = nil
        isCompactAdhkarMode = false

        // Appearance-adaptive root. In Liquid Glass mode, `contentContainer`
        // is the NSVisualEffectView so content inherits vibrancy and sits
        // above the contrast scrim. In opaque mode, `contentContainer` is
        // the root itself. Using the property keeps the choice in one
        // place and works the same for picker/settings screens below.
        let root = RootPanelView(frame: NSRect(x: 0, y: 0, width: W, height: H))
        rootHolder = root

        mainContent = FlippedView(frame: root.bounds)
        mainContent.autoresizingMask = [.width, .height]
        root.contentContainer.addSubview(mainContent)

        buildMainSubtree(into: mainContent, W: W, H: H)

        vc.view = root
        return vc
    }

    private func buildMainSubtree(into content: FlippedView, W: CGFloat, H: CGFloat) {
        // Header (green bg, icon + name + address). Layout tuned so the icon
        // (48×48) and the name+address text block share the same vertical
        // center (y=36) — the previous 44×44 icon + upper-biased text made the
        // text clump look disconnected from the icon.
        let headerH: CGFloat = 72
        let headerBG = FlippedView(frame: NSRect(x: 0, y: 0, width: W, height: headerH))
        headerBG.wantsLayer = true
        headerBG.layer?.backgroundColor = NSColor.appGreenHeader.cgColor
        headerBG.autoresizingMask = [.width]
        content.addSubview(headerBG)

        // App icon — 48×48, vertically centered (12 + 48 + 12 = 72).
        // We use a white SF Symbol on the accent-tinted header strip so the
        // icon automatically reads against any accent the user picks. The
        // PNG app icon would stay bright-green regardless of theme, which is
        // exactly the mismatch users flagged.
        let iconView = NSImageView(frame: NSRect(x: 12, y: 12, width: 48, height: 48))
        if let sym = templateSymbol("moon.stars.fill", pointSize: 34, weight: .semibold) {
            iconView.image = sym
            iconView.contentTintColor = NSColor(white: 1.0, alpha: 0.95)
        } else {
            iconView.image = loadAppIcon()
        }
        iconView.imageScaling = .scaleProportionallyDown
        headerBG.addSubview(iconView)

        // Name — vertically centered with the icon by default. When an
        // address is present, updateUI() drops the name to y=12 and slots
        // the address below so the pair is vertically centered as a block.
        // Width is trimmed by the header link button on the right edge
        // (W - 80 - 44 = W - 124) so long mosque names don't overlap it.
        nameLabel = NSTextField(labelWithString: info.name)
        nameLabel.frame = NSRect(x: 68, y: 25, width: W - 124, height: 22)
        nameLabel.font = Localizer.shared.font(size: 13, weight: .semibold)
        nameLabel.textColor = .white
        nameLabel.drawsBackground = false
        nameLabel.lineBreakMode = .byTruncatingTail
        nameLabel.alignment = .left
        fitLocalizedLabel(nameLabel)
        headerBG.addSubview(nameLabel)

        // Address (up to 2 lines).
        addressLabel = NSTextField(wrappingLabelWithString: "")
        addressLabel.frame = NSRect(x: 68, y: 34, width: W - 124, height: 26)
        addressLabel.font = Localizer.shared.font(size: 10)
        addressLabel.textColor = NSColor(white: 1.0, alpha: 0.85)
        addressLabel.drawsBackground = false
        addressLabel.maximumNumberOfLines = 2
        addressLabel.lineBreakMode = .byTruncatingTail
        addressLabel.alignment = .left
        fitLocalizedLabel(addressLabel, maximumLines: 2)
        headerBG.addSubview(addressLabel)

        // Mosque-finder shortcut — 44pt target, localized accessibility name,
        // and an in-app destination shared with the dashboard/context menu.
        let mosqueShortcut = HoverIconButton(
            symbol: "mappin.and.ellipse",
            toolTip: t("menu.choose"),
            target: self,
            action: #selector(changeMosqueTapped),
            pointSize: 18,
            size: NSSize(width: 44, height: 44))
        mosqueShortcut.setFrameOrigin(NSPoint(x: W - 56, y: 14))
        mosqueShortcut.idleTint = NSColor(white: 1.0, alpha: 0.95)
        mosqueShortcut.hoverTint = .white
        mosqueShortcut.contentTintColor = mosqueShortcut.idleTint
        mosqueShortcut.setAccessibilityLabel(t("menu.choose"))
        mosqueShortcut.setAccessibilityHelp(t("settings.mosque.change"))
        headerLinkBtn = mosqueShortcut
        headerLinkBtn.autoresizingMask = [.minXMargin]
        headerBG.addSubview(headerLinkBtn)

        // Everything added to the root after this point and before the
        // footer belongs to the compact prayer view. Keeping these views as
        // a group lets the book button swap to Adhkar without rebuilding the
        // popover or disturbing its shared header/tool bar.
        let prayerBodySubviewStart = content.subviews.count

        // Next-prayer label
        nextPrayerLbl = NSTextField(labelWithString: "")
        nextPrayerLbl.frame = NSRect(x: 16, y: 82, width: W - 32, height: 16)
        nextPrayerLbl.font = Localizer.shared.font(size: 10, weight: .semibold)
        nextPrayerLbl.textColor = .secondaryLabelColor
        nextPrayerLbl.drawsBackground = false
        nextPrayerLbl.alignment = .center
        fitLocalizedLabel(nextPrayerLbl)
        content.addSubview(nextPrayerLbl)

        // Countdown
        countdownLbl = NSTextField(labelWithString: "--:--:--")
        countdownLbl.frame = NSRect(x: 16, y: 100, width: W - 32, height: 44)
        countdownLbl.font = NSFont.monospacedDigitSystemFont(ofSize: 34, weight: .bold)
        countdownLbl.textColor = .appGreenAccent
        countdownLbl.drawsBackground = false
        countdownLbl.alignment = .center
        content.addSubview(countdownLbl)

        nextAtLbl = NSTextField(labelWithString: "")
        nextAtLbl.frame = NSRect(x: 16, y: 146, width: W - 32, height: 16)
        nextAtLbl.font = NSFont.systemFont(ofSize: 11)
        nextAtLbl.textColor = .secondaryLabelColor
        nextAtLbl.drawsBackground = false
        nextAtLbl.alignment = .center
        content.addSubview(nextAtLbl)

        // Separator + column headers
        let sep = NSBox(frame: NSRect(x: 16, y: 172, width: W - 32, height: 1))
        sep.boxType = .separator
        content.addSubview(sep)

        let colName  = NSTextField(labelWithString: t("col.prayer"))
        let colAdhan = NSTextField(labelWithString: t("col.adhan"))
        let colIqama = NSTextField(labelWithString: t("col.iqama"))
        //              (field,    x,    width)   — compact columns tuned for
        //   the 280-wide popover. Iqama header sits clear of the offset badge
        //   so the row reads: [Prayer]  [Adhan +offset]  [Iqama] [🔔].
        for (v, x, wd) in [(colName, 16.0, 74.0), (colAdhan, 94.0, 60.0), (colIqama, 186.0, 46.0)] {
            v.frame = NSRect(x: x, y: 180, width: wd, height: 14)
            v.font = Localizer.shared.font(size: 9, weight: .medium)
            v.textColor = .tertiaryLabelColor
            v.drawsBackground = false
            // Same authoring as the data cells below — left-aligned in LTR,
            // applyRTL mirrors to right-aligned for Arabic/Urdu so the
            // column header sits directly above its values.
            v.alignment = .left
            fitLocalizedLabel(v)
            content.addSubview(v)
        }

        // Prayer rows — Shuruq intentionally excluded from this list because
        // it's not a prayer; it's shown on its own strip below the Jumua
        // band so the main table only contains the five daily salats.
        let rowKeys = ["prayer.fajr", "prayer.dhuhr",
                       "prayer.asr",  "prayer.maghrib", "prayer.isha"]
        // Display-row → prayer-index mapping — identity now that Shuruq is gone.
        let rowToPrayerIdx: [Int?] = [0, 1, 2, 3, 4]
        timeRowViews.removeAll()
        modeButtons.removeAll()
        let rowY0: CGFloat = 198
        let rowH:  CGFloat = 30
        let accentPair = currentAccentPair()
        for (i, key) in rowKeys.enumerated() {
            let y = rowY0 + CGFloat(i) * rowH
            // Highlight uses the currently-selected accent with a low alpha so
            // the coloured strip is legible behind the row text in both modes.
            // Using currentAccentPair() means the highlight updates whenever
            // the user picks a new accent from the theme menu.
            let hl = AdaptiveBackgroundView(
                frame: NSRect(x: 12, y: y - 2, width: W - 24, height: rowH - 2),
                light: accentPair.light.withAlphaComponent(0.14),
                dark:  accentPair.dark.withAlphaComponent(0.22),
                radius: 8
            )
            hl.isHidden = true
            content.addSubview(hl)

            let name = NSTextField(labelWithString: t(key))
            name.frame = NSRect(x: 16, y: y + 5, width: 74, height: 20)
            name.font = Localizer.shared.font(size: 13, weight: .medium)
            name.textColor = .labelColor
            name.drawsBackground = false
            name.lineBreakMode = .byTruncatingTail
            // Authored as left-aligned; applyRTL flips .left ↔ .right so
            // Arabic/Urdu labels hug the right wall of their column instead
            // of floating mid-cell where they collide with the times column.
            name.alignment = .left
            fitLocalizedLabel(name)
            content.addSubview(name)

            // Adhan — primary, larger. Monospaced digits keep the width stable.
            let adhan = NSTextField(labelWithString: "--:--")
            adhan.frame = NSRect(x: 94, y: y + 3, width: 58, height: 22)
            adhan.font = NSFont.monospacedDigitSystemFont(ofSize: 15, weight: .semibold)
            adhan.textColor = .labelColor
            adhan.drawsBackground = false
            adhan.alignment = .left
            content.addSubview(adhan)

            // Offset badge — small green "+X" directly after the adhan time.
            let offset = NSTextField(labelWithString: "")
            offset.frame = NSRect(x: 154, y: y + 9, width: 28, height: 14)
            offset.font = NSFont.monospacedDigitSystemFont(ofSize: 10, weight: .medium)
            offset.textColor = .appGreenAccent
            offset.drawsBackground = false
            offset.alignment = .left
            content.addSubview(offset)

            // Iqama — clearly separated from the offset badge so the
            // [Iqama] column header visually lines up with the iqama value,
            // not with the +offset chip belonging to adhan.
            let iqama = NSTextField(labelWithString: "—")
            iqama.frame = NSRect(x: 186, y: y + 7, width: 46, height: 18)
            iqama.font = NSFont.monospacedDigitSystemFont(ofSize: 11, weight: .regular)
            iqama.textColor = .tertiaryLabelColor
            iqama.drawsBackground = false
            iqama.alignment = .left
            content.addSubview(iqama)

            timeRowViews.append((name, adhan, offset, iqama, hl))

            // Adhan-mode cycle button — one per prayer row. Placed right after
            // the iqama time so it feels attached to the row. Layout is
            // authored in LTR; `applyRTL` mirrors it for Arabic/Urdu.
            if let prayerIdx = rowToPrayerIdx[i] {
                let btn = NSButton(frame: NSRect(x: 238, y: y + 4, width: 24, height: 24))
                btn.bezelStyle = .regularSquare
                btn.isBordered = false
                btn.title = ""
                btn.tag = prayerIdx
                btn.target = self
                btn.action = #selector(adhanModeButtonTapped(_:))
                btn.imagePosition = .imageOnly
                btn.imageScaling = .scaleProportionallyDown
                btn.setButtonType(.momentaryChange)
                btn.focusRingType = .none
                // applyAdhanModeIcon sets the right SF Symbol, tint, and tooltip
                // for the current mode.
                applyAdhanModeIcon(to: btn, mode: adhanModeForPrayer(prayerIdx))
                content.addSubview(btn)
                modeButtons.append(btn)
            } else {
                modeButtons.append(nil)
            }
        }

        // ---------------- Summary strip ----------------
        // Container band that groups the non-prayer info (Jumua, Shuruq,
        // Hijri date, Gregorian date) into a single visual unit. Using a
        // distinct neutral background (vs. the accent highlight on the
        // active prayer row) makes it obvious that this strip isn't part
        // of the five-prayer table above — it's contextual information.
        //
        // Layout inside the strip:
        //    ┌──────────────────────────────────────────────┐
        //    │  Jumua · HH:MM            Hijri date         │
        //    │  ☀ Shuruq · HH:MM         Gregorian date     │
        //    └──────────────────────────────────────────────┘
        let summaryY: CGFloat   = 360
        let summaryH: CGFloat   = 64
        let summaryBG = AdaptiveBackgroundView(
            frame: NSRect(x: 12, y: summaryY, width: W - 24, height: summaryH),
            light: NSColor(white: 0.0, alpha: 0.05),
            dark:  NSColor(white: 1.0, alpha: 0.07),
            radius: 10
        )
        summaryBG.autoresizingMask = [.width]
        content.addSubview(summaryBG)

        // Column geometry — shared by both rows. Left column hosts Jumua /
        // Shuruq, right column hosts Hijri / Gregorian. Paddings keep text
        // clear of the rounded corners.
        let colW: CGFloat       = (W - 24) / 2
        let colPad: CGFloat     = 10
        let leftColX: CGFloat   = 12 + colPad
        let rightColX: CGFloat  = 12 + colW
        let rightColW: CGFloat  = colW - colPad
        let topRowY: CGFloat    = summaryY + 6
        let botRowY: CGFloat    = summaryY + 34

        // Jumua — top-left. Left-aligned so it lines up with Shuruq below.
        jumuaLbl = NSTextField(labelWithString: "")
        jumuaLbl.frame = NSRect(x: leftColX, y: topRowY, width: colW - colPad, height: 22)
        jumuaLbl.font = Localizer.shared.font(size: 13, weight: .semibold)
        jumuaLbl.textColor = .appGreenAccent
        jumuaLbl.drawsBackground = false
        jumuaLbl.alignment = .left
        fitLocalizedLabel(jumuaLbl)
        content.addSubview(jumuaLbl)

        // Hijri — top-right. Right-aligned so it hugs the right wall of the strip.
        hijriLbl = NSTextField(labelWithString: "")
        hijriLbl.frame = NSRect(x: rightColX, y: topRowY, width: rightColW, height: 22)
        hijriLbl.font = Localizer.shared.font(size: 12, weight: .medium)
        hijriLbl.textColor = .labelColor
        hijriLbl.drawsBackground = false
        hijriLbl.alignment = .right
        fitLocalizedLabel(hijriLbl)
        content.addSubview(hijriLbl)

        // Shuruq (sunrise) — bottom-left, preceded by a small sunrise glyph
        // that matches the monotone SF Symbol look used across the popover.
        shuruqIcon = NSImageView(frame: NSRect(x: leftColX, y: botRowY + 3, width: 14, height: 14))
        if let sym = templateSymbol("sunrise.fill", pointSize: 12, weight: .medium) {
            shuruqIcon.image = sym
        }
        shuruqIcon.contentTintColor = .appGreenAccent
        shuruqIcon.imageScaling = .scaleProportionallyDown
        content.addSubview(shuruqIcon)

        shuruqLbl = NSTextField(labelWithString: "")
        shuruqLbl.frame = NSRect(x: leftColX + 18, y: botRowY, width: colW - colPad - 18, height: 22)
        shuruqLbl.font = Localizer.shared.font(size: 12, weight: .medium)
        shuruqLbl.textColor = .secondaryLabelColor
        shuruqLbl.drawsBackground = false
        shuruqLbl.alignment = .left
        fitLocalizedLabel(shuruqLbl)
        content.addSubview(shuruqLbl)

        // Gregorian date — bottom-right, under the Hijri date. Uses the
        // system calendar formatted in the current UI language so English
        // users see "Tue 22 Apr 2026" while Arabic users see "الثلاثاء 22 أبريل 2026".
        gregorianLbl = NSTextField(labelWithString: "")
        gregorianLbl.frame = NSRect(x: rightColX, y: botRowY, width: rightColW, height: 22)
        gregorianLbl.font = Localizer.shared.font(size: 11, weight: .regular)
        gregorianLbl.textColor = .secondaryLabelColor
        gregorianLbl.drawsBackground = false
        gregorianLbl.alignment = .right
        fitLocalizedLabel(gregorianLbl)
        content.addSubview(gregorianLbl)

        compactPrayerViews = Array(content.subviews.dropFirst(prayerBodySubviewStart))
        let compactAdhkar = CompactAdhkarView(
            frame: NSRect(x: 0, y: 72, width: W, height: 360),
            appDelegate: self)
        compactAdhkar.onFinish = { [weak self] in
            DispatchQueue.main.async { self?.presentNextScheduledAdhkarIfPossible() }
        }
        compactAdhkar.isHidden = true
        content.addSubview(compactAdhkar)
        compactAdhkarView = compactAdhkar

        // ---------------- Bottom toolbar ----------------
        // Hairline separator
        let footerSep = NSBox(frame: NSRect(x: 16, y: 432, width: W - 32, height: 1))
        footerSep.boxType = .separator
        footerSep.autoresizingMask = [.width]
        content.addSubview(footerSep)

        // Four icon buttons, evenly spaced across the bottom row.
        // Centers at 12.5/37.5/62.5/87.5 % give ~26 pt gaps between 44 pt
        // buttons — visually balanced without feeling cramped.
        let btnSize  = NSSize(width: 44, height: 34)
        let btnY: CGFloat = 444
        let centers: [CGFloat] = [W * 0.125, W * 0.375, W * 0.625, W * 0.875]

        // Preferences now live exclusively in the full Settings surface, so
        // the compact toolbar keeps only daily actions.
        let refreshBtn = HoverIconButton(
            symbol: "arrow.clockwise",
            toolTip: t("tooltip.refresh"),
            target: self,
            action: #selector(menuRefresh),
            pointSize: 15,
            size: btnSize)
        refreshBtn.setFrameOrigin(NSPoint(x: centers[0] - btnSize.width/2, y: btnY))
        content.addSubview(refreshBtn)

        let quranBtn = HoverIconButton(
            symbol: "book.pages.fill",
            toolTip: featureText("quran.tab"),
            target: self,
            action: #selector(openQuranFromPopup),
            pointSize: 15,
            size: btnSize)
        quranBtn.setFrameOrigin(NSPoint(x: centers[1] - btnSize.width/2, y: btnY))
        content.addSubview(quranBtn)

        // Adhkar button — switches this same compact surface between prayer
        // times and the compact reader. The reader itself exposes a "More
        // controls" affordance for the full management window.
        let adhkarBtn = HoverIconButton(
            symbol: "text.book.closed.fill",
            toolTip: t("adhkar.editor.title"),
            target: self,
            action: #selector(toggleCompactAdhkar),
            pointSize: 15,
            size: btnSize)
        adhkarBtn.setFrameOrigin(NSPoint(x: centers[2] - btnSize.width/2, y: btnY))
        content.addSubview(adhkarBtn)
        compactAdhkarButton = adhkarBtn

        let settingsBtn = HoverIconButton(
            symbol: "gearshape.fill",
            toolTip: t("tooltip.settings"),
            target: self,
            action: #selector(settingsTapped),
            pointSize: 15,
            size: btnSize)
        settingsBtn.setFrameOrigin(NSPoint(x: centers[3] - btnSize.width/2, y: btnY))
        content.addSubview(settingsBtn)

        // ---------------- RTL pass for Arabic (and Urdu) -----------------
        // Recursive: mirrors content + every nested subtree in one call.
        if Localizer.shared.isRTL {
            applyRTL(content)
        }
    }

    // -------------------------------------------------------- mode swap
    @objc func changeMosqueTapped() { openMosqueSettings() }
    @objc func openQuranFromPopup() {
        popover?.performClose(nil)
        openMainWindow(selecting: 2)
    }
    @objc func settingsTapped() {
        // Prayer popup → Adhan settings; compact Adhkar → Adhkar settings.
        openSettingsWindow(section: isCompactAdhkarMode ? .adhkar : .adhan)
    }

    @objc func toggleCompactAdhkar() {
        setCompactAdhkarMode(!isCompactAdhkarMode)
    }

    private func setCompactAdhkarMode(_ enabled: Bool) {
        isCompactAdhkarMode = enabled
        compactPrayerViews.forEach { $0.isHidden = enabled }
        compactAdhkarView?.isHidden = !enabled
        if enabled { compactAdhkarView?.reloadCollections() }
        updateUI()
        let tint: NSColor = enabled ? .appGreenAccent : .secondaryLabelColor
        compactAdhkarButton?.idleTint = tint
        compactAdhkarButton?.contentTintColor = tint
    }

    private func showCompactAdhkar(_ collection: AdhkarCollection, autoPlay: Bool) {
        pickerView?.isHidden = true
        settingsView?.isHidden = true
        mainContent.isHidden = false
        setCompactAdhkarMode(true)
        compactAdhkarView?.present(collection: collection, autoPlay: autoPlay)
        guard !popover.isShown, let button = statusItem.button else { return }
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
    }

    func showPicker() {
        settingsView?.isHidden = true
        if pickerView == nil {
            let p = MosquePickerView(width: rootHolder.bounds.width, height: rootHolder.bounds.height)
            p.appDelegate = self
            p.autoresizingMask = [.width, .height]
            p.onDone = { [weak self] in self?.showMain() }
            pickerView = p
        }
        mainContent.isHidden = true
        if pickerView!.superview == nil {
            pickerView!.frame = rootHolder.bounds
            // Add inside contentContainer so the Liquid Glass material
            // extends to the picker screen as well.
            rootHolder.contentContainer.addSubview(pickerView!)
        }
        pickerView!.isHidden = false
        pickerView!.refreshCurrentMode()
    }

    func showSettings() {
        pickerView?.isHidden = true
        if settingsView == nil {
            let s = SettingsView(width: rootHolder.bounds.width, height: rootHolder.bounds.height)
            s.appDelegate = self
            s.autoresizingMask = [.width, .height]
            s.onDone = { [weak self] in self?.showMain() }
            s.onOpenPicker = { [weak self] in self?.showPicker() }
            settingsView = s
        }
        mainContent.isHidden = true
        if settingsView!.superview == nil {
            settingsView!.frame = rootHolder.bounds
            // Same contract as the picker: nest inside contentContainer
            // so Liquid Glass applies uniformly.
            rootHolder.contentContainer.addSubview(settingsView!)
        }
        settingsView!.isHidden = false
        settingsView!.refresh()
    }

    func showMain() {
        pickerView?.isHidden = true
        settingsView?.isHidden = true
        mainContent.isHidden = false
        updateUI()
        tick()
    }

    func currentMosqueDidChange() {
        info = MosqueInfo()
        info.name = "Loading…"
        saveInfo()
        updateUI()
        fetchData()
    }

    // ----------------------------------------------------- appearance
    func applyAppearancePref() {
        let pref = UserDefaults.standard.string(forKey: kAppearanceKey) ?? "system"
        let chosen: NSAppearance?
        switch pref {
        case "light": chosen = NSAppearance(named: .aqua)
        case "dark":  chosen = NSAppearance(named: .darkAqua)
        default:      chosen = nil
        }
        NSApp.appearance = chosen
        popover?.appearance = chosen
    }

    /// Rebuild the popover content when the user picks a new language so
    /// every label, font, and RTL mirror reflects the new choice.
    func applyLanguageChange() {
        let wasShown = popover?.isShown ?? false
        // Drop cached sub-panels so they re-build with the new strings on next open.
        pickerView = nil
        settingsView = nil
        popover.contentViewController = buildContent()
        mainWindow?.reloadForPreferences()
        adhkarPanel?.reloadForPreferences()
        updateUI()
        tick()
        if wasShown, let btn = statusItem.button {
            popover.show(relativeTo: btn.bounds, of: btn, preferredEdge: .minY)
        }
    }

    // -------------------------------------------------- hidden data loader
    func setupLoader() {
        loader = WKWebView(frame: NSRect(x: 0, y: 0, width: 400, height: 400))
        loader.navigationDelegate = self
    }

    func fetchData() {
        guard let url = URL(string: currentMosqueURL()) else { return }
        loader.load(URLRequest(url: url))
    }

    func webView(_ wv: WKWebView, didFinish nav: WKNavigation!) {
        let js = """
        (function() {
            try {
                var d = null;
                if (typeof confData !== 'undefined') d = confData;
                else if (window.confData) d = window.confData;
                if (!d && window.mawaqit && window.mawaqit.confData) d = window.mawaqit.confData;
                if (!d) return null;

                function normTime(v) {
                    if (v === null || v === undefined || v === '') return '';
                    if (typeof v === 'number') {
                        var h = Math.floor(v/60), mm = v%60;
                        return (h<10?'0':'')+h+':'+(mm<10?'0':'')+mm;
                    }
                    return String(v);
                }

                // Helper: pick today's entry out of a calendar-shaped object.
                // Returns the raw array (5 or 6 times) or null.
                function todayFromCalendar(cal) {
                    if (!cal) return null;
                    var now = new Date();
                    var mo = now.getMonth();       // 0..11
                    var day = now.getDate();       // 1..31
                    var monthEntry = null;
                    if (Array.isArray(cal)) {
                        // Could be 0-indexed (12 items) or 1-indexed (13 items)
                        if (cal.length >= 13) monthEntry = cal[mo + 1];
                        else                   monthEntry = cal[mo];
                    } else if (typeof cal === 'object') {
                        monthEntry = cal[String(mo + 1)] || cal[String(mo)] || cal[mo + 1] || cal[mo];
                    }
                    if (!monthEntry) return null;
                    var entry = null;
                    if (Array.isArray(monthEntry)) {
                        // Month array might be 0- or 1-indexed
                        if (monthEntry.length >= 32) entry = monthEntry[day];
                        else                         entry = monthEntry[day - 1];
                    } else if (typeof monthEntry === 'object') {
                        entry = monthEntry[String(day)] || monthEntry[day];
                    }
                    if (!entry) return null;
                    if (Array.isArray(entry) && entry.length >= 5) return entry;
                    return null;
                }

                var times = [];
                var shuruq = '';

                // 1) Authoritative: today's row from d.calendar (what the mosque set).
                var todayRow = todayFromCalendar(d.calendar);
                if (todayRow) {
                    var arr = todayRow.map(normTime);
                    if (arr.length >= 6) {
                        shuruq = arr[1];
                        times  = [arr[0], arr[2], arr[3], arr[4], arr[5]];
                    } else {
                        times = arr.slice(0, 5);
                    }
                }

                // 2) Fallback: d.times (may be defaults/base times on some mosques).
                if (times.length < 5) {
                    var t2 = d.times || [];
                    if (!Array.isArray(t2)) t2 = [];
                    t2 = t2.map(normTime);
                    if (t2.length === 6) {
                        if (!shuruq) shuruq = t2[1];
                        times = [t2[0], t2[2], t2[3], t2[4], t2[5]];
                    } else {
                        times = t2.slice(0, 5);
                    }
                }

                // 3) Explicit shuruq field (if still not set).
                if (!shuruq) {
                    var s = d.shuruq;
                    if (typeof s === 'number') s = normTime(s);
                    if (s) shuruq = String(s);
                }

                function mapIq(v) {
                    if (v === null || v === undefined || v === '') return '';
                    if (typeof v === 'number') return '+' + v;
                    var s = String(v).trim();
                    if (s === '') return '';
                    if (/^-?\\d+$/.test(s)) return '+' + s.replace(/^\\+/, '');
                    return s;
                }

                var iqama = [];
                var rawIq = d.iqama !== undefined ? d.iqama :
                            (d.iqamas !== undefined ? d.iqamas : null);
                if (Array.isArray(rawIq)) {
                    iqama = rawIq.slice(0, 5).map(mapIq);
                } else if (rawIq && typeof rawIq === 'object') {
                    var pk = ['fajr','dhuhr','asr','maghrib','isha'];
                    iqama = pk.map(function(k) {
                        return mapIq(rawIq[k] !== undefined ? rawIq[k]
                                : rawIq[k.charAt(0).toUpperCase()+k.slice(1)]);
                    });
                }
                if ((!iqama.length || iqama.every(function(x){return !x;})) && d.iqamaCalendar) {
                    try {
                        var iqRow = todayFromCalendar(d.iqamaCalendar);
                        if (iqRow) iqama = iqRow.slice(0, 5).map(mapIq);
                    } catch(e){}
                }

                var jumua = '';
                var jumuaTimes = [];
                if (typeof d.jumua === 'string') {
                    jumua = normTime(d.jumua);
                    if (jumua) jumuaTimes = [jumua];
                } else if (Array.isArray(d.jumua) && d.jumua.length) {
                    jumuaTimes = d.jumua.map(normTime).filter(Boolean);
                    jumua = jumuaTimes.length ? jumuaTimes[0] : '';
                } else if (d.jumuaTime) {
                    jumua = normTime(d.jumuaTime);
                    if (jumua) jumuaTimes = [jumua];
                }

                var sunset = '';
                if (d.sunset !== undefined) sunset = normTime(d.sunset);
                else if (d.sunsetTime !== undefined) sunset = normTime(d.sunsetTime);

                return JSON.stringify({
                    name: d.name || d.label || '',
                    localisation: d.localisation || d.association || '',
                    phone: d.phone || '',
                    site: d.site || '',
                    times: times,
                    shuruq: shuruq,
                    iqama: iqama,
                    jumua: jumua,
                    jumuaTimes: jumuaTimes,
                    sunset: sunset
                });
            } catch(e) { return null; }
        })();
        """
        wv.evaluateJavaScript(js) { [weak self] result, _ in
            guard let self = self,
                  let json = result as? String,
                  let data = json.data(using: .utf8),
                  let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return }

            var next = MosqueInfo()
            next.name         = (dict["name"]         as? String) ?? self.info.name
            next.localisation = (dict["localisation"] as? String) ?? ""
            next.phone        = (dict["phone"]        as? String) ?? ""
            next.site         = (dict["site"]         as? String) ?? ""
            next.times        = (dict["times"]        as? [String]) ?? []
            next.shuruq       = (dict["shuruq"]       as? String) ?? ""
            next.iqama        = (dict["iqama"]        as? [String]) ?? []
            next.jumua        = (dict["jumua"]        as? String) ?? ""
            next.jumuaTimes   = (dict["jumuaTimes"]   as? [String])
            next.sunset       = (dict["sunset"]       as? String)
            next.date         = self.todayString()
            next.sourceURL    = wv.url?.absoluteString ?? ""

            guard next.times.count >= 5 else { return }
            self.info = next
            self.saveInfo()
            DispatchQueue.main.async {
                self.updateUI()
                self.tick()
                self.mainWindow?.reloadPrayerDashboard()
            }
        }
    }

    // --------------------------------------------------- persistence
    func loadCachedInfo() {
        guard let data = UserDefaults.standard.data(forKey: kInfoKey),
              let saved = try? JSONDecoder().decode(MosqueInfo.self, from: data) else { return }
        info = saved
    }
    func saveInfo() {
        if let data = try? JSONEncoder().encode(info) {
            UserDefaults.standard.set(data, forKey: kInfoKey)
        }
    }

    // ---------------------------------------------------- rendering
    func updateUI() {
        guard nameLabel != nil else { return }
        nameLabel.stringValue = isCompactAdhkarMode
            ? t("settings.section.adhkar")
            : (info.name.isEmpty ? t("mosque.default") : info.name)
        var addr = isCompactAdhkarMode ? "" : info.localisation
        if !isCompactAdhkarMode, !info.phone.isEmpty {
            addr += (addr.isEmpty ? "" : " · ") + "📞 \(info.phone)"
        }
        addressLabel.stringValue = addr

        // Re-center the mosque name vertically with the app icon when there's
        // no address to show, so short mosque names don't float above center.
        // With an address, the block is centered as a whole (name y=12,
        // address y=34 → block midline y=36 = icon midline).
        if let nf = nameLabel?.frame {
            let newY: CGFloat = addr.isEmpty ? 25 : 12
            let newWidth = mainContent.bounds.width - (isCompactAdhkarMode ? 92 : 124)
            nameLabel.frame = NSRect(x: nf.origin.x, y: newY,
                                     width: newWidth, height: nf.size.height)
            fitLocalizedLabel(nameLabel)
            addressLabel.isHidden = addr.isEmpty
            if !addr.isEmpty { fitLocalizedLabel(addressLabel, maximumLines: 2) }
        }

        // The mosque-finder remains available even before a mosque is chosen;
        // that empty state is precisely when the shortcut is most useful.
        if headerLinkBtn != nil {
            headerLinkBtn.isHidden = isCompactAdhkarMode
            headerLinkBtn.isEnabled = true
            headerLinkBtn.alphaValue = 1.0
        }

        // Gregorian date in the current UI language. Format mirrors the
        // Hijri "d MMMM yyyy" layout so the two dates read as a pair.
        if gregorianLbl != nil {
            let fmt = DateFormatter()
            fmt.locale = preferredInterfaceLocale()
            fmt.dateFormat = "EEE d MMM yyyy"
            gregorianLbl.stringValue = fmt.string(from: Date())
        }

        // Each row: (localized prayer name, adhan time, iqama time, iqama offset minutes).
        // Shuruq is handled separately on its own strip below the Jumua line
        // (see `shuruqLbl` a few lines down) so it's intentionally absent here.
        let rows: [(String, String, String?, Int?)] = [
            (t("prayer.fajr"),    info.times.indices.contains(0) ? info.times[0] : "", iqamaTimeAt(0), iqamaOffsetAt(0)),
            (t("prayer.dhuhr"),   info.times.indices.contains(1) ? info.times[1] : "", iqamaTimeAt(1), iqamaOffsetAt(1)),
            (t("prayer.asr"),     info.times.indices.contains(2) ? info.times[2] : "", iqamaTimeAt(2), iqamaOffsetAt(2)),
            (t("prayer.maghrib"), info.times.indices.contains(3) ? info.times[3] : "", iqamaTimeAt(3), iqamaOffsetAt(3)),
            (t("prayer.isha"),    info.times.indices.contains(4) ? info.times[4] : "", iqamaTimeAt(4), iqamaOffsetAt(4)),
        ]
        for (i, row) in rows.enumerated() where i < timeRowViews.count {
            let (name, adhan, offset, iqama, _) = timeRowViews[i]
            name.stringValue  = row.0
            adhan.stringValue = row.1.isEmpty ? "--:--" : displayTime(row.1)

            if let off = row.3, off != 0 {
                let sign = off > 0 ? "+" : ""
                offset.stringValue = "\(sign)\(off)"
            } else {
                offset.stringValue = ""
            }

            if let t = row.2, !t.isEmpty {
                iqama.stringValue = displayTime(t)
            } else {
                iqama.stringValue = "—"
            }
        }
        jumuaLbl.stringValue = info.jumua.isEmpty ? "" : "\(t("label.jumua")) · \(displayTime(info.jumua))"
        hijriLbl.stringValue = hijriString()
        if shuruqLbl != nil {
            shuruqLbl.stringValue = info.shuruq.isEmpty
                ? ""
                : "\(t("prayer.shuruq")) · \(displayTime(info.shuruq))"
        }

        // Apply next-prayer emphasis after values are set.
        if info.times.count >= 5 {
            let (nextIdx, _, _) = nextPrayer()
            emphasizeRow(displayRow(for: nextIdx))
        } else {
            emphasizeRow(-1)
        }
    }

    /// HH:MM string for the iqama (either explicit time, or adhan + offset).
    func iqamaTimeAt(_ i: Int) -> String? {
        guard info.iqama.indices.contains(i), info.times.indices.contains(i) else { return nil }
        let raw = info.iqama[i]
        if raw.isEmpty { return nil }
        if raw.hasPrefix("+") || raw.hasPrefix("-") {
            if let mins = Int(raw) {
                return addMinutes(to: info.times[i], minutes: mins)
            }
        }
        return raw
    }

    /// Offset minutes between adhan and iqama. Works whether Mawaqit returns the
    /// iqama as an offset ("+10") or as an explicit HH:MM time — in the latter
    /// case we derive the difference from the adhan time so the "+X" badge is
    /// always shown between the two columns.
    func iqamaOffsetAt(_ i: Int) -> Int? {
        guard info.iqama.indices.contains(i),
              info.times.indices.contains(i) else { return nil }
        let raw = info.iqama[i]
        if raw.isEmpty { return nil }

        // 1) Source already gave us an offset.
        if raw.hasPrefix("+") || raw.hasPrefix("-") {
            if let n = Int(raw.dropFirst()) {
                return raw.hasPrefix("-") ? -n : n
            }
            if let n = Int(raw) { return n }
        }

        // 2) Explicit HH:MM iqama — derive the offset from the adhan time.
        guard let iqamaStr = iqamaTimeAt(i) else { return nil }
        let adhanStr = info.times[i]
        guard let aMin = minutesOfDay(adhanStr),
              let iMin = minutesOfDay(iqamaStr) else { return nil }
        var diff = iMin - aMin
        // Handle wraparound (e.g. adhan 23:45, iqama 00:05 → +20).
        if diff < -12 * 60 { diff += 24 * 60 }
        if diff >  12 * 60 { diff -= 24 * 60 }
        return diff
    }

    /// Parses "HH:MM" into minutes-since-midnight, or nil if malformed.
    private func minutesOfDay(_ hhmm: String) -> Int? {
        let parts = hhmm.split(separator: ":")
        guard parts.count == 2,
              let h = Int(parts[0]), let m = Int(parts[1]) else { return nil }
        return h * 60 + m
    }

    func addMinutes(to hhmm: String, minutes: Int) -> String {
        let parts = hhmm.split(separator: ":")
        guard parts.count == 2, let h = Int(parts[0]), let m = Int(parts[1]) else { return hhmm }
        var total = (h * 60 + m + minutes) % (24 * 60)
        if total < 0 { total += 24 * 60 }
        return String(format: "%02d:%02d", total / 60, total % 60)
    }

    /// Visually emphasizes the next-prayer row. Per user preference ONLY the
    /// adhan time changes — it shifts left (closer to the prayer name) and
    /// grows to 20pt bold mono. The offset badge, iqama time, and mode
    /// button all keep the exact same x/y/size as on every other row so
    /// columns stay perfectly aligned vertically across the six rows.
    ///
    /// Emphasis is signalled by:
    ///   • an accent-coloured highlight strip behind the row
    ///   • accent colour on the name + adhan text
    ///   • the bigger adhan time
    ///
    /// Row height is uniform 30pt (no reflow of rows below). RTL is handled
    /// by `rect(ltrX:…)` so Arabic/Urdu still mirror correctly.
    func emphasizeRow(_ rowIdx: Int) {
        let rowY0: CGFloat = 198   // matches buildMainSubtree
        let rowH:  CGFloat = 30    // uniform — no shift for rows below
        let isRTL           = Localizer.shared.isRTL
        let superW: CGFloat = timeRowViews.first?.0.superview?.bounds.width ?? 280

        // Map LTR-authored coordinates to the active UI direction.
        func rect(ltrX: CGFloat, y: CGFloat, w: CGFloat, h: CGFloat) -> NSRect {
            let x = isRTL ? (superW - ltrX - w) : ltrX
            return NSRect(x: x, y: y, width: w, height: h)
        }

        for (i, tuple) in timeRowViews.enumerated() {
            let (name, adhan, offset, iqama, hl) = tuple
            let isNext = (i == rowIdx)
            let y = rowY0 + CGFloat(i) * rowH

            // Highlight strip — full row width, symmetric, no RTL mirror.
            hl.frame = NSRect(x: 12, y: y - 2, width: superW - 24, height: rowH - 2)
            hl.isHidden = !isNext

            // Name, offset, iqama and mode button: IDENTICAL frame on every
            // row so their columns stay perfectly aligned. Only the font
            // weight / colour on `name` changes for the emphasised row.
            name.frame   = rect(ltrX: 16,  y: y + 5, w: 74, h: 20)
            offset.frame = rect(ltrX: 154, y: y + 9, w: 28, h: 14)
            iqama.frame  = rect(ltrX: 186, y: y + 7, w: 46, h: 18)
            if i < modeButtons.count, let btn = modeButtons[i] {
                btn.frame = rect(ltrX: 238, y: y + 4, w: 24, h: 24)
            }

            // Offset keeps its default font/colour — never changes between
            // rows, per user request that the +XX indicator stay in the
            // same visual position as the other prayers'.
            offset.font = NSFont.monospacedDigitSystemFont(ofSize: 10, weight: .medium)

            if isNext {
                // Name: default size/weight, accent colour ties the row
                // together visually.
                name.font      = Localizer.shared.font(size: 13, weight: .medium)
                name.textColor = .appAccent

                // Adhan is shifted LEFT (closer to the prayer name) and
                // grows to 20pt bold mono. The frame spans x=78..148,
                // leaving ~6pt of breathing room before the offset badge
                // at x=154 without displacing it.
                adhan.frame    = rect(ltrX: 78, y: y + 1, w: 70, h: 28)
                adhan.font     = NSFont.monospacedDigitSystemFont(ofSize: 20, weight: .bold)
                adhan.textColor = .appAccent

                // Iqama: same font/frame as default rows.
                iqama.font     = NSFont.monospacedDigitSystemFont(ofSize: 11, weight: .regular)
                iqama.textColor = .tertiaryLabelColor
            } else {
                // Default row — restored exactly to buildMainSubtree's
                // authored layout for name + adhan (the previous state may
                // have been the shifted-left emphasised adhan).
                name.font      = Localizer.shared.font(size: 13, weight: .medium)
                name.textColor = .labelColor

                adhan.frame    = rect(ltrX: 94, y: y + 3, w: 58, h: 22)
                adhan.font     = NSFont.monospacedDigitSystemFont(ofSize: 15, weight: .semibold)
                adhan.textColor = .labelColor

                iqama.font     = NSFont.monospacedDigitSystemFont(ofSize: 11, weight: .regular)
                iqama.textColor = .tertiaryLabelColor
            }
            fitLocalizedLabel(name)
        }
    }

    /// Localized prayer name for an index into `info.times` (0=Fajr, 1=Dhuhr, …).
    func localizedPrayerName(at timesIdx: Int) -> String {
        let keys = ["prayer.fajr", "prayer.dhuhr", "prayer.asr", "prayer.maghrib", "prayer.isha"]
        guard keys.indices.contains(timesIdx) else { return "" }
        return t(keys[timesIdx])
    }

    // ---------------------------------------------------- tick loop
    func tick() {
        defer { mainWindow?.refreshPrayerLiveState(now: Date()) }
        // Three independent menu-bar settings:
        //   • showTime       — scheduled prayer time, e.g. "Dhuhr 13:45"
        //   • showCountdown  — live ticking countdown to the next prayer
        //   • hijriFmt       — Hijri date granularity (or .off to hide)
        // Each one produces at most one segment in the title; segments are
        // joined with "  ·  ". Both time and countdown also carry the
        // prayer name so the user knows *which* prayer they refer to.
        let showTime      = UserDefaults.standard.object(forKey: kBarShowTime)      as? Bool ?? true
        let showCountdown = UserDefaults.standard.object(forKey: kBarShowCountdown) as? Bool ?? true
        let hijriFmt      = currentHijriFormat()

        /// Hijri segment, wrapped in spaces if present. Empty string when
        /// the user picked "Off".
        func hijriSegment() -> String {
            hijriFmt == .off ? "" : hijriString(format: hijriFmt)
        }

        guard info.times.count >= 5 else {
            // No data yet: show only the hijri date if requested.
            let h = hijriSegment()
            setStatusTitle(h.isEmpty ? "" : " \(h) ")
            return
        }

        // Adhkar must be checked before the adhan→iqama early return below;
        // otherwise Fajr/Dhuhr/Asr/Maghrib/Isha anchors are skipped for the
        // entire iqama window and can never trigger that day.
        checkAdhkarTrigger()

        // Adhan→Iqama window: during the ~10 minutes between a prayer's
        // adhan and its iqama, the menu-bar swaps to a RED countdown
        // pill showing how long until the iqama is called. The popover
        // keeps pointing at the *next* prayer as usual.
        if let window = currentAdhanWindow() {
            let (curIdx, iqamaDate) = window
            let diff = max(0, Int(iqamaDate.timeIntervalSince(Date())))
            let mm   = diff / 60
            let ss   = diff % 60
            let redCountdown = localizedInterfaceDigits(
                String(format: "%02d:%02d", mm, ss))
            let curName      = localizedPrayerName(at: curIdx)
            let curScheduled = displayTime(info.times[curIdx])

            // Build the prayer segment from whichever pieces the user asked for.
            // Always leads with the prayer name so the string reads naturally.
            var piece = curName
            if showTime      { piece += " \(curScheduled)" }
            if showCountdown { piece += " \(redCountdown)" }
            if !showTime && !showCountdown { piece = "" }

            var parts: [String] = []
            if !piece.isEmpty {
                // RTL: reverse name/time order so the name ends up visually
                // on the right — matches the normal pre-adhan layout.
                if Localizer.shared.isRTL {
                    var comps = [curName]
                    if showTime      { comps.insert(curScheduled, at: 0) }
                    if showCountdown { comps.insert(redCountdown, at: 0) }
                    parts.append(comps.joined(separator: " "))
                } else {
                    parts.append(piece)
                }
            }
            let h = hijriSegment()
            if !h.isEmpty { parts.append(h) }

            let joined = parts.joined(separator: "  ·  ")
            // Pad the string so the white pill has breathing room on both
            // sides of the red text — variableLength will shrink to fit.
            setStatusTitle(joined.isEmpty ? "" : "  \(joined)  ",
                           color: .systemRed,
                           background: .white)

            // Popover still points at the next prayer — update its labels
            // + emphasised row exactly as in the normal branch below.
            let (nextIdx, nextDate, _) = nextPrayer()
            if let next = nextDate, countdownLbl != nil {
                let d = max(0, Int(next.timeIntervalSince(Date())))
                let hh = d / 3600
                let m  = (d % 3600) / 60
                let s  = d % 60
                countdownLbl.stringValue = localizedInterfaceDigits(
                    String(format: "%02d:%02d:%02d", hh, m, s))
                nextPrayerLbl.stringValue = t("label.next_prayer")
                nextAtLbl.stringValue = "\(localizedPrayerName(at: nextIdx))  ·  \(displayTime(info.times[nextIdx]))"
            }
            emphasizeRow(displayRow(for: nextPrayer().index))
            checkAdhanTrigger()
            return
        }

        let (nextIdx, nextDate, _) = nextPrayer()
        if let next = nextDate {
            let diff = max(0, Int(next.timeIntervalSince(Date())))
            let h = diff / 3600
            let m = (diff % 3600) / 60
            let s = diff % 60
            let nameForBar = localizedPrayerName(at: nextIdx)
            // Scheduled clock time in the user's chosen 12h/24h format.
            let scheduled = displayTime(info.times[nextIdx])
            // Live countdown: HH:MM:SS when ≥1 h away, MM:SS inside the
            // final hour so the seconds are visible.
            let countdown: String = localizedInterfaceDigits((diff >= 3600)
                ? String(format: "%d:%02d:%02d", h, m, s)
                : String(format: "%02d:%02d", m, s))

            // Assemble the prayer segment from the two independent toggles.
            // Order: [name] [scheduled] [countdown]. LTR reads naturally,
            // RTL mirrors the same pieces at assembly time.
            var comps: [String] = []
            if showTime || showCountdown { comps.append(nameForBar) }
            if showTime                  { comps.append(scheduled) }
            if showCountdown             { comps.append(countdown) }
            if Localizer.shared.isRTL { comps.reverse() }
            let prayerSeg = comps.joined(separator: " ")

            // Append Hijri segment if requested.
            var parts: [String] = []
            if !prayerSeg.isEmpty { parts.append(prayerSeg) }
            let hij = hijriSegment()
            if !hij.isEmpty { parts.append(hij) }

            let joined = parts.joined(separator: "  ·  ")
            setStatusTitle(joined.isEmpty ? "" : " \(joined) ")

            if countdownLbl != nil {
                countdownLbl.stringValue = localizedInterfaceDigits(
                    String(format: "%02d:%02d:%02d", h, m, s))
                nextPrayerLbl.stringValue = t("label.next_prayer")
                // baseWritingDirection on nextAtLbl (set by applyRTL) handles
                // the visual order, so the logical string stays identical.
                nextAtLbl.stringValue = "\(nameForBar)  ·  \(displayTime(info.times[nextIdx]))"
            }
        }

        emphasizeRow(displayRow(for: nextIdx))

        checkAdhanTrigger()
    }

    func displayRow(for timesIdx: Int) -> Int {
        // With Shuruq moved out of the main table, the five prayer indices
        // map 1:1 to display rows 0..4.
        switch timesIdx {
        case 0...4: return timesIdx
        default:    return -1
        }
    }

    /// If the clock is currently inside a prayer's adhan→iqama window, returns
    /// the prayer index and the upcoming iqama `Date`; otherwise nil. Used by
    /// `tick()` to swap the menu-bar title to a red iqama countdown for the
    /// ~10 minutes between each adhan and its iqama.
    func currentAdhanWindow() -> (index: Int, iqama: Date)? {
        let now = Date()
        let cal = Calendar.current
        let today = cal.startOfDay(for: now)
        let fmt = DateFormatter()
        fmt.dateFormat = "HH:mm"
        fmt.locale = Locale(identifier: "en_US_POSIX")
        fmt.timeZone = TimeZone.current

        for i in 0..<5 {
            guard info.times.indices.contains(i),
                  let adhanD = fmt.date(from: info.times[i]) else { continue }
            let ac = cal.dateComponents([.hour, .minute], from: adhanD)
            guard let adhanDate = cal.date(bySettingHour: ac.hour ?? 0,
                                           minute: ac.minute ?? 0,
                                           second: 0, of: today) else { continue }

            guard let iqamaStr = iqamaTimeAt(i),
                  let iqamaD = fmt.date(from: iqamaStr) else { continue }
            let ic = cal.dateComponents([.hour, .minute], from: iqamaD)
            guard var iqamaDate = cal.date(bySettingHour: ic.hour ?? 0,
                                           minute: ic.minute ?? 0,
                                           second: 0, of: today) else { continue }

            // Isha iqama can roll just past midnight — if the derived date
            // is earlier than the adhan it must belong to tomorrow.
            if iqamaDate < adhanDate {
                iqamaDate = cal.date(byAdding: .day, value: 1, to: iqamaDate) ?? iqamaDate
            }

            if now >= adhanDate && now < iqamaDate {
                return (i, iqamaDate)
            }
        }
        return nil
    }

    func nextPrayer() -> (index: Int, date: Date?, isTomorrow: Bool) {
        let now = Date()
        let cal = Calendar.current
        let today = cal.startOfDay(for: now)
        let fmt = DateFormatter()
        fmt.dateFormat = "HH:mm"
        fmt.locale = Locale(identifier: "en_US_POSIX")
        fmt.timeZone = TimeZone.current

        for i in 0..<5 {
            guard let d = fmt.date(from: info.times[i]) else { continue }
            let c = cal.dateComponents([.hour, .minute], from: d)
            if let when = cal.date(bySettingHour: c.hour ?? 0, minute: c.minute ?? 0, second: 0, of: today),
               when > now { return (i, when, false) }
        }
        if let d = fmt.date(from: info.times[0]),
           let tomorrow = cal.date(byAdding: .day, value: 1, to: today) {
            let c = cal.dateComponents([.hour, .minute], from: d)
            return (0, cal.date(bySettingHour: c.hour ?? 0, minute: c.minute ?? 0, second: 0, of: tomorrow), true)
        }
        return (-1, nil, false)
    }

    // --------------------------------------------- adhan-mode button
    /// Click handler for the per-prayer mode button. Sender's `tag` is the
    /// prayer index (0 = Fajr … 4 = Isha). Cycles off → notify → adhan.
    @objc func adhanModeButtonTapped(_ sender: NSButton) {
        let prayerIdx = sender.tag
        guard (0..<5).contains(prayerIdx) else { return }
        let newMode = adhanModeForPrayer(prayerIdx).next
        setAdhanMode(newMode, forPrayer: prayerIdx)
        applyAdhanModeIcon(to: sender, mode: newMode)

        // If user just turned adhan ON for this prayer, ask for notification
        // permission now if we don't have it yet.
        if newMode == .notify || newMode == .adhan {
            requestNotificationAuthorization()
        }
    }

    /// Sets the SF Symbol + tint on a mode button to match the given mode.
    /// Used both when building the UI and after a click.
    func applyAdhanModeIcon(to btn: NSButton, mode: AdhanMode) {
        let tint: NSColor = {
            switch mode {
            case .off:    return .tertiaryLabelColor
            case .notify: return .secondaryLabelColor
            case .adhan:  return .appGreenAccent
            }
        }()
        if let img = NSImage(systemSymbolName: mode.symbolName,
                             accessibilityDescription: nil) {
            img.isTemplate = true
            btn.image = img
            btn.contentTintColor = tint
        }
        // Also reflect the mode in the tooltip so users can discover what
        // each state means without hunting through Settings.
        switch mode {
        case .off:    btn.toolTip = "Silent (no sound, no notification)"
        case .notify: btn.toolTip = "Notification only"
        case .adhan:  btn.toolTip = "Play adhan"
        }
    }

    // ---------------------------------------------- adhan trigger
    func checkAdhanTrigger() {
        // Per-prayer mode (off/notify/adhan) is the primary control. The
        // legacy global toggles in Settings still act as master kill-switches
        // so users can silence everything without touching each row.
        let globalAdhan = UserDefaults.standard.bool(forKey: kAdhanEnabled)
        let globalNotif = UserDefaults.standard.bool(forKey: kNotificationsKey)
        guard info.times.count >= 5 else { return }

        let now = Date()
        let cal = Calendar.current
        let today = cal.startOfDay(for: now)
        let fmt = DateFormatter()
        fmt.dateFormat = "HH:mm"
        fmt.locale = Locale(identifier: "en_US_POSIX")
        fmt.timeZone = TimeZone.current

        let todayStr = todayString()
        let lastKey = UserDefaults.standard.string(forKey: kLastAdhanKey) ?? ""
        let lastPreKey = UserDefaults.standard.string(forKey: kLastPreAdhanKey) ?? ""
        // Heads-up lead time in minutes. 0 means the feature is off. We still
        // only surface the alert when the user hasn't silenced notifications
        // globally and hasn't set the per-prayer mode to ".off".
        let leadMin = max(0, UserDefaults.standard.integer(forKey: kPreAdhanLeadMinutes))

        for i in 0..<5 {
            let marker = "\(todayStr)#\(i)"
            guard let d = fmt.date(from: info.times[i]) else { continue }
            let c = cal.dateComponents([.hour, .minute], from: d)
            guard let when = cal.date(bySettingHour: c.hour ?? 0, minute: c.minute ?? 0, second: 0, of: today)
                else { continue }
            let dt = now.timeIntervalSince(when)

            // ---------- pre-adhan heads-up (T-leadMin) ---------------------
            // Fires once per prayer per day when we're inside the
            // [-leadMin, -leadMin+1min) window. Suppressed while the user's
            // per-prayer row is set to Off (respect the user's mute).
            if leadMin > 0 && globalNotif {
                let preMarker = "\(todayStr)#\(i):pre"
                let alreadyPrepped =
                    lastPreKey == preMarker ||
                    (lastPreKey > preMarker && lastPreKey.hasPrefix(todayStr))
                if !alreadyPrepped {
                    let leadSecs = TimeInterval(leadMin * 60)
                    // Window: from leadMin minutes before "when" up to
                    // leadMin-minus-one-minute before "when". That's a single
                    // tick-sized edge so we don't re-fire on every tick.
                    if dt >= -leadSecs && dt < -leadSecs + 60 {
                        let mode = adhanModeForPrayer(i)
                        if mode != .off {
                            notifyHeadsUp(prayer: localizedPrayerName(at: i),
                                          minutes: leadMin,
                                          time: info.times[i])
                        }
                        UserDefaults.standard.set(preMarker, forKey: kLastPreAdhanKey)
                    }
                }
            }

            // ---------- main adhan trigger (T=0) ---------------------------
            if lastKey == marker { continue }
            if lastKey > marker && lastKey.hasPrefix(todayStr) { continue }
            if dt >= 0 && dt < 60 {
                let mode = adhanModeForPrayer(i)
                switch mode {
                case .off:
                    break
                case .notify:
                    if globalNotif {
                        notify(prayer: localizedPrayerName(at: i), time: info.times[i])
                    }
                case .adhan:
                    if globalAdhan { playAdhan() }
                    if globalNotif {
                        notify(prayer: localizedPrayerName(at: i), time: info.times[i])
                    }
                }
                UserDefaults.standard.set(marker, forKey: kLastAdhanKey)
                break
            }
        }
    }

    /// Fires a "Dhuhr in 10 min" heads-up notification. Uses a different
    /// identifier prefix than the main adhan notification so both can coexist
    /// in Notification Center if the user happens to open it mid-prayer.
    func notifyHeadsUp(prayer: String, minutes: Int, time: String) {
        let content = UNMutableNotificationContent()
        let titleFmt = t("settings.notif.headsup.title")
        // Swift's String(format:) drops %@ unless the arg is NSString.
        content.title = localizedInterfaceDigits(
            String(format: titleFmt, prayer as NSString, minutes))
        content.body = info.name.isEmpty
            ? "\(prayer) · \(displayTime(time))"
            : "\(info.name) · \(displayTime(time))"
        content.sound = nil   // heads-up should not play audio; the adhan will
        let req = UNNotificationRequest(
            identifier: "prayer.preadhan.\(todayString()).\(prayer)",
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(req, withCompletionHandler: nil)
    }

    func playAdhan() {
        // Guarantee only one playback at a time — if the user spam-taps Test,
        // cut the previous player off before starting the next one.
        scheduledAdhkarDelayTimer?.invalidate()
        scheduledAdhkarDelayTimer = nil
        completedAdhanAllowsQueuedAdhkar = false
        if !scheduledAdhkarQueue.isEmpty { queuedAdhkarIsWaitingForAdhan = true }
        adhanPlayer?.stop()
        let opt = currentAdhanOption()
        let wantedUID = UserDefaults.standard.string(forKey: kAdhanAudioDevice) ?? ""
        func route(_ p: AVAudioPlayer) {
            if !wantedUID.isEmpty { p.currentDevice = wantedUID }
        }
        func start(_ p: AVAudioPlayer) {
            adhanPlayer = p
            p.delegate = self      // so `audioPlayerDidFinishPlaying` resets UI
            route(p)
            p.volume = 1.0
            p.prepareToPlay()
            p.play()
            onAdhanStateChanged?()
            syncStopAdhanStatusItem()
        }
        if !opt.fileName.isEmpty {
            let base = opt.fileName.replacingOccurrences(of: ".mp3", with: "")
            if let url = Bundle.main.url(forResource: base, withExtension: "mp3"),
               FileManager.default.fileExists(atPath: url.path),
               let p = try? AVAudioPlayer(contentsOf: url) {
                start(p)
                return
            }
        }
        // Fallbacks: legacy bundled adhan.mp3 or user's ~/Music/adhan.mp3
        let legacy = Bundle.main.url(forResource: "adhan", withExtension: "mp3")
        let userAdhan = FileManager.default.urls(for: .musicDirectory, in: .userDomainMask)
            .first?.appendingPathComponent("adhan.mp3")
        for case let url? in [legacy, userAdhan] where FileManager.default.fileExists(atPath: url.path) {
            if let p = try? AVAudioPlayer(contentsOf: url) {
                start(p)
                return
            }
        }
        NSSound(named: "Glass")?.play()
    }

    /// User-triggered stop — cuts playback mid-adhan. Safe to call when
    /// nothing is playing (no-ops). Notifies observers so the Test button
    /// can swap back to a play icon.
    func stopAdhan() {
        adhanPlayer?.stop()
        adhanPlayer = nil
        onAdhanStateChanged?()
        syncStopAdhanStatusItem()
        scheduleQueuedAdhkarAfterAdhan()
    }

    // MARK: - AVAudioPlayerDelegate
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        let wasAdhan = adhanPlayer === player
        if wasAdhan { adhanPlayer = nil }
        onAdhanStateChanged?()
        syncStopAdhanStatusItem()
        if wasAdhan { scheduleQueuedAdhkarAfterAdhan() }
    }
    func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: Error?) {
        let wasAdhan = adhanPlayer === player
        if wasAdhan { adhanPlayer = nil }
        onAdhanStateChanged?()
        syncStopAdhanStatusItem()
        if wasAdhan { scheduleQueuedAdhkarAfterAdhan() }
    }

    // ------------------------------------------ menu-bar stop button
    /// Creates or tears down the secondary menu-bar status item that shows
    /// a stop button while adhan is playing. The item is only visible when
    /// audio is actually coming out of the speakers so it doesn't clutter
    /// the menu bar the rest of the time.
    func syncStopAdhanStatusItem() {
        if isAdhanPlaying {
            if stopAdhanStatusItem != nil { return }
            let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
            if let b = item.button {
                let sym = templateSymbol("stop.circle.fill", pointSize: 14, weight: .semibold)
                b.image = sym
                // Tint red so it stands out among all the other menu-bar
                // glyphs and reads as an "active playback, tap to cancel"
                // affordance at a glance.
                b.contentTintColor = .systemRed
                b.toolTip = t("menubar.stop_adhan")
                b.action  = #selector(stopAdhanFromMenuBar(_:))
                b.target  = self
            }
            stopAdhanStatusItem = item
        } else {
            if let item = stopAdhanStatusItem {
                NSStatusBar.system.removeStatusItem(item)
                stopAdhanStatusItem = nil
            }
        }
    }

    @objc func stopAdhanFromMenuBar(_ sender: Any?) {
        stopAdhan()
    }

    // ------------------------------------------ system notification
    func notify(prayer: String, time: String) {
        let content = UNMutableNotificationContent()
        content.title = "\(prayer) · \(time)"
        content.body = info.name.isEmpty ? "Prayer time" : info.name
        content.sound = nil   // we play our own adhan

        let req = UNNotificationRequest(
            identifier: "prayer.\(todayString()).\(prayer)",
            content: content,
            trigger: nil
        )
        // We deliberately don't fall back to the deprecated NSUserNotification
        // API — on modern macOS it's a no-op for many setups and the UN API
        // handles authorization failures gracefully by silently dropping.
        UNUserNotificationCenter.current().add(req, withCompletionHandler: nil)
    }

    // MARK: - Adhkar (morning / evening) trigger + presentation

    /// Resolve a "HH:mm" string from `info` for the chosen anchor, or nil.
    /// morningAnchor: "shuruq" → info.shuruq, "fajr" → info.times[0].
    /// eveningAnchor: "asr" → info.times[2], "maghrib" → info.times[3].
    private func adhkarAnchorTime(_ anchor: String) -> String? {
        switch anchor {
        case "shuruq":  return info.shuruq.isEmpty ? nil : info.shuruq
        case "fajr":    return info.times.count > 0 ? info.times[0] : nil
        case "dhuhr":   return info.times.count > 1 ? info.times[1] : nil
        case "asr":     return info.times.count > 2 ? info.times[2] : nil
        case "maghrib": return info.times.count > 3 ? info.times[3] : nil
        case "isha":    return info.times.count > 4 ? info.times[4] : nil
        default:        return nil
        }
    }

    /// Called every tick from `checkAdhanTrigger`-land — fires the matching
    /// adhkar set once per day when the anchor time is reached, mirroring the
    /// adhan idempotency pattern (marker "YYYY-MM-DD#morning" / "#evening").
    func checkAdhkarTrigger() {
        guard UserDefaults.standard.bool(forKey: kAdhkarEnabled) else { return }
        // v3: iterate every collection in the user's library. Each has its
        // own anchorKind + autoPlay flag, so the user can schedule any number
        // of independent recitations per day. Idempotency is keyed by the
        // collection's UUID so deleting + recreating one re-arms it.
        let now = Date()
        let cal = Calendar.current
        let today = cal.startOfDay(for: now)
        let fmt = DateFormatter()
        fmt.dateFormat = "HH:mm"
        fmt.locale = Locale(identifier: "en_US_POSIX")
        fmt.timeZone = TimeZone.current
        let todayStr = todayString()

        // One idempotency string per day per collection: "YYYY-MM-DD#<uuid-prefix>"
        let firedKey = "adhkarFiredToday"
        var fired = (UserDefaults.standard.array(forKey: firedKey) as? [String]) ?? []
        // Prune any markers from prior days so the array doesn't grow forever.
        fired = fired.filter { $0.hasPrefix(todayStr + "#") }

        for c in AdhkarLibrary.load() {
            guard c.autoPlay else { continue }
            guard c.anchorKind != "manual" else { continue }
            let marker = "\(todayStr)#\(c.id.uuidString)"
            if fired.contains(marker) { continue }
            guard let t = adhkarAnchorTime(c.anchorKind),
                  let d = fmt.date(from: t) else { continue }
            let comps = cal.dateComponents([.hour, .minute], from: d)
            guard let when = cal.date(bySettingHour: comps.hour ?? 0,
                                       minute: comps.minute ?? 0, second: 0, of: today) else { continue }
            let dt = now.timeIntervalSince(when)
            // Five-minute grace period covers wake-from-sleep and transient
            // timer stalls while retaining once-per-day idempotency.
            if dt >= 0 && dt < 5 * 60 {
                enqueueScheduledAdhkar(c)
                fired.append(marker)
            }
        }
        UserDefaults.standard.set(fired, forKey: firedKey)
    }

    private func enqueueScheduledAdhkar(_ collection: AdhkarCollection) {
        guard !scheduledAdhkarQueue.contains(where: { $0.id == collection.id }) else { return }
        scheduledAdhkarQueue.append(collection)
        presentNextScheduledAdhkarIfPossible()
    }

    private func presentNextScheduledAdhkarIfPossible() {
        guard !scheduledAdhkarQueue.isEmpty,
              !(compactAdhkarView?.isReciting ?? false),
              scheduledAdhkarDelayTimer == nil else { return }
        if isAdhanPlaying || (adhanIsDueThisMinute() && !completedAdhanAllowsQueuedAdhkar) {
            queuedAdhkarIsWaitingForAdhan = true
            return
        }
        let next = scheduledAdhkarQueue.removeFirst()
        queuedAdhkarIsWaitingForAdhan = false
        completedAdhanAllowsQueuedAdhkar = false
        showCompactAdhkar(next, autoPlay: true)
    }

    private func adhanIsDueThisMinute() -> Bool {
        guard UserDefaults.standard.bool(forKey: kAdhanEnabled), info.times.count >= 5 else {
            return false
        }
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .current
        let current = formatter.string(from: Date())
        return (0..<5).contains { index in
            info.times[index] == current && adhanModeForPrayer(index) == .adhan
        }
    }

    private func scheduleQueuedAdhkarAfterAdhan() {
        guard queuedAdhkarIsWaitingForAdhan, !scheduledAdhkarQueue.isEmpty else {
            presentNextScheduledAdhkarIfPossible()
            return
        }
        scheduledAdhkarDelayTimer?.invalidate()
        let minutes = max(0, UserDefaults.standard.integer(forKey: kAdhkarAfterAdhanDelay))
        let startQueued = { [weak self] in
            guard let self else { return }
            self.scheduledAdhkarDelayTimer = nil
            self.completedAdhanAllowsQueuedAdhkar = true
            self.presentNextScheduledAdhkarIfPossible()
        }
        if minutes == 0 {
            DispatchQueue.main.async(execute: startQueued)
        } else {
            scheduledAdhkarDelayTimer = Timer.scheduledTimer(
                withTimeInterval: TimeInterval(minutes * 60), repeats: false) { _ in
                    startQueued()
                }
        }
    }

    /// Open the adhkar window. `autoPlay` = true on scheduled trigger; false
    /// when the user opens it manually from the menu (still autoplays because
    /// that's the point of opening it, but leaves control to the user).
    func presentAdhkar(set: AdhkarSet, autoPlay: Bool) {
        let collection = AdhkarLibrary.load().first(where: {
            $0.categoryKey == set.rawValue || $0.name == set.arabicName
        }) ?? AdhkarCollection(name: set.arabicName,
                               categoryKey: set.rawValue,
                               items: AdhkarData.items(for: set).map { AdhkarEntry(from: $0) })
        showCompactAdhkar(collection, autoPlay: autoPlay)
    }

    /// v3 entry point — present a specific user collection.
    func presentAdhkar(collection: AdhkarCollection, autoPlay: Bool) {
        showCompactAdhkar(collection, autoPlay: autoPlay)
    }

    func todayString() -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.timeZone = TimeZone.current
        return f.string(from: Date())
    }
}

// ============================================================================
// MARK: App boot
// ============================================================================
let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
