// ============================================================================
// Salat Time — WidgetKit extension (macOS)
// ----------------------------------------------------------------------------
// Four widget kinds mirror the app's dashboard styles — Overview, List,
// Timeline, Clock — in Apple's widget design language. The main app writes a
// snapshot JSON into the shared group container and reloads timelines; the
// widget renders purely from that snapshot (no network, no Qur'an content).
// Built by build.sh into Contents/PlugIns/SalatWidgets.appex.
// ============================================================================

import WidgetKit
import SwiftUI

// MARK: - shared snapshot

struct PrayerSnapshot: Codable {
    var dateKey: String
    var writtenAt: Double
    var mosque: String
    var names: [String]
    var times: [String]        // "HH:mm", 24-hour, today
    var iqama: [String]
    var shuruqLabel: String
    var shuruq: String
    var nextLabel: String
    var iqamaLabel: String
    var use24h: Bool
    var rtl: Bool
    var accent: [Double]       // r, g, b (light-mode accent)

    static let sample = PrayerSnapshot(
        dateKey: "2026-01-01", writtenAt: Date().timeIntervalSince1970,
        mosque: "Masjid Al-Huda",
        names: ["Fajr", "Dhuhr", "Asr", "Maghrib", "Isha"],
        times: ["05:12", "13:05", "16:42", "19:58", "21:23"],
        iqama: ["05:22", "13:15", "16:52", "20:03", "21:33"],
        shuruqLabel: "Shuruq", shuruq: "06:44",
        nextLabel: "Next prayer", iqamaLabel: "Iqama",
        use24h: true, rtl: false, accent: [0.15, 0.55, 0.45])
}

func widgetSnapshotURL() -> URL? {
    FileManager.default
        .containerURL(forSecurityApplicationGroupIdentifier: "group.com.salattime.app")?
        .appendingPathComponent("widget-snapshot.json")
}

func loadPrayerSnapshot() -> PrayerSnapshot? {
    guard let url = widgetSnapshotURL(),
          let data = try? Data(contentsOf: url),
          let snapshot = try? JSONDecoder().decode(PrayerSnapshot.self, from: data),
          snapshot.times.count >= 5, snapshot.names.count >= 5 else { return nil }
    return snapshot
}

// MARK: - time math

func minutesOfDay(_ hhmm: String) -> Int? {
    let parts = hhmm.split(separator: ":")
    guard parts.count == 2, let hours = Int(parts[0]), let minutes = Int(parts[1])
    else { return nil }
    return hours * 60 + minutes
}

func dateToday(at hhmm: String, reference: Date) -> Date? {
    guard let minutes = minutesOfDay(hhmm) else { return nil }
    let calendar = Calendar.current
    return calendar.date(bySettingHour: minutes / 60, minute: minutes % 60,
                         second: 0, of: reference)
}

func formatTime(_ hhmm: String, use24h: Bool) -> String {
    guard !use24h, let minutes = minutesOfDay(hhmm) else { return hhmm }
    var hours = minutes / 60 % 12
    if hours == 0 { hours = 12 }
    return String(format: "%d:%02d", hours, minutes % 60)
}

// MARK: - timeline provider

struct SalatEntry: TimelineEntry {
    let date: Date
    let snapshot: PrayerSnapshot
    let nextIndex: Int          // 0–4, wraps to Fajr after Isha
    let nextDate: Date
    let isStale: Bool
}

private func makeEntry(at moment: Date, snapshot: PrayerSnapshot) -> SalatEntry {
    let dates = snapshot.times.prefix(5).compactMap { dateToday(at: $0, reference: moment) }
    let stale = moment.timeIntervalSince1970 - snapshot.writtenAt > 36 * 3600
    if let index = dates.firstIndex(where: { $0 > moment }) {
        return SalatEntry(date: moment, snapshot: snapshot, nextIndex: index,
                          nextDate: dates[index], isStale: stale)
    }
    // All prayers passed — next is Fajr tomorrow.
    let fajrTomorrow = dates.first.map {
        Calendar.current.date(byAdding: .day, value: 1, to: $0) ?? $0
    } ?? moment.addingTimeInterval(6 * 3600)
    return SalatEntry(date: moment, snapshot: snapshot, nextIndex: 0,
                      nextDate: fajrTomorrow, isStale: stale)
}

struct SalatProvider: TimelineProvider {
    func placeholder(in context: Context) -> SalatEntry {
        makeEntry(at: Date(), snapshot: .sample)
    }

