# SPEC: the "France — mosque convention" calculation

This is the exact, language-neutral definition of the method, version `fr-dept-2026.1`. Every app must implement it as written: macOS, iOS, Android and web.

- **Reference.** `reference/prayer_method.mjs` is the executable form of this document.
- **Conformance.** An implementation conforms when it reproduces every value in `test-vectors/` (section 8).

---

## 1. Units and conventions

- **Inputs.** A civil date `(y, m, d)`, a place `(φ latitude, λ longitude east-positive)` and an IANA time zone, for example `Europe/Paris`.
- **Times.** All internal times are `Double` local hours.
- **Results.** Every result is a **minute after local midnight**, an integer.
  - Isha that falls after midnight is reported as **≥ 1440**: 00:04 is 1444. This keeps the six prayers in order: Fajr < Shuruq < Dhuhr < Asr < Maghrib < Isha.
  - Display `HH:mm` of `minute mod 1440`.
- **Prayers**, in this order: `fajr, sunrise (Shuruq), dhuhr, asr, maghrib, isha`.
- **Floating point.** Use IEEE-754 double everywhere. Keep the operation order of the formulas below: results are rounded to the minute, so a reordered formula can move a time by one minute.
- **Notation.**
  - `rad(x) = (x·π)/180` and `deg(x) = (x·180)/π`, written exactly in that order.
  - `fix(a, b) = a − b·floor(a/b)`, then `+ b` if the result is negative.

## 2. The engine (Mawaqit arithmetic)

```
1. Julian day at 0h UT (Meeus):
     Y = y, M = m; if M ≤ 2 { Y −= 1; M += 12 }
     A = floor(Y/100); B = 2 − A + floor(A/4)
     JD0 = floor(365.25·(Y + 4716)) + floor(30.6001·(M + 1)) + d + B − 1524.5
     jdBase = JD0 − λ/(15·24)

2. Time zone: utcOff = UTC offset in hours of tz in force at 12:00 local time of that date
                       (from the platform's time-zone database)
     shift = utcOff − λ/15

3. sun(jd) → (decl, eqt):
     D = jd − 2451545.0
     g = fix(357.529 + 0.98560028·D, 360)
     q = fix(280.459 + 0.98564736·D, 360)
     L = fix(q + 1.915·sin(rad(g)) + 0.020·sin(rad(2·g)), 360)
     e = 23.439 − 0.00000036·D
     RA   = deg(atan2(cos(rad(e))·sin(rad(L)), cos(rad(L)))) / 15
     eqt  = q/15 − fix(RA, 24)
     decl = deg(asin(sin(rad(e))·sin(rad(L))))

4. Guess slots s ∈ {5, 6, 12, 13, 18}:
     (decl_s, eqt_s) = sun(jdBase + s/24);  noon_s = fix(12 − eqt_s, 24)
   T(α, s, φ) = (1/15) · deg(acos(clamp(p1/p2, −1, 1)))
       p1 = −sin(rad(α)) − sin(rad(decl_s))·sin(rad(φ))
       p2 =  cos(rad(decl_s))·cos(rad(φ))
   before(α, s, φ) = (noon_s − T(α, s, φ)) + shift
   after(α, s, φ)  = (noon_s + T(α, s, φ)) + shift
   sunrise(φ) = before(0.833, 6, φ)      sunset(φ) = after(0.833, 18, φ)
   transit    = noon_12 + shift
   The clamp means there is never a NaN: an angle the sun does not reach gives solar midnight.

5. Twilight with a high-latitude rule (Fajr: before(α, 5, φ); Isha: after(α, 18, φ)):
     if rule == NONE: done
     night = fix(sunrise(φ) − sunset(φ), 24)
     portion = ANGLE_BASED:        (1/60·α)·night
               NIGHT_FRACTION:     f·night          (f = spec.night_fraction)
               ONE_SEVENTH:        (1/7)·night
               MIDDLE_OF_THE_NIGHT:(1/2)·night
     Fajr: if fix(sunrise(φ) − t, 24) > portion { t = sunrise(φ) − portion }
     Isha: if fix(t − sunset(φ), 24) > portion  { t = sunset(φ) + portion }

6. Asr (shadow factor F: 1 = Shafi'i/Maliki, 2 = Hanafi):
     JDN = integer Julian Day Number (integer arithmetic, floor division):
           yy = y + 4800; if m > 2 { mm = m − 3 } else { mm = m + 9; yy −= 1 }
           JDN = ((yy div 100)·146097) div 4 + ((yy mod 100)·1461) div 4 + (mm·153 + 2) div 5 + d − 32045
           (2026-01-01 → 2461042)
     clockFrac(h) = h/24 − 0.5, + 1 if negative       (h = whole UTC hour of the spec, default 20)
     adecl = epoch == "praytimes" ? decl_13 : sun((JDN + clockFrac(h)) + 13/24).decl
     x = |φ − adecl|
     α = −((atan(1 / (F + tan(rad(x)))) · 180) / π)
     asr = (noon_13 + T(α, 13, φ)) + shift          // T uses decl_13, not adecl

7. Rounding (PHP getFormattedTime, round half-up):
     minute(t): tt = fix(t + 0.5/60, 24); h = floor(tt); mi = floor((tt − h)·60); return h·60 + mi
   Isha only: after rounding, if minute < 360 then minute += 1440.
```

