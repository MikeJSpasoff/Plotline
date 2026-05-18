//
//  PlotlineApp.swift
//  Plotline
//
//  Created by Mike Spasoff on 5/17/26.
//

import SwiftUI

@main
struct PlotlineApp: App {
    var body: some Scene {
        DocumentGroup(newDocument: Plot()) { file in
            ContentView(document: file.$document)
        }
    }
}