    func getSnapshot(in context: Context, completion: @escaping (SalatEntry) -> Void) {
        let snapshot = loadPrayerSnapshot() ?? .sample
        completion(makeEntry(at: Date(), snapshot: snapshot))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<SalatEntry>) -> Void) {
        let now = Date()
        let snapshot = loadPrayerSnapshot() ?? .sample
        var moments: [Date] = [now]
        for time in snapshot.times.prefix(5) {
            if let date = dateToday(at: time, reference: now), date > now {
                moments.append(date.addingTimeInterval(1))
            }
        }
        if let midnight = Calendar.current.date(
            byAdding: .day, value: 1, to: Calendar.current.startOfDay(for: now)) {
            moments.append(midnight.addingTimeInterval(60))
        }
        let entries = moments.sorted().map { makeEntry(at: $0, snapshot: snapshot) }
        completion(Timeline(entries: entries, policy: .atEnd))
    }
}

// MARK: - design system
//
// Apple-widget language: a rich accent-derived gradient canvas, white
// typography with strict opacity hierarchy, SF Rounded numerals, one
// SF Symbol per prayer, and capsule highlights for the "next" element —
// the same vocabulary Weather and Fitness widgets use.

let prayerSymbols = ["sunrise.fill", "sun.max.fill", "sun.min.fill",
                     "sunset.fill", "moon.stars.fill"]

extension PrayerSnapshot {
    func shade(_ multiplier: Double, opacity: Double = 1) -> Color {
        guard accent.count >= 3 else {
            return Color(red: 0.1 * multiplier, green: 0.4 * multiplier,
                         blue: 0.4 * multiplier).opacity(opacity)
        }
        return Color(red: min(1, accent[0] * multiplier),
                     green: min(1, accent[1] * multiplier),
                     blue: min(1, accent[2] * multiplier)).opacity(opacity)
    }

    var canvas: some View {
        ZStack {
            LinearGradient(colors: [shade(0.52), shade(1.12)],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
            RadialGradient(colors: [Color.white.opacity(0.14), .clear],
                           center: .topLeading, startRadius: 0, endRadius: 260)
        }
    }
}

private let inkPrimary = Color.white
private let inkSecondary = Color.white.opacity(0.72)
private let inkTertiary = Color.white.opacity(0.5)
private let pillFill = Color.white.opacity(0.16)

struct StaleView: View {
    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: "moon.stars.fill")
                .font(.title2)
                .foregroundStyle(inkSecondary)
            Text("Salat Time")
                .font(.system(.headline, design: .rounded))
                .foregroundStyle(inkPrimary)
            Text("Open the app to refresh")
                .font(.caption2)
                .foregroundStyle(inkTertiary)
        }
    }
}

struct CountdownText: View {
    let entry: SalatEntry
    var body: some View {
        Text(timerInterval: entry.date...entry.nextDate, countsDown: true)
            .monospacedDigit()
            .multilineTextAlignment(entry.snapshot.rtl ? .trailing : .leading)
    }
}

/// The countdown inside a soft capsule — the signature element shared by
/// every size.
struct CountdownPill: View {
    let entry: SalatEntry
    var compact = false
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "timer")
                .font(.system(size: compact ? 9 : 10, weight: .semibold))
            CountdownText(entry: entry)
                .font(.system(compact ? .caption2 : .caption, design: .rounded)
                    .weight(.semibold))
                .lineLimit(1)
        }
        .foregroundStyle(inkPrimary)
        .padding(.horizontal, compact ? 7 : 9)
        .padding(.vertical, compact ? 3 : 4)
        .background(pillFill, in: Capsule())
    }
}

private func timeText(_ hhmm: String, _ snapshot: PrayerSnapshot,
                      size: CGFloat, weight: Font.Weight = .bold) -> some View {
    Text(formatTime(hhmm, use24h: snapshot.use24h))
        .font(.system(size: size, weight: weight, design: .rounded))
        .monospacedDigit()
}

/// One compact prayer line: symbol · name ····· time. The next prayer gets
/// a soft capsule and full opacity.
struct PrayerRow: View {
    let snapshot: PrayerSnapshot
    let index: Int
    let isNext: Bool
    var showIqama = false
    var dense = false

