//
//  ContentView.swift
//  Trance
//
//  Created by Chresten Soelberg on 01/09/2026.
//

import SwiftUI

struct ContentView: View {
    @State private var isChoosingDuration = false
    @Namespace private var namespace

    private let sessions = Session.mockData

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Sessioner")
                        .font(.title)
                    // to kolonner
                    LazyVGrid(columns: [GridItem(spacing: 12), GridItem(spacing: 12)], spacing: 12) {
                        ForEach(sessions) { session in
                            SessionCard(session: session)
                        }
                    }
                }
                .padding(.horizontal)
            }
            .navigationTitle("Hjem")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Ny session", systemImage: "plus") {
                        isChoosingDuration = true
                    }
                }
                .matchedTransitionSource(id: "ny session", in: namespace)
            }
            .sheet(isPresented: $isChoosingDuration) {
                NewSessionView()
                    .presentationDetents([.medium])
                    // arket vokser ud af plus-knappen
                    .navigationTransition(.zoom(sourceID: "ny session", in: namespace))
            }
        }
    }
}

#Preview {
    ContentView()
}
