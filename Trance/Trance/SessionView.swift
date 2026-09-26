//
//  SessionView.swift
//  Trance
//
//  Created by Chresten Soelberg on 25/09/2026.
//

import SwiftUI

struct SessionView: View {
    let duration: Duration
    let onFinish: () -> Void

    // hardcodet indtil scoren kommer fra sensorerne
    private let relaxation = 0.7
    // bruges indtil HealthKit har en pulsmåling
    @State private var bpm = 60.0
    @State private var relaxationSamples: [Double] = []
    @State private var result: Double?

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            if let result {
                // Efter sessionen: en let farvegradient fra skærmens kant ind mod teksten.
                // Midten har baggrundens farve og ligger samme sted som teksten.
                MeshGradient(
                    width: 3,
                    height: 3,
                    points: [
                        [0, 0], [0.5, 0], [1, 0],
                        [0, 0.44], [0.5, 0.44], [1, 0.44],
                        [0, 1], [0.5, 1], [1, 1],
                    ],
                    colors: [
                        .orange, .yellow, .orange,
                        .pink, Color(.systemBackground), .mint,
                        .teal, .cyan, .blue,
                    ]
                )
                .opacity(0.35)
                .ignoresSafeArea()
                // starter forstørret, så farverne glider ind fra kanten mod teksten
                .transition(.scale(1.4, anchor: UnitPoint(x: 0.5, y: 0.44)).combined(with: .opacity))

                SessionSummaryView(relaxation: result)
                    .padding(.horizontal, 32)
                    // samme sted som prikken
                    .padding(.bottom, 128)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .overlay(alignment: .bottom) {
                        Button("Færdig", action: onFinish)
                            .buttonStyle(.glassProminent)
                            .controlSize(.extraLarge)
                            .font(.headline)
                            // fylder hele bredden
                            .buttonSizing(.flexible)
                            .padding(.horizontal)
                    }
            } else {
                RelaxationBorder(score: relaxation, bpm: bpm)
                    .ignoresSafeArea()
                    // kanten trækker sig ind og bliver sløret, mens gradienten kommer frem
                    .transition(.blurReplace(.downUp))

                Circle()
                    .frame(width: 16, height: 16)
                    .padding(.bottom, 128)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    // prikken forsvinder hurtigt, så den ikke ligger oven på teksten der kommer frem
                    .transition(.opacity.animation(.smooth(duration: 0.25)))
                    .persistentSystemOverlays(.hidden)
                    // skærmen skal ikke låse, man skal fokusere ikke pille ved skærmen
                    .onAppear { UIApplication.shared.isIdleTimerDisabled = true }
                    .onDisappear { UIApplication.shared.isIdleTimerDisabled = false }
                    // når tiden er gået, vis resume
                    .task {
                        try? await Task.sleep(for: duration)
                        relaxationSamples.append(relaxation)
                        withAnimation(reduceMotion ? nil : .spring(duration: 1.2, bounce: 0)) {
                            result = relaxationSamples.reduce(0, +) / Double(relaxationSamples.count)
                        }
                    }
                    // pulsen fra HealthKit skifter sjældent, så det er nok at kigge hvert 5. sekund
                    .task {
                        while !Task.isCancelled {
                            let heartRate = copySensorSnapshot().heartRate
                            if heartRate.available, heartRate.bpm > 0 { bpm = heartRate.bpm }
                            relaxationSamples.append(relaxation)
                            try? await Task.sleep(for: .seconds(5))
                        }
                    }
            }
        }
        .statusBarHidden()
        // haptic feedback når tiden er gået
        .sensoryFeedback(.impact(flexibility: .soft), trigger: result)
    }
}

#Preview {
    SessionView(duration: .seconds(60)) {}
}
