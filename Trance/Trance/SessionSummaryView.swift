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
        VStack(spacing: 8) {
            Text(title)
                .font(.title.bold())
            Text(message)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
    }

    private var title: String {
        if relaxation >= 0.8 { return "Dybt afslappet" }
        if relaxation >= 0.6 { return "Godt afslappet" }
        if relaxation >= 0.4 { return "På vej mod ro" }
        return "En urolig session"
    }

    private var message: String {
        if relaxation >= 0.8 { return "Du fandt helt ned i roen. Tag den med dig resten af dagen." }
        if relaxation >= 0.6 { return "Din krop fandt roen undervejs. Godt gået." }
        if relaxation >= 0.4 { return "Du gav dig selv en pause, og det kan mærkes." }
        return "Nogle dage er sværere end andre. Hver session tæller."
    }
}

#Preview {
    SessionSummaryView(relaxation: 0.7)
}
