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

let kAppVersion          = "3.5.0-beta.1"

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
    /// "manual" (no schedule) | "shuruq" | "fajr" | "dhuhr" | "asr" | "maghrib" | "isha"
    var anchorKind: String
    /// When true, the collection auto-recites at `anchorKind` time once/day.
    var autoPlay:   Bool
    var items:      [AdhkarEntry]
    init(id: UUID = UUID(), name: String, anchorKind: String = "manual",
         autoPlay: Bool = false, items: [AdhkarEntry] = []) {
        self.id = id; self.name = name; self.anchorKind = anchorKind
        self.autoPlay = autoPlay; self.items = items
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
        existing.append(AdhkarCollection(name: name, anchorKind: anchor,
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
        seeded.append(AdhkarCollection(name: set.arabicName, anchorKind: anchor,
                                       autoPlay: plays, items: items))
    }
    AdhkarLibrary.save(seeded)
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
final class AdhkarSession: NSObject, AVAudioPlayerDelegate {

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
        start(collection: AdhkarCollection(name: set.rawValue, items: entries))
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
        isPlaying = false
        isPaused  = true
        onPlaybackStateChange?()
    }

    func resume() {
        guard isPaused else { return }
        if player?.play() ?? false {
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
        player?.volume = m ? 0 : 1.0
        onPlaybackStateChange?()
    }

    /// Hard stop — abandons the session and releases the player.
    func stop() {
        player?.stop()
        player = nil
        items = []
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
        playAudioRef(item.audioRef)
    }

    /// Resolve a logical audioRef to a URL and start playback. Handles both
    /// bundled ("bundled:75.mp3") and imported ("imported:abc.mp3") refs via
    /// resolveAdhkarAudio(). Falls back to auto-advance if audio is missing.
    private func playAudioRef(_ ref: String) {
        player?.stop()
        // If the entry has no audio at all, just advance after a beat.
        guard !ref.isEmpty else {
            scheduleAutoAdvance()
            return
        }
        guard let url = resolveAdhkarAudio(ref),
              FileManager.default.fileExists(atPath: url.path),
              let p = try? AVAudioPlayer(contentsOf: url) else {
            scheduleAutoAdvance()
            return
        }
        player = p
        p.delegate = self
        p.volume = isMuted ? 0 : 1.0
        p.prepareToPlay()
        if p.play() {
            isPlaying = true
            isPaused  = false
            onPlaybackStateChange?()
        }
    }

    /// If audio is missing, auto-advance after a beat so the session never
    /// stalls on a single broken/silent entry.
    private func scheduleAutoAdvance() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            guard let self = self else { return }
            let dummy = AVAudioPlayer()
            self.audioPlayerDidFinishPlaying(dummy, successfully: true)
        }
    }

    private func finish() {
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
        playsSoFar += 1
        if playsSoFar < targetPlays {
            // Same item, repeat.
            if items.indices.contains(index) {
                playAudioRef(items[index].audioRef)
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

    // UI elements
    private var titleLabel:    NSTextField!
    private var positionLabel: NSTextField!       // "3 of 25"
    private var arabicLabel:   NSTextField!       // the dhikr (large, RTL)
    private var countLabel:    NSTextField!       // "تُقرأ 3 مرات"
    private var virtueLabel:   NSTextField!      // virtue / hadith source
    private var playBtn:       HoverIconButton!
    private var muteBtn:       HoverIconButton!
    private var container:     NSView!            // everything sits in here

    private let panelWidth:  CGFloat = 440
    private let panelHeight: CGFloat = 580

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
        titleLabel.stringValue = (set == .morning)
            ? t("adhkar.morning_title")
            : t("adhkar.evening_title")
        centerOnActiveScreen()
        makeKeyAndOrderFront(nil)
        if autoPlay {
            // Try to play from the user's matching collection first; fall back
            // to the bundled set if no user collection exists.
            if let c = matchingUserCollection(for: set) {
                session.start(collection: c)
            } else {
                session.start(set: set)
            }
        }
    }

    /// v3 entry point — present a specific user-edited collection.
    func present(collection: AdhkarCollection, autoPlay: Bool = true) {
        titleLabel.stringValue = collection.name
        centerOnActiveScreen()
        makeKeyAndOrderFront(nil)
        if autoPlay { session.start(collection: collection) }
    }

    /// Find the user's first collection whose name matches the set's localized
    /// title (so the right-click "Adhkar of the Morning" plays the user's
    /// "Morning" collection, including any edits they've made).
    private func matchingUserCollection(for set: AdhkarSet) -> AdhkarCollection? {
        let target = (set == .morning)
            ? t("adhkar.morning_title")
            : t("adhkar.evening_title")
        return AdhkarLibrary.load().first(where: { $0.name == target })
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

    // MARK: - UI build

    private func buildUI() {
        let content = AdaptiveBackgroundView(frame: NSRect(x: 0, y: 0,
                                                            width: panelWidth,
                                                            height: panelHeight),
                                              light: .windowBackgroundColor,
                                              dark: NSColor(calibratedWhite: 0.12, alpha: 1.0))
        content.wantsLayer = true
        contentView = content

        container = NSView()
        container.translatesAutoresizingMaskIntoConstraints = false
        content.addSubview(container)

        titleLabel = makeLabel(fontSize: 18, weight: .semibold, alignment: .center)
        positionLabel = makeLabel(fontSize: 11, weight: .regular, alignment: .center,
                                   textColor: .secondaryLabelColor)

        // Big Arabic line — this is the centerpiece. RTL, large Cairo.
        arabicLabel = NSTextField(wrappingLabelWithString: "")
        arabicLabel.isEditable = false
        arabicLabel.isBordered = false
        arabicLabel.drawsBackground = false
        arabicLabel.alignment = .center
        arabicLabel.font = Localizer.shared.font(size: 22, weight: .medium)
        arabicLabel.baseWritingDirection = .rightToLeft
        arabicLabel.translatesAutoresizingMaskIntoConstraints = false
        arabicLabel.cell?.truncatesLastVisibleLine = false
        arabicLabel.cell?.wraps = true
        arabicLabel.maximumNumberOfLines = 0

        countLabel = makeLabel(fontSize: 12, weight: .regular, alignment: .center,
                               textColor: .secondaryLabelColor)
        virtueLabel = makeLabel(fontSize: 11, weight: .regular, alignment: .center,
                                textColor: .tertiaryLabelColor)
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
        controls.spacing = 12
        controls.distribution = .equalCentering
        controls.translatesAutoresizingMaskIntoConstraints = false

        container.addSubview(titleLabel)
        container.addSubview(positionLabel)
        container.addSubview(arabicLabel)
        container.addSubview(countLabel)
        container.addSubview(virtueLabel)
        container.addSubview(controls)

        let guide = content.leadingAnchor
        NSLayoutConstraint.activate([
            container.leadingAnchor.constraint(equalTo: guide, constant: 24),
            container.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -24),
            container.topAnchor.constraint(equalTo: content.topAnchor, constant: 16),
            container.bottomAnchor.constraint(equalTo: content.bottomAnchor, constant: -20),

            titleLabel.topAnchor.constraint(equalTo: container.topAnchor),
            titleLabel.centerXAnchor.constraint(equalTo: container.centerXAnchor),

            positionLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 6),
            positionLabel.centerXAnchor.constraint(equalTo: container.centerXAnchor),

            arabicLabel.topAnchor.constraint(equalTo: positionLabel.bottomAnchor, constant: 24),
            arabicLabel.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 8),
            arabicLabel.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -8),

            countLabel.topAnchor.constraint(equalTo: arabicLabel.bottomAnchor, constant: 20),
            countLabel.centerXAnchor.constraint(equalTo: container.centerXAnchor),

            virtueLabel.topAnchor.constraint(equalTo: countLabel.bottomAnchor, constant: 14),
            virtueLabel.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 4),
            virtueLabel.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -4),

            controls.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -4),
            controls.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            controls.heightAnchor.constraint(equalToConstant: 36),
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
                                 pointSize: 16, size: NSSize(width: 44, height: 34))
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
        self.focusRingType = .none
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
// MARK: Adhkar window — dedicated adhkar management UI
// ============================================================================
// The app stays a menu-bar app by default (LSUIElement=true, .accessory
// policy). When the adhkar window opens we flip to .regular so a dock icon
// appears, and flip back to .accessory when it closes.
//
// This window is ONLY about adhkar — no prayer times, adhan, or settings
// tabs. Those are managed in the tray app's popover as they always were.

