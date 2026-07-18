import Cocoa
import CoreText
import WebKit
import AVFoundation
import CoreAudio
import CoreLocation
import UserNotifications
import ServiceManagement
import UniformTypeIdentifiers

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

// --- Qur'an reader ----------------------------------------------------------
// Canonical reading surfaces are the King Fahd Complex's explicitly
// embeddable publications. No Qur'an text is generated, OCR'd, transformed,
// or copied into UserDefaults; local state stores locators only.
let kQuranEditionKey       = "quranEdition"              // "hafs" | "warsh"
let kQuranBookmarksKey     = "quranBookmarksJSON_v1"
let kQuranLastHafsURL      = "quranLastHafsURL"
let kQuranLastWarshURL     = "quranLastWarshURL"
let kQuranHafsReaderURL    = "https://qurancomplex.gov.sa/isdarat-hafs/#flipbook-df_11301/1/"
let kQuranWarshReaderURL   = "https://qurancomplex.gov.sa/isdarat-qiraat/#flipbook-df_11326/1/"
let kQuranDeveloperURL     = "https://qurancomplex.gov.sa/quran-dev/"
let kMoroccanMushafURL     = "https://www.habous.gov.ma/fr/islam-au-maroc/6558-la-mise-en-ligne-de-al-moshaf-almohammadi.html"

let kAppVersion          = "3.13.2"

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

/// Convert a raw "HH:MM" string (always 24h from mawaqit) into the display
/// format the user chose in Settings. Returns the input unchanged when the
/// string doesn't parse — no silent loss of data for edge cases like "—".
func displayTime(_ hhmm: String) -> String {
    guard !hhmm.isEmpty else { return hhmm }
    let parts = hhmm.split(separator: ":")
    guard parts.count == 2, let h = Int(parts[0]), let m = Int(parts[1]) else {
        return hhmm
    }
    if !is12HourFormat() { return String(format: "%02d:%02d", h, m) }
    let period = h >= 12 ? "PM" : "AM"
    var h12 = h % 12
    if h12 == 0 { h12 = 12 }
    return String(format: "%d:%02d %@", h12, m, period)
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
    cal.locale = Locale(identifier: Localizer.shared.current.code)
    let fmt = DateFormatter()
    fmt.calendar = cal
    fmt.locale = cal.locale
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
            countText = String(format: t("adhkar.editor.count_times"), item.count)
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
        if let s = dicts[current.code]?[key], !s.isEmpty { return s }
        if let s = dicts["en"]?[key], !s.isEmpty { return s }
        return key
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
        "full.clock.am_outer": "AM · outer ring    PM · inner ring"
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
        "full.clock.am_outer": "Matin · anneau extérieur    Après-midi/soir · anneau intérieur"
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
        "full.clock.am_outer": "AM · anillo exterior    PM · anillo interior"
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
        "full.clock.am_outer": "صباحًا · الحلقة الخارجية    مساءً · الحلقة الداخلية"
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
        "full.clock.am_outer": "上午 · 外圈    下午及夜间 · 内圈"
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
        "full.clock.am_outer": "सुबह · बाहरी घेरा    दोपहर/रात · भीतरी घेरा"
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
        "full.clock.am_outer": "সকাল · বাইরের বলয়    বিকেল/রাত · ভেতরের বলয়"
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
        "full.clock.am_outer": "До полудня · внешнее кольцо    После полудня · внутреннее"
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
        "full.clock.am_outer": "Manhã · anel exterior    Tarde/noite · anel interior"
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
        "full.clock.am_outer": "صبح · بیرونی حلقہ    دوپہر/رات · اندرونی حلقہ"
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
        "Qur’an", "App destinations", "Official King Fahd Complex reader",
        "Source and integrity", "Official Moroccan Mushaf",
        "Open the Ministry of Habous’ official Warsh Mushaf Mohammadi",
        "Forward", "Search the Qur’an or enter 2:255", "Search",
        "Tafsir sources", "Official data", "Bookmarks", "Add bookmark",
        "Remove current bookmark", "Official Mushaf reader",
        "Enter a verse, for example 2:255", "King Fahd Complex developer data",
        "Study results use Hafs; the Warsh Mushaf remains separate",
        "Quran Foundation search and tafsir", "Name this reading place.",
        "Reading bookmark", "No bookmarks yet", "Verified Qur’an sources",
        "Hafs and Warsh pages load unchanged from the King Fahd Complex. Local bookmarks store only their location; no Qur’an text is generated or rewritten.",
        "Open official source", "Verified content is currently unavailable",
    ],
    "fr": [
        "Coran", "Sections de l’app", "Lecteur officiel du Complexe du roi Fahd",
        "Source et intégrité", "Mushaf marocain officiel",
        "Ouvrir le Mushaf Mohammadi officiel en Warsh du ministère des Habous",
        "Suivant", "Rechercher dans le Coran ou saisir 2:255", "Recherche",
        "Sources de tafsir", "Données officielles", "Signets", "Ajouter un signet",
        "Supprimer le signet actuel", "Lecteur officiel du Mushaf",
        "Saisissez un verset, par exemple 2:255", "Données développeur du Complexe du roi Fahd",
        "L’étude utilise Hafs ; le Mushaf Warsh reste séparé",
        "Recherche et tafsir de Quran Foundation", "Nommez cet emplacement de lecture.",
        "Signet de lecture", "Aucun signet", "Sources coraniques vérifiées",
        "Les pages Hafs et Warsh sont chargées sans modification depuis le Complexe du roi Fahd. Les signets ne stockent que l’emplacement ; aucun texte coranique n’est généré ni réécrit.",
        "Ouvrir la source officielle", "Le contenu vérifié est indisponible pour le moment",
    ],
    "es": [
        "Corán", "Secciones de la app", "Lector oficial del Complejo Rey Fahd",
        "Fuente e integridad", "Mushaf marroquí oficial",
        "Abrir el Mushaf Mohammadi oficial en Warsh del Ministerio de Habices",
        "Adelante", "Buscar en el Corán o escribir 2:255", "Buscar",
        "Fuentes de tafsir", "Datos oficiales", "Marcadores", "Añadir marcador",
        "Quitar marcador actual", "Lector oficial del Mushaf",
        "Escribe una aleya, por ejemplo 2:255", "Datos para desarrolladores del Complejo Rey Fahd",
        "El estudio usa Hafs; el Mushaf Warsh permanece separado",
        "Búsqueda y tafsir de Quran Foundation", "Pon un nombre a este punto de lectura.",
        "Marcador de lectura", "Aún no hay marcadores", "Fuentes coránicas verificadas",
        "Las páginas Hafs y Warsh se cargan sin cambios desde el Complejo Rey Fahd. Los marcadores solo guardan la ubicación; ningún texto coránico se genera ni reescribe.",
        "Abrir fuente oficial", "El contenido verificado no está disponible ahora",
    ],
    "ar": [
        "القرآن", "أقسام التطبيق", "قارئ رسمي من مجمع الملك فهد",
        "المصدر وسلامة المحتوى", "المصحف المغربي الرسمي",
        "فتح المصحف المحمدي الرسمي برواية ورش لوزارة الأوقاف والشؤون الإسلامية",
        "التالي", "ابحث في القرآن أو أدخل 2:255", "بحث",
        "مصادر التفسير", "البيانات الرسمية", "العلامات المرجعية", "إضافة علامة",
        "حذف العلامة الحالية", "قارئ المصحف الرسمي",
        "أدخل آية، مثل 2:255", "بيانات المطورين لمجمع الملك فهد",
        "نتائج البحث والتفسير برواية حفص، ويظل مصحف ورش مستقلاً",
        "بحث وتفاسير مؤسسة القرآن", "سمِّ موضع القراءة هذا.",
        "علامة قراءة", "لا توجد علامات بعد", "مصادر قرآن موثّقة",
        "تُحمَّل صفحات حفص وورش كما هي من مجمع الملك فهد. تحفظ العلامات الموضع فقط، ولا يُولَّد النص القرآني ولا يُعاد تحريره.",
        "فتح المصدر الرسمي", "المحتوى الموثّق غير متاح حاليًا",
    ],
    "zh": [
        "古兰经", "应用分区", "法赫德国王古兰经印刷院官方阅读器",
        "来源与完整性", "摩洛哥官方穆斯哈夫",
        "打开宗教基金部官方 Warsh《穆罕默迪穆斯哈夫》",
        "前进", "搜索古兰经或输入 2:255", "搜索",
        "经注来源", "官方数据", "书签", "添加书签",
        "移除当前书签", "官方穆斯哈夫阅读器",
        "输入经文，例如 2:255", "法赫德国王印刷院开发者数据",
        "研读结果使用 Hafs；Warsh 穆斯哈夫保持独立",
        "Quran Foundation 搜索与经注", "为此阅读位置命名。",
        "阅读书签", "暂无书签", "已验证的古兰经来源",
        "Hafs 与 Warsh 页面由法赫德国王印刷院原样加载。本地书签只保存位置，不生成或改写任何古兰经文本。",
        "打开官方来源", "已验证内容暂时不可用",
    ],
    "hi": [
        "क़ुरआन", "ऐप के भाग", "किंग फ़हद कॉम्प्लेक्स का आधिकारिक रीडर",
        "स्रोत और शुद्धता", "आधिकारिक मोरक्को मुसहफ़",
        "हबूस मंत्रालय का आधिकारिक वार्श मुसहफ़ मोहम्मदी खोलें",
        "आगे", "क़ुरआन खोजें या 2:255 लिखें", "खोज",
        "तफ़सीर स्रोत", "आधिकारिक डेटा", "बुकमार्क", "बुकमार्क जोड़ें",
        "मौजूदा बुकमार्क हटाएँ", "आधिकारिक मुसहफ़ रीडर",
        "आयत लिखें, जैसे 2:255", "किंग फ़हद कॉम्प्लेक्स डेवलपर डेटा",
        "अध्ययन परिणाम हफ़्स में हैं; वार्श मुसहफ़ अलग रहता है",
        "Quran Foundation खोज और तफ़सीर", "इस पढ़ने की जगह को नाम दें।",
        "पढ़ने का बुकमार्क", "अभी कोई बुकमार्क नहीं", "सत्यापित क़ुरआन स्रोत",
        "हफ़्स और वार्श पृष्ठ किंग फ़हद कॉम्प्लेक्स से बिना बदलाव लोड होते हैं। बुकमार्क केवल स्थान रखते हैं; क़ुरआन पाठ बनाया या बदला नहीं जाता।",
        "आधिकारिक स्रोत खोलें", "सत्यापित सामग्री अभी उपलब्ध नहीं है",
    ],
    "bn": [
        "কুরআন", "অ্যাপের বিভাগ", "কিং ফাহদ কমপ্লেক্সের সরকারি পাঠক",
        "উৎস ও অখণ্ডতা", "সরকারি মরক্কোর মুসহাফ",
        "হাবুস মন্ত্রণালয়ের সরকারি ওয়ারশ মুসহাফ মোহাম্মদি খুলুন",
        "সামনে", "কুরআনে খুঁজুন বা 2:255 লিখুন", "খোঁজ",
        "তাফসিরের উৎস", "সরকারি ডেটা", "বুকমার্ক", "বুকমার্ক যোগ করুন",
        "বর্তমান বুকমার্ক মুছুন", "সরকারি মুসহাফ পাঠক",
        "আয়াত লিখুন, যেমন 2:255", "কিং ফাহদ কমপ্লেক্স ডেভেলপার ডেটা",
        "অধ্যয়নের ফল হাফস ব্যবহার করে; ওয়ারশ মুসহাফ আলাদা থাকে",
        "Quran Foundation খোঁজ ও তাফসির", "এই পড়ার স্থানটির নাম দিন।",
        "পড়ার বুকমার্ক", "এখনও কোনো বুকমার্ক নেই", "যাচাইকৃত কুরআনের উৎস",
        "হাফস ও ওয়ারশ পৃষ্ঠা কিং ফাহদ কমপ্লেক্স থেকে অপরিবর্তিতভাবে লোড হয়। বুকমার্ক শুধু অবস্থান রাখে; কুরআনের পাঠ তৈরি বা বদলানো হয় না।",
        "সরকারি উৎস খুলুন", "যাচাইকৃত বিষয়বস্তু এখন পাওয়া যাচ্ছে না",
    ],
    "ru": [
        "Коран", "Разделы приложения", "Официальный ридер Комплекса короля Фахда",
        "Источник и целостность", "Официальный марокканский мусхаф",
        "Открыть официальный марокканский Мусхаф Мухаммади в чтении Варш",
        "Вперёд", "Поиск по Корану или ссылка 2:255", "Поиск",
        "Источники тафсира", "Официальные данные", "Закладки", "Добавить закладку",
        "Удалить текущую закладку", "Официальный ридер мусхафа",
        "Введите аят, например 2:255", "Данные для разработчиков Комплекса короля Фахда",
        "Материалы для изучения используют Хафс; мусхаф Варш остаётся отдельным",
        "Поиск и тафсиры Quran Foundation", "Назовите это место чтения.",
        "Закладка чтения", "Закладок пока нет", "Проверенные источники Корана",
        "Страницы Хафс и Варш загружаются без изменений из Комплекса короля Фахда. Закладки хранят только позицию; текст Корана не создаётся и не переписывается.",
        "Открыть официальный источник", "Проверенное содержимое сейчас недоступно",
    ],
    "pt": [
        "Alcorão", "Secções da app", "Leitor oficial do Complexo Rei Fahd",
        "Fonte e integridade", "Mushaf marroquino oficial",
        "Abrir o Mushaf Mohammadi oficial em Warsh do Ministério dos Habous",
        "Avançar", "Pesquisar no Alcorão ou introduzir 2:255", "Pesquisa",
        "Fontes de tafsir", "Dados oficiais", "Marcadores", "Adicionar marcador",
        "Remover marcador atual", "Leitor oficial do Mushaf",
        "Introduza um versículo, por exemplo 2:255", "Dados para programadores do Complexo Rei Fahd",
        "O estudo usa Hafs; o Mushaf Warsh permanece separado",
        "Pesquisa e tafsir da Quran Foundation", "Dê um nome a este ponto de leitura.",
        "Marcador de leitura", "Ainda não há marcadores", "Fontes do Alcorão verificadas",
        "As páginas Hafs e Warsh são carregadas sem alterações do Complexo Rei Fahd. Os marcadores guardam apenas a posição; nenhum texto do Alcorão é gerado ou reescrito.",
        "Abrir fonte oficial", "O conteúdo verificado está indisponível neste momento",
    ],
    "ur": [
        "قرآن", "ایپ کے حصے", "کنگ فہد کمپلیکس کا سرکاری قاری",
        "ماخذ اور صحت", "سرکاری مراکشی مصحف",
        "وزارتِ اوقاف کا سرکاری ورش مصحف محمدی کھولیں",
        "آگے", "قرآن میں تلاش کریں یا 2:255 لکھیں", "تلاش",
        "تفاسیر کے ماخذ", "سرکاری ڈیٹا", "بک مارکس", "بک مارک شامل کریں",
        "موجودہ بک مارک ہٹائیں", "سرکاری مصحف قاری",
        "آیت لکھیں، مثلاً 2:255", "کنگ فہد کمپلیکس کا ڈویلپر ڈیٹا",
        "مطالعہ کے نتائج حفص میں ہیں؛ ورش مصحف الگ رہتا ہے",
        "Quran Foundation تلاش اور تفاسیر", "اس مطالعہ کی جگہ کو نام دیں۔",
        "مطالعہ بک مارک", "ابھی کوئی بک مارک نہیں", "تصدیق شدہ قرآنی ماخذ",
        "حفص اور ورش کے صفحات کنگ فہد کمپلیکس سے بغیر تبدیلی لوڈ ہوتے ہیں۔ بک مارک صرف مقام محفوظ کرتے ہیں؛ قرآنی متن بنایا یا بدلا نہیں جاتا۔",
        "سرکاری ماخذ کھولیں", "تصدیق شدہ مواد فی الحال دستیاب نہیں",
    ],
]

