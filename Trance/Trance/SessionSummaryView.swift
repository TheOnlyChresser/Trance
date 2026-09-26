//
//  SessionSummaryView.swift
//  Trance
//
//  Created by Chresten Soelberg on 26/09/2026.
//

import SwiftUI

struct SessionSummaryView: View {
    let relaxation: Double
    let onDone: () -> Void

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            // ringen med procenten i midten
            ZStack {
                // grå baggrundsring
                Circle()
                    .stroke(Color.gray.opacity(0.2), lineWidth: 14)

                // farvet bue
                Circle()
                    .trim(from: 0, to: relaxation)
                    .stroke(Color.relaxation(relaxation), style: StrokeStyle(lineWidth: 14, lineCap: .round))
                    // så buen starter øverst i stedet for højre
                    .rotationEffect(.degrees(-90))

                Text("\(Int((relaxation * 100).rounded())) %")
                    .font(.system(size: 44, weight: .semibold, design: .rounded))
            }
            .frame(width: 180, height: 180)

            VStack(spacing: 8) {
                Text(title)
                    .font(.title.bold())
                Text(message)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            Spacer()

            Button("Færdig", action: onDone)
                .buttonStyle(.glassProminent)
                .controlSize(.large)
        }
        .padding()
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
    SessionSummaryView(relaxation: 0.7) {}
}