    var body: some View {
        HStack(spacing: dense ? 6 : 8) {
            Image(systemName: prayerSymbols[index])
                .font(.system(size: dense ? 10 : 12, weight: .semibold))
                .foregroundStyle(isNext ? inkPrimary : inkSecondary)
                .frame(width: dense ? 14 : 18)
            Text(snapshot.names[index])
                .font(.system(dense ? .caption : .callout, design: .rounded)
                    .weight(isNext ? .bold : .medium))
                .foregroundStyle(isNext ? inkPrimary : inkSecondary)
                .lineLimit(1)
            Spacer(minLength: 6)
            if showIqama, snapshot.iqama.count > index, !snapshot.iqama[index].isEmpty {
                Text(formatTime(snapshot.iqama[index], use24h: snapshot.use24h))
                    .font(.system(.caption2, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(inkTertiary)
            }
            Text(formatTime(snapshot.times[index], use24h: snapshot.use24h))
                .font(.system(dense ? .caption : .callout, design: .rounded)
                    .weight(isNext ? .bold : .semibold))
                .monospacedDigit()
                .foregroundStyle(isNext ? inkPrimary : inkSecondary)
        }
        .padding(.horizontal, dense ? 7 : 9)
        .padding(.vertical, dense ? 3 : 5)
        .background(isNext ? AnyShapeStyle(pillFill) : AnyShapeStyle(.clear),
                    in: RoundedRectangle(cornerRadius: dense ? 7 : 9, style: .continuous))
    }
}

// MARK: - Overview widget

struct OverviewView: View {
    @Environment(\.widgetFamily) private var family
    let entry: SalatEntry

    var body: some View {
        if entry.isStale { StaleView() } else { content }
    }

    @ViewBuilder private var content: some View {
        let snapshot = entry.snapshot
        switch family {
        case .systemSmall:
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Image(systemName: prayerSymbols[entry.nextIndex])
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(inkPrimary)
                    Spacer()
                    Text(snapshot.nextLabel.uppercased())
                        .font(.system(size: 9, weight: .bold, design: .rounded))
                        .tracking(0.8)
                        .foregroundStyle(inkTertiary)
                }
                Spacer(minLength: 4)
                Text(snapshot.names[entry.nextIndex])
                    .font(.system(.title3, design: .rounded).weight(.bold))
                    .foregroundStyle(inkPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                timeText(snapshot.times[entry.nextIndex], snapshot, size: 34)
                    .foregroundStyle(inkPrimary)
                Spacer(minLength: 4)
                CountdownPill(entry: entry, compact: true)
            }
        case .systemMedium:
            HStack(spacing: 14) {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Image(systemName: prayerSymbols[entry.nextIndex])
                            .font(.system(size: 15, weight: .semibold))
                        Text(snapshot.nextLabel.uppercased())
                            .font(.system(size: 9, weight: .bold, design: .rounded))
                            .tracking(0.8)
                            .foregroundStyle(inkTertiary)
                    }
                    .foregroundStyle(inkPrimary)
                    Spacer(minLength: 2)
                    Text(snapshot.names[entry.nextIndex])
                        .font(.system(.title2, design: .rounded).weight(.bold))
                        .foregroundStyle(inkPrimary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                    timeText(snapshot.times[entry.nextIndex], snapshot, size: 36)
                        .foregroundStyle(inkPrimary)
                    Spacer(minLength: 2)
                    CountdownPill(entry: entry, compact: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                VStack(spacing: 1) {
                    ForEach(0..<5, id: \.self) { index in
                        PrayerRow(snapshot: snapshot, index: index,
                                  isNext: index == entry.nextIndex, dense: true)
                    }
                }
                .frame(width: 152)
            }
        default:
            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .center) {
                    VStack(alignment: .leading, spacing: 0) {
                        HStack(spacing: 6) {
                            Image(systemName: prayerSymbols[entry.nextIndex])
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(inkPrimary)
                            Text(snapshot.nextLabel.uppercased())
                                .font(.system(size: 10, weight: .bold, design: .rounded))
                                .tracking(0.8)
                                .foregroundStyle(inkTertiary)
                        }
                        Text(snapshot.names[entry.nextIndex])
                            .font(.system(.title, design: .rounded).weight(.bold))
                            .foregroundStyle(inkPrimary)
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 3) {
                        timeText(snapshot.times[entry.nextIndex], snapshot, size: 40)
                            .foregroundStyle(inkPrimary)
                        CountdownPill(entry: entry)
                    }
                }
                Rectangle()
                    .fill(Color.white.opacity(0.18))
                    .frame(height: 1)
                    .padding(.vertical, 2)
                VStack(spacing: 2) {
                    ForEach(0..<5, id: \.self) { index in
                        PrayerRow(snapshot: snapshot, index: index,
                                  isNext: index == entry.nextIndex, showIqama: true)
                    }
                }
                Spacer(minLength: 0)
                HStack(spacing: 5) {
                    Image(systemName: "sunrise")
                        .font(.system(size: 9, weight: .semibold))
                    Text("\(snapshot.shuruqLabel) \(formatTime(snapshot.shuruq, use24h: snapshot.use24h))")
                        .monospacedDigit()
                    Spacer()
                    Text(snapshot.mosque)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
                .font(.system(.caption2, design: .rounded))
                .foregroundStyle(inkTertiary)
            }
        }
    }
}

// MARK: - List widget

struct ListView: View {
    @Environment(\.widgetFamily) private var family
    let entry: SalatEntry