func featureText(_ key: String) -> String {
    let code = Localizer.shared.current.code
    if let index = quranTranslationKeys.firstIndex(of: key),
       let row = quranTranslationRows[code], row.indices.contains(index) {
        return row[index]
    }
    if let index = quranTranslationKeys.firstIndex(of: key),
       let row = quranTranslationRows["en"], row.indices.contains(index) {
        return row[index]
    }
    return featureTranslations[code]?[key]
        ?? featureTranslations["en"]?[key]
        ?? key
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

    init(width: CGFloat, height: CGFloat) {
        super.init(frame: NSRect(x: 0, y: 0, width: width, height: height))
        build()
        refreshCurrentMode()
    }
    required init?(coder: NSCoder) { fatalError() }

    private func build() {
        let W = bounds.width, H = bounds.height

        // -------------------- Header: back + title -------------------------
        backBtn = HoverIconButton(
            symbol: backChevronSymbol,
            toolTip: t("tooltip.back"),
            target: self,
            action: #selector(backTapped),
            pointSize: 14,
            size: NSSize(width: 36, height: 28))
        backBtn.setFrameOrigin(NSPoint(x: 10, y: 10))
        addSubview(backBtn)

        titleLbl.frame = NSRect(x: 60, y: 14, width: W - 120, height: 20)
        titleLbl.font = Localizer.shared.font(size: 13, weight: .semibold)
        titleLbl.alignment = .center
        titleLbl.textColor = .labelColor
        titleLbl.drawsBackground = false
        addSubview(titleLbl)

        // Hairline under the title bar for visual separation.
        let hdrSep = NSBox(frame: NSRect(x: 12, y: 42, width: W - 24, height: 1))
        hdrSep.boxType = .separator
        addSubview(hdrSep)

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
        segmented.frame = NSRect(x: 12, y: 50, width: segTotal, height: 26)
        addSubview(segmented)

        // Status / help line. Dynamically shows the active tab's hint text,
        // the search-in-progress message, or a result count.
        statusLabel.frame = NSRect(x: 12, y: 80, width: W - 24, height: 14)
        statusLabel.font = Localizer.shared.font(size: 10)
        statusLabel.textColor = .secondaryLabelColor
        statusLabel.drawsBackground = false
        statusLabel.alignment = .center
        statusLabel.lineBreakMode = .byTruncatingTail
        statusLabel.autoresizingMask = [.width]
        addSubview(statusLabel)

        // -------------------- Input area ----------------------------------
        inputContainer.frame = NSRect(x: 12, y: 100, width: W - 24, height: 30)
        inputContainer.autoresizingMask = [.width]
        addSubview(inputContainer)

        let iw = inputContainer.bounds.width

        // Compact Go / Add icon buttons (arrow.right in a 30×26 pill) leave
        // the textfield with most of the row. All-icon to honour the
        // monotone-icon rule.
        let btnW: CGFloat = 30

        searchField.frame = NSRect(x: 0, y: 2, width: iw - btnW - 4, height: 24)
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

        goSearchBtn.frame = NSRect(x: iw - btnW, y: 0, width: btnW, height: 28)
        goSearchBtn.bezelStyle = .rounded
        goSearchBtn.title = ""
        goSearchBtn.target = self
        goSearchBtn.action = #selector(runSearch)
        goSearchBtn.keyEquivalent = "\r"
        goSearchBtn.autoresizingMask = [.minXMargin]
        goSearchBtn.toolTip = t("picker.btn.search")
        if let img = templateSymbol("magnifyingglass", pointSize: 12, weight: .semibold) {
            goSearchBtn.image = img
            goSearchBtn.imagePosition = .imageOnly
        }

        urlField.frame = NSRect(x: 0, y: 2, width: iw - btnW - 4, height: 24)
        urlField.placeholderString = "mawaqit.net/fr/m/…"
        urlField.font = Localizer.shared.font(size: 12)
        urlField.target = self
        urlField.action = #selector(runAddURL)
        urlField.autoresizingMask = [.width]

        addUrlBtn.frame = NSRect(x: iw - btnW, y: 0, width: btnW, height: 28)
        addUrlBtn.bezelStyle = .rounded
        addUrlBtn.title = ""
        addUrlBtn.target = self
        addUrlBtn.action = #selector(runAddURL)
        addUrlBtn.keyEquivalent = "\r"
        addUrlBtn.autoresizingMask = [.minXMargin]
        addUrlBtn.toolTip = t("picker.btn.add")
        if let img = templateSymbol("plus", pointSize: 12, weight: .semibold) {
            addUrlBtn.image = img
            addUrlBtn.imagePosition = .imageOnly
        }

        // Nearby: compact [city text field][location icon button] row. The
        // icon button on the right reverse-geocodes the device location into
        // a city name and runs the same search the text field does — so the
        // UX stays uniform regardless of whether the city is typed or
        // detected automatically.
        cityField.frame = NSRect(x: 0, y: 2, width: iw - btnW - 4, height: 24)
        cityField.placeholderString = t("picker.placeholder.city")
        cityField.font = Localizer.shared.font(size: 12)
        cityField.delegate = self
        cityField.target = self
        cityField.action = #selector(runCitySearch)
        cityField.autoresizingMask = [.width]
        cityField.stringValue = userCity()

        nearMeBtn.frame = NSRect(x: iw - btnW, y: 0, width: btnW, height: 28)
        nearMeBtn.bezelStyle = .rounded
        nearMeBtn.title = ""
        nearMeBtn.target = self
        nearMeBtn.action = #selector(runNearMe)
        nearMeBtn.keyEquivalent = ""
        nearMeBtn.autoresizingMask = [.minXMargin]
        nearMeBtn.toolTip = t("picker.btn.near")
        if let img = templateSymbol("location.fill", pointSize: 12, weight: .semibold) {
            nearMeBtn.image = img
            nearMeBtn.imagePosition = .imageOnly
        }

        // -------------------- Results scroll view -------------------------
        scrollView.frame = NSRect(x: 12, y: 138, width: W - 24, height: H - 150)
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
        statusLabel.stringValue = String(format: "Identifying your city (%.3f, %.3f)…", lat, lon)

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
        let rowH: CGFloat = 44
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
        nameLbl.frame = NSRect(x: textX, y: 5, width: textW, height: 18)
        nameLbl.font = Localizer.shared.font(size: 13, weight: .semibold)
        nameLbl.textColor = .labelColor
        nameLbl.drawsBackground = false
        nameLbl.lineBreakMode = .byTruncatingTail
        row.addSubview(nameLbl)
        let sub = NSTextField(labelWithString: "\(count) \(count == 1 ? "mosque" : "mosques")")
        sub.frame = NSRect(x: textX, y: 23, width: textW, height: 14)
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
        statusLabel.stringValue = "\(refs.count) result\(refs.count == 1 ? "" : "s")"
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
        let nameH:     CGFloat = 18
        let subH:      CGFloat = 14
        let extraLines = (hasCity ? 1 : 0) + (hasAddress ? 1 : 0)
        let rowH: CGFloat = padTop + nameH +
                            (extraLines > 0 ? lineGap : 0) +
                            CGFloat(extraLines) * subH +
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
        name.font = Localizer.shared.font(size: 13, weight: .semibold)
        name.textColor = isCurrent ? .appGreenAccent : .labelColor
        name.drawsBackground = false
        name.lineBreakMode = .byTruncatingTail
        name.toolTip = m.name
        row.addSubview(name)
        y += nameH

        if hasCity {
            y += lineGap
            let city = NSTextField(labelWithString: m.city)
            city.frame = NSRect(x: leftPad, y: y, width: textW, height: subH)
            city.font = Localizer.shared.font(size: 11, weight: .medium)
            city.textColor = .secondaryLabelColor
            city.drawsBackground = false
            city.lineBreakMode = .byTruncatingTail
            city.toolTip = m.city
            row.addSubview(city)
            y += subH
        }

        if hasAddress {
            y += lineGap
            let addrLbl = NSTextField(labelWithString: addr)
            addrLbl.frame = NSRect(x: leftPad, y: y, width: textW, height: subH)
            addrLbl.font = Localizer.shared.font(size: 10)
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
                preAdhanPopup.addItem(withTitle: String(format: fmt, minutes))
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

/// Full-window host for mosque discovery. The picker used to push the user
/// back into the tiny menu-bar popover, which made Settings feel split across
/// two unrelated apps. It now behaves as a Settings sub-page and returns to
/// the same full-window surface.
final class MainMosquePickerViewController: NSViewController, MainTabContent {
    private weak var appDelegate: AppDelegate?
    var onDone: (() -> Void)?
    private var picker: MosquePickerView!

    init(appDelegate: AppDelegate) {
        self.appDelegate = appDelegate
        super.init(nibName: nil, bundle: nil)
    }
    required init?(coder: NSCoder) { fatalError() }

    override func loadView() {
        let root = NSView(frame: NSRect(x: 0, y: 0, width: 960, height: 554))
        root.userInterfaceLayoutDirection = Localizer.shared.isRTL ? .rightToLeft : .leftToRight
        picker = MosquePickerView(width: 960, height: 554)
        picker.translatesAutoresizingMaskIntoConstraints = false
        picker.appDelegate = appDelegate
        picker.onDone = { [weak self] in self?.onDone?() }
        root.addSubview(picker)
        NSLayoutConstraint.activate([
            picker.leadingAnchor.constraint(equalTo: root.leadingAnchor),
            picker.trailingAnchor.constraint(equalTo: root.trailingAnchor),
            picker.topAnchor.constraint(equalTo: root.topAnchor),
            picker.bottomAnchor.constraint(equalTo: root.bottomAnchor),
        ])
        view = root
    }

    func tabDidActivate() { picker?.refreshCurrentMode() }
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
    private var mosquePickerVC: MainMosquePickerViewController?
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
        mosquePickerVC = nil
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

    private func showSettings(section: Int?) {
        if settingsVC == nil {
            settingsVC = AdhkarSettingsViewController(initialSection: section ?? 0)
        } else if let section {
            settingsVC?.selectSection(section)
        }
        guard let settingsVC else { return }
        present(settingsVC)
    }

    /// Public entry point used by the popup gear. Settings remain a single
    /// full-window surface; the compact popup only chooses which section is
    /// most relevant to open.
    func showSettingsWindow(section: Int) {
        isShowingSettings = true
        showSettings(section: section)
    }

    func showMosquePickerFromSettings() {
        guard let appDelegate else { return }
        isShowingSettings = true
        if mosquePickerVC == nil {
            let controller = MainMosquePickerViewController(appDelegate: appDelegate)
            controller.onDone = { [weak self] in self?.showSettings(section: 0) }
            mosquePickerVC = controller
        }
        if let mosquePickerVC { present(mosquePickerVC) }
    }

    func reloadPrayerDashboard() {
        adhanVC?.tabDidActivate()
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

/// A 24-hour visualization that makes the relationship between the obligatory
/// prayers and the Nawafil windows visible at a glance. The overview remains
/// available for users who prefer a conventional list.
final class PrayerDayTimelineView: NSControl {
    private let info: MosqueInfo
    private let prayerNames: [String]
    private let showsNawafil: Bool
    private var markerPoints: [(point: NSPoint, name: String, raw: String)] = []
    private var hoveredMarker: Int?
    private var selectedMarker: Int?
    private var trackingAreaRef: NSTrackingArea?
    private var minuteTimer: Timer?

    override var isFlipped: Bool { true }
    override var acceptsFirstResponder: Bool { true }

    init(frame: NSRect, info: MosqueInfo, prayerNames: [String],
         showsNawafil: Bool) {
        self.info = info
        self.prayerNames = prayerNames
        self.showsNawafil = showsNawafil
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
        NSAttributedString(string: value, attributes: [
            .font: Localizer.shared.font(size: size, weight: weight),
            .foregroundColor: color,
            .paragraphStyle: paragraph,
        ]).draw(in: rect)
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
            markerPoints.append((NSPoint(x: x, y: lineY), point.name, point.raw))
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
            drawText(String(format: "%02d:00", hour % 24),
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

/// A live analog clock with two prayer rings: AM events sit on the outer
/// ring and PM events on the inner ring. This preserves conventional
/// clockwise clock behavior in Arabic while the labels and surrounding UI
/// still follow RTL.
final class PrayerAnalogClockView: NSControl {
    private let info: MosqueInfo
    private let prayerNames: [String]
    private let showsNawafil: Bool
    private var timer: Timer?
    private var trackingAreaRef: NSTrackingArea?
    private var markerPoints: [(point: NSPoint, title: String, raw: String)] = []
    private var hoveredMarker: Int?

    override var isFlipped: Bool { true }

    init(frame: NSRect, info: MosqueInfo, prayerNames: [String],
         showsNawafil: Bool) {
        self.info = info
        self.prayerNames = prayerNames
        self.showsNawafil = showsNawafil
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
        NSAttributedString(string: string, attributes: [
            .font: Localizer.shared.font(size: size, weight: weight),
            .foregroundColor: color,
            .paragraphStyle: paragraph,
        ]).draw(in: rect)
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
            drawText("\(hour)", rect: NSRect(x: numeral.x - 12, y: numeral.y - 9,
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
            markerPoints.append((marker, prayerNames[index], info.times[index]))
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

        let nowString = DateFormatter.localizedString(from: now, dateStyle: .none,
                                                       timeStyle: .medium)
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

final class PrayerDashboardViewController: NSViewController, MainTabContent {
    private weak var appDelegate: AppDelegate?
    private var scrollView: NSScrollView!
    private var modeControl: NSSegmentedControl!
    private var nawafilControl: NSSegmentedControl!
    private var displayMode = max(0, min(3,
        UserDefaults.standard.integer(forKey: kPrayerDashboardMode)))
    private var nawafilMode: Int = {
        guard UserDefaults.standard.object(forKey: kPrayerNawafilMode) != nil else { return 2 }
        return max(0, min(2, UserDefaults.standard.integer(forKey: kPrayerNawafilMode)))
    }()
    private var lastRenderedWidth: CGFloat = 0
    private var didSetInitialScrollPosition = false

    private typealias NawafilData = (title: String, count: String, window: String,
                                     best: String, source: String)

    init(appDelegate: AppDelegate) {
        self.appDelegate = appDelegate
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError() }

    override func loadView() {
        let root = NSView()
        root.userInterfaceLayoutDirection = Localizer.shared.isRTL ? .rightToLeft : .leftToRight
        modeControl = NSSegmentedControl(labels: [featureText("full.view.overview"),
                                                  featureText("full.view.list"),
                                                  featureText("full.view.timeline"),
                                                  featureText("full.view.clock")],
                                         trackingMode: .selectOne,
                                         target: self,
                                         action: #selector(modeChanged(_:)))
        modeControl.segmentStyle = .texturedRounded
        modeControl.userInterfaceLayoutDirection = root.userInterfaceLayoutDirection
        modeControl.selectedSegment = displayMode
        modeControl.translatesAutoresizingMaskIntoConstraints = false
        modeControl.setAccessibilityLabel(t("main.tab.prayer_times"))

        nawafilControl = NSSegmentedControl(labels: [featureText("full.nawafil.hide"),
                                                     featureText("full.nawafil.integrated"),
                                                     featureText("full.nawafil.separate")],
                                            trackingMode: .selectOne,
                                            target: self,
                                            action: #selector(nawafilModeChanged(_:)))
        nawafilControl.segmentStyle = .texturedRounded
        nawafilControl.selectedSegment = nawafilMode
        nawafilControl.userInterfaceLayoutDirection = root.userInterfaceLayoutDirection
        nawafilControl.translatesAutoresizingMaskIntoConstraints = false
        nawafilControl.setAccessibilityLabel(featureText("full.nawafil"))

        let controlRail = NSStackView(views: [modeControl, nawafilControl])
        controlRail.orientation = .horizontal
        controlRail.alignment = .centerY
        controlRail.spacing = 12
        controlRail.userInterfaceLayoutDirection = root.userInterfaceLayoutDirection
        controlRail.translatesAutoresizingMaskIntoConstraints = false
        root.addSubview(controlRail)

        scrollView = NSScrollView()
        scrollView.drawsBackground = false
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        if Localizer.shared.isRTL { scrollView.userInterfaceLayoutDirection = .rightToLeft }
        root.addSubview(scrollView)
        NSLayoutConstraint.activate([
            controlRail.topAnchor.constraint(equalTo: root.topAnchor, constant: 12),
            controlRail.centerXAnchor.constraint(equalTo: root.centerXAnchor),
            controlRail.leadingAnchor.constraint(greaterThanOrEqualTo: root.leadingAnchor,
                                                 constant: 20),
            controlRail.trailingAnchor.constraint(lessThanOrEqualTo: root.trailingAnchor,
                                                   constant: -20),
            modeControl.widthAnchor.constraint(equalToConstant: 420),
            modeControl.heightAnchor.constraint(equalToConstant: 30),
            nawafilControl.widthAnchor.constraint(equalToConstant: 280),
            nawafilControl.heightAnchor.constraint(equalToConstant: 30),

            scrollView.leadingAnchor.constraint(equalTo: root.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: root.trailingAnchor),
            scrollView.topAnchor.constraint(equalTo: controlRail.bottomAnchor, constant: 8),
            scrollView.bottomAnchor.constraint(equalTo: root.bottomAnchor),
        ])
        self.view = root
        rebuild()
    }

    override func viewDidLayout() {
        super.viewDidLayout()
        guard scrollView != nil else { return }
        let width = max(760, scrollView.contentSize.width)
        if abs(width - lastRenderedWidth) > 2 { rebuild() }
    }

    func tabDidActivate() {
        modeControl?.setLabel(featureText("full.view.overview"), forSegment: 0)
        modeControl?.setLabel(featureText("full.view.list"), forSegment: 1)
        modeControl?.setLabel(featureText("full.view.timeline"), forSegment: 2)
        modeControl?.setLabel(featureText("full.view.clock"), forSegment: 3)
        nawafilControl?.setLabel(featureText("full.nawafil.hide"), forSegment: 0)
        nawafilControl?.setLabel(featureText("full.nawafil.integrated"), forSegment: 1)
        nawafilControl?.setLabel(featureText("full.nawafil.separate"), forSegment: 2)
        rebuild()
    }

    @objc private func modeChanged(_ sender: NSSegmentedControl) {
        displayMode = max(0, min(3, sender.selectedSegment))
        UserDefaults.standard.set(displayMode, forKey: kPrayerDashboardMode)
        rebuild()
        scrollView.contentView.scroll(to: .zero)
        scrollView.reflectScrolledClipView(scrollView.contentView)
    }

    @objc private func nawafilModeChanged(_ sender: NSSegmentedControl) {
        nawafilMode = max(0, min(2, sender.selectedSegment))
        UserDefaults.standard.set(nawafilMode, forKey: kPrayerNawafilMode)
        rebuild()
        scrollView.contentView.scroll(to: .zero)
        scrollView.reflectScrolledClipView(scrollView.contentView)
    }

    private func rebuild() {
        guard scrollView != nil else { return }
        let width = max(760, scrollView.contentSize.width)
        lastRenderedWidth = width
        let separateExtra: CGFloat = nawafilMode == 2 ? 560 : 0
        let bodyHeight: CGFloat
        switch displayMode {
        case 0: bodyHeight = 670 + separateExtra
        case 1: bodyHeight = (nawafilMode == 1 ? 1110 : 760) + separateExtra
        case 2: bodyHeight = 660 + separateExtra
        default: bodyHeight = 820 + separateExtra
        }
        let body = FlippedView(frame: NSRect(x: 0, y: 0, width: width, height: bodyHeight))
        body.autoresizingMask = [.width]
        scrollView.documentView = body
        guard let app = appDelegate else { return }
        let contentWidth = min(856, max(680, width - 64))
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
        field.frame = frame
        field.font = Localizer.shared.font(size: size, weight: weight)
        field.textColor = color
        field.alignment = alignment ?? (isRTL ? .right : .left)
        field.baseWritingDirection = isRTL ? .rightToLeft : .leftToRight
        field.lineBreakMode = wrapping ? .byWordWrapping : .byTruncatingTail
        if wrapping { field.maximumNumberOfLines = 2 }
        return field
    }

    private func localizedLongDate() -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: Localizer.shared.current.code)
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

            let mode = NSButton(frame: NSRect(x: isRTL ? 5 : tileWidth - 43,
                                              y: 5, width: 38, height: 38))
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

            let nameX: CGFloat = isRTL ? 42 : 12
            content.addSubview(dashboardLabel(app.localizedPrayerName(at: index),
                frame: NSRect(x: nameX, y: 14, width: tileWidth - 54, height: 24),
                size: 15.5, weight: .semibold,
                color: index == nextIndex ? .appGreenAccent : .labelColor))
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
            (t("prayer.shuruq"), app.info.shuruq,
             featureText("full.landmark.sunrise"), "sunrise.fill"),
            (featureText("full.sunset"), sunsetRaw,
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
            card.addSubview(dashboardLabel(row.title,
                frame: NSRect(x: x + 8, y: 13, width: columnWidth - 16, height: 22),
                size: 13, weight: .semibold, alignment: .center))
            card.addSubview(dashboardLabel(row.count,
                frame: NSRect(x: x + 8, y: 40, width: columnWidth - 16, height: 18),
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
        body.addSubview(PrayerDayTimelineView(
            frame: NSRect(x: x, y: 84, width: width, height: 360),
            info: app.info, prayerNames: names, showsNawafil: nawafilMode == 1))

        body.addSubview(dashboardLabel(featureText("full.landmarks"),
            frame: NSRect(x: x, y: 468, width: width, height: 30),
            size: 22, weight: .bold))
        addLandmarksStrip(to: body, app: app,
                          frame: NSRect(x: x, y: 506, width: width, height: 82))

        if nawafilMode == 2 {
            body.addSubview(dashboardLabel(featureText("full.nawafil"),
                frame: NSRect(x: x, y: 616, width: width, height: 30),
                size: 22, weight: .bold))
            let rows = nawafilData(app: app)
            for (index, row) in rows.enumerated() {
                addNawafilRow(to: body,
                              frame: NSRect(x: x, y: 654 + CGFloat(index) * 128,
                                            width: width, height: 116), data: row)
            }
            addGuidance(to: body, frame: NSRect(x: x, y: 1174,
                                                width: width, height: 34))
        }
    }

    private func buildList(in body: NSView, app: AppDelegate,
                           x: CGFloat, width: CGFloat) {
        let mosqueName = app.info.name.isEmpty ? t("mosque.default") : app.info.name
        body.addSubview(dashboardLabel(featureText("full.view.list"),
            frame: NSRect(x: x, y: 20, width: width, height: 32),
            size: 24, weight: .bold))
        body.addSubview(dashboardLabel("\(mosqueName) · \(localizedLongDate())",
            frame: NSRect(x: x, y: 52, width: width, height: 21),
            size: 12, color: .secondaryLabelColor))

        var y: CGFloat = 88
        func prayer(_ index: Int) {
            addPrayerListRow(to: body, app: app, index: index,
                frame: NSRect(x: x, y: y, width: width, height: 72))
            y += 80
        }
        func nafl(_ title: String, _ detail: String) {
            addNawafilListRow(to: body, title: title, detail: detail,
                frame: NSRect(x: x + 20, y: y, width: width - 40, height: 52))
            y += 60
        }
        func landmark(_ title: String, _ raw: String, _ symbol: String) {
            addLandmarkListRow(to: body, title: title, raw: raw, symbol: symbol,
                frame: NSRect(x: x + 20, y: y, width: width - 40, height: 52))
            y += 60
        }

        if nawafilMode == 1 {
            nafl(featureText("nawafil.rawatib"), featureText("nawafil.rawatib.count"))
            prayer(0)
            landmark(t("prayer.shuruq"), app.info.shuruq, "sunrise.fill")
            nafl(featureText("nawafil.duha"), featureText("nawafil.duha.count"))
            prayer(1)
            if !app.info.jumua.isEmpty {
                landmark(t("label.jumua"), app.info.jumua, "person.2.fill")
            }
            nafl(featureText("nawafil.rawatib"), featureText("nawafil.rawatib.best"))
            prayer(2)
            let sunset = (app.info.sunset ?? "").isEmpty
                ? (app.info.times.indices.contains(3) ? app.info.times[3] : "")
                : app.info.sunset!
            landmark(featureText("full.sunset"), sunset, "sunset.fill")
            prayer(3)
            nafl(featureText("nawafil.rawatib"), featureText("nawafil.rawatib.best"))
            prayer(4)
            nafl("\(featureText("nawafil.qiyam")) · \(featureText("nawafil.witr"))",
                 featureText("nawafil.qiyam.best"))
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
        let isRTL = Localizer.shared.isRTL
        let card = AdaptiveCardView(frame: frame)
        card.cornerRadius = 12
        parent.addSubview(card)
        let mode = NSButton(frame: NSRect(x: isRTL ? 12 : frame.width - 52,
                                          y: 16, width: 40, height: 40))
        mode.isBordered = false
        mode.title = ""
        mode.tag = index
        mode.target = app
        mode.action = #selector(AppDelegate.adhanModeButtonTapped(_:))
        mode.imagePosition = .imageOnly
        mode.focusRingType = .default
        mode.setAccessibilityLabel(app.localizedPrayerName(at: index))
        app.applyAdhanModeIcon(to: mode, mode: adhanModeForPrayer(index))
        card.addSubview(mode)

        let titleX: CGFloat = isRTL ? 64 : 18
        let titleWidth = frame.width * 0.36
        card.addSubview(dashboardLabel(app.localizedPrayerName(at: index),
            frame: NSRect(x: titleX, y: 15, width: titleWidth, height: 25),
            size: 17, weight: .semibold))
        let raw = app.info.times.indices.contains(index) ? app.info.times[index] : ""
        let timeX: CGFloat = frame.width * 0.43
        let adhan = dashboardLabel(raw.isEmpty ? "—" : displayTime(raw),
            frame: NSRect(x: timeX, y: 13, width: frame.width * 0.22, height: 33),
            size: 27, weight: .semibold, alignment: .center)
        adhan.font = NSFont.monospacedDigitSystemFont(ofSize: 27, weight: .semibold)
        card.addSubview(adhan)
        let iqama = app.iqamaTimeAt(index).map(displayTime) ?? "—"
        let iqamaX: CGFloat = isRTL ? 18 : frame.width * 0.69
        card.addSubview(dashboardLabel("\(t("col.iqama")) · \(iqama)",
            frame: NSRect(x: iqamaX, y: 45,
                          width: frame.width * 0.27, height: 20),
            size: 12.5, color: .secondaryLabelColor,
            alignment: isRTL ? .left : .right))
    }

    private func addNawafilListRow(to parent: NSView, title: String, detail: String,
                                   frame: NSRect) {
        let card = AdaptiveCardView(frame: frame)
        card.cornerRadius = 10
        parent.addSubview(card)
        let icon = NSImageView(frame: NSRect(x: Localizer.shared.isRTL
                                              ? frame.width - 39 : 14,
                                             y: 15, width: 20, height: 20))
        icon.image = templateSymbol("sparkles", pointSize: 13, weight: .semibold)
        icon.contentTintColor = .appGreenAccent
        card.addSubview(icon)
        let textX: CGFloat = Localizer.shared.isRTL ? 14 : 44
        card.addSubview(dashboardLabel(title,
            frame: NSRect(x: textX, y: 7, width: frame.width - 58, height: 21),
            size: 14, weight: .semibold, color: .appGreenAccent))
        card.addSubview(dashboardLabel(detail,
            frame: NSRect(x: textX, y: 29, width: frame.width - 58, height: 17),
            size: 11.5, color: .secondaryLabelColor))
    }

    private func addLandmarkListRow(to parent: NSView, title: String, raw: String,
                                    symbol: String, frame: NSRect) {
        let card = AdaptiveCardView(frame: frame)
        card.cornerRadius = 10
        parent.addSubview(card)
        let isRTL = Localizer.shared.isRTL
        let icon = NSImageView(frame: NSRect(x: isRTL ? frame.width - 39 : 14,
                                             y: 16, width: 20, height: 20))
        icon.image = templateSymbol(symbol, pointSize: 13, weight: .semibold)
        icon.contentTintColor = NSColor.systemOrange
        card.addSubview(icon)
        card.addSubview(dashboardLabel(title,
            frame: NSRect(x: isRTL ? 14 : 44, y: 14,
                          width: frame.width * 0.55, height: 23),
            size: 14, weight: .semibold))
        let time = dashboardLabel(raw.isEmpty ? "—" : displayTime(raw),
            frame: NSRect(x: isRTL ? 44 : frame.width * 0.70, y: 11,
                          width: frame.width * 0.25, height: 28),
            size: 19, weight: .semibold,
            alignment: isRTL ? .left : .right)
        time.font = NSFont.monospacedDigitSystemFont(ofSize: 19, weight: .semibold)
        card.addSubview(time)
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
        body.addSubview(PrayerAnalogClockView(
            frame: NSRect(x: x, y: 84, width: width, height: 500),
            info: app.info, prayerNames: names, showsNawafil: nawafilMode == 1))
        body.addSubview(dashboardLabel(featureText("full.landmarks"),
            frame: NSRect(x: x, y: 610, width: width, height: 30),
            size: 22, weight: .bold))
        addLandmarksStrip(to: body, app: app,
                          frame: NSRect(x: x, y: 648, width: width, height: 82))

        if nawafilMode == 2 {
            body.addSubview(dashboardLabel(featureText("full.nawafil"),
                frame: NSRect(x: x, y: 758, width: width, height: 30),
                size: 22, weight: .bold))
            let rows = nawafilData(app: app)
            for (index, row) in rows.enumerated() {
                addNawafilRow(to: body,
                              frame: NSRect(x: x, y: 796 + CGFloat(index) * 128,
                                            width: width, height: 116), data: row)
            }
            addGuidance(to: body, frame: NSRect(x: x, y: 1316,
                                                width: width, height: 34))
        }
    }

    private func nawafilData(app: AppDelegate) -> [NawafilData] {
        let duhaWindow: String = {
            guard !app.info.shuruq.isEmpty, app.info.times.indices.contains(1) else { return "—" }
            return "\(displayTime(app.addMinutes(to: app.info.shuruq, minutes: 20))) – "
                 + "\(displayTime(app.addMinutes(to: app.info.times[1], minutes: -10)))"
        }()
        let nightWindow: String = {
            guard app.info.times.indices.contains(4), app.info.times.indices.contains(0) else { return "—" }
            return "\(displayTime(app.info.times[4])) – \(displayTime(app.info.times[0]))"
        }()
        let finalThirdBest = lastThirdStart(using: app.info).map {
            "\(featureText("nawafil.qiyam.best")) · \(displayTime($0)) – \(displayTime(app.info.times[0]))"
        } ?? featureText("nawafil.qiyam.best")
        return [
            (featureText("nawafil.rawatib"), featureText("nawafil.rawatib.count"),
             featureText("nawafil.rawatib.window"), featureText("nawafil.rawatib.best"),
             "Jāmiʿ at-Tirmidhī 415"),
            (featureText("nawafil.duha"), featureText("nawafil.duha.count"),
             duhaWindow, featureText("nawafil.duha.best"), "Ṣaḥīḥ Muslim 720, 748b"),
            (featureText("nawafil.qiyam"), featureText("nawafil.qiyam.count"),
             nightWindow, finalThirdBest, "Ṣaḥīḥ al-Bukhārī 1145"),
            (featureText("nawafil.witr"), featureText("nawafil.witr.count"),
             nightWindow, featureText("nawafil.witr.best"), "Ṣaḥīḥ Muslim 752a"),
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
        let titleX: CGFloat = isRTL ? countWidth + 18 : 18
        let countX: CGFloat = isRTL ? 18 : frame.width - countWidth - 18
        content.addSubview(dashboardLabel(data.title,
            frame: NSRect(x: titleX, y: 12,
                          width: frame.width - countWidth - 54, height: 23),
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
        content.addSubview(dashboardLabel(data.source,
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
// MARK: Qur'an — verified Hafs/Warsh reader, study, and local reading state
// ============================================================================

/// Native shell around the King Fahd Complex's official, explicitly
/// embeddable Mushaf publications. The shell owns navigation and reading
/// state; canonical Qur'an content remains untouched at its official source.
final class QuranViewController: NSViewController, MainTabContent,
                                 WKNavigationDelegate, NSSearchFieldDelegate {
    private var editionControl: NSSegmentedControl!
    private var sourceLabel: NSTextField!
    private var searchField: NSSearchField!
    private var studyPopup: NSPopUpButton!
    private var webView: WKWebView!
    private var progress: NSProgressIndicator!
    private var backButton: HoverIconButton!
    private var forwardButton: HoverIconButton!
    private var bookmarkButton: HoverIconButton!
    private var removeBookmarkButton: HoverIconButton!
    private var unavailableOverlay: NSVisualEffectView!
    private var unavailableHint: NSTextField!
    private var fallbackButton: NSButton!
    private var loadWatchdog: Timer?

    private var edition: String {
        editionControl?.selectedSegment == 1 ? "warsh" : "hafs"
    }

    deinit { loadWatchdog?.invalidate() }

    override func loadView() {
        let root = NSView()
        let direction: NSUserInterfaceLayoutDirection = Localizer.shared.isRTL
            ? .rightToLeft : .leftToRight
        root.userInterfaceLayoutDirection = direction

        let controlBar = NSVisualEffectView()
        controlBar.material = .headerView
        controlBar.blendingMode = .withinWindow
        controlBar.state = .active
        controlBar.translatesAutoresizingMaskIntoConstraints = false
        controlBar.userInterfaceLayoutDirection = direction
        root.addSubview(controlBar)

        editionControl = NSSegmentedControl(
            labels: ["Hafs · حفص", "Warsh · ورش"],
            trackingMode: .selectOne, target: self,
            action: #selector(editionChanged(_:)))
        editionControl.segmentStyle = .texturedRounded
        editionControl.selectedSegment = (UserDefaults.standard.string(forKey: kQuranEditionKey)
                                           ?? "hafs") == "warsh" ? 1 : 0
        editionControl.userInterfaceLayoutDirection = direction
        editionControl.translatesAutoresizingMaskIntoConstraints = false
        editionControl.setAccessibilityLabel(featureText("quran.tab"))
        controlBar.addSubview(editionControl)

        sourceLabel = NSTextField(labelWithString: featureText("quran.source.kfgqpc"))
        sourceLabel.font = Localizer.shared.font(size: 11.5, weight: .medium)
        sourceLabel.textColor = .secondaryLabelColor
        sourceLabel.lineBreakMode = .byTruncatingTail
        sourceLabel.alignment = Localizer.shared.leadingAlignment
        sourceLabel.baseWritingDirection = Localizer.shared.isRTL ? .rightToLeft : .leftToRight
        sourceLabel.translatesAutoresizingMaskIntoConstraints = false
        controlBar.addSubview(sourceLabel)

        progress = NSProgressIndicator()
        progress.style = .spinning
        progress.controlSize = .small
        progress.isDisplayedWhenStopped = false
        progress.translatesAutoresizingMaskIntoConstraints = false
        controlBar.addSubview(progress)

        let sourceButton = HoverIconButton(symbol: "checkmark.shield.fill",
            toolTip: featureText("quran.provenance"), target: self,
            action: #selector(showProvenance), pointSize: 14,
            size: NSSize(width: 38, height: 30))
        sourceButton.translatesAutoresizingMaskIntoConstraints = false
        controlBar.addSubview(sourceButton)

        let moroccanButton = NSButton(title: featureText("quran.official_moroccan"),
                                      target: self,
                                      action: #selector(openMoroccanMushaf))
        moroccanButton.bezelStyle = .rounded
        moroccanButton.image = templateSymbol("safari.fill", pointSize: 12)
        moroccanButton.imagePosition = Localizer.shared.isRTL ? .imageRight : .imageLeft
        moroccanButton.toolTip = featureText("quran.official_moroccan.help")
        moroccanButton.translatesAutoresizingMaskIntoConstraints = false
        controlBar.addSubview(moroccanButton)

        backButton = HoverIconButton(symbol: backChevronSymbol,
            toolTip: t("tooltip.back"), target: self,
            action: #selector(goBack), pointSize: 13,
            size: NSSize(width: 34, height: 28))
        forwardButton = HoverIconButton(symbol: Localizer.shared.isRTL
                                            ? "chevron.left" : "chevron.right",
            toolTip: featureText("quran.forward"), target: self,
            action: #selector(goForward), pointSize: 13,
            size: NSSize(width: 34, height: 28))
        let reloadButton = HoverIconButton(symbol: "arrow.clockwise",
            toolTip: t("tooltip.refresh"), target: self,
            action: #selector(reloadReader), pointSize: 13,
            size: NSSize(width: 34, height: 28))
        for button in [backButton!, forwardButton!, reloadButton] {
            button.translatesAutoresizingMaskIntoConstraints = false
            controlBar.addSubview(button)
        }

        searchField = NSSearchField()
        searchField.placeholderString = featureText("quran.search.placeholder")
        searchField.font = Localizer.shared.font(size: 12.5)
        searchField.target = self
        searchField.action = #selector(runStudySearch)
        searchField.delegate = self
        searchField.userInterfaceLayoutDirection = direction
        searchField.translatesAutoresizingMaskIntoConstraints = false
        controlBar.addSubview(searchField)

        studyPopup = NSPopUpButton(frame: .zero, pullsDown: false)
        studyPopup.addItems(withTitles: [featureText("quran.study.search"),
                                         featureText("quran.study.tafsir"),
                                         featureText("quran.study.official_source")])
        studyPopup.target = self
        studyPopup.action = #selector(studyModeChanged(_:))
        studyPopup.userInterfaceLayoutDirection = direction
        studyPopup.translatesAutoresizingMaskIntoConstraints = false
        controlBar.addSubview(studyPopup)

        bookmarkButton = HoverIconButton(symbol: "bookmark.fill",
            toolTip: featureText("quran.bookmarks"), target: self,
            action: #selector(showBookmarks(_:)), pointSize: 13,
            size: NSSize(width: 36, height: 28))
        let addBookmarkButton = HoverIconButton(symbol: "bookmark.badge.plus",
            toolTip: featureText("quran.bookmark.add"), target: self,
            action: #selector(addBookmark), pointSize: 13,
            size: NSSize(width: 36, height: 28))
        removeBookmarkButton = HoverIconButton(symbol: "bookmark.slash",
            toolTip: featureText("quran.bookmark.remove"), target: self,
            action: #selector(removeCurrentBookmark), pointSize: 13,
            size: NSSize(width: 36, height: 28))
        for button in [bookmarkButton!, addBookmarkButton, removeBookmarkButton!] {
            button.translatesAutoresizingMaskIntoConstraints = false
            controlBar.addSubview(button)
        }

        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .default()
        webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = self
        webView.allowsMagnification = true
        webView.translatesAutoresizingMaskIntoConstraints = false
        webView.setAccessibilityLabel(featureText("quran.reader"))
        root.addSubview(webView)

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
        unavailableOverlay.translatesAutoresizingMaskIntoConstraints = false
        unavailableOverlay.isHidden = true
        unavailableOverlay.setAccessibilityElement(true)
        unavailableOverlay.setAccessibilityRole(.group)
        unavailableOverlay.setAccessibilityLabel(featureText("quran.unavailable"))
        root.addSubview(unavailableOverlay)

        let unavailableTitle = NSTextField(labelWithString: featureText("quran.unavailable"))
        unavailableTitle.font = Localizer.shared.font(size: 20, weight: .semibold)
        unavailableTitle.alignment = .center
        unavailableTitle.translatesAutoresizingMaskIntoConstraints = false

        unavailableHint = NSTextField(wrappingLabelWithString: featureText("quran.study.hafs_only"))
        unavailableHint.font = Localizer.shared.font(size: 12.5)
        unavailableHint.textColor = .secondaryLabelColor
        unavailableHint.alignment = .center
        unavailableHint.maximumNumberOfLines = 3
        unavailableHint.translatesAutoresizingMaskIntoConstraints = false

        let retryButton = NSButton(title: t("tooltip.refresh"), target: self,
                                   action: #selector(retryOfficialReader))
        retryButton.bezelStyle = .rounded
        let officialButton = NSButton(title: featureText("quran.provenance.open"),
                                      target: self,
                                      action: #selector(openOfficialReaderExternally))
        officialButton.bezelStyle = .rounded
        fallbackButton = NSButton(title: featureText("quran.source.foundation"),
                                  target: self,
                                  action: #selector(openReaderFallback))
        fallbackButton.bezelStyle = .rounded
        fallbackButton.keyEquivalent = "\r"

        let unavailableActions = NSStackView(views: [retryButton, officialButton,
                                                      fallbackButton])
        unavailableActions.orientation = .horizontal
        unavailableActions.alignment = .centerY
        unavailableActions.distribution = .fillEqually
        unavailableActions.spacing = 8
        unavailableActions.userInterfaceLayoutDirection = direction
        unavailableActions.translatesAutoresizingMaskIntoConstraints = false

        let unavailableStack = NSStackView(views: [unavailableTitle, unavailableHint,
                                                    unavailableActions])
        unavailableStack.orientation = .vertical
        unavailableStack.alignment = .centerX
        unavailableStack.spacing = 14
        unavailableStack.edgeInsets = NSEdgeInsets(top: 22, left: 22,
                                                    bottom: 22, right: 22)
        unavailableStack.userInterfaceLayoutDirection = direction
        unavailableStack.translatesAutoresizingMaskIntoConstraints = false
        unavailableOverlay.addSubview(unavailableStack)

        NSLayoutConstraint.activate([
            controlBar.leadingAnchor.constraint(equalTo: root.leadingAnchor),
            controlBar.trailingAnchor.constraint(equalTo: root.trailingAnchor),
            controlBar.topAnchor.constraint(equalTo: root.topAnchor),
            controlBar.heightAnchor.constraint(equalToConstant: 94),

            editionControl.leadingAnchor.constraint(equalTo: controlBar.leadingAnchor,
                                                     constant: 20),
            editionControl.topAnchor.constraint(equalTo: controlBar.topAnchor, constant: 12),
            editionControl.widthAnchor.constraint(equalToConstant: 260),
            editionControl.heightAnchor.constraint(equalToConstant: 28),

            sourceLabel.leadingAnchor.constraint(equalTo: editionControl.trailingAnchor,
                                                  constant: 12),
            sourceLabel.centerYAnchor.constraint(equalTo: editionControl.centerYAnchor),
            progress.leadingAnchor.constraint(equalTo: sourceLabel.trailingAnchor, constant: 7),
            progress.centerYAnchor.constraint(equalTo: sourceLabel.centerYAnchor),
            progress.widthAnchor.constraint(equalToConstant: 16),
            progress.heightAnchor.constraint(equalToConstant: 16),

            sourceButton.trailingAnchor.constraint(equalTo: moroccanButton.leadingAnchor,
                                                     constant: -8),
            sourceButton.centerYAnchor.constraint(equalTo: editionControl.centerYAnchor),
            sourceButton.widthAnchor.constraint(equalToConstant: 38),
            sourceButton.heightAnchor.constraint(equalToConstant: 30),
            moroccanButton.trailingAnchor.constraint(equalTo: controlBar.trailingAnchor,
                                                      constant: -20),
            moroccanButton.centerYAnchor.constraint(equalTo: editionControl.centerYAnchor),
            moroccanButton.widthAnchor.constraint(equalToConstant: 180),
            sourceLabel.trailingAnchor.constraint(lessThanOrEqualTo: sourceButton.leadingAnchor,
                                                   constant: -8),

            backButton.leadingAnchor.constraint(equalTo: controlBar.leadingAnchor, constant: 20),
            backButton.topAnchor.constraint(equalTo: controlBar.topAnchor, constant: 54),
            backButton.widthAnchor.constraint(equalToConstant: 34),
            backButton.heightAnchor.constraint(equalToConstant: 28),
            forwardButton.leadingAnchor.constraint(equalTo: backButton.trailingAnchor, constant: 2),
            forwardButton.centerYAnchor.constraint(equalTo: backButton.centerYAnchor),
            forwardButton.widthAnchor.constraint(equalToConstant: 34),
            forwardButton.heightAnchor.constraint(equalToConstant: 28),
            reloadButton.leadingAnchor.constraint(equalTo: forwardButton.trailingAnchor, constant: 2),
            reloadButton.centerYAnchor.constraint(equalTo: backButton.centerYAnchor),
            reloadButton.widthAnchor.constraint(equalToConstant: 34),
            reloadButton.heightAnchor.constraint(equalToConstant: 28),

            searchField.leadingAnchor.constraint(equalTo: reloadButton.trailingAnchor, constant: 10),
            searchField.centerYAnchor.constraint(equalTo: backButton.centerYAnchor),
            searchField.heightAnchor.constraint(equalToConstant: 28),
            studyPopup.leadingAnchor.constraint(equalTo: searchField.trailingAnchor, constant: 8),
            studyPopup.centerYAnchor.constraint(equalTo: backButton.centerYAnchor),
            studyPopup.widthAnchor.constraint(equalToConstant: 190),
            studyPopup.heightAnchor.constraint(equalToConstant: 28),
            bookmarkButton.leadingAnchor.constraint(equalTo: studyPopup.trailingAnchor, constant: 8),
            bookmarkButton.centerYAnchor.constraint(equalTo: backButton.centerYAnchor),
            bookmarkButton.widthAnchor.constraint(equalToConstant: 36),
            bookmarkButton.heightAnchor.constraint(equalToConstant: 28),
            addBookmarkButton.leadingAnchor.constraint(equalTo: bookmarkButton.trailingAnchor,
                                                        constant: 2),
            addBookmarkButton.centerYAnchor.constraint(equalTo: backButton.centerYAnchor),
            addBookmarkButton.widthAnchor.constraint(equalToConstant: 36),
            addBookmarkButton.heightAnchor.constraint(equalToConstant: 28),
            removeBookmarkButton.leadingAnchor.constraint(equalTo: addBookmarkButton.trailingAnchor,
                                                           constant: 2),
            removeBookmarkButton.trailingAnchor.constraint(equalTo: controlBar.trailingAnchor,
                                                            constant: -20),
            removeBookmarkButton.centerYAnchor.constraint(equalTo: backButton.centerYAnchor),
            removeBookmarkButton.widthAnchor.constraint(equalToConstant: 36),
            removeBookmarkButton.heightAnchor.constraint(equalToConstant: 28),

            separator.leadingAnchor.constraint(equalTo: root.leadingAnchor),
            separator.trailingAnchor.constraint(equalTo: root.trailingAnchor),
            separator.topAnchor.constraint(equalTo: controlBar.bottomAnchor),
            separator.heightAnchor.constraint(equalToConstant: 1),
            webView.leadingAnchor.constraint(equalTo: root.leadingAnchor),
            webView.trailingAnchor.constraint(equalTo: root.trailingAnchor),
            webView.topAnchor.constraint(equalTo: separator.bottomAnchor),
            webView.bottomAnchor.constraint(equalTo: root.bottomAnchor),

            unavailableOverlay.centerXAnchor.constraint(equalTo: webView.centerXAnchor),
            unavailableOverlay.centerYAnchor.constraint(equalTo: webView.centerYAnchor),
            unavailableOverlay.widthAnchor.constraint(equalToConstant: 580),
            unavailableOverlay.leadingAnchor.constraint(greaterThanOrEqualTo: webView.leadingAnchor,
                                                         constant: 30),
            unavailableOverlay.trailingAnchor.constraint(lessThanOrEqualTo: webView.trailingAnchor,
                                                          constant: -30),
            unavailableStack.leadingAnchor.constraint(equalTo: unavailableOverlay.leadingAnchor),
            unavailableStack.trailingAnchor.constraint(equalTo: unavailableOverlay.trailingAnchor),
            unavailableStack.topAnchor.constraint(equalTo: unavailableOverlay.topAnchor),
            unavailableStack.bottomAnchor.constraint(equalTo: unavailableOverlay.bottomAnchor),
            unavailableHint.widthAnchor.constraint(lessThanOrEqualToConstant: 500),
            unavailableActions.widthAnchor.constraint(equalToConstant: 520),
        ])

        view = root
        loadEdition(resume: true)
    }

    func tabDidActivate() {
        if webView?.url == nil { loadEdition(resume: true) }
        updateNavigationState()
    }

    private func officialReaderURL(for edition: String) -> String {
        edition == "warsh" ? kQuranWarshReaderURL : kQuranHafsReaderURL
    }

    private func lastURLKey(for edition: String) -> String {
        edition == "warsh" ? kQuranLastWarshURL : kQuranLastHafsURL
    }

    private func loadEdition(resume: Bool) {
        UserDefaults.standard.set(edition, forKey: kQuranEditionKey)
        var raw = officialReaderURL(for: edition)
        if resume, let saved = UserDefaults.standard.string(forKey: lastURLKey(for: edition)),
           isAllowedReaderURL(saved), saved.contains("qurancomplex.gov.sa") {
            raw = saved
        }
        guard let url = URL(string: raw) else { return }
        sourceLabel.stringValue = featureText("quran.source.kfgqpc")
        webView.load(URLRequest(url: url,
                                cachePolicy: .returnCacheDataElseLoad,
                                timeoutInterval: 30))
    }

    private func isAllowedReaderURL(_ raw: String) -> Bool {
        guard let host = URL(string: raw)?.host?.lowercased() else { return false }
        return host == "qurancomplex.gov.sa"
            || host.hasSuffix(".qurancomplex.gov.sa")
            || host == "quran.com" || host.hasSuffix(".quran.com")
    }

    @objc private func editionChanged(_ sender: NSSegmentedControl) {
        loadEdition(resume: true)
    }

    @objc private func goBack() { if webView.canGoBack { webView.goBack() } }
    @objc private func goForward() { if webView.canGoForward { webView.goForward() } }
    @objc private func reloadReader() {
        if unavailableOverlay?.isHidden == false {
            retryOfficialReader()
        } else {
            webView.reload()
        }
    }

    private func scheduleLoadWatchdog() {
        loadWatchdog?.invalidate()
        let timer = Timer(timeInterval: 12, repeats: false) { [weak self] _ in
            self?.showUnavailableReader()
        }
        RunLoop.main.add(timer, forMode: .common)
        loadWatchdog = timer
    }

    private func cancelLoadWatchdog() {
        loadWatchdog?.invalidate()
        loadWatchdog = nil
    }

    private func showUnavailableReader() {
        progress?.stopAnimation(nil)
        sourceLabel?.stringValue = featureText("quran.unavailable")
        let isWarsh = edition == "warsh"
        unavailableHint?.stringValue = isWarsh
            ? featureText("quran.official_moroccan.help")
            : featureText("quran.study.hafs_only")
        fallbackButton?.title = isWarsh
            ? featureText("quran.official_moroccan")
            : featureText("quran.source.foundation")
        unavailableOverlay?.isHidden = false
    }

    @objc private func retryOfficialReader() {
        cancelLoadWatchdog()
        unavailableOverlay?.isHidden = true
        loadEdition(resume: false)
    }

    @objc private func openOfficialReaderExternally() {
        guard let url = URL(string: officialReaderURL(for: edition)) else { return }
        NSWorkspace.shared.open(url)
    }

    @objc private func openReaderFallback() {
        if edition == "warsh" {
            openMoroccanMushaf()
            return
        }
        guard let url = URL(string: "https://quran.com/1") else { return }
        unavailableOverlay?.isHidden = true
        sourceLabel.stringValue = featureText("quran.source.foundation")
        webView.load(URLRequest(url: url, timeoutInterval: 30))
    }

    @objc private func studyModeChanged(_ sender: NSPopUpButton) {
        searchField.placeholderString = sender.indexOfSelectedItem == 1
            ? featureText("quran.tafsir.placeholder")
            : featureText("quran.search.placeholder")
        if sender.indexOfSelectedItem == 2 {
            webView.load(URLRequest(url: URL(string: kQuranDeveloperURL)!))
            sourceLabel.stringValue = featureText("quran.source.kfgqpc.developer")
        }
    }

    @objc private func runStudySearch() {
        let query = searchField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return }
        if studyPopup.indexOfSelectedItem == 2 {
            webView.load(URLRequest(url: URL(string: kQuranDeveloperURL)!))
            return
        }
        let isReference = query.range(of: #"^\d{1,3}:\d{1,3}$"#,
                                      options: .regularExpression) != nil
        let url: URL?
        if studyPopup.indexOfSelectedItem == 1, isReference {
            url = URL(string: "https://quran.com/\(query)/tafsirs")
        } else if isReference {
            url = URL(string: "https://quran.com/\(query)")
        } else {
            var components = URLComponents(string: "https://quran.com/search")
            components?.queryItems = [URLQueryItem(name: "q", value: query)]
            url = components?.url
        }
        guard let url else { return }
        webView.load(URLRequest(url: url))
        sourceLabel.stringValue = edition == "warsh"
            ? featureText("quran.study.hafs_only")
            : featureText("quran.source.foundation")
    }

    private func loadBookmarks() -> [QuranBookmark] {
        guard let data = UserDefaults.standard.data(forKey: kQuranBookmarksKey),
              let values = try? JSONDecoder().decode([QuranBookmark].self, from: data) else {
            return []
        }
        return values
    }

    private func saveBookmarks(_ values: [QuranBookmark]) {
        guard let data = try? JSONEncoder().encode(values) else { return }
        UserDefaults.standard.set(data, forKey: kQuranBookmarksKey)
    }

    @objc private func addBookmark() {
        guard let url = webView.url, isAllowedReaderURL(url.absoluteString) else { return }
        let alert = NSAlert()
        alert.messageText = featureText("quran.bookmark.add")
        alert.informativeText = featureText("quran.bookmark.name.help")
        alert.addButton(withTitle: t("settings.save"))
        alert.addButton(withTitle: t("adhkar.editor.cancel"))
        let field = NSTextField(frame: NSRect(x: 0, y: 0, width: 320, height: 24))
        field.stringValue = webView.title?.trimmingCharacters(in: .whitespacesAndNewlines)
            .nonEmpty ?? (edition == "warsh" ? "Warsh · ورش" : "Hafs · حفص")
        alert.accessoryView = field
        guard alert.runModal() == .alertFirstButtonReturn else { return }
        let title = field.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        var values = loadBookmarks()
        if let existing = values.firstIndex(where: { $0.url == url.absoluteString }) {
            values[existing].title = title.nonEmpty ?? values[existing].title
        } else {
            values.append(QuranBookmark(title: title.nonEmpty ?? featureText("quran.bookmark"),
                                        url: url.absoluteString, edition: edition))
        }
        saveBookmarks(values)
        updateNavigationState()
    }

    @objc private func showBookmarks(_ sender: NSButton) {
        let menu = NSMenu()
        let values = loadBookmarks()
        if values.isEmpty {
            let empty = NSMenuItem(title: featureText("quran.bookmarks.empty"),
                                   action: nil, keyEquivalent: "")
            empty.isEnabled = false
            menu.addItem(empty)
        } else {
            for (index, bookmark) in values.enumerated() {
                let item = NSMenuItem(title: bookmark.title,
                                      action: #selector(openBookmark(_:)),
                                      keyEquivalent: "")
                item.tag = index
                item.image = templateSymbol(bookmark.edition == "warsh"
                                                ? "book.closed.fill" : "book.fill",
                                             pointSize: 11)
                menu.addItem(item)
            }
        }
        menu.popUp(positioning: nil, at: NSPoint(x: 0, y: sender.bounds.height + 4),
                   in: sender)
    }

    @objc private func openBookmark(_ sender: NSMenuItem) {
        let values = loadBookmarks()
        guard values.indices.contains(sender.tag),
              let url = URL(string: values[sender.tag].url),
              isAllowedReaderURL(url.absoluteString) else { return }
        editionControl.selectedSegment = values[sender.tag].edition == "warsh" ? 1 : 0
        UserDefaults.standard.set(values[sender.tag].edition, forKey: kQuranEditionKey)
        webView.load(URLRequest(url: url))
    }

    @objc private func removeCurrentBookmark() {
        guard let raw = webView.url?.absoluteString else { return }
        var values = loadBookmarks()
        values.removeAll { $0.url == raw }
        saveBookmarks(values)
        updateNavigationState()
    }

    @objc private func showProvenance() {
        let alert = NSAlert()
        alert.messageText = featureText("quran.provenance.title")
        alert.informativeText = featureText("quran.provenance.detail")
            + "\n\nHafs v13 · SHA-1 36EA5AB0D7EA1702F17FF43F9B50924CCCD77EBF"
            + "\nWarsh v6 · SHA-1 44ECEA8FEB23817FDC01A8EE2162A6A0CF08CAE7"
            + "\nTafsir Muyassar v3 · SHA-1 5F533113C2F54F32EDED734BB49E6A5837965722"
        alert.addButton(withTitle: featureText("quran.provenance.open"))
        alert.addButton(withTitle: t("adhkar.editor.cancel"))
        if alert.runModal() == .alertFirstButtonReturn,
           let url = URL(string: kQuranDeveloperURL) {
            NSWorkspace.shared.open(url)
        }
    }

    @objc private func openMoroccanMushaf() {
        guard let url = URL(string: kMoroccanMushafURL) else { return }
        NSWorkspace.shared.open(url)
    }

    private func updateNavigationState() {
        backButton?.isEnabled = webView?.canGoBack ?? false
        forwardButton?.isEnabled = webView?.canGoForward ?? false
        let current = webView?.url?.absoluteString
        removeBookmarkButton?.isEnabled = current.map { raw in
            loadBookmarks().contains { $0.url == raw }
        } ?? false
    }

    func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
        unavailableOverlay?.isHidden = true
        progress.startAnimation(nil)
        scheduleLoadWatchdog()
        updateNavigationState()
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        cancelLoadWatchdog()
        unavailableOverlay?.isHidden = true
        progress.stopAnimation(nil)
        if let raw = webView.url?.absoluteString, raw.contains("qurancomplex.gov.sa") {
            UserDefaults.standard.set(raw, forKey: lastURLKey(for: edition))
            sourceLabel.stringValue = featureText("quran.source.kfgqpc")
        } else if webView.url?.host?.contains("quran.com") == true {
            sourceLabel.stringValue = edition == "warsh"
                ? featureText("quran.study.hafs_only")
                : featureText("quran.source.foundation")
        }
        updateNavigationState()
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!,
                 withError error: Error) {
        let nsError = error as NSError
        if nsError.domain == NSURLErrorDomain && nsError.code == NSURLErrorCancelled { return }
        cancelLoadWatchdog()
        showUnavailableReader()
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!,
                 withError error: Error) {
        let nsError = error as NSError
        if nsError.domain == NSURLErrorDomain && nsError.code == NSURLErrorCancelled { return }
        cancelLoadWatchdog()
        showUnavailableReader()
    }

    func webView(_ webView: WKWebView,
                 decidePolicyFor navigationAction: WKNavigationAction,
                 decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        guard let url = navigationAction.request.url else {
            decisionHandler(.cancel)
            return
        }
        if isAllowedReaderURL(url.absoluteString) || url.scheme == "about" {
            decisionHandler(.allow)
        } else if navigationAction.navigationType == .linkActivated {
            NSWorkspace.shared.open(url)
            decisionHandler(.cancel)
        } else {
            decisionHandler(.cancel)
        }
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
    private var selectedSection = 0

    private var languagePopup: NSPopUpButton!
    private var appearanceSeg: NSSegmentedControl!
    private var materialSeg: NSSegmentedControl!
    private var timeFormatSeg: NSSegmentedControl!
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

    init(initialSection: Int = 0) {
        selectedSection = max(0, min(3, initialSection))
        super.init(nibName: nil, bundle: nil)
    }
    required init?(coder: NSCoder) { fatalError() }

    func selectSection(_ section: Int) {
        selectedSection = max(0, min(3, section))
        guard isViewLoaded else { return }
        sectionControl.selectedSegment = selectedSection
        rebuildSelectedSection()
        tabDidActivate()
    }

    override func loadView() {
        let root = NSView()
        root.userInterfaceLayoutDirection = Localizer.shared.isRTL ? .rightToLeft : .leftToRight
        sectionControl = NSSegmentedControl()
        sectionControl.segmentCount = 4
        sectionControl.setLabel(featureText("settings.general"), forSegment: 0)
        sectionControl.setLabel(t("settings.section.menu_bar"), forSegment: 1)
        sectionControl.setLabel(t("settings.section.adhan"), forSegment: 2)
        sectionControl.setLabel(t("settings.section.adhkar"), forSegment: 3)
        sectionControl.segmentStyle = .texturedRounded
        sectionControl.userInterfaceLayoutDirection = root.userInterfaceLayoutDirection
        sectionControl.selectedSegment = selectedSection
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

    private func rebuildSelectedSection() {
        accentSwatches.removeAll()
        let body = FlippedView(frame: NSRect(x: 0, y: 0, width: 960, height: 620))
        settingsScrollView.documentView = body
        buildContent(into: body)
        body.needsDisplay = true
    }

    @objc private func settingsSectionChanged(_ sender: NSSegmentedControl) {
        selectedSection = max(0, sender.selectedSegment)
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
            label.frame = NSRect(x: cardX + 4, y: y, width: cardW - 8, height: 24)
            body.addSubview(label)
            y += 26
            if let subtitle = subtitle {
                let detail = NSTextField(wrappingLabelWithString: subtitle)
                detail.font = Localizer.shared.font(size: 11)
                detail.textColor = .secondaryLabelColor
                detail.alignment = isRTL ? .right : .left
                detail.baseWritingDirection = isRTL ? .rightToLeft : .leftToRight
                detail.frame = NSRect(x: cardX + 4, y: y, width: cardW - 8, height: 30)
                body.addSubview(detail)
                y += 34
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
                label.frame = NSRect(x: labelX, y: rowY + 12,
                                     width: labelW, height: 20)
                card.addSubview(label)
            }
            let x = text.isEmpty ? 14 : controlX
            let w = text.isEmpty ? cardW - 28 : controlW
            control.frame = NSRect(x: x, y: rowY + 8, width: w, height: 28)
            card.addSubview(control)
            rowY += rowH
        }

        func endCard(_ height: CGFloat) { y += height + 30 }

        if selectedSection == 0 {
            // General settings are deliberately shared by prayer times,
            // Adhan, and Adhkar. There is one language and one visual system
            // everywhere.
            sectionHeader(t("settings.tab.appearance"),
                          subtitle: t("adhkar.editor.title") + " · Salat Time")
            let (generalCard, generalH) = beginCard(rows: 7)

        languagePopup = NSPopUpButton(frame: .zero, pullsDown: false)
        kSupportedLanguages.forEach { languagePopup.addItem(withTitle: $0.nativeName) }
        languagePopup.selectItem(at: kSupportedLanguages.firstIndex(where: {
            $0.code == Localizer.shared.current.code
        }) ?? 0)
        languagePopup.target = self
        languagePopup.action = #selector(languageChanged(_:))
        addRow(generalCard, label: t("settings.section.language"), control: languagePopup)

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

        openAtLoginCheck = NSButton(checkboxWithTitle: t("settings.startup.open_at_login"),
                                    target: self, action: #selector(openAtLoginChanged(_:)))
        openAtLoginCheck.state = isOpenAtLoginEnabled() ? .on : .off
        addRow(generalCard, label: t("settings.section.startup"), control: openAtLoginCheck)

        let mosqueButton = NSButton(title: t("settings.mosque.change"), target: self,
                                    action: #selector(changeMosque(_:)))
        mosqueButton.bezelStyle = .rounded
        addRow(generalCard, label: t("settings.section.mosque"), control: mosqueButton)
            endCard(generalH)
        }

        if selectedSection == 1 {
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

        if selectedSection == 2 {
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
                : String(format: t("settings.notif.headsup.minutes"), minutes))
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

        if selectedSection == 3 {
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
                : String(format: featureText("adhkar.after_adhan.minutes"), minutes)
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
    @objc private func openAtLoginChanged(_ sender: NSButton) {
        if !setOpenAtLogin(sender.state == .on) {
            sender.state = isOpenAtLoginEnabled() ? .on : .off
        }
    }
    @objc private func changeMosque(_ sender: NSButton) {
        (view.window as? MainWindow)?.showMosquePickerFromSettings()
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
        countField = NSTextField(labelWithString: String(format: t("adhkar.editor.count_times"),
                                                          countStepper.integerValue))
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
        countField.stringValue = String(format: t("adhkar.editor.count_times"),
                                         countStepper.integerValue)
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
    /// "Open mosque page" link button in the header — one tap jumps to the
    /// desktop mawaqit.net page for the currently-selected mosque.
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
        openSettingsWindow(section: 0)
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

    func openSettingsWindow(section: Int) {
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
        popover?.performClose(nil)
        if mainWindow == nil {
            let window = MainWindow(appDelegate: self)
            window.setAdhan(PrayerDashboardViewController(appDelegate: self))
            window.setEditor(AdhkarEditorViewController(appDelegate: self))
            window.setQuran(QuranViewController())
            mainWindow = window
        }
        mainWindow?.showMainWindow()
        mainWindow?.showMosquePickerFromSettings()
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
        headerBG.addSubview(nameLabel)

        // Address (up to 2 lines).
        addressLabel = NSTextField(labelWithString: "")
        addressLabel.frame = NSRect(x: 68, y: 34, width: W - 124, height: 26)
        addressLabel.font = Localizer.shared.font(size: 10)
        addressLabel.textColor = NSColor(white: 1.0, alpha: 0.85)
        addressLabel.drawsBackground = false
        addressLabel.maximumNumberOfLines = 2
        addressLabel.lineBreakMode = .byTruncatingTail
        addressLabel.alignment = .left
        headerBG.addSubview(addressLabel)

        // Mosque-page link button — top-right of the header, white tinted
        // so it reads against the accent strip. Opens the *desktop* mawaqit
        // URL for the currently-selected mosque in the user's default
        // browser. Sized and positioned to align visually with the icon.
        headerLinkBtn = NSButton(frame: NSRect(x: W - 44, y: 20, width: 32, height: 32))
        headerLinkBtn.bezelStyle = .regularSquare
        headerLinkBtn.isBordered = false
        headerLinkBtn.title = ""
        headerLinkBtn.imagePosition = .imageOnly
        headerLinkBtn.imageScaling = .scaleProportionallyDown
        headerLinkBtn.focusRingType = .none
        headerLinkBtn.setButtonType(.momentaryChange)
        if let sym = templateSymbol("arrow.up.right.square.fill",
                                    pointSize: 20, weight: .semibold) {
            headerLinkBtn.image = sym
        }
        headerLinkBtn.contentTintColor = NSColor(white: 1.0, alpha: 0.95)
        headerLinkBtn.toolTip = t("header.openMosque")
        headerLinkBtn.target = self
        headerLinkBtn.action = #selector(openCurrentMosquePageTapped)
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
        content.addSubview(jumuaLbl)

        // Hijri — top-right. Right-aligned so it hugs the right wall of the strip.
        hijriLbl = NSTextField(labelWithString: "")
        hijriLbl.frame = NSRect(x: rightColX, y: topRowY, width: rightColW, height: 22)
        hijriLbl.font = Localizer.shared.font(size: 12, weight: .medium)
        hijriLbl.textColor = .labelColor
        hijriLbl.drawsBackground = false
        hijriLbl.alignment = .right
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
        openSettingsWindow(section: isCompactAdhkarMode ? 3 : 2)
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

    /// Open the currently-selected mosque's page on mawaqit.net in the
    /// user's default browser. Uses `desktopMawaqitURL` to strip the `/m/`
    /// mobile prefix so the user lands on the full-site page with
    /// navigation, donation, and mosque-info sections.
    @objc func openCurrentMosquePageTapped() {
        let raw = currentMosqueURL().trimmingCharacters(in: .whitespacesAndNewlines)
        guard !raw.isEmpty else { return }
        let desktop = desktopMawaqitURL(raw)
        if let url = URL(string: desktop) {
            NSWorkspace.shared.open(url)
        }
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
            addressLabel.isHidden = addr.isEmpty
        }

        // Header link button — only enabled when we actually have a mosque
        // URL to open. Keeps the icon visible but dimmed otherwise so the
        // user doesn't wonder why their click does nothing.
        if headerLinkBtn != nil {
            let hasURL = !currentMosqueURL().trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            headerLinkBtn.isHidden = isCompactAdhkarMode
            headerLinkBtn.isEnabled = hasURL
            headerLinkBtn.alphaValue = hasURL ? 1.0 : 0.4
        }

        // Gregorian date in the current UI language. Format mirrors the
        // Hijri "d MMMM yyyy" layout so the two dates read as a pair.
        if gregorianLbl != nil {
            let fmt = DateFormatter()
            fmt.locale = Locale(identifier: Localizer.shared.current.code)
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
            let redCountdown = String(format: "%02d:%02d", mm, ss)
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
                countdownLbl.stringValue = String(format: "%02d:%02d:%02d", hh, m, s)
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
            let countdown: String = (diff >= 3600)
                ? String(format: "%d:%02d:%02d", h, m, s)
                : String(format: "%02d:%02d", m, s)

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
                countdownLbl.stringValue = String(format: "%02d:%02d:%02d", h, m, s)
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
        content.title = String(format: titleFmt,
                               prayer as NSString,
                               minutes)
        content.body = info.name.isEmpty
            ? "\(prayer) · \(time)"
            : "\(info.name) · \(time)"
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