**Notes**
- **Asr server clock.** The clock exists because Mawaqit's server takes one Asr input from its own clock. 20:00 UTC is the best single value.
- **Daylight-saving time.** Taking the UTC offset at local noon is what makes DST change days come out right. Never add a fixed offset.

## 3. Prayer specs (the rule for one prayer)

The département table, the standard methods and "Match my mosque" all describe each prayer with a **spec**, a small JSON object. The **offset** is in whole minutes, added to the rounded minute. Then `floor` and `cap` apply, in local clock minutes: 240 = 04:00, 1140 = 19:00, 1410 = 23:30.

| Prayer | `family` | Fields | Result (m(t) = rounded minute of §2.7) |
|---|---|---|---|
| fajr | `angle` | `angle, rule, offset, floor?, cap?, lat_eff?, night_fraction?` | m(Fajr twilight §2.5) + offset, then floor/cap |
| fajr / isha | `monthly_angle` | `angles[12], rule (NONE), offset` | as `angle`, using `angles[month − 1]` |
| fajr / isha | `seasonal_angle` | `a, b, rule, offset` | as `angle` with angle = a + b·cos(2π·(doy0 − 355)/365.25), where doy0 = 0-based day of the year |
| fajr | `interval` | `minutes, floor?, cap?, lat_eff?` | m(sunrise) − minutes, then floor/cap |
| isha | `angle` | as Fajr | m(Isha twilight §2.5), then +1440 if < 360, + offset, then floor/cap |
| isha | `interval` | `minutes, floor?, cap?, lat_eff?` | m(sunset) + minutes, then floor/cap. "Maghrib + 90" with Maghrib = sunset + 3 is `minutes: 93`. |
| sunrise | `sunrise` | `offset, lat_eff?` | m(sunrise) + offset |
| dhuhr | `transit` | `offset` | m(transit) + offset |
| dhuhr | `transit_floor` / `transit_cap` | `offset, floor` / `offset, cap` | max / min (m(transit) + offset, bound) |
| dhuhr | `mixed_dst` | `calc_in ("std" or "dst"), offset, value` | computed (m(transit) + offset) on days of the `calc_in` regime, fixed `value` on the other days |
| dhuhr | `fixed` / `fixed_by_dst` | `value` / `std, dst` | a fixed clock time (not in the current table; for custom settings) |
| asr | `shadow` | `factor, clock` or `epoch: "praytimes"`, `offset, floor?` | max(m(asr §2.6) + offset, floor) |
| maghrib | `sunset` | `offset, lat_eff?` | m(sunset) + offset |
| maghrib | `angle` | `angle, rule (default ANGLE_BASED), offset` | m(Isha-type twilight §2.5 with that angle) + offset |

**Rules that apply to every family**

| Field or default | Meaning |
|---|---|
| `lat_eff` | Compute that prayer with latitude `lat_eff` instead of the place's, including the sunrise and sunset its high-latitude rule uses. The longitude and time zone stay the place's. This models a calendar made for a reference city. |
| Default `rule` | `ANGLE_BASED` for `angle` and `seasonal_angle`; `NONE` for `monthly_angle`. |
| Default Asr | `factor` 1 and `clock` 20.0, unless `epoch` is `"praytimes"`, in which case the clock is not used. |
| DST day (for `mixed_dst`, `fixed_by_dst`) | The UTC offset at local noon is greater than the smallest local-noon offset of that calendar year. |
| User adjustments | Per-prayer whole minutes added **last**, after floor/cap. This includes the adjustment chosen by "Match my mosque". |

**Fail closed.** An implementation must reject a spec with an unknown `family` or `rule` rather than guess. It should also flag fields it does not know.

## 4. Location → département → specs

1. **Get a postcode** for the place from the geocoder: typed address, or reverse-geocoded GPS position. See INTEGRATION.md.
2. **Find the département** from the postcode:
   - Strip spaces. It must be exactly 5 digits, otherwise there is no département.
   - `97xxx` and `98xxx` are overseas or Monaco: no département.
   - `20xxx` is Corsica: below 20200 is `"2A"`, otherwise `"2B"`.
   - Otherwise it is the first two digits (`"01"`…`"95"`).
3. **Read the specs** from `data/france_conventions_v1.json`:
   - `departments[code][prayer]` is an index into `specs[prayer]`.
   - If the département is unknown, use `national[prayer]`, the national fallback.
4. **Outside metropolitan France** (another country, overseas, no postcode), do not use the table. Use a standard method (section 5): MWL by default, or the user's choice.
5. **Use the place's own coordinates** with the département's specs. The table gives conventions, not times.

## 5. Standard methods and user options

`data/standard_methods.json` lists the methods as full spec sets.