protocol MainTabContent: NSViewController {
    func tabDidActivate()
}

final class MainWindow: NSWindow, NSWindowDelegate {

    private var contentContainer: NSView!
    private var editorVC: AdhkarEditorViewController?

    init() {
        let frame = NSRect(x: 0, y: 0, width: 960, height: 640)
        super.init(contentRect: frame,
                   styleMask: [.titled, .closable, .miniaturizable, .resizable],
                   backing: .buffered, defer: false)
        self.title = t("adhkar.editor.title")
        self.center()
        self.isReleasedWhenClosed = false
        self.minSize = NSSize(width: 700, height: 480)
        self.delegate = self
        buildShell()
    }

    func showMainWindow() {
        NSApp.setActivationPolicy(.regular)
        makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        editorVC?.tabDidActivate()
    }

    func windowWillClose(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
    }

    private func buildShell() {
        let content = NSView(frame: self.contentLayoutRect)
        contentView = content
        contentContainer = NSView()
        contentContainer.translatesAutoresizingMaskIntoConstraints = false
        content.addSubview(contentContainer)
        NSLayoutConstraint.activate([
            contentContainer.leadingAnchor.constraint(equalTo: content.leadingAnchor),
            contentContainer.trailingAnchor.constraint(equalTo: content.trailingAnchor),
            contentContainer.topAnchor.constraint(equalTo: content.topAnchor),
            contentContainer.bottomAnchor.constraint(equalTo: content.bottomAnchor),
        ])
    }

