//
//  NewSessionView.swift
//  Trance
//
//  Created by Chresten Soelberg on 25/09/2026.
//


import SwiftUI

struct NewSessionView: View {
    @State private var minutes = 10
    @State private var isRunning = false
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 24) {
            Text("Hvor lang tid skal din session være?")
                .font(.title2)
                .multilineTextAlignment(.center)
            Picker("Varighed", selection: $minutes) {
                ForEach([1, 2, 5, 10, 30, 60], id: \.self) { minutes in
                    Text("\(minutes) min")
                }
            }
            .pickerStyle(.wheel)
            Button("Start") {
                isRunning = true
            }
            .buttonStyle(.glassProminent)
            .controlSize(.large)
        }
        .padding()
        .fullScreenCover(isPresented: $isRunning) {
            // Når arket lukkes, forsvinder sessionen oven på det med, så man glider direkte ned på Hjem.
            SessionView(duration: .seconds(minutes * 60)) { dismiss() }
        }
    }
}

#Preview {
    NewSessionView()
}
