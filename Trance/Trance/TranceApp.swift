//
//  TranceApp.swift
//  Trance
//
//  Created by Chresten Soelberg on 01/09/2026.
//

import SwiftUI

@main
struct TranceApp: App {
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            TabView {
                Tab("Hjem", systemImage: "house.fill") {
                    ContentView()
                }
                Tab("Profil", systemImage: "person.fill") {
                    EmptyView()
                }
                Tab("Søg", systemImage: "magnifyingglass", role: .prominent) {
                    SearchView()
                }
            }
            .onAppear { SensorAccess.start() }
            .onChange(of: scenePhase) { _, phase in
                if phase == .active { SensorAccess.start() }
                if phase == .background { SensorAccess.stop() }
            }
        }
    }
}