    func setEditor(_ vc: AdhkarEditorViewController) {
        editorVC = vc
        vc.view.translatesAutoresizingMaskIntoConstraints = false
        contentContainer.subviews.forEach { $0.removeFromSuperview() }
        contentContainer.addSubview(vc.view)
        NSLayoutConstraint.activate([
            vc.view.leadingAnchor.constraint(equalTo: contentContainer.leadingAnchor),
            vc.view.trailingAnchor.constraint(equalTo: contentContainer.trailingAnchor),
            vc.view.topAnchor.constraint(equalTo: contentContainer.topAnchor),
            vc.view.bottomAnchor.constraint(equalTo: contentContainer.bottomAnchor),
        ])
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

    // Transient preview player for the audio picker's "preview" button.
    private var previewPlayer: AVAudioPlayer?

    init(appDelegate: AppDelegate) {
        self.appDelegate = appDelegate
        super.init(nibName: nil, bundle: nil)
    }
    required init?(coder: NSCoder) { fatalError() }

    override func loadView() {
        let v = NSView()
        buildTwoPaneLayout(into: v)
        self.view = v
        // Note: we do NOT call applyRTL here. It mirrors frames AND swaps
        // .right↔.left text alignment, which fights with the explicit
        // alignment = isRTL ? .right : .left we set on every field. The
        // buildTwoPaneLayout already handles RTL via leading/trailing
        // constraint branches and explicit text alignment.
    }

    func tabDidActivate() {
        reloadFromStorage()
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
        let leftWrap = NSView()
        leftWrap.translatesAutoresizingMaskIntoConstraints = false
        // Set RTL layout direction so leadingAnchor/trailingAnchor auto-flip
        // for Arabic. This makes bullet points, titles, and rows respect RTL.
        if isRTL { leftWrap.userInterfaceLayoutDirection = .rightToLeft }
        root.addSubview(leftWrap)

        let collectionsTitle = NSTextField(labelWithString: t("adhkar.editor.collections"))
        collectionsTitle.font = Localizer.shared.font(size: 13, weight: .semibold)
        collectionsTitle.textColor = .secondaryLabelColor
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
        collectionList.spacing = 4
        collectionList.edgeInsets = NSEdgeInsets(top: 4, left: 0, bottom: 4, right: 0)
        collectionList.translatesAutoresizingMaskIntoConstraints = false

        collectionView = NSScrollView()
        collectionView.documentView = collectionList
        collectionView.hasVerticalScroller = true
        collectionView.drawsBackground = false
        collectionView.translatesAutoresizingMaskIntoConstraints = false
        collectionView.hasHorizontalScroller = false
        if let clip = collectionView.contentView as? NSClipView {
            clip.drawsBackground = false
        }
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
        itemsHeaderLabel.font = Localizer.shared.font(size: 17, weight: .semibold)
        itemsHeaderLabel.alignment = isRTL ? .right : .left
        itemsHeaderLabel.baseWritingDirection = isRTL ? .rightToLeft : .leftToRight
        itemsHeaderLabel.translatesAutoresizingMaskIntoConstraints = false
        itemsContainer.addSubview(itemsHeaderLabel)

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
        itemsStack.spacing = 10
        itemsStack.edgeInsets = NSEdgeInsets(top: 8, left: 0, bottom: 8, right: 0)
        itemsStack.translatesAutoresizingMaskIntoConstraints = false

        itemsScrollView = NSScrollView()
        itemsScrollView.documentView = itemsStack
        itemsScrollView.hasVerticalScroller = true
        itemsScrollView.drawsBackground = false
        itemsScrollView.translatesAutoresizingMaskIntoConstraints = false
        itemsScrollView.hasHorizontalScroller = false
        itemsScrollView.autohidesScrollers = true
        itemsContainer.addSubview(itemsScrollView)

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
            leftWrap.topAnchor.constraint(equalTo: root.topAnchor, constant: 16),
            leftWrap.bottomAnchor.constraint(equalTo: root.bottomAnchor, constant: -16),
            leftWrap.widthAnchor.constraint(equalToConstant: 220),

            collectionsTitle.topAnchor.constraint(equalTo: leftWrap.topAnchor),
            collectionsTitle.leadingAnchor.constraint(equalTo: leftWrap.leadingAnchor),
            collectionsTitle.trailingAnchor.constraint(equalTo: leftWrap.trailingAnchor),

            newBtn.topAnchor.constraint(equalTo: collectionsTitle.bottomAnchor, constant: 8),
            newBtn.leadingAnchor.constraint(equalTo: leftWrap.leadingAnchor),
            newBtn.trailingAnchor.constraint(equalTo: leftWrap.trailingAnchor),

            collectionView.topAnchor.constraint(equalTo: newBtn.bottomAnchor, constant: 10),
            collectionView.leadingAnchor.constraint(equalTo: leftWrap.leadingAnchor),
            collectionView.trailingAnchor.constraint(equalTo: leftWrap.trailingAnchor),
            collectionView.bottomAnchor.constraint(equalTo: leftWrap.bottomAnchor),
        ])

