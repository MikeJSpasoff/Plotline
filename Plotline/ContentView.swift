//
//  ContentView.swift
//  Plotline
//
//  Created by Mike Spasoff on 5/17/26.
//

import SwiftUI

struct ContentView: View {
    @Binding var document: Plot
    @State private var selection = Set<PlotEntry.ID>()

    var body: some View {
        HSplitView {
            entriesTable
                .frame(minWidth: 480, idealWidth: 820)

            CalendarView(entries: document.entries)
                .frame(minWidth: 380, idealWidth: 520)
        }
        .toolbar {
            ToolbarItem {
                Button(action: addEntry) {
                    Label("Add Entry", systemImage: "plus")
                }
                .help("Add a new entry")
            }
            ToolbarItem {
                Button(role: .destructive, action: deleteSelected) {
                    Label("Delete", systemImage: "minus")
                }
                .disabled(selection.isEmpty)
                .help("Delete selected entries")
            }
        }
        .navigationTitle("Plot")
    }

    private var entriesTable: some View {
        Table($document.entries, selection: $selection) {
            TableColumn("Date") { $entry in
                DatePicker("", selection: $entry.date, displayedComponents: .date)
                    .labelsHidden()
            }
            .width(min: 110, ideal: 140)

            TableColumn("Activity") { $entry in
                Picker("", selection: $entry.activity) {
                    ForEach(ActivityType.allCases) { type in
                        Text(type.displayName).tag(type)
                    }
                }
                .labelsHidden()
            }
            .width(min: 130, ideal: 160)

            TableColumn("Assignee") { $entry in
                TextField("name@example.com", text: $entry.assignee)
                    .textFieldStyle(.plain)
            }
            .width(min: 160, ideal: 220)

            TableColumn("Name") { $entry in
                TextField("Short name", text: $entry.name)
                    .textFieldStyle(.plain)
            }
            .width(min: 140, ideal: 200)

            TableColumn("Description") { $entry in
                TextField("Details", text: $entry.details, axis: .vertical)
                    .textFieldStyle(.plain)
                    .lineLimit(1...3)
            }
            .width(min: 180, ideal: 280)

            TableColumn("URL") { $entry in
                TextField("https://", text: $entry.url)
                    .textFieldStyle(.plain)
            }
            .width(min: 160, ideal: 220)
        }
    }

    private func addEntry() {
        let new = PlotEntry(date: Date(), activity: .email, assignee: "")
        document.entries.append(new)
        selection = [new.id]
    }

    private func deleteSelected() {
        document.entries.removeAll { selection.contains($0.id) }
        selection.removeAll()
    }
}

#Preview {
    ContentView(document: .constant(Plot(entries: [
        PlotEntry(date: Date(), activity: .email, assignee: "mike@example.com"),
        PlotEntry(date: Date().addingTimeInterval(86400), activity: .meeting, assignee: "jane@example.com")
    ])))
    .frame(width: 1000, height: 600)
}