| id | Method |
|---|---|
| `fr-dept` | France — mosque convention (this table) |
| `uoif-safety` | UOIF 12° with safety minutes |
| `uoif-12` | 12°/12° with no minutes; Mawaqit "FRANCE" |
| `isna` | ISNA 15°/15° |
| `mwl` | MWL 18°/17° |
| `egypt` | Egypt 19.5°/17.5° |
| `umm-al-qura` | 18.5° / Maghrib + 90 |
| `morocco` | Morocco 19°/17° |
| `algeria` | Algeria 18°/17° |
| `tunisia` | Tunisia 18°/18° |
| others | The rest of the Mawaqit library's methods, for other countries |

Every method uses the `ANGLE_BASED` rule and Asr ×1 at clock 20:00.

**User options** that change the specs, never the engine:
- **Asr school.** Hanafi sets `factor: 2` on the Asr spec.
- **High-latitude rule.** Changes `rule` on the Fajr, Isha and Maghrib-angle specs.
- **Per-prayer adjustments.** −30…+30 minutes, added last.
- **Custom.** Any Fajr or Isha angle, or "Shuruq − N" (`interval`) and "Maghrib + N" (`interval` with N + Maghrib's offset).
- **"Astronomical times only."** Removes `floor` and `cap` and turns `mixed_dst` / `transit_floor` into `transit` with the same offset.

## 6. "Match my mosque"

**Purpose.** It lets a user make Fajr and Isha follow their own mosque. This raises within-2-min agreement from 53% / 45% to 81% / 81% (FINDINGS §4).

**Steps**
1. **Ask for two days.** The user types the mosque's Fajr and Isha for **two days of the same month**, for example today and another day from the mosque's monthly timetable. One day is allowed, but warn that it is less reliable.
2. **List the candidates** for each prayer separately:
   - index 0 is the département default (§4), or the current method's spec outside France;
   - then `data/match_presets.json` `presets[prayer]`, in file order.
3. **Try every adjustment** `a` from −10 to +10 minutes, ordered by |a|, negatives first: 0, −1, 1, −2, 2, …, −10, 10.
4. **Pick one.** For each candidate c and adjustment a, compute `err = Σ over typed days |minute_c(day) + a − typed(day)|`.
   - Keep the smallest `err`.
   - On a tie, keep the first in the order "adjustment order, then candidate index". That is, loop adjustments outside and candidates inside, and replace only on a strictly smaller err.
5. **Save** the chosen spec plus its adjustment as the user's setting for that prayer. Show it in words, for example "Fajr 12° − 5 min, Isha Maghrib + 90".

Dhuhr and Maghrib may be matched the same way with only the département default as candidate, which amounts to an adjustment.

## 7. Building a timetable

- **Times.** Compute each day independently with §2–3. Nothing carries over from day to day.
- **Calendar.** For a year calendar, loop over the civil dates of that year. 29 February exists only in leap years. Apps that need a fixed 12×31 grid fill missing days themselves.
- **Regenerate** whenever any of these change:
  - the date passes into a new year;
  - the place or its time zone;
  - the method, the settings or the adjustments;
  - the `methodID` of the data file.
- **Prayer day.** The prayer day ends at midnight, or after that night's Isha if Isha is after midnight. Order and schedule notifications with the ≥ 1440 Isha minute.
- **Imsak.** Fajr − 10 min by default. It is an app setting, not part of the method.
- **Device time zone.** If the device's time zone differs from the place's, compute in the place's zone (the conventions are local clock rules). Then convert each time to an absolute instant to schedule alerts.

## 8. Conformance

An implementation conforms when, for every case in `test-vectors/`, it returns exactly the expected minutes:

| File | What it checks |
|---|---|
| `engine_vectors.json` | Standard methods at 24 world places, 2024–2032 |
| `family_vectors.json` | Every family and option, 2026–2028 |
| `table_vectors.json` | The table every day: 96 département points in 2026, 13 cities over 2026–2028 |
| `smoke_values.json` | Human-readable sample |
| `match_vectors.json` | "Match my mosque" decisions |
| `postcode_vectors.json` | Postcode → département |

**Pass rule.** There is no tolerance: a 1-minute difference is a bug.

**Diagnosing a failure.**
- **Engine vectors carry `utc_offset_hours`.** Check the arithmetic with that offset. If your platform's time-zone database gives a different offset (Morocco rules differ between tzdata releases), report it separately: it is not an engine error.
- **Engine vectors carry `float_hours`** before rounding. A value within 1e-9 h of a minute boundary may differ because of a math library's last bit. This never happened on the 308,520 checked values.

**Reference run.** `node reference/run_vectors.mjs` prints the counts and must end with `ALL VECTORS PASS`.

## 9. Versioning and updates

- **Identity.** The method is identified by `methodID` in `data/france_conventions_v1.json`, currently `fr-dept-2026.1`. Store it with any cached timetable, and recompute when it changes.
- **New table.** A refreshed table, for example from 2027 calendars, gets a new `methodID` and new test vectors from `tools/build_package.py`. The engine and families stay the same.
- **New spec family.** Adding a family is a SPEC change. Bump the SPEC version and add vectors before any app uses it.