        if isRTL {
            // RTL: sidebar on the RIGHT, items pane on the LEFT.
            NSLayoutConstraint.activate([
                leftWrap.trailingAnchor.constraint(equalTo: root.trailingAnchor, constant: -16),

                divider.trailingAnchor.constraint(equalTo: leftWrap.leadingAnchor, constant: -12),
                divider.topAnchor.constraint(equalTo: root.topAnchor, constant: 12),
                divider.bottomAnchor.constraint(equalTo: root.bottomAnchor, constant: -12),

                itemsContainer.trailingAnchor.constraint(equalTo: divider.leadingAnchor, constant: -16),
                itemsContainer.leadingAnchor.constraint(equalTo: root.leadingAnchor, constant: 16),
                itemsContainer.topAnchor.constraint(equalTo: root.topAnchor, constant: 16),
                itemsContainer.bottomAnchor.constraint(equalTo: root.bottomAnchor, constant: -16),
            ])
        } else {
            // LTR: sidebar on the LEFT, items pane on the RIGHT.
            NSLayoutConstraint.activate([
                leftWrap.leadingAnchor.constraint(equalTo: root.leadingAnchor, constant: 16),

                divider.leadingAnchor.constraint(equalTo: leftWrap.trailingAnchor, constant: 12),
                divider.topAnchor.constraint(equalTo: root.topAnchor, constant: 12),
                divider.bottomAnchor.constraint(equalTo: root.bottomAnchor, constant: -12),

                itemsContainer.leadingAnchor.constraint(equalTo: divider.trailingAnchor, constant: 16),
                itemsContainer.trailingAnchor.constraint(equalTo: root.trailingAnchor, constant: -16),
                itemsContainer.topAnchor.constraint(equalTo: root.topAnchor, constant: 16),
                itemsContainer.bottomAnchor.constraint(equalTo: root.bottomAnchor, constant: -16),
            ])
        }

