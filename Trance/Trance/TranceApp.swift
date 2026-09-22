//
//  TranceApp.swift
//  Trance
//
//  Created by Chresten Soelberg on 01/09/2026.
//

import SwiftUI

@main
struct TranceApp: App {
    var body: some Scene {
        WindowGroup {
            TabView {
                Tab("Hjem", systemImage: "house.fill") {
                    ContentView()
                }
                Tab("Sessioner", systemImage: "list.clipboard.fill") {
                    EmptyView()
                }
                Tab("Profil", systemImage: "person.fill") {
                    EmptyView()
                }
            }
        }
    }
}
