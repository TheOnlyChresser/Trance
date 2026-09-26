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

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 16) {
                    Text("Sessioner")
                        .font(.title)
                    ForEach(0..<40) { i in
                        HStack {
                            Text("Session \(i)")
                        }
                        .padding()
                        .padding(.vertical, 16)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color(.secondarySystemBackground))
                        .cornerRadius(80)
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
