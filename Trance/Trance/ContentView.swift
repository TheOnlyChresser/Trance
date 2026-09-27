//
//  ContentView.swift
//  Trance
//
//  Created by Chresten Soelberg on 01/09/2026.
//

import SwiftUI

/// Appens eneste skærm: vælg hvor lang sessionen skal være, og start den.
struct ContentView: View {
    @State private var minutes = 10
    @State private var isRunning = false
    // tallet vokser med tekststørrelsen i Indstillinger
    @ScaledMetric(relativeTo: .largeTitle) private var durationSize = 64.0

    private let durations = [1, 2, 5, 10, 30, 60]

    var body: some View {
        VStack(spacing: 12) {
            Spacer()

            Text("Hvor lang tid skal din session være?")
                .font(.title3)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            // HIG: en kort liste vælges bedre med en menu end et hjul
            Menu {
                Picker("Varighed", selection: $minutes) {
                    ForEach(durations, id: \.self) { minutes in
                        Text("\(minutes) min")
                    }
                }
            } label: {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text("\(minutes) min")
                        .font(.system(size: durationSize, weight: .semibold, design: .rounded))
                        .contentTransition(.numericText())
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.title2.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
            }
            // altid 1 min øverst, også når menuen åbner opad
            .menuOrder(.fixed)
            // sort, så Start er det eneste pink på skærmen
            .tint(.primary)
            .accessibilityLabel("Varighed")
            .accessibilityValue("\(minutes) minutter")
            .animation(.snappy, value: minutes)

            Spacer()

            Button("Start") {
                isRunning = true
            }
            .buttonStyle(.glassProminent)
            .controlSize(.extraLarge)
            .font(.headline)
            // fylder hele bredden
            .buttonSizing(.flexible)
        }
        .padding()
        .background { MeshBackground() }
        .fullScreenCover(isPresented: $isRunning) {
            SessionView(duration: .seconds(minutes * 60)) { isRunning = false }
        }
    }
}

#Preview {
    ContentView()
        .tint(.pink)
}
