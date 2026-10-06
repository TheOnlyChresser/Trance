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

    private let durations = [1, 2, 5, 10, 30, 60]

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Text("Hvor lang tid skal din session være?")
                .font(.title3)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Picker("Varighed", selection: $minutes) {
                ForEach(durations, id: \.self) { minutes in
                    Text("\(minutes) min")
                }
            }
            #if IOS
            .pickerStyle(.wheel)
            #endif
            .frame(width: 240)
            // hjulet kan ikke få større rækker, så det hele gøres større
            .scaleEffect(1.5)
            .padding(.vertical, 60)

            Spacer()

            Button("Start") { isRunning = true }
            .buttonStyle(.glassProminent)
            .controlSize(.extraLarge)
            .font(.headline)
            // fylder hele bredden
            .buttonSizing(.flexible)
        }
        .padding()
        .background { MeshBackground() }
        #if IOS
        .fullScreenCover(isPresented: $isRunning) {
            SessionView(duration: .seconds(minutes * 60)) { isRunning = false }
        }
        #endif
    }
}

#Preview {
    ContentView()
        .tint(.pink)
}
