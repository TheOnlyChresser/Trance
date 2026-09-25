//
//  ContentView.swift
//  Trance
//
//  Created by Chresten Soelberg on 01/09/2026.
//

import SwiftUI

struct ContentView: View {
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
                        .padding(.vertical, 32)
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
                    NavigationLink {
                        NewSessionView()
                    } label: {
                        Label("Ny session", systemImage: "plus")
                    }
                }
            }
        }
    }
}

#Preview {
    ContentView()
}
