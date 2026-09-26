//
//  SessionSummaryView.swift
//  Trance
//
//  Created by Chresten Soelberg on 26/09/2026.
//

import SwiftUI

/// Teksten der står inde i kanten, når sessionen er slut.
struct SessionSummaryView: View {
    let relaxation: Double

    var body: some View {
        let mood = Mood(relaxation)
        VStack(spacing: 8) {
            Text(mood.title)
                .font(.title.bold())
            Text(mood.message)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
    }
}

#Preview {
    SessionSummaryView(relaxation: 0.7)
}
