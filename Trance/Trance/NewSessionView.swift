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

    var body: some View {
        VStack(spacing: 24) {
            Text("Hvor lang tid skal din session være?")
                .font(.title2)
                .multilineTextAlignment(.center)
            Picker("Varighed", selection: $minutes) {
                ForEach(1...12, id: \.self) { minutes in
                    Text("\(minutes * 5) min")
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
            SessionView(duration: .seconds(minutes * 60 * 5))
        }
    }
}

#Preview {
    NavigationStack {
        NewSessionView()
    }
}