        NSLayoutConstraint.activate([
            itemsHeaderLabel.topAnchor.constraint(equalTo: itemsContainer.topAnchor),
            itemsHeaderLabel.leadingAnchor.constraint(equalTo: itemsContainer.leadingAnchor),
            itemsHeaderLabel.trailingAnchor.constraint(equalTo: itemsContainer.trailingAnchor),

            addLibBtn.topAnchor.constraint(equalTo: itemsHeaderLabel.bottomAnchor, constant: 12),
            addLibBtn.leadingAnchor.constraint(equalTo: itemsContainer.leadingAnchor),

            addCustomBtn.topAnchor.constraint(equalTo: itemsHeaderLabel.bottomAnchor, constant: 12),
            addCustomBtn.leadingAnchor.constraint(equalTo: addLibBtn.trailingAnchor, constant: 8),

            itemsScrollView.topAnchor.constraint(equalTo: addLibBtn.bottomAnchor, constant: 12),
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

        let nameLbl = NSTextField(labelWithString: c.name)
        nameLbl.font = Localizer.shared.font(size: 13, weight: isSel ? .semibold : .regular)
        nameLbl.textColor = isSel ? .controlAccentColor : .labelColor
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
                                       size: NSSize(width: 32, height: 28))
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
            row.heightAnchor.constraint(greaterThanOrEqualToConstant: 40),

            // Name: for RTL, anchor to the TRAILING (right) edge with the play
            // button to its LEFT. For LTR, name on leading (left), play on right.
            nameLbl.topAnchor.constraint(equalTo: row.topAnchor, constant: 8),

            badge.topAnchor.constraint(equalTo: nameLbl.bottomAnchor, constant: 2),
            playBtn.centerYAnchor.constraint(equalTo: row.centerYAnchor),
            playBtn.widthAnchor.constraint(equalToConstant: 28),
            playBtn.heightAnchor.constraint(equalToConstant: 24),
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
        appDelegate?.presentAdhkar(collection: collections[idx], autoPlay: true)
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
        input.stringValue = collections[idx].name
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

    @objc private func setAnchor(_ mi: NSMenuItem) {
        guard let dict = mi.representedObject as? [String: Any],
              let id = dict["id"] as? UUID,
              let kind = dict["kind"] as? String,
              let idx = collections.firstIndex(where: { $0.id == id }) else { return }
        collections[idx].anchorKind = kind
        persist(); rebuildCollectionList()
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
            emptyStateLabel.isHidden = false
            itemsScrollView.isHidden = true
            return
        }
        let c = collections[idx]
        itemsHeaderLabel.stringValue = String(format: t("adhkar.editor.items_in"), c.name)
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
    }

