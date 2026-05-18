//
//  Plot.swift
//  Plotline
//
//  Created by Mike Spasoff on 5/17/26.
//

import Foundation
import SwiftUI
import UniformTypeIdentifiers

extension UTType {
    static let plotDocument = UTType(
        exportedAs: "com.mediaintegrated.plotline.plot",
        conformingTo: .utf8PlainText
    )
}

enum ActivityType: String, CaseIterable, Identifiable, Hashable {
    case email = "email"
    case meeting = "meeting"
    case presentation = "presentation"
    case webpageUpdate = "webpage update"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .email: return "Email"
        case .meeting: return "Meeting"
        case .presentation: return "Presentation"
        case .webpageUpdate: return "Webpage Update"
        }
    }

    var color: Color {
        switch self {
        case .email: return .blue
        case .meeting: return .purple
        case .presentation: return .orange
        case .webpageUpdate: return .green
        }
    }

    var iconName: String {
        switch self {
        case .email: return "envelope.fill"
        case .meeting: return "person.2.fill"
        case .presentation: return "rectangle.on.rectangle.fill"
        case .webpageUpdate: return "globe"
        }
    }
}

struct PlotEntry: Identifiable, Hashable {
    var id = UUID()
    var date: Date
    var activity: ActivityType
    var assignee: String
    var name: String = ""
    var details: String = ""
    var url: String = ""
}

struct Plot: FileDocument {
    static var readableContentTypes: [UTType] { [.plotDocument] }

    var entries: [PlotEntry]

    init(entries: [PlotEntry] = []) {
        self.entries = entries
    }

    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents,
              let text = String(data: data, encoding: .utf8) else {
            throw CocoaError(.fileReadCorruptFile)
        }
        self.entries = Plot.parse(text: text)
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        let text = Plot.serialize(entries: entries)
        return FileWrapper(regularFileWithContents: Data(text.utf8))
    }

    // MARK: - Plain text format
    //
    // # Plotline
    // # date | activity | assignee | name | description | url
    // 2026-05-17 | email | mike@example.com | Q3 Launch | Initial outreach | https://example.com
    //
    // Within any field, `|`, `\`, newline, and carriage return are escaped as
    // `\|`, `\\`, `\n`, `\r`. Files with only the first three columns
    // (date, activity, assignee) are still parsed for backward compatibility.

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .iso8601)
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone(secondsFromGMT: 0)
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    static func serialize(entries: [PlotEntry]) -> String {
        var lines: [String] = [
            "# Plotline",
            "# date | activity | assignee | name | description | url"
        ]
        for entry in entries {
            let dateString = dateFormatter.string(from: entry.date)
            let fields: [String] = [
                dateString,
                entry.activity.rawValue,
                escape(entry.assignee),
                escape(entry.name),
                escape(entry.details),
                escape(entry.url)
            ]
            lines.append(fields.joined(separator: " | "))
        }
        return lines.joined(separator: "\n") + "\n"
    }

    static func parse(text: String) -> [PlotEntry] {
        var result: [PlotEntry] = []
        for raw in text.split(whereSeparator: \.isNewline) {
            let line = raw.trimmingCharacters(in: .whitespaces)
            if line.isEmpty || line.hasPrefix("#") { continue }

            let parts = splitEscaped(line)
            guard parts.count >= 3,
                  let date = dateFormatter.date(from: parts[0]),
                  let activity = ActivityType(rawValue: parts[1].lowercased())
            else { continue }

            let assignee = unescape(parts[2])
            let name = parts.count > 3 ? unescape(parts[3]) : ""
            let details = parts.count > 4 ? unescape(parts[4]) : ""
            let url = parts.count > 5 ? unescape(parts[5]) : ""

            result.append(PlotEntry(
                date: date,
                activity: activity,
                assignee: assignee,
                name: name,
                details: details,
                url: url
            ))
        }
        return result
    }

    // MARK: - Escaping

    private static func escape(_ s: String) -> String {
        var out = ""
        out.reserveCapacity(s.count)
        for c in s {
            switch c {
            case "\\": out.append("\\\\")
            case "|":  out.append("\\|")
            case "\n": out.append("\\n")
            case "\r": out.append("\\r")
            default:   out.append(c)
            }
        }
        return out
    }

    private static func unescape(_ s: String) -> String {
        var out = ""
        out.reserveCapacity(s.count)
        var iter = s.makeIterator()
        while let c = iter.next() {
            if c == "\\", let next = iter.next() {
                switch next {
                case "\\": out.append("\\")
                case "|":  out.append("|")
                case "n":  out.append("\n")
                case "r":  out.append("\r")
                default:
                    out.append("\\")
                    out.append(next)
                }
            } else {
                out.append(c)
            }
        }
        return out
    }

    // Splits a line on `|` while honoring `\|` (escaped pipe). Trims surrounding
    // whitespace on each resulting field but leaves the escape sequences intact
    // for `unescape` to handle.
    private static func splitEscaped(_ line: String) -> [String] {
        var parts: [String] = []
        var current = ""
        var iter = line.makeIterator()
        while let c = iter.next() {
            if c == "\\" {
                current.append(c)
                if let next = iter.next() {
                    current.append(next)
                }
            } else if c == "|" {
                parts.append(current.trimmingCharacters(in: .whitespaces))
                current = ""
            } else {
                current.append(c)
            }
        }
        parts.append(current.trimmingCharacters(in: .whitespaces))
        return parts
    }
}
