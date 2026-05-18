//
//  CalendarView.swift
//  Plotline
//
//  Created by Mike Spasoff on 5/17/26.
//

import SwiftUI

struct CalendarView: View {
    let entries: [PlotEntry]

    // Bumping this triggers a scroll back to the current month.
    @State private var todayScrollTrigger: Int = 0

    private let calendar: Calendar = .current

    var body: some View {
        VStack(spacing: 0) {
            header

            weekdayLabels
                .padding(.horizontal, 12)
                .padding(.vertical, 6)

            Divider()

            scrollingMonths
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            Text("Calendar")
                .font(.title3.weight(.semibold))
            Spacer()
            Button("Today") {
                todayScrollTrigger &+= 1
            }
            .buttonStyle(.borderless)
            .help("Jump to current month")
        }
        .padding(.horizontal, 12)
        .padding(.top, 10)
        .padding(.bottom, 4)
    }

    // MARK: - Weekday labels (sticky above the scroll view)

    private var weekdayLabels: some View {
        let symbols = orderedWeekdaySymbols()
        return HStack(spacing: 4) {
            ForEach(symbols, id: \.self) { day in
                Text(day)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
            }
        }
    }

    private func orderedWeekdaySymbols() -> [String] {
        let symbols = calendar.shortStandaloneWeekdaySymbols
        let first = calendar.firstWeekday - 1
        return Array(symbols[first...] + symbols[..<first])
    }

    // MARK: - Scrolling months

    private var scrollingMonths: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 18) {
                    ForEach(months, id: \.self) { monthDate in
                        MonthSection(
                            monthDate: monthDate,
                            entries: entries,
                            calendar: calendar
                        )
                        .id(monthID(monthDate))
                    }
                }
                .padding(12)
            }
            .onAppear {
                DispatchQueue.main.async {
                    proxy.scrollTo(monthID(Date()), anchor: .top)
                }
            }
            .onChange(of: todayScrollTrigger) { _, _ in
                withAnimation {
                    proxy.scrollTo(monthID(Date()), anchor: .top)
                }
            }
        }
    }

    // Range: 6 months before today through 24 months after today, extended
    // outward so every entry's month is visible (with 1 month padding).
    private var months: [Date] {
        let now = Date()
        guard let nowMonthStart = calendar.dateInterval(of: .month, for: now)?.start else {
            return [now]
        }
        let backDefault = calendar.date(byAdding: .month, value: -6, to: nowMonthStart) ?? nowMonthStart
        let fwdDefault = calendar.date(byAdding: .month, value: 24, to: nowMonthStart) ?? nowMonthStart

        let entryMonthStarts = entries.compactMap {
            calendar.dateInterval(of: .month, for: $0.date)?.start
        }
        let minEntry = entryMonthStarts.min().flatMap {
            calendar.date(byAdding: .month, value: -1, to: $0)
        }
        let maxEntry = entryMonthStarts.max().flatMap {
            calendar.date(byAdding: .month, value: 1, to: $0)
        }

        let start = min(backDefault, minEntry ?? backDefault)
        let end = max(fwdDefault, maxEntry ?? fwdDefault)

        var result: [Date] = []
        var cursor = start
        while cursor <= end {
            result.append(cursor)
            guard let next = calendar.date(byAdding: .month, value: 1, to: cursor) else { break }
            cursor = next
        }
        return result
    }

    private func monthID(_ date: Date) -> String {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .iso8601)
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM"
        return f.string(from: date)
    }
}

// MARK: - Month section

private struct MonthSection: View {
    let monthDate: Date
    let entries: [PlotEntry]
    let calendar: Calendar

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(monthTitle)
                .font(.headline)
            MonthGrid(monthDate: monthDate, entries: entries, calendar: calendar)
        }
    }

    private var monthTitle: String {
        let f = DateFormatter()
        f.dateFormat = "MMMM yyyy"
        return f.string(from: monthDate)
    }
}

// MARK: - Month grid

private struct MonthGrid: View {
    let monthDate: Date
    let entries: [PlotEntry]
    let calendar: Calendar

    var body: some View {
        let columns = Array(repeating: GridItem(.flexible(), spacing: 4), count: 7)
        LazyVGrid(columns: columns, spacing: 4) {
            ForEach(days, id: \.self) { date in
                DayCell(
                    date: date,
                    isInMonth: calendar.isDate(date, equalTo: monthDate, toGranularity: .month),
                    entries: entriesForDay(date)
                )
            }
        }
    }