    private func makeItemCard(_ entry: AdhkarEntry, index: Int, collectionIndex: Int) -> NSView {
        // Card background using the app's AdaptiveBackgroundView (same pattern
        // as the mosque-picker rows), not raw controlBackgroundColor.
        let card = AdaptiveBackgroundView(
            frame: NSRect(x: 0, y: 0, width: 100, height: 100),
            light: NSColor(white: 0, alpha: 0.05),
            dark:  NSColor(white: 1, alpha: 0.07),
            radius: 10)
        card.translatesAutoresizingMaskIntoConstraints = false

        let arabic = NSTextField(wrappingLabelWithString: entry.arabic)
        arabic.font = Localizer.shared.font(size: 18, weight: .medium)
        arabic.alignment = .right
        arabic.baseWritingDirection = .rightToLeft
        arabic.textColor = .labelColor
        arabic.translatesAutoresizingMaskIntoConstraints = false
        // Critical for wrapping: low horizontal resistance so the field
        // shrinks/wraps instead of forcing the card wider. Without this,
        // long Arabic text pushes the card to its intrinsic width and the
        // text never wraps.
        arabic.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        arabic.setContentHuggingPriority(.defaultLow, for: .horizontal)
        arabic.cell?.truncatesLastVisibleLine = false
        arabic.cell?.wraps = true
        arabic.maximumNumberOfLines = 0

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
                                     pointSize: 11, size: NSSize(width: 22, height: 22))
        upBtn.tag = index
        let downBtn = HoverIconButton(symbol: "chevron.down", toolTip: t("adhkar.editor.move_down"),
                                       target: self, action: #selector(itemMoveDown(_:)),
                                       pointSize: 11, size: NSSize(width: 22, height: 22))
        downBtn.tag = index
        let removeBtn = HoverIconButton(symbol: "trash", toolTip: t("adhkar.editor.remove"),
                                         target: self, action: #selector(removeItem(_:)),
                                         pointSize: 11, size: NSSize(width: 22, height: 22))
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
                                          size: NSSize(width: 26, height: 26))
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
        let ref = collections[ci].items[i].audioRef
        guard let url = resolveAdhkarAudio(ref),
              let p = try? AVAudioPlayer(contentsOf: url) else { return }
        previewPlayer?.stop()
        previewPlayer = p
        p.play()
    }

    /// Quick preview button on an item card — plays the item's audio.
    @objc private func previewItemAudio(_ sender: HoverIconButton) {
        guard let ci = selectedCollectionIndex() else { return }
        let i = sender.tag
        guard i >= 0, i < collections[ci].items.count else { return }
        let ref = collections[ci].items[i].audioRef
        guard !ref.isEmpty,
              let url = resolveAdhkarAudio(ref),
              let p = try? AVAudioPlayer(contentsOf: url) else { return }
        previewPlayer?.stop()
        previewPlayer = p
        p.play()
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
        guard let ci = selectedCollectionIndex() else { return }
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
        guard let ci = selectedCollectionIndex() else { return }
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

    override func mouseDown(with event: NSEvent) {
        if let id = collectionID {
            onSelect?(id)
        }
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

        registerCairoFonts()
        // One-time migrations: v2→v3 (morning/evening) + v3.1 (expanded catalog).
        migrateAdhkarDefaults()
        migrateAdhkarExpandedCatalog()
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
    @objc func menuChoose() {
        if !popover.isShown { togglePopover() }
        showPicker()
    }
    @objc func menuSettings() {
        if !popover.isShown { togglePopover() }
        showSettings()
    }
    /// Open the adhkar management window. Lazily builds the window + editor
    /// on first call.
    @objc func menuOpenMainWindow() { openMainWindow() }
    func openMainWindow() {
        if mainWindow == nil {
            let w = MainWindow()
            let editor = AdhkarEditorViewController(appDelegate: self)
            w.setEditor(editor)
            mainWindow = w
        }
        mainWindow?.showMainWindow()
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

        // Quick-access language switcher. Users change the UI language far
        // more often than they need to force-refresh, and having to open
        // Settings → Language for a 10-language list felt heavy. Clicking
        // the globe pops up a native NSMenu listing all languages in their
        // native script, with the active one checked. (Refresh remains
        // reachable from the status-bar right-click menu.)
        let languageBtn = HoverIconButton(
            symbol: "globe",
            toolTip: t("tooltip.language"),
            target: self,
            action: #selector(languageBtnTapped(_:)),
            pointSize: 15,
            size: btnSize)
        languageBtn.setFrameOrigin(NSPoint(x: centers[0] - btnSize.width/2, y: btnY))
        content.addSubview(languageBtn)

        let changeBtn = HoverIconButton(
            symbol: "mappin.and.ellipse",
            toolTip: t("tooltip.change"),
            target: self,
            action: #selector(changeMosqueTapped),
            pointSize: 15,
            size: btnSize)
        changeBtn.setFrameOrigin(NSPoint(x: centers[1] - btnSize.width/2, y: btnY))
        content.addSubview(changeBtn)

        // Adhkar button — opens the adhkar manager window directly, so the
        // user doesn't have to right-click → "Open Main Window…".
        // (Theme tweaks are still available in Settings → Appearance.)
        let adhkarBtn = HoverIconButton(
            symbol: "text.book.closed.fill",
            toolTip: t("adhkar.editor.title"),
            target: self,
            action: #selector(menuOpenMainWindow),
            pointSize: 15,
            size: btnSize)
        adhkarBtn.setFrameOrigin(NSPoint(x: centers[2] - btnSize.width/2, y: btnY))
        content.addSubview(adhkarBtn)

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
    @objc func changeMosqueTapped() { showPicker() }
    @objc func settingsTapped() { showSettings() }

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
                if (typeof d.jumua === 'string') jumua = d.jumua;
                else if (Array.isArray(d.jumua) && d.jumua.length) jumua = d.jumua[0];
                else if (d.jumuaTime) jumua = d.jumuaTime;

                return JSON.stringify({
                    name: d.name || d.label || '',
                    localisation: d.localisation || d.association || '',
                    phone: d.phone || '',
                    site: d.site || '',
                    times: times,
                    shuruq: shuruq,
                    iqama: iqama,
                    jumua: jumua
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
            next.date         = self.todayString()
            next.sourceURL    = wv.url?.absoluteString ?? ""

            guard next.times.count >= 5 else { return }
            self.info = next
            self.saveInfo()
            DispatchQueue.main.async { self.updateUI(); self.tick() }
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
        nameLabel.stringValue = info.name.isEmpty ? t("mosque.default") : info.name
        var addr = info.localisation
        if !info.phone.isEmpty { addr += (addr.isEmpty ? "" : " · ") + "📞 \(info.phone)" }
        addressLabel.stringValue = addr

        // Re-center the mosque name vertically with the app icon when there's
        // no address to show, so short mosque names don't float above center.
        // With an address, the block is centered as a whole (name y=12,
        // address y=34 → block midline y=36 = icon midline).
        if let nf = nameLabel?.frame {
            let newY: CGFloat = addr.isEmpty ? 25 : 12
            if nf.origin.y != newY {
                nameLabel.frame = NSRect(x: nf.origin.x, y: newY,
                                         width: nf.size.width, height: nf.size.height)
            }
            addressLabel.isHidden = addr.isEmpty
        }

        // Header link button — only enabled when we actually have a mosque
        // URL to open. Keeps the icon visible but dimmed otherwise so the
        // user doesn't wonder why their click does nothing.
        if headerLinkBtn != nil {
            let hasURL = !currentMosqueURL().trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
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
        checkAdhkarTrigger()
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
    }

    // MARK: - AVAudioPlayerDelegate
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        if adhanPlayer === player { adhanPlayer = nil }
        onAdhanStateChanged?()
        syncStopAdhanStatusItem()
    }
    func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: Error?) {
        if adhanPlayer === player { adhanPlayer = nil }
        onAdhanStateChanged?()
        syncStopAdhanStatusItem()
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
            let marker = "\(todayStr)#\(c.id.uuidString.prefix(8))"
            if fired.contains(marker) { continue }
            guard let t = adhkarAnchorTime(c.anchorKind),
                  let d = fmt.date(from: t) else { continue }
            let comps = cal.dateComponents([.hour, .minute], from: d)
            guard let when = cal.date(bySettingHour: comps.hour ?? 0,
                                       minute: comps.minute ?? 0, second: 0, of: today) else { continue }
            let dt = now.timeIntervalSince(when)
            if dt >= 0 && dt < 60 {
                presentAdhkar(collection: c, autoPlay: true)
                fired.append(marker)
            }
        }
        UserDefaults.standard.set(fired, forKey: firedKey)
    }

    /// Open the adhkar window. `autoPlay` = true on scheduled trigger; false
    /// when the user opens it manually from the menu (still autoplays because
    /// that's the point of opening it, but leaves control to the user).
    func presentAdhkar(set: AdhkarSet, autoPlay: Bool) {
        if adhkarPanel == nil { adhkarPanel = AdhkarPanel() }
        adhkarPanel?.present(set: set, autoPlay: autoPlay)
    }

    /// v3 entry point — present a specific user collection.
    func presentAdhkar(collection: AdhkarCollection, autoPlay: Bool) {
        if adhkarPanel == nil { adhkarPanel = AdhkarPanel() }
        adhkarPanel?.present(collection: collection, autoPlay: autoPlay)
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
