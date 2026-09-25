//
//  SearchView.swift
//  Trance
//
//  Created by Chresten Soelberg on 25/09/2026.
//

import SwiftUI

struct SearchView: View {
    @State private var query = ""

    private let sessions = (0..<40).map { "Session \($0)" }

    private var results: [String] {
        guard !query.isEmpty else { return sessions }
        return sessions.filter { $0.localizedStandardContains(query) }
    }

    var body: some View {
        NavigationStack {
            List(results, id: \.self) { session in
                Text(session)
            }
            .overlay {
                if results.isEmpty {
                    ContentUnavailableView.search(text: query)
                }
            }
            .navigationTitle("Søg")
            .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always), prompt: "Søg i sessioner")
        }
    }
}

#Preview {
    SearchView()
}