    private var days: [Date] {
        guard let interval = calendar.dateInterval(of: .month, for: monthDate) else { return [] }
        let firstOfMonth = interval.start
        let lastOfMonth = calendar.date(byAdding: .day, value: -1, to: interval.end) ?? firstOfMonth

        let firstWeekday = calendar.firstWeekday
        let leadingOffset = (calendar.component(.weekday, from: firstOfMonth) - firstWeekday + 7) % 7
        let gridStart = calendar.date(byAdding: .day, value: -leadingOffset, to: firstOfMonth) ?? firstOfMonth

        let trailingOffset = (firstWeekday + 6 - calendar.component(.weekday, from: lastOfMonth) + 7) % 7
        let gridEnd = calendar.date(byAdding: .day, value: trailingOffset, to: lastOfMonth) ?? lastOfMonth

        var result: [Date] = []
        var cursor = gridStart
        while cursor <= gridEnd {
            result.append(cursor)
            guard let next = calendar.date(byAdding: .day, value: 1, to: cursor) else { break }
            cursor = next
        }
        return result
    }

    private func entriesForDay(_ date: Date) -> [PlotEntry] {
        entries.filter { calendar.isDate($0.date, inSameDayAs: date) }
    }
}

// MARK: - Day cell

private struct DayCell: View {
    let date: Date
    let isInMonth: Bool
    let entries: [PlotEntry]

    private let calendar: Calendar = .current

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text("\(calendar.component(.day, from: date))")
                    .font(.caption.weight(isToday ? .bold : .regular))
                    .foregroundStyle(dayNumberColor)
                Spacer(minLength: 0)
            }

            ForEach(entries.prefix(3)) { entry in
                HStack(spacing: 3) {
                    Image(systemName: entry.activity.iconName)
                        .imageScale(.small)
                    Text(label(for: entry))
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
                .font(.caption2)
                .padding(.horizontal, 4)
                .padding(.vertical, 1)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(entry.activity.color.opacity(0.18), in: RoundedRectangle(cornerRadius: 3))
                .foregroundStyle(entry.activity.color)
                .help(tooltip(for: entry))
            }

            if entries.count > 3 {
                Text("+\(entries.count - 3) more")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)
        }
        .padding(4)
        .frame(maxWidth: .infinity, minHeight: 72, alignment: .topLeading)
        .background(cellBackground)
        .overlay(
            RoundedRectangle(cornerRadius: 4)
                .stroke(isToday ? Color.accentColor : Color.secondary.opacity(0.2),
                        lineWidth: isToday ? 1.5 : 1)
        )
        .opacity(isInMonth ? 1.0 : 0.45)
    }

    private var isToday: Bool {
        calendar.isDateInToday(date)
    }

    private func label(for entry: PlotEntry) -> String {
        let trimmed = entry.name.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? entry.activity.displayName : trimmed
    }

    private func tooltip(for entry: PlotEntry) -> String {
        var lines: [String] = ["\(entry.activity.displayName)"]
        let name = entry.name.trimmingCharacters(in: .whitespacesAndNewlines)
        if !name.isEmpty { lines.append(name) }
        let assignee = entry.assignee.trimmingCharacters(in: .whitespacesAndNewlines)
        if !assignee.isEmpty { lines.append(assignee) }
        let details = entry.details.trimmingCharacters(in: .whitespacesAndNewlines)
        if !details.isEmpty { lines.append(details) }
        let url = entry.url.trimmingCharacters(in: .whitespacesAndNewlines)
        if !url.isEmpty { lines.append(url) }
        return lines.joined(separator: "\n")
    }

    private var dayNumberColor: Color {
        if isToday { return .accentColor }
        return isInMonth ? .primary : .secondary
    }

    private var cellBackground: some View {
        RoundedRectangle(cornerRadius: 4)
            .fill(isInMonth ? Color(nsColor: .controlBackgroundColor) : Color.clear)
    }
}

#Preview {
    CalendarView(entries: [
        PlotEntry(date: Date(), activity: .email, assignee: "mike@example.com"),
        PlotEntry(date: Date(), activity: .meeting, assignee: "jane@example.com"),
        PlotEntry(date: Date().addingTimeInterval(86400 * 3), activity: .presentation, assignee: "bob@example.com"),
        PlotEntry(date: Date().addingTimeInterval(86400 * 7), activity: .webpageUpdate, assignee: "alice@example.com"),
        PlotEntry(date: Date().addingTimeInterval(86400 * 40), activity: .meeting, assignee: "carol@example.com")
    ])
    .frame(width: 500, height: 600)
}
