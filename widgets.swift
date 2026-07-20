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

// MARK: - shared view pieces

extension PrayerSnapshot {
    var accentColor: Color {
        guard accent.count >= 3 else { return .teal }
        return Color(red: accent[0], green: accent[1], blue: accent[2])
    }
}

struct StaleView: View {
    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: "moon.stars")
                .font(.title2)
                .foregroundStyle(.secondary)
            Text("Salat Time")
                .font(.headline)
            Text("Open the app to refresh")
                .font(.caption)
                .foregroundStyle(.secondary)
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

private func rowHighlight(_ isNext: Bool, _ accent: Color) -> some ShapeStyle {
    isNext ? AnyShapeStyle(accent.opacity(0.14)) : AnyShapeStyle(.clear)
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
        let accent = snapshot.accentColor
        switch family {
        case .systemSmall:
            VStack(alignment: .leading, spacing: 2) {
                Text(snapshot.nextLabel.uppercased())
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
                Text(snapshot.names[entry.nextIndex])
                    .font(.system(.title2, design: .rounded).weight(.bold))
                Text(formatTime(snapshot.times[entry.nextIndex], use24h: snapshot.use24h))
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                    .foregroundStyle(accent)
                CountdownText(entry: entry)
                    .font(.callout.weight(.medium))
                    .foregroundStyle(.secondary)
                Spacer(minLength: 0)
                Text(snapshot.mosque)
                    .font(.caption2)
                    .lineLimit(1)
                    .foregroundStyle(.tertiary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        case .systemMedium:
            HStack(spacing: 14) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(snapshot.nextLabel.uppercased())
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Text(snapshot.names[entry.nextIndex])
                        .font(.system(.title, design: .rounded).weight(.bold))
                    Text(formatTime(snapshot.times[entry.nextIndex], use24h: snapshot.use24h))
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundStyle(accent)
                    CountdownText(entry: entry)
                        .font(.callout.weight(.medium))
                        .foregroundStyle(.secondary)
                    Spacer(minLength: 0)
                }
                Divider()
                VStack(alignment: .leading, spacing: 3) {
                    ForEach(0..<5, id: \.self) { index in
                        HStack {
                            Text(snapshot.names[index])
                                .font(.caption.weight(index == entry.nextIndex ? .bold : .regular))
                            Spacer(minLength: 8)
                            Text(formatTime(snapshot.times[index], use24h: snapshot.use24h))
                                .font(.caption.monospacedDigit())
                                .foregroundStyle(index == entry.nextIndex
                                                 ? AnyShapeStyle(accent) : AnyShapeStyle(.secondary))
                        }
                    }
                }
                .frame(maxWidth: 150)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        default:
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .firstTextBaseline) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(snapshot.nextLabel.uppercased())
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.secondary)
                        Text(snapshot.names[entry.nextIndex])
                            .font(.system(.title, design: .rounded).weight(.bold))
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(formatTime(snapshot.times[entry.nextIndex], use24h: snapshot.use24h))
                            .font(.system(size: 34, weight: .bold, design: .rounded))
                            .foregroundStyle(accent)
                        CountdownText(entry: entry)
                            .font(.callout.weight(.medium))
                            .foregroundStyle(.secondary)
                    }
                }
                Divider()
                ForEach(0..<5, id: \.self) { index in
                    HStack {
                        Circle()
                            .fill(index == entry.nextIndex ? accent : Color.secondary.opacity(0.35))
                            .frame(width: 7, height: 7)
                        Text(snapshot.names[index])
                            .font(.body.weight(index == entry.nextIndex ? .semibold : .regular))
                        Spacer()
                        if snapshot.iqama.count > index, !snapshot.iqama[index].isEmpty {
                            Text("\(snapshot.iqamaLabel) \(formatTime(snapshot.iqama[index], use24h: snapshot.use24h))")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }
                        Text(formatTime(snapshot.times[index], use24h: snapshot.use24h))
                            .font(.body.monospacedDigit().weight(index == entry.nextIndex ? .bold : .regular))
                            .foregroundStyle(index == entry.nextIndex
                                             ? AnyShapeStyle(accent) : AnyShapeStyle(.primary))
                    }
                    .padding(.vertical, 3)
                    .padding(.horizontal, 6)
                    .background(rowHighlight(index == entry.nextIndex, accent),
                                in: RoundedRectangle(cornerRadius: 6))
                }
                Spacer(minLength: 0)
                HStack {
                    Text(snapshot.mosque).lineLimit(1)
                    Spacer()
                    Text("\(snapshot.shuruqLabel) \(formatTime(snapshot.shuruq, use24h: snapshot.use24h))")
                }
                .font(.caption2)
                .foregroundStyle(.tertiary)
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
        let accent = snapshot.accentColor
        let compact = family == .systemSmall
        VStack(alignment: .leading, spacing: compact ? 3 : 5) {
            ForEach(0..<5, id: \.self) { index in
                HStack {
                    Text(snapshot.names[index])
                        .font((compact ? Font.caption : .body)
                            .weight(index == entry.nextIndex ? .semibold : .regular))
                    Spacer(minLength: 6)
                    if !compact, family == .systemLarge,
                       snapshot.iqama.count > index, !snapshot.iqama[index].isEmpty {
                        Text(formatTime(snapshot.iqama[index], use24h: snapshot.use24h))
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.tertiary)
                    }
                    Text(formatTime(snapshot.times[index], use24h: snapshot.use24h))
                        .font((compact ? Font.caption : .body).monospacedDigit()
                            .weight(index == entry.nextIndex ? .bold : .regular))
                        .foregroundStyle(index == entry.nextIndex
                                         ? AnyShapeStyle(accent) : AnyShapeStyle(.primary))
                }
                .padding(.vertical, compact ? 1 : 3)
                .padding(.horizontal, compact ? 4 : 6)
                .background(rowHighlight(index == entry.nextIndex, accent),
                            in: RoundedRectangle(cornerRadius: 6))
            }
            if family == .systemLarge {
                Divider()
                HStack {
                    Text(snapshot.nextLabel)
                    CountdownText(entry: entry).foregroundStyle(accent)
                    Spacer()
                    Text("\(snapshot.shuruqLabel) \(formatTime(snapshot.shuruq, use24h: snapshot.use24h))")
                        .foregroundStyle(.tertiary)
                }
                .font(.caption)
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
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
        let accent = snapshot.accentColor
        let nowMinutes = Calendar.current.component(.hour, from: entry.date) * 60
            + Calendar.current.component(.minute, from: entry.date)
        let nowFraction = CGFloat(nowMinutes) / 1440

        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text(snapshot.names[entry.nextIndex])
                    .font(.system(.headline, design: .rounded).weight(.bold))
                Text(formatTime(snapshot.times[entry.nextIndex], use24h: snapshot.use24h))
                    .font(.headline.monospacedDigit())
                    .foregroundStyle(accent)
                Spacer()
                CountdownText(entry: entry)
                    .font(.callout.weight(.medium))
                    .foregroundStyle(.secondary)
            }
            GeometryReader { proxy in
                let width = proxy.size.width
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.secondary.opacity(0.18))
                        .frame(height: 6)
                    Capsule()
                        .fill(accent.opacity(0.55))
                        .frame(width: max(3, width * nowFraction), height: 6)
                    ForEach(0..<5, id: \.self) { index in
                        if let position = fraction(of: snapshot.times[index]) {
                            Circle()
                                .fill(index == entry.nextIndex ? accent : Color.secondary)
                                .frame(width: index == entry.nextIndex ? 11 : 7,
                                       height: index == entry.nextIndex ? 11 : 7)
                                .offset(x: width * position - 4)
                        }
                    }
                }
                .frame(maxHeight: .infinity, alignment: .center)
            }
            .frame(height: 18)
            HStack {
                Text("00").font(.caption2).foregroundStyle(.tertiary)
                Spacer()
                Text("12").font(.caption2).foregroundStyle(.tertiary)
                Spacer()
                Text("24").font(.caption2).foregroundStyle(.tertiary)
            }
            if family == .systemLarge {
                Divider()
                ForEach(0..<5, id: \.self) { index in
                    HStack {
                        Circle()
                            .fill(index == entry.nextIndex ? accent : Color.secondary.opacity(0.4))
                            .frame(width: 7, height: 7)
                        Text(snapshot.names[index])
                            .font(.body.weight(index == entry.nextIndex ? .semibold : .regular))
                        Spacer()
                        Text(formatTime(snapshot.times[index], use24h: snapshot.use24h))
                            .font(.body.monospacedDigit())
                            .foregroundStyle(index == entry.nextIndex
                                             ? AnyShapeStyle(accent) : AnyShapeStyle(.secondary))
                    }
                }
                Spacer(minLength: 0)
                Text(snapshot.mosque)
                    .font(.caption2)
                    .lineLimit(1)
                    .foregroundStyle(.tertiary)
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
        let accent = snapshot.accentColor
        let nowMinutes = Calendar.current.component(.hour, from: entry.date) * 60
            + Calendar.current.component(.minute, from: entry.date)

        VStack(spacing: 6) {
            ZStack {
                Canvas { context, size in
                    let center = CGPoint(x: size.width / 2, y: size.height / 2)
                    let radius = min(size.width, size.height) / 2 - 6
                    // 24-hour ticks.
                    for hour in 0..<24 {
                        let tickAngle = Angle.degrees(Double(hour) / 24 * 360 - 90).radians
                        let major = hour % 6 == 0
                        let inner = radius - (major ? 7 : 4)
                        var path = Path()
                        path.move(to: CGPoint(x: center.x + cos(tickAngle) * inner,
                                              y: center.y + sin(tickAngle) * inner))
                        path.addLine(to: CGPoint(x: center.x + cos(tickAngle) * radius,
                                                 y: center.y + sin(tickAngle) * radius))
                        context.stroke(path, with: .color(.secondary.opacity(major ? 0.55 : 0.25)),
                                       lineWidth: major ? 1.6 : 1)
                    }
                    // Arc from now to next prayer.
                    if let nextMinutes = minutesOfDay(snapshot.times[entry.nextIndex]) {
                        var sweep = Path()
                        let startAngle = Angle.degrees(angle(forMinutes: nowMinutes))
                        var endMinutes = nextMinutes
                        if endMinutes <= nowMinutes { endMinutes += 1440 }
                        let endAngle = Angle.degrees(angle(forMinutes: endMinutes))
                        sweep.addArc(center: center, radius: radius - 12,
                                     startAngle: startAngle, endAngle: endAngle,
                                     clockwise: false)
                        context.stroke(sweep, with: .color(accent.opacity(0.7)),
                                       style: StrokeStyle(lineWidth: 3, lineCap: .round))
                    }
                    // Prayer dots.
                    for index in 0..<5 {
                        guard let minutes = minutesOfDay(snapshot.times[index]) else { continue }
                        let dotAngle = Angle.degrees(angle(forMinutes: minutes)).radians
                        let dotRadius: CGFloat = index == entry.nextIndex ? 5.5 : 3.5
                        let position = CGPoint(x: center.x + cos(dotAngle) * (radius - 12),
                                               y: center.y + sin(dotAngle) * (radius - 12))
                        let rect = CGRect(x: position.x - dotRadius, y: position.y - dotRadius,
                                          width: dotRadius * 2, height: dotRadius * 2)
                        context.fill(Path(ellipseIn: rect),
                                     with: .color(index == entry.nextIndex ? accent : .secondary))
                    }
                    // "Now" marker.
                    let nowAngle = Angle.degrees(angle(forMinutes: nowMinutes)).radians
                    var hand = Path()
                    hand.move(to: center)
                    hand.addLine(to: CGPoint(x: center.x + cos(nowAngle) * (radius - 18),
                                             y: center.y + sin(nowAngle) * (radius - 18)))
                    context.stroke(hand, with: .color(.primary.opacity(0.6)), lineWidth: 1.4)
                    context.fill(Path(ellipseIn: CGRect(x: center.x - 2.5, y: center.y - 2.5,
                                                        width: 5, height: 5)),
                                 with: .color(.primary.opacity(0.7)))
                }
                VStack(spacing: 0) {
                    Text(snapshot.names[entry.nextIndex])
                        .font(.system(.caption, design: .rounded).weight(.bold))
                    CountdownText(entry: entry)
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(accent)
                }
                .padding(6)
                .background(.background.opacity(0.75), in: Capsule())
                .offset(y: family == .systemSmall ? 26 : 40)
            }
            if family == .systemLarge {
                HStack {
                    ForEach(0..<5, id: \.self) { index in
                        VStack(spacing: 1) {
                            Text(snapshot.names[index])
                                .font(.caption2.weight(index == entry.nextIndex ? .bold : .regular))
                                .lineLimit(1)
                            Text(formatTime(snapshot.times[index], use24h: snapshot.use24h))
                                .font(.caption2.monospacedDigit())
                                .foregroundStyle(index == entry.nextIndex
                                                 ? AnyShapeStyle(accent) : AnyShapeStyle(.secondary))
                        }
                        .frame(maxWidth: .infinity)
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
        .containerBackground(for: .widget) { Color.clear.background(.background) }
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