    var body: some View {
        if entry.isStale { StaleView() } else { content }
    }

    @ViewBuilder private var content: some View {
        let snapshot = entry.snapshot
        let dense = family == .systemSmall
        VStack(spacing: dense ? 1 : family == .systemLarge ? 6 : 2) {
            ForEach(0..<5, id: \.self) { index in
                PrayerRow(snapshot: snapshot, index: index,
                          isNext: index == entry.nextIndex,
                          showIqama: family == .systemLarge,
                          dense: dense)
            }
            if family != .systemSmall {
                Spacer(minLength: 0)
                HStack {
                    CountdownPill(entry: entry, compact: family == .systemMedium)
                    Spacer()
                    if family == .systemLarge {
                        HStack(spacing: 5) {
                            Image(systemName: "sunrise")
                                .font(.system(size: 9, weight: .semibold))
                            Text("\(snapshot.shuruqLabel) \(formatTime(snapshot.shuruq, use24h: snapshot.use24h))")
                                .monospacedDigit()
                        }
                        .font(.system(.caption2, design: .rounded))
                        .foregroundStyle(inkTertiary)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }
}

// MARK: - Timeline widget

struct DayTimelineView: View {
    @Environment(\.widgetFamily) private var family
    let entry: SalatEntry

    var body: some View {
        if entry.isStale { StaleView() } else { content }
    }

    private func fraction(of hhmm: String) -> CGFloat? {
        guard let minutes = minutesOfDay(hhmm) else { return nil }
        return CGFloat(minutes) / 1440
    }

    @ViewBuilder private var content: some View {
        let snapshot = entry.snapshot
        let nowMinutes = Calendar.current.component(.hour, from: entry.date) * 60
            + Calendar.current.component(.minute, from: entry.date)
        let nowFraction = CGFloat(nowMinutes) / 1440

        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .center, spacing: 8) {
                Image(systemName: prayerSymbols[entry.nextIndex])
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(inkPrimary)
                Text(snapshot.names[entry.nextIndex])
                    .font(.system(.headline, design: .rounded).weight(.bold))
                    .foregroundStyle(inkPrimary)
                timeText(snapshot.times[entry.nextIndex], snapshot, size: 17,
                         weight: .semibold)
                    .foregroundStyle(inkSecondary)
                Spacer()
                CountdownPill(entry: entry, compact: true)
            }
            GeometryReader { proxy in
                let width = proxy.size.width
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.white.opacity(0.18))
                        .frame(height: 5)
                    Capsule()
                        .fill(Color.white.opacity(0.75))
                        .frame(width: max(4, width * nowFraction), height: 5)
                    ForEach(0..<5, id: \.self) { index in
                        if let position = fraction(of: snapshot.times[index]) {
                            let isNext = index == entry.nextIndex
                            Circle()
                                .fill(isNext ? Color.white : Color.white.opacity(0.55))
                                .frame(width: isNext ? 11 : 7, height: isNext ? 11 : 7)
                                .overlay {
                                    if isNext {
                                        Circle().stroke(Color.white.opacity(0.35),
                                                        lineWidth: 3)
                                    }
                                }
                                .offset(x: width * position - (isNext ? 5.5 : 3.5))
                        }
                    }
                }
                .frame(maxHeight: .infinity, alignment: .center)
            }
            .frame(height: 16)
            HStack {
                ForEach(0..<5, id: \.self) { index in
                    if let position = fraction(of: snapshot.times[index]) {
                        Text(snapshot.names[index])
                            .font(.system(size: 8.5, weight: index == entry.nextIndex
                                          ? .bold : .medium, design: .rounded))
                            .foregroundStyle(index == entry.nextIndex
                                             ? inkPrimary : inkTertiary)
                            .frame(maxWidth: .infinity,
                                   alignment: position < 0.2 ? .leading
                                       : position > 0.8 ? .trailing : .center)
                    }
                }
            }
            if family == .systemLarge {
                Rectangle()
                    .fill(Color.white.opacity(0.18))
                    .frame(height: 1)
                    .padding(.vertical, 2)
                VStack(spacing: 3) {
                    ForEach(0..<5, id: \.self) { index in
                        PrayerRow(snapshot: snapshot, index: index,
                                  isNext: index == entry.nextIndex, showIqama: true)
                    }
                }
                Spacer(minLength: 0)
                Text(snapshot.mosque)
                    .font(.system(.caption2, design: .rounded))
                    .lineLimit(1)
                    .foregroundStyle(inkTertiary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

// MARK: - Clock widget

struct ClockDialView: View {
    @Environment(\.widgetFamily) private var family
    let entry: SalatEntry

    var body: some View {
        if entry.isStale { StaleView() } else { content }
    }

    private func angle(forMinutes minutes: Int) -> Double {
        Double(minutes) / 1440 * 360 - 90
    }

    @ViewBuilder private var content: some View {
        let snapshot = entry.snapshot
        let nowMinutes = Calendar.current.component(.hour, from: entry.date) * 60
            + Calendar.current.component(.minute, from: entry.date)

        VStack(spacing: 8) {
            ZStack {
                Canvas { context, size in
                    let center = CGPoint(x: size.width / 2, y: size.height / 2)
                    let radius = min(size.width, size.height) / 2 - 4
                    // 24-hour ticks, majors at 0/6/12/18.
                    for hour in 0..<24 {
                        let tickAngle = Angle.degrees(Double(hour) / 24 * 360 - 90).radians
                        let major = hour % 6 == 0
                        let inner = radius - (major ? 6.5 : 3.5)
                        var path = Path()
                        path.move(to: CGPoint(x: center.x + cos(tickAngle) * inner,
                                              y: center.y + sin(tickAngle) * inner))
                        path.addLine(to: CGPoint(x: center.x + cos(tickAngle) * radius,
                                                 y: center.y + sin(tickAngle) * radius))
                        context.stroke(path,
                                       with: .color(.white.opacity(major ? 0.65 : 0.28)),
                                       lineWidth: major ? 1.8 : 1)
                    }
                    // Track ring.
                    let ringRadius = radius - 13
                    context.stroke(Path(ellipseIn: CGRect(x: center.x - ringRadius,
                                                          y: center.y - ringRadius,
                                                          width: ringRadius * 2,
                                                          height: ringRadius * 2)),
                                   with: .color(.white.opacity(0.16)), lineWidth: 4)
                    // Arc from now to next prayer.
                    if let nextMinutes = minutesOfDay(snapshot.times[entry.nextIndex]) {
                        var sweep = Path()
                        let startAngle = Angle.degrees(angle(forMinutes: nowMinutes))
                        var endMinutes = nextMinutes
                        if endMinutes <= nowMinutes { endMinutes += 1440 }
                        let endAngle = Angle.degrees(angle(forMinutes: endMinutes))
                        sweep.addArc(center: center, radius: ringRadius,
                                     startAngle: startAngle, endAngle: endAngle,
                                     clockwise: false)
                        context.stroke(sweep, with: .color(.white.opacity(0.9)),
                                       style: StrokeStyle(lineWidth: 4, lineCap: .round))
                    }
                    // Prayer dots on the ring.
                    for index in 0..<5 {
                        guard let minutes = minutesOfDay(snapshot.times[index]) else { continue }
                        let dotAngle = Angle.degrees(angle(forMinutes: minutes)).radians
                        let isNext = index == entry.nextIndex
                        let dotRadius: CGFloat = isNext ? 6 : 3.5
                        let position = CGPoint(x: center.x + cos(dotAngle) * ringRadius,
                                               y: center.y + sin(dotAngle) * ringRadius)
                        let rect = CGRect(x: position.x - dotRadius, y: position.y - dotRadius,
                                          width: dotRadius * 2, height: dotRadius * 2)
                        if isNext {
                            let halo = rect.insetBy(dx: -3, dy: -3)
                            context.fill(Path(ellipseIn: halo),
                                         with: .color(.white.opacity(0.3)))
                        }
                        context.fill(Path(ellipseIn: rect),
                                     with: .color(.white.opacity(isNext ? 1 : 0.6)))
                    }
                    // "Now" hand.
                    let nowAngle = Angle.degrees(angle(forMinutes: nowMinutes)).radians
                    var hand = Path()
                    hand.move(to: center)
                    hand.addLine(to: CGPoint(x: center.x + cos(nowAngle) * (ringRadius - 8),
                                             y: center.y + sin(nowAngle) * (ringRadius - 8)))
                    context.stroke(hand, with: .color(.white.opacity(0.85)),
                                   style: StrokeStyle(lineWidth: 1.6, lineCap: .round))
                    context.fill(Path(ellipseIn: CGRect(x: center.x - 2.5,
                                                        y: center.y - 2.5,
                                                        width: 5, height: 5)),
                                 with: .color(.white))
                }
                VStack(spacing: 1) {
                    Image(systemName: prayerSymbols[entry.nextIndex])
                        .font(.system(size: family == .systemSmall ? 10 : 13,
                                      weight: .semibold))
                        .foregroundStyle(inkPrimary)
                    Text(snapshot.names[entry.nextIndex])
                        .font(.system(family == .systemSmall ? .caption2 : .caption,
                                      design: .rounded).weight(.bold))
                        .foregroundStyle(inkPrimary)
                    CountdownText(entry: entry)
                        .font(.system(size: family == .systemSmall ? 9 : 11,
                                      weight: .semibold, design: .rounded))
                        .foregroundStyle(inkSecondary)
                }
            }
            if family == .systemLarge {
                HStack(spacing: 4) {
                    ForEach(0..<5, id: \.self) { index in
                        let isNext = index == entry.nextIndex
                        VStack(spacing: 2) {
                            Image(systemName: prayerSymbols[index])
                                .font(.system(size: 10, weight: .semibold))
                            Text(formatTime(snapshot.times[index], use24h: snapshot.use24h))
                                .font(.system(.caption2, design: .rounded)
                                    .weight(isNext ? .bold : .medium))
                                .monospacedDigit()
                        }
                        .foregroundStyle(isNext ? inkPrimary : inkSecondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 5)
                        .background(isNext ? AnyShapeStyle(pillFill) : AnyShapeStyle(.clear),
                                    in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                    }
                }
            }
        }
    }
}

// MARK: - widget declarations

private func salatWidgetView<Content: View>(_ entry: SalatEntry,
                                            @ViewBuilder content: () -> Content) -> some View {
    content()
        .environment(\.layoutDirection, entry.snapshot.rtl ? .rightToLeft : .leftToRight)
        .containerBackground(for: .widget) { entry.snapshot.canvas }
}

struct SalatOverviewWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "SalatOverview", provider: SalatProvider()) { entry in
            salatWidgetView(entry) { OverviewView(entry: entry) }
        }
        .configurationDisplayName("Prayer Times — Overview")
        .description("Next prayer with a live countdown and today's times.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

struct SalatListWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "SalatList", provider: SalatProvider()) { entry in
            salatWidgetView(entry) { ListView(entry: entry) }
        }
        .configurationDisplayName("Prayer Times — List")
        .description("All five prayers at a glance.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

struct SalatTimelineWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "SalatTimeline", provider: SalatProvider()) { entry in
            salatWidgetView(entry) { DayTimelineView(entry: entry) }
        }
        .configurationDisplayName("Prayer Times — Timeline")
        .description("Your day as a line, prayers as landmarks.")
        .supportedFamilies([.systemMedium, .systemLarge])
    }
}

struct SalatClockWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "SalatClock", provider: SalatProvider()) { entry in
            salatWidgetView(entry) { ClockDialView(entry: entry) }
        }
        .configurationDisplayName("Prayer Times — Clock")
        .description("A 24-hour dial with the prayers marked.")
        .supportedFamilies([.systemSmall, .systemLarge])
    }
}

@main
struct SalatWidgetBundle: WidgetBundle {
    var body: some Widget {
        SalatOverviewWidget()
        SalatListWidget()
        SalatTimelineWidget()
        SalatClockWidget()
    }
}
